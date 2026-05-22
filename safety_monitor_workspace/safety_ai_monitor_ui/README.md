# Safety AI Monitor UI

Flutter 기반 GUI 클라이언트입니다.

## 역할

- 영상 파일 열기
- 스트림 등록
- 소스 선택/선택 해제
- 이벤트 로그 조회
- 이벤트 상세 조회
- 클립 재생
- 원본 복귀
- 현재 재생 시간 기준 객체 탐지 박스 오버레이

## 현재 연결 방식

### GUI -> Server

- 소스 등록
- 소스 start/stop/restart 요청
- 소스 삭제
- 이벤트 목록/상세 조회
- 프레임 탐지 조회
- 소스 상태 조회
- 클립 조회

GUI는 더 이상 Python worker 제어 파일이나 로컬 브리지 파일을 쓰지 않습니다.
다른 PC 서버를 쓸 때는 GUI 상단 `서버 주소` 입력으로 API base URL을 바꿉니다.

## UX 원칙

- 현재 선택된 소스가 있으면 그 소스의 이벤트 로그만 표시
- 소스를 선택하지 않으면 전체 이벤트 로그 표시
- 로그 클릭 시 해당 이벤트 시작 시점으로 이동
- 클립 재생 중 다른 소스 전환 시 이전 클립 컨텍스트 제거
- 비활성 영상은 자동 pause

## 주요 서버 API 사용

- `POST /api/sources`
- `POST /api/sources/{source_key}/start`
- `POST /api/sources/{source_key}/stop`
- `POST /api/sources/{source_key}/restart`
- `DELETE /api/sources/{source_key}`
- `GET /api/events`
- `GET /api/events/detail`
- `GET /api/frame-detections/current`
- `GET /api/frame-detections/latest`
- `GET /api/source-status`
- `GET /api/clips/{clip_name}`

## 주요 파일

- `lib/screens/home_screen.dart`
  - 소스 등록/전환/이벤트 UX 조립
- `lib/controllers/video_panel_controller.dart`
  - 영상 재생, replay, 복귀, pause 제어
- `lib/services/event_api_service.dart`
  - 서버 HTTP API 호출
- `lib/widgets/video_view_box.dart`
  - 오버레이 박스 렌더링
- `lib/widgets/file_bar.dart`
  - 상단 소스 입력/제어 UI
