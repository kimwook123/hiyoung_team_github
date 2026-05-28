# 서버 DB 스키마 문서

이 문서는 `safety_monitor_server`가 사용하는 SQLite DB의 저장 구조를 설명합니다.

- DB 파일 위치: `safety_monitor_server/data/monitor.db`
- 초기화 코드 기준: `safety_monitor_server/app/database.py`
- DB 엔진: SQLite

## 개요

서버 DB는 크게 4가지 역할을 담당합니다.

- 분석 이벤트 저장
- 프레임 단위 탐지 결과 저장
- 소스별 최신 상태 저장
- 등록된 영상/스트림 소스 메타데이터 저장

## 테이블 목록

- `events`
- `frame_detections`
- `frame_detections_latest`
- `source_status`
- `sources`

---

## 1. events

분석 중 발생한 이벤트 로그를 시간순으로 저장합니다.

예:

- 안전모 미착용 이벤트
- 위험구역 진입 이벤트
- 이벤트의 시작/활성/종료 상태

### 컬럼

| 컬럼명 | 타입 | 설명 |
| --- | --- | --- |
| `id` | INTEGER | 자동 증가 PK |
| `event_key` | TEXT | 같은 이벤트 흐름을 묶는 키 |
| `event_type` | TEXT | 이벤트 종류 |
| `status` | TEXT | 이벤트 상태. 예: `START`, `ACTIVE`, `END` |
| `source_key` | TEXT | 이벤트가 발생한 소스 식별자 |
| `source_type` | TEXT | 소스 종류. 예: `video`, `stream`, `camera` |
| `source_value` | TEXT | 소스 원본 값 또는 정규화된 경로 |
| `client_id` | TEXT | 요청/등록 클라이언트 식별자 |
| `session_id` | TEXT | 세션 식별자 |
| `source_time_seconds` | REAL | 원본 영상 기준 시각(초) |
| `received_at` | TEXT | 서버 저장 시각 |
| `payload_json` | TEXT | 이벤트 전체 JSON 원문 |

### 인덱스

- `idx_events_source_key`
  - `(source_key, id)`
- `idx_events_event_key`
  - `(event_key, id)`

### 비고

- 실제 화면/API에서 쓰는 대부분의 상세 정보는 `payload_json` 안에 들어 있습니다.
- 예를 들어 `message`, `level`, `clip_url`, `started_source_time_text`, `ended_source_time_text`, `related_detections` 등이 함께 저장됩니다.

---

## 2. frame_detections

프레임 단위의 객체 탐지 결과를 시간순으로 누적 저장합니다.

예:

- 특정 시점의 사람/person 박스
- helmet/head 탐지 결과
- 프레임 크기, 탐지 목록

### 컬럼

| 컬럼명 | 타입 | 설명 |
| --- | --- | --- |
| `id` | INTEGER | 자동 증가 PK |
| `source_key` | TEXT | 소스 식별자 |
| `source_time_seconds` | REAL | 원본 영상 기준 시각(초) |
| `frame_id` | INTEGER | 프레임 번호 |
| `received_at` | TEXT | 서버 저장 시각 |
| `payload_json` | TEXT | 프레임 탐지 전체 JSON 원문 |

### 인덱스

- `idx_frame_detections_source_time`
  - `(source_key, source_time_seconds, id)`

### 비고

- 특정 영상 시간대에 가장 가까운 탐지 결과를 찾기 위해 사용됩니다.
- GUI의 객체 탐지 박스 오버레이가 이 테이블을 기반으로 동작합니다.

---

## 3. frame_detections_latest

소스별 “가장 최근 프레임 탐지 결과 1건”만 유지하는 캐시 테이블입니다.

### 컬럼

| 컬럼명 | 타입 | 설명 |
| --- | --- | --- |
| `source_key` | TEXT | PK, 소스 식별자 |
| `source_time_seconds` | REAL | 최신 탐지 시각(초) |
| `frame_id` | INTEGER | 최신 프레임 번호 |
| `received_at` | TEXT | 저장 시각 |
| `payload_json` | TEXT | 최신 프레임 탐지 JSON |

### 비고

- 실시간 스트림/카메라처럼 “지금 가장 최신 탐지 결과”가 필요한 경우 빠르게 조회하기 위해 사용합니다.
- `frame_detections` 전체를 뒤지지 않게 해 주는 캐시 역할입니다.

---

## 4. source_status

현재 서버가 알고 있는 소스별 실행 상태를 저장합니다.

예:

- 분석 시작 중
- 실행 중
- 재연결 중
- 완료
- 오류

### 컬럼

