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

Currently populated: `macos/` (SDL2). Windows runtime DLLs still live in
`bin/`/`bin64/` for now; they are not re-vendored here (removing them would not
reclaim any repository size, since git history keeps them regardless).

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

Each platform directory is produced by a `platform/<platform>/fetch_redist.sh`
script that downloads the official upstream, verifies its SHA-256, normalizes it
into our canonical layout, and records provenance in `SOURCES.txt`. To update a
library, bump the version in the script and re-run it; commit the result.

- macOS: `platform/macos/fetch_redist.sh`

Note the committed files are **not byte-identical to upstream** where
normalization was required (e.g. macOS install-id rewrite + ad-hoc re-sign);
`SOURCES.txt` records both the upstream `.dmg` hash (provenance) and the
committed file's hash (integrity).
