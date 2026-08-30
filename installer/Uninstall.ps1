#Requires -Version 5.1
<#
.SYNOPSIS
    Removes AutoGitHub install: scheduled task, shortcuts, and app folder.
.EXAMPLE
    .\installer\Uninstall.ps1
.EXAMPLE
    & "$env:LOCALAPPDATA\AutoGitHub\installer\Uninstall.ps1" -KeepData
#>
[CmdletBinding()]
param(
    [string]$InstallDir,
    [switch]$KeepData,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $InstallDir) {
    $candidate = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    if (Test-Path -LiteralPath (Join-Path $candidate 'run.ps1')) {
        $InstallDir = $candidate
    } else {
        $InstallDir = Join-Path $env:LOCALAPPDATA 'AutoGitHub'
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $InstallDir 'run.ps1'))) {
    throw "AutoGitHub not found at: $InstallDir"
}

$InstallDir = (Resolve-Path -LiteralPath $InstallDir).Path
$manifestPath = Join-Path $InstallDir 'install-manifest.json'
$manifest = $null
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

Write-Host 'AutoGitHub Uninstaller'
Write-Host "Target: $InstallDir"

if (-not $NonInteractive) {
    $confirm = Read-Host 'Remove AutoGitHub (task, shortcuts, and app files)? (Y/N)'
    if ($confirm -notmatch '^[Yy]') {
        Write-Host 'Uninstall cancelled.'
        exit 1
    }
}

$taskName = $null
if ($manifest -and $manifest.taskName) {
    $taskName = [string]$manifest.taskName
} elseif (-not $manifest) {
    $taskName = 'AutoGitHub Daily Run'
}

if ($taskName) {
    try {
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "Removed scheduled task: $taskName"
        } else {
            Write-Host "Scheduled task not found: $taskName"
        }
    } catch {
        Write-Warning "Could not remove scheduled task '$taskName': $_"
    }
} else {
    Write-Host 'No scheduled task recorded in install manifest (skipped).'
}

$startMenuDir = if ($manifest -and $manifest.startMenuDir) {
    [string]$manifest.startMenuDir
} else {
    Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AutoGitHub'
}
if (Test-Path -LiteralPath $startMenuDir) {
    Remove-Item -LiteralPath $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed Start Menu folder: $startMenuDir"
}

$shortcutCandidates = @()
if ($manifest -and $manifest.desktopShortcut) { $shortcutCandidates += [string]$manifest.desktopShortcut }
if ($manifest -and $manifest.startupShortcut) { $shortcutCandidates += [string]$manifest.startupShortcut }
$shortcutCandidates += @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'AutoGitHub.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Startup')) 'AutoGitHub.lnk')
) | Select-Object -Unique

foreach ($sc in $shortcutCandidates) {
    if ($sc -and (Test-Path -LiteralPath $sc)) {
        Remove-Item -LiteralPath $sc -Force -ErrorAction SilentlyContinue
        Write-Host "Removed shortcut: $sc"
    }
}

if ($KeepData) {
    $keep = @('config\settings.json', 'data', 'logs')
    $backup = Join-Path $env:LOCALAPPDATA ("AutoGitHub-backup-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($rel in $keep) {
        $src = Join-Path $InstallDir $rel
        if (Test-Path -LiteralPath $src) {
            $dst = Join-Path $backup $rel
            $dstParent = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $dstParent)) {
                New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
            }
            Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        }
    }
    Write-Host "Kept a copy of config/data/logs at: $backup"
}

# If uninstall script lives inside InstallDir, schedule delayed self-delete
$removeScript = @"
Start-Sleep -Seconds 1
Remove-Item -LiteralPath '$($InstallDir -replace "'", "''")' -Recurse -Force -ErrorAction SilentlyContinue
"@
$tempPs1 = Join-Path $env:TEMP ("AutoGitHub-uninstall-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
Set-Content -LiteralPath $tempPs1 -Value $removeScript -Encoding UTF8

Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $tempPs1
) -WindowStyle Hidden | Out-Null

Write-Host ''
Write-Host 'Uninstall started. App folder will be removed momentarily.' -ForegroundColor Green
Write-Host "If anything remains, delete manually: $InstallDir"
