from datetime import datetime
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import APIRouter
from fastapi import Body
from fastapi import File
from fastapi import Form
from fastapi import HTTPException
from fastapi import Query
from fastapi import UploadFile

from app.config import DATABASE_PATH
from app.config import SERVER_CLIP_DIR
from app.config import SERVER_SOURCE_CACHE_DIR
from app.config import SERVER_UPLOAD_SOURCE_DIR
from app.database import (
    delete_source,
    delete_source_status,
    get_source,
    list_source_overviews,
    list_sources,
    prune_orphan_source_data,
    reset_source_data,
    upsert_source,
)
from app.realtime_hub import realtime_update_hub
from app.server_event_processor import server_event_processor
from app.schemas import SourceActionResponse
from app.schemas import SourceItem
from app.schemas import SourceListResponse
from app.schemas import SourceOverviewItem
from app.schemas import SourceOverviewListResponse
from app.schemas import SourceUpsertResponse
from app.source_identity import build_source_key
from app.source_identity import build_source_slug
from app.source_identity import normalize_video_source_value
from app.source_rule_config import normalize_rule_config

router = APIRouter(prefix="/api/sources", tags=["sources"])


@router.get("", response_model=SourceListResponse)
def list_sources_route(
    client_id: str | None = Query(default=None),
    session_id: str | None = Query(default=None),
) -> SourceListResponse:
    records = list_sources(
        DATABASE_PATH,
        client_id=client_id,
        session_id=session_id,
    )
    items = [SourceItem(**_decorate_source_record(record)) for record in records]
    return SourceListResponse(count=len(items), items=items)


@router.get("/overview", response_model=SourceOverviewListResponse)
def list_source_overview_route(
    client_id: str | None = Query(default=None),
    session_id: str | None = Query(default=None),
) -> SourceOverviewListResponse:
    records = list_source_overviews(
        DATABASE_PATH,
        client_id=client_id,
        session_id=session_id,
    )
    items = [SourceOverviewItem(**record) for record in records]
    return SourceOverviewListResponse(count=len(items), items=items)


@router.post("", response_model=SourceUpsertResponse)
def upsert_source_route(
    payload: dict[str, Any] = Body(...),
) -> SourceUpsertResponse:
    if not payload:
        raise HTTPException(status_code=400, detail="source payload is required")

    source_type = str(payload.get("source_type", "")).strip()
    source_value = str(payload.get("source_value", "")).strip()
    if not source_type:
        raise HTTPException(status_code=400, detail="source_type is required")
    if not source_value:
        raise HTTPException(status_code=400, detail="source_value is required")

    normalized_source_value = (
        normalize_video_source_value(source_value)
        if source_type.strip().lower() == "video"
        else source_value
    )
    source_key = str(payload.get("source_key", "")).strip() or build_source_key(
        source_type=source_type,
        source_value=normalized_source_value,
    )
    source_slug = str(payload.get("source_slug", "")).strip() or build_source_slug(
        source_type=source_type,
        source_value=normalized_source_value,
    )

    previous = get_source(DATABASE_PATH, source_key)
    normalized = dict(previous or {})
    normalized.update(dict(payload))
    normalized["source_key"] = source_key
    normalized["source_slug"] = source_slug
    normalized["source_type"] = source_type
    normalized["source_value"] = normalized_source_value
    normalized["source_duration_seconds"] = _read_float(
        normalized.get("source_duration_seconds")
    )
    normalized["original_source_type"] = str(
        normalized.get("original_source_type", source_type)
    ).strip() or source_type
    normalized["original_source_value"] = str(
        normalized.get("original_source_value", source_value)
    ).strip() or source_value
    normalized["client_id"] = str(normalized.get("client_id", "")).strip()
    normalized["session_id"] = str(normalized.get("session_id", "")).strip()
    normalized["desired_running"] = bool(normalized.get("desired_running", False))
    normalized["rule_config"] = normalize_rule_config(normalized.get("rule_config"))
    normalized["preview_url"] = (
        f"/api/source-streams/{source_key}?single=true"
        if source_key
        else ""
    )
    normalized["server_media_path"] = ""
    normalized["media_url"] = ""
    normalized_source_type = source_type.strip().lower()
    if normalized_source_type == "video":
        try:
            media_path = Path(normalized_source_value).resolve()
            if str(media_path).startswith(str(SERVER_UPLOAD_SOURCE_DIR.resolve())):
                normalized["server_media_path"] = f"uploaded_sources/{media_path.name}"
                normalized["media_url"] = f"/api/source-media/uploaded/{media_path.name}"
            elif str(media_path).startswith(str(SERVER_SOURCE_CACHE_DIR.resolve())):
                normalized["server_media_path"] = f"source_cache/{media_path.name}"
                normalized["media_url"] = f"/api/source-media/cached/{media_path.name}"
        except OSError:
            pass
    normalized["created_at"] = str(normalized.get("created_at", "")).strip() or (
        previous.get("created_at", "") if previous else ""
    ) or datetime.now().isoformat()
    normalized["updated_at"] = datetime.now().isoformat()

    saved = upsert_source(DATABASE_PATH, normalized)
    realtime_update_hub.publish(
        "source_changed",
        action="upserted",
        source_key=source_key,
    )
    return SourceUpsertResponse(ok=True, item=SourceItem(**_decorate_source_record(saved)))


