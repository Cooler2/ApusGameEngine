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

## Shipped libraries

`bin/` and `bin64/` carry the official SDL2_mixer **2.8.1** release
(https://github.com/libsdl-org/SDL_mixer/releases/tag/release-2.8.1), matching
these headers. Ogg/Vorbis, MP3, FLAC and WAV are decoded by the library itself;
the only optional library shipped alongside is `libxmp.dll`, which 2.6+ needs
for tracker music (.mod/.s3m/.xm). The other optional decoders from the release
(opus, wavpack, gme) are not shipped - add them from the same release if a
project needs those formats.

Keep the DLLs and these headers in step: the bindings are load-time imports, so
calling a function the shipped library does not export does not fail at the call
site - the process refuses to start. `Apus.Engine.SoundSDL` logs both the linked
and the header version at initialization, which makes such a mismatch obvious.

## Bugs / Contributions

If you have any contributions, feel free to drop a pull request or send in a patch.

Same goes for bugs, please use the github issue tracker.

## License

You may license the Pascal SDL 2 Headers either with the MPL license or with the zlib license, both included.
