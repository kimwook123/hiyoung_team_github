# ARCHITECTURE_NOTES.md

## 전체 시스템 구조
- 시스템은 Python 추론 모듈과 Flutter GUI 모듈이 분리된 멀티프로세스 구조다.
- Python은 분석과 이벤트 생성을 담당하고, Flutter는 입력 선택과 결과 시각화를 담당한다.
- 두 모듈은 직접 IPC를 쓰지 않고 `logs` 디렉터리 아래 파일을 교환 매체로 사용한다.
- 현재 구조는 순수 파일 브릿지 방식에서 서버 중심 이벤트 저장 구조로 점진 전환 중이다.

## Python 추론 모듈의 역할
- 프레임 입력 추상화: `FrameSource`
- 모델 추론 추상화: `DetectionModel`
- 프레임별 객체 탐지 결과 생성: `DetectionResult`
- 사람 추적 ID 부여: `PersonTracker`
- 이벤트 규칙 평가: `EventRule`
- 이벤트 상태 관리: `EventFilter`
- 로그/콘솔 후처리: `EventHandler`
- 이벤트 클립 저장: `EventClipRecorder`

## Flutter GUI 모듈의 역할
- 사용자가 영상 파일 또는 스트림 주소를 선택하도록 한다.
- Python이 읽을 `source_state.json`을 갱신한다.
- 로그 파일을 polling으로 읽어 이벤트 목록을 갱신한다.
- 영상 재생, 프레임 이동, 이벤트 오버레이를 제공한다.
- 스트림 이벤트에 연결된 클립 재생과 라이브 복귀 흐름을 제공한다.

## Python과 Flutter의 데이터 교환 방식
- Flutter -> Python
  - `source_state.json`
  - 의미: 현재 선택한 입력 소스 전달
- Python -> Flutter
  - `ui_bridge.json`
  - 의미: 현재 입력 종류, 입력 값, 로그 경로, 모델 종류, FPS 전달
- Python -> Flutter 간접 표시 데이터
  - `*_event_log.txt`
  - `logs/clips/*.mp4`

## 이벤트 저장 모드
- 기본값은 로컬 JSONL 모드이며, Python이 `JsonEventHandler`로 `events.jsonl`을 직접 기록한다.
- 서버 전송 모드에서는 Python이 `POST /api/events`로 이벤트를 보내고, FastAPI 서버가 `events.jsonl` 저장 책임을 가진다.
- 이 모드에서는 같은 `events.jsonl` 중복 저장을 막기 위해 일반 `JsonEventHandler`를 동시에 켜지 않는다.
- 서버 전송 실패 시에만 `events_post_failed.jsonl` 같은 fallback JSONL에 실패 이벤트를 남길 수 있다.
- 누적된 fallback 이벤트는 `run_repost_failed_events.bat` 또는 `tools/repost_failed_events.py`로 나중에 수동 재전송할 수 있다.
- 재전송 스크립트는 원본 fallback 파일을 수정하지 않고, 성공/실패 결과를 별도 JSONL 파일로 남긴다.
- 현재 단계에서는 서버가 `data/events.jsonl`과 `data/clips/` 구조를 소유하도록 준비되어 있다.
- 서버 전송과 클립 업로드 모드를 함께 켰을 때 서버가 이벤트와 클립의 소유권을 더 직접적으로 갖게 된다.

