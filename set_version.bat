@echo off
setlocal EnableDelayedExpansion

set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"

set "NEW_VERSION=%~1"

if "%NEW_VERSION%"=="" (
  set /p "NEW_VERSION=Enter version (example 1.2.0): "
)

if "%NEW_VERSION%"=="" (
  echo Version is required.
  pause
  exit /b 1
)

echo %NEW_VERSION%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
  echo Invalid version format. Use x.y.z, for example 1.2.0
  pause
  exit /b 1
)

set "TARGET_VERSION=%NEW_VERSION%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path = 'pubspec.yaml';" ^
  "$content = Get-Content -Raw -Path $path;" ^
  "$updated = [regex]::Replace($content, '(?m)^version:\s*.+$', 'version: %TARGET_VERSION%');" ^
  "if ($updated -eq $content) { throw 'version field not found'; }" ^
  "[System.IO.File]::WriteAllText((Resolve-Path $path), $updated, (New-Object System.Text.UTF8Encoding($false)));"

if errorlevel 1 (
  echo Failed to update version.
  pause
  exit /b 1
)

echo.
echo Updated version to %TARGET_VERSION%
echo File: %PROJECT_DIR%pubspec.yaml
echo.
echo Example:
echo   set_version.bat 1.2.0
pause
