# app/analysis

서버 내부에서 직접 사용하는 분석 코어 패키지입니다.

## 포함 내용

- `core/`
  - `VideoPipeline`, frame source, tracker, clip recorder
- `models/`
  - dummy / single YOLO / ensemble YOLO 모델 어댑터
- `rules/`
  - 안전모 미착용, 위험구역 등 이벤트 룰

## 원칙

- 이 폴더는 더 이상 독립 Python worker 앱이 아닙니다.
- 분석 시작/중지/재시작은 `app/source_manager.py`가 관리합니다.
- 이벤트/프레임 탐지/상태 저장은 `app/analysis_runtime.py`의 서버 전용 handler/recorder가 맡습니다.
- 클립 메타데이터는 DB와 이벤트 payload에 상대경로 기준으로 저장합니다.
