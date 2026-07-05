# platform — platform-specific build support

Everything required to build, package or integrate the engine on a specific
platform: native host-app projects consumed by a foreign build system (Xcode,
Gradle), packaging/bundling scripts, and scripts that regenerate the vendored
runtime libraries in `redist/`.

## What belongs here vs. elsewhere

- `platform/<os>/` — native host projects and platform build scripts (this
  directory).
- repository root / `Base/` — engine Pascal source, including platform units
  (`SDLplatform`, `Android`, …); compiled by FPC/Delphi.
- `extra/` — Pascal bindings to native libraries.
- `redist/<os>/` — vendored prebuilt runtime binaries with provenance (see
  `redist/README.md`).
- `tools/` — utilities that concern the engine as a whole, plus tools for game
  projects built on the engine (e.g. a future GUI or resource editor).
  Platform-specific build scripts do **not** belong there.

## Layout

```
platform/
  <os>/               # ios, macos, android — same names as in redist/
    <component>/      # a host-app project tree (e.g. ios/shell)
    <script>.sh       # platform build / packaging / redist scripts
```

## Conventions

- Component and file names are timeless and role-based. Never encode task or
  ticket numbers (R-NN) in paths — those belong in commit messages and `Work/`
  documents.
- Committed documentation is written in English; task status reports live in
  `Work/`, not here.
- Generated build output (`build/`, `DerivedData/`) is git-ignored and safe to
  delete.

## Currently populated

- `ios/shell/` — minimal iOS lifecycle shell: Xcode app target + FPC static
  archive + SDL2 framework; see its README for the integration mechanics.
- `macos/` — `make_bundle.sh` (assemble a runnable `.app`, documented in
  `BUILDING_BUNDLES.md`) and `fetch_redist.sh` (regenerate `redist/macos`).
