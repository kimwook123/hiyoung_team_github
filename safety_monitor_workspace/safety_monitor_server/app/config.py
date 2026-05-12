from pathlib import Path


SERVER_DIR = Path(__file__).resolve().parents[1]
WORKSPACE_DIR = SERVER_DIR.parent
DEFAULT_EVENT_LOG_PATH = (
    WORKSPACE_DIR / "safety_ai_monitor" / "logs" / "events.jsonl"
).resolve()
