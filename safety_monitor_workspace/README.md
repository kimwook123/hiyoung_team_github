# Safety AI Monitor

Python 기반 위험 감지 파이프라인과 Flutter 기반 GUI를 함께 사용하는 Windows 프로젝트입니다.

- Python 레이어: 영상/스트림 입력, 객체 검출, 추적, 위험 이벤트 판정, 로그/클립 저장
- Flutter 레이어: 영상 재생, 스트림 열기, 로그 모니터링, 이벤트 오버레이 표시

## 현재 확인한 상태

- Python 3.12에서 백엔드 실행 확인
- `test.mp4` 입력으로 추론, 이벤트 로그, 이벤트 클립 저장 확인
- Flutter SDK 설치 및 프로젝트 의존성 해석 확인
- Flutter Windows 빌드는 Windows `개발자 모드(Developer Mode)`가 꺼져 있으면 플러그인 심볼릭 링크 단계에서 막힘

## 디렉터리 구조

```text
.
├─ safety_ai_monitor/
│  ├─ main.py
│  ├─ config.py
│  ├─ requirements.txt
│  ├─ core/
│  ├─ handlers/
│  ├─ models/
│  │  └─ weights/
│  ├─ rules/
│  └─ logs/
├─ safety_ai_monitor_ui/
├─ flutter/
├─ run_python_and_gui.bat
├─ run_gui_only.bat
├─ run_flutter_debug.bat
└─ build_gui.bat
```

## 권장 실행 환경

- Windows 10/11
- Python `3.12.x`
- Flutter `3.41.x`
- Visual Studio 2022 Build Tools

## Python 설치 및 실행

프로젝트 기준으로 설치:

```powershell
py -3.12 -m pip install -r safety_ai_monitor\requirements.txt
```

백엔드 단독 실행:

```powershell
cd safety_ai_monitor
py -3.12 main.py
```

주의:

- `config.py`의 기본값은 `INPUT_MODE = "gui"` 입니다.
- GUI 모드에서는 Python이 시작된 뒤 GUI가 `source_state.json`에 입력 소스를 써줘야 실제 분석이 시작됩니다.

## Flutter 설치 및 실행

이 저장소는 워크스페이스 루트의 `flutter\bin\flutter.bat`를 사용하도록 배치 파일이 작성되어 있습니다.

### 1. GUI 의존성 받기

```powershell
cd safety_ai_monitor_ui
..\flutter\bin\flutter.bat pub get
```

### 2. 디버그 실행

```powershell
run_flutter_debug.bat
```

### 3. Windows 빌드

```powershell
build_gui.bat
```

중요:

- `media_kit` 플러그인 때문에 Windows 심볼릭 링크 권한이 필요합니다.
- `Building with plugins requires symlink support` 오류가 나면 Windows 개발자 모드를 켜야 합니다.

## 전체 실행

GUI가 이미 빌드된 상태라면:

```powershell
run_python_and_gui.bat
```

이 스크립트는:

1. `safety_ai_monitor\main.py`를 Python 3.12로 실행
2. 3초 대기
3. 빌드된 GUI exe 실행

## 입력 정책

### 영상 파일 / 스트림 선택

- `config.py`에 영상 파일 경로를 직접 적지 않습니다.
- 영상 파일과 스트림 주소는 GUI에서 선택합니다.
- Python은 `safety_ai_monitor/logs/source_state.json`을 읽어 현재 입력 대상을 결정합니다.
- 카메라만 예외적으로 `config.py`의 `INPUT_MODE = "camera"`, `CAMERA_INDEX`를 사용합니다.

### 입력 변경

- GUI에서 다른 영상 파일 또는 스트림으로 바꾸면 Python 파이프라인은 현재 분석을 정리한 뒤 새 입력으로 재시작합니다.
- 짧은 전환 시간은 있을 수 있습니다.

### GUI 시작 시 상태

- GUI는 항상 빈 상태로 시작합니다.
- 이전에 열었던 영상/스트림을 자동 복구하지 않습니다.

## 로그 정책

### 로그 파일 위치

- 영상 파일: `logs/<영상파일명>_event_log.txt`
- 스트림: `logs/stream_event_log.txt`
- 기타: `config.py`의 `LOG_PATH`

예:

- `test.mp4` -> `logs/test_event_log.txt`

### 기록 방식

