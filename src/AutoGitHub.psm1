#Requires -Version 5.1
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Core AutoGitHub helpers: config, date guard, commits, init, logging.
#>

function Get-AutoGitHubRoot {
    param([string]$StartPath = $PSScriptRoot)
    $dir = Resolve-Path -LiteralPath $StartPath
    if ((Split-Path -Leaf $dir) -eq 'src') {
        return (Resolve-Path (Join-Path $dir '..')).Path
    }
    return $dir.Path
}

function Resolve-AutoGitHubPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-UtcTodayString {
    return [DateTime]::UtcNow.ToString('yyyy-MM-dd')
}

function Write-AutoGitHubLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [hashtable]$Config,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $stamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $line = "[$stamp] [$Level] $Message"
    Write-Host $line
    if ($Config -and $Config.enableLogging -and $Config.logFile) {
        $logPath = $Config._logPath
        if (-not $logPath) { return }
        $logDir = Split-Path -Parent $logPath
        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    }
}

function Get-AutoGitHubConfig {
    <#
    .SYNOPSIS
        Loads settings.json (or example) and resolves absolute paths.
    #>
    param(
        [string]$Root = (Get-AutoGitHubRoot),
        [string]$ConfigPath,
        [switch]$DryRun
    )

    if (-not $ConfigPath) {
        $preferred = Join-Path $Root 'config\settings.json'
        $example = Join-Path $Root 'config\settings.example.json'
        if (Test-Path -LiteralPath $preferred) {
            $ConfigPath = $preferred
        } elseif (Test-Path -LiteralPath $example) {
            $ConfigPath = $example
        } else {
            throw "No config found. Copy config/settings.example.json to config/settings.json"
        }
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $config = @{
        githubUrl       = [string]$raw.githubUrl
        branch          = if ($raw.branch) { [string]$raw.branch } else { 'main' }
        commitFile      = if ($raw.commitFile) { [string]$raw.commitFile } else { 'data/commit_data.txt' }
        maxCommits      = if ($null -ne $raw.maxCommits) { [int]$raw.maxCommits } else { 5 }
        dateTracker     = if ($raw.dateTracker) { [string]$raw.dateTracker } else { 'data/last_update.txt' }
        enableLogging   = if ($null -ne $raw.enableLogging) { [bool]$raw.enableLogging } else { $true }
        logFile         = if ($raw.logFile) { [string]$raw.logFile } else { 'logs/autogithub.log' }
        commitMessages  = @()
        contentMode     = if ($raw.contentMode) { [string]$raw.contentMode } else { 'notes' }
        notesFile       = if ($raw.notesFile) { [string]$raw.notesFile } else { 'data/notes.md' }
        dryRun          = if ($DryRun) { $true } elseif ($null -ne $raw.dryRun) { [bool]$raw.dryRun } else { $false }
        allowForcePush  = if ($null -ne $raw.allowForcePush) { [bool]$raw.allowForcePush } else { $false }
        _root           = $Root
        _configPath     = $ConfigPath
    }

    if ($raw.commitMessages) {
        $config.commitMessages = @($raw.commitMessages | ForEach-Object { [string]$_ })
    }
    if ($config.commitMessages.Count -eq 0) {
        $config.commitMessages = @('chore: daily workspace sync')
    }
    if ($config.maxCommits -lt 1) { $config.maxCommits = 1 }

    $config._commitFilePath  = Resolve-AutoGitHubPath -Root $Root -Path $config.commitFile
    $config._dateTrackerPath = Resolve-AutoGitHubPath -Root $Root -Path $config.dateTracker
    $config._logPath         = Resolve-AutoGitHubPath -Root $Root -Path $config.logFile
    $config._notesPath       = Resolve-AutoGitHubPath -Root $Root -Path $config.notesFile

    foreach ($dir in @(
        (Split-Path -Parent $config._commitFilePath),
        (Split-Path -Parent $config._dateTrackerPath),
        (Split-Path -Parent $config._logPath),
        (Split-Path -Parent $config._notesPath)
    )) {
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    return $config
}

function Test-ShouldRunToday {
    <#
    .SYNOPSIS
        Returns whether AutoGitHub should run based on UTC date tracker.
        First run (missing tracker) always returns $true and does not skip.
    #>
    param(
        [Parameter(Mandatory)][string]$DateTrackerPath,
        [string]$Today = (Get-UtcTodayString)
    )

    if (-not (Test-Path -LiteralPath $DateTrackerPath)) {
        return [pscustomobject]@{
            ShouldRun   = $true
            Reason      = 'first-run'
            LastRunDate = $null
            Today       = $Today
        }
    }

    $last = (Get-Content -LiteralPath $DateTrackerPath -TotalCount 1 -ErrorAction Stop).Trim()
    # Accept legacy locale dates as "unknown / run once more", then rewrite ISO
    if ($last -notmatch '^\d{4}-\d{2}-\d{2}$') {
        return [pscustomobject]@{
            ShouldRun   = $true
            Reason      = 'legacy-date-format'
            LastRunDate = $last
            Today       = $Today
        }
    }

    if ($last -eq $Today) {
        return [pscustomobject]@{
            ShouldRun   = $false
            Reason      = 'already-ran-today'
            LastRunDate = $last
            Today       = $Today
        }
    }

    return [pscustomobject]@{
        ShouldRun   = $true
        Reason      = 'new-day'
        LastRunDate = $last
        Today       = $Today
    }
}

function Update-LastRunDate {
    param(
        [Parameter(Mandatory)][string]$DateTrackerPath,
        [string]$Today = (Get-UtcTodayString),
        [switch]$DryRun
    )
    if ($DryRun) { return }
    Set-Content -LiteralPath $DateTrackerPath -Value $Today -Encoding UTF8 -NoNewline
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$WorkingDirectory,
        [switch]$DryRun,
        [hashtable]$Config
    )

    $display = 'git ' + ($Arguments -join ' ')
    if ($DryRun) {
        Write-AutoGitHubLog -Config $Config -Message "DRY-RUN: $display"
        return 0
    }

    $prev = $PWD
    try {
        if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
        & git @Arguments
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        if ($code -ne 0) {
            throw "Command failed (exit $code): $display"
        }
        return $code
    }
    finally {
        Set-Location -LiteralPath $prev.Path
    }
}

function Get-RandomCommitMessage {
    param([hashtable]$Config, [int]$Index, [int]$Total)
    $pool = $Config.commitMessages
    $pick = $pool[(Get-Random -Maximum $pool.Count)]
    return "$pick ($Index/$Total)"
}

function Write-SyntheticCommitContent {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Index,
        [int]$Total
    )
    $stamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $body = @"
# AutoGitHub synthetic marker
index: $Index / $Total
utc: $stamp
"@
    Set-Content -LiteralPath $Path -Value $body -Encoding UTF8
}

