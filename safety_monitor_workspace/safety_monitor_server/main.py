from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import (
    DATABASE_PATH,
    DEFAULT_EVENT_LOG_PATH,
    SERVER_CLIP_DIR,
    SERVER_DATA_DIR,
    ensure_server_dirs,
)
from app.database import init_db
from app.routers.admin import router as admin_router
from app.routers.clips import router as clips_router
from app.routers.events import router as events_router
from app.routers.frame_detections import router as frame_detections_router
from app.routers.source_status import router as source_status_router
from app.schemas import HealthResponse

# 이 파일은 FastAPI 서버의 진입점입니다.
# 서버 소유 데이터 폴더를 준비하고, 이벤트/클립 라우터를 등록합니다.

app = FastAPI(title="Safety Monitor Server")

ensure_server_dirs()
SERVER_DATA_DIR.mkdir(parents=True, exist_ok=True)
SERVER_CLIP_DIR.mkdir(parents=True, exist_ok=True)
init_db(DATABASE_PATH)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(events_router)
app.include_router(clips_router)
app.include_router(admin_router)
app.include_router(frame_detections_router)
app.include_router(source_status_router)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    # health는 서버가 살아 있는지, 현재 SQLite 저장소가 어디인지 확인하는 간단한 점검 API입니다.
    return HealthResponse(
        status="ok",
        event_log_path=str(DATABASE_PATH),
        event_log_exists=DATABASE_PATH.exists(),
    )
