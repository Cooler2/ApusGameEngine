param(
  [string]$Configuration = "Debug",
  [switch]$SkipNativeBuild
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$workRoot = Join-Path $repoRoot "tmp/android"
$downloadsDir = Join-Path $workRoot "downloads"
$sourcesDir = Join-Path $workRoot "sources"
$packageDir = Join-Path $workRoot "package"
$sdlVersion = "2.30.9"
$sdlArchiveName = "SDL2-$sdlVersion.zip"
$sdlArchive = Join-Path $downloadsDir $sdlArchiveName
$sdlSource = Join-Path $sourcesDir "SDL2-$sdlVersion"
$sdlUrl = "https://github.com/libsdl-org/SDL/releases/download/release-$sdlVersion/$sdlArchiveName"
$sdlSha256 = "EC855BCD815B4B63D0C958C42C2923311C656227D6E0C1AE1E721406D346444B"
$probeLibrary = Join-Path $workRoot "libapus_android_engine_probe.so"
$overlayDir = Join-Path $scriptDir "shell"

function Copy-Overlay([string]$source, [string]$destination) {
  Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($source.Length).TrimStart('\', '/')
    $target = Join-Path $destination $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
  }
}

New-Item -ItemType Directory -Force -Path $downloadsDir, $sourcesDir | Out-Null
if (-not (Test-Path -LiteralPath $sdlArchive -PathType Leaf)) {
  Write-Host "Downloading SDL $sdlVersion..."
  Invoke-WebRequest -Uri $sdlUrl -OutFile $sdlArchive
}
$actualHash = (Get-FileHash -LiteralPath $sdlArchive -Algorithm SHA256).Hash
if ($actualHash -ne $sdlSha256) {
  throw "SDL archive hash mismatch: expected $sdlSha256, got $actualHash"
}

if (-not (Test-Path -LiteralPath $sdlSource -PathType Container)) {
  Write-Host "Extracting SDL $sdlVersion..."
  Expand-Archive -LiteralPath $sdlArchive -DestinationPath $sourcesDir
}

if (Test-Path -LiteralPath $packageDir) {
  Remove-Item -LiteralPath $packageDir -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $sdlSource "android-project") -Destination $packageDir -Recurse
Copy-Item -LiteralPath $sdlSource -Destination (Join-Path $packageDir "app/jni/SDL") -Recurse
Copy-Overlay $overlayDir $packageDir

$assetsDir = Join-Path $packageDir "app/src/main/assets"
New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot "demo/TouchDemo/sprite.png") -Destination $assetsDir

$jniLibDir = Join-Path $packageDir "app/libs/arm64-v8a"
New-Item -ItemType Directory -Force -Path $jniLibDir | Out-Null

$gradle = if ($IsWindows -or $env:OS -eq "Windows_NT") {
  Join-Path $packageDir "gradlew.bat"
} else {
  Join-Path $packageDir "gradlew"
}
if (-not ($IsWindows -or $env:OS -eq "Windows_NT")) {
  & chmod +x $gradle
}

if (-not $SkipNativeBuild) {
  $nativeTask = "externalNativeBuild$Configuration"
  Write-Host "Building SDL2 native library ($nativeTask)..."
  Push-Location $packageDir
  try {
    & $gradle --no-daemon $nativeTask
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }

  $sdlLibrary = Get-ChildItem -LiteralPath (Join-Path $packageDir "app/build/intermediates/cxx/$Configuration") `
      -Recurse -Filter "libSDL2.so" |
    Where-Object { $_.FullName -match 'obj[\\/]local[\\/]arm64-v8a' } |
    Select-Object -First 1
  if (-not $sdlLibrary) {
    throw "Gradle built SDL2 but libSDL2.so was not found"
  }
  & (Join-Path $scriptDir "toolchain.ps1") -Engine -SdlLibrary $sdlLibrary.FullName
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
if (-not (Test-Path -LiteralPath $probeLibrary -PathType Leaf)) {
  throw "Engine probe not found: $probeLibrary"
}
Copy-Item -LiteralPath $probeLibrary -Destination (Join-Path $jniLibDir "libapus_android_engine_probe.so")

$task = "assemble$Configuration"
Write-Host "Building Android package ($task)..."
Push-Location $packageDir
try {
  & $gradle --no-daemon $task
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}

$configurationName = $Configuration.ToLowerInvariant()
$apk = Join-Path $packageDir "app/build/outputs/apk/$configurationName/app-$configurationName.apk"
if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) {
  throw "Gradle completed but APK was not found: $apk"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($apk)
try {
  $entries = @($archive.Entries | ForEach-Object { $_.FullName })
  $requiredEntries = @(
    "AndroidManifest.xml",
    "classes.dex",
    "lib/arm64-v8a/libSDL2.so",
    "lib/arm64-v8a/libapus_android_engine_probe.so"
  )
  $missingEntries = @($requiredEntries | Where-Object { $_ -notin $entries })
  if ($missingEntries.Count -gt 0) {
    throw "APK is missing required entries: $($missingEntries -join ', ')"
  }
  $unexpectedAbis = @($entries | Where-Object {
    $_ -match '^lib/([^/]+)/' -and $Matches[1] -ne 'arm64-v8a'
  })
  if ($unexpectedAbis.Count -gt 0) {
    throw "APK contains libraries for unexpected ABIs: $($unexpectedAbis -join ', ')"
  }
} finally {
  $archive.Dispose()
}

Write-Host "[OK] Android APK: $apk"
Write-Host "[OK] SDL2 and the Engine5 SDL_main library are packaged for arm64-v8a"
