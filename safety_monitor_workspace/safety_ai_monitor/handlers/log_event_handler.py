from pathlib import Path
import time

from core.event_handler import EventHandler
from core.event_rule import Event
from core.event_types import EventStatus

# 이 파일은 기존 Flutter 파일 로그 모드와 호환되는 txt 로그를 기록합니다.
# GUI가 EventLogItem.fromLine()으로 읽는 한 줄 텍스트 형식을 여기서 만듭니다.


class LogEventHandler(EventHandler):
    # Event를 사람이 읽기 쉬운 txt 한 줄 형식으로 남기는 핸들러입니다.
    def __init__(self, log_path: str = "logs/event_log.txt") -> None:
        self.log_path = Path(log_path)
        self.last_written_lines: dict[str, str] = {}

        # 현재 선택한 입력의 로그는 매번 새로 시작한다
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_path.write_text("", encoding="utf-8")

    def handle(self, event: Event) -> None:
        # 같은 event_key의 완전히 같은 줄은 다시 쓰지 않아 로그 중복을 줄입니다.
        # logs 폴더가 없으면 생성한다
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
                # 다른 프로세스가 읽는 순간이면 잠시 뒤 다시 시도한다
                last_error = error
                time.sleep(0.05)

        if last_error is not None:
            raise last_error

    def _make_line(self, event: Event) -> str:
        # txt 로그는 GUI 호환을 위해 기존 쉼표 구분 형식을 그대로 유지합니다.
        person_text = "unknown"
        if event.person_id is not None:
            person_text = str(event.person_id)

        status_text = EventStatus.END.value
        if event.ended_at is None or event.ended_frame_id is None:
            status_text = EventStatus.ACTIVE.value

        end_text = event.ended_source_time_text or "-"
        end_frame_text = str(event.ended_frame_id) if event.ended_frame_id is not None else "-"
        clip_path_text = event.clip_path if event.clip_path else "-"
        time_text = event.started_source_time_text or event.source_time_text

        return (
            f"{time_text},"
            f"frame={event.frame_id},"
            f"event_key={event.event_key},"
            f"status={status_text},"
            f"type={event.event_type.value},"
            f"person_id={person_text},"
            f"level={event.level.value},"
            f"start={event.started_source_time_text or '-'},"
            f"start_frame={event.started_frame_id if event.started_frame_id is not None else '-'},"
            f"end={end_text},"
            f"end_frame={end_frame_text},"
            f"duration={event.duration_seconds:.1f}s,"
            f"clip_path={clip_path_text},"
            f"message={event.message}\n"
        )
