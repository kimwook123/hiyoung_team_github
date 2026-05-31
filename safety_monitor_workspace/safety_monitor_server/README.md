# Safety Monitor Server

The server is the storage and query layer.

## Responsibilities

- Store source metadata in SQLite.
- Store source runtime status updates from clients.
- Store frame detections and events reported by clients.
- Store uploaded event clips.
- Store uploaded original media and source preview images reported by clients.
- Serve read APIs and realtime notifications for the viewer.

## Not Responsible For

- Running YOLO inference.
- Owning `best.pt` or `best.engine`.
- Reading local client video files.
- Opening local cameras or RTSP streams on behalf of clients.

## Runtime Boundary

- `main.py` only mounts storage, media, preview, event, status, clip, and realtime routers.
- The active server runtime does not bootstrap any analysis worker.
- If older analysis-related files remain under `app/`, treat them as legacy code paths, not active server behavior.

## Run

```powershell
cd safety_monitor_server
py -3.12 -m uvicorn main:app --host 0.0.0.0 --port 8000
```
