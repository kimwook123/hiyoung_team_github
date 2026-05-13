# event_json_schema.md

## 목적
- `events.jsonl`은 Python AI 파이프라인에서 생성된 `Event`를 서버 또는 다른 클라이언트가 재사용할 수 있도록 JSON Lines 형식으로 기록하는 파일이다.
- 이 파일은 구조화된 이벤트 소비를 위한 별도 출력 계층이며, 기존 Flutter GUI 호환을 위한 `*_event_log.txt` 출력은 그대로 유지된다.
- 즉, `*_event_log.txt`는 기존 GUI 파서용 텍스트 로그이고, `events.jsonl`은 서버 연동 및 후속 시스템 통합을 위한 구조화 로그다.
- 같은 JSON 이벤트 스키마는 Python 로컬 JSONL 기록과 `POST /api/events` 요청 body 양쪽에서 공통으로 사용된다.

## 기록 형식
- `events.jsonl`은 JSON Lines 형식이다.
- 이벤트 1건 또는 같은 이벤트의 상태 업데이트 1건이 한 줄 JSON으로 append 된다.
- 파일은 append-only 이벤트 스트림으로 취급한다.
- 최신 상태가 필요하면 `event_key` 기준으로 가장 마지막 레코드를 사용한다.
- 동일 `event_key`에 대해 완전히 같은 JSON 문자열은 중복 저장하지 않는다.
- 서버가 수신한 레코드에는 `received_at` 같은 서버 수신 메타데이터가 추가될 수 있다.
- 클라이언트는 알 수 없는 추가 필드를 무시할 수 있어야 한다.
- 추후 서버 저장 이벤트에는 `clip_url` 같은 서버 접근용 필드가 추가될 수 있다.
- 이벤트 JSON에는 `clip_url`, `server_clip_path`, `server_clip_name`, `clip_upload_ok`, `clip_available`, `preferred_clip_source` 같은 서버 클립 필드가 추가될 수 있다.

## 필드 목록

| 필드 | 타입 | Nullable | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `event_key` | `string` | 아니오 | 이벤트 식별 키. 현재 `Event` 또는 `EventFilter`가 생성한 값을 그대로 사용한다. | `"NO_HELMET:3"` |
| `event_type` | `string` | 아니오 | 이벤트 종류. `EventType.value` 문자열로 기록된다. | `"NO_HELMET"` |
| `status` | `string` | 아니오 | 이벤트 상태. 현재 serializer는 계산하지 않고 `Event.status.value`를 그대로 기록한다. | `"ACTIVE"` |
| `level` | `string` | 아니오 | 심각도 레벨. `EventLevel.value` 문자열로 기록된다. | `"WARNING"` |
| `message` | `string` | 아니오 | 사용자 표시 또는 로그용 메시지다. | `"안전모 미착용 의심 이벤트 발생"` |
| `frame_id` | `integer` | 아니오 | 현재 이벤트 레코드가 생성된 프레임 번호다. | `120` |
| `person_id` | `integer` | 예 | `Event.person_id` 프로퍼티 값이다. 일반적으로 첫 번째 관련 탐지의 `track_id`를 사용한다. | `3` |
| `created_at` | `string` | 아니오 | 이벤트 레코드 생성 시각. `datetime.isoformat()` 문자열이다. | `"2026-05-13T14:30:00"` |
| `started_at` | `string` | 예 | 이벤트 시작 시각. `Event.__post_init__()`에서 기본적으로 `created_at`으로 채워진다. | `"2026-05-13T14:29:58"` |
| `ended_at` | `string` | 예 | 이벤트 종료 시각. 종료되지 않았으면 `null`이다. | `"2026-05-13T14:30:04"` |
| `duration_seconds` | `number` | 아니오 | 이벤트 누적 지속 시간(초)이다. | `2.1` |
| `started_frame_id` | `integer` | 예 | 이벤트 시작 프레임 번호다. 기본적으로 첫 생성 시 `frame_id`로 채워진다. | `110` |
| `ended_frame_id` | `integer` | 예 | 이벤트 종료 프레임 번호다. 종료되지 않았으면 `null`이다. | `145` |
| `clip_path` | `string` | 아니오 | 저장된 이벤트 클립 경로다. 없으면 빈 문자열일 수 있다. | `"logs/clips/no_helmet_3.mp4"` |
| `clip_url` | `string` | 예 | 서버가 소유한 클립에 접근할 수 있는 URL이다. 있으면 클라이언트는 이 값을 우선 사용한다. | `"/api/clips/no_helmet_3.mp4"` |
| `server_clip_path` | `string` | 예 | 서버 저장소 기준 상대 클립 경로다. | `"clips/no_helmet_3.mp4"` |
| `server_clip_name` | `string` | 예 | 서버 저장소에 기록된 클립 파일명이다. | `"no_helmet_3.mp4"` |
| `clip_upload_ok` | `boolean` | 아니오 | 서버 클립 업로드 성공 여부다. 서버 정규화 단계에서 기본값이 채워질 수 있다. | `true` |
| `clip_available` | `boolean` | 아니오 | 서버 URL 또는 로컬 fallback 경로 중 재생 가능한 클립 정보가 있는지 나타낸다. | `true` |
| `preferred_clip_source` | `string` | 아니오 | 클라이언트가 우선 사용할 클립 소스다. `server`, `local`, `""` 중 하나다. | `"server"` |
| `source_time_seconds` | `number` | 아니오 | 원본 입력 기준 시간(초)이다. | `8.16` |
| `source_time_text` | `string` | 아니오 | 원본 입력 기준 시간 문자열이다. | `"00:08.160"` |
| `started_source_time_text` | `string` | 아니오 | 이벤트 시작 시점의 시간 문자열이다. 비어 있으면 생성 시 `source_time_text`로 초기화된다. | `"00:07.920"` |
| `ended_source_time_text` | `string` | 아니오 | 이벤트 종료 시점의 시간 문자열이다. 종료되지 않았으면 빈 문자열일 수 있다. | `"00:09.280"` |
| `related_detections` | `array<object>` | 아니오 | 이벤트와 연결된 탐지 목록이다. 각 원소는 Detection 구조를 따른다. | 아래 구조 참고 |

