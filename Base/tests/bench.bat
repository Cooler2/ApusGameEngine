@echo off
REM ============================================================================
REM bench.bat - Compile and run Pascal benchmarks with FPC (32-bit and 64-bit)
REM ============================================================================
REM
REM Usage:
REM   bench.bat              - compile and run BenchStrings.dpr (default)
REM   bench.bat Strings      - compile and run BenchStrings.dpr
REM
REM Output:
REM   bench_Strings_64.txt - 64-bit results
REM   bench_Strings_32.txt - 32-bit results
REM
REM Requirements:
REM   - FPC 3.2.2 installed at g:\lazarus\fpc\3.2.2\
REM
REM ============================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"
set FPC32=g:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe
set FPC64=g:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe
set FLAGS=-MDelphi -Sd -O3 -RIntel -Fu..

if "%1"=="" (
  set BENCH=BenchStrings
  set BENCHNAME=Strings
) else (
  set BENCH=Bench%1
  set BENCHNAME=%1
)

set LOG64=bench_!BENCHNAME!_64.txt
set LOG32=bench_!BENCHNAME!_32.txt

REM Delete old results and stale .ppu/.o from Base/ (left by IDE)
del /q !LOG64! !LOG32! bench_!BENCHNAME!_F64.txt bench_!BENCHNAME!_F32.txt 2>nul
del /q ..\*.ppu ..\*.o 2>nul

REM === 64-bit ===
echo Benchmarking !BENCH! (64-bit) - %date% %time% > !LOG64!
echo. >> !LOG64!
echo === Compiling with -O3 === >> !LOG64!
if exist out64 rmdir /s /q out64 2>nul
mkdir out64 2>nul
mkdir bin64 2>nul
%FPC64% %FLAGS% -FU"out64" -FE"bin64" !BENCH!.dpr >> !LOG64! 2>&1
if errorlevel 1 (
  echo COMPILE FAILED >> !LOG64!
  goto compile32
)
echo. >> !LOG64!
echo === Running === >> !LOG64!
bin64\!BENCH!.exe >> !LOG64! 2>&1
echo Exit code: %errorlevel% >> !LOG64!

:compile32
REM === 32-bit ===
echo Benchmarking !BENCH! (32-bit) - %date% %time% > !LOG32!
echo. >> !LOG32!
echo === Compiling with -O3 === >> !LOG32!
if exist out32 rmdir /s /q out32 2>nul
mkdir out32 2>nul
mkdir bin32 2>nul
%FPC32% %FLAGS% -FU"out32" -FE"bin32" !BENCH!.dpr >> !LOG32! 2>&1
if errorlevel 1 (
  echo COMPILE FAILED >> !LOG32!
  goto done
)
echo. >> !LOG32!
echo === Running === >> !LOG32!
bin32\!BENCH!.exe >> !LOG32! 2>&1
echo Exit code: %errorlevel% >> !LOG32!

:done
echo.
echo === 64-bit results ===
type !LOG64!
echo.
echo === 32-bit results ===
type !LOG32!
