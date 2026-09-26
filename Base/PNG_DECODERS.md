# R-32: PNG decoder comparison (FPC 3.2.2, Windows)

The engine selects PNG decoding at compile time. With LODEPNG it imports
LodePNG; otherwise FPC uses TFPReaderPNG and TFPMemoryImage. Keep this selection
for now. LodePNG was consistently faster in the measured cases. Runtime library
probing would add loader, ABI, and deployment behavior that these measurements
do not validate.

## Reproduce

Run GenerateR32PNGFixtures.py from Base/tests (requires Pillow and ImageMagick),
then run bench.bat R32PNG -dLODEPNG and bench.bat R32PNG. Each command builds
both x64 and x86 with -O3 and runs the freshly built program. For LodePNG,
put compatible LodePNG64.dll and LodePNG.dll in Base/tests/bin64 and bin32.
The samples are large RGBA art, small translucent UI, 8-bit palette, 8-bit
grayscale, and Adam7 interlaced RGBA art. Timing includes decode, conversion,
allocation, and release. It excludes file I/O. Full local logs are in the
worktree's ignored Work/r32_png_*.txt.

| Sample | x64 LodePNG | x64 FPC | x86 LodePNG | x86 FPC |
| --- | ---: | ---: | ---: | ---: |
| RGBA 1024x1024, 30 decodes | 1531 ms | 3985 ms | 1891 ms | 4953 ms |
| UI 128x128, 300 decodes | 203 ms | 672 ms | 266 ms | 829 ms |
| Palette 512x512, 30 decodes | 109 ms | 375 ms | 125 ms | 453 ms |
| Gray 512x512, 30 decodes | 62 ms | 578 ms | 78 ms | 656 ms |
| Adam7 RGBA 1024x1024, 30 decodes | 1563 ms | 4078 ms | 1906 ms | 5063 ms |

These are one-run wall-clock measurements on the local Windows host, not
platform-independent speed guarantees. Peak memory was not instrumented.
The FPC path constructs a TFPMemoryImage with 16-bit channels and then converts
each row into the target TRawImage; LodePNG decodes 8-bit samples directly.
Both paths currently downsample 16-bit PNG to 8-bit output. The FPC fallback
with a nil target produces ARGB even for grayscale; when the engine preallocates
a Mono8 target, the corrected shared reader now writes one byte per pixel.
The targeted grayscale decode test covers this path. Palette+tRNS, 16-bit
sample values, gamma/sRGB/iCCP interpretation, and saving need separate
fidelity tests before any decoder policy change.

The local Base/tests/LodePNG64.dll lacks lodepng_decode_memory and
lodepng_encode_memory, yet the engine imports them. That DLL fails at program
startup with an entry-point error. The local Base/bin/LodePNG64.dll exports
the required functions and was used for the measurements. Verify the DLL
exports as part of packaging before enabling LODEPNG on x64.
