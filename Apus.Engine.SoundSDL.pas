// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

// SDL2_mixer sound backend: covers level 1 of the audio requirements
// (play samples and stream music as-is + volume control). Its ceiling is known:
// no pitch, no loop points, panning for samples only and a single music stream
// (so music crossfade is impossible here) - these belong to the miniaudio
// backend. See Work/R-28_audio_activation.md.
unit Apus.Engine.SoundSDL;
interface
uses Apus.Engine.Sound;

type
 TSoundLibSDL=class(TInterfacedObject,ISoundLib)
  procedure Init(windowHandle:THandle=0);
  procedure SetVolume(volumeType:TVolumeType;volume:single); // 0..1
  function OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
  function PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
  procedure StopChannel(var channel:TChannel);
  procedure SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
  procedure SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue:single;timeInterval:single);
  procedure Pause(pause:boolean);
  procedure Done;

  function CanSlide:TChannelAttributes;
  function CanFadeMusic:boolean;
  function HasSingleMusicStream:boolean;
  function IsPlaying(channel:TChannel):boolean;
 end;

implementation
uses SysUtils, SDL2, sdl2_mixer,
  Apus.Core,
  Apus.Log,
  Apus.Types;

const
 // Number of simultaneously playing samples
 SAMPLE_CHANNELS = 32;
 // Slot of the (single) music stream: slots 0..SAMPLE_CHANNELS-1 are SDL_mixer channels
 MUSIC_SLOT = SAMPLE_CHANNELS;
 // Channel handle layout: low 8 bits = slot+1 (so 0 is "no channel"),
 // high 24 bits = generation of the slot at the moment the playback started
 SLOT_BITS = 8;
 SLOT_MASK = $FF;
 GENERATION_MASK = $FFFFFF;

type
 TMediaFileSDL=class(TMediaFile)
  chunk:PMix_Chunk;   // loaded sample
  music:PMix_Music;   // music stream
  destructor Destroy; override;
 end;

 // Mixing slot: an SDL_mixer channel or the music stream
 TSlotSDL=record
  generation:cardinal; // bumped on every playback start, so older handles of the slot become stale
  relVolume:single;    // volume requested for the current playback (before the global one)
 end;

var
 globalMusicVolume:single=1.0;
 globalSoundVolume:single=1.0;
 slots:array[0..MUSIC_SLOT] of TSlotSDL;
 ownAudioSubsystem:boolean; // did this backend initialize SDL's audio subsystem?

{ TMediaFileSDL }

destructor TMediaFileSDL.Destroy;
 begin
  if chunk<>nil then Mix_FreeChunk(chunk);
  if music<>nil then Mix_FreeMusic(music);
  chunk:=nil;
  music:=nil;
  inherited;
 end;

{ Helpers }

// Slot of a live channel handle, -1 for an empty or stale one
function SlotOf(channel:TChannel):integer;
 begin
  result:=integer(cardinal(channel) and SLOT_MASK)-1;
  if (result<0) or (result>MUSIC_SLOT) then exit(-1);
  if slots[result].generation<>cardinal(channel) shr SLOT_BITS then result:=-1;
 end;

// Start a new playback in the slot: the previous handles of the slot become stale
function NewHandle(slot:integer):TChannel;
 begin
  slots[slot].generation:=(slots[slot].generation+1) and GENERATION_MASK;
  result:=TChannel((slots[slot].generation shl SLOT_BITS) or cardinal(slot+1));
 end;

// Panning: -1 = full left, 0 = center, 1 = full right
procedure SetPanning(channel:integer;pan:single);
 var
  left,right:integer;
 begin
  right:=Clamp(round(255*(1+pan)),0,255);
  left:=Clamp(round(255*(1-pan)),0,255);
  Mix_SetPanning(channel,left,right);
 end;

procedure ApplySlotVolume(slot:integer);
 begin
  if slot=MUSIC_SLOT then
   Mix_VolumeMusic(round(slots[slot].relVolume*globalMusicVolume*MIX_MAX_VOLUME))
  else
   Mix_Volume(slot,round(slots[slot].relVolume*globalSoundVolume*MIX_MAX_VOLUME));
 end;

