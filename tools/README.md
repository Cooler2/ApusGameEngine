# tools — engine-wide utilities

Utilities that concern the engine as a whole, and tools intended for game
projects built on the engine (a future GUI or resource editor belongs here
too). Platform-specific build/packaging scripts do **not** — those live in
`platform/<os>/` (see `platform/README.md`).

Current tools:

- [Blender AEM exporter](../manual/aem_static_assets.md) - exports static meshes,
  material bindings and LOD collections to experimental AEM 0.0.

- `upgrade5` - engine4 -> engine5 source upgrader (rules in `engine5.upgrade`,
  notes in `upgrade5.txt`). Build: `./build.sh tools/upgrade5.dpr` / `build.cmd tools\upgrade5.dpr`.
- `gen_case_tables.py` - generates `Base/caseTables.inc`, the Unicode case tables of
  `Apus.Strings` (`ToUpper`/`ToLower`), from `UnicodeData.txt`. Rerun on a new Unicode version.
- `check_minmax.sh` - CI check for a Delphi-only break: a unit with both `Math` and `Apus.Core`
  in uses must not call `Min`/`Max` unqualified (Delphi finds the call ambiguous, FPC does not).
  Run: `bash tools/check_minmax.sh`.

Older tools that do not compile yet are in [`legacy/`](legacy/README.md).
