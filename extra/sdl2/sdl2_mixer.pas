unit sdl2_mixer;

{*
  SDL_mixer:  An audio mixer library based on the SDL library
  Copyright (C) 1997-2013 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*}

{$I jedi.inc}

interface

uses
  {$IFDEF FPC}
  ctypes,
  {$ENDIF}
  SDL2;

{$I ctypes.inc}

const
  {$IFDEF WINDOWS}
    MIX_LibName = 'SDL2_mixer.dll';
  {$ENDIF}

  {$IFDEF UNIX}
    {$IFDEF DARWIN}
      MIX_LibName = 'libSDL2_mixer.dylib';
    {$ELSE}
      {$IFDEF FPC}
        MIX_LibName = 'libSDL2_mixer.so';
      {$ELSE}
        MIX_LibName = 'libSDL2_mixer.so.0';
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF MACOS}
    MIX_LibName = 'SDL2_mixer';
    {$IFDEF FPC}
      {$linklib libSDL2_mixer}
    {$ENDIF}
  {$ENDIF}

  {* Printable format: "%d.%d.%d", MAJOR, MINOR, PATCHLEVEL *}
const
  SDL_MIXER_MAJOR_VERSION = 2;
  SDL_MIXER_MINOR_VERSION = 8;
  SDL_MIXER_PATCHLEVEL    = 1;

  {* This macro can be used to fill a version structure with the compile-time
   * version of the SDL_mixer library.
   *}
procedure SDL_MIXER_VERSION(Out X: TSDL_Version);

  {* Backwards compatibility *}
const
  MIX_MAJOR_VERSION = SDL_MIXER_MAJOR_VERSION;
  MIX_MINOR_VERSION = SDL_MIXER_MINOR_VERSION;
  MIX_PATCHLEVEL    = SDL_MIXER_PATCHLEVEL;

procedure MIX_VERSION(Out X: TSDL_Version);

  {* This function gets the version of the dynamically linked SDL_mixer library.
     it should NOT be used to fill a version structure, instead you should
     use the SDL_MIXER_VERSION() macro.
   *}
function Mix_Linked_Version: PSDL_Version cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Linked_Version' {$ENDIF} {$ENDIF};

type
  PPMix_InitFlags = ^PMix_InitFlags;
  PMix_InitFlags = ^TMix_InitFlags;
  TMix_InitFlags = type cint;

const
  MIX_INIT_FLAC        = TMix_InitFlags($00000001);
  MIX_INIT_MOD         = TMix_InitFlags($00000002);
  MIX_INIT_MP3         = TMix_InitFlags($00000008);
  MIX_INIT_OGG         = TMix_InitFlags($00000010);
  MIX_INIT_MID         = TMix_InitFlags($00000020);
  MIX_INIT_OPUS        = TMix_InitFlags($00000040);
  MIX_INIT_WAVPACK     = TMix_InitFlags($00000080);

// Removed in SDL2_mixer 2.0.2:
// MIX_INIT_MODPLUG     = TMix_InitFlags($00000004);
// MIX_INIT_FLUIDSYNTH  = TMix_InitFlags($00000020);

  {* Loads dynamic libraries and prepares them for use.  Flags should be
     one or more flags from MIX_InitFlags OR'd together.
     It returns the flags successfully initialized, or 0 on failure.
   *}
function Mix_Init(flags: TMix_InitFlags): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Init' {$ENDIF} {$ENDIF};

  {* Unloads libraries loaded with Mix_Init *}
procedure Mix_Quit() cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Quit' {$ENDIF} {$ENDIF};


  {* The default mixer has 8 simultaneous mixing channels *}
{$IFNDEF MIX_CHANNELS}
const
  MIX_CHANNELS = 8;
{$ENDIF}

  {* Good default values for a PC soundcard *}
const
  MIX_DEFAULT_FREQUENCY = 44100;
  MIX_DEFAULT_CHANNELS = 2;
  MIX_MAX_VOLUME       = SDL2.SDL_MIX_MAXVOLUME; {* Volume of a chunk *}

{$IFDEF FPC}
  // This is hidden behind IFDEF because AUDIO_S16SYS is also hidden.
  MIX_DEFAULT_FORMAT = SDL2.AUDIO_S16SYS;
{$ENDIF}

  {* The internal format for an audio chunk *}
type
  PPMix_Chunk = ^PMix_Chunk;
  PMix_Chunk = ^TMix_Chunk;
  TMix_Chunk = record
    allocated: cint;
    abuf: pcuint8;
    alen: cuint32;
    volume: cuint8;       {* Per-sample volume, 0-128 *}
  end;

  {* The different fading types supported *}
type
  PPMix_Fading = ^PMix_Fading;
  PMix_Fading = ^TMix_Fading;
  TMix_Fading = type cint;

const
  MIX_NO_FADING  = TMix_Fading(0);
  MIX_FADING_OUT = TMix_Fading(1);
  MIX_FADING_IN  = TMix_Fading(2);

type
  PPMix_MusicType = ^PMix_MusicType;
  PMix_MusicType = ^TMix_MusicType;
  TMix_MusicType = type cint;

