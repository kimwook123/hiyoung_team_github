# docs

프로젝트 문서 모음입니다.

## 추천 읽는 순서

- 빠르게 실행 흐름을 보려면: [../README.md](../README.md)
- 현재 전체 구조를 이해하려면: [ai/ARCHITECTURE_NOTES.md](./ai/ARCHITECTURE_NOTES.md)
- 개발 시작 포인트를 보려면: [ai/CODEX_CONTEXT.md](./ai/CODEX_CONTEXT.md)
- 이벤트 JSON 계약을 보려면: [ai/event_json_schema.md](./ai/event_json_schema.md)
- 발표 전 확인 항목은: [demo_checklist.md](./demo_checklist.md)

## 현재 문서 기준 구조

- Python AI Worker는 입력 소스를 분석하고 결과를 서버로 전송합니다.
- FastAPI 서버는 SQLite DB와 클립 파일 저장소를 소유합니다.
- Flutter GUI는 서버 조회 전용 클라이언트로 동작합니다.
- GUI와 Python 사이의 직접 연결은 소스 선택 상태 파일 전달에만 남아 있습니다.

## 문서 역할 구분

- 루트 `README.md`
  - 전체 실행 흐름과 현재 구조 요약
- `safety_ai_monitor/README.md`
  - Python AI Worker의 설정, 입력, 전송, 멀티소스 분석 구조
- `safety_monitor_server/README.md`
  - FastAPI API, SQLite 저장소, 클립 저장소
- `safety_ai_monitor_ui/README.md`
  - 멀티소스 GUI, 서버 조회 흐름, 오버레이/클립 UX
- `docs/ai/ARCHITECTURE_NOTES.md`
  - 설계 메모와 구조적 판단 근거
- `docs/ai/CODEX_CONTEXT.md`
  - 개발 작업 시작 시 참고할 최신 컨텍스트
- `docs/ai/AI_TASK_LOG.md`
  - 주요 작업 이력
- `docs/ai/AI_TODO.md`
  - 남은 검토 항목
