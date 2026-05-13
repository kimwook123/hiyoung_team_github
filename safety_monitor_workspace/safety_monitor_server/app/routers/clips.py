from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.config import SERVER_CLIP_DIR
from app.schemas import ClipItem, ClipListResponse, ClipUploadResponse


router = APIRouter(prefix="/api/clips", tags=["clips"])


@router.post("", response_model=ClipUploadResponse)
async def upload_clip(
    file: UploadFile = File(...),
    event_key: str | None = Form(default=None),
) -> ClipUploadResponse:
    original_name = Path(file.filename or "").name.strip()
    if not original_name:
        raise HTTPException(status_code=400, detail="file name is required")
    if "/" in original_name or "\\" in original_name or ".." in original_name:
        raise HTTPException(status_code=400, detail="invalid file name")
    if not original_name.lower().endswith(".mp4"):
        raise HTTPException(status_code=400, detail="only mp4 files are allowed")

    clip_path = _build_unique_clip_path(original_name)

    size_bytes = 0
    try:
        with clip_path.open("wb") as output_file:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                output_file.write(chunk)
                size_bytes += len(chunk)
    except Exception as error:
        raise HTTPException(status_code=500, detail="failed to save clip") from error
    finally:
        await file.close()

    return ClipUploadResponse(
        ok=True,
        name=clip_path.name,
        path=f"clips/{clip_path.name}",
        url=f"/api/clips/{clip_path.name}",
        size_bytes=size_bytes,
        event_key=event_key.strip() if event_key else None,
    )


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


def _build_unique_clip_path(file_name: str) -> Path:
    candidate = (SERVER_CLIP_DIR / file_name).resolve()
    stem = Path(file_name).stem
    suffix = Path(file_name).suffix
    index = 1

    while candidate.exists():
        candidate = (SERVER_CLIP_DIR / f"{stem}_{index}{suffix}").resolve()
        index += 1

    try:
        candidate.relative_to(SERVER_CLIP_DIR)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="invalid clip path") from error

    return candidate
