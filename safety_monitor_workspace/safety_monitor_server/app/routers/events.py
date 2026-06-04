from typing import Any

from fastapi import APIRouter, Body, HTTPException, Query

from app.config import DATABASE_PATH
from app.database import (
    find_events_by_key,
    get_latest_event_by_key,
    insert_event,
    list_events as list_events_from_db,
    list_latest_events as list_latest_events_from_db,
    list_source_summaries,
    merge_latest_event,
)
from app.event_normalizer import normalize_event_record
from app.realtime_hub import realtime_update_hub
from app.schemas import (
    EventCreateResponse,
    EventDetailResponse,
    EventHistoryResponse,
    EventListResponse,
    SourceSummaryItem,
    SourceSummaryListResponse,
)

# 이 파일은 이벤트 저장/조회 API를 담당합니다.
# POST /api/events -> normalize_event_record -> SQLite 저장 흐름이 핵심입니다.

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
        saved_record = None
        if (
            normalized_record.get("clip_available") is True
            and str(normalized_record.get("status", "")).strip().upper() == "END"
        ):
            saved_record = merge_latest_event(DATABASE_PATH, normalized_record)
        if saved_record is None:
            saved_record = insert_event(DATABASE_PATH, normalized_record)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=500, detail="failed to save event") from error

    realtime_update_hub.publish(
        "event_changed",
        source_key=str(saved_record.get("source_key", "")).strip(),
        event_key=str(saved_record.get("event_key", "")).strip(),
        status=str(saved_record.get("status", "")).strip(),
        event_type=str(saved_record.get("event_type", "")).strip(),
    )
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
        items = list_latest_events_from_db(
            DATABASE_PATH,
            event_type=event_type,
            status=status,
            source_key=source_key,
            source_type=source_type,
            client_id=client_id,
            session_id=session_id,
        )
    else:
        items = list_events_from_db(
            DATABASE_PATH,
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
    items = list_latest_events_from_db(
        DATABASE_PATH,
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
    items = list_source_summaries(
        DATABASE_PATH,
        client_id=client_id,
        session_id=session_id,
    )
    ordered_items = [SourceSummaryItem(**item) for item in items]
    return SourceSummaryListResponse(count=len(ordered_items), items=ordered_items)


@router.get("/detail", response_model=EventDetailResponse | EventHistoryResponse)
def get_event_detail(
    event_key: str = Query(min_length=1),
    latest_only: bool = True,
    source_key: str | None = None,
) -> EventDetailResponse | EventHistoryResponse:
    # event_key 하나를 기준으로 최신 1건 또는 전체 이력을 조회합니다.
    normalized_event_key = event_key.strip()
    if not normalized_event_key:
        raise HTTPException(status_code=400, detail="event_key is required")

    if latest_only:
        item = get_latest_event_by_key(
            DATABASE_PATH,
            normalized_event_key,
            source_key=source_key,
        )
        if item is None:
            raise HTTPException(status_code=404, detail="event_key not found")

        return EventDetailResponse(event_key=normalized_event_key, item=item)

    items = find_events_by_key(
        DATABASE_PATH,
        normalized_event_key,
        source_key=source_key,
    )
    if not items:
        raise HTTPException(status_code=404, detail="event_key not found")

    return EventHistoryResponse(
        event_key=normalized_event_key,
        count=len(items),
        items=items,
    )
