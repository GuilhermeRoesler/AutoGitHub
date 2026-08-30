#Requires -Version 5.1
<#
.SYNOPSIS
    AutoGitHub entry point — runs at most once per UTC day.
.PARAMETER DryRun
    Log intended git actions without executing them.
.PARAMETER Force
    Ignore the daily guard and run anyway.
.PARAMETER ForcePushInit
    Allow force push only during first-time repo init (destructive).
.PARAMETER ConfigPath
    Optional path to settings.json.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$ForcePushInit,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $root

$modulePath = Join-Path $root 'src\AutoGitHub.psm1'
Import-Module $modulePath -Force

try {
    $config = Get-AutoGitHubConfig -Root $root -ConfigPath $ConfigPath -DryRun:$DryRun
    Write-AutoGitHubLog -Config $config -Message 'AutoGitHub started'

    $gitDir = Join-Path $root '.git'
    if (-not (Test-Path -LiteralPath $gitDir)) {
        Write-AutoGitHubLog -Config $config -Message 'Repository not initialized. Running initialization...'
        Initialize-AutoGitHubRepo -Config $config -ForcePush:$ForcePushInit
    }

    $decision = Test-ShouldRunToday -DateTrackerPath $config._dateTrackerPath
    if ($Force) {
        Write-AutoGitHubLog -Config $config -Level WARN -Message 'Force flag set — bypassing daily guard.'
        $decision = [pscustomobject]@{
            ShouldRun   = $true
            Reason      = 'forced'
            LastRunDate = $decision.LastRunDate
            Today       = $decision.Today
        }
    }

    if (-not $decision.ShouldRun) {
        Write-AutoGitHubLog -Config $config -Message (
            "Already ran today (Last: $($decision.LastRunDate), Today UTC: $($decision.Today)). Skipping."
        )
        exit 0
    }

    Write-AutoGitHubLog -Config $config -Message (
        "Run approved (reason=$($decision.Reason); last=$($decision.LastRunDate); today=$($decision.Today))"
    )

    $count = 1
    if ($config.contentMode -eq 'synthetic') {
        $count = Get-Random -Minimum 1 -Maximum ($config.maxCommits + 1)
    }

    Write-AutoGitHubLog -Config $config -Message "Running with $count commit(s) [mode=$($config.contentMode)]"
    $null = Invoke-AutoGitHubCommits -Config $config -CommitCount $count
    Update-LastRunDate -DateTrackerPath $config._dateTrackerPath -Today $decision.Today -DryRun:$config.dryRun

    Write-AutoGitHubLog -Config $config -Message 'AutoGitHub completed successfully.'
    exit 0
}
catch {
    $msg = $_.Exception.Message
    if (Get-Variable -Name config -ErrorAction SilentlyContinue) {
        Write-AutoGitHubLog -Config $config -Level ERROR -Message $msg
    } else {
        Write-Host "[ERROR] $msg"
    }
    exit 1
}
