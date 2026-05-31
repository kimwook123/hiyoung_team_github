# Embedded Client Backend

The backend is embedded inside the Flutter client application.

## Responsibilities

- Register local video files, streams, or cameras.
- Own the local YOLO `.pt` and TensorRT `.engine` files.
- Run multi-threaded GPU analysis locally.
- Save local status/events for local inspection.
- Report source metadata, source status, frame detections, events, and event clips to the server.

## API

The client starts a local FastAPI service on port `8100`.

- `GET /`
- `GET /health`
- `GET /api/client/config`
- `GET /api/sources`
- `POST /api/sources`
- `POST /api/sources/upload`
- `POST /api/sources/{source_key}/start`
- `POST /api/sources/{source_key}/stop`
- `POST /api/sources/{source_key}/restart`
- `PATCH /api/sources/{source_key}/config`
- `DELETE /api/sources/{source_key}`

## Run

Use the Flutter client app as the normal entrypoint:

```powershell
run_client.bat
```

The backend is started automatically by the client app and is no longer intended to be used as a standalone operator dashboard.
