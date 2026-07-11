@echo off
echo ========================================
echo  ISWARA Marketplace - Deploy Script
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] Building Flutter Web App...
call flutter build web --web-renderer html
if %errorlevel% neq 0 (
    echo Build GAGAL!
    pause
    exit /b 1
)

echo.
echo [2/3] Checking build folder...
if not exist "build\web\index.html" (
    echo Build folder tidak ditemukan!
    pause
    exit /b 1
)

echo.
echo [3/3] Deploying to Firebase...
call firebase deploy --only hosting

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo  DEPLOY BERHASIL! 🎉
    echo ========================================
) else (
    echo.
    echo ========================================
    echo  Deploy GAGAL!
    echo ========================================
    echo.
    echo Pastikan Anda sudah login Firebase:
    echo   firebase login
)

echo.
pause
