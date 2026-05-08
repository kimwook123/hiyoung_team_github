from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime

from core.detection_model import Detection
from core.event_types import EventLevel, EventStatus, EventType


@dataclass
class Event:
    event_type: EventType
    message: str
    frame_id: int
    created_at: datetime
    level: EventLevel
    related_detections: list[Detection]
    status: EventStatus = EventStatus.ACTIVE
    started_at: datetime | None = None
    ended_at: datetime | None = None
    duration_seconds: float = 0.0
    event_key: str = ""
    started_frame_id: int | None = None
    ended_frame_id: int | None = None
    clip_path: str = ""
    source_time_seconds: float = 0.0
    source_time_text: str = ""
    started_source_time_text: str = ""
    ended_source_time_text: str = ""

    def __post_init__(self) -> None:
        if self.started_at is None:
            self.started_at = self.created_at
        if self.started_frame_id is None:
            self.started_frame_id = self.frame_id
        if not self.event_key:
            self.event_key = self.event_type.value
        if not self.started_source_time_text:
            self.started_source_time_text = self.source_time_text

    @property
    def person_id(self) -> int | None:
        if not self.related_detections:
            return None
        return self.related_detections[0].track_id


class EventRule(ABC):
    # 새로운 위험상황을 추가하려면 EventRule을 상속받고 check() 함수에서 Event 목록을 반환하면 된다.

    @abstractmethod
    def check(self, result) -> list[Event]:
        pass

    @abstractmethod
    def get_name(self) -> str:
        pass
