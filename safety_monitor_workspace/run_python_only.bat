@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "PY_DIR=%ROOT_DIR%\safety_ai_monitor"

if not exist "%PY_DIR%\main.py" (
  echo Python entry file not found.
  echo %PY_DIR%\main.py
  pause
  exit /b 1
)

echo Starting Safety Python AI Worker...
pushd "%PY_DIR%"
py -3.12 main.py
popd

pause
endlocal
