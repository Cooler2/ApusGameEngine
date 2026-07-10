# Engine5 Refactoring — Function Rename Registry

This file tracks all functions extracted from `Apus.Common` into new modules.
Use it as the primary reference when updating old code.

## Android JNI VM state (2026-07-10)

- `jni.curVM` is now mutable. Android initialization stores the `PJavaVM`
  supplied by JNI so `Apus.Android` can attach and detach engine worker threads.

## Platform-native text line endings (2026-07-03)

- `Apus.Core.LineBreak` provides the current platform's native text line
  terminator: CRLF on Windows and LF on Unix-like systems.
- Robot API responses and the engine diagnostics used by Robot API handlers now
  use `LineBreak`; wire protocols that require CRLF remain unchanged.
- `Apus.Log` and `Apus.Logging` write native line endings to their log files and
  caches instead of forcing Windows CRLF on every platform.

## Glyph cache diagnostics and bounds fixes (2026-06-29)

- `Apus.GlyphCache` now rejects items that cannot fit the concrete atlas region
  before entering the band allocator. Packed glyph metadata supports dimensions
  up to 255x255; the older 63x63 comment was stale.
- Generic `DGC: cache overflow` errors now distinguish atlas-space exhaustion
  from exhaustion of internal band descriptors and include the requested band,
  atlas dimensions, and allocator state.
- `Apus.Engine.TextDraw` checks the fixed glyph-update rectangle list before
  writing a new entry, preventing a range-check exception in the diagnostic path.

## Socket API compatibility fixes (2026-06-28)

- `Apus.Socket.recv` and `send` now use the Delphi/FPC-compatible
  `NativeUInt` type for buffer length instead of the FPC-specific `SizeUInt`.
- `Apus.Socket.WSAAccept` uses `UIntPtr` for its callback data instead of the
  FPC-specific `PtrUInt` spelling.

## Thread lifecycle changes (2026-06-27)

- `Apus.HttpRequests` now launches request workers through
  `Apus.Threads.Thread.Start` and tracks them as `IThread`; the legacy
  `Classes.TThread` subclass and `Resume` lifecycle are gone.
- Unhandled exceptions escaping a `Thread.Start` callback are now written with
  `Log.Force`, including the thread name, exception class, and message, before
  the corresponding `IThread` enters the error state.
- `Apus.Threads` now notifies `Apus.EventMan` when a thread exits. Any queued or
  mixed handlers still owned by that thread are removed, its pending events are
  discarded, and a warning lists each dangling event registration together with
  its handler address.

## Status note (2026-03-22)

- R-07 is confirmed working and merged into `engine5`.
- Base migration track is complete (100%): no active `Apus.Common` dependencies remain in live `Base/*.pas` modules.
- `Base/Apus.Common.pas` was removed; compatibility unit is kept only in `Base/Deprecated/Apus.Common.pas`.
- No global/blocking migration tasks remain in Base; current focus is support/development:
  - Linux fixes and verification;
  - benchmark runs and baseline tracking;
  - SSE optimization for highest-impact functions;
  - ongoing bugfixes with test coverage expansion.

## Recent API fixes (2026-05-29)

### Engine networking module names

- Renamed `Apus.Engine.Networking2` to `Apus.Engine.UdpTransport`.
- The module is the symmetric UDP transport layer: packets/sessions/ping/LAN discovery with `Connect` and `Accept`.
- Updated EngineTest project references and signal inventory docs to use the new name.

### Apus.Core typed row-pointer helpers

- Added shared zero-based row-pointer helper types in `Apus.Core` for typed raw-buffer indexing:
  - `TByteRow` / `PByteRow`
  - `TWordRow` / `PWordRow`
  - `TIntRow` / `PIntRow`
  - `TCardinalRow` / `PCardinalRow`
  - `TSingleRow` / `PSingleRow`
- Motivation: make Delphi/FPC-safe row casts explicit and reusable in image/buffer code, for example `PCardinalRow(data)^[i]`. Row types use a large upper bound so indexed access also works with range checking enabled.
- Added `TTexture.ScanLine(y):pointer` and `TTexture.PixelPtr(x,y):pointer` in `Apus.Engine.Resources` so locked texture code can use `PCardinalRow(tex.ScanLine(y))` or address a concrete pixel without repeating raw `data+pitch` arithmetic.

### Engine Linux SDL/OpenGL compile sweep

- Fixed `Apus.Engine.API` display-mode exports for API-only users:
  - `TDisplayScaleMode` now aliases `Apus.Engine.Types.TDisplayScaleMode`.
- Fixed Linux SDL mouse-button cursor handling to call `systemPlatform.SetCursor`.
- Updated `tests/PlatformTest.dpr` and `tests/OpenGL.dpr` to the current `TWindow`/`IGraphicsSystem` lifecycle and modern Base units instead of deprecated `Apus.Common`.
- Fixed case-sensitive include lookup in `tests/TestStyle.dpr` (`Test.inc`).
- Linux/FPC compile-only checks now pass for:
  - `tests/PlatformTest.dpr`
  - `tests/OpenGL.dpr`
  - `demo/SimpleDemo/SimpleDemo.dpr`
  - `demo/StyleDemo/StyleDemo.dpr`
  - `demo/MultiWindow/MultiWindow.dpr`
  - `demo/Draw2D/Draw2D.dpr`
  - `demo/InputDemo/InputDemo.dpr`
  - `demo/UI/UI.dpr`
  - `demo/TextDemo/TextDemo.dpr`
  - `demo/Tweenings/Tweenings.dpr`
- Linux/FPC runtime check now passes for:
  - `tests/TestStyle.dpr`
- Added `tests/linux_smoke.sh` to run these Linux/FPC checks without leaving build artifacts in the repository.

### Base Linux socket compatibility

- Extended `Apus.Socket` into the shared socket compatibility layer for the WinSock-style calls still used by legacy Base network modules.
- `Apus.TCP` and `Apus.SCGI` now depend on `Apus.Socket` instead of importing platform socket units directly.
- Unix-only resolver bindings are kept behind `{$IFDEF UNIX}` inside `Apus.Socket`.
- Linux/FPC compile sweep now includes:
  - `Apus.Socket`
  - `Apus.TCP`
  - `Apus.SCGI`
  - `Apus.Compress`
- `Apus.Profiling` remains Windows-only because its implementation directly uses the Windows unit.

### Base Linux runtime validation

- Updated `Base/tests/TestConv.dpr` to the current `Conv` API:
  - IP formatting uses `Conv.FormatIp(cardinal)`.
  - `Conv.ToStr(boolean)` expectations match the documented `short=false` default.
