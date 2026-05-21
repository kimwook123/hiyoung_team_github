# AI_TASK_LOG.md

## 2026-05-21 - 서버 중심 멀티소스 구조 정리

### Completed

- Flutter GUI의 파일 로그 모드를 제거하고 서버 조회 중심 구조로 정리
- Python -> Server로 이벤트, 프레임 탐지 스냅샷, 소스 상태, 클립 업로드 흐름 추가
- FastAPI 서버 저장소를 JSONL 중심에서 SQLite 중심으로 전환
- GUI 멀티소스 탭 전환 UX 추가
- 활성 탭 전환 시 비활성 영상 자동 일시정지
- 이벤트 로그 클릭 시 원본 영상의 이벤트 시작 시점 이동
- 이벤트 클립 재생 후 원본 복귀 UX 보강
- 이벤트 클립을 start~end 구간 기준으로 저장
- 유튜브 링크를 스트림 입력칸에 넣었을 때 로컬 mp4로 변환 후 재생/분석하도록 추가
- 안전모 감지를 위해 사람 모델 + 안전모 모델 2개를 함께 쓰는 `yolo_ensemble` 추가
- Python 멀티소스 모드가 실행 중 동적으로 활성화되도록 전환 로직 수정

### Changed Files

- Python
  - `safety_ai_monitor/main.py`
  - `safety_ai_monitor/config.py`
  - `safety_ai_monitor/core/pipeline.py`
  - `safety_ai_monitor/core/frame_detection_recorder.py`
  - `safety_ai_monitor/core/source_status_publisher.py`
  - `safety_ai_monitor/core/event_clip_recorder.py`
  - `safety_ai_monitor/models/ensemble_yolo_model.py`
- Server
  - `safety_monitor_server/app/database.py`
  - `safety_monitor_server/app/routers/events.py`
  - `safety_monitor_server/app/routers/frame_detections.py`
  - `safety_monitor_server/app/routers/source_status.py`
  - `safety_monitor_server/app/routers/admin.py`
- GUI
  - `safety_ai_monitor_ui/lib/screens/home_screen.dart`
  - `safety_ai_monitor_ui/lib/controllers/video_panel_controller.dart`
  - `safety_ai_monitor_ui/lib/services/event_api_service.dart`
  - `safety_ai_monitor_ui/lib/widgets/video_view_box.dart`
  - `safety_ai_monitor_ui/lib/widgets/file_bar.dart`

### Important Notes

- 현재 GUI는 영상 자체는 로컬에서 재생하고, 박스와 이벤트는 서버에서 조회합니다.
- Python은 등록된 모든 소스를 병렬 분석해야 하며, GUI의 활성 소스는 분석 대상 제한이 아니라 화면 전환 의미입니다.
- 서버는 `data/monitor.db`와 `data/clips/`를 기준 저장소로 사용합니다.
- `source_key`는 reset, 이벤트 필터링, 프레임 탐지 조회의 핵심 키입니다.

### Current Issue

- 실제 장비 성능에 따라 멀티소스 병렬 분석 성능 저하 가능성은 여전히 검증 필요
- SQLite 기반 구조는 현재 규모에는 적합하지만 대규모 writer 환경에서는 한계가 있을 수 있음

### Next Task

- 멀티클라이언트/멀티소스 실사용 시나리오 기준 검증 보강
- 성능 병목 지점 측정과 표시
- 서버 인증/권한 분리 필요성 검토
