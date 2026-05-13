import json
from pathlib import Path
import time

from core.event_handler import EventHandler
from core.event_rule import Event
from core.event_serializer import serialize_event

# 이 파일은 Event를 로컬 JSON Lines 파일에 저장합니다.
# JSON Lines는 JSON 객체를 한 줄에 하나씩 저장하는 로그 형식입니다.


class JsonEventHandler(EventHandler):
    # 서버 없이도 구조화된 이벤트 로그를 남기기 위한 핸들러입니다.
    def __init__(self, log_path: str = "logs/events.jsonl") -> None:
        self.log_path = Path(log_path)
        self.last_written_lines: dict[str, str] = {}

        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_path.write_text("", encoding="utf-8")

    def handle(self, event: Event) -> None:
        # 같은 event_key의 완전히 같은 JSON 한 줄은 다시 쓰지 않습니다.
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