- 이벤트 1건당 1줄 형식으로 관리합니다.
- 이벤트 시작 직후 바로 한 줄이 생깁니다.
- 이벤트가 진행 중이면 같은 `event_key`의 최신 줄이 계속 추가 기록됩니다.
- 이벤트 종료 시 같은 키의 마지막 줄에 `end`, `end_frame`, `duration`, `clip_path`가 채워집니다.

### 시간 기준

- 영상 파일 입력은 PC 현재 시간이 아니라 영상 시간 기준으로 기록합니다.
  - 예: `00:08.160`
- 스트림/카메라는 현재 시각 기준 문자열을 사용합니다.

## 이벤트 클립 정책

- `SAVE_EVENT_CLIP = True`면 이벤트별 클립을 저장합니다.
- 저장 위치: `safety_ai_monitor/logs/clips`
- `EVENT_CLIP_BEFORE_SECONDS`만큼 이벤트 직전 프레임도 포함합니다.

## 현재 모델/가중치 교체 시 반드시 맞아야 하는 조건

이 프로젝트는 "모델만 바꾸면 자동 적응" 구조가 아닙니다. 현재 룰은 **검출 클래스 이름 문자열**에 의존합니다.

### 현재 룰이 기대하는 클래스 이름

- `NoHelmetRule`: `person`, `helmet`
- `DangerZoneRule`: `person`

### 현재 확인한 기본 가중치 파일

- 파일: `safety_ai_monitor/models/weights/best.pt`
- 클래스: `head`, `helmet`, `person`, `vest`

### 실제 분석 결과

`test.mp4` 기준으로 현재 가중치는 대부분 프레임에서 `person`, `vest`를 검출했고 `helmet` 검출은 거의 없었습니다.

그 결과:

- `NoHelmetRule`이 거의 전 구간에서 3명 모두를 `NO_HELMET`로 판단
- 로그와 클립은 정상 생성
- 즉 "프로그램은 동작"하지만 "의도한 의미로 정확히 동작"한다고 보기는 어렵습니다

### 결론

모델/가중치만 교체해서 잘 동작하려면 아래 둘 중 하나가 맞아야 합니다.

1. 새 모델이 `person`, `helmet` 클래스를 정확히 같은 이름으로 출력해야 합니다.
2. 새 모델 클래스 이름에 맞게 룰 코드를 함께 수정해야 합니다.

예:

- 모델이 `hardhat`을 출력하는데 룰은 `helmet`만 찾으면 계속 오탐이 납니다.
- 모델이 `head`만 출력하고 `helmet` 검출이 약하면 현재 룰은 장시간 `NO_HELMET`를 띄웁니다.

## 모델 및 가중치 파일 교체 방법

### 1. 가중치 파일 교체

- 새 가중치 파일을 `safety_ai_monitor/models/weights/` 아래에 둡니다.
- `config.py`의 `MODEL_PATH`를 바꿉니다.

예:

```python
MODEL_TYPE = "yolo"
MODEL_PATH = "models/weights/my_new_model.pt"
```

### 2. 출력 클래스 이름 확인

교체 후 아래처럼 확인하는 것을 권장합니다.

```powershell
py -3.12 -c "from ultralytics import YOLO; m=YOLO(r'safety_ai_monitor\models\weights\my_new_model.pt'); print(m.names)"
```

### 3. 룰과 클래스 매칭 확인

반드시 아래를 확인하세요.

- 사람 클래스 이름이 `person`인지
- 안전모 클래스 이름이 `helmet`인지
- 추가로 필요한 클래스가 있는지

### 4. 필요한 경우 룰 수정

예를 들어 모델이 `hardhat`을 쓰면 `rules/no_helmet_rule.py`에서 `helmet` 대신 `hardhat`을 보도록 수정해야 합니다.

## `dummy` / `yolo` 말고 다른 계열 모델 추가 방법

새 모델을 붙이는 작업은 단순히 `MODEL_TYPE` 문자열만 늘리는 것이 아니라, 프로젝트 공통 검출 형식으로 변환하는 어댑터를 하나 추가하는 방식입니다.

### 1. `DetectionModel` 구현체 파일 추가

파일 예: `safety_ai_monitor/models/my_detector_model.py`

반드시 아래 3개 메서드를 구현해야 합니다.

- `load()`
- `predict(frame, frame_id)`
- `get_name()`

기준 인터페이스는 `safety_ai_monitor/core/detection_model.py`의 `DetectionModel`입니다.

예:

