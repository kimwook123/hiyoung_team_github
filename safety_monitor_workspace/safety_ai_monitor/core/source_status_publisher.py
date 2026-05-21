from datetime import datetime

import requests


class SourceStatusPublisher:
    def __init__(
        self,
        *,
        post_url: str,
        timeout_seconds: float = 1.0,
        min_interval_seconds: float = 0.5,
    ) -> None:
        self.post_url = post_url.strip()
        self.timeout_seconds = timeout_seconds
        self.min_interval_seconds = min_interval_seconds
        self._last_posted_at = 0.0

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
        if not self.post_url or not source_key.strip():
            return

        now_ts = datetime.now().timestamp()
        if not force and (now_ts - self._last_posted_at) < self.min_interval_seconds:
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

        try:
            requests.post(
                self.post_url,
                json=payload,
                timeout=self.timeout_seconds,
            )
            self._last_posted_at = now_ts
        except requests.RequestException as error:
            print(f"[WARN] source status post failed: {error}")
