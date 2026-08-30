#Requires -Version 5.1
<#
.SYNOPSIS
    Installs AutoGitHub to a local folder, creates shortcuts, and registers the daily task.
.DESCRIPTION
    Default install path: %LOCALAPPDATA%\AutoGitHub (no admin required).
    Copies application files (without .git), writes config, Start Menu shortcuts,
    optional Desktop / Startup shortcuts, and a scheduled task.
.EXAMPLE
    .\installer\Install.ps1
.EXAMPLE
    .\installer\Install.ps1 -GitHubUrl 'https://github.com/you/notes.git' -NonInteractive
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'AutoGitHub'),
    [string]$GitHubUrl,
    [string]$Branch,
    [ValidateSet('notes', 'synthetic')]
    [string]$ContentMode = 'notes',
    [int]$MaxCommits = 5,
    [string]$ScheduleTime = '09:00',
    [string]$TaskName = 'AutoGitHub Daily Run',
    [switch]$CreateDesktopShortcut,
    [switch]$CreateStartupShortcut,
    [switch]$SkipSchedule,
    [switch]$NonInteractive,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'run.ps1'))) {
    throw "Could not locate AutoGitHub repo root from installer path."
}

$installMarker = Join-Path $InstallDir 'install-manifest.json'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AutoGitHub'
$desktopDir = [Environment]::GetFolderPath('Desktop')
$startupDir = [Environment]::GetFolderPath('Startup')

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function New-Shortcut {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$Arguments = '',
        [string]$WorkingDirectory = '',
        [string]$Description = 'AutoGitHub',
        [string]$IconLocation = ''
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($Path)
    $sc.TargetPath = $TargetPath
    $sc.Arguments = $Arguments
    if ($WorkingDirectory) { $sc.WorkingDirectory = $WorkingDirectory }
    $sc.Description = $Description
    if ($IconLocation) { $sc.IconLocation = $IconLocation }
    $sc.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
}

