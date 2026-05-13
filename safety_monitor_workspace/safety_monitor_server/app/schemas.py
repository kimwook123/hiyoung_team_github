from typing import Any

from pydantic import BaseModel


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
