# CODEX_CONTEXT.md

## 프로젝트 한 줄 요약
Windows 환경에서 Python 객체 탐지 파이프라인과 Flutter GUI를 분리 운영하는 안전 모니터링 프로젝트다.

## 프로젝트 목적
- 영상 파일, 스트림, 카메라 입력을 받아 객체 탐지와 이벤트 판정을 수행한다.
- 탐지 결과를 로그와 이벤트 클립으로 저장하고, Flutter GUI에서 재생과 확인이 가능하도록 한다.
- 모델 교체, 위험 규칙 추가, 발표/포트폴리오용 확장 설명이 가능한 구조를 지향한다.

## 사용 언어와 기술 스택
- Python 3.12
- Flutter/Dart 3.x
- OpenCV (`opencv-python`)
- NumPy
- Ultralytics YOLO
- Flutter `media_kit`, `media_kit_video`, `file_selector`
- Windows 배치 스크립트 기반 실행

## 전체 디렉터리 구조 요약
- `safety_ai_monitor/`: Python 추론 파이프라인 본체. 모델 로드, 프레임 입력, 룰 판정, 로그/클립 저장을 담당한다.
- `safety_ai_monitor/core/`: 백엔드 공통 구조. `VideoPipeline`, `DetectionModel`, `FrameSource`, `EventFilter`, `UiBridgeWriter` 같은 핵심 인터페이스와 흐름이 있다.
- `safety_ai_monitor/models/`: 모델 어댑터 구현. 현재 `dummy`, `yolo` 구현이 있다.
- `safety_ai_monitor/rules/`: 탐지 결과를 이벤트로 바꾸는 규칙 계층. 현재 안전모 미착용, 위험구역 진입 룰이 있다.
- `safety_ai_monitor/handlers/`: 이벤트 후처리 계층. 현재 콘솔 출력과 로그 파일 저장 핸들러가 있다.
- `safety_ai_monitor/logs/`: Python-UI 브리지 파일, 입력 상태 파일, 이벤트 로그, 이벤트 클립 저장 위치다.
- `safety_ai_monitor_ui/`: Flutter GUI 프로젝트. 영상 재생, 로그 표시, 이벤트 선택/오버레이를 담당한다.
- 루트 배치 파일들: Python과 GUI 실행 흐름을 Windows에서 쉽게 시작하기 위한 진입점이다.

## Python 쪽 역할
- 입력 소스 열기: 카메라, 영상 파일, 스트림
- 객체 탐지 모델 로드 및 프레임별 추론
- `person` 객체 중심 추적 ID 부여
- 룰 기반 이벤트 생성
- 이벤트 시작/유지/종료 상태 관리
- 이벤트 로그 텍스트 저장
- 이벤트별 클립 저장
- GUI가 읽을 `ui_bridge.json` 기록

## Flutter 쪽 역할
- 영상 파일 선택 또는 스트림 주소 입력
- Python이 읽는 `source_state.json` 갱신
- 동일 입력에 대응되는 로그 파일 경로 계산 및 감시
- 영상/스트림 재생
- 로그 목록 표시
- 현재 프레임에 해당하는 이벤트 오버레이 표시
- 스트림 이벤트 클릭 시 저장된 클립 재생 후 라이브 복귀

## Python과 Flutter의 연결 방식
- 현재 확인된 연결 방식은 파일 입출력 기반이다.
- Flutter는 `source_state.json`에 `source_type`, `source_value`를 기록한다.
- Python은 `SourceStateReader`로 이 파일을 읽고, 변경되면 파이프라인을 재시작한다.
- Python은 현재 분석 대상과 로그 위치를 `ui_bridge.json`에 기록한다.
- Flutter는 `ui_bridge.json` 또는 동일 `logs` 디렉터리 규칙을 바탕으로 로그 파일 위치를 찾는다.
- Flutter는 이벤트 로그 텍스트 파일을 200ms 주기로 다시 읽는다.

