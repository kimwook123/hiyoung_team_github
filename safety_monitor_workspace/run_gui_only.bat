@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "GUI_DIR=%ROOT_DIR%\safety_ai_monitor_ui\build\windows\x64\runner\Release"
set "GUI_EXE=%GUI_DIR%\safety_ai_monitor_ui.exe"

if not exist "%GUI_EXE%" (
  set "GUI_DIR=%ROOT_DIR%\safety_ai_monitor_ui\build\windows\x64\runner\Debug"
  set "GUI_EXE=%GUI_DIR%\safety_ai_monitor_ui.exe"
)

if not exist "%GUI_EXE%" (
  echo GUI executable not found.
  echo %GUI_EXE%
  pause
  exit /b 1
)

start "Safety GUI" /D "%GUI_DIR%" "%GUI_EXE%"

endlocal
