from pathlib import Path

# 이 파일은 FastAPI 서버가 소유하는 데이터 경로를 정의합니다.
# 서버 이벤트 저장소와 서버 클립 저장소 경로가 여기서 결정됩니다.

SERVER_DIR = Path(__file__).resolve().parents[1].resolve()
WORKSPACE_DIR = SERVER_DIR.parent.resolve()
SERVER_DATA_DIR = (SERVER_DIR / "data").resolve()
SERVER_CLIP_DIR = (SERVER_DATA_DIR / "clips").resolve()
SERVER_SOURCE_CACHE_DIR = (SERVER_DATA_DIR / "source_cache").resolve()
SERVER_UPLOAD_SOURCE_DIR = (SERVER_DATA_DIR / "uploaded_sources").resolve()
DATABASE_PATH = (SERVER_DATA_DIR / "monitor.db").resolve()
LEGACY_ANALYSIS_DIR = (WORKSPACE_DIR / "safety_ai_monitor").resolve()
LEGACY_SOURCE_CACHE_DIR = (LEGACY_ANALYSIS_DIR / "logs" / "source_cache").resolve()
LEGACY_CLIP_DIR = (LEGACY_ANALYSIS_DIR / "logs" / "clips").resolve()
ANALYSIS_DIR = (SERVER_DIR / "app" / "analysis").resolve()
ANALYSIS_WEIGHTS_DIR = (ANALYSIS_DIR / "models" / "weights").resolve()

# Analysis runtime
#MODEL_TYPE = "yolo_ensemble"
MODEL_TYPE = "yolo"
MODEL_PATH = (ANALYSIS_WEIGHTS_DIR / "best.pt").resolve()
PERSON_MODEL_PATH = (ANALYSIS_WEIGHTS_DIR / "person_detect.pt").resolve()
SAFETY_MODEL_PATH = (ANALYSIS_WEIGHTS_DIR / "good1.pt").resolve()
PREFER_TENSORRT_ENGINE = True
MIN_CONFIDENCE = 0.3
ANALYSIS_DEVICE = "cuda:0"
ANALYSIS_REQUIRE_CUDA = True
MODEL_INPUT_MAX_WIDTH = 1024
# 0 이하로 두면 source FPS를 기준으로 stride를 만들지 않고 매 프레임 분석합니다.
ANALYSIS_TARGET_FPS = 0.0

# Analysis rules / tracker
USE_NO_HELMET_RULE = True
NO_HELMET_HEAD_RATIO = 0.3
NO_HELMET_OVERLAP_RATIO = 0.2
USE_DANGER_ZONE_RULE = False
DANGER_ZONE_ROI = (100, 200, 500, 600)
EVENT_COOLDOWN_SECONDS = 3
EVENT_END_MISSING_FRAMES = 30
TRACK_MAX_DISTANCE = 100
TRACK_MAX_MISSING_FRAMES = 60
SAVE_EVENT_CLIP = True
EVENT_CLIP_BEFORE_SECONDS = 1
EVENT_CLIP_WRITE_QUEUE_SIZE = 512
FRAME_DETECTION_POST_MAX_FPS = 8.0
SOURCE_STATUS_POST_MIN_INTERVAL_SECONDS = 1.0
ENABLE_PIPELINE_PERF_LOG = True
PIPELINE_PERF_LOG_INTERVAL_FRAMES = 120
ENABLE_SERVER_REQUEST_LOG = True
SERVER_REQUEST_LOG_SUMMARY_INTERVAL_SECONDS = 5.0
SERVER_REQUEST_LOG_SUMMARY_PATHS = (
    "/api/frame-detections/current",
    "/api/source-status",
    "/api/sources",
    "/api/events",
)
ANALYSIS_PROGRESS_LOG_INTERVAL_SECONDS = 10.0


def ensure_server_dirs() -> None:
    # 서버 시작 전에 data/events.jsonl 상위 폴더와 data/clips 폴더를 미리 만들어 둡니다.
    SERVER_DATA_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_CLIP_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_SOURCE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_UPLOAD_SOURCE_DIR.mkdir(parents=True, exist_ok=True)
