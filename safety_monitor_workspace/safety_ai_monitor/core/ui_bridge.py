import json
import time
from pathlib import Path

# 이 파일은 Flutter GUI와 Python AI Worker 사이의 파일 기반 브리지입니다.
# source_state.json은 Flutter -> Python, ui_bridge.json은 Python -> Flutter 방향으로 사용됩니다.


class UiBridgeWriter:
    # 현재 입력 소스와 로그 경로를 GUI가 참고할 수 있게 기록합니다.
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


class UiBridgeRegistry:
    # 다중 소스 환경에서 source_key별 브리지 정보를 한 파일에 유지합니다.
    def __init__(self, bridges_path: str) -> None:
        self.bridges_path = Path(bridges_path)

    def write_entry(
        self,
        *,
        source_key: str,
        source_type: str,
        source_value: str,
        log_path: str,
        model_type: str,
        source_fps: float,
    ) -> None:
        self.bridges_path.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "source_key": source_key,
            "source_type": source_type,
            "source_value": source_value,
            "log_path": log_path,
            "model_type": model_type,
            "source_fps": source_fps,
        }

        items = self._read_items()
        items = [
            item
            for item in items
            if str(item.get("source_key", "")).strip() != source_key
        ]
        items.append(entry)
        self.bridges_path.write_text(
            json.dumps(items, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _read_items(self) -> list[dict]:
        if not self.bridges_path.exists():
            return []

        try:
            data = json.loads(self.bridges_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return []

        if not isinstance(data, list):
            return []
        return [item for item in data if isinstance(item, dict)]


class SourceStateReader:
    # Flutter가 선택한 입력 소스 상태 파일을 읽는 도구입니다.
    def __init__(self, state_path: str, min_updated_at: float | None = None) -> None:
        self.state_path = Path(state_path)
        self.min_updated_at = min_updated_at

    def read(self, wait_seconds: int | None = None) -> dict[str, str]:
        # GUI가 아직 입력을 고르지 않았으면 잠시 기다립니다.
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
        # GUI에서 다른 영상이나 스트림을 고르면 파이프라인을 재시작할 수 있게 변경만 감지합니다.
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


class SourcesStateReader:
    # 다중 소스 상태 파일에서 현재 활성 입력 목록을 읽습니다.
    def __init__(self, state_path: str, min_updated_at: float | None = None) -> None:
        self.state_path = Path(state_path)
        self.min_updated_at = min_updated_at

    def read_all(self) -> list[dict[str, str]]:
        if not self.state_path.exists() or not self._is_fresh_enough():
            return []

        try:
            data = json.loads(self.state_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return []

        if isinstance(data, dict):
            normalized = self._normalize_entry(data, default_slot_id="default")
            return [] if normalized is None else [normalized]

        if not isinstance(data, list):
            return []

        items: list[dict[str, str]] = []
        for index, item in enumerate(data):
            if not isinstance(item, dict):
                continue
            normalized = self._normalize_entry(
                item,
                default_slot_id=f"slot_{index + 1}",
            )
            if normalized is not None:
                items.append(normalized)
        return items

    def _is_fresh_enough(self) -> bool:
        if self.min_updated_at is None:
            return True

        try:
            return self.state_path.stat().st_mtime >= self.min_updated_at
        except OSError:
            return False

    def _normalize_entry(
        self,
        item: dict,
        *,
        default_slot_id: str,
    ) -> dict[str, str] | None:
        source_type = str(item.get("source_type", "")).strip()
        source_value = str(item.get("source_value", "")).strip()
        if not source_type or not source_value:
            return None

        slot_id = str(item.get("slot_id", "")).strip() or default_slot_id
        client_id = str(item.get("client_id", "")).strip()
        session_id = str(item.get("session_id", "")).strip()
        return {
            "slot_id": slot_id,
            "source_type": source_type,
            "source_value": source_value,
            "client_id": client_id,
            "session_id": session_id,
        }
