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
  "if (-not ($content -match '(?m)^version:\s*(.+?)(?:\+(\d+))?$')) { throw 'version field not found'; }" ^
  "$currentVersionName = $matches[1];" ^
  "$currentVersionCode = if ($matches[2]) { [int]$matches[2] } else { 0 };" ^
  "$cleanVersion = '%NEW_VERSION%'.Trim();" ^
  "$parts = $cleanVersion.Split('.');" ^
  "$baseVersionCode = [int]$parts[0] * 1000000 + [int]$parts[1] * 1000 + [int]$parts[2];" ^
  "if ($cleanVersion -eq $currentVersionName) {" ^
  "  if ($currentVersionCode -ge $baseVersionCode) {" ^
  "    $versionCode = $currentVersionCode + 1;" ^
  "  } else {" ^
  "    $versionCode = $baseVersionCode;" ^
  "  }" ^
  "} else {" ^
  "  $versionCode = $baseVersionCode;" ^
  "}" ^
  "$fullVersion = $cleanVersion + '+' + $versionCode.ToString();" ^
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
