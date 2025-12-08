@echo off
:: Tencent DNS Show Rules Script
:: Auto-request administrator privileges and run PowerShell script

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running as administrator...
    goto :RunScript
) else (
    echo Requesting administrator privileges...
    goto :RequestAdmin
)

:RequestAdmin
:: Request administrator privileges
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b

:RunScript
:: Change to script directory
cd /d "%~dp0"

echo.
echo ========================================
echo   Tencent DNS Rules Display
echo ========================================
echo.

:: Set execution policy for current process and run PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; & '.\TencentDNS_ever.ps1' -Action Show"

echo.
echo ========================================
echo   Display Complete
echo ========================================
echo.

:: Pause to see results
pause
