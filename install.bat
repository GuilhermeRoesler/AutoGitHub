@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Install.ps1" %*
set EXITCODE=%ERRORLEVEL%
echo.
pause
endlocal & exit /b %EXITCODE%
