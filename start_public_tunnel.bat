@echo off
title Rakshak-AI Public Cloud Relay
cls
echo =========================================================================
echo               RAKSHAK-AI GLOBAL CLOUD RELAY (ANY-NETWORK TUNNEL)
echo =========================================================================
echo.
echo Starting secure public tunnel to port 5000...
echo This generates a public HTTPS URL accessible from ANY smartphone
echo on ANY cellular network (Jio / Airtel 4G/5G, mobile data, or outside Wi-Fi).
echo.
echo Once the URL appears (e.g., https://xxxxxx.loca.lt):
echo   1. Open the Rakshak-AI app on your phone.
echo   2. Tap the Hub (antenna) icon in the top right AppBar.
echo   3. Paste the URL and tap SAVE ^& APPLY.
echo.
echo =========================================================================
echo.
npx.cmd localtunnel --port 5000
pause
