from typing import Any

from fastapi import APIRouter, Body, HTTPException, Query

from app.config import DATABASE_PATH
from app.database import find_current_frame_detection, insert_frame_detection
from app.schemas import FrameDetectionCreateResponse, FrameDetectionSnapshotResponse

router = APIRouter(prefix="/api/frame-detections", tags=["frame-detections"])


@router.post("", response_model=FrameDetectionCreateResponse)
def create_frame_detection(
    frame_record: dict[str, Any] = Body(...),
) -> FrameDetectionCreateResponse:
    if not frame_record:
        raise HTTPException(status_code=400, detail="frame record is required")

    source_key = str(frame_record.get("source_key", "")).strip()
    if not source_key:
        raise HTTPException(status_code=400, detail="source_key is required")

    if "frame_id" not in frame_record:
        raise HTTPException(status_code=400, detail="frame_id is required")

    saved_record = insert_frame_detection(DATABASE_PATH, frame_record)
    return FrameDetectionCreateResponse(ok=True, item=saved_record)


@router.get("/current", response_model=FrameDetectionSnapshotResponse)
def get_current_frame_detection(
    source_key: str = Query(min_length=1),
    source_time_seconds: float = Query(ge=0.0),
    tolerance_seconds: float = Query(default=0.12, ge=0.01, le=2.0),
) -> FrameDetectionSnapshotResponse:
    item = find_current_frame_detection(
        DATABASE_PATH,
        source_key=source_key,
        source_time_seconds=source_time_seconds,
        tolerance_seconds=tolerance_seconds,
    )
    return FrameDetectionSnapshotResponse(found=item is not None, item=item)
