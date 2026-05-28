@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "UI_DIR=%ROOT_DIR%\safety_ai_monitor_ui"
set "GUI_DIR=%UI_DIR%\build\windows\x64\runner\Release"
set "GUI_EXE=%GUI_DIR%\safety_ai_monitor_ui.exe"
set "CONFIG_PATH=%GUI_DIR%\server_config.json"
set "FLUTTER_CMD=flutter"

if not exist "%UI_DIR%\pubspec.yaml" (
  echo GUI project not found.
  echo %UI_DIR%\pubspec.yaml
  pause
  exit /b 1
)

if not exist "%GUI_EXE%" (
  set "GUI_DIR=%UI_DIR%\build\windows\x64\runner\Debug"
  set "GUI_EXE=%GUI_DIR%\safety_ai_monitor_ui.exe"
  set "CONFIG_PATH=%GUI_DIR%\server_config.json"
)

if not exist "%GUI_EXE%" (
  where "%FLUTTER_CMD%" > nul 2>&1
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

  call :ensure_windows_build_tools
  if errorlevel 1 (
    echo Windows desktop build tools are not ready.
    pause
    exit /b 1
  )

  echo GUI executable not found. Building Flutter Windows app now...
  pushd "%UI_DIR%"
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
    echo.
    echo If this is a new PC, please also check:
    echo   - Visual Studio 2022 with Desktop development with C++
    echo   - Windows 10/11 SDK
    popd
    pause
    exit /b 1
  )
  popd

  set "GUI_DIR=%UI_DIR%\build\windows\x64\runner\Release"
  set "GUI_EXE=%GUI_DIR%\safety_ai_monitor_ui.exe"
  set "CONFIG_PATH=%GUI_DIR%\server_config.json"
)

if not exist "%GUI_EXE%" (
  echo GUI executable not found.
  echo %GUI_EXE%
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

if not exist "%GUI_DIR%" mkdir "%GUI_DIR%"
> "%CONFIG_PATH%" echo {
>> "%CONFIG_PATH%" echo   "api_base_url": "%SERVER_URL%"
>> "%CONFIG_PATH%" echo }

echo Checking server health at %SERVER_URL% ...
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri '%SERVER_URL%/health' -TimeoutSec 5; if ($r.StatusCode -eq 200) { Write-Host 'Server health check succeeded.'; exit 0 } else { exit 1 } } catch { exit 1 }"
if errorlevel 1 (
  echo Warning: server health check failed. The GUI will still start, but connection may not be ready.
)

start "Safety GUI" /D "%GUI_DIR%" "%GUI_EXE%"

endlocal
exit /b 0

:install_flutter
set "TARGET_DIR=%~1"
if "%TARGET_DIR%"=="" exit /b 1

if exist "%TARGET_DIR%\bin\flutter.bat" (
  echo Existing Flutter SDK found:
  echo   %TARGET_DIR%
  set "PATH=%TARGET_DIR%\bin;%PATH%"
  exit /b 0
)

echo Downloading Flutter SDK to:
echo   %TARGET_DIR%
set "FLUTTER_TMP_ROOT=%TEMP%\flutter_sdk_install_%RANDOM%%RANDOM%"
set "FLUTTER_ZIP=%FLUTTER_TMP_ROOT%\flutter_windows.zip"
set "FLUTTER_EXTRACT=%FLUTTER_TMP_ROOT%\extract"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$target = [IO.Path]::GetFullPath('%TARGET_DIR%');" ^
  "$tmpRoot = [IO.Path]::GetFullPath('%FLUTTER_TMP_ROOT%');" ^
  "$zipPath = [IO.Path]::GetFullPath('%FLUTTER_ZIP%');" ^
  "$extractPath = [IO.Path]::GetFullPath('%FLUTTER_EXTRACT%');" ^
  "New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null;" ^
  "New-Item -ItemType Directory -Force -Path $extractPath | Out-Null;" ^
  "$releases = Invoke-RestMethod -UseBasicParsing -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json';" ^
  "$stableHash = $releases.current_release.stable;" ^
  "$release = $releases.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1;" ^
  "if (-not $release) { throw 'Stable Flutter release metadata not found.' }" ^
  "$archiveUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/' + $release.archive;" ^
  "Invoke-WebRequest -UseBasicParsing -Uri $archiveUrl -OutFile $zipPath;" ^
  "Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force;" ^
  "$expandedFlutter = Join-Path $extractPath 'flutter';" ^
  "if (-not (Test-Path $expandedFlutter)) { throw 'Expanded Flutter SDK folder not found.' }" ^
  "if (Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force }" ^
  "New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($target)) | Out-Null;" ^
  "Move-Item -LiteralPath $expandedFlutter -Destination $target;" ^
  "Remove-Item -LiteralPath $tmpRoot -Recurse -Force;"
