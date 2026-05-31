# Run Guide

## 1. Start the server

```powershell
run_server.bat
```

- Starts the storage API on `http://0.0.0.0:8000`.
- Keeps SQLite and uploaded event clips on the server machine.

## 2. Start the client

```powershell
run_client.bat
```

- Starts the local analysis client on `http://0.0.0.0:8100`.
- Starts the Flutter client application.
- The app automatically starts its embedded backend on `http://127.0.0.1:8100`.
- Uses local GPU inference, local weights, and local TensorRT engines.
- Reports source metadata, source status, frame detections, events, and clips to the server.
- Prompts for the remote storage server URL and saves it to `safety_monitor_client/client_settings.json`.

## 3. Start the viewer

```powershell
run_viewer.bat
```

- Starts the Flutter Windows viewer.
- Reads data from the server only.
- Does not register sources or run inference.

## 4. Build the client

```powershell
build_client.bat
```

## 5. Build the viewer

```powershell
build_viewer.bat
```
