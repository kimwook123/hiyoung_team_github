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
    SourceSummaryItem,
    SourceSummaryListResponse,
)

# 이 파일은 이벤트 저장/조회 API를 담당합니다.
# POST /api/events -> normalize_event_record -> append_event_record -> data/events.jsonl 저장 흐름이 핵심입니다.

router = APIRouter(prefix="/api/events", tags=["events"])


@router.post("", response_model=EventCreateResponse)
def create_event(
    event_record: dict[str, Any] = Body(...),
) -> EventCreateResponse:
    # POST는 서버에 데이터를 보내는 요청입니다.
    # 여기서는 Python AI Worker가 보낸 이벤트 JSON을 받아 서버 저장소에 기록합니다.
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
        # 정규화된 이벤트를 서버 소유 JSON Lines 저장소에 append합니다.
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
    source_key: str | None = None,
    source_type: str | None = None,
    client_id: str | None = None,
    session_id: str | None = None,
) -> EventListResponse:
    # GET은 서버에서 데이터를 가져오는 요청입니다.
    if latest_only:
        items = get_latest_events_by_key(DEFAULT_EVENT_LOG_PATH)
    else:
        items = read_event_records(DEFAULT_EVENT_LOG_PATH)

    items = _filter_items(
        items,
        event_type=event_type,
        status=status,
        source_key=source_key,
        source_type=source_type,
        client_id=client_id,
        session_id=session_id,
    )

    if limit is not None:
        items = items[-limit:]

    return EventListResponse(count=len(items), items=items)


@router.get("/latest", response_model=EventListResponse)
def list_latest_events(
    limit: int | None = Query(default=None, ge=1),
    event_type: str | None = None,
    status: str | None = None,
    source_key: str | None = None,
    source_type: str | None = None,
    client_id: str | None = None,
    session_id: str | None = None,
) -> EventListResponse:
    items = get_latest_events_by_key(DEFAULT_EVENT_LOG_PATH)
    items = _filter_items(
        items,
        event_type=event_type,
        status=status,
        source_key=source_key,
        source_type=source_type,
        client_id=client_id,
        session_id=session_id,
    )

    if limit is not None:
        items = items[-limit:]

    return EventListResponse(count=len(items), items=items)


@router.get("/sources", response_model=SourceSummaryListResponse)
def list_sources(
    client_id: str | None = None,
    session_id: str | None = None,
) -> SourceSummaryListResponse:
    items = read_event_records(DEFAULT_EVENT_LOG_PATH)
    items = _filter_items(
        items,
        event_type=None,
        status=None,
        source_key=None,
        source_type=None,
        client_id=client_id,
        session_id=session_id,
    )

    summary_by_key: dict[str, SourceSummaryItem] = {}
    for item in items:
        source_key = str(item.get("source_key", "")).strip()
        if not source_key:
            continue

        source_type = str(item.get("source_type", "")).strip()
        source_value = str(item.get("source_value", "")).strip()
        latest_received_at = str(item.get("received_at", "")).strip()

        previous = summary_by_key.get(source_key)
        if previous is None:
            summary_by_key[source_key] = SourceSummaryItem(
                source_key=source_key,
                source_type=source_type,
                source_value=source_value,
                event_count=1,
                latest_received_at=latest_received_at,
            )
            continue

        summary_by_key[source_key] = SourceSummaryItem(
            source_key=source_key,
            source_type=previous.source_type or source_type,
            source_value=previous.source_value or source_value,
            event_count=previous.event_count + 1,
            latest_received_at=max(previous.latest_received_at, latest_received_at),
        )

    ordered_items = sorted(
        summary_by_key.values(),
        key=lambda item: (item.latest_received_at, item.source_key),
        reverse=True,
    )
    return SourceSummaryListResponse(count=len(ordered_items), items=ordered_items)


@router.get("/detail", response_model=EventDetailResponse | EventHistoryResponse)
def get_event_detail(
    event_key: str = Query(min_length=1),
    latest_only: bool = True,
) -> EventDetailResponse | EventHistoryResponse:
    # event_key 하나를 기준으로 최신 1건 또는 전체 이력을 조회합니다.
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
    source_key: str | None,
    source_type: str | None,
    client_id: str | None,
    session_id: str | None,
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

    if source_key is not None:
        filtered_items = [
            item for item in filtered_items if item.get("source_key") == source_key
        ]

    if source_type is not None:
        filtered_items = [
            item for item in filtered_items if item.get("source_type") == source_type
        ]

    if client_id is not None:
        filtered_items = [
            item for item in filtered_items if item.get("client_id") == client_id
        ]

    if session_id is not None:
        filtered_items = [
            item for item in filtered_items if item.get("session_id") == session_id
        ]

    return filtered_items
