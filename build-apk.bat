@echo off
title Build Telegram Flutter Android APK
echo ========================================================
echo   BUILDING TELEGRAM FLUTTER ANDROID APK
echo ========================================================
echo.
cd /d "%~dp0"
flutter build apk --split-per-abi
echo.
echo ========================================================
echo   APK BUILD COMPLETE!
echo   Output located in: build\app\outputs\flutter-apk\
echo ========================================================
pause
