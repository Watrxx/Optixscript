@echo off
chcp 65001 >nul 2>&1
title OPTIX
cd /d "%~dp0"

:: OPTIX - System Optimizer (Classic Runner)

echo.
echo  ====================================
echo   OPTIX - System Optimizer
echo  ====================================
echo.

:: Check PowerShell
where powershell >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell not found!
    echo.
    pause
    exit /b 1
)

:: Logs in local "logs" folder next to the script
set TEMP_LOG=%~dp0logs\last_run.log

:: Small delay before launching OPTIX
echo [INFO] Launching OPTIX in 3 seconds...
timeout /t 3 /nobreak >nul

:: Run OPTIX
echo [INFO] Starting OPTIX...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0optimization_script.ps1"
set EXITCODE=%errorlevel%

echo.
if %EXITCODE% equ 0 (
    echo [OK] OPTIX finished successfully
) else (
    echo [ERROR] OPTIX crashed with code: %EXITCODE%
)

echo.
echo  ====================================
echo   What do you want to do?
echo  ====================================
echo   1 - Open log
echo   2 - Restart OPTIX
echo   3 - Clean old logs ^& exit
echo   4 - Just exit
echo  ====================================
echo.

choice /c 1234 /n /m "Choose (1-4): "

if errorlevel 4 goto :exit
if errorlevel 3 goto :clean
if errorlevel 2 goto :restart
if errorlevel 1 goto :openlog

:openlog
echo.
echo Opening log: %TEMP_LOG%
start "" notepad "%TEMP_LOG%"
goto :exit

:restart
echo.
echo Restarting in 2 seconds...
timeout /t 2 /nobreak >nul
call "%~dp0run_optix.bat"
goto :exit

:clean
echo.
echo Cleaning old logs from %~dp0logs ...
if exist "%~dp0logs" (
    del /q "%~dp0logs\*.*" >nul 2>&1
    echo [OK] Logs cleaned
) else (
    echo [INFO] No logs to clean
)
timeout /t 2 /nobreak >nul
goto :exit

:exit
echo.
echo Closing in 3 seconds...
timeout /t 3 >nul
exit /b %EXITCODE%
