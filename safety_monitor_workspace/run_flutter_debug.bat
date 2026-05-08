@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "GUI_PROJECT=%ROOT_DIR%\safety_ai_monitor_ui"
set "FLUTTER_BIN=%ROOT_DIR%\flutter\bin\flutter.bat"

if not exist "%FLUTTER_BIN%" (
  echo Flutter SDK not found.
  echo %FLUTTER_BIN%
  pause
  exit /b 1
)

start "Flutter Debug" /D "%GUI_PROJECT%" cmd /k "%FLUTTER_BIN% run -d windows"

endlocal
