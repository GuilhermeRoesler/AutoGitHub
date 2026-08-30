#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive setup: writes config/settings.json and optional scheduled task.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $root 'run.ps1'))) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not (Test-Path (Join-Path $root 'run.ps1'))) {
        $root = (Get-Location).Path
    }
}

Set-Location -LiteralPath $root
Import-Module (Join-Path $root 'src\AutoGitHub.psm1') -Force

$examplePath = Join-Path $root 'config\settings.example.json'
$settingsPath = Join-Path $root 'config\settings.json'

Write-Host 'Welcome to AutoGitHub Setup'
Write-Host ''

if (-not (Test-Path -LiteralPath $examplePath)) {
    throw "Missing $examplePath"
}

$template = Get-Content -LiteralPath $examplePath -Raw -Encoding UTF8 | ConvertFrom-Json

$githubUrl = Read-Host 'GitHub repository URL'
if ([string]::IsNullOrWhiteSpace($githubUrl)) {
    throw 'githubUrl is required'
}

$branch = Read-Host "Branch name [$($template.branch)]"
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = $template.branch }

$maxRaw = Read-Host "Max commits per day for synthetic mode [$($template.maxCommits)]"
$maxCommits = $template.maxCommits
if (-not [string]::IsNullOrWhiteSpace($maxRaw)) { $maxCommits = [int]$maxRaw }

$mode = Read-Host "Content mode: notes|synthetic [$($template.contentMode)]"
if ([string]::IsNullOrWhiteSpace($mode)) { $mode = $template.contentMode }
if ($mode -notin @('notes', 'synthetic')) {
    throw "Invalid contentMode: $mode"
}

$cfg = [ordered]@{
    githubUrl      = $githubUrl.Trim()
    branch         = $branch.Trim()
    commitFile     = $template.commitFile
    maxCommits     = $maxCommits
    dateTracker    = $template.dateTracker
    enableLogging  = $true
    logFile        = $template.logFile
    commitMessages = @($template.commitMessages)
    contentMode    = $mode
    notesFile      = $template.notesFile
    dryRun         = $false
    allowForcePush = $false
}

$configDir = Join-Path $root 'config'
if (-not (Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

($cfg | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $settingsPath -Encoding UTF8
Write-Host "Wrote $settingsPath"

foreach ($d in @('data', 'logs')) {
    $p = Join-Path $root $d
    if (-not (Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }
}

$notes = Join-Path $root $cfg.notesFile
if (-not (Test-Path -LiteralPath $notes)) {
    Copy-Item (Join-Path $root 'data\notes.md') $notes -ErrorAction SilentlyContinue
}

$answer = Read-Host 'Schedule a daily task at 09:00? (Y/N)'
if ($answer -match '^[Yy]') {
    & (Join-Path $root 'src\Register-Schedule.ps1')
}

Write-Host ''
Write-Host 'Setup complete. Run: .\run.ps1   (or run.bat)'
Write-Host 'Tip: prefer contentMode "notes" and edit data/notes.md with real updates.'
