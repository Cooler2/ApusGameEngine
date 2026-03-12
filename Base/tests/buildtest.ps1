# ============================================================================
# buildtest.ps1 - Compile all Base modules to verify they build (Windows)
# ============================================================================
# Usage: powershell -File Base/tests/buildtest.ps1
#        or via: Base\tests\buildtest.bat
# ============================================================================

Set-Location $PSScriptRoot

$fpc    = if ($env:FPC) { $env:FPC } else { 'fpc.exe' }
$flags  = @('-MDelphi', '-Sd', '-RIntel', '-Fu..', '-Fu..\extra', '-Cn')
$outdir = 'out_build'
$log    = 'buildtest_results.txt'

$pass     = 0
$fail     = 0
$failList = [System.Collections.Generic.List[string]]::new()

if (Test-Path $outdir) { Remove-Item $outdir -Recurse -Force }
New-Item -ItemType Directory -Path $outdir | Out-Null

function Write-Log($msg) {
  Write-Host $msg
  Add-Content -Path $log -Value $msg
}

$header = "Build Test (64-bit) - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Set-Content -Path $log -Value $header
Add-Content -Path $log -Value "=========================================="
Write-Host $header
Write-Host "=========================================="

function Build-Module([string]$name) {
  $pasFile = "..\$name.pas"
  $tmpFile = Join-Path $outdir "$name.tmp"

  & $fpc @flags "-FU$outdir" $pasFile *> $tmpFile

  if ($LASTEXITCODE -eq 0) {
    Write-Log "[ ---- ] $name"
    $script:pass++
  } else {
    Write-Log "[ FAIL ] $name"
    Get-Content $tmpFile | Add-Content -Path $log
    Add-Content -Path $log -Value ""
    $script:fail++
    $script:failList.Add($name)
  }
}

# === Level 0: no Apus dependencies ===
Build-Module 'Apus.Types'
Build-Module 'Apus.CPU'
Build-Module 'Apus.Crypto'
Build-Module 'Apus.ADPCM'
Build-Module 'Apus.LongMath'
Build-Module 'Apus.RegExpr'

# === Level 1: Core API ===
Build-Module 'Apus.Core'
Build-Module 'Apus.Colors'
Build-Module 'Apus.Conv'
Build-Module 'Apus.Strings'
Build-Module 'Apus.Log'

# === Level 2: Utils and platform ===
Build-Module 'Apus.Utils'
Build-Module 'Apus.Files'
Build-Module 'Apus.Threads'
Build-Module 'Apus.HashMaps'
Build-Module 'Apus.Geom2D'
Build-Module 'Apus.Geom3D'
Build-Module 'Apus.Spatial'

# === Level 3: Higher-level data structures ===
Build-Module 'Apus.Classes'
Build-Module 'Apus.EventMan'
Build-Module 'Apus.Lib'
Build-Module 'Apus.Tweenings'
Build-Module 'Apus.AnimatedValues'

# === Level 4: Structs and graphics primitives ===
Build-Module 'Apus.Structs'
Build-Module 'Apus.FastGFX'
Build-Module 'Apus.VertexLayout'
Build-Module 'Apus.Socket'

# === Level 5: Images and collections ===
Build-Module 'Apus.Images'
Build-Module 'Apus.GfxFilters'
Build-Module 'Apus.Regions'
Build-Module 'Apus.ProdCons'
Build-Module 'Apus.Huffman'

# === Level 6: Network and files ===
Build-Module 'Apus.ControlFiles'
Build-Module 'Apus.TCP'

# === Level 7: High-level network ===
Build-Module 'Apus.HttpRequests'
Build-Module 'Apus.GfxFormats'

# === Level 8: Text and data ===
Build-Module 'Apus.TextUtils'
Build-Module 'Apus.UnicodeFont'
Build-Module 'Apus.Translation'
Build-Module 'Apus.Database'

# === Level 9: Specialized ===
Build-Module 'Apus.HtmlTree'
Build-Module 'Apus.FreeTypeFont'
Build-Module 'Apus.GlyphCache'
Build-Module 'Apus.GeoIP'

# === Level 10: Diagnostics and extras ===
Build-Module 'Apus.Logging'
Build-Module 'Apus.Profiling'
Build-Module 'Apus.StackTrace'
Build-Module 'Apus.Clipboard'
Build-Module 'Apus.MemoryLeakUtils'
Build-Module 'Apus.Publics'
Build-Module 'Apus.RSA'
Build-Module 'Apus.SCGI'

# === Summary ===
Add-Content -Path $log -Value ""
Add-Content -Path $log -Value "=========================================="
$summary = "SUMMARY: $pass passed, $fail failed"
Write-Log $summary

if ($failList.Count -gt 0) {
  Write-Host "Failed modules:"
  $failList | ForEach-Object { Write-Host "  $_" }
}

if ($fail -gt 0) { exit 1 } else { exit 0 }
