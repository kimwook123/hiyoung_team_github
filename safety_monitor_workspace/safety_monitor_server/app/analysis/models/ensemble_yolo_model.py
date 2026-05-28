import os
from pathlib import Path

import numpy as np

from core.detection_model import Box, Detection, DetectionModel, DetectionResult
from core.path_helper import to_project_path
from models.device_helper import resolve_torch_device

# 이 파일은 사람 전용 YOLO와 안전모 전용 YOLO를 함께 돌려 결과를 합치는 어댑터입니다.


class EnsembleYoloModel(DetectionModel):
    def __init__(
        self,
        person_model_path: str,
        safety_model_path: str,
        min_confidence: float = 0.5,
        device: str = "cuda:0",
        require_cuda: bool = True,
        person_class_map: dict[str, str] | None = None,
        safety_class_map: dict[str, str] | None = None,
    ) -> None:
        self.person_model_path = person_model_path
        self.safety_model_path = safety_model_path
        self.min_confidence = min_confidence
        self.person_model = None
        self.safety_model = None
        self.requested_device = device
        self.require_cuda = require_cuda
        self.device = "cpu"
        self.person_class_map = person_class_map or {
            "person": "person",
        }
        self.safety_class_map = safety_class_map or {
            "helmet": "helmet",
            "hardhat": "helmet",
        }

    def load(self) -> None:
        os.environ.setdefault("YOLO_CONFIG_DIR", to_project_path(".yolo_config"))

        try:
            from ultralytics import YOLO
        except ModuleNotFoundError as error:
            raise RuntimeError(
                "YOLO 모델을 사용하려면 ultralytics 설치가 필요합니다. "
                "예: pip install ultralytics"
            ) from error

        for model_path in [self.person_model_path, self.safety_model_path]:
            if not Path(model_path).exists():
                raise RuntimeError(
                    f"YOLO 가중치 파일을 찾을 수 없습니다: {model_path}"
                )

        self.person_model = YOLO(self.person_model_path)
        self.safety_model = YOLO(self.safety_model_path)
        self.device = resolve_torch_device(
            requested_device=self.requested_device,
            require_cuda=self.require_cuda,
        )

    def predict(self, frame: np.ndarray, frame_id: int) -> DetectionResult:
        if self.person_model is None or self.safety_model is None:
            raise RuntimeError("EnsembleYoloModel.load()를 먼저 호출해야 합니다.")

        detections = []
        detections.extend(
            self._predict_with_model(
                model=self.person_model,
                frame=frame,
                class_map=self.person_class_map,
            )
        )
        detections.extend(
            self._predict_with_model(
                model=self.safety_model,
                frame=frame,
                class_map=self.safety_class_map,
            )
        )
        return DetectionResult(frame_id=frame_id, detections=detections)

    def get_name(self) -> str:
        return "EnsembleYoloModel"

    def _predict_with_model(
        self,
        model,
        frame: np.ndarray,
        class_map: dict[str, str],
    ) -> list[Detection]:
        results = model.predict(frame, device=self.device, stream=False, verbose=False)
        detections: list[Detection] = []

        for result in results:
            names = result.names
            for box_data in result.boxes:
                score = float(box_data.conf[0])
                if score < self.min_confidence:
                    continue

                class_id = int(box_data.cls[0])
                raw_name = str(names[class_id]).strip().lower()
                mapped_name = class_map.get(raw_name)
                if not mapped_name:
                    continue

                x1, y1, x2, y2 = box_data.xyxy[0].tolist()
                detections.append(
                    Detection(
                        name=mapped_name,
                        score=score,
                        box=Box(
                            x1=int(x1),
                            y1=int(y1),
                            x2=int(x2),
                            y2=int(y2),
                        ),
                    )
                )

        return detections
