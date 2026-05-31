@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "CLIENT_PROJECT=%ROOT_DIR%\safety_monitor_client"
set "FLUTTER_BIN=%ROOT_DIR%\flutter\bin\flutter.bat"

if not exist "%FLUTTER_BIN%" (
  echo Flutter SDK not found.
  echo %FLUTTER_BIN%
  pause
  exit /b 1
)

pushd "%CLIENT_PROJECT%"
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
