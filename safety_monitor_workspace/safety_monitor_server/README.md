# safety_monitor_server

FastAPI 기반 이벤트 저장/조회 서버입니다.

이 서버는 AI 추론을 직접 수행하지 않고, Python AI Worker가 보낸 결과를 저장하고 GUI가 조회할 수 있게 제공합니다.

## 현재 저장 구조

- DB: `data/monitor.db`
- 클립 폴더: `data/clips/`

SQLite 테이블:

- `events`
- `frame_detections`
- `source_status`

## 역할

- 이벤트 저장
- 프레임별 객체 탐지 스냅샷 저장
- 소스 상태 저장
- 이벤트 클립 업로드/제공
- 소스별 reset
- 이벤트 목록/상세/최신 상태/소스 요약 조회

## API 목록

- `GET /health`
- `POST /api/events`
- `GET /api/events`
- `GET /api/events/latest`
- `GET /api/events/sources`
- `GET /api/events/detail`
- `POST /api/frame-detections`
- `GET /api/frame-detections/current`
- `POST /api/source-status`
- `GET /api/source-status`
- `POST /api/clips`
- `GET /api/clips`
- `GET /api/clips/{clip_name}`
- `POST /api/admin/reset-data`

## 주요 API 설명

### `POST /api/events`

- Python AI Worker가 이벤트를 전송합니다.
- 서버는 이벤트 payload를 DB에 저장합니다.
- `clip_url`, `clip_available`, `preferred_clip_source` 같은 클립 접근 필드를 정규화할 수 있습니다.

### `POST /api/frame-detections`

- Python AI Worker가 프레임별 객체 탐지 결과를 전송합니다.
- GUI의 박스 오버레이는 주로 이 데이터를 사용합니다.

### `GET /api/frame-detections/current`

- `source_key + source_time_seconds` 기준으로 가장 가까운 프레임 스냅샷을 반환합니다.
- 현재 GUI는 활성 소스의 현재 재생 시점에 맞춰 이 API를 반복 조회합니다.

### `POST /api/source-status`

- Python AI Worker가 현재 소스의 분석 상태를 보냅니다.
- 예:
  - `running`
  - `completed`
  - `stopped`
  - `error`

### `GET /api/source-status`

- GUI가 소스 칩 상태, FPS, 마지막 처리 시점을 표시할 때 사용합니다.

### `POST /api/admin/reset-data`

- 특정 `source_key` 기준으로 이벤트/프레임 탐지/소스 상태/관련 클립을 정리합니다.
- 멀티소스 구조에서 다른 소스 데이터는 유지합니다.

## 동시성 메모

- 현재 서버는 SQLite `WAL` 모드로 동작합니다.
- 여러 GUI 클라이언트의 동시 조회는 비교적 무리 없이 처리하는 방향입니다.
- 여러 Python 분석 클라이언트가 서로 다른 `source_key`를 쓰는 경우도 현재 규모에서는 실용적으로 동작하는 구조입니다.
- 다만 대규모 동시 writer 환경까지 보장하는 구조는 아니므로, 장기적으로는 서버형 DB 전환 여지를 두고 있습니다.

## 실행 예시

```powershell
cd safety_monitor_server
py -3.12 -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

또는 루트에서:

```powershell
run_server.bat
```