- `TestConv` now compiles and passes on Linux/FPC (`135` checks).
- Fixed Linux/FPC thread startup: POSIX `BeginThread` returns a `pthread_t`, which
  must not be assigned through the narrower `THandle` type before being stored as
  `TThreadID`.
- `TestThreads` now passes on Linux/FPC (`65` checks); `TestEventMan` concurrent
  thread scenarios also run without range-check exceptions.
- Fixed `Apus.EventMan.Link` to preserve the linked event name casing passed by
  the caller. Matching remains case-insensitive, while handlers now receive the
  same spelling behavior as direct `Signal` calls.
- `TestEventMan` now passes on Linux/FPC (`39` checks).
- Fixed zero-length `TVec2.Normalize` and `TVec2d.Normalize` to produce explicit
  NaN coordinates without executing runtime `0/0`. `IsValid` now uses `IsNan`
  for the first coordinate instead of a trap-prone NaN self-comparison.
- `TestGeom2D` now passes on Linux/FPC (`78` checks).
- Disabled Win64-ABI-only `TMat4` SSE helpers on Linux x64 so System V builds
  use the existing Pascal fallback for matrix multiplication and Vec4 point/normal transforms.
- `TestGeom3D` now passes on Linux/FPC (`80` checks).
- Fixed `Base/tests/test.sh` to return compilation and runtime failures to its
  caller. Added `Base/tests/test_all.sh` for the deterministic Linux-compatible
  Base regression set.
- Implemented SDL shared OpenGL context lifecycle for secondary windows,
  including cross-thread handoff, context sharing, reactivation, and
  per-context VAO setup for core profiles. Verified `MultiWindow` secondary
  startup and shutdown on Linux/WSL with a live `Tool 1` window.
- Added `cthreads` as the first unit for FPC/Unix builds of maintained demo
  entrypoints so engine applications can start thread-backed game loops on Linux.
- Implemented SDL scan-code to virtual-key mapping instead of returning an
  uninitialized value from `TSDLPlatform.MapScanCodeToVirtualKey`.
- Fixed SDL controller initialization to skip `InitJoystick(0)` when no
  joysticks are connected.
- Fixed SDL screen-coordinate helpers: `ScreenToClient` now subtracts the
  native window position, and `GetMousePos` uses `SDL_GetGlobalMouseState`.
- Made SDL window termination state per-window and routed close events by SDL
  window ID, so closing a secondary window does not terminate every window.
  Verified on Linux/WSL by closing a live `Tool 1` window while the main loop
  continued running.

## Recent API fixes (2026-03-22)

### Apus.Geom2D TRect2 point containment API

- Extended `TRect2` with point-containment methods:
  - `Contains(const p:TPoint):boolean`
  - `Contains(x,y:single):boolean`
- Motivation: remove duplicated inline point-in-rect checks in Engine code and standardize containment logic in the geometry type itself.
- Engine usage updated to call type methods directly (`TWindow.MouseInRect/MouseWasInRect`), avoiding unit-local helper functions.

### Apus.Core.Time high-precision monotonic ticks

- Added explicit high-precision monotonic time API in `Apus.Core.Time`:
  - `Time.TicksUs:int64` — microseconds since program start (QPC/clock_gettime based)
  - `Time.TicksSec:double` — seconds since program start (QPC/clock_gettime based)
- Clarified split of responsibilities:
  - `Time.Ticks` stays as coarse millisecond API for compatibility/timeouts
  - `TicksUs/TicksSec` are the preferred source for frame/input/profiling precision paths
- Added benchmark coverage in `Base/tests/BenchCore.dpr`:
  - `Time.Ticks`
  - `Time.TicksUs`
  - `Time.TicksSec`

## Recent API fixes (2026-03-23)

### Apus.Core.Time test-time override hook

- Added optional monotonic time override hook in `Apus.Core` for deterministic time-based tests.
- API is available only under `{$IFDEF TIME_OVERRIDE}`:
  - `Time.Override(timeUs:int64)` where `timeUs` is microseconds since program start.
- Time behavior under `TIME_OVERRIDE`:
  - if override value is non-zero, `Time.TicksUs` returns it directly;
  - `Time.Ticks` is derived from override as `timeUs div 1000`;
  - `Time.TicksSec` is derived from override as `timeUs * 1e-6`;
  - if override is zero, normal platform clock path is used.
- With `TIME_OVERRIDE` undefined, override code is not compiled and has zero runtime overhead.
- Test harness integration:
  - `Base/tests/test.bat` and `Base/tests/test.sh` now compile tests with `-dTIME_OVERRIDE` by default.
  - `Base/tests/TestCore.dpr` includes explicit `Time override` coverage.
  - `Base/tests/TestTweenings.dpr` uses virtual time path under `TIME_OVERRIDE` (with fallback to `Sleep` when define is off).

### Animation benchmark coverage

- Added `Base/tests/BenchAnimation.dpr` as a unified benchmark comparing `TTweening` and `TAnimatedValue` on matched scenarios:
  - active-animation read path (linear/easeOut);
  - retarget path with realistic overlap cap (<=3).
- Added `Animation` to available benchmark list in `Base/tests/README.md`.

## Recent API fixes (2026-03-24)

### Apus.Core stable SRound semantics across code paths

- Clarified and documented rounding helper intent in `Apus.Core`:
  - `PRound` is symmetric nearest (away from zero on `.5`);
  - `SRound` is rendering-stable nearest defined as `floor(v+0.5)`.
- Updated non-ASM `SRound` fallback to match SSE behavior exactly (`floor(v+0.5)`), replacing old `trunc(v+0.5)` fallback.
- Motivation:
  - keep identical rounding behavior across CPU/compiler paths;
  - preserve translation invariance used by rendering math: `SRound(x+1)=SRound(x)+1`.

### Apus.Files object-style TFileHandle I/O

- `TFileHandle` in `Apus.Files` is now an opaque record with object-style methods:
  - `Read(buf,size):integer`
  - `Write(buf,size):integer`
  - `Seek(offset,origin):int64`
  - `Close`
- These methods are thin wrappers over existing `Files.Read/Write/Seek/Close` and keep provider-chain behavior unchanged.
- Existing static handle API in `Files` remains available for compatibility.
- Added ergonomic untyped-buffer overloads:
  - `Read(var buf; size:integer)`
  - `Write(const buf; size:integer)`
  in `TFileHandle`.
- Safety tweak: raw-pointer access in `TFileHandle` is explicit (`ReadMem/WriteMem`) to avoid overload ambiguity with pointer-value serialization (`Write(ptr,sizeof(ptr))` writes pointer value via `const buf` overload).

## Recent API fixes (2026-03-14)

### Apus.EventMan thread-aware handler deduplication