## related_detections 구조

### Detection 필드

| 필드 | 타입 | Nullable | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `name` | `string` | 아니오 | 탐지 클래스 이름이다. | `"person"` |
| `score` | `number` | 아니오 | 탐지 신뢰도 점수다. | `0.91` |
| `track_id` | `integer` | 예 | 추적 ID다. 추적이 없으면 `null`이다. | `3` |
| `box` | `object` | 예 | 바운딩 박스 정보다. 현재 `Detection.box`는 항상 `Box` 타입이지만 serializer는 `null`도 허용한다. | 아래 구조 참고 |

### Box 필드

| 필드 | 타입 | Nullable | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `x1` | `integer` | 아니오 | 좌상단 x 좌표 | `100` |
| `y1` | `integer` | 아니오 | 좌상단 y 좌표 | `120` |
| `x2` | `integer` | 아니오 | 우하단 x 좌표 | `220` |
| `y2` | `integer` | 아니오 | 우하단 y 좌표 | `420` |

## status 정책
- 현재 JSON 이벤트 출력은 `status`를 별도로 계산하지 않는다.
- [event_serializer.py](/abs/path/c:/Users/AISW_203_114/Desktop/hiyoung_team_github/safety_monitor_workspace/safety_ai_monitor/core/event_serializer.py:32) 에서 `Event.status` 값을 그대로 직렬화한다.
- 따라서 JSON 소비 측은 `status`를 현재 `Event` 객체 상태의 직접 표현으로 받아들여야 한다.
- 반면 기존 txt 로그는 [log_event_handler.py](/abs/path/c:/Users/AISW_203_114/Desktop/hiyoung_team_github/safety_monitor_workspace/safety_ai_monitor/handlers/log_event_handler.py:42) 에서 `ended_at` 또는 `ended_frame_id` 존재 여부를 기준으로 `ACTIVE/END`를 계산한다.
- 즉, txt 로그의 `status`와 JSON `status`는 계산 기준이 다를 수 있으며, 현재 JSON 계약은 serializer 구현을 따른다.

