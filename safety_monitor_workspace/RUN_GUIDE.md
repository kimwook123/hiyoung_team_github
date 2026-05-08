# 실행 가이드

## 1. GUI만 열기

`run_gui_only.bat`

- Flutter GUI를 바로 엽니다.
- Python 분석은 따로 실행 중이어야 로그가 갱신됩니다.

## 2. Python 분석 + GUI 같이 열기

`run_python_and_gui.bat`

- Python 분석 프로그램을 먼저 실행합니다.
- 3초 뒤 Flutter GUI를 엽니다.
- 기본 설정 기준으로 `safety_ai_monitor/main.py`를 실행합니다.

## 3. Flutter 디버그 모드로 열기

`run_flutter_debug.bat`

- Flutter 개발용 실행입니다.
- 코드 수정 후 다시 확인할 때 사용합니다.

## 참고

- GUI 실행 파일 경로:
  - `<현재 작업 폴더>\safety_ai_monitor_ui\build\windows\x64\runner\Release\safety_ai_monitor_ui.exe`

- Python 프로젝트 경로:
  - `<현재 작업 폴더>\safety_ai_monitor`

- 배치 파일은 현재 작업 폴더 기준으로 실행됩니다.
