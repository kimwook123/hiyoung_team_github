from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import cv2

from app.config import (
    ANALYSIS_DEVICE,
    ANALYSIS_DIR,
    ANALYSIS_PROGRESS_LOG_INTERVAL_SECONDS,
    ANALYSIS_REQUIRE_CUDA,
    ANALYSIS_TARGET_FPS,
    CLIENT_CLIP_DIR,
    CLIENT_SOURCE_PREVIEW_DIR,
    CLIENT_SOURCE_CACHE_DIR,
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
    PREFER_TENSORRT_ENGINE,
    SAFETY_MODEL_PATH,
    SAVE_EVENT_CLIP,
    SOURCE_STATUS_POST_MIN_INTERVAL_SECONDS,
    TRACK_MAX_DISTANCE,
    TRACK_MAX_MISSING_FRAMES,
)
from app.database import insert_event
from app.database import insert_frame_detection
from app.database import upsert_source_status
from app.log_utils import log_line
from app.realtime_hub import realtime_update_hub
from app.reporting_api import remote_server_reporter
from app.routers.source_previews import source_preview_path
from app.source_identity import build_source_key
from app.source_identity import build_source_slug
from app.source_identity import normalize_video_source_value
from app.source_rule_config import build_default_rule_config
from app.source_rule_config import normalize_rule_config
from app.source_rule_config import to_roi_tuple


def _ensure_analysis_import_path() -> None:
    analysis_path = str(ANALYSIS_DIR)
    if analysis_path not in sys.path:
        sys.path.insert(0, analysis_path)


_ensure_analysis_import_path()

from core.async_workers import AsyncLatestWorker  # type: ignore  # noqa: E402
from core.async_workers import AsyncTaskWorker  # type: ignore  # noqa: E402
from core.event_clip_recorder import EventClipRecorder  # type: ignore  # noqa: E402
from core.event_filter import EventFilter  # type: ignore  # noqa: E402
from core.event_handler import EventHandler  # type: ignore  # noqa: E402
from core.event_rule import Event  # type: ignore  # noqa: E402
from core.event_serializer import serialize_detection  # type: ignore  # noqa: E402
from core.event_serializer import serialize_event  # type: ignore  # noqa: E402
from core.frame_source import CameraFrameSource  # type: ignore  # noqa: E402
from core.frame_source import StreamFrameSource  # type: ignore  # noqa: E402
from core.frame_source import VideoFileFrameSource  # type: ignore  # noqa: E402
from core.object_tracker import PersonTracker  # type: ignore  # noqa: E402
from core.pipeline import VideoPipeline  # type: ignore  # noqa: E402
from models.dummy_model import DummyDetectionModel  # type: ignore  # noqa: E402
from models.ensemble_yolo_model import EnsembleYoloModel  # type: ignore  # noqa: E402
from models.yolo_model_sample import YoloModelSample  # type: ignore  # noqa: E402
from rules.danger_zone_rule import DangerZoneRule  # type: ignore  # noqa: E402
from rules.no_helmet_rule import NoHelmetRule  # type: ignore  # noqa: E402


