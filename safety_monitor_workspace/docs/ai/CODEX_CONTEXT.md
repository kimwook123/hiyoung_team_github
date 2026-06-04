# CODEX_CONTEXT.md

## 프로젝트 한 줄 요약

클라이언트가 객체 탐지를 수행하고, 서버가 룰을 적용해 이벤트를 판정하며, 뷰어는 서버 데이터를 조회하는 안전 모니터링 프로젝트입니다.

## 핵심 디렉터리

- `safety_monitor_client/`
  - Flutter 클라이언트
  - 내장 분석 백엔드 포함
- `safety_monitor_server/`
  - FastAPI 서버
  - 중앙 DB, 프리뷰, 이벤트, 클립 관리
- `safety_monitor_viewer/`
  - 서버 조회 전용 Flutter 뷰어

## 먼저 볼 파일

### 클라이언트

- `safety_monitor_client/lib/screens/home_screen.dart`
- `safety_monitor_client/embedded_backend/app/source_manager.py`
- `safety_monitor_client/embedded_backend/app/analysis_runtime.py`
- `safety_monitor_client/embedded_backend/app/reporting_api.py`

### 서버

- `safety_monitor_server/main.py`
- `safety_monitor_server/app/server_event_processor.py`
- `safety_monitor_server/app/database.py`
- `safety_monitor_server/app/routers/sources.py`
- `safety_monitor_server/app/routers/events.py`
- `safety_monitor_server/app/routers/frame_detections.py`
- `safety_monitor_server/app/routers/source_status.py`
- `safety_monitor_server/app/routers/source_streams.py`

### 뷰어

- `safety_monitor_viewer/lib/screens/home_screen.dart`
- `safety_monitor_viewer/lib/services/event_api_service.dart`
- `safety_monitor_viewer/lib/controllers/video_panel_controller.dart`

## 중요한 현재 사실

- 클라이언트가 영상 파일, 카메라, 스트림을 직접 엽니다.
- 클라이언트가 객체 탐지를 수행합니다.
- 서버는 탐지 결과와 소스별 룰 설정을 이용해 이벤트를 판정합니다.
- 뷰어는 서버 프리뷰 스트림과 서버 이벤트만 봅니다.
- 선택된 소스가 있으면 해당 소스 이벤트만, 선택이 없으면 전체 이벤트를 보여줍니다.

## 주의할 점

- `source_key` 규칙을 바꾸면 상태 조회, 이벤트 조회, 프리뷰 조회가 함께 영향을 받습니다.
- 소스 삭제와 룰 변경은 소스를 소유한 클라이언트 기준으로 생각해야 합니다.
- 뷰어는 조회 전용이므로 소스 제어 로직을 넣으면 구조가 흔들립니다.
