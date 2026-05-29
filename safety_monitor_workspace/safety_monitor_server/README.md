# safety_monitor_server

영상 분석과 데이터 저장을 담당하는 `FastAPI` 서버입니다.

## 역할

- 영상 파일과 스트림 소스 등록 API 제공
- 등록 소스별 분석 worker 관리
- 이벤트, 프레임 탐지, 소스 상태 저장
- 클립 저장과 정적 제공
- GUI 조회용 API 제공

## 저장 구조

- DB: `data/monitor.db`
- 클립: `data/clips/`
- 서버 캐시: `data/source_cache/`
- 업로드 원본 영상: `data/uploaded_sources/`

주요 테이블:

- `sources`
- `events`
- `frame_detections`
- `frame_detections_latest`
- `source_status`

## 분석 동작

- 서버는 등록된 소스마다 worker thread를 실행합니다.
- worker는 `app/analysis/`의 코어, 모델, 룰을 직접 사용합니다.
- 결과 저장은 서버 내부 DB와 클립 디렉터리로 직접 처리합니다.
- 별도 Python AI worker 프로세스를 따로 실행하지 않습니다.
- 파일 영상은 미완료 상태면 서버 재시작 후 이어서 분석합니다.
- 스트림 소스는 끊기면 `reconnecting` 상태로 두고 재시도합니다.
- 기본 YOLO 설정은 `app/config.py` 기준 `MODEL_TYPE="yolo"`, `ANALYSIS_DEVICE="cuda:0"`, `PREFER_TENSORRT_ENGINE=True` 입니다.
- 같은 이름의 `.engine` 파일이 있으면 TensorRT 엔진을 우선 사용하고, 없거나 실패하면 `.pt` 모델로 동작합니다.
- 프레임 탐지 스냅샷은 `frame_detections`와 `frame_detections_latest`에 저장됩니다.
- 클립 메타데이터는 이벤트 payload에 `clip_url`, `server_clip_path`, `server_clip_name`, `preferred_clip_source` 형태로 함께 저장됩니다.

## 주요 API

### Source Control

- `GET /api/sources`
- `POST /api/sources`
- `POST /api/sources/upload`
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

### Clip / Media

- `GET /api/clips`
- `GET /api/clips/{clip_name}`
- `GET /api/source-media/uploaded/{file_name}`
- `GET /api/source-media/cached/{file_name}`

### Admin

- `POST /api/admin/reset-data`

## 서버 로그

- `[REQ]`: 개별 HTTP 요청
- `[REQ-SUM]`: 고빈도 polling 요청 요약
- `[SRC]`: 소스 lifecycle
- `[PROGRESS]`: 분석 진행 상태
- `[PERF]`: 프레임 처리 성능, 프레임 1장당 평균 분석 시간
- `[WARN]`: 경고
- `[ERROR]`: 예외와 실패

## 실행

```powershell
cd safety_monitor_server
py -3.12 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

또는 루트에서:

```powershell
run_server.bat
```

- `run_server.bat`는 의존성을 자동 점검하고 필요 시 설치를 유도합니다.
- 원격 GUI는 `http://<서버IP>:8000` 주소로 접속할 수 있습니다.
