@echo off
setlocal enabledelayedexpansion

echo ==============================================
echo       EduVaults Installer Script
echo ==============================================
echo.

:: 1. Database Setup
echo [1] Setting up the MySQL Database...
set /p DB_USER="Enter MySQL Username (default: root): "
if "%DB_USER%"=="" set DB_USER=root

set /p DB_PASS="Enter MySQL Password (leave blank if none): "

echo Importing database schema...
if "%DB_PASS%"=="" (
    mysql -u %DB_USER% < ..\api\eduvaults_mysql.sql
) else (
    mysql -u %DB_USER% -p"%DB_PASS%" < ..\api\eduvaults_mysql.sql
)

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to import database. Please ensure MySQL is running and credentials are correct.
    pause
    exit /b %ERRORLEVEL%
)
echo Database imported successfully!

:: 2. API Setup
echo.
echo [2] Setting up the API...
cd ..\api
if not exist node_modules (
    echo Installing API dependencies...
    call npm install
) else (
    echo API dependencies already installed.
)

:: Ensure .env exists
if not exist .env (
    echo Creating .env file...
    echo PORT=5001 > .env
    echo DB_HOST=localhost >> .env
    echo DB_USER=%DB_USER% >> .env
    echo DB_PASSWORD=%DB_PASS% >> .env
    echo DB_NAME=eduvaults >> .env
    echo JWT_SECRET=supersecretkey_for_eduvaults_123 >> .env
    echo GMAIL_USER=runiyuningyuningnibgrum@gmail.com >> .env
    echo GMAIL_PASS=diaqzskrupngsjyq >> .env
    echo .env file created successfully!
)

:: Seed Data
echo Seeding dummy data...
call node seed_dummy_data.js
if %ERRORLEVEL% neq 0 (
    echo [WARNING] Seed data might have failed or already exist.
)

:: 3. Flutter Setup
echo.
echo [3] Setting up the Flutter App...
cd ..
echo Running flutter pub get...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to get Flutter dependencies. Please ensure Flutter is installed.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ==============================================
echo Installation Complete!
echo ==============================================
echo To start the API:
echo   cd api ^&^& npm run dev
echo To start the Flutter app:
echo   flutter run
echo.
echo You can also use "installer\start.bat" to run both simultaneously.
echo.
pause