function Copy-AppFiles {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$DestinationRoot
    )

    $relativePaths = @(
        'run.ps1',
        'run.bat',
        'init_on_startup.vbs',
        'LICENSE',
        'README.md',
        '.gitignore',
        'config\settings.example.json',
        'data\.gitkeep',
        'data\notes.md',
        'src\AutoGitHub.psm1',
        'src\Setup.ps1',
        'src\Register-Schedule.ps1',
        'tests\VerifyDate.Tests.ps1',
        'installer\Install.ps1',
        'installer\Uninstall.ps1'
    )

    foreach ($rel in $relativePaths) {
        $src = Join-Path $SourceRoot $rel
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Warning "Missing source file (skipped): $rel"
            continue
        }
        $dst = Join-Path $DestinationRoot $rel
        $dstDir = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }

    foreach ($dirName in @('data', 'logs', 'config')) {
        $dir = Join-Path $DestinationRoot $dirName
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

function Get-InstallConfigAnswers {
    param(
        [string]$ExamplePath,
        [string]$ExistingSettingsPath,
        [string]$ParamGitHubUrl,
        [string]$ParamBranch,
        [string]$ParamContentMode,
        [int]$ParamMaxCommits,
        [bool]$IsNonInteractive,
        [bool]$ContentModeSpecified,
        [bool]$MaxCommitsSpecified
    )

    $template = Get-Content -LiteralPath $ExamplePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $existing = $null
    if (Test-Path -LiteralPath $ExistingSettingsPath) {
        $existing = Get-Content -LiteralPath $ExistingSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    $defaultUrl = if ($ParamGitHubUrl) {
        $ParamGitHubUrl
    } elseif ($existing -and $existing.githubUrl) {
        [string]$existing.githubUrl
    } else {
        [string]$template.githubUrl
    }

    $defaultBranch = if ($ParamBranch) {
        $ParamBranch
    } elseif ($existing -and $existing.branch) {
        [string]$existing.branch
    } else {
        [string]$template.branch
    }

    $defaultMode = if ($ContentModeSpecified -or $IsNonInteractive) {
        $ParamContentMode
    } elseif ($existing -and $existing.contentMode) {
        [string]$existing.contentMode
    } else {
        [string]$template.contentMode
    }

    $defaultMax = if ($MaxCommitsSpecified -or $IsNonInteractive) {
        $ParamMaxCommits
    } elseif ($existing -and $null -ne $existing.maxCommits) {
        [int]$existing.maxCommits
    } else {
        [int]$template.maxCommits
    }

    if ($IsNonInteractive) {
        if ([string]::IsNullOrWhiteSpace($defaultUrl) -or $defaultUrl -match 'YOUR_USER') {
            throw 'NonInteractive install requires -GitHubUrl with a real repository URL.'
        }
        return [pscustomobject]@{
            githubUrl   = $defaultUrl.Trim()
            branch      = $defaultBranch.Trim()
            contentMode = $defaultMode
            maxCommits  = $defaultMax
            template    = $template
        }
    }

    Write-Host 'Configure AutoGitHub'
    Write-Host ''

    $urlPrompt = if ($defaultUrl -and $defaultUrl -notmatch 'YOUR_USER') {
        "GitHub repository URL [$defaultUrl]"
    } else {
        'GitHub repository URL'
    }
    $urlIn = Read-Host $urlPrompt
    if ([string]::IsNullOrWhiteSpace($urlIn)) { $urlIn = $defaultUrl }
    if ([string]::IsNullOrWhiteSpace($urlIn) -or $urlIn -match 'YOUR_USER') {
        throw 'githubUrl is required (use a real repository URL).'
    }

    $branchIn = Read-Host "Branch name [$defaultBranch]"
    if ([string]::IsNullOrWhiteSpace($branchIn)) { $branchIn = $defaultBranch }

    $modeIn = Read-Host "Content mode: notes|synthetic [$defaultMode]"
    if ([string]::IsNullOrWhiteSpace($modeIn)) { $modeIn = $defaultMode }
    if ($modeIn -notin @('notes', 'synthetic')) {
        throw "Invalid contentMode: $modeIn"
    }

    $maxIn = Read-Host "Max commits/day for synthetic mode [$defaultMax]"
    $maxVal = $defaultMax
    if (-not [string]::IsNullOrWhiteSpace($maxIn)) { $maxVal = [int]$maxIn }

    return [pscustomobject]@{
        githubUrl   = $urlIn.Trim()
        branch      = $branchIn.Trim()
        contentMode = $modeIn
        maxCommits  = $maxVal
        template    = $template
    }
}

function Write-SettingsJson {
    param(
        [Parameter(Mandatory)]$Answers,
        [Parameter(Mandatory)][string]$SettingsPath
    )

    $t = $Answers.template
    $cfg = [ordered]@{
        githubUrl      = $Answers.githubUrl
        branch         = $Answers.branch
        commitFile     = $t.commitFile
        maxCommits     = $Answers.maxCommits
        dateTracker    = $t.dateTracker
        enableLogging  = $true
        logFile        = $t.logFile
        commitMessages = @($t.commitMessages)
        contentMode    = $Answers.contentMode
        notesFile      = $t.notesFile
        dryRun         = $false
        allowForcePush = $false
    }

    $dir = Split-Path -Parent $SettingsPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    ($cfg | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
}

# --- main ---

Write-Host 'AutoGitHub Installer'
Write-Host "Source : $repoRoot"
Write-Host "Target : $InstallDir"

if ((Test-Path -LiteralPath $InstallDir) -and -not $Force) {
    if ($NonInteractive) {
        Write-Host "Install directory exists - upgrading in place (-Force not required for NonInteractive upgrade)."
    } else {
        $overwrite = Read-Host "Install directory already exists. Upgrade / overwrite app files? (Y/N)"
        if ($overwrite -notmatch '^[Yy]') {
            Write-Host 'Install cancelled.'
            exit 1
        }
    }
}

Write-Step "Copying files to $InstallDir"
if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Copy-AppFiles -SourceRoot $repoRoot -DestinationRoot $InstallDir

$examplePath = Join-Path $InstallDir 'config\settings.example.json'
$settingsPath = Join-Path $InstallDir 'config\settings.json'
$answers = Get-InstallConfigAnswers `
    -ExamplePath $examplePath `
    -ExistingSettingsPath $settingsPath `
    -ParamGitHubUrl $GitHubUrl `
    -ParamBranch $Branch `
    -ParamContentMode $ContentMode `
    -ParamMaxCommits $MaxCommits `
    -IsNonInteractive:([bool]$NonInteractive) `
    -ContentModeSpecified:($PSBoundParameters.ContainsKey('ContentMode')) `
    -MaxCommitsSpecified:($PSBoundParameters.ContainsKey('MaxCommits'))

Write-Step 'Writing configuration'
Write-SettingsJson -Answers $answers -SettingsPath $settingsPath
Write-Host "Wrote $settingsPath"

$modulePath = Join-Path $InstallDir 'src\AutoGitHub.psm1'
Import-Module $modulePath -Force

$scheduled = $false
if (-not $SkipSchedule) {
    $doSchedule = $true
    if (-not $NonInteractive) {
        $ans = Read-Host "Register daily scheduled task at ${ScheduleTime}? (Y/N)"
        $doSchedule = ($ans -match '^[Yy]')
    }
    if ($doSchedule) {
        Write-Step "Registering scheduled task '$TaskName'"
        Register-AutoGitHubScheduledTask -Root $InstallDir -TaskName $TaskName -Time $ScheduleTime
        $scheduled = $true
    }
}

Write-Step 'Creating Start Menu shortcuts'
$runBat = Join-Path $InstallDir 'run.bat'
$setupPs1 = Join-Path $InstallDir 'src\Setup.ps1'
$uninstallPs1 = Join-Path $InstallDir 'installer\Uninstall.ps1'
$pwsh = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

New-Shortcut -Path (Join-Path $startMenuDir 'AutoGitHub.lnk') `
    -TargetPath $runBat `
    -WorkingDirectory $InstallDir `
    -Description 'Run AutoGitHub once'

New-Shortcut -Path (Join-Path $startMenuDir 'AutoGitHub Setup.lnk') `
    -TargetPath $pwsh `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$setupPs1`"" `
    -WorkingDirectory $InstallDir `
    -Description 'Reconfigure AutoGitHub'

New-Shortcut -Path (Join-Path $startMenuDir 'Uninstall AutoGitHub.lnk') `
    -TargetPath $pwsh `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$uninstallPs1`"" `
    -WorkingDirectory $InstallDir `
    -Description 'Uninstall AutoGitHub'

$desktopShortcut = $null
$wantDesktop = $CreateDesktopShortcut
if (-not $NonInteractive -and -not $CreateDesktopShortcut) {
    $ans = Read-Host 'Create Desktop shortcut? (Y/N)'
    $wantDesktop = ($ans -match '^[Yy]')
}
if ($wantDesktop) {
    $desktopShortcut = Join-Path $desktopDir 'AutoGitHub.lnk'
    New-Shortcut -Path $desktopShortcut `
        -TargetPath $runBat `
        -WorkingDirectory $InstallDir `
        -Description 'Run AutoGitHub once'
    Write-Host "Desktop shortcut: $desktopShortcut"
}

$startupShortcut = $null
$wantStartup = $CreateStartupShortcut
if (-not $NonInteractive -and -not $CreateStartupShortcut) {
    $ans = Read-Host 'Also launch hidden at Windows logon (Startup folder)? (Y/N)'
    $wantStartup = ($ans -match '^[Yy]')
}
if ($wantStartup) {
    $vbs = Join-Path $InstallDir 'init_on_startup.vbs'
    $startupShortcut = Join-Path $startupDir 'AutoGitHub.lnk'
    New-Shortcut -Path $startupShortcut `
        -TargetPath $vbs `
        -WorkingDirectory $InstallDir `
        -Description 'AutoGitHub hidden startup launcher'
    Write-Host "Startup shortcut: $startupShortcut"
}

$manifest = [ordered]@{
    version          = '1.0'
    installedAtUtc   = [DateTime]::UtcNow.ToString('o')
    installDir       = $InstallDir
    taskName         = if ($scheduled) { $TaskName } else { $null }
    scheduleTime     = if ($scheduled) { $ScheduleTime } else { $null }
    startMenuDir     = $startMenuDir
    desktopShortcut  = $desktopShortcut
    startupShortcut  = $startupShortcut
    githubUrl        = $answers.githubUrl
}
($manifest | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $installMarker -Encoding UTF8

$runPs1Path = Join-Path $InstallDir 'run.ps1'
Write-Host ''
Write-Host 'Installation complete.' -ForegroundColor Green
Write-Host "  App folder : $InstallDir"
Write-Host "  Config     : $settingsPath"
if ($scheduled) {
    Write-Host "  Task       : $TaskName daily at $ScheduleTime"
}
Write-Host "  Start Menu : $startMenuDir"
Write-Host ''
Write-Host 'Next: ensure Git can push to your repo, then run AutoGitHub from the Start Menu'
Write-Host ("      or run: {0}" -f $runPs1Path)
Write-Host 'Uninstall: Start Menu -> Uninstall AutoGitHub'
Write-Host ("       or run: {0}" -f $uninstallPs1)
