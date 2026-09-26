# tools — engine-wide utilities

Utilities that concern the engine as a whole, and tools intended for game
projects built on the engine (a future GUI or resource editor belongs here
too). Platform-specific build/packaging scripts do **not** — those live in
`platform/<os>/` (see `platform/README.md`).

Current tools:

- `upgrade5` - engine4 -> engine5 source upgrader (rules in `engine5.upgrade`,
  notes in `upgrade5.txt`). Build: `./build.sh tools/upgrade5.dpr` / `build.cmd tools\upgrade5.dpr`.

Older tools that do not compile yet are in [`legacy/`](legacy/README.md).