## 현재 역할 분리
- Python AI Worker는 `Event/Clip Producer` 역할을 맡는다.
- FastAPI Server는 `Event/Clip Store`이자 `API Provider` 역할을 맡는다.
- Flutter GUI는 파일 로그 또는 서버 API를 소비하는 `Event/Clip Consumer` 역할을 맡는다.
- `events.jsonl`은 현재 프로토타입 저장소이며, 추후 DB로 교체될 수 있다.
- fallback JSONL은 서버 장애 시 이벤트 유실을 줄이기 위한 안전장치다.
- 이벤트 데이터와 클립 파일의 최종 소유권은 서버로 이동하는 방향이다.
- 기존 `safety_ai_monitor/logs`는 로컬 실행 로그와 fallback 용도로 유지된다.
- 서버는 `safety_monitor_server/data/events.jsonl`과 `safety_monitor_server/data/clips/`를 소유한다.
- 서버 전송 모드에서 Python은 이벤트를 `POST /api/events`로 보내고, 클립은 `POST /api/clips`로 업로드할 수 있다.
- 서버가 반환한 `clip_url`은 Flutter가 서버 클립을 재생하는 데 사용된다.
- 서버는 이벤트 저장 시 clip 접근 필드를 정규화해 클라이언트 소비를 단순화한다.
- 서버 클립이 있으면 `preferred_clip_source="server"`를, 없으면 로컬 fallback 기준으로 `preferred_clip_source="local"` 또는 빈 값을 기록할 수 있다.
- 현재 저장 구조는 파일 기반 프로토타입이며, 추후 DB, Object Storage, WebSocket 구조로 확장할 수 있다.

## 파일 입출력 기반 통신을 사용하는 경우의 장점과 한계
### 장점
- 구현이 단순하다.
- Python과 Flutter를 느슨하게 결합할 수 있다.
- 배치 실행, 단독 실행, 디버그 실행을 분리하기 쉽다.
- 로그와 결과 파일이 곧 디버깅 자료가 된다.

### 한계
- 실시간 양방향 제어에는 반응성이 낮다.
- 파일 잠금, 부분 쓰기, JSON 미완성 상태 같은 경계 상황을 신경 써야 한다.
- 포맷 변경 시 양쪽 파서가 동시에 깨질 수 있다.
- 현재는 폴링 기반이라 이벤트 반영 주기가 파일 읽기 주기에 의존한다.

## 모델 로드와 추론 흐름
- `main.py`에서 `MODEL_TYPE` 기준으로 구현체를 선택한다.
- YOLO 구현은 `YoloModelSample`에서 `ultralytics.YOLO`로 가중치를 로드한다.
- 추론 결과는 모델 원본 타입을 그대로 흘리지 않고 `DetectionResult`로 변환한다.
- 이 공통 포맷 덕분에 룰, 추적기, 핸들러는 모델 프레임워크를 직접 알 필요가 없다.

## 결과 데이터 포맷
- 검출 공통 포맷
  - `Detection(name, score, box, track_id)`
  - `DetectionResult(frame_id, detections, source_time_seconds, source_time_text, event_created_at)`
- 이벤트 공통 포맷
  - `Event(event_type, message, frame_id, created_at, level, related_detections, status, ...)`
- 로그 저장 포맷
  - 쉼표 구분 단일 텍스트 라인
  - 포함 키: `frame`, `event_key`, `status`, `type`, `person_id`, `level`, `start`, `start_frame`, `end`, `end_frame`, `duration`, `clip_path`, `message`
- GUI 파싱 포맷
  - Dart `EventLogItem.fromLine()`이 위 로그 한 줄 형식을 직접 파싱한다.

## 모델 교체 구조
- 장점
  - `DetectionModel` 인터페이스가 이미 있어 새 모델 어댑터를 붙이기 쉽다.
  - 룰/이벤트/GUI는 공통 포맷만 신뢰하므로 추론 백엔드를 숨길 수 있다.
- 한계
  - 새 모델 등록이 자동 발견 방식이 아니라 `main.py` 수동 분기 방식이다.
  - 현재 룰이 클래스 이름 문자열에 의존해 모델 호환성이 낮다.
  - `PersonTracker`도 `person` 이름에 의존한다.

## 안전모 탐지로 확장할 때 고려할 점
- 현재 룰은 `person`과 `helmet` 검출을 전제로 한다.
- 새 모델이 `hardhat`, `head`, 다른 언어 라벨을 쓰면 룰 매핑 계층이 필요할 수 있다.
- 단순 박스 겹침 기반이므로, 작은 헬멧 박스나 가림 상황에서 오탐/미탐이 생길 수 있다.
- 사람별 추적 ID가 로그 키에 반영되므로 트래커 안정성도 같이 봐야 한다.

