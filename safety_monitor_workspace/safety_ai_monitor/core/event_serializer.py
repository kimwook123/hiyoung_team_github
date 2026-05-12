from datetime import datetime
from enum import Enum

from core.detection_model import Box, Detection
from core.event_rule import Event


def serialize_box(box: Box | None) -> dict[str, int | None] | None:
    if box is None:
        return None

    return {
        "x1": box.x1,
        "y1": box.y1,
        "x2": box.x2,
        "y2": box.y2,
    }


def serialize_detection(detection: Detection) -> dict[str, object]:
    return {
        "name": detection.name,
        "score": detection.score,
        "track_id": detection.track_id,
        "box": serialize_box(detection.box),
    }


def serialize_event(event: Event) -> dict[str, object]:
    return {
        "event_key": getattr(event, "event_key", None),
        "event_type": _serialize_value(getattr(event, "event_type", None)),
        "status": _serialize_value(getattr(event, "status", None)),
        "level": _serialize_value(getattr(event, "level", None)),
        "message": getattr(event, "message", None),
        "frame_id": getattr(event, "frame_id", None),
        "person_id": getattr(event, "person_id", None),
        "created_at": _serialize_value(getattr(event, "created_at", None)),
        "started_at": _serialize_value(getattr(event, "started_at", None)),
        "ended_at": _serialize_value(getattr(event, "ended_at", None)),
        "duration_seconds": getattr(event, "duration_seconds", None),
        "started_frame_id": getattr(event, "started_frame_id", None),
        "ended_frame_id": getattr(event, "ended_frame_id", None),
        "clip_path": getattr(event, "clip_path", None),
        "source_time_seconds": getattr(event, "source_time_seconds", None),
        "source_time_text": getattr(event, "source_time_text", None),
        "started_source_time_text": getattr(
            event, "started_source_time_text", None
        ),
        "ended_source_time_text": getattr(event, "ended_source_time_text", None),
        "related_detections": [
            serialize_detection(detection)
            for detection in getattr(event, "related_detections", [])
        ],
    }


def _serialize_value(value: object) -> object:
    if value is None:
        return None
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, datetime):
        return value.isoformat()
    return value
