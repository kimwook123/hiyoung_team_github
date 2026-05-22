from __future__ import annotations

import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app.analysis_runtime import build_pipeline_for_source, build_source_record, resolve_source
from app.config import (
    DATABASE_PATH,
    SERVER_CLIP_DIR,
    SERVER_SOURCE_CACHE_DIR,
    SERVER_UPLOAD_SOURCE_DIR,
)
from app.database import (
    delete_source_status,
    delete_source,
    get_source_status,
    get_source,
    list_sources,
    prune_orphan_source_data,
    reset_source_data,
    set_source_desired_running,
    upsert_source,
    upsert_source_status,
)


@dataclass
class _ManagedWorker:
    source_record: dict[str, Any]
    stop_event: threading.Event
    thread: threading.Thread


class AnalysisSourceManager:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._workers: dict[str, _ManagedWorker] = {}

    def bootstrap(self) -> None:
        for source_record in list_sources(DATABASE_PATH):
            if not bool(source_record.get("desired_running", False)):
                continue
            self.start_source(str(source_record.get("source_key", "")).strip())

    def shutdown(self) -> None:
        with self._lock:
            worker_keys = list(self._workers.keys())
        for source_key in worker_keys:
            self.stop_source(source_key)

    def register_source(
        self,
        *,
        source_type: str,
        source_value: str,
        client_id: str = "",
        session_id: str = "",
        reset_existing: bool = True,
        start_immediately: bool = True,
    ) -> dict[str, Any]:
        resolved = resolve_source(source_type=source_type, source_value=source_value)
        source_record = build_source_record(
            source_type=resolved["source_type"],
            source_value=resolved["source_value"],
            original_source_type=resolved["original_source_type"],
            original_source_value=resolved["original_source_value"],
            client_id=client_id,
            session_id=session_id,
            desired_running=start_immediately,
        )
        source_key = str(source_record.get("source_key", "")).strip()
        source_slug = str(source_record.get("source_slug", "")).strip()

        upsert_source(DATABASE_PATH, source_record)
        if reset_existing:
            reset_source_data(
                DATABASE_PATH,
                source_key=source_key,
                source_slug=source_slug,
                server_clip_dir=SERVER_CLIP_DIR,
            )

        if start_immediately:
            self.start_source(source_key)
        else:
            previous_status = get_source_status(DATABASE_PATH, source_key) or {}
            upsert_source_status(
                DATABASE_PATH,
                {
                    "source_key": source_key,
                    "source_type": source_record["source_type"],
                    "source_value": source_record["source_value"],
                    "client_id": source_record["client_id"],
                    "session_id": source_record["session_id"],
                    "state": "registered",
                    "is_running": False,
                    "source_fps": float(previous_status.get("source_fps", 0.0) or 0.0),
                    "last_frame_id": int(previous_status.get("last_frame_id", -1) or -1),
                    "last_source_time_seconds": float(
                        previous_status.get("last_source_time_seconds", 0.0) or 0.0
                    ),
                    "error_message": "",
                },
            )
        return get_source(DATABASE_PATH, source_key) or source_record

    def list_registered_sources(self) -> list[dict[str, Any]]:
        return list_sources(DATABASE_PATH)

    def start_source(self, source_key: str) -> dict[str, Any]:
        normalized_source_key = source_key.strip()
        source_record = get_source(DATABASE_PATH, normalized_source_key)
        if source_record is None:
            raise KeyError(normalized_source_key)

        set_source_desired_running(
            DATABASE_PATH,
            source_key=normalized_source_key,
            desired_running=True,
        )
        with self._lock:
            existing_worker = self._workers.get(normalized_source_key)
            if existing_worker is not None and existing_worker.thread.is_alive():
                return source_record

            previous_status = get_source_status(DATABASE_PATH, normalized_source_key) or {}
            stop_event = threading.Event()
            thread = threading.Thread(
                target=self._run_worker,
                args=(normalized_source_key, dict(source_record), stop_event),
                name=f"analysis-worker-{normalized_source_key}",
                daemon=True,
            )
            self._workers[normalized_source_key] = _ManagedWorker(
                source_record=dict(source_record),
                stop_event=stop_event,
                thread=thread,
            )
            upsert_source_status(
                DATABASE_PATH,
                {
                    "source_key": normalized_source_key,
                    "source_type": source_record["source_type"],
                    "source_value": source_record["source_value"],
                    "client_id": source_record["client_id"],
                    "session_id": source_record["session_id"],
                    "state": "starting",
                    "is_running": False,
                    "source_fps": float(previous_status.get("source_fps", 0.0) or 0.0),
                    "last_frame_id": int(previous_status.get("last_frame_id", -1) or -1),
                    "last_source_time_seconds": float(
                        previous_status.get("last_source_time_seconds", 0.0) or 0.0
                    ),
                    "error_message": "",
                },
            )
            thread.start()
        return get_source(DATABASE_PATH, normalized_source_key) or source_record

    def stop_source(self, source_key: str) -> dict[str, Any] | None:
        normalized_source_key = source_key.strip()
        set_source_desired_running(
            DATABASE_PATH,
            source_key=normalized_source_key,
            desired_running=False,
        )

        worker: _ManagedWorker | None = None
        with self._lock:
            worker = self._workers.pop(normalized_source_key, None)
        if worker is not None:
            worker.stop_event.set()
            worker.thread.join(timeout=10.0)

        source_record = get_source(DATABASE_PATH, normalized_source_key)
        if source_record is not None:
            previous_status = get_source_status(DATABASE_PATH, normalized_source_key) or {}
            upsert_source_status(
                DATABASE_PATH,
                {
                    "source_key": normalized_source_key,
                    "source_type": source_record["source_type"],
                    "source_value": source_record["source_value"],
                    "client_id": source_record["client_id"],
                    "session_id": source_record["session_id"],
                    "state": "stopped",
                    "is_running": False,
                    "source_fps": float(previous_status.get("source_fps", 0.0) or 0.0),
                    "last_frame_id": int(previous_status.get("last_frame_id", -1) or -1),
                    "last_source_time_seconds": float(
                        previous_status.get("last_source_time_seconds", 0.0) or 0.0
                    ),
                    "error_message": "",
                },
            )
        return source_record

    def restart_source(self, source_key: str) -> dict[str, Any]:
        self.stop_source(source_key)
        return self.start_source(source_key)

    def remove_source(self, source_key: str, *, clear_data: bool = False) -> bool:
        source_record = get_source(DATABASE_PATH, source_key)
        if source_record is None:
            return False
        self.stop_source(source_key)
        if clear_data:
            reset_source_data(
                DATABASE_PATH,
                source_key=source_key,
                source_slug=str(source_record.get("source_slug", "")).strip(),
                server_clip_dir=SERVER_CLIP_DIR,
            )
            self._delete_managed_source_file(source_record)
        deleted = delete_source(DATABASE_PATH, source_key)
        delete_source_status(DATABASE_PATH, source_key)
        prune_orphan_source_data(DATABASE_PATH)
        return deleted

    def _delete_managed_source_file(self, source_record: dict[str, Any]) -> None:
        source_type = str(source_record.get("source_type", "")).strip().lower()
        source_value = str(source_record.get("source_value", "")).strip()
        if source_type != "video" or not source_value:
            return

        try:
            file_path = Path(source_value).resolve()
            managed_roots = (
                SERVER_UPLOAD_SOURCE_DIR.resolve(),
                SERVER_SOURCE_CACHE_DIR.resolve(),
            )
        except OSError:
            return

        normalized_file = str(file_path).replace("\\", "/").lower()
        is_managed_file = False
        for managed_root in managed_roots:
            normalized_root = str(managed_root).replace("\\", "/").lower()
            if normalized_file.startswith(f"{normalized_root}/"):
                is_managed_file = True
                break
        if not is_managed_file:
            return
        if file_path.exists() and file_path.is_file():
            file_path.unlink(missing_ok=True)

    def _run_worker(
        self,
        source_key: str,
        source_record: dict[str, Any],
        stop_event: threading.Event,
    ) -> None:
        try:
            previous_status = get_source_status(DATABASE_PATH, source_key) or {}
            resume_from_seconds = 0.0
            if str(source_record.get("source_type", "")).strip().lower() == "video":
                previous_state = str(previous_status.get("state", "")).strip().lower()
                previous_time = float(
                    previous_status.get("last_source_time_seconds", 0.0) or 0.0
                )
                if previous_state != "completed" and previous_time > 0.0:
                    resume_from_seconds = max(previous_time - 1.0, 0.0)
            pipeline = build_pipeline_for_source(
                source_record,
                restart_checker=lambda: stop_event.is_set(),
                resume_from_seconds=resume_from_seconds,
            )
            stop_reason = pipeline.run()
            if stop_event.is_set():
                stop_reason = "stopped"
            if stop_reason == "completed":
                set_source_desired_running(
                    DATABASE_PATH,
                    source_key=source_key,
                    desired_running=False,
                )
            source_state = get_source(DATABASE_PATH, source_key)
            if source_state is not None and stop_reason != "source_changed":
                previous_status = get_source_status(DATABASE_PATH, source_key) or {}
                upsert_source_status(
                    DATABASE_PATH,
                    {
                        "source_key": source_key,
                        "source_type": source_state["source_type"],
                        "source_value": source_state["source_value"],
                        "client_id": source_state["client_id"],
                        "session_id": source_state["session_id"],
                        "state": stop_reason,
                        "is_running": False,
                        "source_fps": float(
                            previous_status.get("source_fps", 0.0) or 0.0
                        ),
                        "last_frame_id": int(
                            previous_status.get("last_frame_id", -1) or -1
                        ),
                        "last_source_time_seconds": float(
                            previous_status.get("last_source_time_seconds", 0.0) or 0.0
                        ),
                        "error_message": "",
                    },
                )
        except Exception as error:
            source_state = get_source(DATABASE_PATH, source_key) or source_record
            previous_status = get_source_status(DATABASE_PATH, source_key) or {}
            upsert_source_status(
                DATABASE_PATH,
                {
                    "source_key": source_key,
                    "source_type": source_state["source_type"],
                    "source_value": source_state["source_value"],
                    "client_id": source_state["client_id"],
                    "session_id": source_state["session_id"],
                    "state": "error",
                    "is_running": False,
                    "source_fps": float(previous_status.get("source_fps", 0.0) or 0.0),
                    "last_frame_id": int(previous_status.get("last_frame_id", -1) or -1),
                    "last_source_time_seconds": float(
                        previous_status.get("last_source_time_seconds", 0.0) or 0.0
                    ),
                    "error_message": str(error),
                },
            )
            print(f"[ERROR] analysis worker failed: source_key={source_key} error={error}")
        finally:
            with self._lock:
                self._workers.pop(source_key, None)
