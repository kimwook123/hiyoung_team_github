@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "VIEWER_DIR=%ROOT_DIR%\safety_monitor_viewer"
set "VIEWER_BUILD_DIR=%VIEWER_DIR%\build\windows\x64\runner\Release"
set "VIEWER_EXE=%VIEWER_BUILD_DIR%\safety_monitor_viewer.exe"
set "CONFIG_PATH=%VIEWER_DIR%\server_config.json"
set "FLUTTER_CMD=flutter"
set "LOCAL_FLUTTER_CMD=%ROOT_DIR%\flutter\bin\flutter.bat"

if not exist "%VIEWER_DIR%\pubspec.yaml" (
  echo Viewer project not found.
  echo %VIEWER_DIR%\pubspec.yaml
  pause
  exit /b 1
)

if not exist "%VIEWER_EXE%" (
  set "VIEWER_BUILD_DIR=%VIEWER_DIR%\build\windows\x64\runner\Debug"
  set "VIEWER_EXE=%VIEWER_BUILD_DIR%\safety_monitor_viewer.exe"
  set "CONFIG_PATH=%VIEWER_DIR%\server_config.json"
)

if not exist "%VIEWER_EXE%" (
  if exist "%LOCAL_FLUTTER_CMD%" (
    set "FLUTTER_CMD=%LOCAL_FLUTTER_CMD%"
    ver > nul
  )

  if not exist "%LOCAL_FLUTTER_CMD%" (
    where flutter > nul 2>&1
  )
  if errorlevel 1 (
    echo Flutter SDK was not found on this PC.
    choice /C YN /M "Install Flutter SDK now"
    if errorlevel 2 (
      echo Flutter installation was skipped.
      pause
      exit /b 1
    )

    set "DEFAULT_FLUTTER_DIR=%LOCALAPPDATA%\flutter-sdk"
    echo Default Flutter install directory:
    echo   %DEFAULT_FLUTTER_DIR%
    set /p "INPUT_FLUTTER_DIR=Enter Flutter install directory (press Enter to use default): "
    if "%INPUT_FLUTTER_DIR%"=="" (
      set "FLUTTER_DIR=%DEFAULT_FLUTTER_DIR%"
    ) else (
      set "FLUTTER_DIR=%INPUT_FLUTTER_DIR%"
    )

    call :install_flutter "%FLUTTER_DIR%"
    if errorlevel 1 (
      echo Flutter installation failed.
      pause
      exit /b 1
    )

    set "FLUTTER_CMD=%FLUTTER_DIR%\bin\flutter.bat"
  )

  echo Viewer executable not found. Building Flutter Windows app now...
  call "%ROOT_DIR%\build_viewer.bat" /nopause
  if errorlevel 1 (
    echo Viewer build failed.
    pause
    exit /b 1
  )

  set "VIEWER_BUILD_DIR=%VIEWER_DIR%\build\windows\x64\runner\Release"
  set "VIEWER_EXE=%VIEWER_BUILD_DIR%\safety_monitor_viewer.exe"
  set "CONFIG_PATH=%VIEWER_DIR%\server_config.json"
)

if not exist "%VIEWER_EXE%" (
  echo Viewer executable not found.
  echo %VIEWER_EXE%
  pause
  exit /b 1
)

set "DEFAULT_SERVER_URL=http://127.0.0.1:8000"
set "SERVER_URL="

if exist "%CONFIG_PATH%" (
  for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$p='%CONFIG_PATH%'; try { $json = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json; if ($json.api_base_url) { $json.api_base_url } } catch {}"`) do (
    set "SERVER_URL=%%i"
  )
)

if not defined SERVER_URL (
  set "SERVER_URL=%DEFAULT_SERVER_URL%"
)

echo Current API server: %SERVER_URL%
set /p "INPUT_SERVER_URL=Enter API server URL (press Enter to keep current): "
if not "%INPUT_SERVER_URL%"=="" (
  set "SERVER_URL=%INPUT_SERVER_URL%"
)

if not exist "%VIEWER_DIR%" mkdir "%VIEWER_DIR%"
> "%CONFIG_PATH%" echo {
>> "%CONFIG_PATH%" echo   "api_base_url": "%SERVER_URL%"
>> "%CONFIG_PATH%" echo }

echo Checking server health at %SERVER_URL% ...
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri '%SERVER_URL%/health' -TimeoutSec 5; if ($r.StatusCode -eq 200) { Write-Host 'Server health check succeeded.'; exit 0 } else { exit 1 } } catch { exit 1 }"
if errorlevel 1 (
  echo Warning: server health check failed. The viewer will still start, but connection may not be ready.
)

start "Safety Viewer" /D "%VIEWER_BUILD_DIR%" "%VIEWER_EXE%"

endlocal
exit /b 0

:install_flutter
set "TARGET_DIR=%~1"
if "%TARGET_DIR%"=="" exit /b 1

if exist "%TARGET_DIR%\bin\flutter.bat" (
  set "PATH=%TARGET_DIR%\bin;%PATH%"
  exit /b 0
)
exit /b 1

:ensure_windows_build_tools
set "VSWHERE_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_NATIVE_READY="
set "SDK_READY="

if exist "%VSWHERE_EXE%" (
  for /f "usebackq delims=" %%i in (`"%VSWHERE_EXE%" -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
    set "VS_NATIVE_READY=%%i"
  )
)

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$roots = @('C:\Program Files (x86)\Windows Kits\10\Include','C:\Program Files\Windows Kits\10\Include'); foreach ($root in $roots) { if (Test-Path $root) { $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending; if ($dirs) { $dirs[0].FullName; break } } }"`) do (
  set "SDK_READY=%%i"
)

if defined VS_NATIVE_READY if defined SDK_READY exit /b 0
exit /b 1