@router.post("/upload", response_model=SourceUpsertResponse)
async def upload_source_media(
    file: UploadFile = File(...),
    source_key: str = Form(default=""),
    source_slug: str = Form(default=""),
    source_type: str = Form(default="video"),
    source_value: str = Form(default=""),
    original_source_type: str = Form(default="video"),
    original_source_value: str = Form(default=""),
    client_id: str = Form(default=""),
    session_id: str = Form(default=""),
    reset_existing: bool = Form(default=True),
    start_immediately: bool = Form(default=True),
) -> SourceUpsertResponse:
    filename = Path(file.filename or "uploaded_video.mp4").name
    if not filename:
        raise HTTPException(status_code=400, detail="invalid filename")

    suffix = Path(filename).suffix or ".mp4"
    saved_name = f"{uuid4().hex}{suffix.lower()}"
    saved_path = SERVER_UPLOAD_SOURCE_DIR / saved_name

    try:
        with saved_path.open("wb") as output:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
    finally:
        await file.close()

    if not saved_path.exists() or saved_path.stat().st_size <= 0:
        saved_path.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="uploaded file is empty")

    return upsert_source_route(
        {
            "source_key": source_key,
            "source_slug": source_slug,
            "source_type": source_type or "video",
            "source_value": source_value or str(saved_path.resolve()),
            "original_source_type": original_source_type or source_type or "video",
            "original_source_value": original_source_value or source_value or str(saved_path.resolve()),
            "client_id": client_id,
            "session_id": session_id,
            "desired_running": start_immediately,
            "source_duration_seconds": 0.0,
            "server_media_path": f"uploaded_sources/{saved_path.name}",
            "media_url": f"/api/source-media/uploaded/{saved_path.name}",
            "rule_config": normalize_rule_config({}),
        }
    )


@router.delete("/{source_key:path}", response_model=SourceActionResponse)
def delete_source_route(
    source_key: str,
    clear_data: bool = Query(default=False),
    client_id: str = Query(default=""),
    session_id: str = Query(default=""),
) -> SourceActionResponse:
    record = get_source(DATABASE_PATH, source_key)
    if record is None:
        raise HTTPException(status_code=404, detail="source not found")

    owner_client_id = str(record.get("client_id", "")).strip()
    owner_session_id = str(record.get("session_id", "")).strip()
    requested_client_id = client_id.strip()
    requested_session_id = session_id.strip()
    if owner_client_id or owner_session_id:
        if (
            requested_client_id != owner_client_id
            or requested_session_id != owner_session_id
        ):
            raise HTTPException(
                status_code=403,
                detail="only the owning client can delete this source",
            )

    if clear_data:
        reset_source_data(
            DATABASE_PATH,
            source_key=source_key,
            source_slug=str(record.get("source_slug", "")).strip(),
            server_clip_dir=SERVER_CLIP_DIR,
        )
        server_event_processor.clear_source(source_key)

    ok = delete_source(DATABASE_PATH, source_key)
    delete_source_status(DATABASE_PATH, source_key)
    prune_orphan_source_data(DATABASE_PATH)
    server_event_processor.clear_source(source_key)
    if not ok:
        raise HTTPException(status_code=404, detail="source not found")
    realtime_update_hub.publish(
        "source_changed",
        action="deleted",
        source_key=source_key.strip(),
    )
    return SourceActionResponse(ok=True, source_key=source_key, state="deleted")


def _decorate_source_record(record: dict[str, Any]) -> dict[str, Any]:
    next_record = dict(record)
    next_record["source_duration_seconds"] = _read_float(
        next_record.get("source_duration_seconds")
    )
    next_record["rule_config"] = normalize_rule_config(next_record.get("rule_config"))
    next_record["server_media_path"] = str(
        next_record.get("server_media_path", "")
    ).strip()
    next_record["media_url"] = str(next_record.get("media_url", "")).strip()
    next_record["preview_url"] = str(next_record.get("preview_url", "")).strip()
    next_record["created_at"] = str(next_record.get("created_at", "")).strip()
    next_record["updated_at"] = str(next_record.get("updated_at", "")).strip()
    source_key = str(next_record.get("source_key", "")).strip()
    if source_key and not next_record["preview_url"]:
        next_record["preview_url"] = (
            f"/api/source-streams/{source_key}?single=true"
        )

    source_type = str(next_record.get("source_type", "")).strip().lower()
    source_value = str(next_record.get("source_value", "")).strip()
    if source_type == "stream" and source_value.startswith(("rtsp://", "http://", "https://")):
        next_record["media_url"] = source_value
        return next_record

    if next_record["media_url"]:
        return next_record

    if source_type != "video" or not source_value:
        return next_record

    try:
        media_path = Path(source_value).resolve()
    except OSError:
        return next_record

    uploaded_root = SERVER_UPLOAD_SOURCE_DIR.resolve()
    cached_root = SERVER_SOURCE_CACHE_DIR.resolve()
    try:
        media_path.relative_to(uploaded_root)
        next_record["server_media_path"] = f"uploaded_sources/{media_path.name}"
        next_record["media_url"] = f"/api/source-media/uploaded/{media_path.name}"
        return next_record
    except ValueError:
        pass

    try:
        media_path.relative_to(cached_root)
        next_record["server_media_path"] = f"source_cache/{media_path.name}"
        next_record["media_url"] = f"/api/source-media/cached/{media_path.name}"
    except ValueError:
        pass
    return next_record


def _read_float(value: object) -> float:
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
