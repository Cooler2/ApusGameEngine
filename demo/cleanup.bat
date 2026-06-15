@echo off
setlocal

rem Remove ignored build outputs, IDE metadata, logs, and runtime files.
rem Usage:
rem   demo\cleanup.bat
rem   demo\cleanup.bat dry-run

pushd "%~dp0.." || exit /b 1

if /I "%~1"=="dry-run" (
  git clean -ndX -- demo ":(exclude)demo/**/res/*.obj"
) else (
  git clean -fdX -- demo ":(exclude)demo/**/res/*.obj"
)

set "ERR=%ERRORLEVEL%"
popd
exit /b %ERR%
