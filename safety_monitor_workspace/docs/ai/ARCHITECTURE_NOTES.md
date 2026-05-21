# ARCHITECTURE_NOTES.md

## 전체 시스템 구조

- 시스템은 `Python AI Worker + FastAPI Server + Flutter GUI`의 3계층 구조입니다.
- Python은 분석 생산자, 서버는 저장소와 조회 API, GUI는 소비자 역할을 맡습니다.
- GUI와 Python은 완전 실시간 IPC를 하지 않고, 입력 소스 선택 상태만 파일로 교환합니다.
- 이벤트, 프레임 탐지, 소스 상태, 클립 메타데이터의 기준 저장소는 서버입니다.

## 현재 데이터 흐름

### 1. GUI -> Python

- `source_state.json`
  - 단일 활성 소스 호환용
- `sources_state.json`
  - 멀티소스 목록 전달용

GUI는 분석할 소스 목록과 현재 활성 소스만 Python에 전달합니다.

### 2. Python -> Server

- `POST /api/events`
- `POST /api/frame-detections`
- `POST /api/source-status`
- `POST /api/clips`

Python은 프레임 추론 결과를 직접 GUI에 전달하지 않고, 서버를 통해 저장합니다.

### 3. GUI -> Server

- `GET /api/events`
- `GET /api/events/latest`
- `GET /api/events/detail`
- `GET /api/frame-detections/current`
- `GET /api/source-status`
- `GET /api/clips/{clip_name}`
- `GET /health`

GUI는 서버 조회만 담당하며, 로컬 이벤트 JSONL이나 프레임 탐지 로그를 직접 읽지 않습니다.

## Python AI Worker의 역할

- 프레임 입력 추상화: `FrameSource`
- 모델 추론 추상화: `DetectionModel`
- 프레임별 탐지 결과 생성: `DetectionResult`
- 사람 추적 ID 부여: `PersonTracker`
- 이벤트 규칙 평가: `EventRule`
- 이벤트 상태 관리: `EventFilter`
- 이벤트 후처리 및 전송: `EventHandler`
- 이벤트 클립 생성: `EventClipRecorder`
- 프레임 탐지 스냅샷 전송: `FrameDetectionRecorder`
- 소스 상태 전송: `SourceStatusPublisher`

## 멀티소스 처리 구조

- `sources_state.json`의 각 항목은 `slot_id`, `source_type`, `source_value`, `client_id`, `session_id`를 가집니다.
- Python GUI 모드는 소스 목록을 읽어 소스별 worker thread를 띄웁니다.
- 등록된 모든 소스는 병렬 분석 대상입니다.
- GUI에서 현재 활성 탭을 바꿔도 Python 분석 대상이 바뀌는 것은 아닙니다.
- GUI의 활성 탭은 “현재 재생/조회 집중 대상”만 뜻합니다.

## Flutter GUI의 역할

- 영상 파일 또는 스트림 등록
- 유튜브 링크 입력 시 로컬 mp4로 변환 후 등록
- 소스 탭 전환
- 비활성 영상 자동 일시정지
- 이벤트 목록/상세 표시
- 현재 재생 시간 기준 객체 탐지 박스 오버레이
- 로그 클릭 시 이벤트 시작 시점으로 이동
- 클립 재생 후 원본 복귀

## 서버 저장 구조

- DB: `safety_monitor_server/data/monitor.db`
- 클립 폴더: `safety_monitor_server/data/clips/`

SQLite 테이블:

- `events`
- `frame_detections`
- `source_status`

서버는 `source_key` 기준으로 데이터를 분리해 조회/초기화합니다.

## 프레임 박스 동기화 방식

- GUI는 현재 영상 시간을 기준으로 서버의 `/api/frame-detections/current`를 조회합니다.
- 서버는 `source_key + source_time_seconds` 기준으로 가장 가까운 프레임 스냅샷을 반환합니다.
- 분석이 아직 그 시점까지 도달하지 않았으면 박스를 표시하지 않을 수 있습니다.
- 이벤트 박스가 아니라 프레임별 전체 탐지 스냅샷을 기준으로 오버레이하므로, 현재 프레임과 더 정확히 맞추는 방향입니다.

## 이벤트와 클립의 관계

- 이벤트는 `START`, `ACTIVE`, `END` 상태로 저장됩니다.
- 클립은 이벤트 `start~end` 구간 기준으로 생성됩니다.
- 이벤트 상세에서 클립이 있으면 서버 클립 URL을 우선 사용합니다.
- 클립 재생 중에도 원본 시간축 기준 박스 계산이 가능하도록 replay base time을 유지합니다.

## 현재 구조의 장점

- Python, 서버, GUI 책임이 분리되어 설명과 확장이 쉽습니다.
- 여러 GUI 클라이언트가 서버를 조회하는 구조로 확장하기 쉽습니다.
- 여러 Python 분석 클라이언트가 같은 서버에 결과를 적재하기 쉽습니다.
- 소스별 `source_key` 기준 분리 덕분에 멀티소스 운용이 단순해졌습니다.

## 현재 구조의 한계

- GUI와 Python의 직접 통신은 아직 파일 기반입니다.
- 영상 재생과 Python 분석은 서로 다른 플레이어/디코더에서 수행되므로 완전한 프레임 동기화는 아닙니다.
- 서버는 SQLite 기반이므로 대규모 동시 writer 환경에서는 한계가 있습니다.
- `build_model()` 분기와 클래스명 매핑은 아직 수동 관리입니다.

## 발표에서 강조하기 좋은 포인트

- 추론, 저장, 시각화를 분리한 3계층 구조
- 이벤트와 프레임 탐지 스냅샷을 분리한 데이터 설계
- 멀티소스 worker thread 구조
- GUI의 멀티소스 탭 UX와 오버레이 동기화
- 이벤트 클립과 원본 복귀 UX
