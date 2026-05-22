# Demo Checklist

## 1. 사전 확인

- [ ] Python 3.12 사용 가능 여부 확인
- [ ] Flutter SDK 경로 확인
- [ ] `safety_monitor_server/requirements.txt` 설치 여부 확인
- [ ] 테스트 영상 파일 준비 여부 확인
- [ ] `safety_monitor_server/app/analysis/models/weights/` 가중치 파일 존재 여부 확인

## 2. 서버 실행

- [ ] `run_server.bat` 실행
- [ ] `http://127.0.0.1:8000/health` 응답 확인
- [ ] `GET /api/sources` 응답 확인

## 3. GUI 실행

- [ ] `run_gui_only.bat` 실행
- [ ] 영상 파일 선택 가능 여부 확인
- [ ] 스트림 등록 가능 여부 확인
- [ ] 선택된 소스 로그만 표시되는지 확인
- [ ] 선택 해제 시 전체 로그가 보이는지 확인

## 4. 분석 흐름

- [ ] 소스 등록 후 서버 `source_status`가 `starting -> running`으로 바뀌는지 확인
- [ ] 이벤트가 `events`에 저장되는지 확인
- [ ] 프레임 탐지 스냅샷이 저장되는지 확인
- [ ] 클립이 `data/clips/`에 생성되는지 확인

## 5. GUI 상호작용

- [ ] 이벤트 클릭 시 시작 시점으로 이동하는지 확인
- [ ] 클립 열기 후 원본 복귀 가능한지 확인
- [ ] 다른 소스 전환 시 이전 영상이 pause되는지 확인
- [ ] 객체 탐지 박스가 현재 재생 시간 기준으로 갱신되는지 확인

## 6. 멀티소스

- [ ] 소스 2개 이상 등록 시 둘 다 서버 상태가 갱신되는지 확인
- [ ] 활성 소스를 바꿔도 다른 소스 분석이 계속되는지 확인
- [ ] 소스 삭제 시 해당 소스 worker만 멈추는지 확인