def resolve_source(*, source_type: str, source_value: str) -> dict[str, str]:
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
    source_duration_seconds = (
        _read_video_duration_seconds(normalized_source_value)
        if source_type == "video"
        else 0.0
    )
    return {
        "source_key": source_key,
        "source_slug": source_slug,
        "source_type": source_type,
        "source_value": normalized_source_value,
        "source_duration_seconds": source_duration_seconds,
        "original_source_type": original_source_type,
        "original_source_value": original_source_value,
        "client_id": client_id.strip(),
        "session_id": (session_id.strip() or source_key),
        "desired_running": desired_running,
        "rule_config": build_default_rule_config(),
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
        raise RuntimeError(f"unsupported source_type: {source_type}")

    model = _build_model()
    rules = _build_rules(source_record)
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
        clip_dir=str(CLIENT_CLIP_DIR),
        fps=source_fps,
        before_seconds=EVENT_CLIP_BEFORE_SECONDS,
        source_slug=source_slug,
        queue_size=EVENT_CLIP_WRITE_QUEUE_SIZE,
    )
    frame_detection_recorder = ClientFrameDetectionRecorder(
        max_post_fps=FRAME_DETECTION_POST_MAX_FPS,
    )
    source_status_publisher = ClientSourceStatusPublisher(
        min_interval_seconds=SOURCE_STATUS_POST_MIN_INTERVAL_SECONDS,
        progress_log_interval_seconds=ANALYSIS_PROGRESS_LOG_INTERVAL_SECONDS,
    )
    preview_publisher = ClientSourcePreviewPublisher()
    handlers: list[EventHandler] = [ClientEventHandler()]

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
        preview_publisher=preview_publisher,
        source_duration_seconds=float(source_record.get("source_duration_seconds", 0.0) or 0.0),
        analysis_target_fps=ANALYSIS_TARGET_FPS,
        model_input_max_width=MODEL_INPUT_MAX_WIDTH,
        enable_perf_log=ENABLE_PIPELINE_PERF_LOG,
        perf_log_interval_frames=PIPELINE_PERF_LOG_INTERVAL_FRAMES,
    )


