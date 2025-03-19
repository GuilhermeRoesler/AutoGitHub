@echo off
setlocal enabledelayedexpansion

REM ========================================
REM AutoGitHub - Git Repository Initializer
REM ========================================

REM Load configuration if not already loaded
if not defined GITHUB_URL call config\settings.bat

echo Initializing Git repository...

REM Initialize git repository
git init

REM Create initial README if it doesn't exist
if not exist "README.md" (
    echo # AutoGitHub > README.md
    echo. >> README.md
    echo Repository for automated GitHub contributions. >> README.md
    echo Created on %date% >> README.md
)

REM Add all files
git add .

REM Initial commit
git commit -m "Initial repository setup"

REM Set main branch
git branch -M main

REM Add remote origin
git remote add origin %GITHUB_URL%

REM Push to remote
git push -u origin main --force

echo Git repository successfully initialized and connected to %GITHUB_URL%

if %ENABLE_LOGGING%==1 (
    echo [%date% %time%] Git repository initialized and connected to %GITHUB_URL% >> %LOG_FILE%
)

endlocal
