# Third-party components

The Apus Game Engine itself is licensed under BSD-3 (`license.txt`). This file is
the index of everything in this repository that someone else wrote: prebuilt
libraries the engine loads or links, and third-party source code vendored into
the tree. It exists so that a project shipping a build of this engine can see, in
one place, what it is redistributing and what each piece asks for.

Every prebuilt library below is under a permissive licence — zlib, MIT, or the
FreeType License. Redistribution asks only that the notice travels with the
binary: there is no obligation to publish sources, and nothing here restricts
commercial use. Two things need more care and are flagged where they appear: the
BASS headers (the library itself is commercial and is *not* shipped) and a few
interface translations inherited in `Base/extra/`.

## Runtime libraries (prebuilt binaries in the repository)

Provenance — exact upstream artifact, SHA-256 of the committed file, and any
normalization — is recorded per platform in `redist/<platform>/SOURCES.txt`, and
the licence texts live in `redist/<platform>/licenses/`. The Windows binaries are
the odd ones out: they sit where the build output needs them rather than under
`redist/`, so `redist/windows/` carries their paperwork only.

| Component | Version | Committed as | Licence | Notice |
|---|---|---|---|---|
| SDL2 | 2.32.10 | `bin/sdl2.dll`, `bin64/sdl2.dll` | zlib | `redist/windows/licenses/SDL2-LICENSE.txt` |
| SDL2_mixer | 2.8.1 | `bin/SDL2_mixer.dll`, `bin64/SDL2_mixer.dll` | zlib | `redist/windows/licenses/SDL2_mixer-LICENSE.txt` |
| libxmp | 4.6.1 | `bin/libxmp.dll`, `bin64/libxmp.dll` | MIT | `redist/windows/licenses/libxmp-LICENSE.txt` |
| FreeType | 2.10.0 | `Base/bin/freetype32.dll`, `Base/bin/freetype64.dll` | FTL (dual FTL/GPLv2, FTL elected) | `redist/windows/licenses/FreeType-FTL.txt` |
| LodePNG | 20161127 | `Base/bin/LodePNG*.dll`, `Base/tests/LodePNG*.dll`, `Base/extra/LodePNG.lib` | zlib | `redist/windows/licenses/LodePNG-LICENSE.txt` |
| zlib | 1.1.4 | `Base/extra/zlib/*.obj` (Win32 Delphi only) | zlib | `redist/windows/licenses/zlib-LICENSE.txt` |
| SDL2 (macOS) | 2.30.9 | `redist/macos/libSDL2-2.0.0.dylib` | zlib | `redist/macos/licenses/SDL2-LICENSE.txt` |
| SDL2 (iOS) | 2.30.12 | `redist/ios*/SDL2.framework/` | zlib | `redist/ios*/licenses/SDL2-LICENSE.txt` |

Two notes worth carrying downstream:

- **FreeType** asks (FTL §3) that products using it credit FreeType in their
  documentation. This file is that credit for the engine; a game shipping
  `freetype*.dll` owes the same acknowledgement in its own credits.
- **libxmp** was LGPL-2.1 until version 4.5.0 and is MIT from 4.5.0 onward. The
  version shipped here is MIT — do not copy a licence claim from older sources.

Linux builds link the distribution's own SDL2/SDL2_mixer packages; nothing is
vendored for that platform. Files sitting in `bin/`/`bin64/` from local builds
but *not* tracked by git (assimp, steam_api, ImxEx, D3DX8 and other leftovers)
are not part of the repository and are not covered here.

## Vendored source code

Third-party Pascal sources kept in the tree, all with their licence headers
intact:

