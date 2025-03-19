@echo off
REM ========================================
REM AutoGitHub Configuration Settings
REM ========================================

REM GitHub Repository URL (REQUIRED)
set GITHUB_URL=https://github.com/GuilhermeRoesler/AutoGitHub.git

REM File that will be modified for commits
set COMMIT_FILE=data/commit_data.txt

REM Maximum number of random commits per day
set MAX_COMMITS=1

REM Date tracking file location
set DATE_TRACKER=data\last_update.txt

REM Enable logging (1=yes, 0=no)
set ENABLE_LOGGING=1
set LOG_FILE=logs/autogithub.log