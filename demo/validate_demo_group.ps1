param(
  [string]$ProjectGroup = (Join-Path $PSScriptRoot 'demos.groupproj')
)

$ErrorActionPreference = 'Stop'

function Add-Error {
  param([string]$Message)
  $script:errors += $Message
  Write-Host "ERROR: $Message"
}

$errors = @()
$groupPath = (Resolve-Path -LiteralPath $ProjectGroup).Path
$demoDir = Split-Path -Parent $groupPath

[xml]$xml = Get-Content -LiteralPath $groupPath -Raw
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')

$projectNodes = @($xml.SelectNodes('//msb:Projects', $ns))
$targetNodes = @($xml.SelectNodes('//msb:Target', $ns))
$targetsByName = @{}

foreach ($target in $targetNodes) {
  if ($targetsByName.ContainsKey($target.Name)) {
    Add-Error "duplicate target '$($target.Name)'"
  } else {
    $targetsByName[$target.Name] = $target
  }
}

$buildTargets = @()
$cleanTargets = @()
$makeTargets = @()

foreach ($project in $projectNodes) {
  $include = $project.Include
  $path = Join-Path $demoDir $include
  if (-not (Test-Path -LiteralPath $path)) {
    Add-Error "missing project file '$include'"
  }

  $build = @($targetNodes | Where-Object {
    $msbuild = $_.SelectSingleNode('msb:MSBuild', $ns)
    $msbuild -ne $null -and $msbuild.Projects -eq $include -and [string]::IsNullOrEmpty($msbuild.Targets)
  })
  $clean = @($targetNodes | Where-Object {
    $msbuild = $_.SelectSingleNode('msb:MSBuild', $ns)
    $msbuild -ne $null -and $msbuild.Projects -eq $include -and $msbuild.Targets -eq 'Clean'
  })
  $make = @($targetNodes | Where-Object {
    $msbuild = $_.SelectSingleNode('msb:MSBuild', $ns)
    $msbuild -ne $null -and $msbuild.Projects -eq $include -and $msbuild.Targets -eq 'Make'
  })

  if ($build.Count -ne 1) {
    Add-Error "project '$include' has $($build.Count) build targets, expected 1"
  } else {
    $buildTargets += $build[0].Name
  }
  if ($clean.Count -ne 1) {
    Add-Error "project '$include' has $($clean.Count) clean targets, expected 1"
  } else {
    $cleanTargets += $clean[0].Name
  }
  if ($make.Count -ne 1) {
    Add-Error "project '$include' has $($make.Count) make targets, expected 1"
  } else {
    $makeTargets += $make[0].Name
  }
}

foreach ($aggregateName in @('Build', 'Clean', 'Make')) {
  if (-not $targetsByName.ContainsKey($aggregateName)) {
    Add-Error "missing aggregate target '$aggregateName'"
    continue
  }

  $callTarget = $targetsByName[$aggregateName].SelectSingleNode('msb:CallTarget', $ns)
  if ($callTarget -eq $null) {
    Add-Error "aggregate target '$aggregateName' has no CallTarget"
    continue
  }

  $actual = @($callTarget.Targets -split ';' | Where-Object { $_ -ne '' })
  foreach ($targetName in $actual) {
    if (-not $targetsByName.ContainsKey($targetName)) {
      Add-Error "aggregate target '$aggregateName' references missing target '$targetName'"
    }
  }

  $expected = switch ($aggregateName) {
    'Build' { $buildTargets }
    'Clean' { $cleanTargets }
    'Make' { $makeTargets }
  }
  foreach ($targetName in $expected) {
    if ($actual -notcontains $targetName) {
      Add-Error "aggregate target '$aggregateName' omits target '$targetName'"
    }
  }
}

if ($errors.Count -gt 0) {
  Write-Host "Demo group validation failed: $($errors.Count) error(s)."
  exit 1
}

Write-Host "Demo group validation OK: $($projectNodes.Count) project(s), $($targetNodes.Count) target(s)."
exit 0
