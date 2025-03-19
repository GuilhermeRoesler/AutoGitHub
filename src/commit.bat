@echo off
setlocal enabledelayedexpansion

REM ========================================
REM AutoGitHub - Commit Generator
REM ========================================

REM Load configuration if not already loaded
if not defined COMMIT_FILE call config\settings.bat

REM Ensure the commit file exists
if not exist "%COMMIT_FILE%" (
    type nul > "%COMMIT_FILE%"
)

echo Processing %1 commits...

for /l %%i in (1,1,%1) do (
    echo [%time%] Creating commit %%i of %1
    
    REM Generate commit content with timestamp for uniqueness
    echo Commit %%i - %date% %time% > %COMMIT_FILE%
    
    REM Add changes to git
    git add %COMMIT_FILE%
    
    REM Create commit with a more descriptive message
    git commit -m "Update data (%%i/%1) - %date%"
    
    if %ENABLE_LOGGING%==1 (
        echo [%date% %time%] Created commit %%i of %1 >> %LOG_FILE%
    )
)

REM Push all commits to remote repository
echo Pushing commits to remote repository...
git push origin main

if %ENABLE_LOGGING%==1 (
    echo [%date% %time%] Pushed %1 commits to remote repository >> %LOG_FILE%
)

echo All commits successfully processed and pushed.

endlocal
