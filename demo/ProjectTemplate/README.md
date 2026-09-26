# ProjectTemplate

A minimal starting point for your own project: one window, one UI scene and an
Exit button. Everything app-wide goes in `TMainApp.SetupApplication` (commented
options for window size, fixed canvas and pixel-art canvas are there);
scenes are created in `TMainApp.CreateScenes`.

## Start a new project

1. Copy this folder next to it, e.g. to `demo/MyGame/`.
2. Rename `ProjectTemplate.dpr` to `MyGame.dpr` and change `program ProjectTemplate;`
   inside it. Optionally rename `ProjectTemplateApp.pas` (and its `uses` entry).
3. Build and run:

   **Windows (FPC)** - from the repository root:

   ```
   demo\build_demo_fpc.cmd MyGame
   bin64\MyGame.exe
   ```

   The exe goes to `bin64\`, where the required DLLs (SDL2, FreeType) already are.

   **Linux (FPC)** - install `libsdl2-dev` and `libfreetype-dev`, then from the
   repository root:

   ```
   fpc -dOPENGL -dFREETYPE -MDelphi -Sd -RIntel \
     -Fu. -Fuextra -Fuextra/sdl2 -FuBase -FuBase/extra \
     -Fudemo/MyGame -FUdemo/MyGame/_fpc demo/MyGame/MyGame.dpr
   ```

   **Lazarus** - open `ProjectTemplate.lpi` (update the file names in it after
   renaming). **Delphi 12+** - open the `.dpr`; Delphi creates the `.dproj`.

To keep the project outside the engine repository, point the `-Fu` paths (or the
Lazarus/Delphi search paths) at the engine root, `extra`, `extra/sdl2`, `Base` and
`Base/extra`, and copy the DLLs from `bin64\` next to your exe.

## Build options

- `-dSDLMIX` - link the SDL_mixer audio backend. Audio is opt-in: without it the
  sound system stays inactive.
- `-dSDL` - use the SDL platform layer on Windows too (Linux and macOS always use SDL).
- `-dWEBP` - load `.webp` images (decode-only libwebp, bundled for Windows x64 and Linux x64).

See `defines.inc` in the engine root for the full list.
