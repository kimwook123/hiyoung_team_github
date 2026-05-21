from pathlib import Path
import threading
import time

from config import (
    CAMERA_INDEX,
    DANGER_ZONE_ROI,
    ENABLE_EVENT_CLIP_UPLOAD,
    ENABLE_HTTP_EVENT_FALLBACK_JSON,
    ENABLE_HTTP_EVENT_POST,
    ENABLE_HTTP_FRAME_DETECTION_POST,
    ENABLE_HTTP_SOURCE_STATUS_POST,
    ENABLE_JSON_EVENT_LOG,
    EVENT_CLIP_UPLOAD_TIMEOUT_SECONDS,
    EVENT_CLIP_UPLOAD_URL,
    EVENT_POST_TIMEOUT_SECONDS,
    EVENT_POST_URL,
    FRAME_DETECTION_POST_TIMEOUT_SECONDS,
    FRAME_DETECTION_POST_URL,
    EVENT_COOLDOWN_SECONDS,
    EVENT_CLIP_BEFORE_SECONDS,
    EVENT_CLIP_DIR,
    EVENT_END_MISSING_FRAMES,
    FRAME_DETECTION_LOG_PATH,
    HTTP_EVENT_FALLBACK_JSON_PATH,
    INPUT_MODE,
    JSON_EVENT_LOG_PATH,
    LOG_PATH,
    MIN_CONFIDENCE,
    MODEL_PATH,
    MODEL_TYPE,
    PERSON_MODEL_PATH,
    NO_HELMET_HEAD_RATIO,
    NO_HELMET_OVERLAP_RATIO,
    SAFETY_MODEL_PATH,
    SAVE_EVENT_CLIP,
    SHOW_SCREEN,
    SOURCE_STATE_PATH,
    SOURCE_STATUS_POST_TIMEOUT_SECONDS,
    SOURCE_STATUS_POST_URL,
    SOURCES_STATE_PATH,
    TRACK_MAX_DISTANCE,
    TRACK_MAX_MISSING_FRAMES,
    USE_DANGER_ZONE_RULE,
    USE_NO_HELMET_RULE,
)
from core.detection_model import DetectionModel
from core.event_clip_recorder import EventClipRecorder
from core.event_filter import EventFilter
from core.frame_detection_recorder import FrameDetectionRecorder
from core.frame_source import CameraFrameSource, StreamFrameSource, VideoFileFrameSource
from core.object_tracker import PersonTracker
from core.path_helper import to_abs_path, to_project_path
from core.pipeline import VideoPipeline
from core.source_identity import (
    build_source_key,
    build_source_slug,
    normalize_video_source_value,
)
from core.source_status_publisher import SourceStatusPublisher
from core.ui_bridge import SourceStateReader, SourcesStateReader
from handlers.clip_upload_client import ClipUploadClient
from handlers.console_event_handler import ConsoleEventHandler
from handlers.http_event_handler import HttpEventHandler
from handlers.json_event_handler import JsonEventHandler
from handlers.log_event_handler import LogEventHandler
from models.dummy_model import DummyDetectionModel
from models.ensemble_yolo_model import EnsembleYoloModel
from models.yolo_model_sample import YoloModelSample
from rules.danger_zone_rule import DangerZoneRule
from rules.no_helmet_rule import NoHelmetRule

# 이 파일은 Python AI Worker의 진입점입니다.
# 입력 소스, 모델, 룰, 핸들러를 조립하고 필요하면 소스별 worker thread를 띄웁니다.


def build_model() -> DetectionModel:
    if MODEL_TYPE == "dummy":
        return DummyDetectionModel(min_confidence=MIN_CONFIDENCE)

    if MODEL_TYPE == "yolo":
        return YoloModelSample(
            model_path=to_abs_path(MODEL_PATH),
            min_confidence=MIN_CONFIDENCE,
        )

    if MODEL_TYPE == "yolo_ensemble":
        return EnsembleYoloModel(
            person_model_path=to_abs_path(PERSON_MODEL_PATH),
            safety_model_path=to_abs_path(SAFETY_MODEL_PATH),
            min_confidence=MIN_CONFIDENCE,
            person_class_map={
                "person": "person",
            },
            safety_class_map={
                "helmet": "helmet",
                "hardhat": "helmet",
                "head": "head",
            },
        )

    raise ValueError(
        f"지원하지 않는 MODEL_TYPE입니다: {MODEL_TYPE}. "
        "현재 지원: dummy, yolo, yolo_ensemble"
    )


