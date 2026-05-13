@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "PY_DIR=%ROOT_DIR%\safety_ai_monitor"
set "SERVER_DIR=%ROOT_DIR%\safety_monitor_server"
set "GUI_SCRIPT=%ROOT_DIR%\run_gui_only.bat"

if not exist "%PY_DIR%\main.py" (
  echo Python entry file not found.
  echo %PY_DIR%\main.py
  pause
  exit /b 1
)

if not exist "%SERVER_DIR%\main.py" (
  echo Server entry file not found.
  echo %SERVER_DIR%\main.py
  pause
  exit /b 1
)

if not exist "%GUI_SCRIPT%" (
  echo GUI launcher not found.
  echo %GUI_SCRIPT%
  pause
  exit /b 1
)

start "Safety Python" /D "%PY_DIR%" py -3.12 main.py
timeout /t 3 /nobreak > nul
start "Safety Server" /D "%SERVER_DIR%" py -3.12 -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
timeout /t 3 /nobreak > nul
start "Safety GUI Launcher" /D "%ROOT_DIR%" cmd /c ""%GUI_SCRIPT%""

endlocal
