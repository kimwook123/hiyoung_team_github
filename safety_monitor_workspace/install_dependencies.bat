@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "VENV_DIR=%ROOT_DIR%\.venv"
set "PYTHON_EXE=%VENV_DIR%\Scripts\python.exe"
set "MODE=%~1"

if "%MODE%"=="" set "MODE=all"
if /I not "%MODE%"=="server" if /I not "%MODE%"=="client" if /I not "%MODE%"=="all" (
  echo Usage: install_dependencies.bat [server^|client^|all]
  exit /b 1
)

if not exist "%VENV_DIR%\Scripts\python.exe" (
  echo Creating workspace virtual environment:
  echo   %VENV_DIR%
  call :find_bootstrap_python
  if errorlevel 1 (
    echo Python 3.12 or python was not found.
    echo Install Python 3.12 and try again.
    exit /b 1
  )
  call %BOOTSTRAP_PYTHON% -m venv "%VENV_DIR%"
  if errorlevel 1 (
    echo Failed to create virtual environment.
    exit /b 1
  )
)

if not exist "%PYTHON_EXE%" (
  echo Virtual environment python not found:
  echo   %PYTHON_EXE%
  exit /b 1
)

echo Python interpreter:
"%PYTHON_EXE%" -c "import sys; print(sys.executable)"

"%PYTHON_EXE%" -m pip --version > nul 2>&1
if errorlevel 1 (
  echo pip is not available in the virtual environment.
  exit /b 1
)

if /I "%MODE%"=="server" (
  call :ensure_server
  exit /b %ERRORLEVEL%
)

if /I "%MODE%"=="client" (
  call :ensure_client
  exit /b %ERRORLEVEL%
)

call :ensure_server
if errorlevel 1 exit /b 1
call :ensure_client
exit /b %ERRORLEVEL%

:find_bootstrap_python
py -3.12 -c "import sys" > nul 2>&1
if not errorlevel 1 (
  set "BOOTSTRAP_PYTHON=py -3.12"
  exit /b 0
)
python -c "import sys" > nul 2>&1
if not errorlevel 1 (
  set "BOOTSTRAP_PYTHON=python"
  exit /b 0
)
exit /b 1

:ensure_server
echo Checking server Python dependencies...
"%PYTHON_EXE%" -c "import fastapi, uvicorn, websockets, pydantic, multipart, cv2, numpy" > nul 2>&1
if not errorlevel 1 (
  echo Server dependencies are already installed.
  exit /b 0
)

echo Installing missing server dependencies from root requirements-server.txt...
"%PYTHON_EXE%" -m pip install -r "%ROOT_DIR%\requirements-server.txt"
if errorlevel 1 exit /b 1

"%PYTHON_EXE%" -c "import fastapi, uvicorn, websockets, pydantic, multipart, cv2, numpy" > nul 2>&1
if errorlevel 1 (
  echo Server dependency check failed after install.
  exit /b 1
)
echo Server dependencies are ready.
exit /b 0

:ensure_client
echo Checking client embedded backend Python dependencies...
"%PYTHON_EXE%" -c "import fastapi, uvicorn, cv2, numpy, requests, yt_dlp, websockets, torch, tensorrt, ultralytics, onnx, onnxruntime" > nul 2>&1
if not errorlevel 1 (
  echo Client dependencies are already installed.
  exit /b 0
)

echo Installing missing client dependencies from root requirements.txt...
"%PYTHON_EXE%" -m pip install -r "%ROOT_DIR%\requirements.txt"
if errorlevel 1 exit /b 1

"%PYTHON_EXE%" -c "import fastapi, uvicorn, cv2, numpy, requests, yt_dlp, websockets, torch, tensorrt, ultralytics, onnx, onnxruntime" > nul 2>&1
if errorlevel 1 (
  echo Client dependency check failed after install.
  exit /b 1
)
echo Client dependencies are ready.
exit /b 0
