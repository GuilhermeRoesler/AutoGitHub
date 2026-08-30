#Requires -Version 5.1
<#
.SYNOPSIS
    Registers a daily Task Scheduler job with an explicit WorkingDirectory.
#>
[CmdletBinding()]
param(
    [string]$Time = '09:00',
    [string]$TaskName = 'AutoGitHub Daily Run'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $root 'run.ps1'))) {
    $root = (Get-Location).Path
}

Import-Module (Join-Path $root 'src\AutoGitHub.psm1') -Force
Register-AutoGitHubScheduledTask -Root $root -TaskName $TaskName -Time $Time
