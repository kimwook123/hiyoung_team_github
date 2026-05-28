# safety_monitor_server

FastAPI 서버이자 분석 orchestration 계층입니다.

## 역할

- 영상 소스 등록 API 제공
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
- 업로드 원본 영상: `data/uploaded_sources/`

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

### Clip

- `GET /api/clips`
- `GET /api/clips/{clip_name}`

### Source Media

- `GET /api/source-media/uploaded/{file_name}`
- `GET /api/source-media/cached/{file_name}`

### Admin

- `POST /api/admin/reset-data`

## 분석 worker 구조

- 서버는 등록된 소스마다 worker thread를 띄웁니다.
- worker는 `app/analysis/`의 코어/모델/룰을 직접 사용합니다.
- 결과 저장은 서버 내부 DB/클립 디렉터리로 직접 처리합니다.
- 예전처럼 별도 Python AI Worker 프로세스를 사용자 쪽에서 띄우지 않습니다.
- 파일 영상은 미완료 상태면 서버 재시작 후 자동 이어받기됩니다.
- 스트림/CCTV 소스는 끊기면 `reconnecting` 상태로 두고 재시도합니다.
- 기본 YOLO 설정은 `app/config.py` 기준 `MODEL_TYPE="yolo"`, `ANALYSIS_DEVICE="cuda:0"`, `PREFER_TENSORRT_ENGINE=True` 입니다.
- 동일 이름의 `.engine` 파일이 있으면 TensorRT 엔진을 우선 사용하고, 없거나 사용 불가하면 `.pt` 모델로 동작합니다.
- 소스별 프레임 탐지 스냅샷은 GUI 오버레이 기준 시간축에 맞춰 `frame_detections`와 `frame_detections_latest`에 저장됩니다.
- 클립 메타데이터는 이벤트 payload 안에 `clip_url`, `server_clip_path`, `server_clip_name`, `preferred_clip_source` 형태로 함께 저장됩니다.

## 서버 콘솔 로그

- `[REQ]`: 개별 HTTP 요청 처리 로그입니다. 중요한 요청이나 에러 요청을 한 건씩 보여줍니다.
- `[REQ-SUM]`: 고빈도 polling 요청 요약 로그입니다. `frame-detections/current`, `source-status`, `sources`, `events` 등을 몇 초 단위로 묶어 보여줍니다.
- `[SRC]`: 소스 lifecycle 로그입니다. 등록 소스의 시작, 열기, 모델 준비, 재시도, 종료 같은 흐름을 보여줍니다.
- `[PROGRESS]`: 현재 분석 진행 상태입니다. 파일 영상은 `현재초/전체초(%)`, 스트림은 마지막 처리 시각 중심으로 표시됩니다.
- `[PERF]`: 분석 파이프라인 성능 로그입니다. `model_predict`, `frame_total` 같은 평균 처리 시간을 보여줍니다.
- `[WARN]`: 치명적이지는 않지만 확인이 필요한 경고입니다. 예: POST 실패, OpenCV 표시 실패.
- `[ERROR]`: 실제 실패에 가까운 로그입니다. 예: worker 예외, 요청 처리 예외.

태그별 색상도 같이 적용됩니다.

- 하늘색: `[REQ]`, 청록색: `[REQ-SUM]`
- 파란색: `[SRC]`
- 초록색: `[PROGRESS]`
- 자주색: `[PERF]`
- 노란색: `[WARN]`
- 빨간색: `[ERROR]`

## 실행

```powershell
cd safety_monitor_server
py -3.12 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

또는 루트에서:

```powershell
run_server.bat
```

- `run_server.bat`는 서버 의존성을 자동 점검하고, 없으면 설치 여부를 묻습니다.
- 원격 GUI 클라이언트는 같은 네트워크에서 `http://<서버IP>:8000` 주소로 접속하도록 설정하면 됩니다.
