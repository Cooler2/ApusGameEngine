param(
  [switch]$CheckOnly,
  [ValidateRange(21, 99)]
  [int]$ApiLevel = 21
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$outputDir = Join-Path $repoRoot "tmp/android"
$unitDir = Join-Path $outputDir "units"
$probeSource = Join-Path $scriptDir "probe/android_probe.lpr"
$probeLibrary = Join-Path $outputDir "libapus_android_probe.so"
$script:failures = 0

function Resolve-Executable([string]$explicitPath, [string[]]$names) {
  if (-not [string]::IsNullOrWhiteSpace($explicitPath)) {
    if (Test-Path -LiteralPath $explicitPath -PathType Leaf) {
      return (Resolve-Path -LiteralPath $explicitPath).Path
    }
    return $null
  }

  foreach ($name in $names) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
  }
  return $null
}

function Resolve-Directory([string[]]$candidates) {
  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and
        (Test-Path -LiteralPath $candidate -PathType Container)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  return $null
}

function Report([string]$name, [string]$value, [bool]$required = $true) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    $state = if ($required) { "MISSING" } else { "not found" }
    Write-Host ("[{0}] {1}" -f $state, $name)
    if ($required) { $script:failures++ }
  } else {
    Write-Host ("[OK] {0}: {1}" -f $name, $value)
  }
}

function Find-Ndk([string]$sdkRoot) {
  $explicit = Resolve-Directory @(
    $env:ANDROID_NDK_ROOT,
    $env:ANDROID_NDK_HOME,
    $env:NDK_ROOT
  )
  if ($explicit) { return $explicit }
  if (-not $sdkRoot) { return $null }

  $ndkHome = Join-Path $sdkRoot "ndk"
  if (-not (Test-Path -LiteralPath $ndkHome -PathType Container)) {
    return $null
  }
  $versions = Get-ChildItem -LiteralPath $ndkHome -Directory |
    Sort-Object Name -Descending
  if ($versions) { return $versions[0].FullName }
  return $null
}

function Find-NdkTool([string]$ndkRoot, [string]$toolName) {
  if (-not $ndkRoot) { return $null }
  $hostTag = if ($IsWindows -or $env:OS -eq "Windows_NT") {
    "windows-x86_64"
  } elseif ($IsMacOS) {
    "darwin-x86_64"
  } else {
    "linux-x86_64"
  }
  $suffix = if ($IsWindows -or $env:OS -eq "Windows_NT") { ".exe" } else { "" }
  $path = Join-Path $ndkRoot "toolchains/llvm/prebuilt/$hostTag/bin/$toolName$suffix"
  if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
  return $null
}

Write-Host "Apus Engine Android toolchain doctor"
Write-Host "Target: aarch64-android, API $ApiLevel"
Write-Host ""

$compiler = Resolve-Executable $env:FPC_ANDROID @("ppcrossa64", "ppcrossa64.exe")
$binutils = Resolve-Directory @($env:FPC_ANDROID_BINUTILS)
$assemblerName = if ($IsWindows -or $env:OS -eq "Windows_NT") {
  "aarch64-linux-android-as.exe"
} else {
  "aarch64-linux-android-as"
}
$linkerName = if ($IsWindows -or $env:OS -eq "Windows_NT") {
  "aarch64-linux-android-ld.lld.exe"
} else {
  "aarch64-linux-android-ld.lld"
}
$assembler = if ($binutils) { Join-Path $binutils $assemblerName } else { $null }
$linker = if ($binutils) { Join-Path $binutils $linkerName } else { $null }
if ($assembler -and -not (Test-Path -LiteralPath $assembler -PathType Leaf)) { $assembler = $null }
if ($linker -and -not (Test-Path -LiteralPath $linker -PathType Leaf)) { $linker = $null }