| Component | Location | Licence | Used by |
|---|---|---|---|
| Pascal-SDL-2-Headers | `extra/sdl2/` | MPL-2.0 or zlib (both texts in that folder) | SDL platform + audio backends |
| dglOpenGL / dglOpenGLES | `extra/dglOpenGL.pas`, `extra/dglOpenGLES.pas` | MPL-2.0 | desktop GL loader |
| PasMP | `extra/PasMP.pas` | zlib | not referenced by engine code |
| SDLmini | `extra/SDLmini.pas` | SDL 1.3 header miniport, no licence header | not referenced by engine code |
| BASS 2.3 headers | `extra/bass.pas` | proprietary (see below) | `Apus.Engine.SoundBass.pas` |

`extra/sdl2/sdl2_mixer.pas` carries local modifications, each marked with an
`APUS:` comment and described in `extra/sdl2/README.md`.

**BASS** (un4seen.com) is a closed-source commercial library. Only the Pascal
header is present — no `bass.dll` is committed, and the BASS backend is not part
of any default build. Using it requires a licence from un4seen for commercial
products; that is why miniaudio and SDL2_mixer, not BASS, are the engine's
maintained audio backends.

## Inherited interface units (`Base/extra/`)

Header translations and small helper units collected over the years. None of them
ships a library of its own (the binaries they bind to are listed in the first
table, or come from the OS). The licence column states what the file itself
declares — nothing is inferred:

| Unit | Origin | Licence as stated in the file | Referenced in |
|---|---|---|---|
| `DCPmd5a.pas` | DCPcrypt v2, David Barton | MIT, full text in the header | `Apus.Engine.HttpGameClient/Server` |
| `Hashes.pas` | Ciaran McCreesh, 2002 | permissive, zlib-style, in the header | `Base/tests/UStructs.dpr` |
| `RegExpr.pas` | TRegExpr, Andrey V. Sorokin | permissive custom terms, in the header | `Apus.RegExpr` |
| `freetypeh.pas` | Free Pascal RTL | FPC modified LGPL (linking exception) | `Apus.FreeTypeFont` |
| `winsock2_jedi.pas` + `ws2*.inc` | Alex Konshin / JEDI, from Microsoft headers | MPL-1.1 | nothing (dead) |
| `QStrings.pas` | Andrew N. Driazgov, 2000–2001 | **none stated** — copyright only | not compiled; parts copy-pasted into `Apus.ControlFiles` |
| `ZLIBEX.PAS` | ZLibEx, Roberto Della Pasqua / base2 / Borland | **none stated** — copyrights only | `Apus.HttpRequests` |
| `jni.pas` | JNI header translation | **none stated** | `Apus.Android`, Android audio |
| `mysql.pas` + `mysql_win32.inc` | translation of MySQL AB's C headers | header points at **MySQL's own GPL notice** | `Apus.Database`, `Apus.SCGI` |
| `IMixEx.pas` | IMixerPro header, Igor Lobanchikov | proprietary library, header only | `Apus.Engine.SoundImx` (legacy) |

The last five are the ones to look at before any commercial redistribution — not
because a problem is known, but because the files themselves do not settle the
question. Most are legacy: `mysql.pas` binds a client library the engine does not
ship, `IMixEx.pas` belongs to the Win32-only audio backend that R-28 retires, and
`winsock2_jedi.pas` is already unreferenced.

`QStrings.pas` is the one that is not merely legacy: the unit itself is not
compiled (it does not build under FPC), but a block of its code was copy-pasted
into `Apus.ControlFiles.pas` (marked there as such), so that code ships inside a
BSD-3 unit while its origin declares no licence at all. Replacing that block with
an own implementation would close the question outright.

## What a product built on the engine redistributes

If a game ships the Windows build output, it ships SDL2, SDL2_mixer, libxmp,
FreeType and LodePNG. Practically that means: keep the licence texts from
`redist/windows/licenses/` with the distribution (a `licenses/` folder or an
in-game credits screen), and credit FreeType. Nothing else is required.

## Adding a component

Commit the licence text next to the others, add a `SOURCES.txt` entry with the
upstream URL and the SHA-256 of the committed file, and add a row here. See
`redist/README.md` for why binaries are committed to plain git at all, and how
the per-platform directories are regenerated.
