@echo off
echo ========================================
echo    ISWARA - Android APK Builder
echo ========================================
echo.

REM Set Java Home (sesuaikan dengan versi JDK Anda)
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot
set PATH=%JAVA_HOME%\bin;%PATH%

echo Java Version:
java -version
echo.

echo Building APK Debug...
cd /d C:\Users\ephiewae\iswara_app
C:\Users\ephiewae\flutter\bin\flutter.bat build apk --debug

echo.
echo ========================================
echo    Build Complete!
echo ========================================
pause
