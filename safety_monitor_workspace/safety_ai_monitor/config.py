# Input
CAMERA_INDEX = 0
INPUT_MODE = "gui"

# Model
MODEL_TYPE = "yolo_ensemble"
MODEL_PATH = "models/weights/best.pt"
PERSON_MODEL_PATH = "models/weights/person_detect.pt"
SAFETY_MODEL_PATH = "models/weights/good1.pt"
MIN_CONFIDENCE = 0.3

# Local control files
SOURCE_STATE_PATH = "logs/source_state.json"
SOURCES_STATE_PATH = "logs/sources_state.json"

# Local debug / fallback outputs
LOG_PATH = "logs/event_log.txt"
ENABLE_JSON_EVENT_LOG = True
JSON_EVENT_LOG_PATH = "logs/events.jsonl"
FRAME_DETECTION_LOG_PATH = "logs/frame_detections.jsonl"
ENABLE_HTTP_EVENT_FALLBACK_JSON = True
HTTP_EVENT_FALLBACK_JSON_PATH = "logs/events_post_failed.jsonl"

# Server APIs
ENABLE_HTTP_EVENT_POST = True
EVENT_POST_URL = "http://127.0.0.1:8000/api/events"
EVENT_POST_TIMEOUT_SECONDS = 1.5

ENABLE_HTTP_FRAME_DETECTION_POST = True
FRAME_DETECTION_POST_URL = "http://127.0.0.1:8000/api/frame-detections"
FRAME_DETECTION_POST_TIMEOUT_SECONDS = 1.0

ENABLE_HTTP_SOURCE_STATUS_POST = True
SOURCE_STATUS_POST_URL = "http://127.0.0.1:8000/api/source-status"
SOURCE_STATUS_POST_TIMEOUT_SECONDS = 1.0

ENABLE_EVENT_CLIP_UPLOAD = True
EVENT_CLIP_UPLOAD_URL = "http://127.0.0.1:8000/api/clips"
EVENT_CLIP_UPLOAD_TIMEOUT_SECONDS = 5.0

# Clips
SAVE_EVENT_CLIP = True
EVENT_CLIP_DIR = "logs/clips"
EVENT_CLIP_BEFORE_SECONDS = 1

# Rules
USE_NO_HELMET_RULE = True
NO_HELMET_HEAD_RATIO = 0.3
NO_HELMET_OVERLAP_RATIO = 0.2

USE_DANGER_ZONE_RULE = False
DANGER_ZONE_ROI = (100, 200, 500, 600)

# Tracking / event state
EVENT_COOLDOWN_SECONDS = 3
EVENT_END_MISSING_FRAMES = 30
TRACK_MAX_DISTANCE = 100
TRACK_MAX_MISSING_FRAMES = 60

# Local preview
SHOW_SCREEN = False
