# Safety AI Monitor UI

서버와 연결되는 Flutter Windows GUI 클라이언트입니다.

## 역할

- 영상 파일 업로드와 스트림 등록
- 서버 등록 소스 복원
- 멀티 타일 영상 재생
- 이벤트 로그와 상세 조회
- 클립 재생과 원본 복귀
- 현재 재생 시간 기준 탐지 박스 오버레이 표시
- 선택된 타일만 오디오 출력

## 서버 연동

GUI는 다음 API를 사용합니다.

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

GUI는 더 이상 별도 Python worker 제어 파일이나 로컬 브리지 파일을 사용하지 않습니다.

## 현재 UX

- 선택된 소스가 있으면 해당 소스의 이벤트 로그를 우선 표시합니다.
- 선택이 없으면 전체 이벤트 로그를 표시합니다.
- 로그를 클릭하면 해당 이벤트 시작 시점으로 이동합니다.
- 이벤트 상세의 버튼 텍스트는 `클립 재생`이며, 새 창 대신 현재 패널에서 재생 모드로 전환합니다.
- 클립 재생 중 `클립 닫기`로 원본 영상이나 스트림으로 복귀할 수 있습니다.
- 여러 타일이 동시에 재생될 수 있지만 오디오는 선택된 타일만 출력합니다.
- 새 소스를 추가하거나 타일을 바꿔도 다른 영상은 자동 일시정지되지 않습니다.
- 서버 등록 소스 목록의 휴지통 버튼은 서버 완전 삭제와 동일하게 동작합니다.

## 주요 파일

- `lib/screens/home_screen.dart`
  - 소스 등록, 패널 전환, 이벤트 UX, 오디오 포커스
- `lib/controllers/video_panel_controller.dart`
  - 재생, 클립 replay, 복귀, mute 제어
- `lib/services/event_api_service.dart`
  - 서버 HTTP API 호출
- `lib/services/video_service.dart`
  - 플레이어 생성과 dispose, 볼륨 제어
- `lib/widgets/video_view_box.dart`
  - 영상 박스와 탐지 오버레이
- `lib/widgets/video_event_overlay.dart`
  - 이벤트 카드와 상태 오버레이

## 실행

- 기본 실행: `run_gui.bat`
- 디버그 실행:

```powershell
cd safety_ai_monitor_ui
..\flutter\bin\flutter.bat run -d windows
```

- 원격 서버 연결 시 예: `http://192.168.24.114:8000`
