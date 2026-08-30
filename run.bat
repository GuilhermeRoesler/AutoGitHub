@echo off
setlocal
REM Thin launcher — keeps Startup shortcuts and Task Scheduler entries working.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" %*
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
