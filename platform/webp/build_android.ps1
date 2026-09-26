param([string]$SourceArchive='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$work=Join-Path $root 'Work/webp-build/android-arm64'
$archive=if($SourceArchive){(Resolve-Path $SourceArchive).Path}else{Join-Path $root 'Work/libwebp-1.6.0.tar.gz'}
$source=Join-Path $work 'libwebp-1.6.0'
$build=Join-Path $work 'build'
$output=Join-Path $root 'redist/android/arm64-v8a/libapuswebpdecoder.so'
$expectedHash='E4AB7009BF0629FD11982D4C2AA83964CF244CFFBA7347ECD39019A9E38C4564'
$sourceUrl='https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz'
$ndk=if($env:ANDROID_NDK_ROOT){$env:ANDROID_NDK_ROOT}else{'G:\android\sdk\ndk\27.3.13750724'}
$bin=Join-Path $ndk 'toolchains/llvm/prebuilt/windows-x86_64/bin'
$clang=Join-Path $bin 'aarch64-linux-android21-clang.cmd'
$readelf=Join-Path $bin 'llvm-readelf.exe'
$strip=Join-Path $bin 'llvm-strip.exe'
$toolchain=Join-Path $ndk 'build/cmake/android.toolchain.cmake'
New-Item -ItemType Directory -Path $work,(Split-Path $output),(Split-Path $archive) -Force | Out-Null
if(!(Test-Path -LiteralPath $archive -PathType Leaf)){
  if($SourceArchive){throw "Source archive not found: $archive"}
  Invoke-WebRequest -Uri $sourceUrl -OutFile $archive
}
foreach($p in @($clang,$readelf,$strip,$toolchain)){if(!(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing: $p"}}
if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash){throw 'Source archive hash mismatch'}
New-Item -ItemType Directory -Path $work,(Split-Path $output) -Force | Out-Null
$workPath=[IO.Path]::GetFullPath($work).TrimEnd('\')
foreach($parent in @($root,(Join-Path $root 'Work'),(Join-Path $root 'Work/webp-build'),$workPath)){
  if((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Junction in build path: $parent"}
}
foreach($target in @($source,$build)){
  $full=[IO.Path]::GetFullPath($target)
  if(!$full.StartsWith($workPath+'\',[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe build path: $full"}
  if(Test-Path -LiteralPath $full){
    if((Get-Item -LiteralPath $full).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Junction: $full"}
    Remove-Item -LiteralPath $full -Recurse -Force
  }
}
tar -xzf $archive -C $work
if($LASTEXITCODE -ne 0){throw 'Source extraction failed'}
$cmake=(Get-Command cmake -ErrorAction Stop).Source
$ninja=(Get-Command ninja -ErrorAction Stop).Source
& $cmake -S $source -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$ninja" "-DCMAKE_TOOLCHAIN_FILE=$toolchain" '-DANDROID_ABI=arm64-v8a' '-DANDROID_PLATFORM=android-21' '-DCMAKE_BUILD_TYPE=Release' '-DBUILD_SHARED_LIBS=OFF' '-DWEBP_USE_THREAD=OFF' '-DWEBP_BUILD_ANIM_UTILS=OFF' '-DWEBP_BUILD_CWEBP=OFF' '-DWEBP_BUILD_DWEBP=OFF' '-DWEBP_BUILD_EXTRAS=OFF' '-DWEBP_BUILD_GIF2WEBP=OFF' '-DWEBP_BUILD_IMG2WEBP=OFF' '-DWEBP_BUILD_LIBWEBPMUX=OFF' '-DWEBP_BUILD_VWEBP=OFF' '-DWEBP_BUILD_WEBPINFO=OFF' '-DWEBP_BUILD_WEBPMUX=OFF'
if($LASTEXITCODE -ne 0){throw 'CMake configure failed'}
& $cmake --build $build --target webpdecoder -j 4
if($LASTEXITCODE -ne 0){throw 'WebP decoder build failed'}
$static=Join-Path $build 'libwebpdecoder.a'
if(!(Test-Path -LiteralPath $static)){throw "Missing static decoder: $static"}
& $clang -shared '-Wl,-soname,libapuswebpdecoder.so' '-Wl,--whole-archive' $static '-Wl,--no-whole-archive' -o $output
if($LASTEXITCODE -ne 0){throw 'Android shared library link failed'}
& $strip --strip-unneeded $output
if($LASTEXITCODE -ne 0){throw 'Android shared library strip failed'}
$header=& $readelf -h $output
if(!($header | Select-String 'AArch64')){throw 'Wrong ELF architecture'}
$dynamic=& $readelf -d $output
$needed=@($dynamic | Select-String 'NEEDED' | ForEach-Object {if($_.Line -match '\[([^]]+)\]'){$Matches[1]}})
$unexpected=@($needed | Where-Object {$_ -notin @('libc.so','libm.so','libdl.so')})
if($unexpected.Count){throw "Unexpected dependencies: $($unexpected -join ', ')"}
if(!($dynamic | Select-String 'libapuswebpdecoder.so')){throw 'Wrong SONAME'}
$symbols=& $readelf --dyn-syms $output
foreach($name in @('WebPGetInfo','WebPDecodeRGBAInto')){if(!($symbols | Select-String " $name$")){throw "Missing export: $name"}}
Write-Output "Wrote $output"
Write-Output "SHA-256: $((Get-FileHash $output -Algorithm SHA256).Hash)"
Write-Output "Dependencies: $($needed -join ', ')"
