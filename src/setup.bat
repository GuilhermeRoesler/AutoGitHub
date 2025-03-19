@echo off
setlocal

REM ========================================
REM AutoGitHub - Setup Helper
REM ========================================

echo Welcome to AutoGitHub Setup!
echo.

REM Create necessary directories
if not exist "data" mkdir data
if not exist "logs" mkdir logs
if not exist "config" mkdir config
if not exist "src" mkdir src

REM Prompt for GitHub URL
set /p github_url=Enter your GitHub repository URL: 

REM Create or update settings file
echo @echo off > config\settings.bat
echo REM ======================================== >> config\settings.bat
echo REM AutoGitHub Configuration Settings >> config\settings.bat
echo REM ======================================== >> config\settings.bat
echo. >> config\settings.bat
echo REM GitHub Repository URL (REQUIRED) >> config\settings.bat
echo set GITHUB_URL=%github_url% >> config\settings.bat
echo. >> config\settings.bat
echo REM File that will be modified for commits >> config\settings.bat
echo set COMMIT_FILE=data/commit_data.txt >> config\settings.bat
echo. >> config\settings.bat
echo REM Maximum number of random commits per day >> config\settings.bat
echo set MAX_COMMITS=5 >> config\settings.bat
echo. >> config\settings.bat
echo REM Date tracking file location >> config\settings.bat
echo set DATE_TRACKER=data/last_update.txt >> config\settings.bat
echo. >> config\settings.bat
echo REM Enable logging (1=yes, 0=no) >> config\settings.bat
echo set ENABLE_LOGGING=1 >> config\settings.bat
echo set LOG_FILE=logs/autogithub.log >> config\settings.bat

echo.
echo Setup completed successfully!
echo.
echo Would you like to schedule AutoGitHub to run daily?
choice /c YN /m "Schedule daily task (Y/N)?"

if errorlevel 2 goto SkipSchedule
if errorlevel 1 goto Schedule

:Schedule
call schedule_task.bat
goto End

:SkipSchedule
echo Task scheduling skipped. You can run AutoGitHub manually using run.bat

:End
echo.
echo Setup complete! You can now run AutoGitHub using run.bat
echo.

endlocal