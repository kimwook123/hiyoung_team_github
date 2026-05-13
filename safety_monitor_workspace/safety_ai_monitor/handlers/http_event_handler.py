import json

import requests

from core.event_handler import EventHandler
from core.event_rule import Event
from core.event_serializer import serialize_event


class HttpEventHandler(EventHandler):
    def __init__(
        self,
        post_url: str,
        timeout_seconds: float = 1.5,
        fallback_handler: EventHandler | None = None,
    ) -> None:
        self.post_url = post_url
        self.timeout_seconds = timeout_seconds
        self.fallback_handler = fallback_handler
        self.last_sent_payloads: dict[str, str] = {}

    def handle(self, event: Event) -> None:
        payload = serialize_event(event)
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

    def _handle_failure(self, event: Event, message: str) -> None:
        print(message)

        if self.fallback_handler is None:
            return

        try:
            self.fallback_handler.handle(event)
        except Exception as error:
            print(f"HTTP event fallback failed: {error}")
