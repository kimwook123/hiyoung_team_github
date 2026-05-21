import json
import time
from pathlib import Path

import requests

from core.detection_model import DetectionResult
from core.event_serializer import serialize_detection


class FrameDetectionRecorder:
    # 프레임 단위 전체 탐지 결과를 JSON Lines로 저장합니다.
    # 이벤트 로그와 달리 현재 프레임의 실제 탐지 객체를 그대로 복원하기 위한 용도입니다.
    def __init__(
        self,
        log_path: str,
        *,
        post_url: str = "",
        timeout_seconds: float = 1.0,
    ) -> None:
        self.log_path = Path(log_path)
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.post_url = post_url.strip()
        self.timeout_seconds = timeout_seconds

    def write(
        self,
        result: DetectionResult,
        *,
        source_type: str,
        source_value: str,
        source_key: str,
        source_slug: str,
        frame_width: int,
        frame_height: int,
    ) -> None:
        record = {
            "frame_id": result.frame_id,
            "source_type": source_type,
            "source_value": source_value,
            "source_key": source_key,
            "source_slug": source_slug,
            "source_time_seconds": result.source_time_seconds,
            "source_time_text": result.source_time_text,
            "frame_width": frame_width,
            "frame_height": frame_height,
            "detections": [
                serialize_detection(detection)
                for detection in result.detections
            ],
        }
        line = json.dumps(record, ensure_ascii=False) + "\n"
        self._append_line(line)
        self._post_record(record)

    def _append_line(self, line: str) -> None:
        last_error: Exception | None = None

        for _ in range(5):
            try:
                with self.log_path.open("a", encoding="utf-8") as log_file:
                    log_file.write(line)
                return
            except PermissionError as error:
                last_error = error
                time.sleep(0.05)

        if last_error is not None:
            raise last_error

    def _post_record(self, record: dict) -> None:
        if not self.post_url:
            return

        try:
            requests.post(
                self.post_url,
                json=record,
                timeout=self.timeout_seconds,
            )
        except requests.RequestException as error:
            print(f"[WARN] frame detection post failed: {error}")