// Report which decoders are actually available in the linked SDL2_mixer build
procedure InitDecoders;
 var
  wanted,got:integer;
  st:String8;
 begin
  wanted:=MIX_INIT_OGG or MIX_INIT_MP3 or MIX_INIT_FLAC or MIX_INIT_MOD or MIX_INIT_OPUS;
  got:=Mix_Init(wanted);
  st:='';
  if got and MIX_INIT_OGG>0 then st:=st+' ogg';
  if got and MIX_INIT_MP3>0 then st:=st+' mp3';
  if got and MIX_INIT_FLAC>0 then st:=st+' flac';
  if got and MIX_INIT_MOD>0 then st:=st+' mod';
  if got and MIX_INIT_OPUS>0 then st:=st+' opus';
  // wav is decoded by SDL itself, so a missing decoder is a warning, not a failure
  if got=0 then
   Log.Warn('[SDL_MIX] No optional decoders available: '+Mix_GetError)
  else begin
   Log.Info('[SDL_MIX] Decoders:'+st);
   if got<>wanted then Log.Info('[SDL_MIX] Some decoders are missing: '+Mix_GetError);
  end;
 end;

{ TSoundLibSDL }

function TSoundLibSDL.CanSlide:TChannelAttributes;
 begin
  result:=[]; // SDL_mixer can only fade out, see SlideChannel
 end;

function TSoundLibSDL.CanFadeMusic:boolean;
 begin
  result:=true;
 end;

function TSoundLibSDL.HasSingleMusicStream:boolean;
 begin
  result:=true; // SDL_mixer mixes many samples, but plays one music stream
 end;

function TSoundLibSDL.IsPlaying(channel:TChannel):boolean;
 var
  slot:integer;
 begin
  slot:=SlotOf(channel);
  if slot<0 then exit(false);
  if slot=MUSIC_SLOT then
   result:=Mix_PlayingMusic<>0
  else
   result:=Mix_Playing(slot)<>0; // a paused channel counts as playing
 end;

procedure TSoundLibSDL.Init(windowHandle:THandle);
 var
  i,freq,chan:integer;
  format:word;
  ver:PSDL_Version;
 begin
  Log.Info('[SDL_MIX] Init');
  // The audio subsystem may already be up if the SDL platform backend is used
  if SDL_WasInit(SDL_INIT_AUDIO)=0 then begin
   if SDL_InitSubSystem(SDL_INIT_AUDIO)<0 then
    raise EError.Create('[SDL_MIX] cannot initialize SDL audio: '+SDL_GetError);
   ownAudioSubsystem:=true;
  end;
  InitDecoders;
  if Mix_OpenAudio(44100,AUDIO_S16,2,1024)<>0 then
   raise EError.Create('[SDL_MIX] open audio error: '+Mix_GetError);
  Mix_AllocateChannels(SAMPLE_CHANNELS);
  // generations are kept: handles from an earlier Init must stay stale
  for i:=0 to MUSIC_SLOT do slots[i].relVolume:=1.0;
  // Diagnostics: what the device actually gave us
  ver:=Mix_Linked_Version;
  if ver<>nil then
   Log.Info('[SDL_MIX] SDL2_mixer %d.%d.%d (headers: %d.%d.%d)',
     [ver.major,ver.minor,ver.patch,SDL_MIXER_MAJOR_VERSION,SDL_MIXER_MINOR_VERSION,SDL_MIXER_PATCHLEVEL]);
  freq:=0; format:=0; chan:=0;
  if Mix_QuerySpec(@freq,@format,@chan)<>0 then
   Log.Info('[SDL_MIX] Device: driver=%s, %d Hz, format $%x, %d channels, %d mixing channels',
     [string(SDL_GetCurrentAudioDriver),freq,format,chan,SAMPLE_CHANNELS])
  else
   Log.Warn('[SDL_MIX] Device query failed: '+Mix_GetError);
 end;

procedure TSoundLibSDL.Done;
 begin
  Log.Info('[SDL_MIX] stopping');
  Mix_HaltChannel(-1);
  Mix_HaltMusic;
  Mix_CloseAudio;
  Mix_Quit;
  if ownAudioSubsystem then begin
   SDL_QuitSubSystem(SDL_INIT_AUDIO);
   ownAudioSubsystem:=false;
  end;
 end;

