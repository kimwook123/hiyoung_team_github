import json

import requests

from handlers.clip_upload_client import ClipUploadClient
from core.event_handler import EventHandler
from core.event_rule import Event
from core.event_serializer import serialize_event


class HttpEventHandler(EventHandler):
    def __init__(
        self,
        post_url: str,
        timeout_seconds: float = 1.5,
        fallback_handler: EventHandler | None = None,
        clip_upload_client: ClipUploadClient | None = None,
    ) -> None:
        self.post_url = post_url
        self.timeout_seconds = timeout_seconds
        self.fallback_handler = fallback_handler
        self.clip_upload_client = clip_upload_client
        self.last_sent_payloads: dict[str, str] = {}

    def handle(self, event: Event) -> None:
        payload = serialize_event(event)
        self._attach_clip_upload_fields(payload, event)
        payload_text = json.dumps(payload, ensure_ascii=False, sort_keys=True)

        if self.last_sent_payloads.get(event.event_key) == payload_text:
            return

        try:
            response = requests.post(
                self.post_url,
                json=payload,
                timeout=self.timeout_seconds,
            )
            if 200 <= response.status_code < 300:
                self.last_sent_payloads[event.event_key] = payload_text
                return

            self._handle_failure(
                event,
                f"HTTP event post failed: status_code={response.status_code}",
            )
        except requests.RequestException as error:
            self._handle_failure(event, f"HTTP event post failed: {error}")

    def _attach_clip_upload_fields(self, payload: dict, event: Event) -> None:
        clip_path = str(payload.get("clip_path") or "").strip()
        if not clip_path or clip_path == "-" or self.clip_upload_client is None:
            return

        upload_result = self.clip_upload_client.upload_clip(
            clip_path=clip_path,
            event_key=event.event_key,
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

    def _handle_failure(self, event: Event, message: str) -> None:
        print(message)

        if self.fallback_handler is None:
            return

        try:
            self.fallback_handler.handle(event)
        except Exception as error:
            print(f"HTTP event fallback failed: {error}")
