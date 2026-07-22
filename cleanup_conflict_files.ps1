param(
    [string]$TargetPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$conflictMarker = "_" + [string]([char]0x51B2) + [char]0x7A81 + [char]0x6587 + [char]0x4EF6
$exitCode = 0

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $TargetPath = $PSScriptRoot
    }
    else {
        $TargetPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
}

function Remove-FilePermanently {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Remove-Item -LiteralPath $FilePath -Force
}

try {
    if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
        Write-Host "Target folder does not exist:" -ForegroundColor Red -NoNewline
        Write-Host " $TargetPath" -ForegroundColor Yellow
        $exitCode = 1
        return
    }

    Write-Host "Scanning folder:" -ForegroundColor Cyan -NoNewline
    Write-Host " $TargetPath" -ForegroundColor Yellow

    $matchedFiles = Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force |
        Where-Object { $_.Name -like ("*" + $conflictMarker + "*") } |
        Sort-Object FullName

    $backupPath = Join-Path -Path $TargetPath -ChildPath "backup"
    $allBackupFiles = @()
    $backupFilesToKeep = @()
    $backupFilesToRemove = @()

    if (Test-Path -LiteralPath $backupPath -PathType Container) {
        $allBackupFiles = Get-ChildItem -LiteralPath $backupPath -File -Force |
            Sort-Object Name -Descending

        if (@($allBackupFiles).Count -gt 3) {
            $backupFilesToKeep = @($allBackupFiles | Select-Object -First 3)
            $backupFilesToRemove = @($allBackupFiles | Select-Object -Skip 3)
        }
        else {
            $backupFilesToKeep = @($allBackupFiles)
        }
    }

    $count = @($matchedFiles).Count
    $backupRemoveCount = @($backupFilesToRemove).Count
    $totalCandidates = $count + $backupRemoveCount

    if ($totalCandidates -eq 0) {
        Write-Host ("No files found with marker: {0}" -f $conflictMarker) -ForegroundColor Green
        if (Test-Path -LiteralPath $backupPath -PathType Container) {
            Write-Host ("Backup files are already within limit. Current count kept: {0}" -f @($backupFilesToKeep).Count) -ForegroundColor Green
        }
        return
    }

    Write-Host ""
    if ($count -gt 0) {
        Write-Host ("Conflict files containing marker: {0}" -f $conflictMarker) -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        foreach ($file in $matchedFiles) {
            Write-Host $file.FullName
        }
        Write-Host "----------------------------------------"
        Write-Host ("Total conflict files found: {0}" -f $count) -ForegroundColor Yellow
        Write-Host ""
    }

    if (Test-Path -LiteralPath $backupPath -PathType Container) {
        Write-Host "Backup cleanup plan:" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        Write-Host ("Backup folder: {0}" -f $backupPath)
        Write-Host ("Backup files to keep: {0}" -f @($backupFilesToKeep).Count) -ForegroundColor Green
        foreach ($file in $backupFilesToKeep) {
            Write-Host ("KEEP   {0}" -f $file.Name) -ForegroundColor Green
        }
        Write-Host ("Backup files to delete: {0}" -f $backupRemoveCount) -ForegroundColor Yellow
        foreach ($file in $backupFilesToRemove) {
            Write-Host ("REMOVE {0}" -f $file.FullName)
        }
        Write-Host "----------------------------------------"
        Write-Host ""
    }

    $confirmation = (Read-Host "Delete all listed files permanently and keep only the newest 3 backup files? Type Y to continue, anything else to cancel").Trim()

    if ($confirmation -cnotmatch '^[Yy]$') {
        Write-Host "Cancelled. No files were changed." -ForegroundColor Green
        return
    }

    $conflictMovedCount = 0
    $backupMovedCount = 0
    $failedCount = 0

    foreach ($file in $matchedFiles) {
        try {
            Remove-FilePermanently -FilePath $file.FullName
            Write-Host ("Deleted: {0}" -f $file.FullName) -ForegroundColor DarkYellow
            $conflictMovedCount++
        }
        catch {
            Write-Host ("Failed: {0}" -f $file.FullName) -ForegroundColor Red
            Write-Host ("Reason: {0}" -f $_.Exception.Message) -ForegroundColor Red
            $failedCount++
        }
    }

    foreach ($file in $backupFilesToRemove) {
        try {
            Remove-FilePermanently -FilePath $file.FullName
            Write-Host ("Deleted old backup: {0}" -f $file.FullName) -ForegroundColor DarkYellow
            $backupMovedCount++
        }
        catch {
            Write-Host ("Failed: {0}" -f $file.FullName) -ForegroundColor Red
            Write-Host ("Reason: {0}" -f $_.Exception.Message) -ForegroundColor Red
            $failedCount++
        }
    }

    $movedCount = $conflictMovedCount + $backupMovedCount

    Write-Host ""
    Write-Host "Done." -ForegroundColor Cyan
    Write-Host ("Conflict files deleted successfully: {0}" -f $conflictMovedCount) -ForegroundColor Green
    Write-Host ("Old backup files deleted successfully: {0}" -f $backupMovedCount) -ForegroundColor Green
    Write-Host ("Total deleted successfully: {0}" -f $movedCount) -ForegroundColor Green
    Write-Host ("Failed to delete: {0}" -f $failedCount) -ForegroundColor Yellow

    if (@($backupFilesToKeep).Count -gt 0) {
        Write-Host ("Newest backup files kept: {0}" -f @($backupFilesToKeep).Count) -ForegroundColor Green
    }

    if ($movedCount -gt 0 -and $failedCount -eq 0) {
        Write-Host "Cleanup completed successfully. Files were deleted permanently." -ForegroundColor Green
    }
    elseif ($movedCount -gt 0) {
        Write-Host "Cleanup finished, but some files failed to delete." -ForegroundColor Yellow
    }
}
catch {
    Write-Host ("Unexpected error: {0}" -f $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
}
finally {
    Write-Host ""
    Read-Host "Press Enter to close this window" | Out-Null
    exit $exitCode
}
