from dataclasses import dataclass
from datetime import datetime

from core.event_rule import Event
from core.event_types import EventStatus


@dataclass
class ActiveEventState:
    event_type: str
    message: str
    level: str
    frame_id: int
    started_frame_id: int
    last_frame_id: int
    started_at: datetime
    last_seen_at: datetime
    source_time_seconds: float
    source_time_text: str
    started_source_time_text: str
    related_detections: list
    missed_frames: int = 0


class EventFilter:
    def __init__(self, cooldown_seconds: int, end_missing_frames: int = 5) -> None:
        self.cooldown_seconds = cooldown_seconds
        self.end_missing_frames = max(1, end_missing_frames)
        self.active_events: dict[str, ActiveEventState] = {}
        self.closed_events: dict[str, ActiveEventState] = {}

    def update(self, events: list[Event]) -> list[Event]:
        # 현재 프레임 이벤트를 바탕으로 시작/종료 이벤트를 만든다
        output_events = []
        current_event_map = {self._make_event_key(event): event for event in events}

        for event_key, event in current_event_map.items():
            active_state = self.active_events.get(event_key)
            if active_state is None:
                reopened_state = self._try_reopen_closed_event(
                    event_key=event_key,
                    event=event,
                )
                if reopened_state is not None:
                    self.active_events[event_key] = reopened_state
                    continue

                self.active_events[event_key] = ActiveEventState(
                    event_type=event.event_type.value,
                    message=event.message,
                    level=event.level.value,
                    frame_id=event.frame_id,
                    started_frame_id=event.frame_id,
                    last_frame_id=event.frame_id,
                    started_at=event.created_at,
                    last_seen_at=event.created_at,
                    source_time_seconds=event.source_time_seconds,
                    source_time_text=event.source_time_text,
                    started_source_time_text=event.source_time_text,
                    related_detections=event.related_detections,
                )
                output_events.append(
                    self._build_event(
                        source_event=event,
                        event_key=event_key,
                        status=EventStatus.START,
                        started_at=event.created_at,
                        ended_at=None,
                        duration_seconds=0.0,
                        started_frame_id=event.frame_id,
                        ended_frame_id=None,
                        started_source_time_text=event.source_time_text,
                        ended_source_time_text="",
                    )
                )
                continue

            active_state.frame_id = event.frame_id
            active_state.last_frame_id = event.frame_id
            active_state.last_seen_at = event.created_at
            active_state.source_time_seconds = event.source_time_seconds
            active_state.source_time_text = event.source_time_text
            active_state.related_detections = event.related_detections
            active_state.missed_frames = 0

        ended_keys = []
        for event_key, active_state in self.active_events.items():
            if event_key in current_event_map:
                continue

            active_state.missed_frames += 1
            if active_state.missed_frames >= self.end_missing_frames:
                output_events.append(
                    Event(
                        event_type=self._parse_event_type(active_state.event_type),
                        message=active_state.message,
                        frame_id=active_state.frame_id,
                        created_at=active_state.last_seen_at,
                        level=self._parse_event_level(active_state.level),
                        related_detections=active_state.related_detections,
                        status=EventStatus.END,
                        started_at=active_state.started_at,
                        ended_at=active_state.last_seen_at,
                        duration_seconds=self._get_duration_seconds(active_state),
                        event_key=event_key,
                        started_frame_id=active_state.started_frame_id,
                        ended_frame_id=active_state.last_frame_id,
                        source_time_seconds=active_state.source_time_seconds,
                        source_time_text=active_state.source_time_text,
                        started_source_time_text=active_state.started_source_time_text,
                        ended_source_time_text=active_state.source_time_text,
                    )
                )
                self.closed_events[event_key] = ActiveEventState(
                    event_type=active_state.event_type,
                    message=active_state.message,
                    level=active_state.level,
                    frame_id=active_state.frame_id,
                    started_frame_id=active_state.started_frame_id,
                    last_frame_id=active_state.last_frame_id,
                    started_at=active_state.started_at,
                    last_seen_at=active_state.last_seen_at,
                    source_time_seconds=active_state.source_time_seconds,
                    source_time_text=active_state.source_time_text,
                    started_source_time_text=active_state.started_source_time_text,
                    related_detections=active_state.related_detections,
                    missed_frames=0,
                )
                ended_keys.append(event_key)

        for event_key in ended_keys:
            del self.active_events[event_key]

        return output_events

    def get_active_events(self, frame_id: int, now: datetime) -> list[Event]:
        active_events = []
        for event_key, active_state in self.active_events.items():
            active_events.append(
                Event(
                    event_type=self._parse_event_type(active_state.event_type),
                    message=active_state.message,
                    frame_id=frame_id,
                    created_at=active_state.last_seen_at,
                    level=self._parse_event_level(active_state.level),
                    related_detections=active_state.related_detections,
                    status=EventStatus.ACTIVE,
                    started_at=active_state.started_at,
                    ended_at=None,
                    duration_seconds=self._get_duration_seconds(active_state),
                    event_key=event_key,
                    started_frame_id=active_state.started_frame_id,
                    ended_frame_id=None,
                    source_time_seconds=active_state.source_time_seconds,
                    source_time_text=active_state.source_time_text,
                    started_source_time_text=active_state.started_source_time_text,
                    ended_source_time_text="",
                )
            )
        return active_events

    def close_all(self) -> list[Event]:
        output_events = []
        for event_key, active_state in list(self.active_events.items()):
            output_events.append(
                Event(
                    event_type=self._parse_event_type(active_state.event_type),
                    message=active_state.message,
                    frame_id=active_state.frame_id,
                    created_at=active_state.last_seen_at,
                    level=self._parse_event_level(active_state.level),
                    related_detections=active_state.related_detections,
                    status=EventStatus.END,
                    started_at=active_state.started_at,
                    ended_at=active_state.last_seen_at,
                    duration_seconds=self._get_duration_seconds(active_state),
                    event_key=event_key,
                    started_frame_id=active_state.started_frame_id,
                    ended_frame_id=active_state.last_frame_id,
                    source_time_seconds=active_state.source_time_seconds,
                    source_time_text=active_state.source_time_text,
                    started_source_time_text=active_state.started_source_time_text,
                    ended_source_time_text=active_state.source_time_text,
                )
            )
            self.closed_events[event_key] = ActiveEventState(
                event_type=active_state.event_type,
                message=active_state.message,
                level=active_state.level,
                frame_id=active_state.frame_id,
                started_frame_id=active_state.started_frame_id,
                last_frame_id=active_state.last_frame_id,
                started_at=active_state.started_at,
                last_seen_at=active_state.last_seen_at,
                source_time_seconds=active_state.source_time_seconds,
                source_time_text=active_state.source_time_text,
                started_source_time_text=active_state.started_source_time_text,
                related_detections=active_state.related_detections,
                missed_frames=0,
            )
            del self.active_events[event_key]
        return output_events

    def _build_event(
        self,
        source_event: Event,
        event_key: str,
        status: EventStatus,
        started_at: datetime,
        ended_at: datetime | None,
        duration_seconds: float,
        started_frame_id: int,
        ended_frame_id: int | None,
        started_source_time_text: str,
        ended_source_time_text: str,
    ) -> Event:
        return Event(
            event_type=source_event.event_type,
            message=source_event.message,
            frame_id=source_event.frame_id,
            created_at=source_event.created_at,
            level=source_event.level,
            related_detections=source_event.related_detections,
            status=status,
            started_at=started_at,
            ended_at=ended_at,
            duration_seconds=duration_seconds,
            event_key=event_key,
            started_frame_id=started_frame_id,
            ended_frame_id=ended_frame_id,
            source_time_seconds=source_event.source_time_seconds,
            source_time_text=source_event.source_time_text,
            started_source_time_text=started_source_time_text,
            ended_source_time_text=ended_source_time_text,
        )

    def _get_duration_seconds(self, active_state: ActiveEventState) -> float:
        return max(
            0.0,
            (active_state.last_seen_at - active_state.started_at).total_seconds(),
        )

    def _make_event_key(self, event: Event) -> str:
        if event.person_id is not None:
            return f"{event.event_type.value}:person:{event.person_id}"
        return event.event_type.value

    def _try_reopen_closed_event(
        self,
        event_key: str,
        event: Event,
    ) -> ActiveEventState | None:
        closed_state = self.closed_events.get(event_key)
        if closed_state is None:
            return None

        gap_seconds = (event.created_at - closed_state.last_seen_at).total_seconds()
        if gap_seconds > self.cooldown_seconds:
            return None

        return ActiveEventState(
            event_type=event.event_type.value,
            message=event.message,
            level=event.level.value,
            frame_id=event.frame_id,
            started_frame_id=closed_state.started_frame_id,
            last_frame_id=event.frame_id,
            started_at=closed_state.started_at,
            last_seen_at=event.created_at,
            source_time_seconds=event.source_time_seconds,
            source_time_text=event.source_time_text,
            started_source_time_text=closed_state.started_source_time_text,
            related_detections=event.related_detections,
            missed_frames=0,
        )

    def _parse_event_type(self, event_type_value: str):
        from core.event_types import EventType

        return EventType(event_type_value)

    def _parse_event_level(self, level_value: str):
        from core.event_types import EventLevel

        return EventLevel(level_value)
