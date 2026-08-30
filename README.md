# AutoGitHub

![GitHub license](https://img.shields.io/github/license/GuilhermeRoesler/AutoGitHub)
![GitHub last commit](https://img.shields.io/github/last-commit/GuilhermeRoesler/AutoGitHub)

Windows automation that syncs a small GitHub repo **at most once per UTC day**, with real error handling, JSON config, and optional Task Scheduler integration.

> **Honest scope:** the old Batch edition existed mainly to paint the contribution graph with synthetic commits. This rewrite defaults to **`contentMode: "notes"`** — it commits changes to `data/notes.md` (real notes / status). Synthetic placeholder commits still exist for compatibility but are discouraged.

## Disclaimer

This project is an **unofficial** personal automation tool and is **not** affiliated with, endorsed by, or connected to GitHub, Inc. (or Microsoft).

You are solely responsible for how you use AutoGitHub, including compliance with [GitHub's Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service), Acceptable Use policies, and any employer or school rules. Using `contentMode: "synthetic"` (or any setup) mainly to fabricate activity on the contribution graph may violate those terms and can lead to account restrictions — prefer meaningful commits via **notes** mode.

The software is provided **as is**, without warranty of any kind. Automating `git push` against your credentials can modify remote repositories; review your config, prefer `dryRun` when testing, and use at your own risk.

## Requirements

- Windows PowerShell 5.1+ (or PowerShell 7+)
- Git installed and authenticated for `git push` (Credential Manager or SSH)

## Quick start (installer — recommended)

```powershell
git clone https://github.com/GuilhermeRoesler/AutoGitHub.git
cd AutoGitHub
.\install.bat
```

Or from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Install.ps1
```

The installer copies the app to `%LOCALAPPDATA%\AutoGitHub`, writes `config\settings.json`, creates **Start Menu** shortcuts, and (by default) registers the daily Task Scheduler job.

Silent / non-interactive example:

```powershell
.\installer\Install.ps1 -NonInteractive `
  -GitHubUrl 'https://github.com/YOU/your-repo.git' `
  -CreateDesktopShortcut `
  -ScheduleTime '09:00'
```

Uninstall (Start Menu → **Uninstall AutoGitHub**, or):

```powershell
& "$env:LOCALAPPDATA\AutoGitHub\installer\Uninstall.ps1"
```

## Quick start (portable / from clone)

```powershell
git clone https://github.com/GuilhermeRoesler/AutoGitHub.git
cd AutoGitHub
copy config\settings.example.json config\settings.json
# Edit config\settings.json — set your githubUrl and branch
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Setup.ps1   # optional wizard
.\run.ps1
```

`run.bat` is a thin wrapper around `run.ps1` (useful for Startup shortcuts).

## Configuration (`config/settings.json`)

Copy from `config/settings.example.json`. The real `settings.json` is gitignored.

| Key | Meaning |
|-----|---------|
| `githubUrl` | Remote repository URL |
| `branch` | Branch to commit/push (default `main`) |
| `contentMode` | `notes` (recommended) or `synthetic` |
| `notesFile` | File updated in notes mode |
| `commitFile` | File overwritten in synthetic mode |
| `maxCommits` | Max random commits/day in synthetic mode only |
| `commitMessages` | Message pool; one is picked per commit |
| `dateTracker` | UTC `yyyy-MM-dd` last-run file |
| `enableLogging` / `logFile` | Optional file log |
| `dryRun` | Log git actions without executing |
| `allowForcePush` | Opt-in destructive init push (default `false`) |

### CLI flags

```powershell
.\run.ps1 -DryRun              # no git writes/pushes
.\run.ps1 -Force               # ignore daily guard
.\run.ps1 -ForcePushInit       # only for first init if you really need --force
.\run.ps1 -ConfigPath path.json
```

## Modes

### `notes` (default)

Appends a dated marker to `data/notes.md` once per UTC day (if missing), commits, and pushes. Edit the notes file yourself for meaningful content — the graph stays green as a side effect of real updates.

### `synthetic` (legacy)

Writes placeholder content to `commitFile` up to `maxCommits` times. Kept for compatibility; prefer notes.

## Scheduling

The installer registers the task for you. From a portable clone:

```powershell
powershell -NoProfile -File .\src\Register-Schedule.ps1
```

Creates **AutoGitHub Daily Run** at 09:00 with an explicit **WorkingDirectory** set to the app/repo root (fixes the old Batch bug where relative paths broke under Task Scheduler).

### Startup (hidden)

During install you can opt into a Startup-folder shortcut. Manually:

1. `Win + R` → `shell:startup`
2. Shortcut to `init_on_startup.vbs` in the install folder (sets working directory, then runs `run.bat` hidden)

## Tests

```powershell
powershell -NoProfile -File .\tests\VerifyDate.Tests.ps1
```

Covers first-run, same-day skip, new-day run, legacy date migration, dry-run date writes, and notes idempotency.

## Security notes

- No tokens in the repo — uses your existing Git credentials
- Init **does not** force-push unless `-ForcePushInit` or `allowForcePush: true`
- Init stages known project paths only (no blind `git add .`)
- Failed `git` commands abort the run (no fake “success”)

## License

MIT — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome. Prefer improvements that keep notes-first workflow and UTC date safety.
