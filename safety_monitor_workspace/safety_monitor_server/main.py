from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import (
    DEFAULT_EVENT_LOG_PATH,
    SERVER_CLIP_DIR,
    SERVER_DATA_DIR,
    ensure_server_dirs,
)
from app.routers.clips import router as clips_router
from app.routers.events import router as events_router
from app.schemas import HealthResponse

# 이 파일은 FastAPI 서버의 진입점입니다.
# 서버 소유 데이터 폴더를 준비하고, 이벤트/클립 라우터를 등록합니다.

app = FastAPI(title="Safety Monitor Server")

ensure_server_dirs()
SERVER_DATA_DIR.mkdir(parents=True, exist_ok=True)
SERVER_CLIP_DIR.mkdir(parents=True, exist_ok=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(events_router)
app.include_router(clips_router)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    # health는 서버가 살아 있는지, 현재 이벤트 저장 파일이 어디인지 확인하는 간단한 점검 API입니다.
    return HealthResponse(
        status="ok",
        event_log_path=str(DEFAULT_EVENT_LOG_PATH),
        event_log_exists=DEFAULT_EVENT_LOG_PATH.exists(),
    )
