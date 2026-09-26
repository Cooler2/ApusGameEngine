# WebP decoder distribution

The WebP binding in Base/Apus.GfxFormats.pas uses only WebPGetInfo and
WebPDecodeRGBAInto. Build the upstream libwebp 1.6.0 webpdecoder target:
it combines the decoder objects into one library. The source release URL and
SHA-256 are pinned in build_windows.ps1 and redist/windows/SOURCES.txt.
The source archive may be supplied locally with -SourceArchive; this keeps
rebuilds possible when the upstream server is unavailable. The binary used
by games is committed under bin64/.

On Windows x64, install CMake and a MinGW-w64 x64 toolchain (gcc,
mingw32-make, objdump), then run:

    ./platform/webp/build_windows.ps1

The script extracts a fresh copy of the verified source into Work/, builds
only the decoder DLL, and checks its exports and PE imports before replacing
bin64/libwebpdecoder.dll. The accepted imports are KERNEL32.dll and
msvcrt.dll, both Windows components. It does not ship libgcc. Two clean
builds with the same GCC 15.2.0 toolchain produced the same SHA-256;
other toolchain versions may produce different bytes. Win32 is
optional and has no WebP binary in this repository.

On Linux x64, run bash platform/webp/build_linux.sh. It builds the upstream
decoder-only archive with PIC, links one private libapuswebpdecoder.so, and
rejects dependencies other than libc.so.6. The checked binary is committed in
redist/linux/. For an FPC game, define WEBP, add
`-Fl<repo>/redist/linux` and `-k-rpath -k'$ORIGIN'` at link time, and copy the
library beside the executable. The private name prevents the linker from
choosing a system libwebpdecoder. GfxFormats passes with that layout and no
LD_LIBRARY_PATH.

macOS still needs an app-bundle dylib with a controlled install name and
signing. Android needs a shared library for each packaged ABI. Keep WEBP
disabled on those targets until their binaries and loaders are tested.
iOS currently uses PNG rather than a WebP decoder.
