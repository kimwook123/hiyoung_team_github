# AI_TODO.md

## Short-term

- [ ] 서버 시작 시 기존 `sources` 중 미완료 파일 영상 복구와 스트림/CCTV 재시도 흐름을 실제 시나리오로 검증
- [ ] 멀티소스 동시 분석 시 처리량과 지연을 다시 측정
- [ ] 이벤트/클립/프레임 탐지 정리 정책 보강
- [ ] `run_gui_only.bat`의 Flutter/VS/SDK 자동 설치 시나리오를 새 PC에서 실제 검증

## Mid-term

- [ ] source별 권한/소유권 정책이 필요한지 검토
- [ ] 서버 source 목록과 GUI 로컬 슬롯 복구 UX를 연결할지 검토
- [ ] 서버 IP 자동 발견 또는 고정 호스트명 전략 검토

## Long-term

- [ ] SQLite에서 PostgreSQL 등 서버형 DB 전환 검토
- [ ] WebSocket/SSE push 기반 UI 갱신 구조 검토
- [ ] 멀티 GUI 클라이언트 인증/권한 구조 설계
