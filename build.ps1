param(
  [Parameter(Position=0)]
  [string]$Target = "",
  [Parameter(Position=1)]
  [string]$Mode = "win64"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

function Get-Aliases {
  return @{
    "simple"         = @{ dpr = "demo\SimpleDemo\SimpleDemo.dpr"; defines = @("OPENGL","SDL") }
    "simpledemo"     = @{ dpr = "demo\SimpleDemo\SimpleDemo.dpr"; defines = @("OPENGL","SDL") }
    "simpledemo-win" = @{ dpr = "demo\SimpleDemo\SimpleDemo.dpr"; defines = @("OPENGL") }
    "meshlab"        = @{ dpr = "demo\MeshLab\MeshLab.dpr"; defines = @("OPENGL") }
    "uilab"          = @{ dpr = "demo\UILab\UILab.dpr"; defines = @("OPENGL") }
  }
}

if ([string]::IsNullOrWhiteSpace($Target)) {
  Write-Host "Usage: build <alias-or-path> [mode]"
  Write-Host "Examples:"
  Write-Host "  build simpledemo"
  Write-Host "  build demo\SimpleDemo\SimpleDemo.dpr"
  Write-Host ""
  Write-Host "Mode: only win64 is supported."
  Write-Host ""
  Write-Host "Available aliases:"
  $aliases = Get-Aliases
  foreach ($k in ($aliases.Keys | Sort-Object)) {
    Write-Host ("  {0,-12} -> {1}" -f $k, $aliases[$k].dpr)
  }
  exit 1
}

if ($Mode.ToLowerInvariant() -ne "win64") {
  Write-Host "Only win64 build is supported. Requested: $Mode"
  exit 1
}

function Resolve-Target([string]$name) {
  $key = $name.Trim().ToLowerInvariant()
  $aliases = Get-Aliases

  if ($aliases.ContainsKey($key)) {
    return $aliases[$key]
  }

  $candidate = $name
  if (-not $candidate.ToLowerInvariant().EndsWith(".dpr")) {
    if (Test-Path $candidate) {
      if ((Get-Item $candidate).PSIsContainer) {
        $base = Split-Path $candidate -Leaf
        $candidateWithDpr = Join-Path $candidate ($base + ".dpr")
        if (Test-Path $candidateWithDpr) {
          $candidate = $candidateWithDpr
        }
      } else {
        $candidate = "$candidate.dpr"
      }
    } else {
      $candidate = "$candidate.dpr"
    }
  }

  if (-not (Test-Path $candidate)) {
    throw "Target not found: $name"
  }

  return @{ dpr = $candidate; defines = @() }
}

$resolved = Resolve-Target $Target
$dprRel = $resolved.dpr
$defines = @($resolved.defines)
$dprAbs = Join-Path $repoRoot $dprRel

if (-not (Test-Path $dprAbs)) {
  throw "DPR file not found: $dprRel"
}

$projectDir = Split-Path -Parent $dprAbs
$projectName = [System.IO.Path]::GetFileNameWithoutExtension($dprAbs)
$outDir = Join-Path $projectDir "lib\x86_64-win64"
$binDir = Join-Path $repoRoot "bin64"
$logPath = Join-Path $repoRoot "build_results.txt"

if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

$args = @(
  "-MDelphi",
  "-Sd",
  "-WG",
  "-RIntel",
  "-Fu$repoRoot",
  "-Fu$repoRoot\extra",
  "-Fu$repoRoot\extra\sdl2",
  "-Fu$repoRoot\Base",
  "-Fu$repoRoot\Base\extra",
  "-FU$outDir",
  "-FE$binDir",
  $dprAbs
)

foreach ($def in $defines) {
  $args = @("-d$def") + $args
}

"Building $dprRel (win64) - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logPath -Encoding UTF8
"fpc $($args -join ' ')" | Out-File -FilePath $logPath -Append -Encoding UTF8
"" | Out-File -FilePath $logPath -Append -Encoding UTF8

Push-Location $projectDir
try {
  & fpc @args 2>&1 | ForEach-Object {
    Write-Host $_
    Add-Content -Path $logPath -Value $_ -Encoding UTF8
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD FAILED: $dprRel"
    Write-Host "Log: $logPath"
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "BUILD OK: $dprRel"
Write-Host "Output: $binDir\$projectName.exe"
Write-Host "Log: $logPath"
exit 0
