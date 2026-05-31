# Safety Monitor Server

The server is the storage and query layer.

## Responsibilities

- Store source metadata in SQLite.
- Store source runtime status updates from clients.
- Store frame detections and events reported by clients.
- Store uploaded event clips.
- Serve read APIs and realtime notifications for the viewer.

## Not Responsible For

- Running YOLO inference.
- Owning `best.pt` or `best.engine`.
- Reading local client video files.

## Run

```powershell
cd safety_monitor_server
py -3.12 -m uvicorn main:app --host 0.0.0.0 --port 8000
```
