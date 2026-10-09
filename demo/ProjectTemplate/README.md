# ProjectTemplate

A minimal starting point for your own project: one window, one UI scene and an
Exit button. Everything app-wide goes in `TMainApp.SetupApplication` (commented
options for window size, fixed canvas and pixel-art canvas are there);
scenes are created in `TMainApp.CreateScenes`.

## Start a new project

1. Copy this folder next to it, e.g. to `demo/MyGame/`.
2. Optionally rename `ProjectTemplate.dpr` to `MyGame.dpr` (and `program ProjectTemplate;`
   inside it) and `ProjectTemplateApp.pas` (and its `uses` entry).
3. Build and run - from the repository root:

   ```
   build.cmd MyGame              (Windows)
   bin64\MyGame.exe

   ./build.sh MyGame             (Linux, macOS)
   demo/MyGame/MyGame
   ```

   On Windows the exe goes to `bin64\`, where the required DLLs (SDL2, FreeType)
   already are. On Linux install `libsdl2-dev` and `libfreetype-dev` first.
   The scripts build `<folder>/<folder>.dpr`, or the only `.dpr` in the folder.

   **Lazarus** - open `ProjectTemplate.lpi` (update the file names in it after
   renaming). **Delphi 12+** - open the `.dpr`; Delphi creates the `.dproj`.

`build.cmd`/`build.sh` are internal tools of the engine repository (demos, tests,
tools). A project kept outside the repository writes its own build script around
the engine option list `build.cfg`, run from the engine root (its paths are
relative to it):

```
fpc @build.cfg -Fu<project> -FU<project>/_fpc -FE<output> <project>/<name>.dpr
```

On Windows put the DLLs from `bin64\` (SDL2, FreeType) next to the exe.
For Lazarus/Delphi, point the search paths at the engine root, `extra`,
`extra/sdl2`, `Base` and `Base/extra` (the list in `build.cfg`).

## Build options

Pass them after the project name (`./build.sh MyGame -dSDLMIX`), or put them in
`MyGame/build.cfg`, one per line - the scripts pick that file up automatically.


- `-dSDLMIX` - link the SDL_mixer audio backend. Audio is opt-in: without it the
  sound system stays inactive.
- `-dSDL` - compile in the SDL platform layer on Windows (Linux and macOS always use
  SDL). Native Windows stays the default; SDL is selected with
  `requestBackend.platform:=spSDL` or the `-SDL` command-line parameter.
- `-dWEBP` - load `.webp` images (decode-only libwebp, bundled for Windows x64 and Linux x64).

See `defines.inc` in the engine root for the full list, and `build.cfg` for the
options every build uses.
