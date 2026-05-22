from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, Form, HTTPException, Query, Request, UploadFile

from app.config import SERVER_SOURCE_CACHE_DIR, SERVER_UPLOAD_SOURCE_DIR
from app.realtime_hub import realtime_update_hub
from app.schemas import (
    SourceActionResponse,
    SourceCreateRequest,
    SourceItem,
    SourceListResponse,
    SourceUpsertResponse,
)
from app.source_manager import AnalysisSourceManager

router = APIRouter(prefix="/api/sources", tags=["sources"])


def _manager_from_request(request: Request) -> AnalysisSourceManager:
    manager = getattr(request.app.state, "source_manager", None)
    if not isinstance(manager, AnalysisSourceManager):
        raise HTTPException(status_code=500, detail="source manager is not ready")
    return manager


@router.get("", response_model=SourceListResponse)
def list_sources(request: Request) -> SourceListResponse:
    manager = _manager_from_request(request)
    records = manager.list_registered_sources()
    items = [SourceItem(**_decorate_source_record(record)) for record in records]
    return SourceListResponse(count=len(items), items=items)


@router.post("", response_model=SourceUpsertResponse)
def register_source(
    payload: SourceCreateRequest,
    request: Request,
) -> SourceUpsertResponse:
    manager = _manager_from_request(request)
    item = manager.register_source(
        source_type=payload.source_type,
        source_value=payload.source_value,
        client_id=payload.client_id,
        session_id=payload.session_id,
        reset_existing=payload.reset_existing,
        start_immediately=payload.start_immediately,
    )
    realtime_update_hub.publish(
        "source_changed",
        action="registered",
        source_key=str(item.get("source_key", "")).strip(),
    )
    return SourceUpsertResponse(ok=True, item=SourceItem(**_decorate_source_record(item)))


@router.post("/upload", response_model=SourceUpsertResponse)
async def upload_video_source(
    request: Request,
    file: UploadFile = File(...),
    client_id: str = Form(default=""),
    session_id: str = Form(default=""),
    reset_existing: bool = Form(default=True),
    start_immediately: bool = Form(default=True),
) -> SourceUpsertResponse:
    manager = _manager_from_request(request)
    filename = Path(file.filename or "uploaded_video.mp4").name
    if not filename:
        raise HTTPException(status_code=400, detail="invalid filename")

    suffix = Path(filename).suffix
    if not suffix:
      suffix = ".mp4"
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
        if saved_path.exists():
            saved_path.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="uploaded file is empty")

    try:
        item = manager.register_source(
            source_type="video",
            source_value=str(saved_path.resolve()),
            client_id=client_id,
            session_id=session_id,
            reset_existing=reset_existing,
            start_immediately=start_immediately,
        )
    except Exception:
        saved_path.unlink(missing_ok=True)
        raise

    realtime_update_hub.publish(
        "source_changed",
        action="registered",
        source_key=str(item.get("source_key", "")).strip(),
    )
    return SourceUpsertResponse(ok=True, item=SourceItem(**_decorate_source_record(item)))


def _decorate_source_record(record: dict) -> dict:
    next_record = dict(record)
    source_type = str(next_record.get("source_type", "")).strip().lower()
    source_value = str(next_record.get("source_value", "")).strip()
    next_record["server_media_path"] = ""
    next_record["media_url"] = ""

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


@router.post("/{source_key:path}/start", response_model=SourceActionResponse)
def start_source(source_key: str, request: Request) -> SourceActionResponse:
    manager = _manager_from_request(request)
    try:
        manager.start_source(source_key)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="source not found") from error
    realtime_update_hub.publish(
        "source_changed",
        action="started",
        source_key=source_key.strip(),
    )
    return SourceActionResponse(ok=True, source_key=source_key, state="starting")


@router.post("/{source_key:path}/stop", response_model=SourceActionResponse)
def stop_source(source_key: str, request: Request) -> SourceActionResponse:
    manager = _manager_from_request(request)
    record = manager.stop_source(source_key)
    if record is None:
        raise HTTPException(status_code=404, detail="source not found")
    realtime_update_hub.publish(
        "source_changed",
        action="stopped",
        source_key=source_key.strip(),
    )
    return SourceActionResponse(ok=True, source_key=source_key, state="stopped")


@router.post("/{source_key:path}/restart", response_model=SourceActionResponse)
def restart_source(source_key: str, request: Request) -> SourceActionResponse:
    manager = _manager_from_request(request)
    try:
        manager.restart_source(source_key)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="source not found") from error
    realtime_update_hub.publish(
        "source_changed",
        action="restarted",
        source_key=source_key.strip(),
    )
    return SourceActionResponse(ok=True, source_key=source_key, state="starting")


@router.delete("/{source_key:path}", response_model=SourceActionResponse)
def delete_source(
    source_key: str,
    request: Request,
    clear_data: bool = Query(default=False),
) -> SourceActionResponse:
    manager = _manager_from_request(request)
    ok = manager.remove_source(source_key, clear_data=clear_data)
    if not ok:
        raise HTTPException(status_code=404, detail="source not found")
    realtime_update_hub.publish(
        "source_changed",
        action="deleted",
        source_key=source_key.strip(),
    )
    return SourceActionResponse(ok=True, source_key=source_key, state="deleted")
