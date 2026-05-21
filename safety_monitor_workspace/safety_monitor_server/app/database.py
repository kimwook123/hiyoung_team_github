import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Iterator

from app.source_identity import extract_clip_name


def init_db(db_path: Path) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with _connect(db_path) as connection:
        connection.executescript(
            """
            PRAGMA journal_mode=WAL;
            PRAGMA synchronous=NORMAL;

            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_key TEXT NOT NULL,
                event_type TEXT NOT NULL,
                status TEXT NOT NULL,
                source_key TEXT NOT NULL,
                source_type TEXT NOT NULL,
                source_value TEXT NOT NULL,
                client_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                source_time_seconds REAL NOT NULL,
                received_at TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_events_source_key
            ON events(source_key, id);

            CREATE INDEX IF NOT EXISTS idx_events_event_key
            ON events(event_key, id);

            CREATE TABLE IF NOT EXISTS frame_detections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_key TEXT NOT NULL,
                source_time_seconds REAL NOT NULL,
                frame_id INTEGER NOT NULL,
                received_at TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_frame_detections_source_time
            ON frame_detections(source_key, source_time_seconds, id);

            CREATE TABLE IF NOT EXISTS source_status (
                source_key TEXT PRIMARY KEY,
                source_type TEXT NOT NULL,
                source_value TEXT NOT NULL,
                client_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                state TEXT NOT NULL,
                is_running INTEGER NOT NULL,
                source_fps REAL NOT NULL,
                last_frame_id INTEGER NOT NULL,
                last_source_time_seconds REAL NOT NULL,
                error_message TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            """
        )


