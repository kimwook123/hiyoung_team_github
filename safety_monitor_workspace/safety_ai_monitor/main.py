from pathlib import Path
import time

from config import (
    BRIDGE_PATH,
    CAMERA_INDEX,
    DANGER_ZONE_ROI,
    ENABLE_EVENT_CLIP_UPLOAD,
    ENABLE_HTTP_EVENT_FALLBACK_JSON,
    ENABLE_HTTP_EVENT_POST,
    ENABLE_JSON_EVENT_LOG,
    EVENT_CLIP_UPLOAD_TIMEOUT_SECONDS,
    EVENT_CLIP_UPLOAD_URL,
    EVENT_POST_TIMEOUT_SECONDS,
    EVENT_POST_URL,
    EVENT_COOLDOWN_SECONDS,
    EVENT_CLIP_BEFORE_SECONDS,
    EVENT_CLIP_DIR,
    EVENT_END_MISSING_FRAMES,
    HTTP_EVENT_FALLBACK_JSON_PATH,
    INPUT_MODE,
    JSON_EVENT_LOG_PATH,
    LOG_PATH,
    MIN_CONFIDENCE,
    MODEL_PATH,
    MODEL_TYPE,
    NO_HELMET_HEAD_RATIO,
    NO_HELMET_OVERLAP_RATIO,
    SAVE_EVENT_CLIP,
    SHOW_SCREEN,
    SOURCE_STATE_PATH,
    TRACK_MAX_DISTANCE,
    TRACK_MAX_MISSING_FRAMES,
    USE_DANGER_ZONE_RULE,
    USE_NO_HELMET_RULE,
)
from core.event_clip_recorder import EventClipRecorder
from core.event_filter import EventFilter
from core.detection_model import DetectionModel
from core.frame_source import CameraFrameSource, StreamFrameSource, VideoFileFrameSource
from core.object_tracker import PersonTracker
from core.path_helper import to_abs_path, to_project_path
from core.pipeline import VideoPipeline
from core.ui_bridge import SourceStateReader, UiBridgeWriter
from handlers.console_event_handler import ConsoleEventHandler
from handlers.clip_upload_client import ClipUploadClient
from handlers.http_event_handler import HttpEventHandler
from handlers.json_event_handler import JsonEventHandler
from handlers.log_event_handler import LogEventHandler
from models.dummy_model import DummyDetectionModel
from models.yolo_model_sample import YoloModelSample
from rules.danger_zone_rule import DangerZoneRule
from rules.no_helmet_rule import NoHelmetRule


def build_model() -> DetectionModel:
    # config.py의 MODEL_TYPE 값으로 모델 구현체를 고른다
    if MODEL_TYPE == "dummy":
        return DummyDetectionModel(min_confidence=MIN_CONFIDENCE)

    if MODEL_TYPE == "yolo":
        return YoloModelSample(
            model_path=to_abs_path(MODEL_PATH),
            min_confidence=MIN_CONFIDENCE,
        )

    raise ValueError(
        f"지원하지 않는 MODEL_TYPE입니다: {MODEL_TYPE}. "
        "현재 지원: dummy, yolo"
    )