function TSoundLibSDL.OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
 var
  st:String8;
  chunk:PMix_Chunk;
  music:PMix_Music;
  media:TMediaFileSDL;
 begin
  result:=nil;
  st:=fname;

  media:=TMediaFileSDL.Create;
  if mode=mlmLoadUnpack then begin
   // Load as sample: any format SDL_mixer decodes. Never fall back to a music
   // stream here - a sample loaded that way would replace the current music
   chunk:=Mix_LoadWAV(PAnsiChar(st));
   if chunk=nil then begin
    Log.Error('[SDL_MIX] Failed to load media file %s: %s',[fName,string(Mix_GetError)]);
    media.Free;
    exit(nil);
   end;
   media.chunk:=chunk;
  end else begin
   // Load as music
   music:=Mix_LoadMUS(PAnsiChar(st));
   if music=nil then begin
    Log.Error('[SDL_MIX] Failed to load music file %s: %s',[fname,string(Mix_GetError)]);
    media.Free;
    exit(nil);
   end;
   media.music:=music;
  end;

  media.source:=fName;
  // Fill in numChannels/sampleRate/bitDepth: the engine needs sampleRate to
  // convert the "freq=" playback parameter into a speed factor
  try
   media.DetectParams(fName);
  except
   on e:Exception do
    Log.Warn('[SDL_MIX] Cannot detect params of %s: %s',[fName,ExceptionMsg(e)]);
  end;
  result:=media;
 end;

function TSoundLibSDL.PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
 var
  m:TMediaFileSDL;
  loops,res:integer;
 begin
  ASSERT(media is TMediaFileSDL);
  m:=TMediaFileSDL(media);
  if settings.loop then loops:=-1 else loops:=0;
  if m.chunk<>nil then begin
   // Play sample
   res:=Mix_PlayChannel(-1,m.chunk,loops);
   if res<0 then begin
    Log.Error('[SDL_MIX] failed to play sample %s: %s',[m.source,string(Mix_GetError)]);
    exit(0);
   end;
   slots[res].relVolume:=settings.volume;
   ApplySlotVolume(res);
   SetPanning(res,settings.pan);
   result:=NewHandle(res);
  end else begin
   // Play music (SDL_mixer has a single music stream).
   // A fade-out started for the previous track keeps its own timer running: it
   // would halt whatever plays when it expires, i.e. this new track. Stop the
   // old stream explicitly instead of letting the fade finish on its own.
   if Mix_FadingMusic<>MIX_NO_FADING then Mix_HaltMusic;
   if Mix_PlayMusic(m.music,loops)<>0 then begin
    Log.Error('[SDL_MIX] failed to play music %s: %s',[m.source,string(Mix_GetError)]);
    exit(0);
   end;
   slots[MUSIC_SLOT].relVolume:=settings.volume;
   ApplySlotVolume(MUSIC_SLOT);
   result:=NewHandle(MUSIC_SLOT);
  end;
 end;

procedure TSoundLibSDL.SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
 var
  slot:integer;
 begin
  slot:=SlotOf(channel);
  if slot<0 then exit;
  case attr of
   caVolume:begin
    slots[slot].relVolume:=value;
    ApplySlotVolume(slot);
   end;
   caPanning:
    if slot<>MUSIC_SLOT then SetPanning(slot,value);
   // caSpeed is not supported by SDL_mixer
  end;
 end;

procedure TSoundLibSDL.SetVolume(volumeType:TVolumeType;volume:single);
 var
  i:integer;
 begin
  case volumeType of
   vtSounds:begin
    globalSoundVolume:=volume;
    // Per-channel volumes are relative to the global one, so reapply them
    for i:=0 to SAMPLE_CHANNELS-1 do
     if Mix_Playing(i)<>0 then ApplySlotVolume(i);
   end;
   vtMusic:begin
    globalMusicVolume:=volume;
    ApplySlotVolume(MUSIC_SLOT);
   end;
  end;
 end;

procedure TSoundLibSDL.SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue,timeInterval:single);
 var
  slot:integer;
 begin
  // SDL_mixer has no generic slide: only a fade-out is available (CanSlide=[])
  slot:=SlotOf(channel);
  if slot<0 then exit;
  if (attr<>caVolume) or (newValue>0) then exit;
  if slot=MUSIC_SLOT then
   Mix_FadeOutMusic(round(timeInterval*1000))
  else
   Mix_FadeOutChannel(slot,round(timeInterval*1000));
 end;

procedure TSoundLibSDL.Pause(pause:boolean);
 begin
  if pause then begin
   Mix_Pause(-1);
   Mix_PauseMusic;
  end else begin
   Mix_Resume(-1);
   Mix_ResumeMusic;
  end;
 end;

procedure TSoundLibSDL.StopChannel(var channel:TChannel);
 var
  slot:integer;
 begin
  slot:=SlotOf(channel);
  channel:=0;
  if slot<0 then exit; // this playback has already ended
  if slot=MUSIC_SLOT then begin
   Log.Info('[SDL_MIX] halt music');
   Mix_HaltMusic;
  end else
   Mix_HaltChannel(slot);
 end;

end.
