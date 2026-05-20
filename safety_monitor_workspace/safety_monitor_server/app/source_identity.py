from pathlib import Path


def extract_clip_name(record: dict) -> str:
    server_clip_name = str(record.get("server_clip_name", "")).strip()
    if server_clip_name:
        return server_clip_name

    server_clip_path = str(record.get("server_clip_path", "")).strip()
    if server_clip_path:
        return Path(server_clip_path).name

    clip_url = str(record.get("clip_url", "")).strip()
    if clip_url:
        return Path(clip_url).name

    return ""
