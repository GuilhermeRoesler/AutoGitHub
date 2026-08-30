#Requires -Version 5.1
<#
.SYNOPSIS
    Lightweight unit tests for the UTC daily guard (no Pester required).
.DESCRIPTION
    Run: powershell -NoProfile -File tests/VerifyDate.Tests.ps1
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Import-Module (Join-Path $root 'src\AutoGitHub.psm1') -Force

$failed = 0
$passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        Write-Host "PASS  $Name"
        $script:passed++
    } else {
        Write-Host "FAIL  $Name"
        $script:failed++
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autogithub-tests-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $tracker = Join-Path $tempRoot 'last_update.txt'

    # First run: missing tracker => should run
    $r1 = Test-ShouldRunToday -DateTrackerPath $tracker -Today '2026-08-30'
    Assert-True ($r1.ShouldRun -eq $true) 'first-run ShouldRun=true'
    Assert-True ($r1.Reason -eq 'first-run') 'first-run reason'

    # Same day => skip
    Set-Content -LiteralPath $tracker -Value '2026-08-30' -Encoding UTF8 -NoNewline
    $r2 = Test-ShouldRunToday -DateTrackerPath $tracker -Today '2026-08-30'
    Assert-True ($r2.ShouldRun -eq $false) 'same-day ShouldRun=false'
    Assert-True ($r2.Reason -eq 'already-ran-today') 'same-day reason'

    # New day => run
    $r3 = Test-ShouldRunToday -DateTrackerPath $tracker -Today '2026-08-31'
    Assert-True ($r3.ShouldRun -eq $true) 'new-day ShouldRun=true'
    Assert-True ($r3.Reason -eq 'new-day') 'new-day reason'

    # Legacy locale date => migrate/run
    Set-Content -LiteralPath $tracker -Value '30/08/2026' -Encoding UTF8 -NoNewline
    $r4 = Test-ShouldRunToday -DateTrackerPath $tracker -Today '2026-08-30'
    Assert-True ($r4.ShouldRun -eq $true) 'legacy-date ShouldRun=true'
    Assert-True ($r4.Reason -eq 'legacy-date-format') 'legacy-date reason'

    # Update-LastRunDate writes ISO
    Update-LastRunDate -DateTrackerPath $tracker -Today '2026-09-01'
    $stored = (Get-Content -LiteralPath $tracker -Raw).Trim()
    Assert-True ($stored -eq '2026-09-01') 'Update-LastRunDate writes ISO date'

    # Dry-run does not write
    Update-LastRunDate -DateTrackerPath $tracker -Today '2026-09-02' -DryRun
    $stored2 = (Get-Content -LiteralPath $tracker -Raw).Trim()
    Assert-True ($stored2 -eq '2026-09-01') 'Update-LastRunDate -DryRun leaves file unchanged'

    # Get-UtcTodayString format
    $today = Get-UtcTodayString
    Assert-True ($today -match '^\d{4}-\d{2}-\d{2}$') 'Get-UtcTodayString is yyyy-MM-dd'

    # Append-DailyNote is idempotent per day
    $notes = Join-Path $tempRoot 'notes.md'
    $a1 = Add-DailyNote -Path $notes -Today '2026-08-30'
    $a2 = Add-DailyNote -Path $notes -Today '2026-08-30'
    Assert-True ($a1 -eq $true) 'Add-DailyNote first call writes'
    Assert-True ($a2 -eq $false) 'Add-DailyNote second call same day is no-op'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Passed: $passed  Failed: $failed"
if ($failed -gt 0) { exit 1 }
exit 0
