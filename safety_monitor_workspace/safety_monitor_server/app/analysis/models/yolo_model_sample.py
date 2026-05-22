import os
from pathlib import Path

import numpy as np

from core.detection_model import Box, Detection, DetectionModel, DetectionResult
from core.path_helper import to_project_path

# 이 파일은 Ultralytics YOLO 결과를 DetectionResult 공통 형식으로 바꾸는 어댑터입니다.


class YoloModelSample(DetectionModel):
    # 실제 YOLO 모델을 프로젝트 공통 인터페이스에 맞춰 감싼 구현체입니다.
    def __init__(self, model_path: str, min_confidence: float = 0.5) -> None:
        self.model_path = model_path
        self.min_confidence = min_confidence
        self.model = None

    def load(self) -> None:
        # Keep Ultralytics writable even in restricted Windows environments.
        os.environ.setdefault("YOLO_CONFIG_DIR", to_project_path(".yolo_config"))

        try:
            from ultralytics import YOLO
        except ModuleNotFoundError as error:
            raise RuntimeError(
                "YOLO 모델을 사용하려면 ultralytics 설치가 필요합니다. "
                "예: pip install ultralytics"
            ) from error

        if not Path(self.model_path).exists():
            raise RuntimeError(
                f"YOLO 가중치 파일을 찾을 수 없습니다: {self.model_path}"
            )

        self.model = YOLO(self.model_path)

    def predict(self, frame: np.ndarray, frame_id: int) -> DetectionResult:
        # 모델 원본 출력은 그대로 흘리지 않고 Detection/Box 구조로 변환합니다.
        if self.model is None:
            raise RuntimeError("YoloModelSample.load()를 먼저 호출해야 합니다.")

        results = self.model(frame)
        detections = []

        for result in results:
            names = result.names
            for box_data in result.boxes:
                score = float(box_data.conf[0])
                if score < self.min_confidence:
                    continue

                class_id = int(box_data.cls[0])
                name = names[class_id]
                x1, y1, x2, y2 = box_data.xyxy[0].tolist()

                detections.append(
                    Detection(
                        name=name,
                        score=score,
                        box=Box(
                            x1=int(x1),
                            y1=int(y1),
                            x2=int(x2),
                            y2=int(y2),
                        ),
                    )
                )

        return DetectionResult(frame_id=frame_id, detections=detections)

    def get_name(self) -> str:
        return "YoloModelSample"
