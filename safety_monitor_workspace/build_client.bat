@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ORIGINAL_ROOT_DIR=%~dp0"
if "%ORIGINAL_ROOT_DIR:~-1%"=="\" set "ORIGINAL_ROOT_DIR=%ORIGINAL_ROOT_DIR:~0,-1%"
set "ROOT_DIR=%ORIGINAL_ROOT_DIR%"
set "SHORT_BUILD_DRIVE=%SAFETY_MONITOR_BUILD_DRIVE%"
if "%SHORT_BUILD_DRIVE%"=="" set "SHORT_BUILD_DRIVE=S:"
if not "%SHORT_BUILD_DRIVE:~-1%"==":" set "SHORT_BUILD_DRIVE=%SHORT_BUILD_DRIVE%:"
set "MAPPED_SHORT_DRIVE="
set "JUNCTION_SHORT_ROOT="
set "PAUSE_ON_EXIT=1"
if /I "%~1"=="/nopause" set "PAUSE_ON_EXIT=0"
if /I "%~1"=="--no-pause" set "PAUSE_ON_EXIT=0"

call :map_short_root
if errorlevel 1 goto :fail

set "CLIENT_PROJECT=%ROOT_DIR%\safety_monitor_client"
set "LOCAL_FLUTTER_BIN=%ROOT_DIR%\flutter\bin\flutter.bat"
set "FLUTTER_BIN=flutter"

call "%ROOT_DIR%\install_dependencies.bat" client
if errorlevel 1 (
  echo Failed to prepare client dependencies.
  goto :fail
)

if exist "%LOCAL_FLUTTER_BIN%" (
  set "FLUTTER_BIN=%LOCAL_FLUTTER_BIN%"
) else (
  where flutter > nul 2>&1
  if errorlevel 1 (
    echo Flutter SDK not found.
    echo Expected local SDK:
    echo   %LOCAL_FLUTTER_BIN%
    goto :fail
  )
)

call :prepare_windows_build_environment
if errorlevel 1 goto :fail

pushd "%CLIENT_PROJECT%"
call "%FLUTTER_BIN%" clean
if errorlevel 1 (
  echo flutter clean failed.
  popd
  goto :fail
)

if not exist "windows\flutter\CMakeLists.txt" (
  echo Windows Flutter build files are missing. Regenerating them...
  call "%FLUTTER_BIN%" create --platforms=windows .
  if errorlevel 1 (
    echo flutter create windows files failed.
    popd
    goto :fail
  )
)

call "%FLUTTER_BIN%" pub get
if errorlevel 1 (
  echo flutter pub get failed.
  popd
  goto :fail
)

call "%FLUTTER_BIN%" config --enable-windows-desktop
if errorlevel 1 (
  echo flutter config --enable-windows-desktop failed.
  popd
  goto :fail
)

call "%FLUTTER_BIN%" build windows
if errorlevel 1 (
  echo flutter build windows failed.
  popd
  goto :fail
)

popd
echo Build finished.
call :cleanup_short_root
if "%PAUSE_ON_EXIT%"=="1" pause
exit /b 0

:map_short_root
if /I "%SAFETY_MONITOR_DISABLE_SUBST%"=="1" exit /b 0
if /I "%ORIGINAL_ROOT_DIR:~0,3%"=="%SHORT_BUILD_DRIVE%\" exit /b 0

set "DRIVE_CANDIDATES=%SHORT_BUILD_DRIVE% S: R: Q: P: T: Y: Z: X: W: V:"
for %%D in (%DRIVE_CANDIDATES%) do (
  set "CANDIDATE_DRIVE=%%D"
  if /I "!ORIGINAL_ROOT_DIR:~0,3!"=="!CANDIDATE_DRIVE!\" exit /b 0
  if not exist "!CANDIDATE_DRIVE!\" (
    subst !CANDIDATE_DRIVE! "%ORIGINAL_ROOT_DIR%" > nul 2>&1
    if not errorlevel 1 (
      set "MAPPED_SHORT_DRIVE=!CANDIDATE_DRIVE!"
      set "ROOT_DIR=!CANDIDATE_DRIVE!"
      echo Building through short path !ROOT_DIR! to avoid Windows path length issues.
      exit /b 0
    )
  )
)

call :map_junction_root
exit /b %ERRORLEVEL%

:map_junction_root
if /I "%SAFETY_MONITOR_DISABLE_JUNCTION%"=="1" (
  echo Failed to create a short build path with subst, and junction fallback is disabled.
  echo Set SAFETY_MONITOR_BUILD_DRIVE to a free drive letter or move the workspace to C:\smw.
  exit /b 1
)
set "JUNCTION_SHORT_ROOT=%SAFETY_MONITOR_BUILD_LINK%"
if "%JUNCTION_SHORT_ROOT%"=="" set "JUNCTION_SHORT_ROOT=%TEMP%\smw_build"
if exist "%JUNCTION_SHORT_ROOT%" rmdir "%JUNCTION_SHORT_ROOT%" > nul 2>&1
cmd /c mklink /J "%JUNCTION_SHORT_ROOT%" "%ORIGINAL_ROOT_DIR%" > nul 2>&1
if errorlevel 1 (
  echo Failed to create a short build path with subst or junction.
  echo Move the workspace to a short path such as C:\smw and retry.
  exit /b 1
)
set "ROOT_DIR=%JUNCTION_SHORT_ROOT%"
echo Building through short junction %ROOT_DIR% to avoid Windows path length issues.
exit /b 0

:prepare_windows_build_environment
git -C "%ORIGINAL_ROOT_DIR%" config core.longpaths true > nul 2>&1

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "try { (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop).LongPathsEnabled } catch { '0' }"`) do (
  set "WINDOWS_LONG_PATHS=%%i"
)
if not "%WINDOWS_LONG_PATHS%"=="1" (
  echo Warning: Windows LongPathsEnabled is not enabled on this PC.
  echo The build will use a short subst path, but enabling Windows long paths is recommended.
)

call :ensure_windows_build_tools
if errorlevel 1 (
  echo Windows desktop C++ build tools are not ready.
  echo Install Visual Studio Build Tools or Visual Studio Community with "Desktop development with C++" and Windows 10/11 SDK.
  exit /b 1
)
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
exit /b 1

:cleanup_short_root
if not "%MAPPED_SHORT_DRIVE%"=="" (
  subst %MAPPED_SHORT_DRIVE% /D > nul 2>&1
)
if not "%JUNCTION_SHORT_ROOT%"=="" (
  if exist "%JUNCTION_SHORT_ROOT%" rmdir "%JUNCTION_SHORT_ROOT%" > nul 2>&1
)
exit /b 0

:fail
call :cleanup_short_root
if "%PAUSE_ON_EXIT%"=="1" pause
exit /b 1
