@echo off
title Telegram WebRTC - Free Public Online Server
echo ========================================================
echo   STARTING TELEGRAM WEBRTC APP + FREE PUBLIC TUNNEL
echo ========================================================
echo.

cd /d "%~dp0"

echo [1/2] Launching Backend Server on port 3000...
start "Telegram Server" cmd /k "npm start"

timeout /t 3 /nobreak >nul

echo [2/2] Creating Free 100%% Permanent Cloudflare HTTPS Tunnel...
echo.
echo ========================================================
echo COPY THE PUBLIC HTTPS LINK BELOW TO SHARE WITH ANYONE:
echo ========================================================
echo.
npx -y untun tunnel --port 3000
pause
