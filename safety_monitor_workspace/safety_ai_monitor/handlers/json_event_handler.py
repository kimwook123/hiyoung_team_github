import json
from pathlib import Path
import time

from core.event_handler import EventHandler
from core.event_rule import Event
from core.event_serializer import serialize_event


class JsonEventHandler(EventHandler):
    def __init__(self, log_path: str = "logs/events.jsonl") -> None:
        self.log_path = Path(log_path)
        self.last_written_lines: dict[str, str] = {}

        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_path.write_text("", encoding="utf-8")

    def handle(self, event: Event) -> None:
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

        line = self._make_line(event)
        if self.last_written_lines.get(event.event_key) == line:
            return

        self._append_line(line)
        self.last_written_lines[event.event_key] = line

    def _append_line(self, line: str) -> None:
        last_error: Exception | None = None

        for _ in range(5):
            try:
                with self.log_path.open("a", encoding="utf-8") as log_file:
                    log_file.write(line)
                return
            except PermissionError as error:
                last_error = error
                time.sleep(0.05)

        if last_error is not None:
            raise last_error

    def _make_line(self, event: Event) -> str:
        event_data = serialize_event(event)
        return json.dumps(event_data, ensure_ascii=False) + "\n"
