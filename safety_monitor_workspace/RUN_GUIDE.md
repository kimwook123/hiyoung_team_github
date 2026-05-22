# 실행 가이드

## 1. 서버만 실행

`run_server.bat`

- FastAPI 서버를 실행합니다.
- 서버가 분석 worker도 내부적으로 관리합니다.
- 기본 host는 `0.0.0.0:8000`이라 다른 PC GUI도 접속할 수 있습니다.

## 2. GUI만 실행

`run_gui_only.bat`

- 빌드된 Flutter GUI만 실행합니다.
- 서버가 이미 떠 있어야 소스 등록, 로그 조회, 박스 표시가 정상 동작합니다.
- 원격 서버를 쓸 때는 GUI 상단 `서버 주소` 입력에 `http://서버IP:8000`을 넣고 적용합니다.

## 3. 서버 + GUI 같이 실행

`run_server_and_gui.bat`

- 서버를 먼저 실행합니다.
- 잠시 뒤 GUI를 실행합니다.

## 4. Flutter 디버그 모드

`run_flutter_debug.bat`

- 코드 수정 후 GUI를 개발 모드로 확인할 때 사용합니다.

## 5. Windows 빌드

`build_gui.bat`

- Flutter Windows 릴리스 빌드를 생성합니다.

## 참고

- 서버 저장소:
  - `safety_monitor_server/data/monitor.db`
  - `safety_monitor_server/data/clips/`
- 서버 내부 분석 패키지:
  - `safety_monitor_server/app/analysis/`
- GUI 실행 파일:
  - `safety_ai_monitor_ui/build/windows/x64/runner/Release/safety_ai_monitor_ui.exe`