def build_pipeline(
    source_state: dict[str, str] | None = None,
    restart_checker=None,
) -> VideoPipeline:
    if INPUT_MODE == "camera":
        frame_source = CameraFrameSource(camera_index=CAMERA_INDEX)
        source_type = "camera"
        source_value = str(CAMERA_INDEX)
        slot_id = "camera_0"
        client_id = ""
        session_id = ""
    else:
        if source_state is None:
            source_state = _get_source_state_reader().read()
        source_type = source_state["source_type"]
        source_value = source_state["source_value"]
        slot_id = str(source_state.get("slot_id", "")).strip() or "default"
        client_id = str(source_state.get("client_id", "")).strip()
        session_id = str(source_state.get("session_id", "")).strip() or slot_id

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
    normalized_source_value = source_value
    if source_type == "video":
        normalized_source_value = normalize_video_source_value(source_value)
    source_key = build_source_key(
        source_type=source_type,
        source_value=normalized_source_value,
    )
    source_slug = build_source_slug(
        source_type=source_type,
        source_value=normalized_source_value,
    )
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
        source_slug=source_slug,
    )
    frame_detection_recorder = FrameDetectionRecorder(
        log_path=to_project_path(FRAME_DETECTION_LOG_PATH),
        post_url=FRAME_DETECTION_POST_URL if ENABLE_HTTP_FRAME_DETECTION_POST else "",
        timeout_seconds=FRAME_DETECTION_POST_TIMEOUT_SECONDS,
    )
    source_status_publisher = None
    if ENABLE_HTTP_SOURCE_STATUS_POST:
        source_status_publisher = SourceStatusPublisher(
            post_url=SOURCE_STATUS_POST_URL,
            timeout_seconds=SOURCE_STATUS_POST_TIMEOUT_SECONDS,
        )

    return VideoPipeline(
        frame_source=frame_source,
        model=model,
        rules=rules,
        handlers=handlers,
        event_filter=event_filter,
        tracker=tracker,
        clip_recorder=clip_recorder,
        frame_detection_recorder=frame_detection_recorder,
        show_screen=SHOW_SCREEN,
        restart_checker=restart_checker,
        source_type=source_type,
        source_value=normalized_source_value,
        source_key=source_key,
        source_slug=source_slug,
        client_id=client_id,
        session_id=session_id,
        source_fps=source_fps,
        source_status_publisher=source_status_publisher,
    )


def main() -> None:
    if INPUT_MODE == "gui":
        _run_gui_mode()
        return

    pipeline = build_pipeline()
    pipeline.run()


def _run_gui_mode() -> None:
    sources_reader = _get_sources_state_reader()
    source_reader = _get_source_state_reader()
    current_state: dict[str, str] | None = None

    while True:
        if sources_reader.read_all():
            _run_multi_source_gui_mode()
            current_state = None
            continue

        if current_state is None:
            current_state = source_reader.read()

        pipeline = build_pipeline(
            source_state=current_state,
            restart_checker=lambda: sources_reader.read_all()
            or source_reader.read_if_changed(current_state) is not None,
        )
        stop_reason = pipeline.run()

        if sources_reader.read_all():
            current_state = None
            continue

        if stop_reason == "source_changed":
            current_state = source_reader.read()
            continue

        current_state = source_reader.wait_for_change(current_state)


class _SourceWorker:
    def __init__(self, source_state: dict[str, str]) -> None:
        self.source_state = dict(source_state)
        self.stop_event = threading.Event()
        self.thread = threading.Thread(
            target=self._run,
            name=f"source-worker-{self.worker_id}",
            daemon=True,
        )

    @property
    def worker_id(self) -> str:
        return self.source_state.get("slot_id", "default")

    def start(self) -> None:
        self.thread.start()

    def stop(self) -> None:
        self.stop_event.set()

    def is_alive(self) -> bool:
        return self.thread.is_alive()

    def _run(self) -> None:
        while not self.stop_event.is_set():
            pipeline = build_pipeline(
                source_state=self.source_state,
                restart_checker=lambda: self.stop_event.is_set(),
            )
            stop_reason = pipeline.run()
            if stop_reason != "source_changed":
                break


def _run_multi_source_gui_mode() -> None:
    reader = _get_sources_state_reader(min_updated_at=None)
    workers: dict[str, _SourceWorker] = {}

    while True:
        next_states = reader.read_all()
        if not next_states:
            for worker in workers.values():
                worker.stop()
            return

        next_by_slot = {
            str(item.get("slot_id", "")).strip() or f"slot_{index + 1}": item
            for index, item in enumerate(next_states)
        }

        for slot_id, worker in list(workers.items()):
            next_state = next_by_slot.get(slot_id)
            if next_state == worker.source_state:
                continue
            worker.stop()
            workers.pop(slot_id, None)

        for slot_id, next_state in next_by_slot.items():
            if slot_id in workers:
                continue
            worker = _SourceWorker(next_state)
            workers[slot_id] = worker
            worker.start()

        for slot_id, worker in list(workers.items()):
            if worker.is_alive():
                continue
            workers.pop(slot_id, None)

        time.sleep(1.0)


def _get_source_state_reader(
    min_updated_at: float | None = None,
) -> SourceStateReader:
    return SourceStateReader(
        state_path=to_project_path(SOURCE_STATE_PATH),
        min_updated_at=min_updated_at if min_updated_at is not None else time.time(),
    )


def _get_sources_state_reader(
    min_updated_at: float | None = None,
) -> SourcesStateReader:
    return SourcesStateReader(
        state_path=to_project_path(SOURCES_STATE_PATH),
        min_updated_at=min_updated_at if min_updated_at is not None else time.time(),
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
