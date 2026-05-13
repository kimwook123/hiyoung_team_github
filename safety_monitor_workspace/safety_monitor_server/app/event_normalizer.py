from copy import deepcopy
from pathlib import PurePosixPath
from typing import Any
from urllib.parse import urlsplit


def normalize_event_record(event_record: dict[str, Any]) -> dict[str, Any]:
    normalized = deepcopy(event_record)

    clip_url = _clean_string(normalized.get("clip_url"))
    clip_path = _clean_string(normalized.get("clip_path"))
    server_clip_name = _clean_string(normalized.get("server_clip_name"))
    server_clip_path = _clean_string(normalized.get("server_clip_path"))

    if not server_clip_name and clip_url:
        server_clip_name = _extract_clip_name_from_url(clip_url)
        if server_clip_name:
            normalized["server_clip_name"] = server_clip_name

    if not server_clip_path and server_clip_name:
        server_clip_path = f"clips/{server_clip_name}"
        normalized["server_clip_path"] = server_clip_path

    if clip_url:
        normalized["clip_available"] = True
        normalized["preferred_clip_source"] = "server"
    elif clip_path:
        normalized["clip_available"] = True
        normalized["preferred_clip_source"] = "local"
    else:
        normalized["clip_available"] = False
        normalized["preferred_clip_source"] = ""

    if "clip_upload_ok" not in normalized:
        normalized["clip_upload_ok"] = bool(clip_url)

    return normalized


def _clean_string(value: Any) -> str:
    if value is None:
        return ""
    if not isinstance(value, str):
        value = str(value)
    return value.strip()


def _extract_clip_name_from_url(clip_url: str) -> str:
    path_text = urlsplit(clip_url).path.strip()
    if not path_text:
        return ""

    path = PurePosixPath(path_text)
    parts = [part for part in path.parts if part not in {"", "/"}]
    if len(parts) < 3:
        return ""
    if parts[:2] != ["api", "clips"]:
        return ""

    name = path.name.strip()
    if not name.lower().endswith(".mp4"):
        return ""
    return name
