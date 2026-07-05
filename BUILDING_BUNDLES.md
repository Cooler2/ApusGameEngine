# Building distributable bundles

On some platforms a runnable application is more than the executable your IDE
produces: it needs an OS-specific bundle layout, its shared libraries copied in
and relinked, and a signature. This document covers those platforms. Where a
plain **Build** in Delphi/Lazarus (or the FPC scripts) already yields something
you can ship, that is noted and there is nothing else to do here.

The examples below use the `SimpleDemo` demo; substitute your own executable and
resources.

---

## macOS — `.app` bundle

A bare Mach-O executable runs from a terminal but is not a proper macOS
application: no Dock/focus behaviour, no Retina unless declared, and it carries
absolute paths to Homebrew libraries that only exist on the build machine. The
`.app` bundle fixes all three.

### Prerequisites

- **Xcode Command Line Tools** — `xcode-select --install` (provides `ld`,
  `install_name_tool`, `codesign`, `otool`).
- **FPC 3.2.2+** (Homebrew `fpc`, or an official installer / fpcupdeluxe).
- **SDL + FreeType** via Homebrew: `brew install sdl2 sdl3 sdl2_mixer freetype`.
  Note `brew install sdl2` installs **sdl2-compat** (an SDL2 API shim on top of
  SDL3) — see [SDL on macOS](#sdl-on-macos) below.

### 1. Build the executable

Either build in Lazarus (`demo/SimpleDemo/SimpleDemo.lpi`) or with FPC directly:

```sh
fpc -dSDL -dOPENGL -MDelphi -Sd \
  -Fu. -Fuextra -Fuextra/sdl2 -FuBase -FuBase/extra -Fudemo/SimpleDemo \
  "-Fl$(brew --prefix sdl2)/lib" -FEbin64 \
  -oSimpleDemo_macos demo/SimpleDemo/SimpleDemo.dpr
```

This produces `bin64/SimpleDemo_macos`.

### 2. Assemble the bundle

```sh
tools/make_macos_bundle.sh
```

Options: `--exe PATH`, `--name NAME`, `--out DIR`, `--resdir DIR`, `--id
BUNDLE_ID`, and trailing resource file names (default: `particles.png
game.ctl`). The script:

- builds `SimpleDemo.app/Contents/{MacOS,Resources,Frameworks}` + `Info.plist`
  (with `NSHighResolutionCapable` — **required**, or the Retina path stays off
  when launched from the bundle);
- copies resources into `Contents/Resources`, and **walks the executable's
  dependency graph** (`otool -L`, recursively) to copy every non-system dylib —
  SDL2, and, when present, FreeType, `SDL2_mixer` and its codec libraries — into
  `Contents/Frameworks`. Nothing is hardcoded per library, so adding a dependency
  needs no script change (the one exception is `libSDL3`, which sdl2-compat
  `dlopen`s at runtime and is therefore invisible to `otool` — see below);
- rewrites each bundled library's install name and the executable's references to
  `@rpath/...` and adds the rpath `@executable_path/../Frameworks`;
- **ad-hoc** signs nested-first (each dylib, then the app) and verifies with
  `codesign --verify --deep --strict`.

Result: `bin64/SimpleDemo.app`, self-contained against the bundled SDL.

### 3. Run

```sh
open bin64/SimpleDemo.app
```

An automated build → bundle → run-from-inside-bundle smoke test lives in
`tests/macos_bundle_smoke.sh` (drives the app through the file-based Robot API).

### Resource lookup inside a bundle

Inside a bundle the executable is at `Contents/MacOS/` and its resources at
`Contents/Resources/`. Demos that `SetCurrentDir` to their asset folder must
handle this — `SimpleDemo` falls back to `../Resources` under `{$IFDEF DARWIN}`
when its dev-layout asset folder is absent. Apply the same pattern to your app.

### SDL on macOS

Homebrew no longer ships classic SDL2 — the `sdl2` formula is an alias for
**sdl2-compat**, which implements the SDL2 API on top of SDL3 and `dlopen`s
`libSDL3` at runtime. The bundle script detects this and bundles **both**
`libSDL2` and `libSDL3`; for a genuinely self-contained SDL2 it bundles just
`libSDL2`.

For a **distributable** bundle, prefer official/controlled binaries over Homebrew
ones: Homebrew dylibs are built with `minimum-macOS = the build host's version`,
so a bundle made from them only launches on that macOS version or newer — and
this applies to **every** dependency (FreeType, `SDL2_mixer`, …), not just SDL.

The repo vendors a controlled SDL2 for exactly this. Populate it once with:

```sh
tools/fetch_redist_macos.sh     # -> redist/macos/libSDL2-2.0.0.dylib (+ SOURCES, license)
```

This downloads the **official** SDL2 release (a self-contained, universal
arm64+x86_64 framework with a low deployment target), verifies its SHA-256 and
normalizes it into `redist/macos/`. Because official SDL2 is self-contained, it
also **removes the libSDL3 dependency** the Homebrew sdl2-compat shim needs.

Then build the bundle so it substitutes the vendored library:

```sh
REDIST_LIBDIR="$PWD/redist/macos" tools/make_macos_bundle.sh ...
```

Any bundled dylib whose **leaf name** matches a file in `REDIST_LIBDIR` is taken
from there instead of the host copy; the bundle layout is identical, only the
source of each dylib changes. Use `REDIST_LIBDIR` (not `SDL2_LIBDIR`) for this:
`SDL2_LIBDIR` also steers the FPC link path in the build/test scripts, whereas
`REDIST_LIBDIR` only affects which dylibs the bundle packs, so the dev build
keeps linking against Homebrew while the bundle ships the vendored SDL2.

### Distribution / signing levels

| Level | What it needs | Who it's for |
|---|---|---|
| Ad-hoc (`codesign -s -`, done by the script) | nothing | local dev, CI artifacts |
| Unsigned developer build | nothing | testers: `xattr -dr com.apple.quarantine App.app`, or System Settings → Privacy & Security → Open Anyway |
| Storefront (Steam / itch) | a store account | public game distribution **without** an Apple account — store-installed builds get no quarantine flag |
| Developer ID + notarization | Apple Developer Program ($99/yr) | direct public distribution (dmg/zip from a website) |

Gatekeeper on macOS 15+ no longer lets right-click → Open bypass the check for
non-notarized apps, so direct public distribution without notarization has a
rough UX; storefronts are the practical no-notarization channel. Developer ID +
notarization layers `--options runtime` signing, `notarytool submit` and
`stapler staple` on top of the same bundle — the bundle layout does not change.

---

## Windows

No bundle step. A native (`DELPHI;OPENGL;LODEPNG;FREETYPE`) build produces a
`.exe`; ship it with the DLLs it needs alongside. Nothing in this document
applies.

## Linux

A native build produces an ELF binary. For a portable single-file artifact,
package it as an AppImage (SDL/FreeType bundled) — not yet scripted in this repo.

## Android / iOS

Mobile packaging (APK / `.app`/`.ipa`) is tracked separately and not yet part of
the standard build: Android under roadmap **R-24**, iOS under **R-30**.
