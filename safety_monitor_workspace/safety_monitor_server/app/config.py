from pathlib import Path


SERVER_DIR = Path(__file__).resolve().parents[1].resolve()
WORKSPACE_DIR = SERVER_DIR.parent.resolve()
SERVER_DATA_DIR = (SERVER_DIR / "data").resolve()
SERVER_CLIP_DIR = (SERVER_DATA_DIR / "clips").resolve()
DEFAULT_EVENT_LOG_PATH = (SERVER_DATA_DIR / "events.jsonl").resolve()


def ensure_server_dirs() -> None:
    SERVER_DATA_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_CLIP_DIR.mkdir(parents=True, exist_ok=True)