const
  MUS_NONE           = TMix_MusicType(0);
  MUS_CMD            = TMix_MusicType(1);
  MUS_WAV            = TMix_MusicType(2);
  MUS_MOD            = TMix_MusicType(3);
  MUS_MID            = TMix_MusicType(4);
  MUS_OGG            = TMix_MusicType(5);
  MUS_MP3            = TMix_MusicType(6);
  MUS_MP3_MAD_UNUSED = TMix_MusicType(7);
  MUS_FLAC           = TMix_MusicType(8);
  MUS_MODPLUG_UNUSED = TMix_MusicType(9);
  MUS_OPUS           = TMix_MusicType(10);
  MUS_WAVPACK        = TMix_MusicType(11);
  MUS_GM             = TMix_MusicType(12);

type
  {* The internal format for a music chunk interpreted via mikmod *}
  PPMix_Music = ^PMix_Music;
  PMix_Music = type Pointer;

  {* Open the mixer with a certain audio format *}
function Mix_OpenAudio(frequency: cint; format: cuint16; channels: cint; chunksize: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_OpenAudio' {$ENDIF} {$ENDIF};

  { * Open a specific audio device for playback. *}
function Mix_OpenAudioDevice(frequency: cint; format: cuint16; channels: cint; chunksize: cint; device: PAnsiChar; allowed_changes: cint): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_OpenAudioDevice' {$ENDIF} {$ENDIF};

  {* Pause (1) or resume (0) the whole audio output. *}
procedure Mix_PauseAudio(pause_on: cint); cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_PauseAudio' {$ENDIF} {$ENDIF};

  {* Dynamically change the number of channels managed by the mixer.
     If decreasing the number of channels, the upper channels are
     stopped.
     This function returns the new number of allocated channels.
   *}
function Mix_AllocateChannels(numchans: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_AllocateChannels' {$ENDIF} {$ENDIF};

  {* Find out what the actual audio device parameters are.
     This function returns 1 if the audio has been opened, 0 otherwise.
   *}
function Mix_QuerySpec(frequency: pcint; format: pcuint16; channels: pcint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_QuerySpec' {$ENDIF} {$ENDIF};

  {* Load a wave file or a music (.mod .s3m .it .xm) file *}
function Mix_LoadWAV_RW(src: PSDL_RWops; freesrc: cint): PMix_Chunk cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_LoadWAV_RW' {$ENDIF} {$ENDIF};
function Mix_LoadWAV(_file: PAnsiChar): PMix_Chunk cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_LoadWAV' {$ENDIF} {$ENDIF};
function Mix_LoadMUS(_file: PAnsiChar): PMix_Music cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_LoadMUS' {$ENDIF} {$ENDIF};

  {* Load a music file from an SDL_RWop object (Ogg and MikMod specific currently)
     Matt Campbell (matt@campbellhome.dhs.org) April 2000 *}
function Mix_LoadMUS_RW(src: PSDL_RWops; freesrc: cint): PMix_Music cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_LoadMUS_RW' {$ENDIF} {$ENDIF};

  {* Load a music file from an SDL_RWop object assuming a specific format *}
function Mix_LoadMUSType_RW(src: PSDL_RWops; _type: TMix_MusicType; freesrc: cint): PMix_Music cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_LoadMUSType_RW' {$ENDIF} {$ENDIF};

  {* Load a wave file of the mixer format from a memory buffer *}
function Mix_QuickLoad_WAV(mem: pcuint8): PMix_Chunk cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_QuickLoad_WAV' {$ENDIF} {$ENDIF};

  {* Load raw audio data of the mixer format from a memory buffer *}
function Mix_QuickLoad_RAW(mem: pcuint8; len: cuint32): PMix_Chunk cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_QuickLoad_RAW' {$ENDIF} {$ENDIF};

  {* Free an audio chunk previously loaded *}
procedure Mix_FreeChunk(chunk: PMix_Chunk) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FreeChunk' {$ENDIF} {$ENDIF};
procedure Mix_FreeMusic(music: PMix_Music) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FreeMusic' {$ENDIF} {$ENDIF};

  {* Get a list of chunk/music decoders that this build of SDL_mixer provides.
     This list can change between builds AND runs of the program, if external
     libraries that add functionality become available.
     You must successfully call Mix_OpenAudio() before calling these functions.
     This API is only available in SDL_mixer 1.2.9 and later.

     // usage...
     int i;
     const int total = Mix_GetNumChunkDecoders();
     for (i = 0; i < total; i++)
         printf("Supported chunk decoder: [%s]\n", Mix_GetChunkDecoder(i));

     Appearing in this list doesn't promise your specific audio file will
     decode...but it's handy to know if you have, say, a functioning Timidity
     install.

     These return values are static, read-only data; do not modify or free it.
     The pointers remain valid until you call Mix_CloseAudio().
  *}
function Mix_GetNumChunkDecoders: cint cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetNumChunkDecoders' {$ENDIF} {$ENDIF};
function Mix_GetChunkDecoder(index: cint): PAnsiChar cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetChunkDecoder' {$ENDIF} {$ENDIF};
function Mix_HasChunkDecoder(const name: PAnsiChar): TSDL_Bool cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_HasChunkDecoder' {$ENDIF} {$ENDIF};
function Mix_GetNumMusicDecoders: cint cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetNumMusicDecoders' {$ENDIF} {$ENDIF};
function Mix_GetMusicDecoder(index: cint): PAnsiChar cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicDecoder' {$ENDIF} {$ENDIF};
function Mix_HasMusicDecoder(const name: PAnsiChar): TSDL_Bool cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_HasMusicDecoder' {$ENDIF} {$ENDIF};

  {* Find out the music format of a mixer music, or the currently playing
     music, if 'music' is NULL.
  *}
function Mix_GetMusicType(music: PMix_Music): TMix_MusicType cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicType' {$ENDIF} {$ENDIF};

  {* Get the title for a music object, or its filename.
     This returns format-specific metadata. Not all formats support this!

     If `music` is NULL, this will query the currently-playing music.

     If the music's title tag is missing or empty, the filename will be returned instead.

     This function never returns NIL! If no data is available, it will return an empty string.
  *}
function Mix_GetMusicTitle(music: PMix_Music): PAnsiChar; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicTitle' {$ENDIF} {$ENDIF};

  {* Get the title for a music object.
     This returns format-specific metadata. Not all formats support this!

     If `music` is NULL, this will query the currently-playing music.

     This function never returns NIL! If no data is available, it will return an empty string.
  *}
function Mix_GetMusicTitleTag(music: PMix_Music): PAnsiChar; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicTitleTag' {$ENDIF} {$ENDIF};

  {* Get the artist name for a music object.
     This returns format-specific metadata. Not all formats support this!

     If `music` is NULL, this will query the currently-playing music.

     This function never returns NIL! If no data is available, it will return an empty string.
  *}
function Mix_GetMusicArtistTag(music: PMix_Music): PAnsiChar; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicArtistTag' {$ENDIF} {$ENDIF};

  {* Get the album name for a music object.
     This returns format-specific metadata. Not all formats support this!

     If `music` is NULL, this will query the currently-playing music.

     This function never returns NIL! If no data is available, it will return an empty string.
  *}
function Mix_GetMusicAlbumTag(music: PMix_Music): PAnsiChar; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicAlbumTag' {$ENDIF} {$ENDIF};

  {* Get the copyright text for a music object.
     This returns format-specific metadata. Not all formats support this!

     If `music` is NULL, this will query the currently-playing music.

     This function never returns NIL! If no data is available, it will return an empty string.
  *}
function Mix_GetMusicCopyrightTag(music: PMix_Music): PAnsiChar; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicCopyrightTag' {$ENDIF} {$ENDIF};

  {* Set a function that is called after all mixing is performed.
     This can be used to provide real-time visual display of the audio stream
     or add a custom mixer filter for the stream data.
  *}
type
  PPMix_Func = ^PMix_Func;
  PMix_Func = ^TMix_Func;
  TMix_Func = procedure(udata: Pointer; stream: pcuint8; len: cint) cdecl;

procedure Mix_SetPostMix(func: TMix_Func; arg: Pointer) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetPostMix' {$ENDIF} {$ENDIF};

  {* Add your own music player or additional mixer function.
     If 'mix_func' is NULL, the default music player is re-enabled.
   *}
procedure Mix_HookMusic(func: TMix_Func; arg: Pointer) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_HookMusic' {$ENDIF} {$ENDIF};

  {* Add your own callback when the music has finished playing
   *  or when it is stopped from a call to Mix_HaltMusic.
   *}
type
  PPMix_Music_Finished = ^PMix_Music_Finished;
  PMix_Music_Finished = ^TMix_Music_Finished;
  TMix_Music_Finished = procedure() cdecl;

procedure Mix_HookMusicFinished(music_finished: PMix_Music_Finished) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_HookMusicFinished' {$ENDIF} {$ENDIF};

  {* Get a pointer to the user data for the current music hook *}
function Mix_GetMusicHookData: Pointer cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicHookData' {$ENDIF} {$ENDIF};

  {*
   * Add your own callback when a channel has finished playing. NULL
   *  to disable callback. The callback may be called from the mixer's audio
   *  callback or it could be called as a result of Mix_HaltChannel(), etc.
   *  do not call SDL_LockAudio() from this callback; you will either be
   *  inside the audio callback, or SDL_mixer will explicitly lock the audio
   *  before calling your callback.
   *}
type
  PPMix_Channel_Finished = ^PMix_Channel_Finished;
  PMix_Channel_Finished = ^TMix_Channel_Finished;
  TMix_Channel_Finished = procedure(channel: cint) cdecl;

procedure Mix_ChannelFinished(channel_finished: TMix_Channel_Finished) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_ChannelFinished' {$ENDIF} {$ENDIF};

  {* Special Effects API by ryan c. gordon. (icculus@icculus.org) *}
const
  MIX_CHANNEL_POST = -2;

  {* This is the format of a special effect callback:
   *
   *   myeffect(int chan, void *stream, int len, void *udata);
   *
   * (chan) is the channel number that your effect is affecting. (stream) is
   *  the buffer of data to work upon. (len) is the size of (stream), and
   *  (udata) is a user-defined bit of data, which you pass as the last arg of
   *  Mix_RegisterEffect(), and is passed back unmolested to your callback.
   *  Your effect changes the contents of (stream) based on whatever parameters
   *  are significant, or just leaves it be, if you prefer. You can do whatever
   *  you like to the buffer, though, and it will continue in its changed state
   *  down the mixing pipeline, through any other effect functions, then finally
   *  to be mixed with the rest of the channels and music for the final output
   *  stream.
   *
   * DO NOT EVER call SDL_LockAudio() from your callback function!
   *}
type
  PPMix_EffectFunc_t = ^PMix_EffectFunc_t;
  PMix_EffectFunc_t = ^TMix_EffectFunc_t;
  TMix_EffectFunc_t = procedure(chan: cint; stream: Pointer; len: cint; udata: Pointer) cdecl;

  {*
   * This is a callback that signifies that a channel has finished all its
   *  loops and has completed playback. This gets called if the buffer
   *  plays out normally, or if you call Mix_HaltChannel(), implicitly stop
   *  a channel via Mix_AllocateChannels(), or unregister a callback while
   *  it's still playing.
   *
   * DO NOT EVER call SDL_LockAudio() from your callback function!
   *}
type
  PPMix_EffectDone_t = ^PMix_EffectDone_t;
  PMix_EffectDone_t = ^TMix_EffectDone_t;
  TMix_EffectDone_t = procedure(chan: cint; udata: Pointer) cdecl;

  {* Register a special effect function. At mixing time, the channel data is
   *  copied into a buffer and passed through each registered effect function.
   *  After it passes through all the functions, it is mixed into the final
   *  output stream. The copy to buffer is performed once, then each effect
   *  function performs on the output of the previous effect. Understand that
   *  this extra copy to a buffer is not performed if there are no effects
   *  registered for a given chunk, which saves CPU cycles, and any given
   *  effect will be extra cycles, too, so it is crucial that your code run
   *  fast. Also note that the data that your function is given is in the
   *  format of the sound device, and not the format you gave to Mix_OpenAudio(),
   *  although they may in reality be the same. This is an unfortunate but
   *  necessary speed concern. Use Mix_QuerySpec() to determine if you can
   *  handle the data before you register your effect, and take appropriate
   *  actions.
   * You may also specify a callback (Mix_EffectDone_t) that is called when
   *  the channel finishes playing. This gives you a more fine-grained control
   *  than Mix_ChannelFinished(), in case you need to free effect-specific
   *  resources, etc. If you don't need this, you can specify NULL.
   * You may set the callbacks before or after calling Mix_PlayChannel().
   * Things like Mix_SetPanning() are just internal special effect functions,
   *  so if you are using that, you've already incurred the overhead of a copy
   *  to a separate buffer, and that these effects will be in the queue with
   *  any functions you've registered. The list of registered effects for a
   *  channel is reset when a chunk finishes playing, so you need to explicitly
   *  set them with each call to Mix_PlayChannel*().
   * You may also register a special effect function that is to be run after
   *  final mixing occurs. The rules for these callbacks are identical to those
   *  in Mix_RegisterEffect, but they are run after all the channels and the
   *  music have been mixed into a single stream, whereas channel-specific
   *  effects run on a given channel before any other mixing occurs. These
   *  global effect callbacks are call "posteffects". Posteffects only have
   *  their Mix_EffectDone_t function called when they are unregistered (since
   *  the main output stream is never "done" in the same sense as a channel).
   *  You must unregister them manually when you've had enough. Your callback
   *  will be told that the channel being mixed is (MIX_CHANNEL_POST) if the
   *  processing is considered a posteffect.
   *
   * After all these effects have finished processing, the callback registered
   *  through Mix_SetPostMix() runs, and then the stream goes to the audio
   *  device.
   *
   * DO NOT EVER call SDL_LockAudio() from your callback function!
   *
   * returns zero if error (no such channel), nonzero if added.
   *  Error messages can be retrieved from Mix_GetError().
   *}
function Mix_RegisterEffect(chan: cint; f: TMix_EffectFunc_t; d: TMix_EffectDone_t; arg: Pointer): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_RegisterEffect' {$ENDIF} {$ENDIF};

  {* You may not need to call this explicitly, unless you need to stop an
   *  effect from processing in the middle of a chunk's playback.
   * Posteffects are never implicitly unregistered as they are for channels,
   *  but they may be explicitly unregistered through this function by
   *  specifying MIX_CHANNEL_POST for a channel.
   * returns zero if error (no such channel or effect), nonzero if removed.
   *  Error messages can be retrieved from Mix_GetError().
   *}
function Mix_UnregisterEffect(channel: cint; f: TMix_EffectFunc_t): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_UnregisterEffect' {$ENDIF} {$ENDIF};

  {* You may not need to call this explicitly, unless you need to stop all
   *  effects from processing in the middle of a chunk's playback. Note that
   *  this will also shut off some internal effect processing, since
   *  Mix_SetPanning() and others may use this API under the hood. This is
   *  called internally when a channel completes playback.
   * Posteffects are never implicitly unregistered as they are for channels,
   *  but they may be explicitly unregistered through this function by
   *  specifying MIX_CHANNEL_POST for a channel.
   * returns zero if error (no such channel), nonzero if all effects removed.
   *  Error messages can be retrieved from Mix_GetError().
   *}
function Mix_UnregisterAllEffects(channel: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_UnregisterEffects' {$ENDIF} {$ENDIF};

const
  MIX_EFFECTSMAXSPEED = 'MIX_EFFECTSMAXSPEED';

  {*
   * These are the internally-defined mixing effects. They use the same API that
   *  effects defined in the application use, but are provided here as a
   *  convenience. Some effects can reduce their quality or use more memory in
   *  the name of speed; to enable this, make sure the environment variable
   *  MIX_EFFECTSMAXSPEED (see above) is defined before you call
   *  Mix_OpenAudio().
   *}

  {* Set the panning of a channel. The left and right channels are specified
   *  as integers between 0 and 255, quietest to loudest, respectively.
   *
   * Technically, this is just individual volume control for a sample with
   *  two (stereo) channels, so it can be used for more than just panning.
   *  If you want real panning, call it like this:
   *
   *   Mix_SetPanning(channel, left, 255 - left);
   *
   * ...which isn't so hard.
   *
   * Setting (channel) to MIX_CHANNEL_POST registers this as a posteffect, and
   *  the panning will be done to the final mixed stream before passing it on
   *  to the audio device.
   *
   * This uses the Mix_RegisterEffect() API internally, and returns without
   *  registering the effect function if the audio device is not configured
   *  for stereo output. Setting both (left) and (right) to 255 causes this
   *  effect to be unregistered, since that is the data's normal state.
   *
   * returns zero if error (no such channel or Mix_RegisterEffect() fails),
   *  nonzero if panning effect enabled. Note that an audio device in mono
   *  mode is a no-op, but this call will return successful in that case.
   *  Error messages can be retrieved from Mix_GetError().
   *}
function Mix_SetPanning(channel: cint; left: cuint8; right: cuint8): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetPanning' {$ENDIF} {$ENDIF};

  {* Set the position of a channel. (angle) is an integer from 0 to 360, that
   *  specifies the location of the sound in relation to the listener. (angle)
   *  will be reduced as neccesary (540 becomes 180 degrees, -100 becomes 260).
   *  Angle 0 is due north, and rotates clockwise as the value increases.
   *  For efficiency, the precision of this effect may be limited (angles 1
   *  through 7 might all produce the same effect, 8 through 15 are equal, etc).
   *  (distance) is an integer between 0 and 255 that specifies the space
   *  between the sound and the listener. The larger the number, the further
   *  away the sound is. Using 255 does not guarantee that the channel will be
   *  culled from the mixing process or be completely silent. For efficiency,
   *  the precision of this effect may be limited (distance 0 through 5 might
   *  all produce the same effect, 6 through 10 are equal, etc). Setting (angle)
   *  and (distance) to 0 unregisters this effect, since the data would be
   *  unchanged.
   *
   * If you need more precise positional audio, consider using OpenAL for
   *  spatialized effects instead of SDL_mixer. This is only meant to be a
   *  basic effect for simple "3D" games.
   *
   * If the audio device is configured for mono output, then you won't get
   *  any effectiveness from the angle; however, distance attenuation on the
   *  channel will still occur. While this effect will function with stereo
   *  voices, it makes more sense to use voices with only one channel of sound,
   *  so when they are mixed through this effect, the positioning will sound
   *  correct. You can convert them to mono through SDL before giving them to
   *  the mixer in the first place if you like.
   *
   * Setting (channel) to MIX_CHANNEL_POST registers this as a posteffect, and
   *  the positioning will be done to the final mixed stream before passing it
   *  on to the audio device.
   *
   * This is a convenience wrapper over Mix_SetDistance() and Mix_SetPanning().
   *
   * returns zero if error (no such channel or Mix_RegisterEffect() fails),
   *  nonzero if position effect is enabled.
   *  Error messages can be retrieved from Mix_GetError().
   *}
function Mix_SetPosition(channel: cint; angle: cint16; distance: cuint8): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetPosition' {$ENDIF} {$ENDIF};

  {* Set the "distance" of a channel. (distance) is an integer from 0 to 255
   *  that specifies the location of the sound in relation to the listener.
   *  Distance 0 is overlapping the listener, and 255 is as far away as possible
   *  A distance of 255 does not guarantee silence; in such a case, you might
   *  want to try changing the chunk's volume, or just cull the sample from the
   *  mixing process with Mix_HaltChannel().
   * For efficiency, the precision of this effect may be limited (distances 1
   *  through 7 might all produce the same effect, 8 through 15 are equal, etc).
   *  (distance) is an integer between 0 and 255 that specifies the space
   *  between the sound and the listener. The larger the number, the further
   *  away the sound is.
   * Setting (distance) to 0 unregisters this effect, since the data would be
   *  unchanged.
   * If you need more precise positional audio, consider using OpenAL for
   *  spatialized effects instead of SDL_mixer. This is only meant to be a
   *  basic effect for simple "3D" games.
   *
   * Setting (channel) to MIX_CHANNEL_POST registers this as a posteffect, and
   *  the distance attenuation will be done to the final mixed stream before
   *  passing it on to the audio device.
   *
   * This uses the Mix_RegisterEffect() API internally.
   *
   * returns zero if error (no such channel or Mix_RegisterEffect() fails),
   *  nonzero if position effect is enabled.
   *  Error messages can be retrieved from Mix_GetError().
   *}
function Mix_SetDistance(channel: cint; distance: cuint8): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetDistance' {$ENDIF} {$ENDIF};

{*
 * !!! FIXME : Haven't implemented, since the effect goes past the
 *              end of the sound buffer. Will have to think about this.
 *               --ryan.
 *}
//#if 0
{* Causes an echo effect to be mixed into a sound. (echo) is the amount
 *  of echo to mix. 0 is no echo, 255 is infinite (and probably not
 *  what you want).
 *
 * Setting (channel) to MIX_CHANNEL_POST registers this as a posteffect, and
 *  the reverbing will be done to the final mixed stream before passing it on
 *  to the audio device.
 *
 * This uses the Mix_RegisterEffect() API internally. If you specify an echo
 *  of zero, the effect is unregistered, as the data is already in that state.
 *
 * returns zero if error (no such channel or Mix_RegisterEffect() fails),
 *  nonzero if reversing effect is enabled.
 *  Error messages can be retrieved from Mix_GetError().
 *}
//extern no_parse_DECLSPEC int SDLCALL Mix_SetReverb(int channel, Uint8 echo);
//#endif

  {* Causes a channel to reverse its stereo. This is handy if the user has his
   *  speakers hooked up backwards, or you would like to have a minor bit of
   *  psychedelia in your sound code.  :)  Calling this function with (flip)
   *  set to non-zero reverses the chunks's usual channels. If (flip) is zero,
   *  the effect is unregistered.
   *
   * This uses the Mix_RegisterEffect() API internally, and thus is probably
   *  more CPU intensive than having the user just plug in his speakers
   *  correctly. Mix_SetReverseStereo() returns without registering the effect
   *  function if the audio device is not configured for stereo output.
   *
   * If you specify MIX_CHANNEL_POST for (channel), then this the effect is used
   *  on the final mixed stream before sending it on to the audio device (a
   *  posteffect).
   *
   * returns zero if error (no such channel or Mix_RegisterEffect() fails),
   *  nonzero if reversing effect is enabled. Note that an audio device in mono
   *  mode is a no-op, but this call will return successful in that case.
   *  Error messages can be retrieved from Mix_GetError().
   *}
function Mix_SetReverseStereo(channel: cint; flip: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetReverseStereo' {$ENDIF} {$ENDIF};

  {* end of effects API. --ryan. *}

  {* Reserve the first channels (0 -> n-1) for the application, i.e. don't allocate
     them dynamically to the next sample if requested with a -1 value below.
     Returns the number of reserved channels.
   *}
function Mix_ReserveChannels(num: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_ReverseChannels' {$ENDIF} {$ENDIF};

  {* Channel grouping functions *}

  {* Attach a tag to a channel. A tag can be assigned to several mixer
     channels, to form groups of channels.
     If 'tag' is -1, the tag is removed (actually -1 is the tag used to
     represent the group of all the channels).
     Returns true if everything was OK.
   *}
function Mix_GroupChannel(which: cint; tag: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GroupChannel' {$ENDIF} {$ENDIF};
  {* Assign several consecutive channels to a group *}
function Mix_GroupChannels(from: cint; _to: cint; tag: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GroupChannels' {$ENDIF} {$ENDIF};
  {* Finds the first available channel in a group of channels,
     returning -1 if none are available.
   *}
function Mix_GroupAvailable(tag: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GroupAvailable' {$ENDIF} {$ENDIF};
  {* Returns the number of channels in a group. This is also a subtle
     way to get the total number of channels when 'tag' is -1
   *}
function Mix_GroupCount(tag: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GroupCount' {$ENDIF} {$ENDIF};
  {* Finds the "oldest" sample playing in a group of channels *}
function Mix_GroupOldest(tag: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GroupOldest' {$ENDIF} {$ENDIF};
  {* Finds the "most recent" (i.e. last) sample playing in a group of channels *}
function Mix_GroupNewer(tag: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GroupNewer' {$ENDIF} {$ENDIF};

  {* Play an audio chunk on a specific channel.
     If the specified channel is -1, play on the first free channel.
     If 'loops' is greater than zero, loop the sound that many times.
     If 'loops' is -1, loop inifinitely (~65000 times).
     Returns which channel was used to play the sound.
  *}
function Mix_PlayChannel(channel: cint; chunk: PMix_Chunk; loops: cint): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_PlayChannel' {$ENDIF} {$ENDIF};
  {* The same as above, but the sound is played at most 'ticks' milliseconds *}
function Mix_PlayChannelTimed(channel: cint; chunk: PMix_Chunk; loops: cint; ticks: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_PlayChannelTimed' {$ENDIF} {$ENDIF};
function Mix_PlayMusic(music: PMix_Music; loops: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_PlayMusic' {$ENDIF} {$ENDIF};

  {* Fade in music or a channel over "ms" milliseconds, same semantics as the "Play" functions *}
function Mix_FadeInMusic(music: PMix_Music; loops: cint; ms: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadeInMusic' {$ENDIF} {$ENDIF};
function Mix_FadeInMusicPos(music: PMix_Music; loops: cint; ms: cint; position: cdouble): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadeInMusicPos' {$ENDIF} {$ENDIF};
function Mix_FadeInChannel(channel: cint; chunk: PMix_Chunk; loops: cint; ms: cint): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadeInChannel' {$ENDIF} {$ENDIF};
function Mix_FadeInChannelTimed(channel: cint; chunk: PMix_Chunk; loops: cint; ms: cint; ticks: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadeInChannelTimed' {$ENDIF} {$ENDIF};

  {* Set the volume in the range of 0-128 of a specific channel or chunk.
     If the specified channel is -1, set volume for all channels.
     Returns the original volume.
     If the specified volume is -1, just return the current volume.
  *}
function Mix_Volume(channel: cint; volume: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Volume' {$ENDIF} {$ENDIF};
function Mix_VolumeChunk(chunk: PMix_Chunk; volume: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_VolumeChunk' {$ENDIF} {$ENDIF};
function Mix_VolumeMusic(volume: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_VolumeMusic' {$ENDIF} {$ENDIF};

  {* Query the current volume for a music object. *}
function Mix_GetMusicVolume(music: PMix_Music): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicVolume' {$ENDIF} {$ENDIF};

  {* Set the master volume for all channels.

     SDL_Mixer keeps a per-channel volume, a per-chunk volume, and a master volume.
     All three are considered when mixing audio.

     Note that the master volume does not affect any playing music;
     it is only applied when mixing chunks. Use Mix_VolumeMusic() for that.

     If the specified volume is -1, this returns the current volume.
  *}
function Mix_MasterVolume(volume: cint): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_MasterVolume' {$ENDIF} {$ENDIF};

  {* Halt playing of a particular channel *}
function Mix_HaltChannel(channel: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_HaltChannel' {$ENDIF} {$ENDIF};
function Mix_HaltGroup(tag: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_HaltGroup' {$ENDIF} {$ENDIF};
function Mix_HaltMusic: cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_HaltMusic' {$ENDIF} {$ENDIF};

  {* Change the expiration delay for a particular channel.
     The sample will stop playing after the 'ticks' milliseconds have elapsed,
     or remove the expiration if 'ticks' is -1
  *}
function Mix_ExpireChannel(channel: cint; ticks: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_ExpireChannel' {$ENDIF} {$ENDIF};

  {* Halt a channel, fading it out progressively till it's silent
     The ms parameter indicates the number of milliseconds the fading
     will take.
   *}
function Mix_FadeOutChannel(which: cint; ms: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadeOutChannel' {$ENDIF} {$ENDIF};
function Mix_FadeOutGroup(tag: cint; ms: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadeOutGroup' {$ENDIF} {$ENDIF};
function Mix_FadeOutMusic(ms: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadeOutMusic' {$ENDIF} {$ENDIF};

  {* Query the fading status of a channel *}
function Mix_FadingMusic: TMix_Fading cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadingMusic' {$ENDIF} {$ENDIF};
function Mix_FadingChannel(which: cint): TMix_Fading cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_FadingChannel' {$ENDIF} {$ENDIF};

  {* Pause/Resume a particular channel *}
procedure Mix_Pause(channel: cint) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Pause' {$ENDIF} {$ENDIF};
procedure Mix_Resume(channel: cint) cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Resume' {$ENDIF} {$ENDIF};
function Mix_Paused(channel: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Paused' {$ENDIF} {$ENDIF};

  {* Pause/Resume the music stream *}
procedure Mix_PauseMusic cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_PauseMusic' {$ENDIF} {$ENDIF};
procedure Mix_ResumeMusic cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_ResumeMusic' {$ENDIF} {$ENDIF};
procedure Mix_RewindMusic cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_RewindMusic' {$ENDIF} {$ENDIF};
function Mix_PausedMusic: cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_PausedMusic' {$ENDIF} {$ENDIF};

  {* Jump to a given order in MOD music. *}
function Mix_ModMusicJumpToOrder(order: cint): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_ModMusicJumpToOrder' {$ENDIF} {$ENDIF};

  {* Set a track in a GME music object. *}
function Mix_StartTrack(music: PMix_Music; track: cint): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_StartTrack' {$ENDIF} {$ENDIF};

  {* Get number of tracks in a GME music object. *}
function Mix_GetNumTracks(music: PMix_Music): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetNumTracks' {$ENDIF} {$ENDIF};

  {* Set the current position in the music stream.
     This returns 0 if successful, or -1 if it failed or isn't implemented.
     This function is only implemented for MOD music formats (set pattern
     order number) and for OGG, FLAC, MP3_MAD, MP3_MPG and MODPLUG music
     (set position in seconds), at the moment.
  *}
function Mix_SetMusicPosition(position: cdouble): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetMusicPosition' {$ENDIF} {$ENDIF};

  {* Get the current position of a music stream, in seconds.
     Returns -1.0 if this feature is not supported for some codec.
  *}
function Mix_GetMusicPosition(music: PMix_Music): cdouble; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicPosition' {$ENDIF} {$ENDIF};

  {* Get a music object's duration, in seconds.
     If NIL is passed, returns duration of currently playing music.
     Returns -1.0 on error.
  *}
function Mix_MusicDuration(music: PMix_Music): cdouble; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_MusicDuration' {$ENDIF} {$ENDIF};

  {* Get the loop start time position of a music stream, in seconds.
     Returns -1.0 if this feature is not used by this music
     or unsupported by the codec.
  *}
function Mix_GetMusicLoopStartTime(music: PMix_Music): cdouble; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicLoopStartTime' {$ENDIF} {$ENDIF};

  {* Get the loop end time position of a music stream, in seconds.
     Returns -1.0 if this feature is not used by this music
     or unsupported by the codec.
  *}
function Mix_GetMusicLoopEndTime(music: PMix_Music): cdouble; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicLoopEndTime' {$ENDIF} {$ENDIF};

  {* Get the loop time length of a music stream, in seconds.
     Returns -1.0 if this feature is not used by this music
     or unsupported by the codec.
  *}
function Mix_GetMusicLoopLengthTime(music: PMix_Music): cdouble; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetMusicLoopLengthTime' {$ENDIF} {$ENDIF};

  {* Check the status of a specific channel.
     If the specified channel is -1, check all channels.
  *}
function Mix_Playing(channel: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_Playing' {$ENDIF} {$ENDIF};
function Mix_PlayingMusic: cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_PlayingMusic' {$ENDIF} {$ENDIF};

  {* Stop music and set external music playback command *}
function Mix_SetMusicCMD(command: PAnsiChar): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetMusicCMD' {$ENDIF} {$ENDIF};

  {* Synchro value is set by MikMod from modules while playing *}
function Mix_SetSynchroValue(value: cint): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetSynchroValue' {$ENDIF} {$ENDIF};
function Mix_GetSynchroValue: cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetSynchroValue' {$ENDIF} {$ENDIF};

  {* Set/Get/Iterate SoundFonts paths to use by supported MIDI backends *}
function Mix_SetSoundFonts(paths: PAnsiChar): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetSoundFonts' {$ENDIF} {$ENDIF};
function Mix_GetSoundFonts: PAnsiChar cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetSoundFonts' {$ENDIF} {$ENDIF};

type
  PPMix_SoundFunc = ^PMix_SoundFunc;
  PMix_SoundFunc = ^TMix_SoundFunc;
  TMix_SoundFunc = function(c: PAnsiChar; p: Pointer): cint cdecl;

function Mix_EachSoundFont(func: TMix_SoundFunc; data: Pointer): cint cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_EachSoundFont' {$ENDIF} {$ENDIF};

  {* Set full path of the Timidity config file.
     This is only useful if SDL_Mixer is using Timidity to play MIDI files.
  *}
function Mix_SetTimidityCfg(path: PAnsiChar): cint; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_SetTimidityCfg' {$ENDIF} {$ENDIF};

  {* Get full path of previously specified Timidity config file.
     If a path has never been specified, this returns NIL.

     This returns a pointer to internal memory;
     it must not be modified nor freed by the caller.
  *}
function Mix_GetTimidityCfg(): PAnsiChar; cdecl;
  external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetTimidityCfg' {$ENDIF} {$ENDIF};

  {* Get the Mix_Chunk currently associated with a mixer channel
      Returns NULL if it's an invalid channel, or there's no chunk associated.
  *}
function Mix_GetChunk(channel: cint): PMix_Chunk cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_GetChunk' {$ENDIF} {$ENDIF};

  {* Close the mixer, halting all playing audio *}
procedure Mix_CloseAudio cdecl; external MIX_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_MIX_CloseAudio' {$ENDIF} {$ENDIF};

{* We'll use SDL for reporting errors *}
function Mix_SetError(const fmt: PAnsiChar; args: array of const): cint; cdecl;
  external SDL_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_SDL_SetError' {$ELSE} 'SDL_SetError' {$ENDIF};
function Mix_GetError: PAnsiChar; cdecl;
  external SDL_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_SDL_GetError' {$ELSE} 'SDL_GetError' {$ENDIF};
procedure Mix_ClearError(); cdecl;
  external SDL_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_SDL_ClearError' {$ELSE} 'SDL_ClearError' {$ENDIF};

implementation

procedure SDL_MIXER_VERSION(Out X: TSDL_Version);
begin
  X.major := SDL_MIXER_MAJOR_VERSION;
  X.minor := SDL_MIXER_MINOR_VERSION;
  X.patch := SDL_MIXER_PATCHLEVEL;
end;

procedure MIX_VERSION(Out X: TSDL_Version);
begin
  SDL_MIXER_VERSION(X);
end;

end.
