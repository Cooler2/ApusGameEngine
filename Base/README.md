# Apus Engine — Base Library

This directory contains the platform-independent utility library used by the Apus Game Engine.
All modules are written in Pascal (compatible with Delphi 12+ and FPC 3.2+).

## Module Overview

| Group | Modules | Description |
|-------|---------|-------------|
| **Foundation** | Core, Types, Classes, Structs, EventMan | Basic types, collections, event system |
| **Strings** | Strings, Conv | UTF-8 string operations, type conversions |
| **Geometry** | Geom2D, Geom3D, VertexLayout | 2D/3D math, vectors, matrices |
| **Graphics** | Colors, FastGFX, Images, GfxFormats, GfxFilters, Regions | Image processing, pixel formats |
| **Text** | TextUtils, UnicodeFont, FreeTypeFont, GlyphCaches | Font rendering and text layout |
| **Animation** | AnimatedValues, Tweenings | Value interpolation and easing |
| **Networking** | Socket, TCP, HttpRequests, GeoIP | Network communication |
| **Platform** | CrossPlatform | OS abstraction layer |
| **Utilities** | Utils, Logging, Files, HashMaps, Threads, Profiling, StackTrace, Clipboard, CPU | General-purpose tools |
| **Specialized** | Crypto, RSA, Database, Translation, HtmlTree, ControlFiles | Domain-specific modules |
| **Auxiliary** | ProdCons, Huffman, ADPCM, LongMath, RegExpr, SCGI | Compression, codecs, math |

## Directory Structure

```
Base/
  *.pas          — library source files (Apus.*.pas)
  deprecated/    — old units kept for reference, not for use in new projects
  extra/         — third-party units and build-time libraries
  tests/         — unit tests and benchmarks (see tests/README.md)
  tools/         — standalone utility tool projects
  doc/           — additional documentation
  bin/           — compiled output and runtime libraries
```

## Primary String Type

The library uses `String8` (UTF-8) as the primary string type. Built-in `string` is used
only where RTL interoperability requires it.

## Compatibility

All modules target both **Windows** and **Linux** on x86/x64. ARM support is in progress.
Conditional compilation (`{$IFDEF WINDOWS}`, `{$IFDEF FPC}`, etc.) is used where needed.
