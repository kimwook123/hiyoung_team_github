import json
from pathlib import Path


def read_event_records(log_path: Path) -> list[dict]:
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


def get_latest_events_by_key(log_path: Path) -> list[dict]:
    latest_by_key: dict[object, dict] = {}

    for record in read_event_records(log_path):
        event_key = record.get("event_key")
        if event_key in latest_by_key:
            latest_by_key.pop(event_key)
        latest_by_key[event_key] = record

    return list(latest_by_key.values())


def find_events_by_key(log_path: Path, event_key: str) -> list[dict]:
    return [
        record
        for record in read_event_records(log_path)
        if record.get("event_key") == event_key
    ]


def get_latest_event_by_key(log_path: Path, event_key: str) -> dict | None:
    items = find_events_by_key(log_path, event_key)
    if not items:
        return None
    return items[-1]
