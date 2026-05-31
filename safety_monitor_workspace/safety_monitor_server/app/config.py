from pathlib import Path


SERVER_DIR = Path(__file__).resolve().parents[1].resolve()
SERVER_DATA_DIR = (SERVER_DIR / "data").resolve()
SERVER_CLIP_DIR = (SERVER_DATA_DIR / "clips").resolve()
SERVER_SOURCE_PREVIEW_DIR = (SERVER_DATA_DIR / "source_previews").resolve()
SERVER_UPLOAD_SOURCE_DIR = (SERVER_DATA_DIR / "uploaded_sources").resolve()
SERVER_SOURCE_CACHE_DIR = (SERVER_DATA_DIR / "source_cache").resolve()
DATABASE_PATH = (SERVER_DATA_DIR / "monitor.db").resolve()

ENABLE_SERVER_REQUEST_LOG = True
SERVER_REQUEST_LOG_SUMMARY_INTERVAL_SECONDS = 5.0
SERVER_REQUEST_LOG_SUMMARY_PATHS = (
    "/api/frame-detections/current",
    "/api/source-status",
    "/api/sources",
    "/api/events",
)


def ensure_server_dirs() -> None:
    SERVER_DATA_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_CLIP_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_SOURCE_PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_UPLOAD_SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_SOURCE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
