from pathlib import Path

# 이 파일은 FastAPI 서버가 소유하는 데이터 경로를 정의합니다.
# 서버 이벤트 저장소와 서버 클립 저장소 경로가 여기서 결정됩니다.

SERVER_DIR = Path(__file__).resolve().parents[1].resolve()
WORKSPACE_DIR = SERVER_DIR.parent.resolve()
SERVER_DATA_DIR = (SERVER_DIR / "data").resolve()
SERVER_CLIP_DIR = (SERVER_DATA_DIR / "clips").resolve()
DEFAULT_EVENT_LOG_PATH = (SERVER_DATA_DIR / "events.jsonl").resolve()


def ensure_server_dirs() -> None:
    # 서버 시작 전에 data/events.jsonl 상위 폴더와 data/clips 폴더를 미리 만들어 둡니다.
    SERVER_DATA_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_CLIP_DIR.mkdir(parents=True, exist_ok=True)
