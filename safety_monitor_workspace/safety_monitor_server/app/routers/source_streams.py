from __future__ import annotations

import asyncio

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import Response, StreamingResponse

from app.database import get_source
from app.config import DATABASE_PATH
from app.routers.source_previews import preview_path_for_source_key

router = APIRouter(prefix="/api/source-streams", tags=["source-streams"])


@router.get("/{source_key:path}")
async def stream_source(
    source_key: str,
    single: bool = Query(default=False),
):
    normalized_source_key = source_key.strip()
    if not normalized_source_key:
        raise HTTPException(status_code=400, detail="source_key is required")
    if get_source(DATABASE_PATH, normalized_source_key) is None:
        raise HTTPException(status_code=404, detail="source not found")

    if single:
        jpeg_bytes = _read_preview_bytes(normalized_source_key)
        if jpeg_bytes is None:
            raise HTTPException(status_code=404, detail="source preview not found")
        return Response(content=jpeg_bytes, media_type="image/jpeg")

    async def _frame_generator():
        last_signature = b""
        while True:
            jpeg_bytes = _read_preview_bytes(normalized_source_key)
            if jpeg_bytes and jpeg_bytes != last_signature:
                last_signature = jpeg_bytes
                yield b"--frame\r\n"
                yield b"Content-Type: image/jpeg\r\n"
                yield f"Content-Length: {len(jpeg_bytes)}\r\n\r\n".encode("ascii")
                yield jpeg_bytes
                yield b"\r\n"
            await asyncio.sleep(0.08)

    return StreamingResponse(
        _frame_generator(),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
        },
    )


def _read_preview_bytes(source_key: str) -> bytes | None:
    preview_path = preview_path_for_source_key(source_key)
    if not preview_path.exists() or not preview_path.is_file():
        return None
    try:
        return preview_path.read_bytes()
    except OSError:
        return None
