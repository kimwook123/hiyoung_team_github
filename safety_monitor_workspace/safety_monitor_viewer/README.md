# Safety Monitor Viewer

The viewer is a Flutter Windows application that reads server data.

## Responsibilities

- Show source status from the server.
- Show event logs and event details.
- Show frame detection overlays from server snapshots.
- Replay uploaded event clips from the server.

## Behavior

- Treated as read-only.
- Does not register sources.
- Does not own weights or TensorRT engines.
- Does not run inference.

## Run

```powershell
cd safety_monitor_viewer
..\flutter\bin\flutter.bat run -d windows
```
