# Safety AI Monitor

서버와 GUI 클라이언트 2계층으로 정리한 Windows 기반 안전 모니터링 프로젝트입니다.

## 현재 구조

- `safety_monitor_server/`
  - FastAPI 서버
  - 영상 소스 등록 API
  - 분석 worker 관리
  - 이벤트/프레임 탐지/소스 상태/클립 저장
  - GUI 조회 API 제공
  - 내부 분석 패키지: `safety_monitor_server/app/analysis/`
- `safety_ai_monitor_ui/`
  - Flutter GUI 클라이언트
  - 멀티 패널 영상 재생
  - 소스 등록/선택
  - 이벤트/클립/박스 조회
  - 현재 재생 시간 기준 오버레이
  - 선택된 타일만 오디오 재생, 나머지는 무음

## 데이터 흐름

### 1. 클라이언트 -> 서버

- 영상 파일/스트림 소스 등록
- 소스 목록 조회
- 이벤트/클립/프레임 탐지/소스 상태 조회

### 2. 서버 내부

- 등록된 소스를 `source_key` 기준으로 관리
- 소스별 분석 worker thread 실행
- 분석 결과를 SQLite와 클립 디렉터리에 직접 저장
- 미완료 파일 영상은 서버 재시작 후 이어서 분석
- CCTV/RTSP/HTTP 스트림은 연결 가능한 동안 계속 분석, 끊기면 재시도

### 3. GUI 표시

- GUI는 영상을 로컬/서버 URL 기준으로 재생
- 박스/이벤트/클립은 서버에서 조회
- 현재 활성 소스만 이벤트 로그와 메인 오버레이를 표시
- 이벤트 클립은 별도 창이 아니라 현재 화면의 해당 패널에서 재생 모드로 전환
- 선택된 타일만 오디오가 나오고 나머지 타일은 무음 처리
- 선택을 해제하면 전체 이벤트 로그를 표시

## 저장소

- DB: `safety_monitor_server/data/monitor.db`
- 클립: `safety_monitor_server/data/clips/`
- 서버 캐시: `safety_monitor_server/data/source_cache/`
- 업로드 원본 영상: `safety_monitor_server/data/uploaded_sources/`

## 실행 순서

### 1. 서버 실행

```powershell
run_server.bat
```

- `Python 3.12`와 `py` 런처가 있으면, 배치 파일이 서버 의존성(`fastapi`, `uvicorn`, `opencv-python`, `numpy`, `requests`, `yt-dlp`)을 검사하고 필요 시 설치를 유도합니다.
- 기본 배치는 `0.0.0.0:8000`으로 서버를 열어 같은 네트워크의 다른 PC GUI도 접속할 수 있게 합니다.

### 2. GUI 실행

```powershell
run_gui.bat
```

- GUI 실행 파일이 없으면 배치가 `Flutter`, `Visual Studio 2022 Desktop development with C++`, `Windows SDK`를 확인하고 필요 시 설치 여부를 묻습니다.
- 설치 후 `flutter pub get`, `flutter build windows`를 자동으로 시도합니다.
- GUI는 실행 시 서버 주소를 물어보고 `server_config.json`에 저장합니다.
- 디버그 실행이 필요하면 `safety_ai_monitor_ui` 폴더에서 로컬 Flutter SDK로 직접 실행할 수 있습니다.
  - `..\flutter\bin\flutter.bat run -d windows`

## 현재 핵심 특징

- 서버가 분석 worker를 직접 관리합니다.
- 다른 PC에 서버 폴더만 배치해도 `run_server.bat`으로 분석/저장/API를 함께 실행할 수 있습니다.
- 서버 콘솔 로그는 `[REQ]`, `[REQ-SUM]`, `[SRC]`, `[PROGRESS]`, `[PERF]`, `[WARN]`, `[ERROR]` 태그로 구분되며 색상도 적용됩니다.
- GUI는 상단 `서버 주소` 입력 또는 `run_gui.bat`의 초기 입력으로 로컬/원격 서버를 전환할 수 있습니다.
- GUI는 더 이상 `source_state.json`, `sources_state.json`, `ui_bridge.json`에 의존하지 않습니다.
- 분석 결과 저장은 HTTP 재전송이 아니라 서버 내부 DB/클립 저장 흐름입니다.
- 멀티소스 분석은 서버에서, 멀티패널 전환/재생은 GUI에서 담당합니다.
- 객체 탐지 박스는 서버의 프레임 탐지 스냅샷을 기준으로 표시합니다.
- 분석 코어/모델/룰은 `safety_monitor_server/app/analysis/` 아래로 흡수되었습니다.
- 서버 등록 소스는 GUI에서 다시 열 수 있고, 서버만 켜져 있어도 저장된 미완료 소스는 계속 분석됩니다.
- YOLO 실행 시 `best.engine` 같은 TensorRT 엔진 파일이 있으면 이를 우선 사용하고, 없으면 `.pt`로 동작합니다.
- 이벤트 상세의 `클립 재생`은 현재 선택된 소스 패널 또는 현재 화면에서 재생 모드로 전환됩니다.
- 새 소스를 추가하거나 타일을 바꿔도 다른 영상은 일시정지되지 않습니다.

## 주요 문서

- 전체 문서 안내: [docs/README.md](./docs/README.md)
- 서버: [safety_monitor_server/README.md](./safety_monitor_server/README.md)
- GUI: [safety_ai_monitor_ui/README.md](./safety_ai_monitor_ui/README.md)
- 분석 패키지: [safety_monitor_server/app/analysis/README.md](./safety_monitor_server/app/analysis/README.md)
- 구조 노트: [docs/ai/ARCHITECTURE_NOTES.md](./docs/ai/ARCHITECTURE_NOTES.md)
- 개발 컨텍스트: [docs/ai/CODEX_CONTEXT.md](./docs/ai/CODEX_CONTEXT.md)
