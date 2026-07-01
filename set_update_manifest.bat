@echo off
setlocal

set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"

set "APK_URL=%~1"
set "PAGE_URL=%~2"
set "NOTES=%~3"

if "%APK_URL%"=="" (
  set /p APK_URL=Enter APK url: 
)

if "%PAGE_URL%"=="" (
  set /p PAGE_URL=Enter page url (optional): 
)

if "%NOTES%"=="" (
  set /p NOTES=Enter release notes (optional): 
)

if "%APK_URL%"=="" (
  echo APK url is required.
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$pubspec = 'pubspec.yaml';" ^
  "$manifest = 'update/latest.json';" ^
  "$content = Get-Content -Raw -Path $pubspec;" ^
  "$match = [regex]::Match($content, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$');" ^
  "if (-not $match.Success) { throw 'version field not found'; }" ^
  "$version = $match.Groups[1].Value;" ^
  "$build = [int]$match.Groups[2].Value;" ^
  "$data = [ordered]@{ version = $version; build = $build; notes = '%NOTES%'; apk_url = '%APK_URL%'; page_url = '%PAGE_URL%'; published_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz') };" ^
  "$json = $data | ConvertTo-Json -Depth 3;" ^
  "[System.IO.File]::WriteAllText((Join-Path (Get-Location) $manifest), $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)));"

if errorlevel 1 (
  echo Failed to update update/latest.json
  exit /b 1
)

echo.
echo Updated update/latest.json using version from pubspec.yaml
echo APK url: %APK_URL%
if not "%PAGE_URL%"=="" echo Page url: %PAGE_URL%
echo.
echo Example:
echo   set_update_manifest.bat https://cdn.example.com/PocketMeow.apk https://your-site.example.com "Bug fixes"
pause