| 컬럼명 | 타입 | 설명 |
| --- | --- | --- |
| `source_key` | TEXT | PK, 소스 식별자 |
| `source_type` | TEXT | 소스 종류 |
| `source_value` | TEXT | 소스 값 |
| `client_id` | TEXT | 등록 클라이언트 식별자 |
| `session_id` | TEXT | 세션 식별자 |
| `state` | TEXT | 현재 상태. 예: `starting`, `running`, `completed`, `error` |
| `is_running` | INTEGER | 실행 여부. `0` 또는 `1` |
| `source_fps` | REAL | 소스 FPS |
| `last_frame_id` | INTEGER | 마지막 처리 프레임 번호 |
| `last_source_time_seconds` | REAL | 마지막 처리 영상 시각(초) |
| `error_message` | TEXT | 오류 메시지 |
| `updated_at` | TEXT | 상태 갱신 시각 |
| `payload_json` | TEXT | 상태 전체 JSON |

### 비고

- GUI에서 “분석중”, “분석 완료”, “오류”, 진행률 표시 등에 사용됩니다.
- 비디오 재분석 재시작 시 이어받기 판단에도 활용됩니다.

---

## 5. sources

서버에 등록된 영상/스트림 소스 자체의 메타데이터를 저장합니다.

### 컬럼

| 컬럼명 | 타입 | 설명 |
| --- | --- | --- |
| `source_key` | TEXT | PK, 소스 식별자 |
| `source_slug` | TEXT | 파일명/표시용 슬러그 |
| `source_type` | TEXT | 소스 종류 |
| `source_value` | TEXT | 정규화된 소스 값 |
| `original_source_type` | TEXT | 원래 요청된 소스 종류 |
| `original_source_value` | TEXT | 원래 요청된 소스 값 |
| `client_id` | TEXT | 등록 클라이언트 식별자 |
| `session_id` | TEXT | 세션 식별자 |
| `desired_running` | INTEGER | 서버가 이 소스를 계속 돌릴지 여부 |
| `created_at` | TEXT | 등록 시각 |
| `updated_at` | TEXT | 마지막 수정 시각 |
| `payload_json` | TEXT | 소스 전체 JSON |

### payload_json 내부 주요 필드

현재 구현상 중요한 부가 정보는 `payload_json` 안에 함께 저장됩니다.

예:

- `source_duration_seconds`
- `rule_config`
- `media_url`
- `server_media_path`

### rule_config 예시

```json
{
  "use_no_helmet_rule": true,
  "use_danger_zone_rule": false,
  "danger_zone_roi": {
    "x1": 100,
    "y1": 120,
    "x2": 420,
    "y2": 360
  }
}
```

### 비고

- 소스별 룰 설정은 별도 테이블이 아니라 `sources.payload_json` 내부에 저장됩니다.
- 비디오 소스에서 룰이 바뀌면 서버는 이 설정을 읽고 해당 소스를 처음부터 재분석할 수 있습니다.

---

## 테이블 간 관계

명시적인 FK 제약은 없지만, 논리적으로는 아래 관계를 가집니다.

- `sources.source_key`
  - 기준 키
- `source_status.source_key`
  - `sources`의 현재 상태
- `events.source_key`
  - `sources`에서 발생한 이벤트
- `frame_detections.source_key`
  - `sources`의 프레임 탐지 이력
- `frame_detections_latest.source_key`
  - `sources`의 최신 프레임 탐지 캐시

---

## 데이터 흐름

### 1. 소스 등록

- 클라이언트가 소스를 등록
- 서버가 `sources`에 저장
- 초기 상태를 `source_status`에 반영

### 2. 분석 진행

- 워커가 프레임을 읽음
- 탐지 결과를 `frame_detections`, `frame_detections_latest`에 저장
- 상태를 `source_status`에 갱신

### 3. 이벤트 발생

- 룰 판단 결과를 `events`에 저장
- 필요 시 클립 경로/URL도 이벤트 payload에 포함

### 4. GUI 조회

- 이벤트 로그: `events`
- 탐지 박스: `frame_detections`, `frame_detections_latest`
- 진행 상태: `source_status`
- 등록 소스 목록: `sources`

---

## 정리

핵심 기준 키는 `source_key`입니다.

- 소스 메타데이터는 `sources`
- 현재 실행 상태는 `source_status`
- 이벤트 이력은 `events`
- 프레임 탐지 이력은 `frame_detections`
- 최신 프레임 탐지는 `frame_detections_latest`

현재 구조는 “정규 컬럼 + 상세 JSON payload” 혼합 방식입니다.
즉, 자주 필터링/정렬하는 항목은 컬럼으로 따로 두고, 상세 정보는 `payload_json`에 함께 저장하는 형태입니다.
