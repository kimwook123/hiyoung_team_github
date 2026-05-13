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

echo Starting Safety Monitor Server on http://127.0.0.1:8000
pushd "%SERVER_DIR%"
py -3.12 -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
popd

pause
endlocal
