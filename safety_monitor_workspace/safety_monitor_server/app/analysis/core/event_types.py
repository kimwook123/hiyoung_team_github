from enum import Enum


class EventType(Enum):
    NO_HELMET = "NO_HELMET"
    DANGER_ZONE = "DANGER_ZONE"
    FALL_DOWN = "FALL_DOWN"
    FIRE_DETECTED = "FIRE_DETECTED"
    SMOKE_DETECTED = "SMOKE_DETECTED"
    LOITERING = "LOITERING"
    UNKNOWN = "UNKNOWN"


class EventLevel(Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    DANGER = "DANGER"
    CRITICAL = "CRITICAL"


class EventStatus(Enum):
    START = "START"
    ACTIVE = "ACTIVE"
    END = "END"
