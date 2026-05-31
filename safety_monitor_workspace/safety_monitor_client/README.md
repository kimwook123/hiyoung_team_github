# Safety Monitor Client

The client is a Flutter Windows application with an embedded local analysis backend.

## Responsibilities

- Register local video files and stream sources.
- Analyze only the operator's own local sources with per-source rules.
- Show source runtime status and recent events from the embedded backend.
- Show detection overlays, event logs, and clip replay while reviewing local analysis results.
- Send analyzed data to the central server.
- Display local runtime ownership such as weights, TensorRT engine, and device.

## Behavior

- Owns local weights and optional TensorRT engine files.
- Starts the embedded backend automatically on `http://127.0.0.1:8100`.
- Sends analyzed data to the central server through the embedded backend.

## Run

```powershell
cd safety_monitor_client
..\flutter\bin\flutter.bat run -d windows
```
