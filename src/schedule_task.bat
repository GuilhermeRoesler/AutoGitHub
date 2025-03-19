@echo off
setlocal

REM ========================================
REM AutoGitHub - Task Scheduler
REM ========================================

echo Setting up scheduled task for AutoGitHub...

REM Get the current directory
set CURRENT_DIR=%CD%

REM Create a scheduled task to run daily at 9 AM
schtasks /create /tn "AutoGitHub Daily Run" /tr "%CURRENT_DIR%\run.bat" /sc daily /st 09:00 /f

echo Task scheduled successfully. AutoGitHub will run daily at 9:00 AM.
echo You can modify this schedule in Windows Task Scheduler.

endlocal