## 예시 JSON

### NO_HELMET 예시

```json
{
  "event_key": "NO_HELMET:3",
  "event_type": "NO_HELMET",
  "status": "ACTIVE",
  "level": "WARNING",
  "message": "안전모 미착용 의심 이벤트 발생",
  "frame_id": 120,
  "person_id": 3,
  "created_at": "2026-05-13T14:30:00",
  "started_at": "2026-05-13T14:29:58",
  "ended_at": null,
  "duration_seconds": 2.1,
  "started_frame_id": 110,
  "ended_frame_id": null,
  "clip_path": "logs/clips/no_helmet_3.mp4",
  "source_time_seconds": 8.16,
  "source_time_text": "00:08.160",
  "started_source_time_text": "00:07.920",
  "ended_source_time_text": "",
  "related_detections": [
    {
      "name": "person",
      "score": 0.91,
      "track_id": 3,
      "box": {
        "x1": 100,
        "y1": 120,
        "x2": 220,
        "y2": 420
      }
    }
  ]
}
```

### DANGER_ZONE 예시

```json
{
  "event_key": "DANGER_ZONE:7",
  "event_type": "DANGER_ZONE",
  "status": "END",
  "level": "DANGER",
  "message": "위험구역 침입 이벤트 종료",
  "frame_id": 245,
  "person_id": 7,
  "created_at": "2026-05-13T14:31:10",
  "started_at": "2026-05-13T14:31:02",
  "ended_at": "2026-05-13T14:31:10",
  "duration_seconds": 8.0,
  "started_frame_id": 201,
  "ended_frame_id": 245,
  "clip_path": "logs/clips/danger_zone_7.mp4",
  "source_time_seconds": 18.36,
  "source_time_text": "00:18.360",
  "started_source_time_text": "00:10.120",
  "ended_source_time_text": "00:18.360",
  "related_detections": [
    {
      "name": "person",
      "score": 0.96,
      "track_id": 7,
      "box": {
        "x1": 340,
        "y1": 180,
        "x2": 470,
        "y2": 510
      }
    }
  ]
}
```

## 소비 측 처리 가이드
- 서버 또는 다른 소비자는 `events.jsonl`을 순차적으로 읽고 `event_key` 기준 마지막 레코드로 최신 상태를 재구성할 수 있다.
- `status`가 `END`인 레코드는 종료된 이벤트로 처리한다.
- `clip_path`가 비어 있지 않으면 저장된 이벤트 클립과 연결할 수 있다.
- 현재 `clip_path`는 생산자 로컬 경로일 수 있으며, 서버 소유 클립 전환 이후에는 서버 URL 필드가 우선될 수 있다.
- `clip_url`이 있으면 클라이언트는 `clip_url`을 우선 사용하고, `preferred_clip_source`가 `"server"`인 경우도 같은 의미로 해석할 수 있다.
- `clip_url`이 없고 `preferred_clip_source`가 `"local"`이면 기존 `clip_path`를 fallback으로 사용할 수 있다.
- `clip_path`는 기존 호환성과 fallback을 위해 보존될 수 있다.
- `related_detections`를 사용하면 이벤트 시점의 탐지 객체, 추적 ID, 박스 정보를 함께 전달할 수 있다.
- `source_time_text`는 영상 파일에서는 영상 재생 시간 문자열일 수 있고, 스트림 또는 카메라에서는 현재 시각 기반 문자열일 수 있다.
- 클라이언트는 알 수 없는 추가 필드를 무시해야 한다.

## 주의사항
- 기존 `*_event_log.txt` 형식은 Flutter GUI 호환을 위해 유지되며, 이 문서는 그 텍스트 로그 계약을 대체하지 않는다.
- 이 문서는 현재 `events.jsonl` JSON 출력 계층의 계약 문서다.
- 모델 클래스명, `Rule` 판정 로직, `EventFilter` 상태 전이 정책은 별도 문서 또는 기존 `docs/ai` 문서를 따른다.
- 구현이 변경되면 이 문서도 함께 갱신해야 한다.
