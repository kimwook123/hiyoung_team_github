# CODEX_CONTEXT.md

## 프로젝트 한 줄 요약

서버가 분석 worker를 직접 관리하고, Flutter GUI가 서버 API만 조회하는 안전 모니터링 프로젝트입니다.

## 핵심 디렉터리

- `safety_monitor_server/`
  - FastAPI 서버와 분석 worker 관리
  - 내부 분석 패키지: `app/analysis/`
- `safety_ai_monitor_ui/`
  - GUI 클라이언트

## 먼저 볼 파일

### 서버

- `safety_monitor_server/main.py`
- `safety_monitor_server/app/source_manager.py`
- `safety_monitor_server/app/analysis_runtime.py`
- `safety_monitor_server/app/analysis/`
- `safety_monitor_server/app/database.py`
- `safety_monitor_server/app/routers/sources.py`
- `safety_monitor_server/app/routers/events.py`
- `safety_monitor_server/app/routers/frame_detections.py`
- `safety_monitor_server/app/routers/source_status.py`

### GUI

- `safety_ai_monitor_ui/lib/screens/home_screen.dart`
- `safety_ai_monitor_ui/lib/services/event_api_service.dart`
- `safety_ai_monitor_ui/lib/controllers/video_panel_controller.dart`

## 중요한 현재 사실

- GUI는 `source_state.json`, `sources_state.json`, `ui_bridge.json`을 더 이상 사용하지 않습니다.
- 소스 등록은 `POST /api/sources`로 합니다.
- 분석 start/stop/restart도 서버 API 기준입니다.
- 이벤트 로그는 현재 선택된 소스가 있으면 그 소스만, 선택이 없으면 전체를 보여줍니다.
- 프레임 박스는 `/api/frame-detections/current` 또는 `/latest` 기준입니다.

## 분석 관련 사실

- `yolo_ensemble`가 기본 구조입니다.
- 사람 모델 + 안전모 모델 2개를 함께 씁니다.
- 현재 주요 병목은 대체로 `model_predict`입니다.
- `ANALYSIS_TARGET_FPS = 10.0`
- `MODEL_INPUT_MAX_WIDTH = 1024`

## 주의할 점

- 서버는 `app.*` import 구조라 `safety_monitor_server` 폴더 기준으로 실행하는 흐름을 유지합니다.
- `source_key` 정규화 규칙을 바꾸면 이벤트 필터, 상태 조회, 박스 조회가 함께 흔들립니다.
- GUI는 서버 분석과 별개로 영상을 로컬 재생하므로, seek/재생 시간과 서버 스냅샷 정합성은 늘 같이 봐야 합니다.
