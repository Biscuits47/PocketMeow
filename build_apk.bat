@echo off
setlocal

set "SHOULD_PAUSE=1"
if /I "%~1"=="--no-pause" (
  set "SHOULD_PAUSE=0"
)

set PROJECT_DIR=%~dp0
cd /d "%PROJECT_DIR%"

if not defined JAVA_HOME (
  if exist "D:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
    set "JAVA_HOME=D:\Program Files\Android\Android Studio\jbr"
  ) else if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
  ) else if exist "C:\Program Files\Eclipse Adoptium\jdk-17\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17"
  )
)

if defined JAVA_HOME (
  set "PATH=%JAVA_HOME%\bin;%PATH%"
)

if exist "C:\Users\krilra\flutter\bin\flutter.bat" (
  set "FLUTTER_CMD=C:\Users\krilra\flutter\bin\flutter.bat"
) else (
  set "FLUTTER_CMD=flutter"
)

echo.
echo [PocketMeow] Checking Flutter...
echo [PocketMeow] Using Java: %JAVA_HOME%
java -version
if errorlevel 1 (
  echo.
  echo Java is not available. Please install JDK 17+ or Android Studio.
  call :maybe_pause
  exit /b 1
)
call "%FLUTTER_CMD%" --version
if errorlevel 1 (
  echo.
  echo Flutter is not available. Please install Flutter or fix PATH first.
  call :maybe_pause
  exit /b 1
)

echo.
echo [PocketMeow] Fetching dependencies...
call "%FLUTTER_CMD%" pub get
if errorlevel 1 (
  echo.
  echo flutter pub get failed.
  call :maybe_pause
  exit /b 1
)

echo.
echo [PocketMeow] Building release APK...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$flutter='%FLUTTER_CMD%'; $cmdStr = '{0} build apk --release > build_out.log 2> build_err.log' -f $flutter; $proc = Start-Process cmd.exe -ArgumentList '/c', $cmdStr -WindowStyle Hidden -PassThru; $i=0; while(-not $proc.HasExited){ $i=[math]::min($i+1, 99); Write-Progress -Activity 'Building PocketMeow APK' -Status ('{0}%% Complete' -f $i) -PercentComplete $i; Start-Sleep -Milliseconds 600 }; Write-Progress -Activity 'Building PocketMeow APK' -Completed; exit $proc.ExitCode"
set BUILD_EXIT_CODE=%ERRORLEVEL%

if %BUILD_EXIT_CODE% neq 0 (
  echo.
  echo APK build failed. Please check build_err.log and build_out.log for details.
  call :maybe_pause
  exit /b 1
)

set "TARGET_DIR=E:\Temp"
if not exist "%TARGET_DIR%" (
  echo [PocketMeow] Creating target directory %TARGET_DIR%...
  mkdir "%TARGET_DIR%"
)

for /f "tokens=2" %%v in ('findstr "^version: " "%PROJECT_DIR%pubspec.yaml"') do set "FULL_VERSION=%%v"
for /f "tokens=1 delims=+" %%a in ("%FULL_VERSION%") do set "APP_VERSION=%%a"
set "APK_FILENAME=PocketMeow_v%APP_VERSION%.apk"

echo [PocketMeow] Copying APK to %TARGET_DIR%...
copy /Y "%PROJECT_DIR%build\app\outputs\flutter-apk\app-release.apk" "%TARGET_DIR%\%APK_FILENAME%" >nul

echo.
echo APK build and copy completed:
echo %TARGET_DIR%\%APK_FILENAME%
call :maybe_pause
exit /b 0

:maybe_pause
if "%SHOULD_PAUSE%"=="1" pause
exit /b 0
