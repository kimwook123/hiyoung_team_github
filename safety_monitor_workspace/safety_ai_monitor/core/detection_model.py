from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime

import numpy as np


@dataclass
class Box:
    x1: int
    y1: int
    x2: int
    y2: int

    def width(self) -> int:
        return max(0, self.x2 - self.x1)

    def height(self) -> int:
        return max(0, self.y2 - self.y1)

    def center(self) -> tuple[int, int]:
        # 박스의 중심 좌표를 계산한다
        return ((self.x1 + self.x2) // 2, (self.y1 + self.y2) // 2)


@dataclass
class Detection:
    name: str
    score: float
    box: Box
    track_id: int | None = None


@dataclass
class DetectionResult:
    frame_id: int
    detections: list[Detection]
    source_time_seconds: float = 0.0
    source_time_text: str = ""
    event_created_at: datetime | None = None


class DetectionModel(ABC):
    # 모든 객체 탐지 모델이 따라야 하는 기본 구조

    @abstractmethod
    def load(self) -> None:
        pass

    @abstractmethod
    def predict(self, frame: np.ndarray, frame_id: int) -> DetectionResult:
        pass

    @abstractmethod
    def get_name(self) -> str:
        pass