@contextmanager
def _connect(db_path: Path) -> Iterator[sqlite3.Connection]:
    connection = sqlite3.connect(db_path, timeout=30, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    try:
        yield connection
        connection.commit()
    finally:
        connection.close()


def insert_event(db_path: Path, event_record: dict) -> dict:
    saved_record = dict(event_record)
    saved_record["received_at"] = str(saved_record.get("received_at", "")).strip() or (
        datetime.now().isoformat()
    )

    with _connect(db_path) as connection:
        connection.execute(
            """
            INSERT INTO events (
                event_key, event_type, status, source_key, source_type, source_value,
                client_id, session_id, source_time_seconds, received_at, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                str(saved_record.get("event_key", "")).strip(),
                str(saved_record.get("event_type", "")).strip(),
                str(saved_record.get("status", "")).strip(),
                str(saved_record.get("source_key", "")).strip(),
                str(saved_record.get("source_type", "")).strip(),
                str(saved_record.get("source_value", "")).strip(),
                str(saved_record.get("client_id", "")).strip(),
                str(saved_record.get("session_id", "")).strip(),
                _to_float(saved_record.get("source_time_seconds")),
                saved_record["received_at"],
                json.dumps(saved_record, ensure_ascii=False),
            ),
        )
    return saved_record


def list_events(
    db_path: Path,
    *,
    event_type: str | None = None,
    status: str | None = None,
    source_key: str | None = None,
    source_type: str | None = None,
    client_id: str | None = None,
    session_id: str | None = None,
) -> list[dict]:
    query = """
        SELECT payload_json
        FROM events
        WHERE 1=1
    """
    parameters: list[object] = []
    query, parameters = _append_common_filters(
        query,
        parameters,
        event_type=event_type,
        status=status,
        source_key=source_key,
        source_type=source_type,
        client_id=client_id,
        session_id=session_id,
    )
    query += " ORDER BY id ASC"

    with _connect(db_path) as connection:
        rows = connection.execute(query, parameters).fetchall()
    return [_decode_payload(row["payload_json"]) for row in rows]


def list_latest_events(
    db_path: Path,
    *,
    event_type: str | None = None,
    status: str | None = None,
    source_key: str | None = None,
    source_type: str | None = None,
    client_id: str | None = None,
    session_id: str | None = None,
) -> list[dict]:
    ordered_items = list_events(
        db_path,
        event_type=event_type,
        status=status,
        source_key=source_key,
        source_type=source_type,
        client_id=client_id,
        session_id=session_id,
    )
    latest_by_key: dict[str, dict] = {}
    for item in ordered_items:
        event_key = str(item.get("event_key", "")).strip()
        if event_key in latest_by_key:
            latest_by_key.pop(event_key)
        latest_by_key[event_key] = item
    return list(latest_by_key.values())


def find_events_by_key(db_path: Path, event_key: str) -> list[dict]:
    with _connect(db_path) as connection:
        rows = connection.execute(
            "SELECT payload_json FROM events WHERE event_key = ? ORDER BY id ASC",
            (event_key,),
        ).fetchall()
    return [_decode_payload(row["payload_json"]) for row in rows]


def get_latest_event_by_key(db_path: Path, event_key: str) -> dict | None:
    with _connect(db_path) as connection:
        row = connection.execute(
            "SELECT payload_json FROM events WHERE event_key = ? ORDER BY id DESC LIMIT 1",
            (event_key,),
        ).fetchone()
    if row is None:
        return None
    return _decode_payload(row["payload_json"])


def list_source_summaries(
    db_path: Path,
    *,
    client_id: str | None = None,
    session_id: str | None = None,
) -> list[dict]:
    query = """
        SELECT
            source_key,
            MAX(source_type) AS source_type,
            MAX(source_value) AS source_value,
            COUNT(*) AS event_count,
            MAX(received_at) AS latest_received_at
        FROM events
        WHERE 1=1
    """
    parameters: list[object] = []
    if client_id is not None:
        query += " AND client_id = ?"
        parameters.append(client_id)
    if session_id is not None:
        query += " AND session_id = ?"
        parameters.append(session_id)
    query += """
        GROUP BY source_key
        ORDER BY latest_received_at DESC, source_key DESC
    """

    with _connect(db_path) as connection:
        rows = connection.execute(query, parameters).fetchall()
    return [
        {
            "source_key": str(row["source_key"]),
            "source_type": str(row["source_type"] or ""),
            "source_value": str(row["source_value"] or ""),
            "event_count": int(row["event_count"] or 0),
            "latest_received_at": str(row["latest_received_at"] or ""),
        }
        for row in rows
    ]


def insert_frame_detection(db_path: Path, frame_record: dict) -> dict:
    saved_record = dict(frame_record)
    saved_record["received_at"] = str(saved_record.get("received_at", "")).strip() or (
        datetime.now().isoformat()
    )
    with _connect(db_path) as connection:
        connection.execute(
            """
            INSERT INTO frame_detections (
                source_key, source_time_seconds, frame_id, received_at, payload_json
            ) VALUES (?, ?, ?, ?, ?)
            """,
            (
                str(saved_record.get("source_key", "")).strip(),
                _to_float(saved_record.get("source_time_seconds")),
                _to_int(saved_record.get("frame_id")),
                saved_record["received_at"],
                json.dumps(saved_record, ensure_ascii=False),
            ),
        )
    return saved_record


def find_current_frame_detection(
    db_path: Path,
    *,
    source_key: str,
    source_time_seconds: float,
    tolerance_seconds: float,
) -> dict | None:
    with _connect(db_path) as connection:
        before_row = connection.execute(
            """
            SELECT payload_json, source_time_seconds
            FROM frame_detections
            WHERE source_key = ? AND source_time_seconds <= ?
            ORDER BY source_time_seconds DESC, id DESC
            LIMIT 1
            """,
            (source_key, source_time_seconds),
        ).fetchone()
        after_row = connection.execute(
            """
            SELECT payload_json, source_time_seconds
            FROM frame_detections
            WHERE source_key = ? AND source_time_seconds > ?
            ORDER BY source_time_seconds ASC, id ASC
            LIMIT 1
            """,
            (source_key, source_time_seconds),
        ).fetchone()

    best_row: sqlite3.Row | None = None
    if before_row is not None and abs(before_row["source_time_seconds"] - source_time_seconds) <= tolerance_seconds:
        best_row = before_row
    if after_row is not None and abs(after_row["source_time_seconds"] - source_time_seconds) <= tolerance_seconds:
        if best_row is None or abs(after_row["source_time_seconds"] - source_time_seconds) < abs(best_row["source_time_seconds"] - source_time_seconds):
            best_row = after_row

    if best_row is None:
        return None
    return _decode_payload(best_row["payload_json"])


def upsert_source_status(db_path: Path, status_record: dict) -> dict:
    saved_record = dict(status_record)
    saved_record["updated_at"] = str(saved_record.get("updated_at", "")).strip() or (
        datetime.now().isoformat()
    )
    source_key = str(saved_record.get("source_key", "")).strip()
    with _connect(db_path) as connection:
        connection.execute(
            """
            INSERT INTO source_status (
                source_key, source_type, source_value, client_id, session_id, state,
                is_running, source_fps, last_frame_id, last_source_time_seconds,
                error_message, updated_at, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(source_key) DO UPDATE SET
                source_type=excluded.source_type,
                source_value=excluded.source_value,
                client_id=excluded.client_id,
                session_id=excluded.session_id,
                state=excluded.state,
                is_running=excluded.is_running,
                source_fps=excluded.source_fps,
                last_frame_id=excluded.last_frame_id,
                last_source_time_seconds=excluded.last_source_time_seconds,
                error_message=excluded.error_message,
                updated_at=excluded.updated_at,
                payload_json=excluded.payload_json
            """,
            (
                source_key,
                str(saved_record.get("source_type", "")).strip(),
                str(saved_record.get("source_value", "")).strip(),
                str(saved_record.get("client_id", "")).strip(),
                str(saved_record.get("session_id", "")).strip(),
                str(saved_record.get("state", "")).strip(),
                1 if bool(saved_record.get("is_running", False)) else 0,
                _to_float(saved_record.get("source_fps")),
                _to_int(saved_record.get("last_frame_id"), default=-1),
                _to_float(saved_record.get("last_source_time_seconds")),
                str(saved_record.get("error_message", "")).strip(),
                saved_record["updated_at"],
                json.dumps(saved_record, ensure_ascii=False),
            ),
        )
    return saved_record


def list_source_statuses(db_path: Path) -> list[dict]:
    with _connect(db_path) as connection:
        rows = connection.execute(
            "SELECT payload_json FROM source_status ORDER BY updated_at DESC, source_key DESC"
        ).fetchall()
    return [_decode_payload(row["payload_json"]) for row in rows]


def reset_source_data(db_path: Path, *, source_key: str, source_slug: str, server_clip_dir: Path) -> tuple[bool, int, int]:
    removed_records = list_events(db_path, source_key=source_key)
    kept_records = list_events(db_path)
    kept_records = [
        item for item in kept_records if str(item.get("source_key", "")).strip() != source_key
    ]

    with _connect(db_path) as connection:
        deleted_event_count = connection.execute(
            "DELETE FROM events WHERE source_key = ?",
            (source_key,),
        ).rowcount
        connection.execute(
            "DELETE FROM frame_detections WHERE source_key = ?",
            (source_key,),
        )
        connection.execute(
            "DELETE FROM source_status WHERE source_key = ?",
            (source_key,),
        )

    remaining_clip_names = {
        clip_name
        for clip_name in (extract_clip_name(record) for record in kept_records)
        if clip_name
    }
    removed_clip_names = {
        clip_name
        for clip_name in (extract_clip_name(record) for record in removed_records)
        if clip_name and clip_name not in remaining_clip_names
    }

    deleted_clip_count = 0
    for clip_name in removed_clip_names:
        clip_path = server_clip_dir / clip_name
        if clip_path.exists() and clip_path.is_file():
            clip_path.unlink()
            deleted_clip_count += 1

    if source_slug:
        for clip_path in server_clip_dir.glob(f"{source_slug}__*.mp4"):
            if not clip_path.is_file() or clip_path.name in remaining_clip_names:
                continue
            clip_path.unlink()
            deleted_clip_count += 1

    return bool(removed_records), deleted_event_count, deleted_clip_count


def _append_common_filters(
    query: str,
    parameters: list[object],
    *,
    event_type: str | None,
    status: str | None,
    source_key: str | None,
    source_type: str | None,
    client_id: str | None,
    session_id: str | None,
) -> tuple[str, list[object]]:
    if event_type is not None:
        query += " AND event_type = ?"
        parameters.append(event_type)
    if status is not None:
        query += " AND status = ?"
        parameters.append(status)
    if source_key is not None:
        query += " AND source_key = ?"
        parameters.append(source_key)
    if source_type is not None:
        query += " AND source_type = ?"
        parameters.append(source_type)
    if client_id is not None:
        query += " AND client_id = ?"
        parameters.append(client_id)
    if session_id is not None:
        query += " AND session_id = ?"
        parameters.append(session_id)
    return query, parameters


def _decode_payload(payload_json: str) -> dict:
    try:
        decoded = json.loads(payload_json)
    except json.JSONDecodeError:
        return {}
    return decoded if isinstance(decoded, dict) else {}


def _to_float(value: object) -> float:
    if isinstance(value, float):
        return value
    if isinstance(value, int):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return 0.0
    return 0.0


def _to_int(value: object, *, default: int = 0) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value)
        except ValueError:
            return default
    return default
