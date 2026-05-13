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

## FastAPI 연동 준비 상태

- 현재 GUI의 기본 동작은 기존 파일 로그 기반 구조를 유지합니다.
- 이벤트 목록과 오버레이는 여전히 txt 로그 파일 파싱 흐름을 사용합니다.
- `lib/models/api_event_item.dart`는 서버 JSON 응답 모델입니다.
- `lib/models/event_log_item.dart`는 기존 UI 표시 모델입니다.
- `lib/services/event_api_service.dart`는 향후 FastAPI 서버 기반 이벤트 조회로 전환하기 위한 준비 계층입니다.
- `lib/controllers/api_event_controller.dart`는 향후 파일 로그 모드와 API 모드를 스위칭할 때 사용할 API 전용 controller입니다.
- `lib/adapters/api_event_log_adapter.dart`는 API 이벤트를 기존 UI 모델로 변환하기 위한 준비 계층입니다.
- `lib/controllers/event_feed_source.dart`는 파일 로그 모드와 API 모드를 같은 UI 표시 모델로 다루기 위한 공통 인터페이스입니다.
- `lib/controllers/file_event_feed_source.dart`는 `EventLogController`를 감싸는 어댑터입니다.
- `lib/controllers/api_event_feed_source.dart`는 `ApiEventController`를 감싸는 어댑터입니다.
- `ApiEventController`는 내부적으로 `ApiEventItem` 목록을 유지하면서, `logItems` getter로 기존 UI용 `EventLogItem` 목록도 함께 제공합니다.
- 이 구조 덕분에 기존 `EventLogBox`, `VideoViewBox`를 크게 바꾸지 않고 API 모드로 전환할 수 있습니다.
- 기본 서버 주소는 `http://127.0.0.1:8000` 입니다.
- 아직 `HomeScreen`에는 연결하지 않았고, 실제 화면 전환은 다음 단계에서 진행합니다.
- 다음 단계에서 `HomeScreen`이 `EventFeedSource`를 바라보도록 바꾸면 파일 로그/API 모드 전환이 쉬워집니다.

## 참고 패키지

- `media_kit`, `media_kit_video`, `media_kit_libs_video`
  - Flutter desktop 영상 재생용
- `file_selector`
  - 영상 파일과 로그 파일 선택용
- `http`
  - FastAPI 이벤트 조회 API 호출 준비용

패키지 정보는 pub.dev 기준으로 반영했습니다.