- Fixed `SetEventHandler` deduplication identity for concurrent registrations:
  - before: duplicate check used only `(event,handler)`;
  - now: duplicate check uses `(event,handler,threadNum,mode)`.
- Effect: the same handler can be registered for the same event in multiple threads when using `emQueued/emMixed`, and each thread receives its own queued callback.
- Added regression coverage in `Base/tests/TestEventMan.dpr`:
  - concurrent unique-handler registration;
  - concurrent duplicate registration (same thread identity semantics);
  - queued same-handler registration in many threads (one callback per thread).

## Recent API fixes (2026-03-19)

### Apus.Utils command-line helpers restored

- Restored legacy command-line helpers in `Apus.Utils`:
  - `HasParam(const name:string):boolean`
  - `GetParam(const name:string):string`
- Source parity note: implementation moved from deprecated `Apus.Common` (`SameText` search across `ParamStr`).
- Engine integration:
  - `Apus.Engine.GameApp.Prepare` now uses `HasParam/GetParam` for platform selection (`-SDL`, `-WINDOWS`, `-PLATFORM=...`).

## Recent API fixes (2026-03-11)

### Apus.Spatial module skeleton

- Added new base module: `Base/Apus.Spatial.pas`.
- Introduced engine5-first geometry names and spatial primitives:
  - `TVec2`, `TVec3` (12 bytes), `TVec4`
  - `TMat2`, `TMat3`, `TMat34`, `TMat4`
  - `TRay`, `TSphere`, `TFrustum`
- Added methods-first intersection API:
  - `TRay.IntersectsSphere/IntersectsBox/IntersectsTriangle`
  - `TSphere.ContainsPoint/IntersectsSphere/IntersectsBox`
  - `TFrustum.InitFromMVP/IntersectsSphere/IntersectsBox`
  - `TFrustum.InitFromMVP(...;includeNearFar:boolean=true)` supports 4-plane mode for parallel/orthographic projection culling.
- Extended existing box type via helper:
  - `TBBox3sHelper.IncludePoint/IncludeBox/Center/Extents/ContainsPoint/IntersectsBox/IntersectsSphere`
- Added scoped static helpers in `TSpatial` (`Dot3`, `Cross3`, `Distance2`) to avoid global function sprawl.
- Compilation check: `Apus.Spatial.pas` builds with FPC in Delphi mode.

## Recent API fixes (2026-02-26)

### Apus.Files BOM-aware text I/O

- `Files.LoadAsString(fname,...)` now strips UTF-8 BOM when reading from file start (`startFrom=0`).
- `Files.Save(fname,data:String8)` now writes UTF-8 BOM by default.
- Added overload: `Files.Save(fname,data:String8;addBOM:boolean)` for explicit control.
  - Use `addBOM=false` for raw text/binary-like writes where byte-exact layout matters.

### Apus.Utils enum helper extraction

- Added `GetEnumNameSafe(typeInfo:pointer;value:integer):string` to `Apus.Utils`.
- Behavior matches legacy `Apus.Common`:
  - returns `GetEnumName(PTypeInfo(typeInfo),value)` when `typeInfo<>nil`
  - returns fallback string `ENUM_<value>` when `typeInfo=nil`
- Migration note: replace legacy implicit access via `Apus.Common` with explicit `uses Apus.Utils`.

### Apus.FreeTypeFont String32 migration

- `Apus.FreeTypeFont` public text API migrated from UTF-16 (`WideString`/`WideChar`) to UCS-4 (`String32`/`Char32`):
  - `RenderText(...;st:String32;...)`
  - `GetTextWidth(st:String32;...)`
  - `Interval(ch1,ch2:Char32;...)`
  - `CharPadding(ch:Char32;...)`
  - `RenderGlyph(ch:Char32;...)`
- Internal hash records now store `Char32` and `integer` metric fields to avoid truncation.
- FreeType calls now pass full codepoints (`cardinal(ch)`) instead of 16-bit truncation.

### Apus.Strings String32Helper ASCII accessors

- Added `String32Helper.TryAnsiChar(index:integer;out ch:AnsiChar):boolean` (0-based).
- Added `String32Helper.AnsiChar(index:integer;defaultChar:AnsiChar=#0):AnsiChar` (0-based).
- Purpose: simplify migration of parser code that operates on ASCII tags while input is `String32`.

### Apus.Strings String32 split overload parity

- Added `String32Helper.Split(const delimiters:String32;quoteChar:UCS4Char=0):Strings32`.
- Behavior mirrors `String8.Split(const delimiters:String8;quoteChar:AnsiChar=#0)`:
  - split by any delimiter char from the set
  - ignore delimiters while inside quoted fragments
  - keep quote characters in resulting tokens

### Apus.Core IntArray helper

- Added `IntArrayHelper` in `Apus.Core` with methods:
  - `IndexOf(value:integer):integer`
  - `Contains(value:integer):boolean`
  - `Add(value:integer)`
  - `Remove(value:integer):boolean`
- Migration note: replace legacy `FindInteger(arr,v)` with `arr.IndexOf(v)`.

### Apus.Threads TLock.Enter caller override

- `TLock.Enter` now accepts optional parameter: `procedure Enter(callerAddr:pointer=nil);`
- Use this in wrapper helpers to pass caller from higher stack frame, so lock diagnostics store meaningful owner/trying addresses.

## Recent API fixes (2026-02-22)

### Apus.Strings search API (case-insensitive support)

- `IndexOf/LastIndexOf/Contains` for `String8` and `String32` now support optional `ignoreCase`.
- Migration note: `PosFrom(..., ignoreCase=true)` must be rewritten manually to `st.IndexOf(..., true)` (tool marks TODO).

### Apus.HtmlTree UTF-8 API migration

- `Apus.HtmlTree` public API is now `String8`-based (`ParseHTML`, `DecodeHTMLString`, node text/tag/attributes helpers).
- Local `PosFrom` helper removed; module uses `String8.IndexOf(...,ignoreCase)` from `Apus.Strings`.

## Recent API fixes (2026-02-19)

### Apus.Core `Min/Max` return type corrections

Fixed incorrect return types that could truncate values:

| Old signature | New signature |
|---|---|
| `Min(a,b:cardinal):integer` | `Min(a,b:cardinal):cardinal` |
| `Min(a,b:int64):integer` | `Min(a,b:int64):int64` |
| `Min(a,b:uint64):integer` | `Min(a,b:uint64):uint64` |
| `Max(a,b:cardinal):integer` | `Max(a,b:cardinal):cardinal` |
| `Max(a,b:int64):integer` | `Max(a,b:int64):int64` |
| `Max(a,b:uint64):integer` | `Max(a,b:uint64):uint64` |
| `Min(a,b,c:single):integer` | `Min(a,b,c:single):single` |
| `Max(a,b,c:single):integer` | `Max(a,b,c:single):single` |

