from contextlib import asynccontextmanager
from time import perf_counter

from fastapi import FastAPI
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware

from app.config import (
    DATABASE_PATH,
    ENABLE_SERVER_REQUEST_LOG,
    LEGACY_SOURCE_CACHE_DIR,
    SERVER_CLIP_DIR,
    SERVER_DATA_DIR,
    SERVER_SOURCE_CACHE_DIR,
    ensure_server_dirs,
)
from app.database import (
    init_db,
    migrate_legacy_analysis_paths,
    prune_orphan_source_data,
    prune_orphan_source_statuses,
)
from app.routers.admin import router as admin_router
from app.routers.clips import router as clips_router
from app.routers.events import router as events_router
from app.routers.frame_detections import router as frame_detections_router
from app.routers.sources import router as sources_router
from app.routers.source_media import router as source_media_router
from app.routers.source_status import router as source_status_router
from app.schemas import HealthResponse
from app.source_manager import AnalysisSourceManager

# 이 파일은 FastAPI 서버의 진입점입니다.
# 서버 소유 데이터 폴더를 준비하고, 이벤트/클립 라우터를 등록합니다.

ensure_server_dirs()
SERVER_DATA_DIR.mkdir(parents=True, exist_ok=True)
SERVER_CLIP_DIR.mkdir(parents=True, exist_ok=True)
init_db(DATABASE_PATH)
migrate_legacy_analysis_paths(
    DATABASE_PATH,
    legacy_source_cache_dir=LEGACY_SOURCE_CACHE_DIR,
    server_source_cache_dir=SERVER_SOURCE_CACHE_DIR,
)
prune_orphan_source_statuses(DATABASE_PATH)
prune_orphan_source_data(DATABASE_PATH)


@asynccontextmanager
async def lifespan(app: FastAPI):
    source_manager = AnalysisSourceManager()
    app.state.source_manager = source_manager
    app.state.database_path = DATABASE_PATH
    source_manager.bootstrap()
    try:
        yield
    finally:
        source_manager.shutdown()


app = FastAPI(title="Safety Monitor Server", lifespan=lifespan)

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
app.include_router(sources_router)
app.include_router(source_media_router)


if ENABLE_SERVER_REQUEST_LOG:

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        started_at = perf_counter()
        client_host = request.client.host if request.client else "-"
        method = request.method.upper()
        path = request.url.path
        query = request.url.query
        display_path = f"{path}?{query}" if query else path
        try:
            response = await call_next(request)
        except Exception as error:
            elapsed_ms = (perf_counter() - started_at) * 1000.0
            print(
                f"[REQ] client={client_host} method={method} path={display_path} "
                f"status=500 duration={elapsed_ms:.1f}ms error={error}",
                flush=True,
            )
            raise

        elapsed_ms = (perf_counter() - started_at) * 1000.0
        print(
            f"[REQ] client={client_host} method={method} path={display_path} "
            f"status={response.status_code} duration={elapsed_ms:.1f}ms",
            flush=True,
        )
        return response


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    # health는 서버가 살아 있는지, 현재 SQLite 저장소가 어디인지 확인하는 간단한 점검 API입니다.
    return HealthResponse(
        status="ok",
        event_log_path=str(DATABASE_PATH),
        event_log_exists=DATABASE_PATH.exists(),
    )
