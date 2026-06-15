@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "VIEWER_PROJECT=%ROOT_DIR%\safety_monitor_viewer"
set "LOCAL_FLUTTER_BIN=%ROOT_DIR%\flutter\bin\flutter.bat"
set "FLUTTER_BIN=flutter"

if exist "%LOCAL_FLUTTER_BIN%" (
  set "FLUTTER_BIN=%LOCAL_FLUTTER_BIN%"
) else (
  where flutter > nul 2>&1
  if errorlevel 1 (
  echo Flutter SDK not found.
  echo Expected local SDK:
  echo   %LOCAL_FLUTTER_BIN%
  pause
  exit /b 1
  )
)

pushd "%VIEWER_PROJECT%"
call "%FLUTTER_BIN%" pub get
if errorlevel 1 (
  echo flutter pub get failed.
  popd
  pause
  exit /b 1
)

call "%FLUTTER_BIN%" build windows
if errorlevel 1 (
  echo flutter build windows failed.
  popd
  pause
  exit /b 1
)

popd

echo Build finished.
pause
endlocal