Implementation of `Min/Max(a,b,c:single)` was also fixed to compare `single` values directly (no `trunc()`).

## Apus.Colors (2026-06-09)

Global free functions replaced with static methods on `type Color = record`.
`BilinearMixF` (scalar) and `BilinearMix(values:PCardinal,u,v)` (SSE pointer overload) remain free functions.
`Color`, `TARGBColor`, `InvalidColor` are re-exported from `Apus.Lib`.

**Gotcha:** Pascal is case-insensitive — a local var named `color:cardinal` shadows the `Color` type.
Rename any such local to `col` or a more specific name before calling `Color.XXX()`.

| Old name | New name (Color record) | Notes |
|---|---|---|
| `MyColor(r,g,b)` | `Color.RGB(r,g,b)` | |
| `MyColor(a,r,g,b)` | `Color.ARGB(a,r,g,b)` | |
| `MyColorF(a,r,g,b)` | `Color.ARGBf(a,r,g,b)` | |
| `GrayColor(gray)` | `Color.Gray(gray)` | |
| `GrayAlpha(alpha)` | `Color.GrayAlpha(alpha)` | |
| `GetAlpha(color)` | `Color.Alpha(color)` | |
| `IsSemiTransparent(color)` | `Color.HasAlpha(color)` | |
| `SwapColor(color)` | `Color.Swap(color)` | |
| `ColorAdd(c1,c2)` | `Color.Add(c1,c2)` | |
| `ColorSub(c1,c2)` | `Color.Sub(c1,c2)` | |
| `ColorMult2(c1,c2)` | `Color.Mult(c1,c2)` | |
| `ColorAlpha(color,alpha)` | `Color.Scale(color,alpha)` | multiplies alpha channel |
| `ReplaceAlpha(color,alpha)` | `Color.SetAlpha(color,alpha)` | replaces alpha channel |
| `ColorMix(c1,c2,value:integer)` | `Color.Mix(c1,c2,value:integer)` | |
| `ColorMixF(c1,c2,t:single)` | `Color.Mix(c1,c2,t:single)` | |
| `ColorBlend(c1,c2,value:integer)` | `Color.Blend(c1,c2,value:integer)` | |
| `ColorBlendF(c1,c2,value:single)` | `Color.Blend(c1,c2,value:single)` | |
| `Blend(background,foreground)` | `Color.Blend(background,foreground)` | alpha-blend overload |
| `BilinearMix(c0,c1,c2,c3,u,v)` | `Color.BilinearMix(c0,c1,c2,c3,u,v)` | 4-arg cardinal overload |
| `BilinearBlend(c0,c1,c2,c3,v1,v2)` | `Color.BilinearBlend(c0,c1,c2,c3,v1,v2)` | |
| `Lightness(color)` | `Color.Lightness(color)` | |
| `ColorDiff(c1,c2)` | `Color.Diff(c1,c2)` | |
| `SimpleColorDiff(c1,c2)` | `Color.SimpleDiff(c1,c2)` | |
| `Brightness(c,value)` | `Color.Brighten(c,value)` | renamed |
| `Contrast(c,value)` | `Color.Contrast(c,value)` | same name |
| `BilinearMixF(v0,v1,v2,v3,u,v)` | `BilinearMixF(...)` | **stays free function** |
| `BilinearMix(values:PCardinal,u,v)` | `BilinearMix(values:PCardinal,u,v)` | **stays free function** (SSE) |

## Apus.Core (low-level math, memory, bits, time, exceptions)

| Old name (Common) | New name (Core) | Notes |
|---|---|---|
| `min2(a,b)` | `Min(a,b)` | overloads for integer/single/double |
| `max2(a,b)` | `Max(a,b)` | overloads for integer/single/double |
| `min2d(a,b)` | `Min(a,b:double)` | merged into Min overloads |
| `max2d(a,b)` | `Max(a,b:double)` | merged into Max overloads |
| `min2s(a,b)` | `Min(a,b:single)` | merged into Min overloads |
| `max2s(a,b)` | `Max(a,b:single)` | merged into Max overloads |
| `Clamp(v,min,max)` | `Clamp(v,min,max)` | same name, added single/double overloads |
| `Sat(v,0,255)` | `Sat(v)` | now clamps to 0..1 (single/double) |
| `Swap(a,b)` | `Swap(a,b)` | same name |
| `GetPow2(v)` | `NextPow2(v)` | renamed for clarity (next power of two) |
| `Pow2(e)` | `Pow2(e)` | same name |
| `Log2i(v)` | `Log2i(v)` | same name |
| `HasFlag(v,flag)` | `Bits.HasAll(v,flag)` | |
| `SetFlag(v,flag)` | `Bits.SetFlag(v,flag)` | |
| `GetBit(data,idx)` | `Bits.Get(data,idx)` | |
| `SetBit(data,idx,val)` | `Bits.SetBit(data,idx,val)` | |
| `GetBits(data,idx,size)` | `Bits.GetBits(data,idx,size)` | overload for cardinal |
| `SetBits(data,idx,size,val)` | `Bits.SetBits(data,idx,size,val)` | overloads for byte/word/cardinal/uint64 |
| `ZeroMem(data,size)` | `Mem.Clear(data,size)` | |
| `Toggle(b)` | `Toggle(b)` | same name |
| `Wrap(v,max:single)` | `Wrap(v,max:single)` | same name; with fast path for in-range values |
| `Wrap(v,max:double)` | `Wrap(v,max:double)` | same name |
| `FRound(v:double)` | `FRound(v:double)` | same name; fast round (biased +epsilon) |
| `PRound(v:double)` | `PRound(v:double)` | same name; precise round |
| `SRound(v:single)` | `SRound(v:single)` | same name; SSE-accelerated, Pascal fallback for ARM |
| `HasValue(v)` | `HasValue(v)` | moved from Apus.Conv to Apus.Core; checks if variant is not unassigned |

### Stack trace support (new in engine5)

Namespace-style API for stack inspection:

| Method | Signature | Notes |
|---|---|---|
| `Stack.Caller` | `class function Caller: pointer` | Get immediate caller address using system API. For **fast caller** use intrinsics: `{$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF}` |
| `Stack.Trace` | `class function Trace(var frames: TCallStack; skip: integer = 0): integer` | Capture up to 4 call stack frames. Returns actual count. Used in exceptions/logging. |

Types:
- `TCallStack = array[0..3] of pointer` — fixed array for 4 stack frames

**Performance:** `Stack.Caller` is **~50-200 cycles** (system call). Intrinsic version is **~3-7 cycles** but requires inline usage.

