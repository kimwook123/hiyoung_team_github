# 실행 가이드

## 1. 서버만 실행

`run_server.bat`

- FastAPI 서버를 실행합니다.
- 서버가 분석 worker도 내부적으로 관리합니다.
- 기본 host는 `0.0.0.0:8000`이라 다른 PC GUI도 접속할 수 있습니다.
- `Python 3.12`와 `py`가 있으면 필수 서버 패키지를 자동 점검하고, 없으면 설치 여부를 묻습니다.

## 2. GUI만 실행

`run_gui.bat`

- GUI 실행 파일이 있으면 바로 실행합니다.
- 실행 파일이 없으면 Flutter Windows 빌드를 자동 시도합니다.
- 필요한 경우 다음 항목을 순서대로 검사하고 설치 여부를 묻습니다.
  - Flutter SDK
  - Visual Studio 2022 Desktop development with C++
  - Windows SDK
- 실행 시 서버 주소를 입력받고, 값을 `server_config.json`에 저장합니다.
- 다음 실행부터는 저장된 서버 주소를 기본값으로 사용합니다.
- 원격 서버 예시: `http://192.168.24.114:8000`

## 3. Flutter 디버그 모드

```powershell
cd safety_ai_monitor_ui
..\flutter\bin\flutter.bat run -d windows
```

- 코드 수정 후 GUI를 디버그 모드로 확인할 때 사용합니다.
- 로컬 `flutter` 명령이 PATH에 없어도 저장소 루트의 `flutter\bin\flutter.bat`로 실행할 수 있습니다.

## 4. Windows 빌드

`build_gui.bat`

- Flutter Windows 릴리스 빌드를 생성합니다.

## 참고

- 서버 저장소:
  - `safety_monitor_server/data/monitor.db`
  - `safety_monitor_server/data/clips/`
  - `safety_monitor_server/data/source_cache/`
  - `safety_monitor_server/data/uploaded_sources/`
- 서버 내부 분석 패키지:
  - `safety_monitor_server/app/analysis/`
- GUI 실행 파일:
  - `safety_ai_monitor_ui/build/windows/x64/runner/Release/safety_ai_monitor_ui.exe`
- 미완료 파일 영상은 서버 재시작 후 자동 이어받기됩니다.
- CCTV/RTSP/HTTP 스트림은 서버가 살아 있고 등록 상태가 유지되는 한 계속 분석을 재시도합니다.
- 이벤트 상세의 `클립 재생`은 별도 새 창이 아니라 현재 GUI 패널에서 클립 재생 모드로 전환됩니다.
- 여러 영상이 동시에 재생될 수 있지만, 오디오는 현재 선택된 타일만 출력됩니다.

## 서버 로그 읽는 법

- `[REQ]`: 개별 API 요청 처리 로그
- `[REQ-SUM]`: 자주 오는 polling 요청 요약 로그
- `[SRC]`: 소스 시작/열기/재시도/종료 같은 lifecycle 로그
- `[PROGRESS]`: 분석 진행률과 현재 상태
- `[PERF]`: 프레임 처리 성능 요약
- `[WARN]`: 경고
- `[ERROR]`: 실패/예외

서버 콘솔에서는 태그별 색도 함께 사용합니다.
