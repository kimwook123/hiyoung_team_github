# docs

프로젝트 문서 모음입니다.

## 현재 구조 요약

- 서버가 분석 worker를 직접 관리합니다.
- GUI는 서버 API만 사용합니다.
- 분석 코어는 `safety_monitor_server/app/analysis/` 내부 패키지입니다.

## 추천 읽는 순서

- 전체 구조: [../README.md](../README.md)
- 서버 설계 메모: [ai/ARCHITECTURE_NOTES.md](./ai/ARCHITECTURE_NOTES.md)
- 개발 컨텍스트: [ai/CODEX_CONTEXT.md](./ai/CODEX_CONTEXT.md)
- 이벤트 JSON 계약: [ai/event_json_schema.md](./ai/event_json_schema.md)
- 발표/시연 체크: [demo_checklist.md](./demo_checklist.md)