Exception classes moved from `Apus.Classes` to `Apus.Core`:

| Old location (Classes) | New location (Core) | Notes |
|---|---|---|
| `TBaseException` | `TBaseException` | same name, base class with stack trace using `Stack.Trace` |
| `EWarning` | `EWarning` | same name |
| `EError` | `EError` | same name |
| `EFatalError` | `EFatalError` | same name |

**Note:** In engine5, `EBaseException` uses `Stack.Trace` to capture call stack on all platforms (previously only worked on x86 32-bit). Exception message format: `[addr1->addr2->addr3] Error message`

### Time scope (new in engine5)

Unified time API replacing fragmented functions:

| Old name | New name (Time) | Notes |
|---|---|---|
| `GetTickCount` (32-bit) | `Time.Ticks` | **REMOVED** — old 32-bit version (overflow every 49 days) |
| `GetTickCount64` | `Time.Ticks` | 64-bit monotonic time in ms, cross-platform |
| `MyTickCount` | `Time.Ticks` | better replacement with no overflow |
| `Sleep(ms)` | `Time.Sleep(ms)` | moved to Time scope |
| `Time.Now` | `Time.Now` | same — high-precision local datetime |
| `Time.UTC` | `Time.UTC` | same — high-precision UTC datetime |
| `Time.Stamp` | `Time.Stamp` | same — HH:MM:SS.mmm for logs |

**High-resolution timer** (`Timer` scope in Apus.Core):
- `Timer.Start(out t)` / `Timer.Get(t):double` — explicit timer, returns seconds
- `Timer.Start` / `Timer.Get` — implicit internal timer (parameterless)

Exception helper functions moved from `Apus.Common` to `Apus.Core`:

| Old location (Common) | New location (Core) | Notes |
|---|---|---|
| `ExceptionMsg(e)` | `ExceptionMsg(e)` | Returns exception message with address and stack trace. For `EBaseException` uses already captured stack. |
| `NotImplemented(msg)` | `NotImplemented(msg)` | Raises `EError` with "Not implemented: msg". Inline. |
| `NotSupported(msg)` | `NotSupported(msg)` | Raises `EError` with "Not supported: msg". Inline. |

### Time scope (new in engine5)

High-precision time functions:

| Old name (Common) | New name (Core) | Notes |
|---|---|---|
| `NowGMT` | `Time.UTC` | UTC time in TDateTime format (high-precision on Windows 8+) |
| — | `Time.Now` | Local time in TDateTime format (high-precision on Windows 8+) |
| `GetUTCTime` + formatting | `Time.Stamp` | Returns `HH:MM:SS.mmm` string for logs |
| `MyTickCount` | `Time.Ticks` | coarse monotonic milliseconds, cross-platform |

**Usage:**
```pascal
dt := Time.UTC;           // high-precision UTC
dt := Time.Now;           // high-precision local time
Log.Msg(Time.Stamp + ' Started');
```

Use `CoreTime.Ticks` when `SysUtils.Time` creates a name conflict in a unit.

## Apus.Conv (parsing and formatting)

| Old name (Common) | New name (Conv) | Notes |
|---|---|---|
| `ParseInt(st)` | `Conv.ToInt(st)` | |
| `ParseFloat(st)` | `Conv.ToFloat(st)` | |
| `ParseBool(st)` | `Conv.ToBool(st)` | |
| `HexToInt(st)` | `Conv.HexToInt(st)` | same name |
| `StrToIp(st)` | `Conv.ToIp(st)` | |
| `IpToStr(ip)` | `Conv.FormatIp(ip)` | renamed from Conv.ToIp(cardinal) to Conv.FormatIp |
| `FormatHex(v,digits)` | `Conv.ToHex(v,digits)` | |
| `PtrToStr(p)` | `Conv.ToStr(p)` | |
| `BoolToAStr(b)` | `Conv.ToStr(b)` | |
| `FormatInt(v)` | `Conv.FormatInt(v)` | same name |
| `FormatMoney(v,digits)` | `Conv.FormatMoney(v,digits)` | same name |
| `SizeToStr(size)` | `Conv.FormatSize(size)` | |
| `FormatTime(timeMs)` | `Conv.TimeToStr(timeMs)` | |
| `EncodeHex(data,size)` | `Conv.EncodeHex(data,size)` | same name |
| `DecodeHex(hexStr)` | `Conv.DecodeHex(hexStr)` | same name |
| `HexDump(buf,size)` | `Conv.HexDump(buf,size)` | same name |
| `DecDump(buf,size)` | `Conv.DecDump(buf,size)` | same name |
| `EncodeB64(data,size)` | `Conv.ToBase64(data,size)` | |
| `DecodeB64(st,buf,size)` | `Conv.FromBase64(st,buf,size)` | |

## Apus.Strings (string helper methods)

String functions moved from free-standing functions to `String8Helper` record helper.
Call style changes from `Func(st, args)` to `st.Method(args)`.

| Old name (Common) | New name (Strings) | Notes |
|---|---|---|
| `PosFrom(substr,st)` | `st.IndexOf(substr)` | For `ignoreCase=true`, use manual rewrite to `st.IndexOf(substr,1,true)` |
| `PosFrom(substr,st,minIdx)` | `st.IndexOf(substr,minIdx)` | For `ignoreCase=true`, use manual rewrite to `st.IndexOf(substr,minIdx,true)` |
| `LastPos(substr,st)` | `st.LastIndexOf(substr)` | |
| `Chop(st)` | `st.Trim` | |
| `SameText8(a,b)` | `a.Same(b)` | case-insensitive |
| `UpperCase(st)` | `st.ToUpper` | |
| `LowerCase(st)` | `st.ToLower` | |
| `SplitA(delim,st)` | `st.Split(delim)` | **CAUTION**: Split treats each char as delimiter; SplitA uses whole string |
| `Join(arr,delim)` | `String8.Join(arr,delim)` | class function |
| `QuoteStr(st)` | `st.Quote` | |
| `UnQuoteStr(st)` | `st.Unquote` | |
| `URLEncodeUTF8(st)` | `st.UrlEncode` | |
| `ExtractStr(st,pre,suf)` | `st.Extract(pre,suf)` | |
| `ParseInt(st)` | `st.ToInt64` | also available via Conv.ToInt |
| `ParseFloat(st)` | `st.ToDouble` | also available via Conv.ToFloat |
| `ParseBool(st)` | `st.ToBoolean` | also available via Conv.ToBool |
| `FastHash(st)` | `FastHash(st)` | same name, simple fast hash (case-insensitive) |
| `StrHash(st)` | `StrHash(st)` | same name, string hash (case-sensitive) |
| `SameText8(a,b)` | `a.Same(b)` | case-insensitive comparison |
| `Format(fmt,args)` | `UTF8.Format(fmt,args)` | native String8 format, no Unicode roundtrip. Specs: %d %u %x %X %f %g %s %p %%, flags: - 0 +, width, .precision |

