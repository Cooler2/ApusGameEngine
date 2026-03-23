@echo off
REM ============================================================================
REM test.bat - Compile and run Pascal tests with FPC (32-bit and 64-bit)
REM ============================================================================
REM
REM Usage:
REM   test.bat              - compile and run TestCore.dpr (default)
REM   test.bat TestStrings  - compile and run TestStrings.dpr
REM
REM Output:
REM   test_results_64.txt - 64-bit compilation and test results
REM   test_results_32.txt - 32-bit compilation and test results
REM
REM Requirements:
REM   - FPC 3.2.2 installed at g:\lazarus\fpc\3.2.2\
REM
REM ============================================================================
setlocal
cd /d "%~dp0"
set FPC32=ppc386.exe
set FPC64=fpc.exe
set FLAGS=-MDelphi -Sd -RIntel -Fu.. -Ct -CR -dTIME_OVERRIDE
set LOG64=test_results_64.txt
set LOG32=test_results_32.txt

if "%1"=="" (
  set TEST=TestCore
) else (
  set TEST=%1
  if not exist "%TEST%.dpr" (
    set TEST=Test%1
  )
)

REM Delete old results and stale .ppu/.o from Base/ (left by IDE)
del /q %LOG64% 2>nul
del /q %LOG32% 2>nul
del /q ..\*.ppu ..\*.o 2>nul

REM === 64-bit ===
echo Testing %TEST% (64-bit) - %date% %time% > %LOG64%
echo. >> %LOG64%
echo === Compiling === >> %LOG64%
REM Clean 64-bit output directory
if exist out64 rmdir /s /q out64 2>nul
mkdir out64 2>nul
mkdir bin64 2>nul
%FPC64% %FLAGS% -FU"out64" -FE"bin64" %TEST%.dpr >> %LOG64% 2>&1
if errorlevel 1 (
  echo COMPILE FAILED >> %LOG64%
  goto compile32
)
echo. >> %LOG64%
echo === Running === >> %LOG64%
bin64\%TEST%.exe >> %LOG64% 2>&1
echo Exit code: %errorlevel% >> %LOG64%

:compile32
REM === 32-bit ===
echo Testing %TEST% (32-bit) - %date% %time% > %LOG32%
echo. >> %LOG32%
echo === Compiling === >> %LOG32%
REM Clean 32-bit output directory
if exist out32 rmdir /s /q out32 2>nul
mkdir out32 2>nul
mkdir bin32 2>nul
%FPC32% %FLAGS% -FU"out32" -FE"bin32" %TEST%.dpr >> %LOG32% 2>&1
if errorlevel 1 (
  echo COMPILE FAILED >> %LOG32%
  goto done
)
echo. >> %LOG32%
echo === Running === >> %LOG32%
bin32\%TEST%.exe >> %LOG32% 2>&1
echo Exit code: %errorlevel% >> %LOG32%

:done
echo.
echo === 64-bit results ===
type %LOG64%
echo.
echo === 32-bit results ===
type %LOG32%
