# safety_ai_monitor

Python AI Worker 레이어입니다.

이 폴더는 입력 소스를 분석하고 이벤트와 이벤트 클립을 생성합니다.  
GUI를 직접 렌더링하지 않고, 설정에 따라 로컬 로그를 남기거나 FastAPI 서버로 이벤트를 전송합니다.

## 역할

- 영상 파일, 스트림, 카메라 입력 분석
- 객체 검출과 사람 추적
- 룰 기반 이벤트 생성
- txt 이벤트 로그 유지
- 로컬 JSONL 기록 또는 HTTP 이벤트 전송
- 이벤트 클립 생성
- 서버 전송 실패 시 fallback JSONL 저장

## 이벤트 출력 모드

### 로컬 JSONL 모드

- `ENABLE_HTTP_EVENT_POST = False`
- `ENABLE_JSON_EVENT_LOG = True`
- Python이 `logs/events.jsonl`을 직접 기록합니다.

### 서버 전송 모드

- `ENABLE_HTTP_EVENT_POST = True`
- Python이 `POST /api/events`로 이벤트를 전송합니다.
- 서버가 `safety_monitor_server/data/events.jsonl` 저장 책임을 가집니다.

### 서버 전송 + 클립 업로드 모드

- `ENABLE_HTTP_EVENT_POST = True`
- `ENABLE_EVENT_CLIP_UPLOAD = True`
- 이벤트 종료 시 `clip_path`가 있으면 `POST /api/clips` 업로드를 시도할 수 있습니다.
- 업로드 성공 시 이벤트 payload에 `clip_url`, `server_clip_path`, `server_clip_name`, `clip_upload_ok`가 추가될 수 있습니다.

## 주요 출력 파일

- txt 로그: `logs/*_event_log.txt`
- 로컬 JSONL: `logs/events.jsonl`
- fallback 이벤트: `logs/events_post_failed.jsonl`
- 재전송 성공 로그: `logs/events_post_reposted_success.jsonl`
- 재전송 실패 로그: `logs/events_post_repost_failed.jsonl`
- 이벤트 클립: `logs/clips/*.mp4`
- GUI 브리지: `logs/ui_bridge.json`
- 입력 상태: `logs/source_state.json`

## 관련 설정

파일: `config.py`

- `INPUT_MODE`
- `MODEL_TYPE`
- `MODEL_PATH`
- `ENABLE_JSON_EVENT_LOG`
- `ENABLE_HTTP_EVENT_POST`
- `EVENT_POST_URL`
- `ENABLE_HTTP_EVENT_FALLBACK_JSON`
- `ENABLE_EVENT_CLIP_UPLOAD`
- `EVENT_CLIP_UPLOAD_URL`
- `SAVE_EVENT_CLIP`

설정값은 실험 중 바뀔 수 있으므로, 실행 전 실제 `config.py`를 다시 확인하는 것을 권장합니다.

## 실행

루트에서:

- `run_python_only.bat`
- `run_python_and_gui.bat`
- `run_python_server_and_gui.bat`

직접 실행:

```powershell
cd safety_ai_monitor
py -3.12 main.py
```

## 재전송 유틸리티

서버가 꺼져 있거나 전송에 실패하면 fallback JSONL이 쌓일 수 있습니다.

- 루트 배치: `run_repost_failed_events.bat`
- 스크립트: `tools/repost_failed_events.py`

원본 fallback 파일은 삭제하지 않고, 성공/실패 결과를 별도 JSONL로 남깁니다.

## 관련 문서

- 루트 실행 안내: [../README.md](../README.md)
- 서버 구조: [../safety_monitor_server/README.md](../safety_monitor_server/README.md)
- GUI 구조: [../safety_ai_monitor_ui/README.md](../safety_ai_monitor_ui/README.md)
- 구조 노트: [../docs/ai/ARCHITECTURE_NOTES.md](../docs/ai/ARCHITECTURE_NOTES.md)
- 이벤트 JSON 스키마: [../docs/ai/event_json_schema.md](../docs/ai/event_json_schema.md)