### String type conversion (new in engine5)

| Old name (Common) | New name (Strings) | Notes |
|---|---|---|
| `Str8(st)` | `Str8(st)` | same name; overloads for UnicodeString, WideString, UTF8String (+AnsiString in UNICODE mode) |
| `Str16(st)` | `Str16(st)` | same name; overloads for UnicodeString, WideString, UTF8String (+AnsiString in UNICODE mode) |
| — | `Str32(st)` | **NEW**: convert String8/WideString/UnicodeString to String32 (UCS-4) |

### UTF-8 encoding (moved from Apus.Conv to Apus.Strings)

| Old name (Common/Conv) | New name (Strings) | Notes |
|---|---|---|
| `EncodeUTF8(ws)` | `UTF8.Encode(ws)` | WideString → String8; also accepts addBOM parameter |
| `DecodeUTF8(s)` | `UTF8.ToWide(s)` | String8 → WideString; strips BOM if present |
| `IsUTF8(s)` | `UTF8.HasBOM(s)` | check for UTF-8 BOM |
| `UTF8.FromWide(ws)` | `UTF8.FromWide(ws)` | alias for UTF8.Encode (inline) |

### Encoding conversion (moved from Apus.Conv to Apus.Utils)

| Old name (Common/Conv) | New name (Utils) | Notes |
|---|---|---|
| `UnicodeTo(ws,enc)` | `UnicodeTo(ws,enc)` | WideString → String8 with arbitrary encoding (UTF-8/Win1251/ANSI) |
| `UnicodeFrom(s,enc)` | `UnicodeFrom(s,enc)` | String8 → WideString with arbitrary encoding |

## Apus.Files (file I/O and utilities)

File functions moved from free-standing functions to `Files` record with static class methods.
Call style changes from `Func(args)` to `Files.Method(args)`.

### File I/O

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `MyFileExists(fname)` | `Files.Exists(fname)` | |
| `GetFileSize(fname)` | `Files.GetFileInfo(fname,info)` | size via `info.size` field |
| `LoadFileAsBytes(fname)` | `Files.LoadAsBytes(fname)` | added `numBytes`, `startFrom` params |
| `LoadFileAsString(fname)` | `Files.LoadAsString(fname)` | added `numBytes`, `startFrom` params |
| `SaveFile(fname,buf,size)` | `Files.Save(fname,buf,size)` | also overloads for ByteArray, String8, TBuffer |
| `ReadFile(fname,buf,posit,size)` | `Files.ReadBlock(fname,buf,offset,size)` | |
| `WriteFile(fname,buf,posit,size)` | `Files.WriteBlock(fname,buf,offset,size)` | |

### File operations

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `CopyFile(sour,dest)` | `Files.CopyFile(sour,dest)` | same name |
| `MakeBakFile(fname)` | `Files.MakeBakFile(fname)` | same name |

### Directory operations (`Folder` record)

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `DirectoryExists(path)` | `Folder.Exists(path)` | new wrapper |
| `ForceDirectories(path)` | `Folder.Create(path)` | creates with parents |
| `ListFiles(path,mask,recursive)` | `Folder.ListFiles(path,mask,recursive)` | mask supports `;`-separated patterns |
| `FindFile(name,path)` | `Folder.Find(name,path)` | findDir=false by default |
| `FindDir(name,path)` | `Folder.Find(name,path,true)` | findDir=true |
| `CopyDir(sour,dest)` | `Folder.Copy(sour,dest)` | |
| `MoveDir(sour,dest)` | `Folder.Move(sour,dest)` | |
| `DeleteDir(path)` | `Folder.Delete(path)` | |

### Path utilities

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `SafeFileName(fname)` | `Files.SafeFileName(fname)` | same name |
| `FileName(fname)` | `Files.FileName(fname)` | same name |
| `AddFileNameRule(rule)` | `Files.AddFileNameRule(rule)` | same name |
| `IsPathRelative(fname)` | `Files.IsPathRelative(fname)` | same name |
| `WaitForFile(fname,delay,exists)` | `Files.WaitForFile(fname,delay,exists)` | same name |

### Not moved (stays in Common)

| Old name (Common) | Notes |
|---|---|
| `DumpDir(path)` | depends on ForceLogMessage (logging) |

## Apus.Log (unified logging interface)

Logging functions extracted from `Apus.Common` into new unified API.

### Basic logging

| Old name (Common) | New name (Log) | Notes |
|---|---|---|
| `LogMessage(text)` | `Log.Msg(text)` or `Log.Info(text)` | default severity is Normal (was Normal in Common) |
| `LogMessage(text,group)` | `Log.Msg(text,group)` | category parameter |
| `LogMessage(text,params)` | `Log.Msg(text,params)` | Format overload |
| `ForceLogMessage(text)` | `Log.Force(text)` | forced (bypass cache, flush immediately) |
| `LogError(text)` | `Log.Error(text)` | error level + counter increment |
| `DebugMessage(text)` | `Log.Debug(text)` | debug level (lowest) |
| — | `Log.Warn(text)` | new: warning level |
| — | `Log.Fatal(text)` | new: fatal error level |

### Logger configuration

| Old name (Common) | New name (Log) | Notes |
|---|---|---|
| `UseLogFile(name)` | `Logger.UseLogFile(name)` | same name, added `useThread` and `keepOpened` params |
| `SetLogMode(mode,groups)` | `Logger.SetVerbosity(minSeverity)` | simplified: only min severity filter |
| `FlushLog` | `Logger.Flush` | same functionality |
| `LogCacheMode(enable,enforce,runThread)` | `Logger.LogCacheMode(enable,bypassSeverity)` | redesigned params |
| `StopLogThread` | `Logger.StopLogThread` | same name |
| — | `Logger.SetCustomHandler(handler,disable)` | **NEW**: interceptor support for Apus.Logging refactor |
| — | `Logger.GetErrorCount` | **NEW**: returns error/fatal counter |

### Severity levels (TSeverity enum)

Replaces old TLogModes (lmSilent/lmForced/lmNormal/lmVerbose):

| Old (Common) | New (Log) | Value | Notes |
|---|---|---|---|
| — | `TSeverity.Debug` | 0 | auxiliary debug info |
| — | `TSeverity.Info` | 1 | minor event |
| LogMessage default | `TSeverity.Normal` | 2 | regular event |
| ForceLogMessage | `TSeverity.Forced` | 3 | important, flush buffer |
| — | `TSeverity.Warn` | 4 | warning |
| LogError | `TSeverity.Error` | 5 | error |
| — | `TSeverity.Fatal` | 6 | fatal error |