if errorlevel 1 exit /b 1

set "PATH=%TARGET_DIR%\bin;%PATH%"
call "%TARGET_DIR%\bin\flutter.bat" --version
if errorlevel 1 exit /b 1

exit /b 0

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

echo Visual Studio 2022 C++ desktop build tools or Windows SDK were not found.
echo Visual Studio: %VS_NATIVE_READY%
echo Windows SDK: %SDK_READY%
choice /C YN /M "Install Visual Studio 2022 Desktop C++ and Windows SDK now"
if errorlevel 2 exit /b 1

set "DEFAULT_VS_DIR=%ProgramFiles%\Microsoft Visual Studio\2022\Community"
echo Default Visual Studio install directory:
echo   %DEFAULT_VS_DIR%
set /p "INPUT_VS_DIR=Enter Visual Studio install directory (press Enter to use default): "
if "%INPUT_VS_DIR%"=="" (
  set "VS_INSTALL_DIR=%DEFAULT_VS_DIR%"
) else (
  set "VS_INSTALL_DIR=%INPUT_VS_DIR%"
)

call :install_visual_studio_native "%VS_INSTALL_DIR%"
if errorlevel 1 exit /b 1

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

echo Visual Studio installation finished, but Windows SDK is still not detected.
where winget > nul 2>&1
if errorlevel 1 (
  echo winget is not available, so Windows SDK cannot be auto-installed from this script.
  exit /b 1
)

choice /C YN /M "Install Windows SDK now with winget"
if errorlevel 2 exit /b 1

winget install --accept-package-agreements --accept-source-agreements Microsoft.WindowsSDK.10.0.26100
if errorlevel 1 exit /b 1

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$roots = @('C:\Program Files (x86)\Windows Kits\10\Include','C:\Program Files\Windows Kits\10\Include'); foreach ($root in $roots) { if (Test-Path $root) { $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending; if ($dirs) { $dirs[0].FullName; break } } }"`) do (
  set "SDK_READY=%%i"
)

if defined VS_NATIVE_READY if defined SDK_READY exit /b 0
exit /b 1

:install_visual_studio_native
set "TARGET_VS_DIR=%~1"
if "%TARGET_VS_DIR%"=="" exit /b 1

set "VS_TMP_ROOT=%TEMP%\vs_buildtools_install_%RANDOM%%RANDOM%"
set "VS_BOOTSTRAPPER=%VS_TMP_ROOT%\vs_community.exe"

echo Downloading Visual Studio bootstrapper...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$tmpRoot = [IO.Path]::GetFullPath('%VS_TMP_ROOT%');" ^
  "$bootstrapper = [IO.Path]::GetFullPath('%VS_BOOTSTRAPPER%');" ^
  "New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null;" ^
  "Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vs/17/release/vs_community.exe' -OutFile $bootstrapper;"
if errorlevel 1 exit /b 1

echo Installing Visual Studio 2022 Community with Desktop development with C++...
echo This can take a long time and may prompt for administrator permission.
"%VS_BOOTSTRAPPER%" --wait --norestart --installPath "%TARGET_VS_DIR%" --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended
if errorlevel 1 exit /b 1

exit /b 0