class ClientEventHandler(EventHandler):
    def __init__(self, queue_size: int = 512) -> None:
        self.worker = AsyncTaskWorker[dict[str, Any]](
            name="client-event-worker",
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
        self._attach_remote_clip_fields(payload)
        saved_record = insert_event(DATABASE_PATH, payload)
        realtime_update_hub.publish(
            "event_changed",
            source_key=str(saved_record.get("source_key", "")).strip(),
            event_key=str(saved_record.get("event_key", "")).strip(),
            status=str(saved_record.get("status", "")).strip(),
            event_type=str(saved_record.get("event_type", "")).strip(),
        )
        if bool(saved_record.get("clip_available", False)):
            remote_server_reporter.post_event(saved_record)

    def _attach_remote_clip_fields(self, payload: dict[str, Any]) -> None:
        payload.setdefault("clip_upload_ok", False)
        payload.setdefault("clip_available", False)
        payload.setdefault("preferred_clip_source", "none")
        clip_path = str(payload.get("clip_path", "") or "").strip()
        if not clip_path or clip_path == "-":
            return

        upload_result = remote_server_reporter.upload_clip(
            clip_path=clip_path,
            event_key=str(payload.get("event_key", "")).strip(),
            source_key=str(payload.get("source_key", "")).strip(),
            source_slug=str(payload.get("source_slug", "")).strip(),
        )
        if not upload_result:
            return

        payload["server_clip_name"] = str(upload_result.get("name", "")).strip()
        payload["server_clip_path"] = str(upload_result.get("path", "")).strip()
        payload["clip_url"] = str(upload_result.get("url", "")).strip()
        payload["clip_upload_ok"] = bool(upload_result.get("ok", True))
        payload["clip_available"] = True
        payload["preferred_clip_source"] = "server"

    def close(self) -> None:
        self.worker.close(timeout_seconds=30.0)


class ClientFrameDetectionRecorder:
    def __init__(self, *, max_post_fps: float = 8.0) -> None:
        self.max_post_fps = max(0.0, max_post_fps)
        self.last_posted_at = 0.0
        self.worker = AsyncLatestWorker[dict[str, Any]](
            name="client-frame-detection-worker",
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
            "detections": [serialize_detection(detection) for detection in result.detections],
        }
        self.worker.submit(record)

    def _save_record_sync(self, record: dict[str, Any]) -> None:
        saved_record = insert_frame_detection(DATABASE_PATH, record)
        remote_server_reporter.post_frame_detection(saved_record)

    def close(self) -> None:
        self.worker.close(timeout_seconds=15.0)


class ClientSourceStatusPublisher:
    def __init__(
        self,
        *,
        min_interval_seconds: float = 1.0,
        progress_log_interval_seconds: float = 10.0,
    ) -> None:
        self.min_interval_seconds = min_interval_seconds
        self.progress_log_interval_seconds = max(1.0, progress_log_interval_seconds)
        self.last_signature = ""
        self.last_posted_at = 0.0
        self.last_logged_at_by_source_key: dict[str, float] = {}
        self.last_logged_state_by_source_key: dict[str, str] = {}
        self.last_logged_progress_bucket_by_source_key: dict[str, int] = {}
        self.worker = AsyncLatestWorker[dict[str, Any]](
            name="client-source-status-worker",
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
        source_duration_seconds: float = 0.0,
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
            "source_duration_seconds": source_duration_seconds,
            "last_frame_id": last_frame_id,
            "last_source_time_seconds": last_source_time_seconds,
            "error_message": error_message,
            "updated_at": datetime.now().isoformat(),
        }
        self.worker.submit(payload)
        self.last_posted_at = now_ts
        self.last_signature = signature
        self._log_progress(
            source_key=source_key,
            source_type=source_type,
            client_id=client_id,
            state=state,
            is_running=is_running,
            source_duration_seconds=source_duration_seconds,
            last_frame_id=last_frame_id,
            last_source_time_seconds=last_source_time_seconds,
            error_message=error_message,
            now_ts=now_ts,
            force=force,
        )

    def _save_status_sync(self, payload: dict[str, Any]) -> None:
        saved_record = upsert_source_status(DATABASE_PATH, payload)
        realtime_update_hub.publish(
            "source_status_changed",
            source_key=str(saved_record.get("source_key", "")).strip(),
            state=str(saved_record.get("state", "")).strip(),
            is_running=bool(saved_record.get("is_running", False)),
        )
        remote_server_reporter.post_status(saved_record)

    def close(self) -> None:
        self.worker.close(timeout_seconds=15.0)

    def _log_progress(
        self,
        *,
        source_key: str,
        source_type: str,
        client_id: str,
        state: str,
        is_running: bool,
        source_duration_seconds: float,
        last_frame_id: int,
        last_source_time_seconds: float,
        error_message: str,
        now_ts: float,
        force: bool,
    ) -> None:
        normalized_state = state.strip().lower() or "unknown"
        state_changed = self.last_logged_state_by_source_key.get(source_key) != normalized_state
        progress_bucket = -1
        if source_duration_seconds > 0:
            progress_bucket = int(
                max(0.0, min(100.0, (last_source_time_seconds / source_duration_seconds) * 100.0))
            )
        progress_bucket_changed = (
            progress_bucket >= 0
            and self.last_logged_progress_bucket_by_source_key.get(source_key) != progress_bucket
            and progress_bucket % 5 == 0
        )
        timed_out = (
            force
            or state_changed
            or progress_bucket_changed
            or (now_ts - self.last_logged_at_by_source_key.get(source_key, 0.0))
            >= self.progress_log_interval_seconds
        )
        if not timed_out:
            return

        if source_duration_seconds > 0:
            progress_text = (
                f"{last_source_time_seconds:.1f}/{source_duration_seconds:.1f}s "
                f"({max(0.0, min(100.0, (last_source_time_seconds / source_duration_seconds) * 100.0)):.1f}%)"
            )
        else:
            progress_text = f"{last_source_time_seconds:.1f}s"

        log_line(
            "PROGRESS",
            source=source_key,
            type=source_type,
            client=client_id or "-",
            state=normalized_state,
            running="yes" if is_running else "no",
            frame=last_frame_id,
            progress=progress_text,
            error=error_message.strip() or None,
        )

        self.last_logged_at_by_source_key[source_key] = now_ts
        self.last_logged_state_by_source_key[source_key] = normalized_state
        if progress_bucket >= 0:
            self.last_logged_progress_bucket_by_source_key[source_key] = progress_bucket


class ClientSourcePreviewPublisher:
    def __init__(self, *, max_preview_fps: float = 10.0) -> None:
        self.max_preview_fps = max(0.1, max_preview_fps)
        self.last_posted_at = 0.0
        self.worker = AsyncLatestWorker[dict[str, Any]](
            name="client-source-preview-worker",
            consumer=self._save_preview_sync,
        )

    def publish(self, *, frame, result, source_key: str) -> None:
        now_ts = datetime.now().timestamp()
        min_interval = 1.0 / self.max_preview_fps
        if (now_ts - self.last_posted_at) < min_interval:
            return
        self.last_posted_at = now_ts

        ok, encoded = cv2.imencode(".jpg", frame)
        if not ok:
            return
        self.worker.submit(
            {
                "source_key": source_key,
                "jpeg_bytes": encoded.tobytes(),
            }
        )

    def _save_preview_sync(self, payload: dict[str, Any]) -> None:
        source_key = str(payload.get("source_key", "")).strip()
        jpeg_bytes = payload.get("jpeg_bytes")
        if not source_key or not isinstance(jpeg_bytes, (bytes, bytearray)):
            return

        CLIENT_SOURCE_PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
        preview_path = source_preview_path(source_key)
        preview_path.write_bytes(bytes(jpeg_bytes))
        remote_server_reporter.upload_source_preview(
            source_key=source_key,
            preview_path=str(preview_path),
        )

    def close(self) -> None:
        self.worker.close(timeout_seconds=15.0)


def _build_model():
    if MODEL_TYPE == "dummy":
        return DummyDetectionModel(min_confidence=MIN_CONFIDENCE)
    if MODEL_TYPE == "yolo":
        return YoloModelSample(
            model_path=str(MODEL_PATH),
            min_confidence=MIN_CONFIDENCE,
            device=ANALYSIS_DEVICE,
            require_cuda=ANALYSIS_REQUIRE_CUDA,
            prefer_tensorrt_engine=PREFER_TENSORRT_ENGINE,
        )
    if MODEL_TYPE == "yolo_ensemble":
        return EnsembleYoloModel(
            person_model_path=str(PERSON_MODEL_PATH),
            safety_model_path=str(SAFETY_MODEL_PATH),
            min_confidence=MIN_CONFIDENCE,
            device=ANALYSIS_DEVICE,
            require_cuda=ANALYSIS_REQUIRE_CUDA,
            prefer_tensorrt_engine=PREFER_TENSORRT_ENGINE,
            person_class_map={"person": "person"},
            safety_class_map={
                "helmet": "helmet",
                "hardhat": "helmet",
                "head": "head",
            },
        )
    raise ValueError(f"unsupported MODEL_TYPE: {MODEL_TYPE}")


def _build_rules(source_record: dict[str, Any]) -> list[Any]:
    rules: list[Any] = []
    rule_config = normalize_rule_config(source_record.get("rule_config"))
    if bool(rule_config.get("use_no_helmet_rule", True)):
        rules.append(
            NoHelmetRule(
                head_ratio=NO_HELMET_HEAD_RATIO,
                overlap_ratio=NO_HELMET_OVERLAP_RATIO,
            )
        )
    danger_zone_roi = to_roi_tuple(rule_config.get("danger_zone_roi"))
    if bool(rule_config.get("use_danger_zone_rule", False)) and danger_zone_roi is not None:
        rules.append(DangerZoneRule(roi=danger_zone_roi))
    return rules


def _download_youtube_video(url: str) -> Path:
    try:
        import yt_dlp
    except ModuleNotFoundError as error:
        raise RuntimeError("yt-dlp is required for YouTube sources") from error

    CLIENT_SOURCE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    url_hash = hashlib.sha1(url.encode("utf-8")).hexdigest()[:12]
    output_path = CLIENT_SOURCE_CACHE_DIR / f"youtube_{url_hash}.mp4"
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
        raise RuntimeError("failed to download youtube source")
    return output_path


def _is_youtube_url(value: str) -> bool:
    normalized = value.strip().lower()
    return (
        "youtube.com/" in normalized
        or "youtu.be/" in normalized
        or "youtube-nocookie.com/" in normalized
    )


def _read_video_duration_seconds(video_path: str) -> float:
    try:
        cap = cv2.VideoCapture(video_path)
    except Exception:
        return 0.0
    try:
        if cap is None or not cap.isOpened():
            return 0.0
        fps = float(cap.get(cv2.CAP_PROP_FPS))
        frame_count = float(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if fps <= 0 or frame_count <= 0:
            return 0.0
        return frame_count / fps
    finally:
        if cap is not None:
            cap.release()
