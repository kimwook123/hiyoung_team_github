import json
import time
from datetime import datetime
from pathlib import Path

# 이 파일은 events.jsonl 읽기/쓰기 유틸리티입니다.
# JSON Lines 형식으로 저장된 이벤트를 읽고, 최신 상태를 모아 주고, 새 이벤트를 append합니다.

def read_event_records(log_path: Path) -> list[dict]:
    # JSON Lines 파일을 한 줄씩 읽습니다.
    # 잘못된 줄이 있어도 서버가 죽지 않게 해당 줄만 건너뜁니다.
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
    # 같은 event_key가 여러 번 기록될 수 있으므로 마지막 상태만 남깁니다.
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


def append_event_record(log_path: Path, event_record: dict) -> dict:
    # 서버가 최종적으로 events.jsonl에 저장하는 함수입니다.
    # PermissionError는 다른 프로세스가 읽는 순간일 수 있어 잠깐 재시도합니다.
    if not isinstance(event_record, dict):
        raise ValueError("event_record must be a dict")

    log_path.parent.mkdir(parents=True, exist_ok=True)

    saved_record = dict(event_record)
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
