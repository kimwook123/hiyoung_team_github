from fastapi import APIRouter, Body, HTTPException

from app.config import (
    DATABASE_PATH,
    SERVER_CLIP_DIR,
    ensure_server_dirs,
)
from app.database import reset_source_data
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
    )

    return ResetDataResponse(
        ok=True,
        source_key=source_key,
        cleared_events=cleared_events,
        deleted_event_count=deleted_event_count,
        deleted_clip_count=deleted_clip_count,
    )
