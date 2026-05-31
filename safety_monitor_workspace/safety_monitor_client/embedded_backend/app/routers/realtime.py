from fastapi import APIRouter
from fastapi import WebSocket

from app.realtime_hub import realtime_update_hub

router = APIRouter(tags=["realtime"])


@router.websocket("/ws/updates")
async def updates_socket(websocket: WebSocket) -> None:
    await realtime_update_hub.serve(websocket)
