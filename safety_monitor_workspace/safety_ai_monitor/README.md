# safety_ai_monitor

Python AI Worker 레이어입니다.

이 폴더는 입력 소스를 분석하고, 이벤트/프레임 탐지/소스 상태/이벤트 클립을 생성해 서버로 전송합니다.

## 역할

- 영상 파일, 스트림, 카메라 입력 분석
- 단일 YOLO 또는 다중 모델 앙상블 추론
- 사람 추적
- 룰 기반 이벤트 생성
- txt 이벤트 로그 유지
- 서버 이벤트 전송
- 서버 프레임 탐지 전송
- 서버 소스 상태 전송
- 이벤트 클립 생성 및 업로드

## 현재 입력/실행 구조

- `INPUT_MODE = "gui"` 일 때 GUI가 작성한 `source_state.json`, `sources_state.json`을 읽습니다.
- 단일 소스 호환 모드와 멀티소스 worker thread 모드를 모두 지원합니다.
- 멀티소스에서는 등록된 소스마다 worker thread를 띄워 병렬 분석합니다.

## 현재 주요 출력

- txt 로그: `logs/*_event_log.txt`
- fallback 이벤트: `logs/events_post_failed.jsonl`
- 재전송 성공/실패 로그
- 이벤트 클립: `logs/clips/*.mp4`
- GUI -> Python 제어 파일:
  - `logs/source_state.json`
  - `logs/sources_state.json`

현재 GUI가 직접 소비하는 핵심 데이터는 로컬 파일이 아니라 서버 API입니다.

## 서버 전송 항목

- `POST /api/events`
- `POST /api/frame-detections`
- `POST /api/source-status`
- `POST /api/clips`

## 모델 구조

### `MODEL_TYPE = "yolo"`

- 단일 YOLO 가중치를 사용합니다.

### `MODEL_TYPE = "yolo_ensemble"`

- 사람 모델과 안전모 모델을 함께 사용합니다.
- 관련 설정:
  - `PERSON_MODEL_PATH`
  - `SAFETY_MODEL_PATH`

현재 기본 구조는:

- 사람 모델 -> `person`
- 안전모 모델 -> `helmet`, `head`

클래스 매핑은 `main.py`, `NoHelmetRule` 구현과 함께 봐야 합니다.

## 관련 설정

파일: `config.py`

주요 항목:

- 입력
  - `INPUT_MODE`
  - `SOURCE_STATE_PATH`
  - `SOURCES_STATE_PATH`
- 모델
  - `MODEL_TYPE`
  - `MODEL_PATH`
  - `PERSON_MODEL_PATH`
  - `SAFETY_MODEL_PATH`
  - `MIN_CONFIDENCE`
- 서버 전송
  - `ENABLE_HTTP_EVENT_POST`
  - `EVENT_POST_URL`
  - `ENABLE_HTTP_FRAME_DETECTION_POST`
  - `FRAME_DETECTION_POST_URL`
  - `ENABLE_HTTP_SOURCE_STATUS_POST`
  - `SOURCE_STATUS_POST_URL`
  - `ENABLE_EVENT_CLIP_UPLOAD`
  - `EVENT_CLIP_UPLOAD_URL`
- 클립
  - `SAVE_EVENT_CLIP`
  - `EVENT_CLIP_DIR`

## 유튜브 링크 입력

- GUI에서 유튜브 링크를 스트림 입력칸에 넣으면 helper가 먼저 로컬 mp4로 변환합니다.
- 이후 Python은 일반 video 입력처럼 그 파일을 분석합니다.
- 이를 위해 `yt-dlp`가 설치되어 있어야 합니다.

## 실행

루트에서:

- `run_python_only.bat`
- `run_python_and_gui.bat`
- `run_python_server_and_gui.bat`

직접 실행:

```powershell
cd safety_ai_monitor
py -3.12 main.py
```

## 관련 문서

- 전체 구조: [../README.md](../README.md)
- 서버 문서: [../safety_monitor_server/README.md](../safety_monitor_server/README.md)
- GUI 문서: [../safety_ai_monitor_ui/README.md](../safety_ai_monitor_ui/README.md)
- 구조 노트: [../docs/ai/ARCHITECTURE_NOTES.md](../docs/ai/ARCHITECTURE_NOTES.md)
