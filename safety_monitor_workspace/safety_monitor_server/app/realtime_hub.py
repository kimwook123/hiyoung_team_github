from __future__ import annotations

import asyncio
import json
import threading
from typing import Any

from fastapi import WebSocket
from fastapi import WebSocketDisconnect

from app.log_utils import log_line


class RealtimeUpdateHub:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._listeners: dict[int, tuple[asyncio.AbstractEventLoop, asyncio.Queue[str]]] = {}

    async def serve(self, websocket: WebSocket) -> None:
        await websocket.accept()
        queue: asyncio.Queue[str] = asyncio.Queue(maxsize=128)
        listener_id = id(queue)
        loop = asyncio.get_running_loop()
        with self._lock:
            self._listeners[listener_id] = (loop, queue)
            listener_count = len(self._listeners)
        log_line("PUSH", event="client-connect", clients=listener_count)
        try:
            while True:
                payload = await queue.get()
                await websocket.send_text(payload)
        except WebSocketDisconnect:
            pass
        finally:
            with self._lock:
                self._listeners.pop(listener_id, None)
                listener_count = len(self._listeners)
            log_line("PUSH", event="client-disconnect", clients=listener_count)

    def publish(self, event_type: str, **payload: Any) -> None:
        message = {"type": event_type, **payload}
        encoded = json.dumps(message, ensure_ascii=False)
        with self._lock:
            listeners = list(self._listeners.values())
            listener_count = len(listeners)
        if listener_count <= 0:
            return
        log_line(
            "PUSH",
            event=event_type,
            clients=listener_count,
            source=str(payload.get("source_key", "")).strip() or None,
            action=str(payload.get("action", "")).strip() or None,
            state=str(payload.get("state", "")).strip() or None,
        )
        for loop, queue in listeners:
            loop.call_soon_threadsafe(self._enqueue_message, queue, encoded)

    @staticmethod
    def _enqueue_message(queue: asyncio.Queue[str], payload: str) -> None:
        if queue.full():
            try:
                queue.get_nowait()
            except asyncio.QueueEmpty:
                pass
        try:
            queue.put_nowait(payload)
        except asyncio.QueueFull:
            pass


realtime_update_hub = RealtimeUpdateHub()
