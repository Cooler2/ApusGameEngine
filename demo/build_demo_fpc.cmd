@echo off
setlocal

rem Build any demo with FPC using engine-standard flags.
rem Usage:
rem   demo\build_demo_fpc.cmd InputDemo
rem   demo\build_demo_fpc.cmd SimpleDemo sdl
rem   demo\build_demo_fpc.cmd MyDemo snd     (link the SDL_mixer audio backend)
rem Audio backends are opt-in (see defines.inc), so "snd" is required by any
rem demo that plays sound. SoundDemo enables it automatically.

if "%~1"=="" (
  echo Usage: %~nx0 DemoName [sdl^|snd]
  exit /b 1
)

set "DEMO=%~1"
set "MODE=%~2"
set "ROOT=%~dp0.."
set "DEMO_DIR=%ROOT%\demo\%DEMO%"
set "DPR=%DEMO_DIR%\%DEMO%.dpr"
set "OUT=%DEMO_DIR%\_fpc"
set "EXE_OUT=%ROOT%\bin64"
set "DEF_SDL="
set "DEF_SND="

if /I "%MODE%"=="sdl" set "DEF_SDL=-dSDL"
if /I "%MODE%"=="snd" set "DEF_SND=-dSDLMIX"
if /I "%DEMO%"=="SoundDemo" set "DEF_SND=-dSDLMIX"

if not exist "%DPR%" (
  echo ERROR: Demo project not found: "%DPR%"
  exit /b 2
)

if not exist "%OUT%" mkdir "%OUT%"
if not exist "%EXE_OUT%" mkdir "%EXE_OUT%"

rem Clean old unit/object files only in the demo output folder.
if exist "%OUT%\*.ppu" del /q "%OUT%\*.ppu" >nul 2>nul
if exist "%OUT%\*.o" del /q "%OUT%\*.o" >nul 2>nul

echo Building "%DEMO%"...
fpc -dOPENGL -dFREETYPE %DEF_SDL% %DEF_SND% -MDelphi -Sd -RIntel -WG ^
  -Fu"%ROOT%" ^
  -Fu"%ROOT%\extra" ^
  -Fu"%ROOT%\extra\sdl2" ^
  -Fu"%ROOT%\Base" ^
  -Fu"%ROOT%\Base\extra" ^
  -FE"%EXE_OUT%" ^
  -FU"%OUT%" ^
  "%DPR%"

set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo Build FAILED with error %ERR%.
  exit /b %ERR%
)

echo.
echo Build OK: "%EXE_OUT%\%DEMO%.exe"
exit /b 0
