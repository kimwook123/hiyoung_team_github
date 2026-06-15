@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "SERVER_DIR=%ROOT_DIR%\safety_monitor_server"
set "PYTHON_CMD=%ROOT_DIR%\.venv\Scripts\python.exe"

call "%ROOT_DIR%\install_dependencies.bat" server
if errorlevel 1 (
  echo Failed to prepare server dependencies.
  pause
  exit /b 1
)

if not exist "%SERVER_DIR%\main.py" (
  echo Server entry file not found.
  echo %SERVER_DIR%\main.py
  pause
  exit /b 1
)

echo Python interpreter:
"%PYTHON_CMD%" -c "import sys; print(sys.executable)"

echo Starting Safety Monitor Server on http://0.0.0.0:8000
echo.
echo Server URLs to use from other PCs:
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } | Sort-Object InterfaceAlias | ForEach-Object { Write-Host ('  http://' + $_.IPAddress + ':8000') }"
echo.
echo If other PCs cannot open http://SERVER_IP:8000/health, run setup_server_firewall.bat as Administrator on this server PC.
echo.
pushd "%SERVER_DIR%"
"%PYTHON_CMD%" -m uvicorn main:app --host 0.0.0.0 --port 8000 --no-access-log
popd

pause
endlocal
