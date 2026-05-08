from core.event_handler import EventHandler
from core.event_rule import Event


class ConsoleEventHandler(EventHandler):
    def handle(self, event: Event) -> None:
        person_text = "unknown"
        if event.person_id is not None:
            person_text = str(event.person_id)

        end_text = "-"
        if event.ended_at is not None:
            end_text = event.ended_at.isoformat(timespec="seconds")

        print(
            "[EVENT] "
            f"time={event.source_time_text or event.created_at.isoformat(timespec='seconds')} "
            f"frame={event.frame_id} "
            f"status={event.status.value} "
            f"type={event.event_type.value} "
            f"person_id={person_text} "
            f"level={event.level.value} "
            f"start={event.started_at.isoformat(timespec='seconds')} "
            f"end={end_text} "
            f"duration={event.duration_seconds:.1f}s "
            f"message={event.message}"
        )
