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

:: Check for updates from git repo if available
if exist "%~dp0..\.git" (
    echo [INFO] Checking for updates...
    git -C "%~dp0.." pull --quiet 2>nul
    if errorlevel 0 (
        echo [OK] Update check completed
    ) else (
        echo [INFO] Skipping update check
    )
    echo.
)

:: Logs in local "logs" folder next to the script
if not exist "%~dp0logs" mkdir "%~dp0logs" 2>nul
set "TEMP_LOG=%~dp0logs\last_run.log"

:: Small delay before launching OPTIX
echo [INFO] Launching OPTIX in 3 seconds...
timeout /t 3 /nobreak >nul 2>&1

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
echo   3 - Clean old logs & exit
echo   4 - Just exit
echo  ====================================
echo.

set "CHOICE="
choice /c 1234 /n /m "Choose (1-4): " 2>nul
set "CHOICE_ERR=%errorlevel%"
if %CHOICE_ERR% equ 0 (
    set /p CHOICE="Choose (1-4): "
) else (
    set "CHOICE=%CHOICE_ERR%"
)

if "%CHOICE%" equ "4" goto :exit
if "%CHOICE%" equ "3" goto :clean
if "%CHOICE%" equ "2" goto :restart
if "%CHOICE%" equ "1" goto :openlog
goto :exit

:openlog
echo.
echo Opening log: %TEMP_LOG%
start "" notepad "%TEMP_LOG%" 2>nul
goto :exit

:restart
echo.
echo Restarting in 2 seconds...
timeout /t 2 /nobreak >nul 2>&1
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
timeout /t 2 /nobreak >nul 2>&1
goto :exit

:exit
echo.
echo Closing in 3 seconds...
timeout /t 3 >nul 2>&1
exit /b %EXITCODE%
