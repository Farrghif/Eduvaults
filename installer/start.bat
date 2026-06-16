@echo off
echo ==============================================
echo       Starting EduVaults Services
echo ==============================================
echo.

echo Starting API Server...
start "EduVaults API" cmd /k "cd ..\api && npm run dev"

echo.
echo Starting Flutter App...
echo Please ensure an emulator is running, a device is connected, or Chrome is available for web.
start "EduVaults Flutter App" cmd /k "cd .. && flutter run"

echo.
echo Services are starting in new windows. You can close this window.
pause