$sdkRoot = Resolve-Directory @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)
$ndkRoot = Find-Ndk $sdkRoot
$javaHomeExecutable = if ($env:JAVA_HOME) {
  Join-Path $env:JAVA_HOME (if ($IsWindows -or $env:OS -eq "Windows_NT") {
    "bin/java.exe"
  } else {
    "bin/java"
  })
} else {
  $null
}
$java = Resolve-Executable $javaHomeExecutable @("java", "java.exe")
if (-not $java -and -not $javaHomeExecutable) {
  $java = Resolve-Executable $null @("java", "java.exe")
}
$readElf = Find-NdkTool $ndkRoot "llvm-readelf"

Report "FPC aarch64 Android compiler (FPC_ANDROID)" $compiler
Report "FPC Android assembler (FPC_ANDROID_BINUTILS)" $assembler
Report "FPC Android linker (FPC_ANDROID_BINUTILS)" $linker
Report "Android SDK (ANDROID_SDK_ROOT)" $sdkRoot
Report "Android NDK (ANDROID_NDK_ROOT)" $ndkRoot
Report "Java" $java
Report "NDK llvm-readelf" $readElf $false

if ($compiler) {
  $version = (& $compiler -iV 2>$null | Select-Object -First 1)
  Report "FPC version" $version
}

if ($CheckOnly) {
  Write-Host ""
  if ($script:failures -gt 0) {
    Write-Host "Toolchain is incomplete: $($script:failures) required checks failed."
    exit 1
  }
  Write-Host "Toolchain checks passed."
  exit 0
}

$nativeReady = $compiler -and $assembler -and $linker -and $ndkRoot
if (-not $nativeReady) {
  Write-Host ""
  Write-Host "Native probe skipped: compiler, GNU cross-binutils, or NDK is missing."
  Write-Host "Set the variables documented in platform/android/README.md and retry."
  exit 1
}

$hostTag = if ($IsWindows -or $env:OS -eq "Windows_NT") {
  "windows-x86_64"
} elseif ($IsMacOS) {
  "darwin-x86_64"
} else {
  "linux-x86_64"
}
$sysroot = Join-Path $ndkRoot "toolchains/llvm/prebuilt/$hostTag/sysroot"
$apiLibDir = Join-Path $sysroot "usr/lib/aarch64-linux-android/$ApiLevel"
if (-not (Test-Path -LiteralPath $apiLibDir -PathType Container)) {
  throw "NDK API library directory not found: $apiLibDir"
}

New-Item -ItemType Directory -Force -Path $unitDir | Out-Null
if (Test-Path -LiteralPath $probeLibrary) {
  Remove-Item -LiteralPath $probeLibrary -Force
}

$arguments = @(
  "-Tandroid",
  "-Paarch64",
  "-MDelphi",
  "-B",
  "-Cg",
  "-XLL",
  "-FD$binutils",
  "-XPaarch64-linux-android-",
  "-XR$sysroot",
  "-Fl$apiLibDir",
  "-FU$unitDir",
  "-FE$outputDir",
  "-o$probeLibrary",
  $probeSource
)

Write-Host ""
Write-Host "Building native probe..."
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $probeLibrary -PathType Leaf)) {
  throw "FPC reported success but did not create $probeLibrary"
}
Write-Host "[OK] Probe library: $probeLibrary"

if ($readElf) {
  $header = & $readElf -h $probeLibrary
  if ($LASTEXITCODE -ne 0 -or ($header -join "`n") -notmatch "AArch64") {
    throw "Probe is not an AArch64 ELF library"
  }
  $symbols = & $readElf --dyn-syms $probeLibrary
  if ($LASTEXITCODE -ne 0 -or ($symbols -join "`n") -notmatch "JNI_OnLoad") {
    throw "Probe does not export JNI_OnLoad"
  }
  Write-Host "[OK] AArch64 ELF and JNI_OnLoad export verified"
}

Write-Host "Android native toolchain probe passed."
if ($script:failures -gt 0) {
  Write-Host "Full APK toolchain still has $($script:failures) missing required checks."
  exit 1
}
