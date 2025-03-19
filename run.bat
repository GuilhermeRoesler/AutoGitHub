@echo off
setlocal enabledelayedexpansion

REM ========================================
REM AutoGitHub - Main Runner
REM ========================================

REM Setup program
@REM call src\setup.bat

REM Load configuration
call config\settings.bat 2>nul || (
    echo Configuration file not found. Using default settings.
    set GITHUB_URL=https://github.com/YOUR_USER/AutoGitHub.git
    set COMMIT_FILE=modifyme.txt
    set MAX_COMMITS=5
    set DATE_TRACKER=last_update.txt
    set ENABLE_LOGGING=0
)

REM Create necessary directories
if not exist "data" mkdir data
if not exist "logs" mkdir logs

REM Initialize log file
if "%ENABLE_LOGGING%"=="1" (
    echo [%date% %time%] AutoGitHub started > logs\autogithub.log
    set LOG_FILE=logs\autogithub.log
)

REM Verify if repository is initialized
if not exist ".git" (
    echo Repository not initialized. Running initialization...
    if "%ENABLE_LOGGING%"=="1" (
        echo [%date% %time%] Repository not initialized. Running initialization... >> !LOG_FILE!
    )
    call src\git_init.bat
)

REM Setting scheduler
@REM call src\schedule_task.bat

REM Check if we already ran today
call src\verify_date.bat

if "%RUN_TODAY%"=="1" (
    REM Generate random number of commits (between 1 and MAX_COMMITS)
    set /a number_of_commits=%random% * %MAX_COMMITS% / 32768 + 1
    
    echo Running AutoGitHub with !number_of_commits! commits...
    if "%ENABLE_LOGGING%"=="1" (
        echo [%date% %time%] Running with !number_of_commits! commits >> !LOG_FILE!
    )
    
    call src\commit.bat !number_of_commits!
    
    REM Update the last run date
    echo %date% > %DATE_TRACKER%
    
    echo AutoGitHub completed successfully.
    if "%ENABLE_LOGGING%"=="1" (
        echo [%date% %time%] AutoGitHub completed successfully >> !LOG_FILE!
    )
) else (
    echo AutoGitHub already ran today. Skipping execution.
    if "%ENABLE_LOGGING%"=="1" (
        echo [%date% %time%] Already ran today. Skipping execution >> !LOG_FILE!
    )
)

endlocal
