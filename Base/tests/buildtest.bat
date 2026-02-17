@echo off
REM Build test - wrapper that runs buildtest.ps1 via PowerShell
REM Output: buildtest_results.txt
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0buildtest.ps1"
exit /b %ERRORLEVEL%
