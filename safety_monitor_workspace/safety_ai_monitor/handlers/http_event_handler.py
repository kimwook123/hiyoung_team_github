import json
from dataclasses import dataclass
from time import monotonic

import requests

from core.async_workers import AsyncTaskWorker
from core.event_handler import EventHandler
from core.event_rule import Event
from core.event_serializer import serialize_event
from handlers.clip_upload_client import ClipUploadClient
from handlers.json_event_handler import JsonEventHandler


@dataclass
class _PendingEventPost:
    event_key: str
    payload: dict[str, object]


class HttpEventHandler(EventHandler):
    # Python AI Worker가 만든 Event를 백그라운드 큐로 서버에 전송합니다.
    # 필요하면 먼저 clip_path 파일을 POST /api/clips로 업로드한 뒤 서버 클립 정보를 payload에 붙입니다.
    def __init__(
        self,
        post_url: str,
        timeout_seconds: float = 1.5,
        fallback_handler: EventHandler | None = None,
        clip_upload_client: ClipUploadClient | None = None,
        queue_size: int = 512,
        active_post_min_interval_seconds: float = 0.5,
    ) -> None:
        self.post_url = post_url
        self.timeout_seconds = timeout_seconds
        self.fallback_handler = fallback_handler
        self.clip_upload_client = clip_upload_client
        self.active_post_min_interval_seconds = max(0.0, active_post_min_interval_seconds)
        self.session = requests.Session()
        self.last_sent_payloads: dict[str, str] = {}
        self.last_queued_payloads: dict[str, str] = {}
        self.last_active_posted_at_by_key: dict[str, float] = {}
        self.worker = AsyncTaskWorker[_PendingEventPost](
            name="event-post-worker",
            consumer=self._send_pending_post,
            max_queue_size=queue_size,
        )

    def handle(self, event: Event) -> None:
        payload = serialize_event(event)
        if self._should_skip_active_payload(payload):
            return
        payload_text = json.dumps(payload, ensure_ascii=False, sort_keys=True)

        if self.last_queued_payloads.get(event.event_key) == payload_text:
            return

        submitted = self.worker.submit(
            _PendingEventPost(
                event_key=event.event_key,
                payload=payload,
            )
        )
        if submitted:
            self.last_queued_payloads[event.event_key] = payload_text
            return

        if not submitted:
            self._handle_failure_payload(
                payload,
                f"HTTP event post queue full: event_key={event.event_key}",
            )

    def _attach_clip_upload_fields(self, payload: dict[str, object]) -> None:
        clip_path = str(payload.get("clip_path") or "").strip()
        if not clip_path or clip_path == "-" or self.clip_upload_client is None:
            return

        upload_result = self.clip_upload_client.upload_clip(
            clip_path=clip_path,
            event_key=str(payload.get("event_key", "") or "").strip() or None,
            source_key=str(payload.get("source_key", "") or "").strip() or None,
            source_slug=str(payload.get("source_slug", "") or "").strip() or None,
        )
        if upload_result is None:
            payload["clip_upload_ok"] = False
            return

        payload["clip_upload_ok"] = True
        if upload_result.get("url") is not None:
            payload["clip_url"] = upload_result.get("url")
        if upload_result.get("path") is not None:
            payload["server_clip_path"] = upload_result.get("path")
        if upload_result.get("name") is not None:
            payload["server_clip_name"] = upload_result.get("name")

    def _send_pending_post(self, pending_post: _PendingEventPost) -> None:
        payload = dict(pending_post.payload)
        self._attach_clip_upload_fields(payload)
        payload_text = json.dumps(payload, ensure_ascii=False, sort_keys=True)

        if self.last_sent_payloads.get(pending_post.event_key) == payload_text:
            return

        try:
            response = self.session.post(
                self.post_url,
                json=payload,
                timeout=self.timeout_seconds,
            )
            if 200 <= response.status_code < 300:
                self.last_sent_payloads[pending_post.event_key] = payload_text
                if str(payload.get("status", "")).strip() == "ACTIVE":
                    self.last_active_posted_at_by_key[pending_post.event_key] = monotonic()
                return

            self._handle_failure_payload(
                payload,
                f"HTTP event post failed: status_code={response.status_code}",
            )
        except requests.RequestException as error:
            self._handle_failure_payload(payload, f"HTTP event post failed: {error}")

    def _handle_failure_payload(
        self,
        payload: dict[str, object],
        message: str,
    ) -> None:
        print(message)

        if self.fallback_handler is None:
            return

        try:
            if isinstance(self.fallback_handler, JsonEventHandler):
                self.fallback_handler.handle_payload(
                    payload,
                    event_key=str(payload.get("event_key", "") or ""),
                )
                return
            print("[WARN] unsupported fallback handler type for payload mode")
        except Exception as error:
            print(f"HTTP event fallback failed: {error}")

    def _should_skip_active_payload(self, payload: dict[str, object]) -> bool:
        if str(payload.get("status", "")).strip() != "ACTIVE":
            return False
        event_key = str(payload.get("event_key", "")).strip()
        if not event_key or self.active_post_min_interval_seconds <= 0:
            return False
        last_posted_at = self.last_active_posted_at_by_key.get(event_key, 0.0)
        return (monotonic() - last_posted_at) < self.active_post_min_interval_seconds

    def close(self) -> None:
        self.worker.close(timeout_seconds=max(30.0, self.timeout_seconds + 10.0))
        self.session.close()
        if self.clip_upload_client is not None:
            self.clip_upload_client.close()
