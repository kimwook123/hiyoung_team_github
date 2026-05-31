# Safety Monitor Workspace

This workspace is organized as a `client -> server -> viewer` system.

## Projects

- `safety_monitor_client/`
  - Single Flutter Windows client application.
  - Embeds the local Python analysis backend in `embedded_backend/`.
  - Owns local video sources, YOLO weights, TensorRT engines, and GPU inference.
  - Runs multi-threaded local analysis.
  - Uploads frame detections, events, and event clips to the server.

- `safety_monitor_server/`
  - Does not run inference.
  - Stores source metadata, source status, frame detections, events, and event clips.
  - Exposes read/write APIs for clients and read APIs for viewers.

- `safety_monitor_viewer/`
  - Flutter Windows viewer.
  - Reads server data and visualizes source status, detections, events, and clips.
  - Treated as read-only for source registration and rule changes.

## Launch

```powershell
run_server.bat
run_client.bat
run_viewer.bat
```

## Notes

- The client is expected to run on the machine that owns the local video files and GPU.
- The client app auto-starts its embedded backend on `http://127.0.0.1:8100`.
- The server stores event clips in `safety_monitor_server/data/clips/`.
- The viewer can inspect server data and replay uploaded event clips without owning the weights.
