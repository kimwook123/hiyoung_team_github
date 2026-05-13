# 실행 가이드

## 1. GUI만 열기

`run_gui_only.bat`

- 빌드된 Flutter GUI만 실행합니다.
- Python 분석은 따로 실행 중이어야 로그나 API 이벤트가 갱신됩니다.

## 2. Python AI Worker만 실행

`run_python_only.bat`

- Python 분석 파이프라인만 실행합니다.
- GUI 없이 이벤트 생성, 로그 기록, 서버 전송을 확인할 때 사용합니다.

## 3. Python 분석 + GUI 같이 열기

`run_python_and_gui.bat`

- Python AI Worker를 먼저 실행합니다.
- 3초 뒤 Flutter GUI를 엽니다.
- 파일 로그 모드 기반 기존 흐름을 빠르게 확인할 때 사용합니다.

## 4. FastAPI 서버만 실행

`run_server.bat`

- FastAPI 이벤트 저장/조회 서버만 실행합니다.
- 서버는 `safety_monitor_server/data/events.jsonl`과 `data/clips/`를 사용합니다.

## 5. Python + Server + GUI 같이 열기

`run_python_server_and_gui.bat`

- Python AI Worker를 먼저 실행합니다.
- 3초 뒤 FastAPI 서버를 실행합니다.
- 다시 3초 뒤 Flutter GUI를 엽니다.

## 6. 실패 이벤트 재전송

`run_repost_failed_events.bat`

- `logs/events_post_failed.jsonl`에 쌓인 실패 이벤트를 서버로 다시 보냅니다.
- 원본 fallback 파일은 삭제하지 않습니다.

## 7. Flutter 디버그 모드로 열기

`run_flutter_debug.bat`

- Flutter 개발용 실행입니다.
- 코드 수정 후 다시 확인할 때 사용합니다.

## 8. Windows 빌드

`build_gui.bat`

- Flutter Windows 릴리스 빌드를 생성합니다.

## 참고

- GUI 실행 파일 경로:
  - `<현재 작업 폴더>\safety_ai_monitor_ui\build\windows\x64\runner\Release\safety_ai_monitor_ui.exe`

- Python 프로젝트 경로:
  - `<현재 작업 폴더>\safety_ai_monitor`

- FastAPI 서버 프로젝트 경로:
  - `<현재 작업 폴더>\safety_monitor_server`

- 배치 파일은 현재 작업 폴더 기준으로 실행됩니다.
