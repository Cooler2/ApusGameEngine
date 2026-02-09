@echo off
REM ============================================================================
REM clean.bat - Remove build artifacts from tests directory
REM ============================================================================
REM
REM This script deletes temporary files created during test builds:
REM   - Object files (.o, .ppu, .dcu)
REM   - Executable files (.exe)
REM   - Debug files (.dbg)
REM   - IDE temporary files (.identcache, .compiled, .~dsk, .dsk, .lpi, .lps)
REM   - Resource files (.rsm, .res)
REM   - Project local files (.dproj.local)
REM   - Output directories (out, out32, out64)
REM
REM Usage: clean.bat
REM
REM WARNING: This script will permanently delete files. Use with caution.
REM ============================================================================

setlocal enabledelayedexpansion

echo Cleaning test build artifacts...

REM Delete individual file patterns
del /q test*.exe 2>nul
del /q bench*.exe 2>nul
del /q *.o 2>nul
del /q *.ppu 2>nul
del /q *.dcu 2>nul
del /q *.rsm 2>nul
del /q *.res 2>nul
del /q *.dbg 2>nul
del /q *.identcache 2>nul
del /q *.compiled 2>nul
del /q *.~dsk 2>nul
del /q *.dsk 2>nul
rem del /q *.lpi 2>nul
del /q *.lps 2>nul
del /q *.dproj.local 2>nul
del /q *.stat 2>nul
del /q *.local 2>nul

REM Delete test executables (but keep original .exe files? We'll delete all .exe except test.bat doesn't have .exe)
del /q Test*.exe 2>nul
del /q bench*.exe 2>nul
del /q prog.exe 2>nul

REM Delete output directories
if exist out rmdir /s /q out 2>nul
if exist out32 rmdir /s /q out32 2>nul
if exist out64 rmdir /s /q out64 2>nul

REM Delete bin directories (relative to tests)
if exist ..\..\bin\Test*.exe del ..\..\bin\Test*.exe 2>nul
if exist ..\..\bin64\Test*.exe del ..\..\bin64\Test*.exe 2>nul

REM Delete files in Win32 and Win64 directories (recursively delete all files but keep directories)
if exist Win32 (
  echo Cleaning Win32 directory...
  REM Delete all files in Win32 and all subdirectories, keep directory structure
  del /s /q Win32\*.* 2>nul
  REM Remove empty directories (optional, but we keep them as requested)
  REM for /d %%d in (Win32\*) do rmdir "%%d" 2>nul
)

if exist Win64 (
  echo Cleaning Win64 directory...
  REM Delete all files in Win64 and all subdirectories, keep directory structure
  del /s /q Win64\*.* 2>nul
  REM Remove empty directories (optional, but we keep them as requested)
  REM for /d %%d in (Win64\*) do rmdir "%%d" 2>nul
)

REM Delete log files
rem del /q test_results_64.txt 2>nul
rem del /q test_results_32.txt 2>nul
del /q log.txt 2>nul

echo Cleanup completed.
pause
