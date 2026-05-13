from typing import Any

from pydantic import BaseModel

# 이 파일은 FastAPI 응답 모델 모음입니다.
# Pydantic 모델은 서버가 어떤 JSON 형태를 돌려주는지 문서처럼 보여 주는 역할도 합니다.

class EventListResponse(BaseModel):
    count: int
    items: list[dict[str, Any]]


class EventDetailResponse(BaseModel):
    event_key: str
    item: dict[str, Any]


class EventHistoryResponse(BaseModel):
    event_key: str
    count: int
    items: list[dict[str, Any]]


class EventCreateResponse(BaseModel):
    ok: bool
    item: dict[str, Any]


class ClipItem(BaseModel):
    name: str
    path: str
    url: str


class ClipListResponse(BaseModel):
    count: int
    items: list[ClipItem]


class ClipUploadResponse(BaseModel):
    ok: bool
    name: str
    path: str
    url: str
    size_bytes: int
    event_key: str | None = None


class HealthResponse(BaseModel):
    status: str
    event_log_path: str
    event_log_exists: bool
