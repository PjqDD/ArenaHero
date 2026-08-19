@echo off
setlocal

cd /d "%~dp0"
title Arena Hero Launcher

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    goto :failed
)

if not exist ".venv\Scripts\python.exe" goto :setup
".venv\Scripts\python.exe" -c "import arena_hero" >nul 2>&1
if errorlevel 1 goto :setup
goto :credentials

:setup
echo [Arena Hero] Preparing the Python environment...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
if errorlevel 1 goto :failed

:credentials
if exist ".arena_hero_api_key.dpapi" goto :launch
echo.
echo [Arena Hero] An API Key is required for the first launch.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0set_key.ps1"
if errorlevel 1 goto :failed

:launch
echo.
echo [Arena Hero] Starting the agent and route overlay...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_all.ps1"
if errorlevel 1 goto :failed

echo.
echo [Arena Hero] Launch completed. This window will close shortly.
timeout /t 3 /nobreak >nul
exit /b 0

:failed
echo.
echo [ERROR] Arena Hero could not be started. Review the message above.
pause
exit /b 1
