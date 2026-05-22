# Safety AI Monitor UI

Flutter 기반 GUI 클라이언트입니다.

## 역할

- 영상 파일 열기
- 스트림 등록
- 서버 등록 소스 다시 열기
- 소스 선택/선택 해제
- 이벤트 로그 조회
- 이벤트 상세 조회
- 클립 재생
- 원본 복귀
- 현재 재생 시간 기준 객체 탐지 박스 오버레이

## 현재 연결 방식

### GUI -> Server

- 영상 파일 업로드 기반 소스 등록
- 스트림 소스 등록
- 소스 삭제
- 이벤트 목록/상세 조회
- 프레임 탐지 조회
- 소스 상태 조회
- 클립 조회
- 서버 저장 영상 조회

GUI는 더 이상 Python worker 제어 파일이나 로컬 브리지 파일을 쓰지 않습니다.
다른 PC 서버를 쓸 때는 GUI 상단 `서버 주소` 입력이나 `run_gui_only.bat` 초기 입력으로 API base URL을 맞춥니다.

## UX 원칙

- 현재 선택된 소스가 있으면 그 소스의 이벤트 로그만 표시
- 소스를 선택하지 않으면 전체 이벤트 로그 표시
- 로그 클릭 시 해당 이벤트 시작 시점으로 이동
- 클립 재생 중 다른 소스 전환 시 이전 클립 컨텍스트 제거
- 비활성 영상은 자동 pause
- 서버 등록 소스 목록에서 현재 상태와 진행도를 확인 가능
- 서버 등록 소스는 `화면에 열기`로 다시 복원 가능

## 주요 서버 API 사용

- `POST /api/sources`
- `POST /api/sources/upload`
- `DELETE /api/sources/{source_key}`
- `GET /api/events`
- `GET /api/events/detail`
- `GET /api/frame-detections/current`
- `GET /api/frame-detections/latest`
- `GET /api/source-status`
- `GET /api/clips/{clip_name}`
- `GET /api/source-media/uploaded/{file_name}`
- `GET /api/source-media/cached/{file_name}`

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

## 배포 메모

- `run_gui_only.bat`는 실행 파일이 없으면 Flutter/Windows 빌드 도구 설치 여부를 묻고 자동 빌드를 시도합니다.
- 원격 서버 연결에는 서버 PC IP 또는 호스트명 예: `http://192.168.24.114:8000` 이 필요합니다.
