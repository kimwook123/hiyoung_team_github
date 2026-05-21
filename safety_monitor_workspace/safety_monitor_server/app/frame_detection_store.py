import json
import time
from datetime import datetime
from pathlib import Path


def append_frame_detection_record(log_path: Path, record: dict) -> dict:
    if not isinstance(record, dict):
        raise ValueError("frame detection record must be a dict")

    log_path.parent.mkdir(parents=True, exist_ok=True)

    saved_record = dict(record)
    if "received_at" not in saved_record:
        saved_record["received_at"] = datetime.now().isoformat()

    line = json.dumps(saved_record, ensure_ascii=False) + "\n"
    for attempt in range(3):
        try:
            with log_path.open("a", encoding="utf-8") as log_file:
                log_file.write(line)
            return saved_record
        except PermissionError:
            if attempt == 2:
                raise
            time.sleep(0.1)

    return saved_record


def read_frame_detection_records(log_path: Path) -> list[dict]:
    if not log_path.exists():
        return []

    records: list[dict] = []
    with log_path.open("r", encoding="utf-8") as log_file:
        for line in log_file:
            raw_line = line.strip()
            if not raw_line:
                continue

            try:
                record = json.loads(raw_line)
            except json.JSONDecodeError:
                continue

            if isinstance(record, dict):
                records.append(record)

    return records


def find_current_frame_detection(
    log_path: Path,
    *,
    source_key: str,
    source_time_seconds: float,
    tolerance_seconds: float,
) -> dict | None:
    normalized_source_key = source_key.strip()
    if not normalized_source_key:
        return None

    before_or_equal: dict | None = None
    after: dict | None = None

    for record in read_frame_detection_records(log_path):
        if str(record.get("source_key", "")).strip() != normalized_source_key:
            continue

        record_seconds = _to_float(record.get("source_time_seconds"))
        if record_seconds is None:
            continue

        if record_seconds <= source_time_seconds:
            before_or_equal = record
            continue

        if after is None:
            after = record
        break

    best_record: dict | None = None
    if before_or_equal is not None:
        before_seconds = _to_float(before_or_equal.get("source_time_seconds")) or 0.0
        if abs(source_time_seconds - before_seconds) <= tolerance_seconds:
            best_record = before_or_equal

    if after is not None:
        after_seconds = _to_float(after.get("source_time_seconds")) or 0.0
        if abs(after_seconds - source_time_seconds) <= tolerance_seconds:
            if best_record is None:
                best_record = after
            else:
                best_seconds = _to_float(best_record.get("source_time_seconds")) or 0.0
                if abs(after_seconds - source_time_seconds) < abs(
                    best_seconds - source_time_seconds
                ):
                    best_record = after

    return best_record


def remove_frame_detections_by_source_key(log_path: Path, source_key: str) -> int:
    if not log_path.exists():
        return 0

    removed_count = 0
    kept_lines: list[str] = []
    with log_path.open("r", encoding="utf-8") as log_file:
        for line in log_file:
            raw_line = line.strip()
            if not raw_line:
                continue

            try:
                record = json.loads(raw_line)
            except json.JSONDecodeError:
                kept_lines.append(raw_line)
                continue

            if (
                isinstance(record, dict)
                and str(record.get("source_key", "")).strip() == source_key
            ):
                removed_count += 1
                continue

            kept_lines.append(raw_line)

    next_text = "" if not kept_lines else "".join(f"{line}\n" for line in kept_lines)
    log_path.write_text(next_text, encoding="utf-8")
    return removed_count


def _to_float(value: object) -> float | None:
    if isinstance(value, float):
        return value
    if isinstance(value, int):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None
