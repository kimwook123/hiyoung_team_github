# app/analysis

서버 내부에서 직접 사용하는 분석 코어 패키지입니다.

## 구성

- `core/`
  - `VideoPipeline`, frame source, tracker, clip recorder
- `models/`
  - dummy, 단일 YOLO, ensemble YOLO 모델 어댑터
- `rules/`
  - 안전모 미착용, 위험구역 등 이벤트 룰

## 현재 원칙

- 이 폴더는 독립 실행형 worker 앱이 아니라 서버 내부 패키지입니다.
- 분석 시작과 중지, 재시작은 `app/source_manager.py`가 관리합니다.
- 이벤트, 프레임 탐지, 상태 저장은 `app/analysis_runtime.py`가 맡습니다.
- 클립 메타데이터는 DB와 이벤트 payload에 상대경로 기준으로 저장합니다.
- 기본 모델 경로는 `models/weights/best.pt`입니다.
- 같은 이름의 `best.engine`이 있으면 TensorRT 엔진을 우선 사용합니다.
- YOLO 모델 로딩 시 `task="detect"`를 명시합니다.
- 비디오 진행 시간은 OpenCV `POS_MSEC` 값이 불안정할 때 프레임 번호 기반 시간 보정 로직을 사용합니다.
