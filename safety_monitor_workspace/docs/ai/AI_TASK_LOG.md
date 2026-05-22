# AI_TASK_LOG.md

## 2026-05-22 - 서버/클라이언트 2계층 리팩터링

### Completed

- 서버가 분석 worker를 직접 관리하는 구조로 전환
- `POST /api/sources` 기반 소스 등록 API 추가
- `POST /api/sources/upload` 기반 로컬 영상 업로드 등록 추가
- 분석 결과 저장을 서버 내부 DB/클립 디렉터리 직접 저장으로 전환
- 분석 코어/모델/룰을 `safety_monitor_server/app/analysis/` 아래로 흡수
- GUI의 파일 기반 Python 브리지 제거
- GUI 소스 등록/삭제를 서버 API 기준으로 전환
- 독립 Python worker 실행 스크립트 제거
- 문서를 서버 중심 구조 기준으로 최신화
- 서버 등록 소스 다시 열기, 진행도 표시, 서버 단독 분석 재개 흐름 추가
- `run_server.bat` / `run_gui_only.bat` 자동 의존성 검사 및 설치 흐름 추가

### Cleaned Up

- `safety_ai_monitor/main.py`
- `safety_ai_monitor/config.py`
- `safety_ai_monitor/core/ui_bridge.py`
- `safety_ai_monitor/tools/resolve_media_source.py`
- GUI의 `app_link_service.dart`
- GUI의 `input_source_resolver_service.dart`
- GUI의 로컬 이벤트 JSON 서비스/컨트롤러

### Current Note

- 현재 기준 분석 실행은 `safety_monitor_server` 내부에서만 이뤄집니다.
- 남은 작업은 주로 운영 검증, 원격 배포 검증, 네트워크 자동 발견 여부 검토 쪽입니다.
