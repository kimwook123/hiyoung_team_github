@echo off
setlocal EnableExtensions

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "VIEWER_DIR=%ROOT_DIR%\safety_monitor_viewer"
set "LOCAL_FLUTTER=%ROOT_DIR%\flutter\bin\flutter.bat"
set "FLUTTER_CMD=flutter"
set "PAUSE_ON_EXIT=1"
if /I "%~1"=="/nopause" set "PAUSE_ON_EXIT=0"
if /I "%~1"=="--no-pause" set "PAUSE_ON_EXIT=0"

call :check_workspace_path
if errorlevel 1 goto :fail
call :find_flutter
if errorlevel 1 goto :fail
call :prepare_windows_build_environment
if errorlevel 1 goto :fail

if not exist "%VIEWER_DIR%\pubspec.yaml" (
  echo Viewer project not found:
  echo   %VIEWER_DIR%\pubspec.yaml
  goto :fail
)

pushd "%VIEWER_DIR%"
call "%FLUTTER_CMD%" clean
if errorlevel 1 (
  popd
  goto :fail
)

if not exist "windows\flutter\CMakeLists.txt" (
  echo Regenerating missing Windows Flutter files...
  call "%FLUTTER_CMD%" create --platforms=windows .
  if errorlevel 1 (
    popd
    goto :fail
  )
)

call "%FLUTTER_CMD%" pub get
if errorlevel 1 (
  popd
  goto :fail
)

call "%FLUTTER_CMD%" config --enable-windows-desktop
if errorlevel 1 (
  popd
  goto :fail
)

call "%FLUTTER_CMD%" build windows
if errorlevel 1 (
  popd
  goto :fail
)
popd

echo Viewer build finished.
if "%PAUSE_ON_EXIT%"=="1" pause
exit /b 0

:check_workspace_path
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "'%ROOT_DIR%'.Length"`) do set "ROOT_LEN=%%i"
echo Workspace root: %ROOT_DIR%
echo Path length: %ROOT_LEN%
if %ROOT_LEN% GEQ 80 (
  echo This path is too long. Move the repository near a drive root, e.g. C:\safety_monitor_workspace or D:\safety_monitor_workspace.
  exit /b 1
)
exit /b 0

:find_flutter
if exist "%LOCAL_FLUTTER%" (
  set "FLUTTER_CMD=%LOCAL_FLUTTER%"
  exit /b 0
)
where flutter > nul 2>&1
if errorlevel 1 (
  echo Flutter SDK not found. Put Flutter at:
  echo   %ROOT_DIR%\flutter
  echo or add flutter to PATH.
  exit /b 1
)
set "FLUTTER_CMD=flutter"
exit /b 0

:prepare_windows_build_environment
git -C "%ROOT_DIR%" config core.longpaths true > nul 2>&1
call :ensure_windows_build_tools
exit /b %ERRORLEVEL%

:ensure_windows_build_tools
set "VSWHERE_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_NATIVE_READY="
set "SDK_READY="
if exist "%VSWHERE_EXE%" (
  for /f "usebackq delims=" %%i in (`"%VSWHERE_EXE%" -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_NATIVE_READY=%%i"
)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$roots=@('C:\Program Files (x86)\Windows Kits\10\Include','C:\Program Files\Windows Kits\10\Include'); foreach($root in $roots){ if(Test-Path $root){ $dirs=Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending; if($dirs){ $dirs[0].FullName; break } } }"`) do set "SDK_READY=%%i"
if defined VS_NATIVE_READY if defined SDK_READY exit /b 0
echo Windows C++ build tools are missing.
echo Install Visual Studio Build Tools with "Desktop development with C++" and Windows 10/11 SDK.
exit /b 1

:fail
echo Viewer build failed.
if "%PAUSE_ON_EXIT%"=="1" pause
exit /b 1
