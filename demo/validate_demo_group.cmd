@echo off
setlocal

rem Validate demos.groupproj paths, project targets, and aggregate targets.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0validate_demo_group.ps1" %*
exit /b %ERRORLEVEL%