## 객체 탐지 실행 흐름
1. `safety_ai_monitor/main.py`가 `config.py` 값을 읽는다.
2. `build_pipeline()`이 입력 소스, 모델, 룰, 핸들러, 추적기, 이벤트 필터, 클립 레코더를 조립한다.
3. `VideoPipeline.run()`이 프레임 소스를 열고 모델을 로드한다.
4. 프레임마다 `model.predict()`가 `DetectionResult`를 반환한다.
5. `PersonTracker`가 `person` 탐지에만 `track_id`를 부여한다.
6. 룰이 `DetectionResult`를 받아 `Event` 목록을 만든다.
7. `EventFilter`가 `START/ACTIVE/END` 상태를 관리한다.
8. `LogEventHandler`와 `ConsoleEventHandler`가 이벤트를 기록한다.
9. `EventClipRecorder`가 활성 이벤트 기준으로 MP4 클립을 저장한다.
10. GUI는 로그와 클립 파일을 읽어 표시한다.

## 모델 로드 방식
- `main.py`의 `build_model()`이 `MODEL_TYPE`으로 분기한다.
- 현재 확인된 구현체는 `DummyDetectionModel`, `YoloModelSample` 두 개다.
- YOLO는 `models/yolo_model_sample.py`에서 `ultralytics.YOLO`로 가중치를 로드한다.
- YOLO 설정 디렉터리는 프로젝트 내부 `.yolo_config`로 고정한다.
- 모델 출력은 반드시 `DetectionResult` 공통 형식으로 변환된다.

## 입력 데이터 흐름
- GUI 모드:
  - Flutter가 영상 파일 또는 스트림 주소를 선택한다.
  - Flutter가 `safety_ai_monitor/logs/source_state.json`을 쓴다.
  - Python이 이를 읽어 `VideoFileFrameSource` 또는 `StreamFrameSource`를 생성한다.
- 카메라 모드:
  - `config.py`의 `INPUT_MODE="camera"`와 `CAMERA_INDEX`를 사용한다.
- 프레임은 OpenCV `VideoCapture`를 통해 읽힌다.

## 출력 데이터 흐름
- 탐지 결과는 메모리 내 `DetectionResult`와 `Event`로 처리된다.
- 이벤트 상태는 텍스트 로그 한 줄 형식으로 누적 저장된다.
- 활성 이벤트는 필요 시 MP4 클립으로 저장된다.
- 현재 입력 정보와 로그 경로는 `ui_bridge.json`으로 저장된다.
- Flutter는 로그 파일을 파싱해 목록과 오버레이를 구성한다.

## 현재 지원하는 입력 형식
- 카메라 인덱스 입력
- 로컬 영상 파일: 코드상 파일 선택 확장자는 `mp4`, `mov`, `avi`, `mkv`
- 스트림 주소: 코드상 RTSP/HTTP 등 `media_kit`/OpenCV가 열 수 있는 URL 문자열
- 단일 이미지 입력: 확인 필요

## 현재 지원하는 출력 형식
- 이벤트 로그 텍스트: `*_event_log.txt`, `stream_event_log.txt`, `event_log.txt`
- 이벤트 클립 MP4: `logs/clips/*.mp4`
- 브리지 JSON: `logs/ui_bridge.json`
- 입력 상태 JSON: `logs/source_state.json`
- 화면 표시용 OpenCV 창: `SHOW_SCREEN=True`일 때만 사용

## 모델 교체 가능성
- 모델 교체용 최소 인터페이스는 이미 있다. 기준은 `core/detection_model.py`의 `DetectionModel`이다.
- 새 모델은 `load()`, `predict()`, `get_name()`을 구현해야 한다.
- 실제 교체는 자동 플러그인 구조가 아니라 `main.py`의 `build_model()` 분기 추가 방식이다.
- 룰은 클래스 이름 문자열(`person`, `helmet`)에 의존하므로, 모델 교체 시 룰 호환성 검증이 필수다.

## 주요 설정값 위치
- `safety_ai_monitor/config.py`
  - 입력 방식, 카메라 번호
  - 모델 종류, 가중치 경로, confidence
  - 룰 사용 여부
  - ROI 좌표
  - 이벤트 쿨다운, 추적 파라미터
  - 로그/브리지/클립 경로
- `safety_ai_monitor/main.py`
  - 모델 구현체 선택
  - 룰/핸들러 조립
  - 입력별 로그 파일명 결정
- `safety_ai_monitor_ui/lib/services/app_link_service.dart`
  - Flutter 쪽 로그 경로 계산 규칙
  - `source_state.json` 위치 결정 규칙

## 자주 수정될 가능성이 높은 파일 목록
- `safety_ai_monitor/config.py`
  - 실험 시 모델 경로, threshold, 룰 on/off, ROI를 가장 자주 바꿀 가능성이 높다.
