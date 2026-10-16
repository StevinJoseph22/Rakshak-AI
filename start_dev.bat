@echo off
title Rakshak-AI Unified Launcher
cls
echo ==============================================================================
echo                      RAKSHAK-AI UNIFIED SYSTEM RUNNER
echo ==============================================================================
echo.

rem Detect current active Wi-Fi IPv4 address
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-NetIPAddress -InterfaceAlias 'Wi-Fi*' -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -notlike '127.*' }).IPAddress | Select-Object -First 1"') do set WORKSTATION_IP=%%a

if "%WORKSTATION_IP%"=="" (
    for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '192.168.56.*' -and $_.IPAddress -notlike '172.*' }).IPAddress | Select-Object -First 1"') do set WORKSTATION_IP=%%a
)

if "%WORKSTATION_IP%"=="" set WORKSTATION_IP=127.0.0.1

echo [Network] Active Workstation IPv4 : %WORKSTATION_IP%
echo [Backend] Listening on Port       : http://%WORKSTATION_IP%:5000
echo [Dashboard] Listening on Port     : http://localhost:5173
echo.

rem Automatically enable reverse port forwarding for USB-connected Android devices
set ADB="C:\AndroidSDK\platform-tools\adb.exe"
if exist %ADB% (
    echo [ADB] Checking for connected Android devices...
    %ADB% reverse tcp:5000 tcp:5000 2>nul
    if %ERRORLEVEL% equ 0 (
        echo [ADB] Port 5000 reversed to device successfully (0ms latency fast-path).
    ) else (
        echo [ADB] No USB Android device found (device can connect over Wi-Fi: http://%WORKSTATION_IP%:5000).
    )
)
echo.
echo ==============================================================================
echo Launching Backend and Dashboard concurrently in this single terminal...
echo Press Ctrl+C at any time to terminate both servers.
echo ==============================================================================
echo.

cmd /c "npx --yes concurrently -n \"backend,dashboard\" -c \"cyan.bold,magenta.bold\" \"npm run dev --prefix backend\" \"npm run dev --prefix dashboard\""
pause
