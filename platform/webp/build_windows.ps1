param(
  [string]$SourceArchive = ''
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$work = Join-Path $root 'Work/webp-build'
$archive = if ($SourceArchive) { (Resolve-Path $SourceArchive).Path } else { Join-Path $work 'libwebp-1.6.0.tar.gz' }
$source = Join-Path $work 'libwebp-1.6.0'
$build = Join-Path $work 'win64'
$output = Join-Path $root 'bin64/libwebpdecoder.dll'
$url = 'https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz'
$expectedHash = 'E4AB7009BF0629FD11982D4C2AA83964CF244CFFBA7347ECD39019A9E38C4564'

New-Item -ItemType Directory -Path $work -Force | Out-Null
if (!(Test-Path -LiteralPath $archive)) {
  if ($SourceArchive) { throw "Source archive not found: $archive" }
  Invoke-WebRequest -Uri $url -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash) {
  throw "Source archive hash mismatch: $archive"
}

# Always rebuild from the verified archive rather than reusing modified source.
# Check absolute paths and junctions before recursive removal.
$workPath = [IO.Path]::GetFullPath($work).TrimEnd('\')
foreach ($parent in @($root, (Join-Path $root 'Work'), $workPath)) {
  if ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "Build path contains a junction: $parent"
  }
}
foreach ($target in @($source, $build)) {
  $targetPath = [IO.Path]::GetFullPath($target)
  if (!$targetPath.StartsWith($workPath + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unexpected build path: $targetPath"
  }
  if (Test-Path -LiteralPath $targetPath) {
    if ((Get-Item -LiteralPath $targetPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
      throw "Build path is a junction: $targetPath"
    }
    Remove-Item -LiteralPath $targetPath -Recurse -Force
  }
}
tar -xzf $archive -C $work
if ($LASTEXITCODE -ne 0) { throw 'Could not extract libwebp source' }

$cmake = (Get-Command cmake -ErrorAction Stop).Source
$gcc = (Get-Command gcc -ErrorAction Stop).Source
$toolDir = Split-Path $gcc
$make = Join-Path $toolDir 'mingw32-make.exe'
$objdump = Join-Path $toolDir 'objdump.exe'
if (!(Test-Path -LiteralPath $make) -or !(Test-Path -LiteralPath $objdump)) {
  throw 'gcc, mingw32-make, and objdump must come from the same MinGW-w64 toolchain'
}
if ((& $gcc -dumpmachine) -ne 'x86_64-w64-mingw32') {
  throw 'The WebP Windows build requires an x86_64-w64-mingw32 compiler'
}

$options = @(
  '-G', 'MinGW Makefiles',
  "-DCMAKE_C_COMPILER=$gcc",
  "-DCMAKE_MAKE_PROGRAM=$make",
  '-DCMAKE_BUILD_TYPE=Release',
  '-DCMAKE_SHARED_LINKER_FLAGS=-static-libgcc -Wl,--no-insert-timestamp',
  '-DBUILD_SHARED_LIBS=ON',
  '-DWEBP_USE_THREAD=OFF',
  '-DWEBP_BUILD_ANIM_UTILS=OFF',
  '-DWEBP_BUILD_CWEBP=OFF',
  '-DWEBP_BUILD_DWEBP=OFF',
  '-DWEBP_BUILD_EXTRAS=OFF',
  '-DWEBP_BUILD_GIF2WEBP=OFF',
  '-DWEBP_BUILD_IMG2WEBP=OFF',
  '-DWEBP_BUILD_LIBWEBPMUX=OFF',
  '-DWEBP_BUILD_VWEBP=OFF',
  '-DWEBP_BUILD_WEBPINFO=OFF',
  '-DWEBP_BUILD_WEBPMUX=OFF'
)
& $cmake -S $source -B $build @options
if ($LASTEXITCODE -ne 0) { throw 'CMake configure failed' }
& $cmake --build $build --target webpdecoder --config Release -j 4
if ($LASTEXITCODE -ne 0) { throw 'WebP decoder build failed' }

$built = Join-Path $build 'libwebpdecoder.dll'
$imports = @(& $objdump -p $built | Select-String 'DLL Name:' | ForEach-Object { ($_.Line -split ':', 2)[1].Trim().ToLowerInvariant() })
$unexpected = @($imports | Where-Object { $_ -notin @('kernel32.dll', 'msvcrt.dll') })
if ($unexpected.Count -ne 0) { throw "Unexpected DLL imports: $($unexpected -join ', ')" }
$exports = & $objdump -p $built
foreach ($name in @('WebPGetInfo', 'WebPDecodeRGBAInto')) {
  if (!($exports | Select-String -SimpleMatch $name)) { throw "Missing export: $name" }
}

Copy-Item -LiteralPath $built -Destination $output -Force
Write-Output "Wrote $output"
Write-Output "SHA-256: $((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash)"
Write-Output "Imports: $($imports -join ', ')"
