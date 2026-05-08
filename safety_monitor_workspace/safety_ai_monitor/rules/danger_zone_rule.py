from datetime import datetime

from core.detection_model import Detection, DetectionResult
from core.event_rule import Event, EventRule
from core.event_types import EventLevel, EventType


class DangerZoneRule(EventRule):
    def __init__(self, roi: tuple[int, int, int, int]) -> None:
        self.roi = roi

    def check(self, result: DetectionResult) -> list[Event]:
        events = []
        for detection in result.detections:
            if detection.name != "person":
                continue

            if self._is_center_in_roi(detection):
                events.append(
                    Event(
                        event_type=EventType.DANGER_ZONE,
                        message="위험구역 침입 이벤트 발생",
                        frame_id=result.frame_id,
                        created_at=result.event_created_at or datetime.now(),
                        level=EventLevel.DANGER,
                        related_detections=[detection],
                        source_time_seconds=result.source_time_seconds,
                        source_time_text=result.source_time_text,
                    )
                )

        return events

    def _is_center_in_roi(self, detection: Detection) -> bool:
        roi_x1, roi_y1, roi_x2, roi_y2 = self.roi
        center_x, center_y = detection.box.center()
        return roi_x1 <= center_x <= roi_x2 and roi_y1 <= center_y <= roi_y2

    def get_name(self) -> str:
        return "DangerZoneRule"