def build_pipeline(
    source_state: dict[str, str] | None = None,
    restart_checker=None,
) -> VideoPipeline:
    if INPUT_MODE == "camera":
        frame_source = CameraFrameSource(camera_index=CAMERA_INDEX)
        source_type = "camera"
        source_value = str(CAMERA_INDEX)
    else:
        if source_state is None:
            source_state = _get_source_state_reader().read()
        source_type = source_state["source_type"]
        source_value = source_state["source_value"]
        if source_type == "stream":
            frame_source = StreamFrameSource(stream_url=source_value)
        elif source_type == "video":
            source_value = to_abs_path(source_value)
            frame_source = VideoFileFrameSource(video_path=source_value)
        else:
            raise RuntimeError(
                "GUI에서 영상 파일 또는 스트림을 먼저 선택해야 합니다."
            )

    model = build_model()

    log_path = _build_log_path(source_type=source_type, source_value=source_value)

    rules = []
    if USE_NO_HELMET_RULE:
        rules.append(
            NoHelmetRule(
                head_ratio=NO_HELMET_HEAD_RATIO,
                overlap_ratio=NO_HELMET_OVERLAP_RATIO,
            )
        )

    if USE_DANGER_ZONE_RULE:
        rules.append(DangerZoneRule(roi=DANGER_ZONE_ROI))

    handlers = [
        ConsoleEventHandler(),
        LogEventHandler(log_path=log_path),
    ]
    if ENABLE_HTTP_EVENT_POST:
        fallback_handler = None
        clip_upload_client = None
        if ENABLE_HTTP_EVENT_FALLBACK_JSON:
            fallback_handler = JsonEventHandler(
                log_path=to_project_path(HTTP_EVENT_FALLBACK_JSON_PATH)
            )
        if ENABLE_EVENT_CLIP_UPLOAD:
            clip_upload_client = ClipUploadClient(
                upload_url=EVENT_CLIP_UPLOAD_URL,
                timeout_seconds=EVENT_CLIP_UPLOAD_TIMEOUT_SECONDS,
            )
        handlers.append(
            HttpEventHandler(
                post_url=EVENT_POST_URL,
                timeout_seconds=EVENT_POST_TIMEOUT_SECONDS,
                fallback_handler=fallback_handler,
                clip_upload_client=clip_upload_client,
            )
        )
    elif ENABLE_JSON_EVENT_LOG:
        handlers.append(
            JsonEventHandler(log_path=to_project_path(JSON_EVENT_LOG_PATH))
        )

    event_filter = EventFilter(
        cooldown_seconds=EVENT_COOLDOWN_SECONDS,
        end_missing_frames=EVENT_END_MISSING_FRAMES,
    )
    tracker = PersonTracker(
        max_distance=TRACK_MAX_DISTANCE,
        max_missing_frames=TRACK_MAX_MISSING_FRAMES,
    )
    source_fps = frame_source.get_fps()
    clip_recorder = EventClipRecorder(
        enabled=SAVE_EVENT_CLIP,
        clip_dir=to_project_path(EVENT_CLIP_DIR),
        fps=source_fps,
        before_seconds=EVENT_CLIP_BEFORE_SECONDS,
    )

    UiBridgeWriter(bridge_path=to_project_path(BRIDGE_PATH)).write(
        source_type=source_type,
        source_value=source_value,
        log_path=log_path,
        model_type=MODEL_TYPE,
        source_fps=source_fps,
    )

    return VideoPipeline(
        frame_source=frame_source,
        model=model,
        rules=rules,
        handlers=handlers,
        event_filter=event_filter,
        tracker=tracker,
        clip_recorder=clip_recorder,
        show_screen=SHOW_SCREEN,
        restart_checker=restart_checker,
    )


def main() -> None:
    if INPUT_MODE == "gui":
        _run_gui_mode()
        return

    pipeline = build_pipeline()
    pipeline.run()


def _run_gui_mode() -> None:
    source_reader = _get_source_state_reader()
    current_state = source_reader.read()

    while True:
        pipeline = build_pipeline(
            source_state=current_state,
            restart_checker=lambda: source_reader.read_if_changed(current_state)
            is not None,
        )
        stop_reason = pipeline.run()

        if stop_reason == "source_changed":
            current_state = source_reader.read()
            continue

        current_state = source_reader.wait_for_change(current_state)


def _get_source_state_reader() -> SourceStateReader:
    return SourceStateReader(
        state_path=to_project_path(SOURCE_STATE_PATH),
        min_updated_at=time.time(),
    )


def _build_log_path(source_type: str, source_value: str) -> str:
    if source_type == "video":
        video_name = Path(source_value).stem
        return str(
            (Path(to_project_path("logs")) / f"{video_name}_event_log.txt").resolve()
        )

    if source_type == "stream":
        return str((Path(to_project_path("logs")) / "stream_event_log.txt").resolve())

    return to_project_path(LOG_PATH)


if __name__ == "__main__":
    main()
