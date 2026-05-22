# ARCHITECTURE_NOTES.md

## 현재 목표 구조

- `Server`
  - 소스 등록 API
  - 분석 작업 관리
  - 분석 worker 실행
  - 이벤트/프레임 탐지/상태/클립 저장
  - GUI 조회 API
- `Client`
  - 영상 재생
  - 소스 등록 요청
  - 소스 목록/상태 조회
  - 이벤트/클립/박스 조회

## 현재 실제 분리 상태

### 서버

- FastAPI 앱: `safety_monitor_server/`
- 분석 worker manager: `app/source_manager.py`
- 분석 런타임 조립: `app/analysis_runtime.py`
- 저장소:
  - `data/monitor.db`
  - `data/clips/`
  - `data/source_cache/`

### 클라이언트

- Flutter GUI: `safety_ai_monitor_ui/`
- 영상은 로컬 플레이어에서 직접 재생
- 분석 결과는 서버에서만 조회

### 분석 패키지

- `safety_monitor_server/app/analysis/`
- 독립 실행 진입점 없이 서버가 내부적으로 직접 사용

## 데이터 흐름

### 1. 소스 등록

- GUI `POST /api/sources` 또는 `POST /api/sources/upload`
- 서버가 입력 소스를 정규화
- 필요하면 유튜브 링크를 서버 캐시 mp4로 변환
- 로컬 영상 파일은 서버 `uploaded_sources`로 업로드
- 서버가 `source_key` / `source_slug` 생성
- 서버가 source row 저장 후 worker 시작

### 2. 분석

- 서버 worker가 소스를 열고 `VideoPipeline` 실행
- 사람 탐지 / 안전모 탐지 / 룰 평가 수행
- 이벤트 클립 생성

### 3. 저장

- 이벤트 -> `events`
- 프레임 탐지 -> `frame_detections`, `frame_detections_latest`
- 소스 상태 -> `source_status`
- 소스 등록 정보 -> `sources`
- 클립 mp4 -> `data/clips/`

### 4. 조회

- GUI는 `source_key` 기준으로 이벤트와 박스를 조회
- 현재 선택된 소스가 있으면 해당 소스 로그만 표시
- 선택이 없으면 전체 로그 표시
- 서버 등록 소스는 GUI에서 다시 `화면에 열기` 가능

## 멀티소스

- 서버는 소스별 worker thread를 관리
- GUI의 활성 소스 전환은 재생/조회 집중 대상 전환 의미
- 비활성 소스도 서버 분석은 계속 가능
- GUI 플레이어는 비활성 소스를 pause
- 파일 영상은 미완료면 서버 재시작 후 이어서 분석
- 스트림/CCTV는 연결 오류 시 `reconnecting` 상태로 재시도

## 설계상 장점

- GUI와 분석 worker의 직접 파일 브리지 제거
- 소스 등록/분석/저장 책임이 서버로 집중
- 멀티클라이언트 구조 설명이 쉬움
- 독립 Python worker 실행이 없어 운영 단순화

## 현재 남는 한계

- GUI 재생과 서버 분석은 같은 디코더를 공유하지 않으므로 완전 프레임 일치는 아님
- DB는 SQLite라 대규모 동시 writer 환경에서는 한계가 있음
- 클라이언트가 원격 서버에 붙으려면 서버 IP 또는 호스트명을 알아야 하며, 현재는 자동 발견이 아니라 수동 입력/저장 방식입니다.