```python
import numpy as np

from core.detection_model import Box, Detection, DetectionModel, DetectionResult


class MyDetectorModel(DetectionModel):
    def __init__(self, model_path: str, min_confidence: float = 0.5) -> None:
        self.model_path = model_path
        self.min_confidence = min_confidence
        self.model = None

    def load(self) -> None:
        # 모델 파일 로드
        pass

    def predict(self, frame: np.ndarray, frame_id: int) -> DetectionResult:
        detections = [
            Detection(
                name="person",
                score=0.95,
                box=Box(x1=10, y1=20, x2=100, y2=200),
            )
        ]
        return DetectionResult(frame_id=frame_id, detections=detections)

    def get_name(self) -> str:
        return "MyDetectorModel"
```

### 2. 모델 출력값을 프로젝트 공통 형식으로 변환

핵심은 새 모델의 원본 출력을 아래 공통 형식으로 바꾸는 것입니다.

- 클래스명: `Detection.name`
- confidence: `Detection.score`
- 박스 좌표: `Detection.box`

즉 어떤 프레임워크를 쓰더라도 최종적으로는 `DetectionResult`를 반환해야 합니다.

```python
DetectionResult(
    frame_id=frame_id,
    detections=[
        Detection(
            name="person",
            score=0.91,
            box=Box(x1=100, y1=120, x2=220, y2=420),
        )
    ],
)
```

### 3. `main.py`에 import 및 분기 추가

파일: `safety_ai_monitor/main.py`

```python
from models.my_detector_model import MyDetectorModel
```

`build_model()`에 분기를 추가합니다.

```python
if MODEL_TYPE == "my_detector":
    return MyDetectorModel(
        model_path=to_abs_path(MODEL_PATH),
        min_confidence=MIN_CONFIDENCE,
    )
```

### 4. `config.py`에서 `MODEL_TYPE` 선택

```python
MODEL_TYPE = "my_detector"
MODEL_PATH = "models/weights/my_detector_weights.bin"
```

### 5. 새 모델 계열 추가 시 체크리스트

- 영상 1프레임 입력 시 `predict()`가 예외 없이 동작하는지
- 클래스명이 현재 룰과 호환되는지
- 좌표계가 `x1, y1, x2, y2` 형식으로 정확한지
- confidence 기준이 `MIN_CONFIDENCE`와 자연스럽게 맞는지
- 추론 속도가 스트림 사용 환경에서 감당 가능한지

### 6. 새 모델 계열 추가 시 가장 중요한 규칙

현재 프로젝트의 룰, 추적기, 로그 시스템은 모델 프레임워크 자체를 모르고 아래 공통 포맷만 신뢰합니다.

- `Detection.name`
- `Detection.score`
- `Detection.box`
- 필요 시 추적 후 부여되는 `track_id`

그래서 새 모델을 붙일 때는 "모델을 잘 로드하는가"보다 "프로젝트 공통 형식으로 정확히 변환하는가"가 더 중요합니다.

## 새 위험 감지 Rule 추가 방법

### 1. 이벤트 타입 추가

파일: `safety_ai_monitor/core/event_types.py`

```python
class EventType(Enum):
    NO_HELMET = "NO_HELMET"
    DANGER_ZONE = "DANGER_ZONE"
    FORKLIFT_NEAR_PERSON = "FORKLIFT_NEAR_PERSON"
```

### 2. 룰 파일 생성

파일 예: `safety_ai_monitor/rules/forklift_near_person_rule.py`

```python
from datetime import datetime

from core.event_rule import Event, EventRule
from core.event_types import EventLevel, EventType


class ForkliftNearPersonRule(EventRule):
    def check(self, result):
        events = []
        # result.detections를 검사해서 조건이 맞으면 Event 추가
        return events

    def get_name(self) -> str:
        return "ForkliftNearPersonRule"
```

### 3. `main.py`에 import 추가

```python
from rules.forklift_near_person_rule import ForkliftNearPersonRule
```

### 4. `build_pipeline()`에서 rules 리스트에 등록

```python
rules.append(ForkliftNearPersonRule())
```

### 규칙 작성 규약

- 입력은 `DetectionResult`
- 출력은 `list[Event]`
- `related_detections`에는 관련 객체를 넣습니다
- 사람별 이벤트 추적이 필요하면 관련 detection에 `track_id`가 있어야 합니다
- 중복 억제와 시작/종료 판단은 `EventFilter`가 담당합니다

## 새 EventHandler 추가 방법

