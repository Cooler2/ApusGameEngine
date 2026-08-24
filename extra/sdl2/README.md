# Pascal-SDL-2-Headers

These are the Pascal SDL 2 Headers.

## Installation

Just add the headers to your include path. Include sdl2.pas for the main SDL2 library (should be always needed). Furthermore headers for the other SDL2 libraries are provided: 
 - sdl2_image.pas
 - sdl2_mixer.pas
 - sdl2_net.pas
 - sdl2_ttf.pas

## Local modifications (Apus Game Engine)

This is a vendored copy. Changes made here are marked with an `APUS:` comment:

- `sdl2_mixer.pas`: `Mix_LoadWAV`, `Mix_PlayChannel` and `Mix_FadeInChannel` are
  macros in `SDL_mixer.h`, not exported symbols, but they were declared as
  `external`. Any binary that referenced one of them failed to start
  (`STATUS_ENTRYPOINT_NOT_FOUND` on Windows). They are ordinary functions now,
  expanding to `Mix_LoadWAV_RW` / `Mix_PlayChannelTimed` /
  `Mix_FadeInChannelTimed` exactly as the C header does.

## Shipped libraries vs headers

These headers describe SDL2_mixer 2.8.x, while the DLLs shipped in `bin/` and
`bin64/` are 2.0.4. Because the bindings are load-time imports, calling a
function that the shipped library does not export does not fail at the call
site - the process refuses to start. `Apus.Engine.SoundSDL` logs both versions
at initialization so the mismatch is visible.

The 2.6+ API absent from the shipped 2.0.4: `Mix_MasterVolume`,
`Mix_GetMusicVolume`, `Mix_PauseAudio`, `Mix_MusicDuration`,
`Mix_GetMusicPosition`, `Mix_GetMusicLoopStartTime`, `Mix_GetMusicLoopEndTime`,
`Mix_GetMusicLoopLengthTime`, `Mix_ModMusicJumpToOrder`, `Mix_GetNumTracks`,
`Mix_HasMusicDecoder`, `Mix_GetMusicTitle`, `Mix_GetMusicTitleTag`,
`Mix_GetMusicArtistTag`, `Mix_GetMusicAlbumTag`, `Mix_GetMusicCopyrightTag`,
`Mix_SetTimidityCfg`, `Mix_GetTimidityCfg`.

## Bugs / Contributions

If you have any contributions, feel free to drop a pull request or send in a patch.

Same goes for bugs, please use the github issue tracker.

## License

You may license the Pascal SDL 2 Headers either with the MPL license or with the zlib license, both included.
