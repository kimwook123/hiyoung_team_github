# 서버 DB 스키마 문서

이 문서는 `safety_monitor_server`의 SQLite DB가 무엇을 저장하는지 설명합니다.

## 기본 정보

- DB 파일: `safety_monitor_server/data/monitor.db`
- 기준 코드: `safety_monitor_server/app/database.py`
- DB 엔진: SQLite

## 이 DB가 담당하는 일

서버 DB는 다음 데이터를 저장합니다.

- 등록된 소스 메타데이터
- 소스별 최신 상태
- 프레임 탐지 결과
- 서버가 판정한 이벤트
- 이벤트 클립과 연결되는 부가 정보

중요한 점:

- 객체 탐지 자체는 클라이언트가 수행합니다.
- 서버는 클라이언트가 보낸 탐지 결과와 소스별 룰 설정을 이용해 이벤트를 판정합니다.

## 테이블 목록

- `sources`
- `source_status`
- `frame_detections`
- `frame_detections_latest`
- `events`

---

## 1. sources

서버가 알고 있는 소스 자체의 메타데이터를 저장합니다.

예:

- 영상 파일 소스
- 카메라 소스
- 스트림 소스

### 주요 컬럼

| 컬럼명 | 설명 |
| --- | --- |
| `source_key` | 소스 식별자 |
| `source_slug` | 화면 표시용 이름 |
| `source_type` | `video`, `camera`, `stream` |
| `source_value` | 소스 원본 값 |
| `original_source_type` | 처음 등록 당시 타입 |
| `original_source_value` | 처음 등록 당시 값 |
| `client_id` | 소유 클라이언트 식별자 |
| `session_id` | 소유 세션 식별자 |
| `desired_running` | 재연결 후 자동 재개 여부 |
| `created_at` | 등록 시각 |
| `updated_at` | 마지막 갱신 시각 |
| `payload_json` | 소스 전체 정보 JSON |

### payload_json 안의 대표 정보

- `rule_config`
- `source_duration_seconds`
- `preview_url`
- `media_url`
- `server_media_path`

### 비고

- 현재 구조에서는 소스별 룰 설정도 `payload_json.rule_config`에 저장됩니다.
- 이 룰 설정은 서버가 이벤트를 판정할 때 사용합니다.

---

## 2. source_status

소스별 최신 실행 상태 1건을 저장합니다.

예:

- `starting`
- `running`
- `completed`
- `stopped`
- `disconnected`
- `error`

### 주요 컬럼

| 컬럼명 | 설명 |
| --- | --- |
| `source_key` | 소스 식별자 |
| `source_type` | 소스 종류 |
| `source_value` | 소스 값 |
| `client_id` | 소유 클라이언트 식별자 |
| `session_id` | 세션 식별자 |
| `state` | 현재 상태 |
| `is_running` | 실행 여부 |
| `source_fps` | 소스 FPS |
| `last_frame_id` | 마지막 처리 프레임 |
| `last_source_time_seconds` | 마지막 처리 시각 |
| `error_message` | 오류 메시지 |
| `updated_at` | 마지막 heartbeat 시각 |
| `payload_json` | 상태 전체 JSON |

### 비고

- 뷰어와 클라이언트 UI의 진행 상태, 오프라인 판정, 최근 갱신 시각 표시 등에 사용됩니다.

---

## 3. frame_detections

클라이언트가 보낸 프레임 단위 탐지 결과 이력을 저장합니다.

### 주요 컬럼

| 컬럼명 | 설명 |
| --- | --- |
| `id` | 자동 증가 PK |
| `source_key` | 소스 식별자 |
| `source_time_seconds` | 원본 영상 기준 시각 |
| `frame_id` | 프레임 번호 |
| `received_at` | 서버 수신 시각 |
| `payload_json` | 탐지 결과 전체 JSON |

### 비고

- 서버 이벤트 판정의 입력 데이터입니다.
- 뷰어의 객체 탐지 박스 표시에도 사용됩니다.

---

## 4. frame_detections_latest

소스별 최신 탐지 결과 1건만 저장하는 캐시 테이블입니다.

### 주요 컬럼

| 컬럼명 | 설명 |
| --- | --- |
| `source_key` | 소스 식별자 |
| `source_time_seconds` | 최신 탐지 시각 |
| `frame_id` | 최신 프레임 번호 |
| `received_at` | 서버 저장 시각 |
| `payload_json` | 최신 탐지 JSON |

### 비고

- 실시간 소스에서 최신 박스를 빠르게 조회할 때 사용합니다.

---

## 5. events

서버가 최종 판정한 이벤트 기록을 저장합니다.

예:

- 안전모 미착용
- 위험구역 진입
- 이벤트 시작/종료

### 주요 컬럼

| 컬럼명 | 설명 |
| --- | --- |
| `id` | 자동 증가 PK |
| `event_key` | 같은 이벤트 흐름을 묶는 키 |
| `event_type` | 이벤트 종류 |
| `status` | `START`, `ACTIVE`, `END` |
| `source_key` | 이벤트가 발생한 소스 |
| `source_type` | 소스 종류 |
| `source_value` | 소스 값 |
| `client_id` | 소유 클라이언트 식별자 |
| `session_id` | 세션 식별자 |
| `source_time_seconds` | 이벤트 시점 |
| `received_at` | 서버 저장 시각 |
| `payload_json` | 이벤트 전체 JSON |

### payload_json 안의 대표 정보

- `message`
- `level`
- `started_source_time_text`
- `ended_source_time_text`
- `clip_url`
- `clip_available`
- `related_detections`

### 비고

- 이벤트 클립은 나중에 업로드되어 기존 이벤트 레코드와 병합될 수 있습니다.

---

## 테이블 관계

핵심 연결 키는 `source_key`입니다.

- `sources`
  - 소스 메타데이터 기준 테이블
- `source_status`
  - 소스별 최신 상태
- `frame_detections`
  - 소스의 탐지 이력
- `frame_detections_latest`
  - 소스의 최신 탐지 캐시
- `events`
  - 소스에서 발생한 이벤트 이력

---

## 실제 데이터 흐름

### 1. 소스 등록

- 클라이언트가 소스를 등록합니다.
- 서버가 `sources`에 저장합니다.

### 2. 분석 진행

- 클라이언트가 로컬에서 객체 탐지를 수행합니다.
- 서버는 탐지 결과를 `frame_detections`와 `frame_detections_latest`에 저장합니다.
- 상태 heartbeat를 `source_status`에 반영합니다.

### 3. 이벤트 판정

- 서버가 `sources.rule_config`와 `frame_detections`를 이용해 이벤트를 판정합니다.
- 결과를 `events`에 저장합니다.

### 4. 조회

- 상태 조회: `source_status`
- 이벤트 조회: `events`
- 탐지 박스 조회: `frame_detections`, `frame_detections_latest`
- 소스 목록 조회: `sources`

---

## 요약

현재 서버 DB는 “클라이언트가 보낸 분석 결과를 중앙 저장하고, 서버가 룰을 적용해 이벤트를 만드는 구조”를 기준으로 설계되어 있습니다.
