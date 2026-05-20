import json

from fastapi import APIRouter, Body, HTTPException

from app.config import DEFAULT_EVENT_LOG_PATH, SERVER_CLIP_DIR, ensure_server_dirs
from app.schemas import ResetDataResponse
from app.source_identity import extract_clip_name

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

    kept_records: list[dict] = []
    removed_records: list[dict] = []
    if DEFAULT_EVENT_LOG_PATH.exists():
        with DEFAULT_EVENT_LOG_PATH.open("r", encoding="utf-8") as log_file:
            for line in log_file:
                raw_line = line.strip()
                if not raw_line:
                    continue

                try:
                    record = json.loads(raw_line)
                except json.JSONDecodeError:
                    continue

                if not isinstance(record, dict):
                    continue

                record_source_key = str(record.get("source_key", "")).strip()
                if record_source_key == source_key:
                    removed_records.append(record)
                else:
                    kept_records.append(record)

    with DEFAULT_EVENT_LOG_PATH.open("w", encoding="utf-8") as log_file:
        for record in kept_records:
            log_file.write(json.dumps(record, ensure_ascii=False) + "\n")

    remaining_clip_names = {
        clip_name
        for clip_name in (extract_clip_name(record) for record in kept_records)
        if clip_name
    }
    removed_clip_names = {
        clip_name
        for clip_name in (extract_clip_name(record) for record in removed_records)
        if clip_name and clip_name not in remaining_clip_names
    }

    deleted_clip_count = 0
    for clip_name in removed_clip_names:
        clip_path = SERVER_CLIP_DIR / clip_name
        if clip_path.exists() and clip_path.is_file():
            clip_path.unlink()
            deleted_clip_count += 1

    if source_slug:
        for clip_path in SERVER_CLIP_DIR.glob(f"{source_slug}__*.mp4"):
            if not clip_path.is_file() or clip_path.name in remaining_clip_names:
                continue
            clip_path.unlink()
            deleted_clip_count += 1

    return ResetDataResponse(
        ok=True,
        source_key=source_key,
        cleared_events=bool(removed_records),
        deleted_event_count=len(removed_records),
        deleted_clip_count=deleted_clip_count,
    )
