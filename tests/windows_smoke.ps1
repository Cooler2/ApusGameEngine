param(
  [string]$OutDir=$env:OUTDIR,
  [string]$Fpc=$env:FPC,
  [switch]$NoRun
)

# Compile and run Windows/FPC engine smoke targets without touching source dirs.

$ErrorActionPreference='Stop'

$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir=Join-Path $root 'tmp\engine5_fpc_engine_smoke'
}
if([string]::IsNullOrWhiteSpace($Fpc)){
  $Fpc='fpc'
}

$outFull=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
if(Test-Path $outFull){
  Remove-Item -LiteralPath $outFull -Recurse -Force
}
New-Item -ItemType Directory -Path $outFull | Out-Null

$flags=@(
  '-dSDL',
  '-dOPENGL',
  '-MDelphi',
  '-Sd',
  '-RIntel',
  "-Fu$root",
  "-Fu$(Join-Path $root 'extra')",
  "-Fu$(Join-Path $root 'extra\sdl2')",
  "-Fu$(Join-Path $root 'Base')",
  "-Fu$(Join-Path $root 'Base\extra')",
  '-Se1'
)

function Invoke-FpcTarget {
  param(
    [string]$Target,
    [string]$UnitDir,
    [switch]$CompileOnly
  )

  $targetPath=Join-Path $root $Target
  $name=[IO.Path]::GetFileNameWithoutExtension($Target)
  $targetOut=Join-Path $outFull $name
  $log=Join-Path $outFull "$name.log"
  New-Item -ItemType Directory -Path $targetOut | Out-Null

  $args=@()
  $args+=$flags
  if($UnitDir){
    $args+="-Fu$(Join-Path $root $UnitDir)"
  }
  if($CompileOnly -or $NoRun){
    $args+='-Cn'
  } else {
    $args+="-FE$targetOut"
  }
  $args+="-FU$targetOut"
  $args+=$targetPath

  & $Fpc @args > $log 2>&1
  if($LASTEXITCODE -ne 0){
    Write-Host "[ FAIL ] $Target"
    Get-Content -LiteralPath $log -Tail 80
    exit $LASTEXITCODE
  }

  if((-not $CompileOnly) -and (-not $NoRun)){
    $exe=Join-Path $targetOut "$name.exe"
    & $exe >> $log 2>&1
    if($LASTEXITCODE -ne 0){
      Write-Host "[ FAIL ] $Target"
      Get-Content -LiteralPath $log -Tail 80
      exit $LASTEXITCODE
    }
  }

  Write-Host "[ ---- ] $Target"
}

Invoke-FpcTarget 'tests/PlatformTest.dpr' -CompileOnly
Invoke-FpcTarget 'tests/OpenGL.dpr' -CompileOnly
Invoke-FpcTarget 'tests/TestStyle.dpr'
Invoke-FpcTarget 'tests/TestGpuLayout.dpr'
Invoke-FpcTarget 'tests/TestHttpGameClient.dpr'
Invoke-FpcTarget 'tests/TestUdpTransport.dpr'
Invoke-FpcTarget 'tests/TestMesh3D.dpr'
Invoke-FpcTarget 'tests/TestMeshOps.dpr'
Invoke-FpcTarget 'tests/TestObjMesh.dpr'

Write-Host ''
Write-Host 'SUMMARY: Windows/FPC engine smoke targets passed'
