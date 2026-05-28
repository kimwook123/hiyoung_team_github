# Safety AI Monitor

Windows 환경에서 동작하는 안전 모니터링 시스템입니다. `FastAPI` 서버가 영상 분석과 데이터 저장을 맡고, `Flutter` GUI가 소스 등록, 모니터링, 이벤트 조회와 클립 재생을 담당합니다.

## 구성

- `safety_monitor_server/`
  - 소스 등록 API
  - 분석 worker 관리
  - 이벤트, 프레임 탐지, 소스 상태, 클립 저장
  - GUI 조회용 API 제공
  - 내부 분석 패키지: `safety_monitor_server/app/analysis/`
- `safety_ai_monitor_ui/`
  - Flutter Windows GUI
  - 멀티 타일 영상 재생
  - 소스 등록과 복원
  - 이벤트, 클립, 탐지 박스 조회
  - 선택된 타일만 오디오 출력

## 현재 동작

### 서버

- 등록된 소스를 `source_key` 기준으로 관리합니다.
- 소스별 분석 worker를 서버 내부에서 직접 실행합니다.
- 결과는 SQLite와 클립 디렉터리에 직접 저장합니다.
- 미완료 파일 영상은 서버 재시작 후 이어서 분석합니다.
- RTSP, HTTP, CCTV 계열 스트림은 끊기면 재연결을 시도합니다.
- YOLO 실행 시 같은 이름의 `best.engine`이 있으면 TensorRT 엔진을 우선 사용하고, 없으면 `.pt` 모델로 동작합니다.

### GUI

- 영상은 로컬 파일 또는 서버 `media_url` 기준으로 재생합니다.
- 이벤트, 클립, 탐지 박스, 소스 상태는 서버 API에서 조회합니다.
- 현재 선택된 소스가 있으면 그 소스의 이벤트 로그를 우선 표시합니다.
- 선택이 없으면 전체 소스 이벤트 로그를 표시합니다.
- 이벤트 상세의 `클립 재생`은 새 창이 아니라 현재 패널에서 재생 모드로 전환합니다.
- 여러 타일이 동시에 재생될 수 있지만 오디오는 선택된 타일만 출력합니다.
- 새 소스를 등록하거나 다른 타일을 선택해도 기존 영상은 자동 일시정지되지 않습니다.

## 저장 위치

- DB: `safety_monitor_server/data/monitor.db`
- 클립: `safety_monitor_server/data/clips/`
- 서버 캐시: `safety_monitor_server/data/source_cache/`
- 업로드 원본 영상: `safety_monitor_server/data/uploaded_sources/`

## 실행

### 서버 실행

```powershell
run_server.bat
```

- `Python 3.12`와 `py` 런처가 있으면 서버 의존성을 자동 점검합니다.
- 기본 주소는 `http://0.0.0.0:8000`입니다.

### GUI 실행

```powershell
run_gui.bat
```

- 실행 파일이 없으면 Flutter Windows 빌드를 자동 시도합니다.
- GUI는 실행 시 서버 주소를 입력받고 `server_config.json`에 저장합니다.

### GUI 디버그 실행

```powershell
cd safety_ai_monitor_ui
..\flutter\bin\flutter.bat run -d windows
```

## 핵심 메모

- 서버가 분석과 저장을 직접 처리하므로 별도 Python AI worker를 따로 띄우지 않습니다.
- GUI는 더 이상 `source_state.json`, `sources_state.json`, `ui_bridge.json` 같은 브리지 파일에 의존하지 않습니다.
- 서버 콘솔 로그는 `[REQ]`, `[REQ-SUM]`, `[SRC]`, `[PROGRESS]`, `[PERF]`, `[WARN]`, `[ERROR]` 태그로 구분됩니다.
- 서버 등록 소스는 GUI에서 다시 열 수 있고, 등록 목록의 휴지통 버튼은 서버 완전 삭제와 같은 동작을 합니다.

## 문서

- 전체 문서 안내: [docs/README.md](./docs/README.md)
- 실행 가이드: [RUN_GUIDE.md](./RUN_GUIDE.md)
- 서버: [safety_monitor_server/README.md](./safety_monitor_server/README.md)
- GUI: [safety_ai_monitor_ui/README.md](./safety_ai_monitor_ui/README.md)
- 분석 패키지: [safety_monitor_server/app/analysis/README.md](./safety_monitor_server/app/analysis/README.md)
