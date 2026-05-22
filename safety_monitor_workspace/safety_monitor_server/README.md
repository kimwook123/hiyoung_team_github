# safety_monitor_server

FastAPI 서버이자 분석 orchestration 계층입니다.

## 역할

- 영상 소스 등록 API 제공
- 분석 start/stop/restart 제어
- 서버 내부 분석 worker 관리
- 이벤트 저장
- 프레임 탐지 스냅샷 저장
- 소스 상태 저장
- 클립 저장 및 제공
- GUI 조회 API 제공

## 저장 구조

- DB: `data/monitor.db`
- 클립: `data/clips/`
- 서버 캐시: `data/source_cache/`

주요 테이블:

- `sources`
- `events`
- `frame_detections`
- `frame_detections_latest`
- `source_status`

## 주요 API

### Source Control

- `GET /api/sources`
- `POST /api/sources`
- `POST /api/sources/{source_key}/start`
- `POST /api/sources/{source_key}/stop`
- `POST /api/sources/{source_key}/restart`
- `DELETE /api/sources/{source_key}`

### Event / Detection / Status

- `GET /health`
- `GET /api/events`
- `GET /api/events/latest`
- `GET /api/events/detail`
- `GET /api/events/sources`
- `GET /api/frame-detections/current`
- `GET /api/frame-detections/latest`
- `GET /api/source-status`

### Clip

- `GET /api/clips`
- `GET /api/clips/{clip_name}`

### Admin

- `POST /api/admin/reset-data`

## 분석 worker 구조

- 서버는 등록된 소스마다 worker thread를 띄웁니다.
- worker는 `app/analysis/`의 코어/모델/룰을 직접 사용합니다.
- 결과 저장은 서버 내부 DB/클립 디렉터리로 직접 처리합니다.
- 예전처럼 별도 Python AI Worker 프로세스를 사용자 쪽에서 띄우지 않습니다.

## 실행

```powershell
cd safety_monitor_server
py -3.12 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

또는 루트에서:

```powershell
run_server.bat
```

원격 GUI 클라이언트는 같은 네트워크에서 `http://<서버IP>:8000` 주소로 접속하도록 설정하면 됩니다.
