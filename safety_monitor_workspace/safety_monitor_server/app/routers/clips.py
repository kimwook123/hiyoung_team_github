from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from app.config import SERVER_CLIP_DIR
from app.schemas import ClipItem, ClipListResponse


router = APIRouter(prefix="/api/clips", tags=["clips"])


@router.get("", response_model=ClipListResponse)
def list_clips() -> ClipListResponse:
    items = [
        ClipItem(
            name=clip_path.name,
            path=f"clips/{clip_path.name}",
            url=f"/api/clips/{clip_path.name}",
        )
        for clip_path in sorted(SERVER_CLIP_DIR.glob("*.mp4"))
        if clip_path.is_file()
    ]
    return ClipListResponse(count=len(items), items=items)


@router.get("/{clip_name}")
def get_clip(clip_name: str) -> FileResponse:
    normalized_name = clip_name.strip()
    if (
        not normalized_name
        or "/" in normalized_name
        or "\\" in normalized_name
        or ".." in normalized_name
    ):
        raise HTTPException(status_code=400, detail="invalid clip name")

    clip_path = (SERVER_CLIP_DIR / normalized_name).resolve()
    try:
        clip_path.relative_to(SERVER_CLIP_DIR)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="invalid clip path") from error

    if not clip_path.exists() or not clip_path.is_file():
        raise HTTPException(status_code=404, detail="clip not found")

    return FileResponse(
        path=clip_path,
        filename=clip_path.name,
        media_type="video/mp4",
    )
