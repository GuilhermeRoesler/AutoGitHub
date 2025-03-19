@echo off
setlocal enabledelayedexpansion

REM ========================================
REM AutoGitHub - Date Verification
REM ========================================

REM Load configuration if not already loaded
if not defined DATE_TRACKER call config\settings.bat

set RUN_TODAY=0

REM Create date tracker file if it doesn't exist
if not exist "%DATE_TRACKER%" (
    echo Creating new date tracker file...
    echo 01/01/2000 > "%DATE_TRACKER%"
    if %ENABLE_LOGGING%==1 echo [%date% %time%] Created new date tracker file >> %LOG_FILE%
    goto :end_date_check
)

REM Read the last update date
set /p last_update=<"%DATE_TRACKER%"

REM Compare with current date
if not %last_update%==%date% (
    set RUN_TODAY=1
    if %ENABLE_LOGGING%==1 echo [%date% %time%] Already ran today (Last: %last_update%, Current: %date%) >> %LOG_FILE%
) else (
    if %ENABLE_LOGGING%==1 echo [%date% %time%] New day detected (Last: %last_update%, Current: %date%) >> %LOG_FILE%
)

:end_date_check
endlocal & set RUN_TODAY=%RUN_TODAY%