## 위험상황 감지로 확장할 때 고려할 점
- 현재 이벤트 구조는 새 `EventType`과 새 `EventRule`을 추가하기 좋다.
- 다만 복합 이벤트(사람-장비 거리, 쓰러짐, 화재 등)는 단일 프레임 규칙보다 시간 누적 로직이 더 필요할 수 있다.
- 장기 상태 판단이 늘어나면 `EventFilter` 이전 또는 이후에 별도 상태 모듈이 필요할 수 있다.

## ROI 침범 감지로 확장할 때 고려할 점
- 현재 `DangerZoneRule`는 사람 중심점이 ROI 안에 들어오는지만 본다.
- 다각형 ROI, 여러 구역, GUI 상 편집 기능은 아직 확인되지 않았다.
- ROI 변경을 자주 할 계획이면 `config.py` 상수만으로는 한계가 있을 수 있다.

## 실시간 처리 성능 관련 주의사항
- Python 루프는 프레임 단위 동기 처리 구조다.
- 모델 추론, 이벤트 클립 저장, 로그 쓰기가 모두 같은 처리 흐름에 붙어 있다.
- `SAVE_EVENT_CLIP=True`일 때는 프레임 복사와 비디오 쓰기 비용이 추가된다.
- GUI는 200ms polling으로 로그를 다시 읽으므로, 이벤트 수가 많아질수록 파일 크기 영향이 커질 수 있다.
- 정교한 FPS 관리나 백프레셔 처리 로직은 현재 코드에서 별도 확인되지 않았다.

## 현재 구조의 장점과 한계
### 장점
- 구조가 단순하고 학습/발표용으로 설명하기 좋다.
- 모델, 룰, 핸들러 책임 분리가 비교적 명확하다.
- Python과 Flutter를 독립 실행할 수 있다.
- 이벤트 로그와 클립이 남아 사후 검토에 유리하다.

### 한계
- 설정 관리가 `config.py` 중심 정적 상수 방식이다.
- 클래스명 의존성이 강해 모델 교체가 완전 자동화되어 있지 않다.
- 로그 포맷이 텍스트 파싱 기반이라 구조적 변경에 약하다.
- GUI가 `ui_bridge.json`의 모든 필드를 아직 적극 사용하지는 않는 것으로 보인다.

## 추후 발표/포트폴리오에서 강조할 수 있는 설계 포인트
- 추론 엔진과 GUI를 분리한 멀티프로세스 구조
- 모델별 출력을 `DetectionResult`로 표준화한 어댑터 방식
- 룰 기반 이벤트 계층과 상태 필터 계층 분리
- 이벤트 로그와 이벤트 클립을 함께 남기는 사후 분석 친화 설계
- 영상 파일, 스트림, 카메라를 같은 파이프라인으로 다루는 입력 추상화

## 확인 필요
- 이미지 입력 전용 경로 또는 학습/평가 파이프라인 존재 여부
- 다중 모델 비교용 현재 코드 존재 여부
- `ui_bridge.json` 자동 연결 기능을 GUI가 실제 초기화에 사용하도록 설계할 계획 여부

## 멀티소스 확장 메모
- 다중 소스 상태 파일은 `sources_state.json`이며, 각 항목은 `slot_id`, `source_type`, `source_value`, `client_id`, `session_id`를 가질 수 있다.
- Python GUI 모드는 이 목록을 읽고 소스별 worker thread를 띄우는 방향으로 확장되었다.
- 단일 소스 호환을 위해 기존 `source_state.json`과 `ui_bridge.json`도 유지한다.
- 다중 소스 브리지 목록은 `ui_bridges.json`에 source_key별로 기록된다.
- 서버는 `source_key`, `source_type`, `client_id`, `session_id` 기준 이벤트 필터를 지원하고, `GET /api/events/sources`로 소스 요약 목록을 제공한다.
- 현재 Flutter 메인 화면은 여전히 단일 패널 중심이며, 멀티 패널 모니터 월 UI는 후속 리팩터링이 필요하다.
