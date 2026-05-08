import json
import time
from pathlib import Path


class UiBridgeWriter:
    def __init__(self, bridge_path: str) -> None:
        self.bridge_path = Path(bridge_path)

    def write(
        self,
        source_type: str,
        source_value: str,
        log_path: str,
        model_type: str,
        source_fps: float,
    ) -> None:
        self.bridge_path.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "source_type": source_type,
            "source_value": source_value,
            "log_path": log_path,
            "model_type": model_type,
            "source_fps": source_fps,
        }
        self.bridge_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )


class SourceStateReader:
    def __init__(self, state_path: str, min_updated_at: float | None = None) -> None:
        self.state_path = Path(state_path)
        self.min_updated_at = min_updated_at

    def read(self, wait_seconds: int | None = None) -> dict[str, str]:
        deadline = None if wait_seconds is None else time.time() + wait_seconds
        while True:
            if self.state_path.exists() and self._is_fresh_enough():
                try:
                    current_state = self._read_data(raise_on_empty=False)
                except (json.JSONDecodeError, OSError):
                    current_state = {}

                if current_state:
                    return current_state

            if deadline is not None and time.time() >= deadline:
                raise RuntimeError(
                    "입력 소스 상태 파일을 찾을 수 없습니다. "
                    "Flutter GUI에서 영상 파일 또는 스트림을 먼저 선택해 주세요: "
                    f"{self.state_path}"
                )
            time.sleep(0.5)

    def read_if_changed(self, previous_state: dict[str, str]) -> dict[str, str] | None:
        if not self.state_path.exists() or not self._is_fresh_enough():
            return None

        try:
            current_state = self._read_data(raise_on_empty=False)
        except (json.JSONDecodeError, OSError):
            return None

        if not current_state:
            return None

        if (
            current_state.get("source_type") != previous_state.get("source_type")
            or current_state.get("source_value") != previous_state.get("source_value")
        ):
            return current_state

        return None

    def wait_for_change(self, previous_state: dict[str, str]) -> dict[str, str]:
        while True:
            changed_state = self.read_if_changed(previous_state)
            if changed_state is not None:
                return changed_state
            time.sleep(0.5)

    def _is_fresh_enough(self) -> bool:
        if self.min_updated_at is None:
            return True

        try:
            return self.state_path.stat().st_mtime >= self.min_updated_at
        except OSError:
            return False

    def _read_data(self, raise_on_empty: bool) -> dict[str, str]:
        text = self.state_path.read_text(encoding="utf-8")
        data = json.loads(text)
        source_type = str(data.get("source_type", "")).strip()
        source_value = str(data.get("source_value", "")).strip()

        if not source_type or not source_value:
            if raise_on_empty:
                raise RuntimeError(
                    "입력 소스 상태 파일 내용이 비어 있습니다. "
                    "Flutter GUI에서 영상 파일 또는 스트림을 다시 선택해 주세요."
                )
            return {}

        return {
            "source_type": source_type,
            "source_value": source_value,
        }