function Initialize-NotesFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        @"
# AutoGitHub notes

$(Get-UtcTodayString) - started tracking notes.
"@ | Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

function Add-DailyNote {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Today = (Get-UtcTodayString)
    )
    Initialize-NotesFile -Path $Path
    $marker = "<!-- autogithub:$Today -->"
    $existing = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($existing -and $existing.Contains($marker)) {
        return $false
    }
    $line = "`r`n$marker`r`n- $Today - daily note / status update`r`n"
    Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
    return $true
}

function Initialize-AutoGitHubRepo {
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [switch]$ForcePush
    )

    $root = $Config._root
    $gitDir = Join-Path $root '.git'

    if (Test-Path -LiteralPath $gitDir) {
        Write-AutoGitHubLog -Config $Config -Message 'Repository already initialized.'
        return
    }

    if (-not $Config.githubUrl -or $Config.githubUrl -match 'YOUR_USER') {
        throw 'Set a real githubUrl in config/settings.json before initializing.'
    }

    Write-AutoGitHubLog -Config $Config -Message 'Initializing git repository...'
    Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @('init')

    $readme = Join-Path $root 'README.md'
    if (-not (Test-Path -LiteralPath $readme)) {
        if (-not $Config.dryRun) {
            @"
# AutoGitHub

Automated workspace sync helper.
Created on $(Get-UtcTodayString) (UTC).
"@ | Set-Content -LiteralPath $readme -Encoding UTF8
        }
    }

    # Stage intentional project files only - never blind git add .
    $toAdd = @(
        'README.md', 'LICENSE', '.gitignore', 'run.ps1', 'run.bat', 'install.bat',
        'init_on_startup.vbs', 'config/settings.example.json', 'src', 'tests',
        'installer', 'data/.gitkeep', 'data/notes.md'
    ) | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) }

    if ($toAdd.Count -gt 0) {
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments (@('add') + $toAdd)
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'commit', '-m', 'chore: initial AutoGitHub setup'
        )
    }

    Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @('branch', '-M', $Config.branch)

    $remotes = @()
    if (-not $Config.dryRun) {
        $remotes = @(git -C $root remote 2>$null)
    }
    if ($remotes -notcontains 'origin') {
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'remote', 'add', 'origin', $Config.githubUrl
        )
    }

    $useForce = $ForcePush -or $Config.allowForcePush
    if ($useForce) {
        Write-AutoGitHubLog -Config $Config -Level WARN -Message 'Force push enabled - this can overwrite remote history.'
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'push', '-u', 'origin', $Config.branch, '--force'
        )
    } else {
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'push', '-u', 'origin', $Config.branch
        )
    }

    Write-AutoGitHubLog -Config $Config -Message "Repository connected to $($Config.githubUrl) (branch $($Config.branch))"
}

