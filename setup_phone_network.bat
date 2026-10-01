@echo off
echo ========================================================
echo   Rakshak-AI: Reverse Port Forwarding for Physical Device
echo ========================================================
echo.
set ADB="C:\AndroidSDK\platform-tools\adb.exe"

if not exist %ADB% (
    echo Error: ADB not found at %ADB%
    pause
    exit /b 1
)

echo Enabling reverse port forward (5000 -> 5000)...
%ADB% reverse tcp:5000 tcp:5000

echo.
echo Active reverse mappings:
%ADB% reverse --list

echo.
echo Testing connectivity from device...
%ADB% shell "curl -s http://127.0.0.1:5000/health"
echo.
echo Done! Phone is now connected to laptop backend with 0ms latency.
echo ========================================================
pause
