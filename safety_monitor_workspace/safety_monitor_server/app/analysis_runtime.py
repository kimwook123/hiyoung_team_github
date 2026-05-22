from __future__ import annotations

import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from app.config import (
    ANALYSIS_DIR,
    ANALYSIS_TARGET_FPS,
    DANGER_ZONE_ROI,
    DATABASE_PATH,
    ENABLE_PIPELINE_PERF_LOG,
    EVENT_CLIP_BEFORE_SECONDS,
    EVENT_CLIP_WRITE_QUEUE_SIZE,
    EVENT_COOLDOWN_SECONDS,
    EVENT_END_MISSING_FRAMES,
    FRAME_DETECTION_POST_MAX_FPS,
    MIN_CONFIDENCE,
    MODEL_INPUT_MAX_WIDTH,
    MODEL_PATH,
    MODEL_TYPE,
    NO_HELMET_HEAD_RATIO,
    NO_HELMET_OVERLAP_RATIO,
    PERSON_MODEL_PATH,
    PIPELINE_PERF_LOG_INTERVAL_FRAMES,
    SAFETY_MODEL_PATH,
    SAVE_EVENT_CLIP,
    SERVER_CLIP_DIR,
    SERVER_SOURCE_CACHE_DIR,
    SOURCE_STATUS_POST_MIN_INTERVAL_SECONDS,
    TRACK_MAX_DISTANCE,
    TRACK_MAX_MISSING_FRAMES,
    USE_DANGER_ZONE_RULE,
    USE_NO_HELMET_RULE,
)
from app.database import insert_event, insert_frame_detection, upsert_source_status
from app.source_identity import build_source_key, build_source_slug, normalize_video_source_value


def _ensure_analysis_import_path() -> None:
    analysis_path = str(ANALYSIS_DIR)
    if analysis_path not in sys.path:
        sys.path.insert(0, analysis_path)


_ensure_analysis_import_path()

from core.async_workers import AsyncLatestWorker, AsyncTaskWorker  # type: ignore  # noqa: E402
from core.event_clip_recorder import EventClipRecorder  # type: ignore  # noqa: E402
from core.event_filter import EventFilter  # type: ignore  # noqa: E402
from core.event_handler import EventHandler  # type: ignore  # noqa: E402
from core.event_rule import Event  # type: ignore  # noqa: E402
from core.event_serializer import serialize_detection, serialize_event  # type: ignore  # noqa: E402
from core.frame_source import CameraFrameSource, StreamFrameSource, VideoFileFrameSource  # type: ignore  # noqa: E402
from core.object_tracker import PersonTracker  # type: ignore  # noqa: E402
from core.pipeline import VideoPipeline  # type: ignore  # noqa: E402
from models.dummy_model import DummyDetectionModel  # type: ignore  # noqa: E402
from models.ensemble_yolo_model import EnsembleYoloModel  # type: ignore  # noqa: E402
from models.yolo_model_sample import YoloModelSample  # type: ignore  # noqa: E402
from rules.danger_zone_rule import DangerZoneRule  # type: ignore  # noqa: E402
from rules.no_helmet_rule import NoHelmetRule  # type: ignore  # noqa: E402


def resolve_source(
    *,
    source_type: str,
    source_value: str,
) -> dict[str, str]:
    normalized_source_type = source_type.strip()
    normalized_source_value = source_value.strip()
    if normalized_source_type == "stream" and _is_youtube_url(normalized_source_value):
        resolved_path = _download_youtube_video(normalized_source_value)
        return {
            "source_type": "video",
            "source_value": str(resolved_path.resolve()),
            "original_source_type": normalized_source_type,
            "original_source_value": normalized_source_value,
        }
    return {
        "source_type": normalized_source_type,
        "source_value": normalized_source_value,
        "original_source_type": normalized_source_type,
        "original_source_value": normalized_source_value,
    }


def build_source_record(
    *,
    source_type: str,
    source_value: str,
    original_source_type: str,
    original_source_value: str,
    client_id: str = "",
    session_id: str = "",
    desired_running: bool = True,
) -> dict[str, Any]:
    normalized_source_value = source_value
    if source_type == "video":
        normalized_source_value = normalize_video_source_value(source_value)
    source_key = build_source_key(source_type=source_type, source_value=normalized_source_value)
    source_slug = build_source_slug(source_type=source_type, source_value=normalized_source_value)
    return {
        "source_key": source_key,
        "source_slug": source_slug,
        "source_type": source_type,
        "source_value": normalized_source_value,
        "original_source_type": original_source_type,
        "original_source_value": original_source_value,
        "client_id": client_id.strip(),
        "session_id": (session_id.strip() or source_key),
        "desired_running": desired_running,
    }


