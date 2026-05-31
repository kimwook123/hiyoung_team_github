@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "CLIENT_DIR=%ROOT_DIR%\safety_monitor_client"
set "BACKEND_DIR=%CLIENT_DIR%\embedded_backend"
set "SETTINGS_PATH=%CLIENT_DIR%\client_settings.json"
set "CLIENT_BUILD_DIR=%CLIENT_DIR%\build\windows\x64\runner\Release"
set "CLIENT_EXE=%CLIENT_BUILD_DIR%\safety_monitor_client.exe"
set "FLUTTER_CMD=flutter"
set "LOCAL_FLUTTER_CMD=%ROOT_DIR%\flutter\bin\flutter.bat"
set "PYTHON_CMD=py -3.12"

if exist "%ROOT_DIR%\.venv\Scripts\python.exe" (
  set "PYTHON_CMD=%ROOT_DIR%\.venv\Scripts\python.exe"
)

if not exist "%CLIENT_DIR%\pubspec.yaml" (
  echo Client project not found.
  echo %CLIENT_DIR%\pubspec.yaml
  pause
  exit /b 1
)

if not exist "%BACKEND_DIR%\main.py" (
  echo Embedded backend entry file not found.
  echo %BACKEND_DIR%\main.py
  pause
  exit /b 1
)

call %PYTHON_CMD% -c "import fastapi, uvicorn, cv2, numpy, requests, yt_dlp, websockets, torch, tensorrt, onnx, onnxruntime" > nul 2>&1
if errorlevel 1 (
  echo Required embedded backend packages are missing.
  choice /M "Install embedded backend requirements now"
  if errorlevel 2 (
    echo Skipping package installation. Client was not started.
    pause
    exit /b 1
  )

  call %PYTHON_CMD% -m pip install -r "%BACKEND_DIR%\requirements.txt"
  if errorlevel 1 (
    echo Failed to install embedded backend requirements.
    pause
    exit /b 1
  )
)

call %PYTHON_CMD% -c "import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)" > nul 2>&1
if errorlevel 1 (
  echo CUDA is not available in the Python environment used by the embedded backend.
  pause
  exit /b 1
)

if exist "%LOCAL_FLUTTER_CMD%" (
  set "FLUTTER_CMD=%LOCAL_FLUTTER_CMD%"
)

if not exist "%CLIENT_EXE%" (
  where "%FLUTTER_CMD%" > nul 2>&1
  if errorlevel 1 (
    echo Flutter SDK was not found on this PC.
    pause
    exit /b 1
  )

  echo Client executable not found. Building Flutter Windows app now...
  pushd "%CLIENT_DIR%"
  call "%FLUTTER_CMD%" pub get
  if errorlevel 1 (
    echo flutter pub get failed.
    popd
    pause
    exit /b 1
  )
  call "%FLUTTER_CMD%" config --enable-windows-desktop
  call "%FLUTTER_CMD%" build windows
  if errorlevel 1 (
    echo flutter build windows failed.
    popd
    pause
    exit /b 1
  )
  popd
)

if not exist "%CLIENT_EXE%" (
  echo Client executable not found.
  echo %CLIENT_EXE%
  pause
  exit /b 1
)

set "DEFAULT_SERVER_URL=http://127.0.0.1:8000"
set "REMOTE_SERVER_URL="

if exist "%SETTINGS_PATH%" (
  for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$p='%SETTINGS_PATH%'; try { $json = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json; if ($json.remote_server_base_url) { $json.remote_server_base_url } } catch {}"`) do (
    set "REMOTE_SERVER_URL=%%i"
  )
)

if not defined REMOTE_SERVER_URL (
  if not "%SAFETY_MONITOR_SERVER_URL%"=="" (
    set "REMOTE_SERVER_URL=%SAFETY_MONITOR_SERVER_URL%"
  ) else (
    set "REMOTE_SERVER_URL=%DEFAULT_SERVER_URL%"
  )
)

echo Current remote server: %REMOTE_SERVER_URL%
set /p "INPUT_REMOTE_SERVER_URL=Enter remote server URL (press Enter to keep current): "
if not "%INPUT_REMOTE_SERVER_URL%"=="" (
  set "REMOTE_SERVER_URL=%INPUT_REMOTE_SERVER_URL%"
)

> "%SETTINGS_PATH%" echo {
>> "%SETTINGS_PATH%" echo   "remote_server_base_url": "%REMOTE_SERVER_URL%"
>> "%SETTINGS_PATH%" echo }

echo Checking storage server health at %REMOTE_SERVER_URL% ...
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri '%REMOTE_SERVER_URL%/health' -TimeoutSec 5; if ($r.StatusCode -eq 200) { Write-Host 'Server health check succeeded.'; exit 0 } else { exit 1 } } catch { exit 1 }"
if errorlevel 1 (
  echo Warning: storage server health check failed. The client app will still start.
)

start "Safety Monitor Client" /D "%CLIENT_BUILD_DIR%" "%CLIENT_EXE%"

endlocal
exit /b 0
