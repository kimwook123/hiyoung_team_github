# AI_TASK_LOG.md

## Initial Project Handoff

### Current State
- Python 백엔드와 Flutter GUI가 분리된 Windows 프로젝트로 구성되어 있다.
- 기본 실행 모드는 `INPUT_MODE="gui"`, `MODEL_TYPE="yolo"`다.
- Python은 파일 기반으로 입력 상태를 받고 이벤트 로그와 클립을 저장한다.
- Flutter는 영상/스트림 재생과 로그 시각화를 담당한다.
- 저장소에는 `test.mp4`와 이에 대응하는 로그/브리지 예시 파일이 존재한다.

### Confirmed Architecture
- 백엔드 진입점은 `safety_ai_monitor/main.py`다.
- 핵심 파이프라인은 `core/pipeline.py`의 `VideoPipeline`이다.
- 모델 계층은 `core/detection_model.py` 인터페이스를 통해 `models/dummy_model.py`, `models/yolo_model_sample.py`로 구현되어 있다.
- 이벤트 생성은 `rules/*.py`, 이벤트 상태 관리는 `core/event_filter.py`, 후처리는 `handlers/*.py`로 분리되어 있다.
- Python과 Flutter는 `safety_ai_monitor/logs/` 아래 JSON/TXT/MP4 파일을 통해 통신한다.
- Flutter 진입점은 `safety_ai_monitor_ui/lib/main.dart`, 화면 조립은 `lib/screens/home_screen.dart`다.

### Important Existing Features
- 로컬 영상 파일 선택 후 분석 로그 연동
- 스트림 주소 입력 후 분석 로그 연동
- 카메라 입력 지원 코드 존재
- YOLO 가중치 로드 및 공통 검출 포맷 변환
- `person` 대상 간단 추적 ID 부여
- `NO_HELMET`, `DANGER_ZONE` 이벤트 규칙 구조
- 이벤트 START/ACTIVE/END 상태 관리
- 이벤트 로그 텍스트 저장
- 이벤트 클립 MP4 저장
- Flutter 오버레이 및 이벤트 목록 클릭 이동
- 스트림 이벤트의 replay clip 재생 후 라이브 복귀

### Known Risk Areas
- `NoHelmetRule`은 `person`, `helmet` 클래스명에 직접 의존하므로 모델 교체 시 의미가 쉽게 깨질 수 있다.
- `LogEventHandler`의 한 줄 포맷은 Flutter `EventLogItem.fromLine()` 파서와 강하게 결합되어 있다.
- `source_state.json`, `ui_bridge.json` 경로 규약은 Python/Flutter 양쪽에서 함께 맞아야 한다.
- `PersonTracker`는 `person` 클래스만 추적하므로 클래스명 변경 또는 다중 객체 이벤트 확장 시 영향이 있다.
- 현재 `best.pt` 파일은 Git 상태상 수정된 것으로 보이며, 문서 작업 외 변경과 충돌하지 않게 주의해야 한다.

### Suggested Next Documentation Updates
- 실제 기능 변경 후 이 파일에 작업 날짜, 변경 파일, 영향 범위를 기록한다.
- 모델 교체나 룰 수정이 있었다면 “기대 클래스명”과 “검증한 샘플 입력”을 함께 남긴다.
- 로그 포맷이나 브리지 파일 구조가 바뀌면 Flutter 영향과 호환성 메모를 추가한다.
- 발표용 기능 추가 시 사용자 시나리오와 데모 흐름을 함께 요약한다.

### Handoff Template

## YYYY-MM-DD - Task Name

### Completed
- 

### Changed Files
- 

### Important Notes
- 

### Current Issue
- 

### Next Task
- 

