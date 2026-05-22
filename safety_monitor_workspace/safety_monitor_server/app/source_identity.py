from pathlib import Path


def build_source_key(source_type: str, source_value: str) -> str:
    normalized_type = source_type.strip().lower()
    normalized_value = normalize_source_value(source_value)
    return f"{normalized_type}|{normalized_value}"


def build_source_slug(source_type: str, source_value: str) -> str:
    source_key = build_source_key(source_type, source_value)
    return f"src_{_fnv1a32(source_key):08x}"


def normalize_source_value(source_value: str) -> str:
    return source_value.strip().replace("\\", "/").lower()


def normalize_video_source_value(source_value: str) -> str:
    return str(Path(source_value).resolve())


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


def _fnv1a32(text: str) -> int:
    result = 0x811C9DC5
    for char in text:
        result ^= ord(char)
        result = (result * 0x01000193) & 0xFFFFFFFF
    return result
