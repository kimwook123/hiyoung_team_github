# AI_TODO.md

## Short-term

- [ ] 서버 시작 시 기존 `sources` 중 `desired_running=true` 복구 흐름을 실제 시나리오로 검증
- [ ] 멀티소스 동시 분석 시 처리량과 지연을 다시 측정
- [ ] 이벤트/클립/프레임 탐지 정리 정책 보강

## Mid-term

- [ ] source별 권한/소유권 정책이 필요한지 검토
- [ ] 서버 source 목록과 GUI 로컬 슬롯 복구 UX를 연결할지 검토

## Long-term

- [ ] SQLite에서 PostgreSQL 등 서버형 DB 전환 검토
- [ ] WebSocket/SSE push 기반 UI 갱신 구조 검토
- [ ] 멀티 GUI 클라이언트 인증/권한 구조 설계
