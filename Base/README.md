# Apus Engine — Base Library

This directory contains the platform-independent utility library used by the Apus Game Engine.
All modules are written in Pascal (compatible with Delphi 12+ and FPC 3.2+).

## Module Overview

| Group | Modules | Description |
|-------|---------|-------------|
| **Foundation** | Core, Types, Classes, Containers, HashMaps, EventMan, Lib | Basic types, collections, event system (`Lib` re-exports the foundation modules) |
| **Strings** | Strings, Conv, TextUtils | UTF-8 string operations, type conversions |
| **Geometry** | Geom2D, Geom3D, Spatial, VertexLayout | 2D/3D math, vectors, matrices, intersection tests |
| **Graphics** | Colors, FastGFX, Images, GfxFormats, GfxFilters, Regions | Image processing, pixel formats |
| **Text** | UnicodeFont, FreeTypeFont, GlyphCache | Font rendering and glyph caching |
| **Animation** | AnimatedValues, Tweenings | Value interpolation and easing |
| **Networking** | Socket, TCP, HttpRequests, HttpServer, GeoIP | Network communication |
| **Platform** | Android | Android integration |
| **Utilities** | Utils, Files, Log, Logging, Threads, Profiling, StackTrace, Clipboard, CPU, MemoryLeakUtils | General-purpose tools |
| **Specialized** | Crypto, RSA, Database, Translation, HtmlTree, ControlFiles, Publics | Domain-specific modules (`Publics`: named variables and expression evaluation) |
| **Auxiliary** | Compress, ProdCons, Huffman, ADPCM, LongMath, RegExpr, SCGI | Compression, codecs, math |

`Network` is deprecated (use `Socket`); it stays only for `Apus.Engine.UdpTransport`.

## Directory Structure

```
Base/
  Apus.*.pas     — library source files
  extra/         — third-party units and build-time libraries
  tests/         — unit tests and benchmarks (see tests/README.md)
  tools/         — small HTML helpers (bin2pas, sql2pas)
  bin/           — runtime libraries for Base tests and tools
```

## Primary String Type

The library uses `String8` (UTF-8) as the primary string type. Built-in `string` is used
only where RTL interoperability requires it.

## Compatibility

All modules target both **Windows** and **Linux** on x86/x64. ARM support is in progress.
Conditional compilation (`{$IFDEF WINDOWS}`, `{$IFDEF FPC}`, etc.) is used where needed.
