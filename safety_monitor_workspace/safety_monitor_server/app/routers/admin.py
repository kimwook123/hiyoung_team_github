from fastapi import APIRouter, Body, HTTPException

from app.config import (
    DATABASE_PATH,
    SERVER_CLIP_DIR,
    SERVER_EVENT_THUMBNAIL_DIR,
    ensure_server_dirs,
)
from app.database import clear_all_event_data, reset_source_data
from app.server_event_processor import server_event_processor
from app.schemas import ResetDataResponse

# 이 파일은 source_key 기준으로 서버 저장소를 초기화하는 관리용 API를 제공합니다.

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.post("/reset-data", response_model=ResetDataResponse)
def reset_data(
    payload: dict = Body(...),
) -> ResetDataResponse:
    ensure_server_dirs()

    source_key = str(payload.get("source_key", "")).strip()
    source_slug = str(payload.get("source_slug", "")).strip()
    if not source_key:
        raise HTTPException(status_code=400, detail="source_key is required")

    cleared_events, deleted_event_count, deleted_clip_count = reset_source_data(
        DATABASE_PATH,
        source_key=source_key,
        source_slug=source_slug,
        server_clip_dir=SERVER_CLIP_DIR,
        server_thumbnail_dir=SERVER_EVENT_THUMBNAIL_DIR,
    )
    server_event_processor.clear_source(source_key)

    return ResetDataResponse(
        ok=True,
        source_key=source_key,
        cleared_events=cleared_events,
        deleted_event_count=deleted_event_count,
        deleted_clip_count=deleted_clip_count,
    )

@router.post("/clear-events")
def clear_events() -> dict[str, object]:
    ensure_server_dirs()
    deleted_event_count, deleted_frame_count, _ = clear_all_event_data(DATABASE_PATH)
    deleted_clip_count = 0
    for clip_path in SERVER_CLIP_DIR.glob("*.mp4"):
        if clip_path.is_file():
            clip_path.unlink(missing_ok=True)
            deleted_clip_count += 1
    deleted_thumbnail_count = 0
    for thumbnail_path in SERVER_EVENT_THUMBNAIL_DIR.glob("*.jp*g"):
        if thumbnail_path.is_file():
            thumbnail_path.unlink(missing_ok=True)
            deleted_thumbnail_count += 1
    server_event_processor.clear_all()
    return {
        "ok": True,
        "deleted_event_count": deleted_event_count,
        "deleted_frame_count": deleted_frame_count,
        "deleted_clip_count": deleted_clip_count,
        "deleted_thumbnail_count": deleted_thumbnail_count,
    }


