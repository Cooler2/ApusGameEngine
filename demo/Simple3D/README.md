# Simple3D WebP sample

The textured cube loads res/cubetex.webp when WEBP is defined. The WebP file
is a lossless conversion of cubetex.png; their decoded RGBA pixels are identical.
Without WEBP, the demo loads the PNG. The filename is shown in the window.

The Delphi project enables WEBP on Win64. Win32 keeps the PNG path. For an
FPC x64 build, add -dWEBP to the normal Simple3D compile command. The Windows
x64 decoder DLL is already in bin64/ beside the executable. Other targets
need the libwebpdecoder library named in Base/engine5_changes.md.

The demo's executable normally runs from bin64/ or bin/ and resolves res/
through its existing baseDir logic. The asset stays in demo/Simple3D/res/.