## Apus.Threads (thread synchronization and management)

Threading primitives and thread management utilities extracted from `Apus.Common`.

**Major changes in engine5:**
- **Type renamed**: TMyCriticalSection → TLock (modern, cross-platform)
- **Fields encapsulated**: TLock fields are now private
- **New scope**: `Thread` record for thread operations
- **New methods**: TLock.Init/Cleanup, IsLocked, GetOwner
- **New type**: TLightweightEvent (WaitOnAddress/futex-based)

### Critical section management

| Old name (Common) | New name (Threading) | Notes |
|---|---|---|
| `InitCritSect(cr,name,level)` | `InitCritSect(cr,name,level)` | same name |
| `DeleteCritSect(cr)` | `DeleteCritSect(cr)` | same name |
| `EnterCriticalSection(cr,caller)` | `EnterCriticalSection(cr,caller)` | same name |
| `LeaveCriticalSection(cr)` | `LeaveCriticalSection(cr)` | same name |
| `DumpCritSects` | `DumpCritSects` | same name |
| `CheckCritSections` | `CheckCritSections` | same name |
| `TMyCriticalSection.Enter` | `lock.Enter` | method restored, same syntax |
| `TMyCriticalSection.Leave` | `lock.Leave` | method restored, same syntax |

### Thread scope (modern API)

| Old function (Common) | New method (Threads) | Notes |
|---|---|---|
| `RegisterThread(name)` | `Thread.Register(name)` | static method, cleaner |
| `UnregisterThread` | `Thread.Unregister` | static method |
| `PingThread` | `Thread.Ping` | static method |
| `GetThreadName(threadID)` | `Thread.GetName(threadID)` | static method, 0=current |

**Note**: Old functions still available but deprecated for compatibility.

### TLock object methods (new in engine5)

| Method | Notes |
|---|---|
| `lock.Init(name, level)` | Initialize lock (replaces InitCritSect) |
| `lock.Cleanup` | Cleanup lock (replaces DeleteCritSect) |
| `lock.Enter` | Acquire lock |
| `lock.Leave` | Release lock |
| `lock.IsLocked` | Check if locked |
| `lock.GetOwner` | Get owning thread ID |

### Utilities

| Old name (Common) | New name (Threading) | Notes |
|---|---|---|
| `WaitFor(var p,maxTime)` | `WaitFor(var p,maxTime)` | same name |
| `debugCriticalSections` | `debugCriticalSections` | global var, same name |

### Types moved from Apus.Types

| Old type (Types/Common) | New type (Threads) | Notes |
|---|---|---|
| `TMyCriticalSection` | `TLock` | **RENAMED** and moved from Apus.Types to Apus.Threads |
| `PCriticalSection` | `PLock` | **RENAMED** pointer type |
| `TSRWLock` | `TSRWLock` | **MOVED** from Apus.Types to Apus.Threads (Windows Vista+) |

### New types in engine5

| Type | Description |
|---|---|
| `TLightweightEvent` | Lightweight event using WaitOnAddress (Win8+) or futex (Linux) |
| `TScopedLock` | Delphi-only RAII lock wrapper with automatic cleanup (`{$IFDEF DELPHI}`) |
| `Thread` | Static record for thread operations |

### Backward compatibility aliases

| Old name | New name | Notes |
|---|---|---|
| `TMyCriticalSection` | `TLock` | type alias |
| `PCriticalSection` | `PLock` | type alias |
| `TCriticalSection` | `TLock` | type alias |
| `PCS` | `PLock` | type alias |
| `RegisterThread` | `Thread.Register` | old function deprecated |
| `UnregisterThread` | `Thread.Unregister` | old function deprecated |
| `PingThread` | `Thread.Ping` | old function deprecated |
| `GetThreadName` | `Thread.GetName` | old function deprecated |

## Apus.Utils (miscellaneous utilities)

Functions that don't fit scope of core/conv/strings/files modules.

| Old name (Common) | New name (Utils) | Notes |
|---|---|---|
| `ParseDate(st,default)` | `ParseDate(st,default)` | same name - parses DD.MM.YYYY HH:MM:SS and variants |
| `ParseTime(st,default)` | `ParseTime(st,default)` | same name - parses HH:MM:SS |
| `GetDateFromStr(st)` | `GetDateFromStr(st)` | alias for ParseDate |
| `SplitA(divider,st)` | `SplitA(divider,st)` | same name - splits by string divider (whole string, not charset) |
| `SplitA(divider,st,quotes)` | `SplitA(divider,st,quotes)` | same name - with quote handling |
| `Chop(st)` | `Chop(st)` or `st.Trim` | both available - trim whitespace |

**Note**: Utils is the default place for functions that don't fit other modules. More functions will be added here (EncodeUTF8/DecodeUTF8, AddString/RemoveString, HasParam/GetParam, etc).

## Apus.Compress (compression and patching)

Compression/decompression and binary patching utilities extracted from `Apus.Common`.

### RLE compression

| Old name (Common) | New name (Compress) | Notes |
|---|---|---|
| `PackRLE(buf,size,addHeader)` | `RLE.Pack(buf,size,addHeader)` | |
| `UnpackRLE(buf,size)` | `RLE.Unpack(buf,size)` | |
| `CheckRLEHeader(buf,size)` | `RLE.CheckHeader(buf,size)` | returns unpacked size or -1 |

### LZ compression

| Old name (Common) | New name (Compress) | Notes |
|---|---|---|
| `SimpleCompress(data)` | `LZ.Compress(data)` | |
| `SimpleDecompress(data)` | `LZ.Decompress(data)` | |

### Binary patching

| Old name (Common) | New name (Compress) | Notes |
|---|---|---|
| `CreateBackupPatch(orig,mod,size)` | `Patch.Create(orig,mod,size)` | |
| `ApplyBackupPatch(data,size,patch,patchSize)` | `Patch.Apply(data,size,patchBuf,patchSize)` | |

## Remaining legacy Common surface

This section tracks old `Apus.Common` helpers that still matter for migration.
Do not treat it as a list of functions to reintroduce under the old names.

### Resolved replacements

