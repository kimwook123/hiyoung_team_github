# Safety AI Monitor

Python AI Worker, FastAPI 서버, Flutter GUI를 분리해 운영하는 Windows 기반 안전 모니터링 프로젝트입니다.

## 현재 구조 한눈에 보기

- `GUI -> Python`
  - GUI는 분석할 영상/스트림 소스만 `source_state.json`, `sources_state.json`으로 전달합니다.
- `Python -> Server`
  - Python AI Worker는 이벤트, 프레임별 객체 탐지 스냅샷, 소스 상태, 이벤트 클립을 서버에 저장합니다.
- `GUI -> Server`
  - GUI는 서버에서 이벤트 목록, 상세, 클립, 현재 시점 박스, 소스 상태를 조회해 표시합니다.

즉, 영상 재생은 GUI가 직접 하고, 분석은 Python이 따로 수행하며, 결과 데이터는 서버가 소유합니다.

## 현재 핵심 동작

- 여러 영상/스트림 소스를 GUI에 등록할 수 있습니다.
- Python은 등록된 소스마다 worker thread를 띄워 병렬 분석합니다.
- GUI는 탭 방식으로 활성 소스를 전환합니다.
- 현재 활성 소스만 화면에 재생되고, 비활성 소스는 일시정지됩니다.
- 객체 탐지 박스는 서버의 프레임 스냅샷을 현재 재생 시간에 맞춰 오버레이합니다.
- 이벤트 로그에서 항목을 클릭하면 원본 영상의 이벤트 시작 시점으로 이동합니다.
- 이벤트 상세에서 `클립 열기`를 누르면 이벤트 start~end 구간 클립을 재생하고, 필요 시 원본으로 복귀할 수 있습니다.

## 컴포넌트 역할

### Python AI Worker

- 폴더: `safety_ai_monitor/`
- 역할:
  - 영상 파일, 스트림, 카메라 입력 열기
  - YOLO 또는 다중 YOLO 앙상블 추론
  - 사람 추적
  - 위험 이벤트 판정
  - 이벤트 클립 생성
  - 이벤트 / 프레임 탐지 / 소스 상태를 서버로 전송

### FastAPI Server

- 폴더: `safety_monitor_server/`
- 역할:
  - SQLite 기반 이벤트 저장소 제공
  - 이벤트 클립 파일 저장
  - 이벤트 목록/상세/클립/프레임 탐지/소스 상태 API 제공
- 현재 서버 저장소:
  - `data/monitor.db`
  - `data/clips/`

### Flutter GUI

- 폴더: `safety_ai_monitor_ui/`
- 역할:
  - 영상 재생
  - 멀티소스 등록 및 화면 전환
  - 서버 이벤트 조회
  - 프레임별 객체 탐지 박스 오버레이
  - 이벤트 시작 시점 이동
  - 이벤트 클립 재생과 원본 복귀

## 멀티소스 동작 요약

- GUI에 등록된 모든 소스는 Python에서 병렬 분석 대상입니다.
- 활성 탭은 GUI에서 현재 보고 있는 화면만 의미합니다.
- 활성 소스를 바꾸더라도 Python의 다른 소스 분석은 계속 진행됩니다.
- GUI는 활성 소스에 대해서만 현재 프레임 박스와 상태를 집중 조회합니다.

## 실행 순서

### 1. Python AI Worker 의존성 설치

```powershell
py -3.12 -m pip install -r safety_ai_monitor\requirements.txt
```

### 2. 서버 의존성 설치

```powershell
py -3.12 -m pip install -r safety_monitor_server\requirements.txt
```

### 3. Flutter 의존성 설치

```powershell
cd safety_ai_monitor_ui
..\flutter\bin\flutter.bat pub get
```

### 4. 전체 실행

```powershell
run_python_server_and_gui.bat
```

이 흐름은 다음을 순서대로 실행합니다.

1. Python AI Worker
2. FastAPI 서버
3. Flutter GUI

## 실행 모드 메모

- `run_python_only.bat`
  - Python AI Worker만 실행
- `run_server.bat`
  - FastAPI 서버만 실행
- `run_gui_only.bat`
  - 빌드된 GUI만 실행
- `run_python_server_and_gui.bat`
  - Python, 서버, GUI 전체 실행

## 주요 변경 사항 기준 요약

- 파일 로그 기반 GUI 표시는 제거되고, GUI는 서버 API 기반으로 동작합니다.
- 서버 저장소는 JSONL 중심에서 SQLite 중심으로 전환되었습니다.
- Python은 이벤트뿐 아니라 프레임 탐지 스냅샷과 소스 상태도 서버로 전송합니다.
- GUI는 로컬 프레임 탐지 파일 대신 서버의 `/api/frame-detections/current`를 조회합니다.
- 소스별 reset은 `source_key` 기준으로 분리 처리됩니다.

## 문서 읽는 순서

- 전체 구조 요약: [docs/README.md](./docs/README.md)
- Python AI Worker: [safety_ai_monitor/README.md](./safety_ai_monitor/README.md)
- FastAPI 서버: [safety_monitor_server/README.md](./safety_monitor_server/README.md)
- Flutter GUI: [safety_ai_monitor_ui/README.md](./safety_ai_monitor_ui/README.md)
- 구조 노트: [docs/ai/ARCHITECTURE_NOTES.md](./docs/ai/ARCHITECTURE_NOTES.md)
- 개발 컨텍스트: [docs/ai/CODEX_CONTEXT.md](./docs/ai/CODEX_CONTEXT.md)
- 이벤트 JSON 계약: [docs/ai/event_json_schema.md](./docs/ai/event_json_schema.md)
- 발표 전 체크리스트: [docs/demo_checklist.md](./docs/demo_checklist.md)
