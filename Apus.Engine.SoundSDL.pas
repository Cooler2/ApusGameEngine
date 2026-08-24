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
 // Sample channel index marking the (single) music stream
 MUSIC_CHANNEL = -1;

type
 TMediaFileSDL=class(TMediaFile)
  chunk:PMix_Chunk;   // loaded sample
  music:PMix_Music;   // music stream
  destructor Destroy; override;
 end;

 // Channel objects are owned by the backend and reused: one per SDL_mixer
 // channel plus one for the music stream. StopChannel only clears the caller's
 // reference, it never frees the object.
 TChannelSDL=class(TChannel)
  sampleChannel:integer; // MUSIC_CHANNEL for the music stream
  relVolume:single;      // volume requested for this channel (before the global one)
  constructor Create(channelIndex:integer);
 end;

var
 globalMusicVolume:single=1.0;
 globalSoundVolume:single=1.0;
 channels:array[0..SAMPLE_CHANNELS-1] of TChannelSDL;
 musicChannel:TChannelSDL;
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

{ TChannelSDL }

constructor TChannelSDL.Create(channelIndex:integer);
 begin
  sampleChannel:=channelIndex;
  relVolume:=1.0;
 end;

{ Helpers }

// Panning: -1 = full left, 0 = center, 1 = full right
procedure SetPanning(channel:integer;pan:single);
 var
  left,right:integer;
 begin
  right:=Clamp(round(255*(1+pan)),0,255);
  left:=Clamp(round(255*(1-pan)),0,255);
  Mix_SetPanning(channel,left,right);
 end;

procedure ApplyChannelVolume(ch:TChannelSDL);
 begin
  if ch.sampleChannel=MUSIC_CHANNEL then
   Mix_VolumeMusic(round(ch.relVolume*globalMusicVolume*MIX_MAX_VOLUME))
  else
   Mix_Volume(ch.sampleChannel,round(ch.relVolume*globalSoundVolume*MIX_MAX_VOLUME));
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
  ch:integer;
 begin
  result:=false;
  if channel=nil then exit;
  ASSERT(channel is TChannelSDL);
  ch:=TChannelSDL(channel).sampleChannel;
  if ch=MUSIC_CHANNEL then
   result:=Mix_PlayingMusic<>0
  else
   result:=Mix_Playing(ch)<>0;
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
  for i:=0 to SAMPLE_CHANNELS-1 do
   if channels[i]=nil then channels[i]:=TChannelSDL.Create(i);
  if musicChannel=nil then musicChannel:=TChannelSDL.Create(MUSIC_CHANNEL);
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
 var
  i:integer;
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
  for i:=0 to SAMPLE_CHANNELS-1 do FreeAndNil(channels[i]);
  FreeAndNil(musicChannel);
 end;

function TSoundLibSDL.OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
 var
  st:String8;
  chunk:PMix_Chunk;
  music:PMix_Music;
  media:TMediaFileSDL;
  ext:string;
 begin
  result:=nil;
  st:=fname;
  ext:=LowerCase(ExtractFileExt(fName));

  media:=TMediaFileSDL.Create;
  if (mode=mlmLoadUnpack) and ((ext='.wav') or (ext='.ogg')) then begin
   // Load as sample
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
    exit(nil);
   end;
   channels[res].relVolume:=settings.volume;
   ApplyChannelVolume(channels[res]);
   SetPanning(res,settings.pan);
   result:=channels[res];
  end else begin
   // Play music (SDL_mixer has a single music stream).
   // A fade-out started for the previous track keeps its own timer running: it
   // would halt whatever plays when it expires, i.e. this new track. Stop the
   // old stream explicitly instead of letting the fade finish on its own.
   if Mix_FadingMusic<>MIX_NO_FADING then Mix_HaltMusic;
   if Mix_PlayMusic(m.music,loops)<>0 then begin
    Log.Error('[SDL_MIX] failed to play music %s: %s',[m.source,string(Mix_GetError)]);
    exit(nil);
   end;
   musicChannel.relVolume:=settings.volume;
   ApplyChannelVolume(musicChannel);
   result:=musicChannel;
  end;
 end;

procedure TSoundLibSDL.SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
 var
  ch:TChannelSDL;
 begin
  if channel=nil then exit;
  ASSERT(channel is TChannelSDL);
  ch:=TChannelSDL(channel);
  case attr of
   caVolume:begin
    ch.relVolume:=value;
    ApplyChannelVolume(ch);
   end;
   caPanning:
    if ch.sampleChannel<>MUSIC_CHANNEL then SetPanning(ch.sampleChannel,value);
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
     if (channels[i]<>nil) and (Mix_Playing(i)<>0) then ApplyChannelVolume(channels[i]);
   end;
   vtMusic:begin
    globalMusicVolume:=volume;
    if musicChannel<>nil then ApplyChannelVolume(musicChannel);
   end;
  end;
 end;

procedure TSoundLibSDL.SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue,timeInterval:single);
 var
  ch:integer;
 begin
  // SDL_mixer has no generic slide: only a fade-out is available (CanSlide=[])
  if channel=nil then exit;
  ASSERT(channel is TChannelSDL);
  if (attr<>caVolume) or (newValue>0) then exit;
  ch:=TChannelSDL(channel).sampleChannel;
  if ch=MUSIC_CHANNEL then
   Mix_FadeOutMusic(round(timeInterval*1000))
  else
   Mix_FadeOutChannel(ch,round(timeInterval*1000));
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
  ch:integer;
 begin
  if channel=nil then exit;
  ASSERT(channel is TChannelSDL);
  ch:=TChannelSDL(channel).sampleChannel;
  if ch=MUSIC_CHANNEL then begin
   Log.Info('[SDL_MIX] halt music');
   Mix_HaltMusic;
  end else
   Mix_HaltChannel(ch);
  channel:=nil; // the object itself is owned by the backend
 end;

end.
