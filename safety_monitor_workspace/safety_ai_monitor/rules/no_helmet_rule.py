from datetime import datetime

from core.detection_model import Box, Detection, DetectionResult
from core.event_rule import Event, EventRule
from core.event_types import EventLevel, EventType

# 이 파일은 person과 helmet 탐지 결과를 이용해 안전모 미착용 의심 이벤트를 만듭니다.


class NoHelmetRule(EventRule):
    # 사람 박스의 상단 일부를 머리 영역으로 보고, 그 안에 helmet이 있는지 확인합니다.
    def __init__(self, head_ratio: float = 0.3, overlap_ratio: float = 0.2) -> None:
        self.head_ratio = min(max(head_ratio, 0.1), 0.5)
        self.overlap_ratio = min(max(overlap_ratio, 0.0), 1.0)

    def check(self, result: DetectionResult) -> list[Event]:
        # DetectionResult에서 person과 helmet만 골라 Event 목록으로 바꾸는 단계입니다.
        persons = [d for d in result.detections if d.name == "person"]
        helmets = [d for d in result.detections if d.name == "helmet"]

        events = []
        for person in persons:
            if self._has_matching_helmet(person=person, helmets=helmets):
                continue

            events.append(
                Event(
                    event_type=EventType.NO_HELMET,
                    message="안전모 미착용 의심 이벤트 발생",
                    frame_id=result.frame_id,
                    created_at=result.event_created_at or datetime.now(),
                    level=EventLevel.WARNING,
                    related_detections=[person],
                    source_time_seconds=result.source_time_seconds,
                    source_time_text=result.source_time_text,
                )
            )

        return events

    def _has_matching_helmet(self, person: Detection, helmets: list[Detection]) -> bool:
        head_box = self._make_head_box(person.box)
        for helmet in helmets:
            if self._is_helmet_in_head_box(head_box=head_box, helmet=helmet):
                return True
        return False

    def _make_head_box(self, person_box: Box) -> Box:
        head_height = max(1, int(person_box.height() * self.head_ratio))
        return Box(
            x1=person_box.x1,
            y1=person_box.y1,
            x2=person_box.x2,
            y2=person_box.y1 + head_height,
        )

    def _is_helmet_in_head_box(self, head_box: Box, helmet: Detection) -> bool:
        center_x, center_y = helmet.box.center()
        center_inside = (
            head_box.x1 <= center_x <= head_box.x2
            and head_box.y1 <= center_y <= head_box.y2
        )
        if center_inside:
            return True

        overlap_ratio = self._get_overlap_ratio(head_box=head_box, helmet_box=helmet.box)
        return overlap_ratio >= self.overlap_ratio

    def _get_overlap_ratio(self, head_box: Box, helmet_box: Box) -> float:
        overlap_x1 = max(head_box.x1, helmet_box.x1)
        overlap_y1 = max(head_box.y1, helmet_box.y1)
        overlap_x2 = min(head_box.x2, helmet_box.x2)
        overlap_y2 = min(head_box.y2, helmet_box.y2)

        overlap_width = max(0, overlap_x2 - overlap_x1)
        overlap_height = max(0, overlap_y2 - overlap_y1)
        overlap_area = overlap_width * overlap_height
        head_area = max(1, head_box.width() * head_box.height())
        return overlap_area / head_area

    def get_name(self) -> str:
        return "NoHelmetRule"
