@echo off
rem Build a program on the engine with FPC (Windows).
rem Usage: build.cmd <Name|path> [extra fpc options...]
rem   <Name>  - a demo folder name, e.g. SimpleDemo (-> demo\SimpleDemo)
rem   <path>  - any project folder or .dpr file, also outside the repository
rem The project is <folder>\<folder>.dpr, or the only .dpr in the folder.
rem Options come from build.cfg (engine-wide) and <folder>\build.cfg (if present).
rem The executable goes to bin64\ (or bin\ for a 32-bit FPC), next to the DLLs;
rem units go to <folder>\_fpc. Linux/macOS counterpart: build.sh.
setlocal EnableDelayedExpansion

if "%~1"=="" (
  echo Usage: %~nx0 ^<Name^|path^> [extra fpc options...]
  exit /b 1
)
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "TARGET=%~1"

rem collect extra options (everything after the first argument)
set "EXTRA="
shift
:nextarg
if "%~1"=="" goto argsdone
set "EXTRA=!EXTRA! %1"
shift
goto nextarg
:argsdone

set "DPR="
set "DIR="
for %%F in ("%TARGET%") do if /I "%%~xF"==".dpr" if exist "%%~fF" set "DPR=%%~fF"
if not defined DPR (
  if exist "%TARGET%\*" (
    for %%D in ("%TARGET%") do set "DIR=%%~fD"
  ) else if exist "%ROOT%\demo\%TARGET%\*" (
    set "DIR=%ROOT%\demo\%TARGET%"
  ) else (
    echo ERROR: project not found: %TARGET%
    exit /b 2
  )
)
if not defined DPR (
  for %%D in ("!DIR!") do set "DPR=!DIR!\%%~nxD.dpr"
  if not exist "!DPR!" (
    set "DPR="
    set "COUNT=0"
    rem the extension check skips .dproj, which *.dpr also matches via 8.3 names
    for %%F in ("!DIR!\*.dpr") do if /I "%%~xF"==".dpr" (
      set "DPR=%%~fF"
      set /a COUNT+=1
    )
    if not "!COUNT!"=="1" (
      echo ERROR: expected a .dpr named after the folder or a single .dpr in !DIR!
      exit /b 2
    )
  )
)
for %%F in ("%DPR%") do set "DIR=%%~dpF"
set "DIR=%DIR:~0,-1%"

rem 64-bit FPC -> bin64, 32-bit -> bin (the DLLs for each are there)
set "BIN=bin64"
for /f %%C in ('fpc -iTP') do if /I "%%C"=="i386" set "BIN=bin"

set "OPTS=@"%ROOT%\build.cfg""
if exist "%DIR%\build.cfg" set "OPTS=%OPTS% @"%DIR%\build.cfg""
if not exist "%DIR%\_fpc" mkdir "%DIR%\_fpc"

rem build.cfg paths are relative to the repository root
pushd "%ROOT%"
echo Building %DPR%
fpc %OPTS% -Fu"%DIR%" -FU"%DIR%\_fpc" -FE"%ROOT%\%BIN%" %EXTRA% "%DPR%"
set "ERR=%ERRORLEVEL%"
popd
if not "%ERR%"=="0" (
  echo Build FAILED with error %ERR%.
  exit /b %ERR%
)
exit /b 0
