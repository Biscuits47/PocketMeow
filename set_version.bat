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

set "NEW_VERSION=%NEW_VERSION: =%"

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
  "if (-not ($content -match '(?m)^version:\s*.+$')) { throw 'version field not found'; }" ^
  "$cleanVersion = '%NEW_VERSION%'.Trim();" ^
  "$parts = $cleanVersion.Split('.');" ^
  "$versionCode = [int]$parts[0] * 10 + [int]$parts[2];" ^
  "$fullVersion = $cleanVersion + '+' + $versionCode.ToString('D2');" ^
  "$updated = [regex]::Replace($content, '(?m)^version:\s*.+$', ('version: ' + $fullVersion));" ^
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
