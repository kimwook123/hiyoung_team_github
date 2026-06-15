@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "CLIENT_DIR=%ROOT_DIR%\safety_monitor_client"
set "BACKEND_DIR=%CLIENT_DIR%\embedded_backend"
set "SETTINGS_PATH=%CLIENT_DIR%\client_settings.json"
set "CLIENT_BUILD_DIR=%CLIENT_DIR%\build\windows\x64\runner\Release"
set "CLIENT_EXE=%CLIENT_BUILD_DIR%\safety_monitor_client.exe"
set "MODEL_PATH=%BACKEND_DIR%\app\analysis\models\weights\best.pt"
set "ENGINE_PATH=%BACKEND_DIR%\app\analysis\models\weights\best.engine"
set "FLUTTER_CMD=flutter"
set "LOCAL_FLUTTER_CMD=%ROOT_DIR%\flutter\bin\flutter.bat"
set "PYTHON_CMD=%ROOT_DIR%\.venv\Scripts\python.exe"

call "%ROOT_DIR%\install_dependencies.bat" client
if errorlevel 1 (
  echo Failed to prepare client dependencies.
  pause
  exit /b 1
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

"%PYTHON_CMD%" -c "import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)" > nul 2>&1
if errorlevel 1 (
  echo CUDA is not available in the Python environment used by the embedded backend.
  pause
  exit /b 1
)

set "YOLO_CONFIG_DIR=%BACKEND_DIR%\data\ultralytics"
if not exist "%YOLO_CONFIG_DIR%" mkdir "%YOLO_CONFIG_DIR%"

echo Checking TensorRT runtime engine...
if exist "%ENGINE_PATH%" (
  echo Found prebuilt TensorRT engine.
) else (
  if /I "%SAFETY_MONITOR_PREPARE_TENSORRT%"=="1" (
    echo No prebuilt TensorRT engine found. Preparing it before launch because SAFETY_MONITOR_PREPARE_TENSORRT=1.
    "%PYTHON_CMD%" "%BACKEND_DIR%\ensure_runtime_engine.py"
    if errorlevel 1 (
      echo Failed to prepare a CUDA TensorRT runtime engine for the client backend.
      pause
      exit /b 1
    )
  ) else (
    echo No prebuilt TensorRT engine found.
    echo Skipping blocking TensorRT preflight and starting the client immediately.
    echo Set SAFETY_MONITOR_PREPARE_TENSORRT=1 if you want to force engine preparation before launch.
  )
)

if exist "%LOCAL_FLUTTER_CMD%" (
  set "FLUTTER_CMD=%LOCAL_FLUTTER_CMD%"
)

if not exist "%CLIENT_EXE%" (
  echo Client executable not found. Building Flutter Windows app now...
  call "%ROOT_DIR%\build_client.bat" /nopause
  if errorlevel 1 (
    echo Client build failed.
    pause
    exit /b 1
  )
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

powershell -NoProfile -Command "$p='%SETTINGS_PATH%'; $data=@{}; if (Test-Path -LiteralPath $p) { try { $json=Get-Content -LiteralPath $p -Raw | ConvertFrom-Json; foreach ($prop in $json.PSObject.Properties) { $data[$prop.Name]=$prop.Value } } catch {} }; $data['remote_server_base_url']='%REMOTE_SERVER_URL%'; if (-not $data.ContainsKey('client_id') -or [string]::IsNullOrWhiteSpace([string]$data['client_id'])) { $hostName=[System.Net.Dns]::GetHostName().ToLowerInvariant() -replace '[^a-z0-9]+','_'; $hostName=$hostName.Trim('_'); if ([string]::IsNullOrWhiteSpace($hostName)) { $hostName='local' }; $data['client_id']='client_' + $hostName }; $data | ConvertTo-Json | Set-Content -LiteralPath $p -Encoding UTF8"

echo Checking storage server health at %REMOTE_SERVER_URL% ...
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri '%REMOTE_SERVER_URL%/health' -TimeoutSec 5; if ($r.StatusCode -eq 200) { Write-Host 'Server health check succeeded.'; exit 0 } else { exit 1 } } catch { exit 1 }"
if errorlevel 1 (
  echo Warning: storage server health check failed. The client app will still start.
)

start "Safety Monitor Client" /D "%CLIENT_BUILD_DIR%" "%CLIENT_EXE%"

endlocal
exit /b 0
