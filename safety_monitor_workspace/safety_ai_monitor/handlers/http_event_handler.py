import json

import requests

from handlers.clip_upload_client import ClipUploadClient
from core.event_handler import EventHandler
from core.event_rule import Event
from core.event_serializer import serialize_event

# 이 파일은 이벤트를 FastAPI 서버로 보내는 핸들러입니다.
# POST는 서버에 데이터를 보내는 요청이며, 실패 시 fallback handler가 대신 로컬 저장을 맡을 수 있습니다.


class HttpEventHandler(EventHandler):
    # Python AI Worker가 만든 Event를 POST /api/events로 전송합니다.
    # 필요하면 먼저 clip_path 파일을 POST /api/clips로 업로드한 뒤 서버 클립 정보를 payload에 붙입니다.
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
        # Event를 dict로 직렬화한 뒤 HTTP 요청으로 서버에 보냅니다.
        # timeout은 서버 응답을 기다리는 최대 시간이며, 200번대 상태 코드는 성공으로 봅니다.
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
        # 로컬 clip_path가 있을 때만 서버 클립 업로드를 시도합니다.
        # 업로드 성공 후 받은 clip_url은 Flutter API 모드에서 로컬 경로보다 우선 사용됩니다.
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
        # 이벤트 POST가 실패했을 때만 fallback handler가 동작합니다.
        # 예를 들어 JsonEventHandler를 fallback으로 두면 실패 이벤트를 로컬 JSONL에 남길 수 있습니다.
        print(message)

        if self.fallback_handler is None:
            return

        try:
            self.fallback_handler.handle(event)
        except Exception as error:
            print(f"HTTP event fallback failed: {error}")
