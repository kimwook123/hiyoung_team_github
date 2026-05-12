from fastapi import APIRouter, HTTPException, Query

from app.config import DEFAULT_EVENT_LOG_PATH
from app.event_store import (
    find_events_by_key,
    get_latest_event_by_key,
    get_latest_events_by_key,
    read_event_records,
)
from app.schemas import EventDetailResponse, EventHistoryResponse, EventListResponse


router = APIRouter(prefix="/api/events", tags=["events"])


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
