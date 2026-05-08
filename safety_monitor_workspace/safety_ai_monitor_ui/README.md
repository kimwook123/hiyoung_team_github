# Safety AI Monitor UI

Flutter로 만든 영상 확인용 UI 레이어입니다.

이 앱은 Python 분석 파이프라인과 분리되어 동작합니다.

- Python 레이어: 영상 분석, 이벤트 판단, 로그 저장
- Flutter 레이어: 영상 재생, 프레임 이동, 이벤트 로그 표시

## 폴더 구조

```text
safety_ai_monitor_ui/
  pubspec.yaml
  README.md

  lib/
    main.dart
    app.dart

    models/
      app_link_info.dart
      event_log_item.dart

    services/
      app_link_service.dart
      event_log_service.dart
      video_service.dart

    controllers/
      event_log_controller.dart
      video_panel_controller.dart

    screens/
      home_screen.dart

    widgets/
      file_bar.dart
      video_view_box.dart
      video_control_bar.dart
      event_log_box.dart
```

## 역할 분리

- `services/`
  - Flutter 외부 자원과 연결합니다.
  - 영상 재생 라이브러리, 로그 파일 읽기 등을 담당합니다.

- `controllers/`
  - 화면 상태를 관리합니다.
  - 재생 상태, 현재 시간, 로그 목록 등을 다룹니다.

- `widgets/`
  - 화면 표시만 담당합니다.
  - 버튼, 리스트, 플레이어 화면을 그립니다.

- `screens/`
  - 화면을 조립합니다.

## 주요 기능

- 영상 열기
- RTSP / CCTV 스트림 주소 열기
- 재생 / 일시정지
- 이전 프레임 / 다음 프레임 이동
- 재생 위치 슬라이더
- 이벤트 로그 파일 읽기
- 이벤트 로그 목록 표시
- 현재 프레임 이벤트 오버레이 표시
- 이벤트 목록 클릭 시 해당 위치로 이동
- 스트림 이벤트 클릭 시 저장된 이벤트 클립 재생
- 스트림 클립 확인 후 라이브 복귀

## Python 레이어와 연결 방법

이 앱은 Python 프로젝트의 로그 파일을 읽어 표시합니다.

예시:

- 영상 파일: `sample_video.mp4`
- 로그 파일: `safety_ai_monitor/logs/event_log.txt`
- 스트림 주소: `rtsp://127.0.0.1:8554/live`

Python 앱은 `safety_ai_monitor/logs/ui_bridge.json` 파일도 함께 만들 수 있습니다.
Flutter UI는 이 파일을 읽어서 영상 경로와 로그 경로를 자동으로 연결하려고 시도합니다.

로그 형식은 현재 Python 프로젝트의 콘솔/로그 출력 형식을 기준으로 읽습니다.

## 참고 패키지

- `media_kit`, `media_kit_video`, `media_kit_libs_video`
  - Flutter desktop 영상 재생용
- `file_selector`
  - 영상 파일과 로그 파일 선택용

패키지 정보는 pub.dev 기준으로 반영했습니다.
