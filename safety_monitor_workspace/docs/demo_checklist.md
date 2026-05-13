# Demo Checklist

## 1. 공통 사전 확인
- [ ] Python 3.12 사용 가능 여부 확인
- [ ] Flutter SDK 경로 확인
- [ ] 필요한 requirements 설치 여부 확인
- [ ] 테스트 영상 파일 준비 여부 확인
- [ ] `safety_ai_monitor/models/weights/best.pt` 존재 여부 확인

## 2. 안정 시연 체크리스트

목적:
- 서버 없이 기존 파일 기반 흐름 확인

확인 항목:
- [ ] `run_python_and_gui.bat` 실행
- [ ] Flutter GUI 실행 여부 확인
- [ ] 영상 파일 선택 가능 여부 확인
- [ ] 이벤트 로그 표시 여부 확인
- [ ] 이벤트 클릭 시 영상 위치 이동 여부 확인
- [ ] `clipPath`가 있는 이벤트의 클립 재생 여부 확인
- [ ] `logs/<영상명>_event_log.txt` 생성 여부 확인

## 3. 서버-클라이언트 분리 시연 체크리스트

목적:
- Python AI Worker -> FastAPI Server -> Flutter GUI 흐름 확인

확인 항목:
- [ ] `safety_ai_monitor/config.py`에서 `ENABLE_HTTP_EVENT_POST = True` 설정 확인
- [ ] `run_server.bat` 실행
- [ ] `http://127.0.0.1:8000/health` 응답 확인
- [ ] Python AI Worker 실행
- [ ] `POST /api/events`로 이벤트가 들어오는지 확인
- [ ] `logs/events.jsonl` 생성 또는 갱신 여부 확인
- [ ] Flutter GUI에서 API 서버 모드 선택
- [ ] API 서버 상태 확인 버튼 동작 확인
- [ ] API 새로고침 버튼 동작 확인
- [ ] 이벤트 상세 패널 표시 확인
- [ ] `relatedDetections` 표시 확인
- [ ] `clipPath`가 있는 경우 클립 열기 동작 확인

## 4. 장애 대응 체크리스트

목적:
- 서버 전송 실패 fallback과 재전송 흐름 확인

확인 항목:
- [ ] 서버가 꺼진 상태에서 서버 전송 모드 실행 시 실패 이벤트가 `events_post_failed.jsonl`에 기록될 수 있는지 확인
- [ ] 서버 재실행 후 `run_repost_failed_events.bat` 실행
- [ ] `events_post_reposted_success.jsonl` 생성 여부 확인
- [ ] `events_post_repost_failed.jsonl` 생성 여부 확인
- [ ] 원본 `events_post_failed.jsonl`이 삭제되지 않는지 확인

## 5. 발표 때 말할 핵심 한 줄
- [ ] Python AI Worker는 이벤트를 생성한다.
- [ ] FastAPI Server는 이벤트를 저장하고 API로 제공한다.
- [ ] Flutter GUI는 파일 로그 모드와 API 서버 모드를 모두 지원한다.
- [ ] 현재 저장소는 파일 기반 프로토타입이며, 추후 DB/WebSocket 구조로 확장 가능하다.
