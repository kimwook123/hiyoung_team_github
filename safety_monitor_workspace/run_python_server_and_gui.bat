@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "PY_SCRIPT=%ROOT_DIR%\run_python_only.bat"
set "SERVER_SCRIPT=%ROOT_DIR%\run_server.bat"
set "GUI_SCRIPT=%ROOT_DIR%\run_gui_only.bat"

if not exist "%PY_SCRIPT%" (
  echo Python launcher not found.
  echo %PY_SCRIPT%
  pause
  exit /b 1
)

if not exist "%SERVER_SCRIPT%" (
  echo Server launcher not found.
  echo %SERVER_SCRIPT%
  pause
  exit /b 1
)

if not exist "%GUI_SCRIPT%" (
  echo GUI launcher not found.
  echo %GUI_SCRIPT%
  pause
  exit /b 1
)

start "Safety Python Launcher" /D "%ROOT_DIR%" cmd /c ""%PY_SCRIPT%""
timeout /t 3 /nobreak > nul
start "Safety Server Launcher" /D "%ROOT_DIR%" cmd /c ""%SERVER_SCRIPT%""
timeout /t 3 /nobreak > nul
start "Safety GUI Launcher" /D "%ROOT_DIR%" cmd /c ""%GUI_SCRIPT%""

endlocal