| Old name | Replacement | Notes |
|---|---|---|
| `EncodeUTF8(st)` / `DecodeUTF8(st)` | `UTF8.Encode`, `UTF8.ToWide`, `UTF8.FromWide`, `Str8`, `Str16` in **Apus.Strings** | Prefer explicit UTF-8 helpers and string conversion helpers, not standalone Common names. |
| `UnicodeFrom(st,enc)` / `UnicodeTo(st,enc)` | **Apus.Utils** | `TTextEncoding` and the encoding conversion helpers live together in `Apus.Utils`. |
| `Str8(s)` / `Str16(s)` | **Apus.Strings** | Cast/convert to `String8` / `String16`. |
| `SortRecordsByInt/Double/Float` | **Apus.Core.Sort** | Implemented as `Sort.ByInt/ByFloat/ByDouble(var items; itemSize,itemCount,offset:integer; asc:boolean)`. |
| `HasParam/GetParam` | **Apus.Utils** | Command-line argument access. |
| `TTextEncoding/teUnknown` | **Apus.Utils** | Defined as `TTextEncoding=(teUnknown,teANSI,teWin1251,teUTF8)`. |
| `ErrorMessage(msg)` | **Apus.Core** `SystemMessage(msg)` | Configurable critical message output (log/stderr/msgbox/raise). |
| `LastChar(st)` | **Apus.Strings** | Available as string helper methods. |
| `Unescape(st)` | **Apus.Strings** | Available as `String8Helper.Unescape`. |
| `ExtractFilePath/FileName/ExpandFileName` | **SysUtils** | RTL functions; add `SysUtils` to `uses`. |
| `TrimLeft/TrimRight` standalone | **SysUtils** or `st.TrimLeft/TrimRight` | Also available as `String8` helper methods. |

### Still unresolved or intentionally absent

| Old name | Current status | Notes |
|---|---|---|
| `IsUTF8(st)` | Not reintroduced as a Common-compatible helper | Old behavior checked for UTF-8 BOM. Prefer explicit BOM handling or `UTF8.IsValid`, depending on intent. |
| `SafeStrItem(arr,i)` | Still only in deprecated Common | Add a small helper only when a live migration needs this exact behavior. |
| `PackBytes(b1..b4)` / `PackWords(w1,w2)` | Still only in deprecated Common | Candidate for `Apus.Core` if live users need it. |
| `PointerInRange(p,base,size)` | Still only in deprecated Common | Candidate for `Apus.Core` if live pointer-range checks need it. |
| `AddString/RemoveString/FindString` | Still only in deprecated Common under the old names | Prefer typed dynamic-array helpers or capacity-aware builders for new code. `Base/Apus.Android.pas` still has legacy-name users behind Android-specific code paths. |

## 2026-03-18 — Hash Maps Consolidation

### Moved from `Apus.Structs` to `Apus.HashMaps`

- `THashItem`, `TCell`
- `TStrHash`
- `THash`
- `TSimpleHash`, `TSimpleHashS`, `TSimpleHashAS`, `TSimpleHash8`
- `TObjectHash`, `PObjectHash`
- `TVarHash`, `PVarHash`
- `TErrorState`

### Final `Apus.Structs` state

- `Apus.Structs` is removed from live Base.
- No compatibility aliases are kept in `Apus.Structs`; update old units to use
  `Apus.HashMaps` or `Apus.Containers` explicitly.
- Hash implementations live in `Apus.HashMaps`.
- Non-hash algorithmic containers live in `Apus.Containers`.

### Deprecation policy

- Preferred generic API for new code: `THashMap<T>`.
- Supported specialized hashes:
  - `THash` (DB-oriented multi-value mode: `String8 -> variant(s)`)
  - `TSimpleHash` (`int64 -> int64`)
  - `TObjectHash` (`String8 -> TNamedObject`)
- Legacy/compat hashes marked `deprecated`:
  - `TStrHash`
  - `TSimpleHashS`
  - `TSimpleHashAS`
  - `TSimpleHash8`
  - `TVarHash`

## 2026-03-18 — Containers split

- Added new module `Apus.Containers` for non-hash algorithmic containers.
- Removed `Apus.Structs` unit and moved container API surface to `Apus.Containers`.
- Removed legacy `TestStructs`; added `TestContainers` in modern test format.
- `TBitStream` is now in `Apus.Types`.

## 2026-03-19 — Sort API moved to Apus.Core

- Added `Sort` scope in `Apus.Core`:
  - `Sort.ByInt`
  - `Sort.ByFloat`
  - `Sort.ByDouble`
  - `Sort.ByStr` (`String8` field)
- Removed legacy `SortRecordsByInt/Float/Double` API from `Apus.Types` (no wrappers left).
- Moved sorting coverage from `TestTypes` to `TestCore`.

## 2026-03-19 — Apus.Types validation and fixes

- Added new test suite: `Base/tests/TestTypes.dpr` (modern console test template).
- Expanded edge-case coverage for:
  - `TIntRange` / `TFloatRange`
  - `TArray<T>`
  - `TNameValue` / `TNameValueList`
  - `TBuffer` / `TWriteBuffer`
  - `TBitStream`
- Fixed defects found by tests:
  - `TBitStream`: proper buffer zeroing size, safe bit mask for bit 31 under range/overflow checks, correct resize rounding, correct bit-write path in `Put(var buf;...)`.
  - `TNameValueList.Init(st,...)`: constructor now assigns delegated constructor result to `self`.

## 2026-06-19 — Depth state API (Apus.Engine.API)

- `IRenderTarget.UseDepthBuffer(test;writeEnable:boolean)` → **`SetDepthMode(test:TDepthTest=Keep; write:TDepthWrite=Keep)`**. The misleading "buffer" name dropped; test and write mask are now independent axes, each with a keep-current sentinel.
- `TDepthBufferTest` → **`TDepthTest`** (scoped enum): `dbDisabled/dbPass/dbPassLess/dbPassLessEqual/dbPassGreater/dbNever` → `TDepthTest.Disabled/Pass/Less/LessEqual/Greater/Never` + new `TDepthTest.Keep`.
- New **`TDepthWrite`** scoped enum (`Keep/Off/On`) for the write mask (was a bare `boolean`). `,false`→`,TDepthWrite.Off`, `,true`→`,TDepthWrite.On`.
- New **`IRenderTarget.DepthMode:TDepthMode`** getter (record `{test;write}`) + tracked `curDepth` threadvar state — enables save/restore and keep-current. No state stack (deliberate).
- Fixed latent bug: write mask was skipped when test=`dbDisabled`; now `glDepthMask` always reflects tracked state.
- No compatibility alias. Upgrader rules added to `tools/engine5.upgrade`.

## 2026-06-19 — Removed legacy OpenGL painters

- Removed `Apus.Engine.PainterGL.pas` and `Apus.Engine.PainterGL2.pas`.
- Current desktop rendering uses `Apus.Engine.OpenGL` with `IGraphicsSystem`, `IRenderTarget`, `IShader`, `IDrawer`, and `ITextDrawer`.
- The old Android backend still needs migration to the current graphics-system architecture before Android builds can be re-enabled.
