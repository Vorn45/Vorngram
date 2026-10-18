@echo off
title Telegram Flutter App - Android Emulator
echo ========================================================
echo   LAUNCHING PIXEL 7 AND RUNNING TELEGRAM FLUTTER APP
echo ========================================================
echo.
cd /d "%~dp0"
echo Starting Android emulator Pixel_7...
flutter emulators --launch Pixel_7
echo Waiting for emulator to boot up...
timeout /t 10 /nobreak
flutter run -d android
pause
