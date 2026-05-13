# CODEX_CONTEXT.md

## 프로젝트 한 줄 요약
Windows 환경에서 Python AI Worker, FastAPI Event Store/API Server, Flutter GUI를 분리 운영하는 안전 모니터링 프로젝트다.

## 현재 목표 구조

- Python AI Worker
  - 이벤트와 이벤트 클립을 생성한다.
- FastAPI Server
  - 이벤트와 클립을 저장하고 HTTP API로 제공한다.
- Flutter GUI
  - 파일 로그 모드 또는 API 서버 모드로 이벤트와 클립을 소비한다.

## 디렉터리 구조 요약

- `safety_ai_monitor/`
  - Python AI Worker 본체
  - 입력 소스, 모델, 룰, 핸들러, txt 로그, 로컬 JSONL, HTTP 전송, 이벤트 클립 담당
- `safety_monitor_server/`
  - FastAPI 서버
  - `data/events.jsonl`, `data/clips/`, 이벤트/클립 API 담당
- `safety_ai_monitor_ui/`
  - Flutter GUI
  - 파일 로그 모드와 API 서버 모드 둘 다 지원
- `docs/`
  - 구조, 계약, 발표용 체크리스트 문서
- 루트 배치 파일
  - Python, 서버, GUI 실행 진입점

## Python AI Worker 역할

- 영상 파일, 스트림, 카메라 입력 열기
- 객체 검출 모델 로드와 프레임별 추론
- 사람 중심 추적 ID 부여
- 룰 기반 이벤트 생성
- txt 이벤트 로그 저장
- 설정에 따라 로컬 JSONL 기록 또는 `POST /api/events` 전송
- 이벤트 클립 생성
- 설정에 따라 `POST /api/clips` 클립 업로드
- GUI가 읽는 `ui_bridge.json`, `source_state.json` 연동 유지

## FastAPI Server 역할

- 서버 소유 이벤트 저장소: `safety_monitor_server/data/events.jsonl`
- 서버 소유 클립 저장소: `safety_monitor_server/data/clips/`
- `POST /api/events`
- `POST /api/clips`
- `GET /health`
- `GET /api/events`
- `GET /api/events/latest`
- `GET /api/events/detail`
- `GET /api/clips`
- `GET /api/clips/{clip_name}`

## Flutter GUI 역할

- 영상 파일 선택 또는 스트림 주소 입력
- 파일 로그 모드에서는 txt 로그 파일을 읽어 이벤트 표시
- API 서버 모드에서는 FastAPI API로 이벤트 목록/상세/health/클립 조회
- 영상/스트림 재생
- 현재 프레임 이벤트 오버레이 표시
- 이벤트 클릭 시 위치 이동
- 클립 재생 후 라이브 복귀

## 현재 연결 방식

### 1. Flutter -> Python

- `source_state.json`
- 의미: 현재 선택한 입력 소스 전달

### 2. Python -> Flutter

- `ui_bridge.json`
- `*_event_log.txt`
- `logs/clips/*.mp4`

### 3. Python -> FastAPI Server

- `POST /api/events`
- `POST /api/clips`

### 4. Flutter -> FastAPI Server

- `GET /health`
- `GET /api/events`
- `GET /api/events/latest`
- `GET /api/events/detail`
- `GET /api/clips/{clip_name}`

## 이벤트 저장 모드

### 로컬 JSONL 모드

- `ENABLE_HTTP_EVENT_POST = False`
- `ENABLE_JSON_EVENT_LOG = True`
- Python이 `logs/events.jsonl`을 직접 기록한다.

### 서버 전송 모드

- `ENABLE_HTTP_EVENT_POST = True`
- Python이 `POST /api/events`로 이벤트를 전송한다.
- FastAPI 서버가 `data/events.jsonl` 저장 책임을 가진다.

### 서버 전송 + 클립 업로드 모드

- `ENABLE_HTTP_EVENT_POST = True`
- `ENABLE_EVENT_CLIP_UPLOAD = True`
- Python이 `POST /api/clips`로 클립 업로드도 시도할 수 있다.
- 업로드 성공 시 이벤트 payload에 `clip_url`, `server_clip_path`, `server_clip_name`, `clip_upload_ok`가 포함될 수 있다.

## 서버 정규화 정책

- 서버는 `POST /api/events` 저장 전에 clip 관련 필드를 정규화한다.
- `clip_url`이 있으면:
  - `clip_available = true`
  - `preferred_clip_source = "server"`
- `clip_path`만 있으면:
  - `clip_available = true`
  - `preferred_clip_source = "local"`
- 둘 다 없으면:
  - `clip_available = false`
  - `preferred_clip_source = ""`

## Flutter API 모드 현재 상태

- API 서버 모드 선택 가능
- `/health` 자동 1회 확인 + 수동 확인 가능
- 이벤트 목록 자동 polling
  - 현재 3초 간격
- `clip_url` 우선, `clipPath` fallback 재생
- `relatedDetections` 표시 가능
- `clipAvailable`, `preferredClipSource`, `clipUploadOk`, `serverClipName`, `serverClipPath` 표시 가능

## 중요 설정 파일

- `safety_ai_monitor/config.py`
- `safety_monitor_server/app/config.py`
- `safety_ai_monitor_ui/lib/screens/home_screen.dart`

실행 전에는 문서보다 실제 설정 파일 값을 우선 확인하는 것이 안전하다.

## 새 작업 시작 시 먼저 볼 파일

- Python 파이프라인 변경:
  - `safety_ai_monitor/main.py`
  - `safety_ai_monitor/config.py`
- 이벤트/스키마 변경:
  - `safety_ai_monitor/core/event_serializer.py`
  - `safety_monitor_server/app/routers/events.py`
  - `docs/ai/event_json_schema.md`
- 클립/서버 구조 변경:
  - `safety_monitor_server/app/routers/clips.py`
  - `safety_monitor_server/app/config.py`
- GUI 표시 변경:
  - `safety_ai_monitor_ui/lib/screens/home_screen.dart`
  - `safety_ai_monitor_ui/lib/models/api_event_item.dart`

## 주의할 점

- 파일 로그 모드와 API 서버 모드는 다르다.
- 로컬 JSONL 모드와 서버 전송 모드는 다르다.
- 서버가 항상 모든 클립을 가진다고 단정하면 안 된다.
  - `ENABLE_EVENT_CLIP_UPLOAD = True`일 때만 서버 클립 소유 흐름이 완성된다.
- `safety_ai_monitor/logs`는 로컬 실행 로그, fallback, 임시 산출물 용도로 계속 남는다.