def build_pipeline_for_source(
    source_record: dict[str, Any],
    *,
    restart_checker=None,
    resume_from_seconds: float = 0.0,
) -> VideoPipeline:
    source_type = str(source_record.get("source_type", "")).strip()
    source_value = str(source_record.get("source_value", "")).strip()
    client_id = str(source_record.get("client_id", "")).strip()
    session_id = str(source_record.get("session_id", "")).strip()
    source_key = str(source_record.get("source_key", "")).strip()
    source_slug = str(source_record.get("source_slug", "")).strip()

    if source_type == "camera":
        frame_source = CameraFrameSource(camera_index=int(source_value or "0"))
    elif source_type == "stream":
        frame_source = StreamFrameSource(stream_url=source_value)
    elif source_type == "video":
        frame_source = VideoFileFrameSource(
            video_path=source_value,
            start_time_seconds=resume_from_seconds,
        )
    else:
        raise RuntimeError(f"지원하지 않는 source_type입니다: {source_type}")

    model = _build_model()
    rules = _build_rules()
    tracker = PersonTracker(
        max_distance=TRACK_MAX_DISTANCE,
        max_missing_frames=TRACK_MAX_MISSING_FRAMES,
    )
    event_filter = EventFilter(
        cooldown_seconds=EVENT_COOLDOWN_SECONDS,
        end_missing_frames=EVENT_END_MISSING_FRAMES,
    )
    source_fps = frame_source.get_fps()
    clip_recorder = EventClipRecorder(
        enabled=SAVE_EVENT_CLIP,
        clip_dir=str(SERVER_CLIP_DIR),
        fps=source_fps,
        before_seconds=EVENT_CLIP_BEFORE_SECONDS,
        source_slug=source_slug,
        queue_size=EVENT_CLIP_WRITE_QUEUE_SIZE,
    )
    frame_detection_recorder = ServerFrameDetectionRecorder(
        max_post_fps=FRAME_DETECTION_POST_MAX_FPS,
    )
    source_status_publisher = ServerSourceStatusPublisher(
        min_interval_seconds=SOURCE_STATUS_POST_MIN_INTERVAL_SECONDS,
    )
    handlers: list[EventHandler] = [
        ServerEventHandler(),
    ]

    return VideoPipeline(
        frame_source=frame_source,
        model=model,
        rules=rules,
        handlers=handlers,
        event_filter=event_filter,
        tracker=tracker,
        clip_recorder=clip_recorder,
        frame_detection_recorder=frame_detection_recorder,
        show_screen=False,
        restart_checker=restart_checker,
        source_type=source_type,
        source_value=source_value,
        source_key=source_key,
        source_slug=source_slug,
        client_id=client_id,
        session_id=session_id,
        source_fps=source_fps,
        source_status_publisher=source_status_publisher,
        analysis_target_fps=ANALYSIS_TARGET_FPS,
        model_input_max_width=MODEL_INPUT_MAX_WIDTH,
        enable_perf_log=ENABLE_PIPELINE_PERF_LOG,
        perf_log_interval_frames=PIPELINE_PERF_LOG_INTERVAL_FRAMES,
    )


class ServerEventHandler(EventHandler):
    def __init__(self, queue_size: int = 512) -> None:
        self.worker = AsyncTaskWorker[dict[str, Any]](
            name="server-db-event-worker",
            consumer=self._save_payload_sync,
            max_queue_size=queue_size,
        )
        self.last_payloads_by_event_key: dict[str, str] = {}

    def handle(self, event: Event) -> None:
        payload = serialize_event(event)
        payload_text = json.dumps(payload, ensure_ascii=False, sort_keys=True)
        event_key = str(payload.get("event_key", "") or "")
        if self.last_payloads_by_event_key.get(event_key) == payload_text:
            return
        if self.worker.submit(dict(payload)):
            self.last_payloads_by_event_key[event_key] = payload_text
            return
        self._save_payload_sync(payload)

    def _save_payload_sync(self, payload: dict[str, Any]) -> None:
        self._attach_clip_fields(payload)
        insert_event(DATABASE_PATH, payload)

    def _attach_clip_fields(self, payload: dict[str, Any]) -> None:
        clip_path = str(payload.get("clip_path", "") or "").strip()
        if not clip_path or clip_path == "-":
            return

        file_path = Path(clip_path)
        if not file_path.exists() or not file_path.is_file():
            return

        target_name = file_path.name
        target_path = SERVER_CLIP_DIR / target_name
        if file_path.resolve() != target_path.resolve():
            target_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file_path, target_path)

        payload["server_clip_name"] = target_path.name
        payload["server_clip_path"] = f"clips/{target_path.name}"
        payload["clip_url"] = f"/api/clips/{target_path.name}"
        payload["clip_upload_ok"] = True

    def close(self) -> None:
        self.worker.close(timeout_seconds=30.0)


