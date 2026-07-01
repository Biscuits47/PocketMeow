@echo off
setlocal

set PROJECT_DIR=%~dp0
cd /d "%PROJECT_DIR%"

if exist "C:\Users\krilra\flutter\bin\flutter.bat" (
  set "FLUTTER_CMD=C:\Users\krilra\flutter\bin\flutter.bat"
) else (
  set "FLUTTER_CMD=flutter"
)

echo.
echo [PocketMeow] Checking Flutter...
call "%FLUTTER_CMD%" --version
if errorlevel 1 (
  echo.
  echo Flutter is not available. Please install Flutter or fix PATH first.
  pause
  exit /b 1
)

echo.
echo [PocketMeow] Fetching dependencies...
call "%FLUTTER_CMD%" pub get
if errorlevel 1 (
  echo.
  echo flutter pub get failed.
  pause
  exit /b 1
)

echo.
echo [PocketMeow] Building release APK...
call "%FLUTTER_CMD%" build apk --release
if errorlevel 1 (
  echo.
  echo APK build failed.
  echo Make sure Android SDK is installed and configured.
  pause
  exit /b 1
)

echo.
echo APK build completed:
echo %PROJECT_DIR%build\app\outputs\flutter-apk\app-release.apk
pause
