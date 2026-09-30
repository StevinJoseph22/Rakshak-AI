@echo off
echo ========================================================
echo   RAKSHAK-AI: RESETTING DEMO STATE FOR NEXT JUDGE RUN
echo ========================================================
cd backend
call npm.cmd run demo:reset
cd ..
echo Done.
