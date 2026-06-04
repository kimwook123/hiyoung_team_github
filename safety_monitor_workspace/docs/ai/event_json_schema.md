# event_json_schema.md

## 목적

- 이벤트 JSON은 서버가 최종 저장하는 공통 이벤트 계약입니다.
- 객체 탐지 결과는 클라이언트가 보내지만, 이벤트 판정은 서버가 수행합니다.
- 이 문서는 `POST /api/events`와 서버 DB `events.payload_json`에 공통으로 적용됩니다.
- `*_event_log.txt`는 보조 로그이고, 주 조회 경로는 서버 API입니다.

## 기록 단위

- 이벤트 1건 또는 같은 이벤트의 상태 변경 1건이 1레코드입니다.
- 같은 `event_key`에 대해 `START`, `ACTIVE`, `END`가 누적될 수 있습니다.
- 최신 상태만 필요하면 같은 `source_key + event_key` 기준 마지막 레코드를 사용합니다.

## 주요 필드

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `event_key` | `string` | 이벤트 식별 키 |
| `event_type` | `string` | 이벤트 종류 |
| `status` | `string` | `START`, `ACTIVE`, `END` |
| `message` | `string` | 사용자 표시용 메시지 |
| `frame_id` | `integer` | 이벤트 기준 프레임 |
| `person_id` | `integer?` | 관련 사람 track id |
| `source_key` | `string` | 소스 식별 키 |
| `source_type` | `string` | `video`, `stream`, `camera` |
| `source_value` | `string` | 원본 소스 값 |
| `client_id` | `string` | 소유 클라이언트 식별자 |
| `session_id` | `string` | 세션 식별자 |
| `source_time_seconds` | `number` | 원본 기준 시각 |
| `source_time_text` | `string` | 원본 기준 시각 문자열 |
| `started_source_time_text` | `string` | 이벤트 시작 시각 |
| `ended_source_time_text` | `string` | 이벤트 종료 시각 |
| `clip_path` | `string` | 로컬 fallback 클립 경로 |
| `clip_url` | `string?` | 서버 클립 URL |
| `clip_available` | `boolean` | 재생 가능한 클립 존재 여부 |
| `related_detections` | `array<object>` | 판단 근거 탐지 목록 |

## 클립 정책

- 서버 클립이 있으면 `clip_url` 기준으로 재생합니다.
- 로컬 경로만 있으면 fallback 재생이 가능합니다.
- 클립은 나중에 업로드되어 기존 이벤트 레코드와 병합될 수 있습니다.

## 소비 측 가이드

- 뷰어와 클라이언트 UI는 필요에 따라 전체 이벤트 이력 또는 최신 상태를 표시합니다.
- 이벤트 상세는 `source_key + event_key` 기준으로 보는 것이 안전합니다.
- 프레임 박스 표시는 이벤트 JSON이 아니라 프레임 탐지 스냅샷 API를 기준으로 합니다.
