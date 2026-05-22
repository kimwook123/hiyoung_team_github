import numpy as np

from core.detection_model import Box, Detection, DetectionModel, DetectionResult

# 이 파일은 실제 모델 없이 파이프라인 흐름을 확인하기 위한 더미 모델입니다.


class DummyDetectionModel(DetectionModel):
    # 일정 프레임마다 person, helmet을 만들어 구조 테스트에 사용합니다.
    def __init__(self, min_confidence: float = 0.5) -> None:
        self.min_confidence = min_confidence

    def load(self) -> None:
        # 실제 AI 모델이 아니라 파이프라인 구조 확인용이다
        print("[DummyDetectionModel] 더미 모델을 사용합니다.")

    def predict(self, frame: np.ndarray, frame_id: int) -> DetectionResult:
        detections = []

        if frame_id % 5 == 0:
            detections.append(
                Detection(
                    name="person",
                    score=0.90,
                    box=Box(x1=120, y1=180, x2=260, y2=520),
                )
            )

        if frame_id % 15 == 0:
            detections.append(
                Detection(
                    name="helmet",
                    score=0.85,
                    box=Box(x1=150, y1=150, x2=220, y2=210),
                )
            )

        detections = [
            detection for detection in detections if detection.score >= self.min_confidence
        ]
        return DetectionResult(frame_id=frame_id, detections=detections)

    def get_name(self) -> str:
        return "DummyDetectionModel"
