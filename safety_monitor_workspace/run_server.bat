@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "SERVER_DIR=%ROOT_DIR%\safety_monitor_server"

if not exist "%SERVER_DIR%\main.py" (
  echo Server entry file not found.
  echo %SERVER_DIR%\main.py
  pause
  exit /b 1
)

py -3.12 -c "import fastapi, uvicorn, cv2, numpy, requests, yt_dlp, websockets, torch" > nul 2>&1
if errorlevel 1 (
  echo Required server packages are missing.
  echo This server needs FastAPI, Uvicorn, OpenCV, NumPy, Requests, yt-dlp, WebSocket support, and PyTorch.
  choice /M "Install server requirements now"
  if errorlevel 2 (
    echo Skipping package installation. Server was not started.
    pause
    exit /b 1
  )

  py -3.12 -m pip install -r "%SERVER_DIR%\requirements.txt"
  if errorlevel 1 (
    echo Failed to install server requirements.
    pause
    exit /b 1
  )
)

echo Python interpreter:
py -3.12 -c "import sys; print(sys.executable)"

py -3.12 -c "import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)" > nul 2>&1
if errorlevel 1 (
  echo CUDA is not available in the Python 3.12 environment used by the server.
  echo Install the CUDA-enabled PyTorch build for Python 3.12 before starting the server.
  pause
  exit /b 1
)

echo Starting Safety Monitor Server on http://0.0.0.0:8000
pushd "%SERVER_DIR%"
py -3.12 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000 --no-access-log
popd

pause
endlocal
