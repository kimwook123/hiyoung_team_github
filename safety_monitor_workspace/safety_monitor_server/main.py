from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import DEFAULT_EVENT_LOG_PATH
from app.routers.events import router as events_router
from app.schemas import HealthResponse


app = FastAPI(title="Safety Monitor Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(events_router)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        event_log_path=str(DEFAULT_EVENT_LOG_PATH),
        event_log_exists=DEFAULT_EVENT_LOG_PATH.exists(),
    )