function Invoke-AutoGitHubCommits {
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [int]$CommitCount
    )

    $root = $Config._root
    $mode = $Config.contentMode.ToLowerInvariant()
    if ($CommitCount -lt 1) { $CommitCount = 1 }

    if ($mode -eq 'notes') {
        $changed = $true
        if (-not $Config.dryRun) {
            $changed = Add-DailyNote -Path $Config._notesPath
        } else {
            Write-AutoGitHubLog -Config $Config -Message "DRY-RUN: would append daily note to $($Config.notesFile)"
        }

        if (-not $changed -and -not $Config.dryRun) {
            # File already has today's marker - still allow commit if there are unstaged note changes
            Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
                'add', '--', $Config.notesFile
            )
            $status = ''
            if (-not $Config.dryRun) {
                $status = (& git -C $root status --porcelain -- $Config.notesFile | Out-String).Trim()
            }
            if (-not $status -and -not $Config.dryRun) {
                Write-AutoGitHubLog -Config $Config -Message 'Notes mode: nothing to commit today.'
                return 0
            }
        } else {
            Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
                'add', '--', $Config.notesFile
            )
        }

        $msg = Get-RandomCommitMessage -Config $Config -Index 1 -Total 1
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'commit', '-m', $msg
        )
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'push', 'origin', $Config.branch
        )
        Write-AutoGitHubLog -Config $Config -Message "Notes commit pushed to origin/$($Config.branch)"
        return 1
    }

    # synthetic mode (legacy contribution-style markers) - discouraged but supported
    Write-AutoGitHubLog -Config $Config -Level WARN -Message 'contentMode=synthetic creates placeholder commits; prefer notes mode.'
    for ($i = 1; $i -le $CommitCount; $i++) {
        Write-AutoGitHubLog -Config $Config -Message "Creating commit $i of $CommitCount"
        if (-not $Config.dryRun) {
            Write-SyntheticCommitContent -Path $Config._commitFilePath -Index $i -Total $CommitCount
        }
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'add', '--', $Config.commitFile
        )
        $msg = Get-RandomCommitMessage -Config $Config -Index $i -Total $CommitCount
        Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
            'commit', '-m', $msg
        )
    }

    Invoke-Git -Config $Config -DryRun:$Config.dryRun -WorkingDirectory $root -Arguments @(
        'push', 'origin', $Config.branch
    )
    Write-AutoGitHubLog -Config $Config -Message "Pushed $CommitCount commit(s) to origin/$($Config.branch)"
    return $CommitCount
}

function Register-AutoGitHubScheduledTask {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$TaskName = 'AutoGitHub Daily Run',
        [string]$Time = '09:00'
    )

    $runPs1 = Join-Path $Root 'run.ps1'
    if (-not (Test-Path -LiteralPath $runPs1)) {
        throw "run.ps1 not found at $runPs1"
    }

    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$runPs1`""
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg -WorkingDirectory $Root
    $trigger = New-ScheduledTaskTrigger -Daily -At $Time
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Host "Scheduled task '$TaskName' registered daily at $Time (WorkingDirectory=$Root)"
}

Export-ModuleMember -Function @(
    'Get-AutoGitHubRoot',
    'Get-AutoGitHubConfig',
    'Get-UtcTodayString',
    'Write-AutoGitHubLog',
    'Test-ShouldRunToday',
    'Update-LastRunDate',
    'Initialize-AutoGitHubRepo',
    'Invoke-AutoGitHubCommits',
    'Register-AutoGitHubScheduledTask',
    'Invoke-Git',
    'Add-DailyNote',
    'Write-SyntheticCommitContent'
)