- `safety_ai_monitor/main.py`
  - 새 모델 추가, 룰 추가, 핸들러 추가 시 실제 조립 지점이라 중요하다.
- `safety_ai_monitor/models/yolo_model_sample.py`
  - YOLO 계열 교체나 출력 포맷 조정 시 직접 수정될 가능성이 높다.
- `safety_ai_monitor/rules/no_helmet_rule.py`
  - 현재 클래스명 의존성이 강해 모델 변경 시 자주 손볼 가능성이 높다.
- `safety_ai_monitor/rules/danger_zone_rule.py`
  - ROI 이벤트 확장 시 수정 가능성이 높다.
- `safety_ai_monitor_ui/lib/screens/home_screen.dart`
  - 파일 선택, 스트림 열기, 로그 연결 흐름이 모여 있어 GUI 동선 변경 시 중요하다.
- `safety_ai_monitor_ui/lib/services/app_link_service.dart`
  - Python-Flutter 파일 연동 규칙이 모여 있어 경로 규약 변경 시 핵심이다.
- `safety_ai_monitor_ui/lib/services/event_log_service.dart`
  - 로그 형식이 바뀌면 가장 먼저 영향 받는다.
- `safety_ai_monitor_ui/lib/models/event_log_item.dart`
  - Python 로그 한 줄 포맷을 Dart 객체로 파싱하는 핵심 파일이다.

## 새 작업을 시작할 때 AI가 먼저 확인해야 하는 파일 기준
- 실행 흐름을 건드리는 작업:
  - `safety_ai_monitor/main.py`, `safety_ai_monitor/core/pipeline.py`
  - 이유: 실제 조립 순서와 프레임 처리 순서를 알아야 부작용을 줄일 수 있다.
- 설정값을 건드리는 작업:
  - `safety_ai_monitor/config.py`
  - 이유: 경로, 모델, threshold가 여기서 관리된다.
- 모델 교체/추가 작업:
  - `safety_ai_monitor/core/detection_model.py`, `safety_ai_monitor/models/*.py`, `safety_ai_monitor/main.py`
  - 이유: 공통 출력 형식과 분기 지점을 먼저 맞춰야 한다.
- 이벤트/룰 작업:
  - `safety_ai_monitor/rules/*.py`, `safety_ai_monitor/core/event_filter.py`, `safety_ai_monitor/core/event_rule.py`
  - 이유: 이벤트 생성과 상태 관리가 분리되어 있다.
- GUI 연동 작업:
  - `safety_ai_monitor/core/ui_bridge.py`, `safety_ai_monitor_ui/lib/services/app_link_service.dart`, `safety_ai_monitor_ui/lib/services/event_log_service.dart`
  - 이유: 파일 기반 통신의 양쪽 규약을 함께 확인해야 한다.
- GUI 표시 작업:
  - `safety_ai_monitor_ui/lib/screens/home_screen.dart`, `lib/controllers/*.dart`, `lib/widgets/*.dart`
  - 이유: 화면 조립, 상태 흐름, 표시 방식이 나뉘어 있다.

## 현재 확인된 중요한 사실
- 기본 `INPUT_MODE`는 `gui`, 기본 `MODEL_TYPE`은 `yolo`다.
- 기본 가중치 경로는 `safety_ai_monitor/models/weights/best.pt`다.
- 현재 저장소에는 `safety_ai_monitor/logs/ui_bridge.json`, `source_state.json`, `test_event_log.txt` 예시가 존재한다.
- `ui_bridge.json` 예시에는 `source_type`, `source_value`, `log_path`, `model_type`, `source_fps`가 기록되어 있다.
- 현재 GUI 초기화 시 `clearSourceState()`를 호출해 이전 선택 상태를 비운다.
- `AppLinkService.readDefaultLink()`와 `AppLinkInfo`는 존재하지만, 현재 `HomeScreen`에서 실제 사용되는 코드는 확인되지 않았다.

## 확인 필요
- 단일 이미지 추론 입력 지원 여부
- ONNX 또는 Ultralytics 외 다른 추론 백엔드 지원 여부
- Flutter가 `ui_bridge.json`을 읽어 자동 복구/자동 연결하는 흐름이 현재 UI에서 실제 사용 중인지 여부
- 발표용 산출물이나 학습 파이프라인(`train.py` 등) 존재 여부
