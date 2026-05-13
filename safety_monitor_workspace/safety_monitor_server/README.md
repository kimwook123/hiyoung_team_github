# safety_monitor_server

이 서버는 기존 Python AI 파이프라인을 실행하거나 제어하지 않는 파일 기반 이벤트 API 서버입니다.

- 입력 데이터는 `safety_ai_monitor/logs/events.jsonl` 파일입니다.
- 서버는 기본적으로 `data/events.jsonl`과 `data/clips/`를 서버 소유 저장소로 사용합니다.
- 서버는 `events.jsonl`을 읽어서 HTTP API로 이벤트 목록을 제공합니다.
- 또한 Python AI Worker의 서버 전송 모드에서는 `POST /api/events`로 이벤트를 받아 서버의 `data/events.jsonl`에 append 저장할 수 있습니다.
- 기존 `*_event_log.txt`, `source_state.json`, `ui_bridge.json`, Flutter UI 동작은 변경하지 않습니다.
- 현재는 파일 기반 프로토타입이며, 추후 DB 저장소나 WebSocket 기반 실시간 전송으로 확장할 수 있습니다.
- CORS는 개발 편의를 위해 모든 origin 허용으로 열려 있으며, 운영 환경에서는 제한이 필요합니다.
- 이 서버는 AI 추론을 수행하지 않고 이벤트 저장과 조회만 담당합니다.

## 실행 예시

```bash
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

워크스페이스 루트에서는 `run_server.bat`로 같은 서버를 바로 실행할 수 있습니다.

## API 목록

- `GET /health`
- `POST /api/events`
- `GET /api/events`
- `GET /api/events/latest`
- `GET /api/events/detail?event_key=...&latest_only=true`
- `GET /api/clips`
- `GET /api/clips/{clip_name}`

## API 개요

### `GET /health`
- 서버 상태와 현재 이벤트 로그 경로, 파일 존재 여부를 반환합니다.

### `POST /api/events`
- Python AI Worker가 JSON 이벤트를 서버로 전송할 때 사용하는 수신 API입니다.
- 서버는 받은 이벤트를 서버 소유 파일 기반 저장소인 `data/events.jsonl`에 JSON Lines 형식으로 append 저장합니다.
- 추후에는 같은 계약을 유지한 채 DB 저장 방식으로 교체할 수 있습니다.

예시 요청:

```json
{
  "event_key": "NO_HELMET:3",
  "event_type": "NO_HELMET",
  "status": "ACTIVE",
  "level": "WARNING",
  "message": "안전모 미착용 의심 이벤트 발생",
  "frame_id": 120,
  "person_id": 3,
  "source_time_text": "00:08.160",
  "related_detections": []
}
```

### `GET /api/events`
- `events.jsonl` 전체 레코드를 반환합니다.
- 쿼리 파라미터:
  - `latest_only`: `true`면 `event_key` 기준 최신 상태만 반환합니다.
  - `limit`: 마지막 N개만 반환합니다.
  - `event_type`: 특정 이벤트 타입만 반환합니다.
  - `status`: 특정 상태만 반환합니다.

### `GET /api/events/latest`
- `event_key` 기준 최신 이벤트 상태만 반환합니다.

### `GET /api/events/detail?event_key=...&latest_only=true`
- 특정 `event_key`의 최신 이벤트 상태 또는 전체 변경 이력을 조회합니다.
- `latest_only=true`면 최신 상태 1건을 반환합니다.
- `latest_only=false`면 해당 `event_key`의 전체 기록을 반환합니다.
- 이벤트 상세 화면이나 클립 연결 기능에서 사용할 수 있습니다.

### `GET /api/clips`
- 서버가 소유한 `data/clips/` 아래 mp4 클립 목록을 반환합니다.

### `GET /api/clips/{clip_name}`
- 서버가 소유한 mp4 클립 파일을 직접 반환합니다.
- 현재는 Python AI Worker가 클립을 서버로 업로드하는 기능은 아직 없습니다.
- 추후 Python 쪽에서 클립 업로드를 붙이면 Flutter는 서버 clip URL을 사용할 수 있습니다.

## 서버 소유 데이터 디렉터리

- `data/events.jsonl`
- `data/clips/`

## 현재 범위

- 이 서버는 `events.jsonl` 계약만 소비합니다.
- Flutter UI 연동은 아직 하지 않습니다.
- AI 파이프라인 import 없이 파일 기반으로만 동작합니다.