class ServerFrameDetectionRecorder:
    def __init__(self, *, max_post_fps: float = 8.0) -> None:
        self.max_post_fps = max(0.0, max_post_fps)
        self.last_posted_at = 0.0
        self.worker = AsyncLatestWorker[dict[str, Any]](
            name="server-db-frame-detection-worker",
            consumer=self._save_record_sync,
        )

    def write(
        self,
        result,
        *,
        source_type: str,
        source_value: str,
        source_key: str,
        source_slug: str,
        frame_width: int,
        frame_height: int,
    ) -> None:
        now_ts = datetime.now().timestamp()
        if self.max_post_fps > 0:
            min_interval = 1.0 / self.max_post_fps
            if (now_ts - self.last_posted_at) < min_interval:
                return
        self.last_posted_at = now_ts

        record = {
            "frame_id": result.frame_id,
            "source_type": source_type,
            "source_value": source_value,
            "source_key": source_key,
            "source_slug": source_slug,
            "source_time_seconds": result.source_time_seconds,
            "source_time_text": result.source_time_text,
            "frame_width": frame_width,
            "frame_height": frame_height,
            "detections": [
                serialize_detection(detection)
                for detection in result.detections
            ],
        }
        self.worker.submit(record)

    def _save_record_sync(self, record: dict[str, Any]) -> None:
        insert_frame_detection(DATABASE_PATH, record)

    def close(self) -> None:
        self.worker.close(timeout_seconds=15.0)


class ServerSourceStatusPublisher:
    def __init__(self, *, min_interval_seconds: float = 1.0) -> None:
        self.min_interval_seconds = min_interval_seconds
        self.last_signature = ""
        self.last_posted_at = 0.0
        self.worker = AsyncLatestWorker[dict[str, Any]](
            name="server-db-source-status-worker",
            consumer=self._save_status_sync,
        )

    def publish(
        self,
        *,
        source_key: str,
        source_type: str,
        source_value: str,
        source_fps: float,
        client_id: str,
        session_id: str,
        state: str,
        is_running: bool,
        last_frame_id: int = -1,
        last_source_time_seconds: float = 0.0,
        error_message: str = "",
        force: bool = False,
    ) -> None:
        now_ts = datetime.now().timestamp()
        if not force and (now_ts - self.last_posted_at) < self.min_interval_seconds:
            return
        signature = (
            f"{source_key}|{state}|{1 if is_running else 0}|"
            f"{last_frame_id}|{last_source_time_seconds:.3f}|{error_message}"
        )
        if not force and signature == self.last_signature:
            return

        payload = {
            "source_key": source_key,
            "source_type": source_type,
            "source_value": source_value,
            "client_id": client_id,
            "session_id": session_id,
            "state": state,
            "is_running": is_running,
            "source_fps": source_fps,
            "last_frame_id": last_frame_id,
            "last_source_time_seconds": last_source_time_seconds,
            "error_message": error_message,
            "updated_at": datetime.now().isoformat(),
        }
        self.worker.submit(payload)
        self.last_posted_at = now_ts
        self.last_signature = signature

    def _save_status_sync(self, payload: dict[str, Any]) -> None:
        upsert_source_status(DATABASE_PATH, payload)

    def close(self) -> None:
        self.worker.close(timeout_seconds=15.0)


def _build_model():
    if MODEL_TYPE == "dummy":
        return DummyDetectionModel(min_confidence=MIN_CONFIDENCE)
    if MODEL_TYPE == "yolo":
        return YoloModelSample(
            model_path=str(MODEL_PATH),
            min_confidence=MIN_CONFIDENCE,
        )
    if MODEL_TYPE == "yolo_ensemble":
        return EnsembleYoloModel(
            person_model_path=str(PERSON_MODEL_PATH),
            safety_model_path=str(SAFETY_MODEL_PATH),
            min_confidence=MIN_CONFIDENCE,
            person_class_map={"person": "person"},
            safety_class_map={
                "helmet": "helmet",
                "hardhat": "helmet",
                "head": "head",
            },
        )
    raise ValueError(f"지원하지 않는 MODEL_TYPE입니다: {MODEL_TYPE}")


def _build_rules() -> list[Any]:
    rules: list[Any] = []
    if USE_NO_HELMET_RULE:
        rules.append(
            NoHelmetRule(
                head_ratio=NO_HELMET_HEAD_RATIO,
                overlap_ratio=NO_HELMET_OVERLAP_RATIO,
            )
        )
    if USE_DANGER_ZONE_RULE:
        rules.append(DangerZoneRule(roi=DANGER_ZONE_ROI))
    return rules


def _download_youtube_video(url: str) -> Path:
    try:
        import yt_dlp
    except ModuleNotFoundError as error:
        raise RuntimeError("유튜브 링크를 열려면 yt-dlp 설치가 필요합니다.") from error

    SERVER_SOURCE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    url_hash = hashlib.sha1(url.encode("utf-8")).hexdigest()[:12]
    output_path = SERVER_SOURCE_CACHE_DIR / f"youtube_{url_hash}.mp4"
    if output_path.exists() and output_path.is_file() and output_path.stat().st_size > 0:
        return output_path

    ydl_opts = {
        "format": "best[ext=mp4]/best",
        "outtmpl": str(output_path),
        "merge_output_format": "mp4",
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "overwrites": True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    if not output_path.exists() or output_path.stat().st_size <= 0:
        raise RuntimeError("유튜브 영상을 다운로드하지 못했습니다.")
    return output_path


def _is_youtube_url(value: str) -> bool:
    normalized = value.strip().lower()
    return (
        "youtube.com/" in normalized
        or "youtu.be/" in normalized
        or "youtube-nocookie.com/" in normalized
    )
