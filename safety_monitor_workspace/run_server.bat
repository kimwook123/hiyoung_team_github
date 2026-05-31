@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "SERVER_DIR=%ROOT_DIR%\safety_monitor_server"
set "PYTHON_CMD=py -3.12"

if exist "%ROOT_DIR%\.venv\Scripts\python.exe" (
  set "PYTHON_CMD=%ROOT_DIR%\.venv\Scripts\python.exe"
)

if not exist "%SERVER_DIR%\main.py" (
  echo Server entry file not found.
  echo %SERVER_DIR%\main.py
  pause
  exit /b 1
)

call %PYTHON_CMD% -c "import fastapi, uvicorn, websockets, pydantic, multipart" > nul 2>&1
if errorlevel 1 (
  echo Required server packages are missing.
  echo This server needs FastAPI, Uvicorn, WebSocket support, and multipart form handling.
  choice /M "Install server requirements now"
  if errorlevel 2 (
    echo Skipping package installation. Server was not started.
    pause
    exit /b 1
  )

  call %PYTHON_CMD% -m pip install -r "%SERVER_DIR%\requirements.txt"
  if errorlevel 1 (
    echo Failed to install server requirements.
    pause
    exit /b 1
  )
)

echo Python interpreter:
call %PYTHON_CMD% -c "import sys; print(sys.executable)"

echo Starting Safety Monitor Server on http://0.0.0.0:8000
pushd "%SERVER_DIR%"
call %PYTHON_CMD% -m uvicorn main:app --host 0.0.0.0 --port 8000 --no-access-log
popd

pause
endlocal
