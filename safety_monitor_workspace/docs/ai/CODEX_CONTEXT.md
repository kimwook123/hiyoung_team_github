# CODEX_CONTEXT.md

## 프로젝트 한 줄 요약

Windows 환경에서 Python AI Worker가 여러 영상 소스를 분석하고, FastAPI 서버가 결과를 SQLite에 저장하며, Flutter GUI가 서버에서 조회해 시각화하는 안전 모니터링 프로젝트입니다.

## 현재 목표 구조

- Python AI Worker
  - 이벤트, 프레임 탐지, 소스 상태, 클립 생성 및 서버 전송
- FastAPI Server
  - SQLite 이벤트 저장소와 클립 파일 저장소 제공
- Flutter GUI
  - 멀티소스 등록, 영상 재생, 서버 조회, 오버레이 표시

## 디렉터리 구조 요약

- `safety_ai_monitor/`
  - Python AI Worker
- `safety_monitor_server/`
  - FastAPI 서버
  - `data/monitor.db`
  - `data/clips/`
- `safety_ai_monitor_ui/`
  - Flutter GUI
- `docs/`
  - 구조, 운영 메모, 작업 로그

## Python AI Worker 역할

- 영상 파일, 스트림, 카메라 입력 열기
- YOLO 또는 `yolo_ensemble` 모델 로드
- 프레임별 객체 탐지
- 사람 추적
- 룰 기반 이벤트 생성
- 이벤트 클립 생성
- `POST /api/events`
- `POST /api/frame-detections`
- `POST /api/source-status`
- 필요 시 `POST /api/clips`

## FastAPI Server 역할

- SQLite DB 초기화와 저장
- 이벤트 목록/상세/최신 상태 조회
- 프레임 탐지 현재 시점 조회
- 소스 상태 조회
- 소스별 reset
- 서버 클립 업로드와 재생 URL 제공

현재 주요 API:

- `GET /health`
- `POST /api/events`
- `GET /api/events`
- `GET /api/events/latest`
- `GET /api/events/sources`
- `GET /api/events/detail`
- `POST /api/frame-detections`
- `GET /api/frame-detections/current`
- `POST /api/source-status`
- `GET /api/source-status`
- `POST /api/clips`
- `GET /api/clips/{clip_name}`
- `POST /api/admin/reset-data`

## Flutter GUI 역할

- 영상 파일 선택
- 스트림 등록
- 유튜브 링크 입력 후 자동 변환
- 멀티소스 슬롯/탭 관리
- 현재 활성 소스 재생
- 비활성 소스 자동 일시정지
- 이벤트 목록/상세 표시
- 현재 프레임 객체 탐지 박스 오버레이
- 이벤트 시작 시점 이동
- 이벤트 클립 재생 및 원본 복귀

## 현재 연결 방식

### 1. GUI -> Python

- `source_state.json`
- `sources_state.json`

### 2. Python -> Server

- 이벤트 POST
- 프레임 탐지 POST
- 소스 상태 POST
- 클립 업로드 POST

### 3. GUI -> Server

- health 조회
- 이벤트 목록/상세 조회
- 프레임 탐지 현재 시점 조회
- 소스 상태 조회
- 클립 재생 URL 조회

## 중요한 현재 사실

- GUI는 더 이상 `frame_detections.jsonl`이나 `ui_bridge.json`에 의존하지 않습니다.
- GUI는 서버 상태를 기준으로 FPS, 분석 상태, 박스 표시 이유를 판단합니다.
- Python은 등록된 모든 소스를 병렬 분석하고, GUI의 활성 탭은 조회 집중 대상만 의미합니다.
- 같은 소스를 다시 등록하면 새 슬롯을 만들지 않고 기존 슬롯으로 전환합니다.

## 새 작업 시작 시 먼저 볼 파일

- Python 분석/멀티소스:
  - `safety_ai_monitor/main.py`
  - `safety_ai_monitor/config.py`
  - `safety_ai_monitor/core/pipeline.py`
- 서버 저장/조회:
  - `safety_monitor_server/app/database.py`
  - `safety_monitor_server/app/routers/events.py`
  - `safety_monitor_server/app/routers/frame_detections.py`
  - `safety_monitor_server/app/routers/source_status.py`
- GUI 멀티소스/오버레이:
  - `safety_ai_monitor_ui/lib/screens/home_screen.dart`
  - `safety_ai_monitor_ui/lib/controllers/video_panel_controller.dart`
  - `safety_ai_monitor_ui/lib/services/event_api_service.dart`

## 주의할 점

- `source_state.json`은 활성 소스 호환용이고, 멀티소스 실체는 `sources_state.json`입니다.
- 이벤트 오버레이는 이벤트 로그가 아니라 프레임 탐지 스냅샷을 기준으로 합니다.
- 서버 저장소는 DB 중심이지만, 클립은 파일 저장소를 병행합니다.
- `source_key`를 기준으로 동작하는 코드가 많으므로, 소스 정규화 규칙을 함부로 바꾸면 안 됩니다.
