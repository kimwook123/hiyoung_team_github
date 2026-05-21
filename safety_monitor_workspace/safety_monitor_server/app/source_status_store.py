import json
from datetime import datetime
from pathlib import Path


def read_source_status_records(status_path: Path) -> list[dict]:
    if not status_path.exists():
        return []

    try:
        data = json.loads(status_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return []

    if not isinstance(data, list):
        return []

    return [item for item in data if isinstance(item, dict)]


def upsert_source_status(status_path: Path, record: dict) -> dict:
    if not isinstance(record, dict):
        raise ValueError("source status record must be a dict")

    source_key = str(record.get("source_key", "")).strip()
    if not source_key:
        raise ValueError("source_key is required")

    status_path.parent.mkdir(parents=True, exist_ok=True)
    records = read_source_status_records(status_path)
    saved_record = dict(record)
    saved_record["updated_at"] = (
        str(saved_record.get("updated_at", "")).strip() or datetime.now().isoformat()
    )

    next_records = [
        item
        for item in records
        if str(item.get("source_key", "")).strip() != source_key
    ]
    next_records.append(saved_record)
    status_path.write_text(
        json.dumps(next_records, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return saved_record


def remove_source_status_by_source_key(status_path: Path, source_key: str) -> int:
    records = read_source_status_records(status_path)
    next_records = [
        item
        for item in records
        if str(item.get("source_key", "")).strip() != source_key
    ]
    removed_count = len(records) - len(next_records)
    status_path.parent.mkdir(parents=True, exist_ok=True)
    status_path.write_text(
        json.dumps(next_records, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return removed_count
