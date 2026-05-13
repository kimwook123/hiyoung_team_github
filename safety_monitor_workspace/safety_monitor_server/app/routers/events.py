from typing import Any

from fastapi import APIRouter, Body, HTTPException, Query

from app.config import DEFAULT_EVENT_LOG_PATH
from app.event_normalizer import normalize_event_record
from app.event_store import (
    append_event_record,
    find_events_by_key,
    get_latest_event_by_key,
    get_latest_events_by_key,
    read_event_records,
)
from app.schemas import (
    EventCreateResponse,
    EventDetailResponse,
    EventHistoryResponse,
    EventListResponse,
)


router = APIRouter(prefix="/api/events", tags=["events"])


@router.post("", response_model=EventCreateResponse)
def create_event(
    event_record: dict[str, Any] = Body(...),
) -> EventCreateResponse:
    if not event_record:
        raise HTTPException(status_code=400, detail="event record is required")

    normalized_record = dict(event_record)

    event_key = str(normalized_record.get("event_key", "")).strip()
    if not event_key:
        raise HTTPException(status_code=400, detail="event_key is required")

    event_type = str(normalized_record.get("event_type", "")).strip()
    if not event_type:
        raise HTTPException(status_code=400, detail="event_type is required")

    normalized_record["event_key"] = event_key
    normalized_record["event_type"] = event_type

    if "message" not in normalized_record or normalized_record["message"] is None:
        normalized_record["message"] = ""

    status = str(normalized_record.get("status", "")).strip()
    if not status:
        normalized_record["status"] = "ACTIVE"

    normalized_record = normalize_event_record(normalized_record)

    try:
        saved_record = append_event_record(DEFAULT_EVENT_LOG_PATH, normalized_record)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=500, detail="failed to save event") from error

    return EventCreateResponse(ok=True, item=saved_record)


@router.get("", response_model=EventListResponse)
def list_events(
    latest_only: bool = False,
    limit: int | None = Query(default=None, ge=1),
    event_type: str | None = None,
    status: str | None = None,
) -> EventListResponse:
    if latest_only:
        items = get_latest_events_by_key(DEFAULT_EVENT_LOG_PATH)
    else:
        items = read_event_records(DEFAULT_EVENT_LOG_PATH)

    items = _filter_items(items, event_type=event_type, status=status)

    if limit is not None:
        items = items[-limit:]

    return EventListResponse(count=len(items), items=items)


@router.get("/latest", response_model=EventListResponse)
def list_latest_events(
    limit: int | None = Query(default=None, ge=1),
    event_type: str | None = None,
    status: str | None = None,
) -> EventListResponse:
    items = get_latest_events_by_key(DEFAULT_EVENT_LOG_PATH)
    items = _filter_items(items, event_type=event_type, status=status)

    if limit is not None:
        items = items[-limit:]

    return EventListResponse(count=len(items), items=items)


@router.get("/detail", response_model=EventDetailResponse | EventHistoryResponse)
def get_event_detail(
    event_key: str = Query(min_length=1),
    latest_only: bool = True,
) -> EventDetailResponse | EventHistoryResponse:
    normalized_event_key = event_key.strip()
    if not normalized_event_key:
        raise HTTPException(status_code=400, detail="event_key is required")

    if latest_only:
        item = get_latest_event_by_key(DEFAULT_EVENT_LOG_PATH, normalized_event_key)
        if item is None:
            raise HTTPException(status_code=404, detail="event_key not found")

        return EventDetailResponse(event_key=normalized_event_key, item=item)

    items = find_events_by_key(DEFAULT_EVENT_LOG_PATH, normalized_event_key)
    if not items:
        raise HTTPException(status_code=404, detail="event_key not found")

    return EventHistoryResponse(
        event_key=normalized_event_key,
        count=len(items),
        items=items,
    )


def _filter_items(
    items: list[dict],
    event_type: str | None,
    status: str | None,
) -> list[dict]:
    filtered_items = items

    if event_type is not None:
        filtered_items = [
            item for item in filtered_items if item.get("event_type") == event_type
        ]

    if status is not None:
        filtered_items = [
            item for item in filtered_items if item.get("status") == status
        ]

    return filtered_items
