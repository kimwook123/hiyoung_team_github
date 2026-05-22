# event_json_schema.md

## 목적

- 이벤트 JSON은 서버 내부 분석 worker가 생성하고 서버가 저장하는 공통 이벤트 계약입니다.
- 이 계약은 `POST /api/events` 요청 body와 서버 DB에 저장되는 payload 양쪽에서 공통으로 사용됩니다.
- 과거에는 `events.jsonl`이 주 저장소였지만, 현재 기준 저장소는 서버 SQLite DB입니다.
- 기존 `*_event_log.txt`는 디버깅 및 호환용 보조 로그이며, GUI의 주 소비 경로는 서버 API입니다.

## 기록 단위

- 이벤트 1건 또는 같은 이벤트의 상태 업데이트 1건이 1레코드입니다.
- 같은 `event_key`에 대해 `START`, `ACTIVE`, `END` 이력이 누적될 수 있습니다.
- 최신 상태가 필요하면 `event_key` 기준 마지막 레코드를 사용합니다.
- 서버는 알 수 없는 추가 필드를 삭제하지 않고 payload 그대로 보존합니다.

## 주요 필드

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `event_key` | `string` | 이벤트 식별 키 |
| `event_type` | `string` | 이벤트 종류 |
| `status` | `string` | `START`, `ACTIVE`, `END` 등 이벤트 상태 |
| `message` | `string` | 사용자 표시용 메시지 |
| `frame_id` | `integer` | 이벤트 레코드가 생성된 프레임 번호 |
| `person_id` | `integer?` | 관련 사람 track id |
| `source_key` | `string` | 소스 식별 키 |
| `source_type` | `string` | `video`, `stream`, `camera` |
| `source_value` | `string` | 원본 소스 값 |
| `client_id` | `string` | 분석 클라이언트 식별자 |
| `session_id` | `string` | 세션 식별자 |
| `source_time_seconds` | `number` | 원본 입력 기준 시간(초) |
| `source_time_text` | `string` | 원본 입력 기준 시간 문자열 |
| `started_source_time_text` | `string` | 이벤트 시작 시간 문자열 |
| `ended_source_time_text` | `string` | 이벤트 종료 시간 문자열 |
| `clip_path` | `string` | 레거시 로컬 fallback 클립 경로 |
| `clip_url` | `string?` | 서버 클립 URL |
| `server_clip_path` | `string?` | 서버 DB에 저장되는 상대경로 (`clips/...`) |
| `server_clip_name` | `string?` | 서버 저장 클립 파일명 |
| `clip_available` | `boolean` | 재생 가능한 클립 존재 여부 |
| `preferred_clip_source` | `string` | `server`, `local`, `""` |
| `related_detections` | `array<object>` | 이벤트 관련 탐지 목록 |

## related_detections 구조

### Detection

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | `string` | 탐지 클래스명 |
| `score` | `number` | 신뢰도 |
| `track_id` | `integer?` | 추적 id |
| `box` | `object?` | 바운딩 박스 |

### Box

| 필드 | 타입 |
| --- | --- |
| `x1` | `integer` |
| `y1` | `integer` |
| `x2` | `integer` |
| `y2` | `integer` |

## 클립 필드 정책

- `clip_url`이 있으면 GUI는 서버 클립을 우선 사용합니다.
- `clip_url`이 없고 `server_clip_path`가 있으면 서버 상대경로 기준으로 재생할 수 있습니다.
- `clip_url`과 `server_clip_path`가 모두 없고 `clip_path`만 있으면 레거시 로컬 fallback 재생이 가능합니다.
- `preferred_clip_source`는 클라이언트가 어떤 경로를 우선해야 하는지 알려주는 힌트입니다.

## 소비 측 가이드

- GUI 이벤트 목록은 필요에 따라 전체 이력 또는 최신 상태만 조회할 수 있습니다.
- 이벤트 시작 시점 이동은 `started_source_time_text` 또는 `source_time_seconds`를 기준으로 처리합니다.
- 현재 프레임 박스 표시는 이벤트가 아니라 `/api/frame-detections/current`의 프레임 스냅샷을 사용합니다.
- 이벤트 JSON의 `related_detections`는 상세 정보와 판단 근거 표시용입니다.

## 주의사항

- 이 문서는 이벤트 계약 문서이며, 프레임 탐지 스냅샷 스키마 전체를 다루지는 않습니다.
- 이벤트와 프레임 탐지는 서로 다른 저장 흐름을 가집니다.
- 구현이 바뀌면 서버 라우터와 GUI 모델도 함께 확인해야 합니다.
