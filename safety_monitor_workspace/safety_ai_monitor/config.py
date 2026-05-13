# 카메라 번호. 보통 노트북 기본 카메라는 0이다.
CAMERA_INDEX = 0

# 입력 방식
# "gui", "camera" 중 하나를 사용한다
INPUT_MODE = "gui"

# 사용할 모델 종류
# "dummy", "yolo"처럼 짧은 이름으로 고른다
MODEL_TYPE = "yolo"

# 학습된 모델 파일 경로
# dummy 모델에서는 사용하지 않는다
MODEL_PATH = "models/weights/best.pt"

# 이벤트 로그 저장 경로
LOG_PATH = "logs/event_log.txt"

# JSON 이벤트 로그 저장 여부
ENABLE_JSON_EVENT_LOG = True

# JSON 이벤트 로그 저장 경로
JSON_EVENT_LOG_PATH = "logs/events.jsonl"

# HTTP 이벤트 전송 사용 여부
ENABLE_HTTP_EVENT_POST = False

# HTTP 이벤트 전송 대상 URL
EVENT_POST_URL = "http://127.0.0.1:8000/api/events"

# HTTP 이벤트 전송 타임아웃(초)
EVENT_POST_TIMEOUT_SECONDS = 1.5

# HTTP 이벤트 전송 실패 시 로컬 fallback JSON 저장 여부
ENABLE_HTTP_EVENT_FALLBACK_JSON = True

# HTTP 이벤트 전송 실패 시 저장할 fallback JSON 경로
HTTP_EVENT_FALLBACK_JSON_PATH = "logs/events_post_failed.jsonl"

# Flutter UI와 연결할 정보 파일 경로
BRIDGE_PATH = "logs/ui_bridge.json"

# Flutter UI가 선택한 입력 소스 상태 파일
SOURCE_STATE_PATH = "logs/source_state.json"

# 이벤트 클립 저장 폴더
EVENT_CLIP_DIR = "logs/clips"

# 이벤트 시작 전 몇 초를 클립에 같이 저장할지 정한다
EVENT_CLIP_BEFORE_SECONDS = 3

# 이벤트 클립 저장 여부
SAVE_EVENT_CLIP = True

# 안전모 미착용 Rule 사용 여부
USE_NO_HELMET_RULE = True

# 위험구역 침입 Rule 사용 여부
USE_DANGER_ZONE_RULE = False

# 위험구역 좌표: x1, y1, x2, y2
DANGER_ZONE_ROI = (100, 200, 500, 600)

# 같은 이벤트가 반복 저장되지 않도록 기다리는 시간(초)
EVENT_COOLDOWN_SECONDS = 3

# 같은 사람으로 볼 최대 거리(픽셀)
TRACK_MAX_DISTANCE = 100

# 사람이 잠시 안 보여도 같은 ID를 유지할 최대 프레임 수
TRACK_MAX_MISSING_FRAMES = 30

# 이벤트가 몇 프레임 연속으로 안 보일 때 종료로 볼지 정한다
EVENT_END_MISSING_FRAMES = 5

# 객체 탐지 결과를 사용할 최소 신뢰도
MIN_CONFIDENCE = 0.5

# 사람 박스 상단에서 머리 영역으로 볼 비율
NO_HELMET_HEAD_RATIO = 0.3

# 머리 영역과 헬멧 박스가 이 비율 이상 겹치면 착용으로 본다
NO_HELMET_OVERLAP_RATIO = 0.2

# True면 OpenCV 화면을 띄운다.
# 단, opencv-python-headless 환경에서는 창이 열리지 않는다.
SHOW_SCREEN = False

# 나중에는 이 설정을 config.json 같은 파일로 분리할 수 있다.
