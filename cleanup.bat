@echo off
setlocal

REM ============================================================================
REM cleanup.bat - Remove compiler/build artifacts in repository
REM ============================================================================
REM Removes common Delphi/FPC artifacts recursively from current directory:
REM   .ppu .o .or .obj .dcu .dcp .dcpil .rsm .res .map .tds .identcache
REM   .compiled .dproj.local .lps .a
REM
REM Important:
REM   - .bak files are NOT touched
REM   - source files are NOT touched
REM ============================================================================

set ROOT=%~dp0
pushd "%ROOT%" >nul

echo Cleaning build artifacts under:
echo   %CD%
echo.

for %%E in (ppu o or obj dcu dcp dcpil rsm res map tds identcache compiled dproj.local lps a) do (
  del /q "*.%%E" 2>nul
)

echo Done.
popd >nul
endlocal