핸들러는 콘솔 출력, 파일 로그, 알림 전송 같은 "이벤트 후처리"를 담당합니다.

### 1. 핸들러 파일 생성

파일 예: `safety_ai_monitor/handlers/slack_event_handler.py`

```python
from core.event_handler import EventHandler
from core.event_rule import Event


class SlackEventHandler(EventHandler):
    def handle(self, event: Event) -> None:
        # START / ACTIVE / END 상태를 받아 원하는 외부 처리 수행
        pass
```

### 2. `main.py`에 import 추가

```python
from handlers.slack_event_handler import SlackEventHandler
```

### 3. `build_pipeline()`의 handlers 리스트에 등록

```python
handlers = [
    ConsoleEventHandler(),
    LogEventHandler(log_path=log_path),
    SlackEventHandler(),
]
```

### 핸들러 작성 규약

- `handle(event)` 하나만 구현하면 됩니다
- `event.status`는 `START`, `ACTIVE`, `END` 중 하나입니다
- 알림 중복을 줄이고 싶으면 `START`일 때만 외부 알림을 보내는 방식이 안전합니다

## 핵심 설정값

파일: `safety_ai_monitor/config.py`

- `INPUT_MODE`: `gui` 또는 `camera`
- `MODEL_TYPE`: `dummy` 또는 `yolo`
- `MODEL_PATH`: YOLO 가중치 파일 경로
- `MIN_CONFIDENCE`: 검출 최소 confidence
- `USE_NO_HELMET_RULE`: 안전모 미착용 룰 사용 여부
- `USE_DANGER_ZONE_RULE`: 위험구역 진입 룰 사용 여부
- `DANGER_ZONE_ROI`: 위험구역 좌표
- `SAVE_EVENT_CLIP`: 이벤트 클립 저장 여부

## 프로그램 규칙 / 정책

### 1. 입력 정책

- GUI가 현재 입력 소스의 단일 진실 공급원입니다.
- Python은 `source_state.json`을 읽어서만 GUI 입력을 따라갑니다.

### 2. 모델 정책

- `MODEL_TYPE`에 따라 모델 구현체를 선택합니다.
- 현재 내장 구현은 `dummy`, `yolo` 두 가지입니다.
- YOLO 사용 시 Ultralytics 설정 디렉터리는 프로젝트 내부 `.yolo_config/`를 사용합니다.

### 3. 룰 정책

- 룰은 검출 결과를 이벤트로 바꾸는 계층입니다.
- 룰은 검출 클래스 이름에 강하게 의존합니다.
- 모델 교체 시 룰 호환성을 반드시 재검증해야 합니다.

### 4. 이벤트 상태 정책

- 한 이벤트는 `START -> ACTIVE -> END` 상태 흐름을 가집니다.
- 같은 사람의 같은 이벤트는 `event_key` 기준으로 묶입니다.
- 일시적으로 사라졌다가 짧은 시간 내 복귀하면 cooldown 기준으로 이어질 수 있습니다.

### 5. 로그 정책

- 현재 선택한 입력의 로그 파일은 분석 시작 시 새로 씁니다.
- 다른 입력의 로그 파일은 보존합니다.

### 6. GUI 정책

- GUI는 로그 파일을 주기적으로 다시 읽어 화면에 반영합니다.
- 스트림 모드에서 이벤트 클립을 누르면 저장된 replay clip을 재생할 수 있습니다.

### 7. 운영 정책

- 새 모델을 붙일 때는 반드시 샘플 영상 1개 이상으로 로그와 오탐 양상을 확인합니다.
- 룰 추가 시 최소한 영상 파일 기준 재생 테스트를 먼저 통과시키는 것을 권장합니다.
- 스트림 실시간성은 최종적으로 모델 추론 FPS에 크게 좌우됩니다.

## 이번 점검에서 확인한 결과 요약

- 백엔드 실행: 가능
- 이벤트 로그/클립 저장: 가능
- GUI 소스 연동 설계: 코드상 정상
- GUI Windows 빌드: 개발자 모드 없으면 현재 환경에서 중단
- 현재 기본 가중치와 `NoHelmetRule`의 의미 정합성: 불완전

즉, 이 프로젝트는 **실행 자체는 가능**하지만, **모델/가중치만 교체하면 무조건 의도대로 동작하는 구조는 아닙니다**. 새 모델의 클래스 체계와 룰의 기대 클래스 이름이 맞아야 합니다.
