# redist — vendored third-party runtime libraries

Prebuilt, redistributable native libraries the engine links against, committed
directly to the repository so that:

- **bundle/package builds are reproducible offline** and do not break if an
  upstream download URL moves or a release is pulled;
- the binaries are **discoverable and reusable** — anyone can browse the repo (or
  a GitHub source ZIP) and grab a known, documented library.

## Layout

```
redist/
  <platform>/
    <library files>       # loose, directly usable
    licenses/             # upstream license texts
    SOURCES.txt           # provenance: version, URL, sha256, normalization
```

Currently populated: `linux/` (WebP), `macos/`, `ios/` and `ios-simulator/` (SDL2), plus
`windows/` — which is paperwork only. The Windows DLLs stay in `bin/`, `bin64/`
and `Base/bin/`, where the build output needs them; re-vendoring them here would
double their weight, and moving them would not reclaim any repository size
either, since git history keeps them regardless. `redist/windows/` therefore
holds just their `SOURCES.txt` and `licenses/`.

`THIRD-PARTY.md` in the repository root indexes every third-party component,
binary and source, and points at the notice file for each.

## Why plain git, not LFS or a zip

- **Plain git, not LFS.** LFS needs `git-lfs` on every clone, a server with LFS
  support, and GitHub bandwidth quota (which a large binary can exhaust, breaking
  clones/CI). Worse for our goals: GitHub source ZIPs and the web file view serve
  LFS *pointer files*, not the binaries — defeating discoverability.
- **Loose files, not a zip.** git already deflates blobs in its packfiles, so a
  zip barely shrinks the initial size, and on every update the whole archive is
  re-added to history — whereas loose files let git dedup unchanged blobs and
  delta-compress. Loose files are also usable without an extraction step.

## Regenerating / auditing

The platform scripts download pinned upstream releases, verify SHA-256, and
place the resulting libraries in their canonical locations. Provenance and
committed binary hashes are recorded in `SOURCES.txt`. To update a
library, bump the version in the script and re-run it; commit the result.

- Linux WebP: `platform/webp/build_linux.sh`
- macOS: `platform/macos/fetch_redist.sh`
- Windows WebP: `platform/webp/build_windows.ps1` downloads a pinned source
  archive, builds the decoder DLL, checks its imports, and installs it in `bin64/`.
  Other Windows binaries are documented in `redist/windows/SOURCES.txt`.

Note the committed files are **not byte-identical to upstream** where
normalization was required (e.g. macOS install-id rewrite + ad-hoc re-sign);
`SOURCES.txt` records both the upstream `.dmg` hash (provenance) and the
committed file's hash (integrity).
