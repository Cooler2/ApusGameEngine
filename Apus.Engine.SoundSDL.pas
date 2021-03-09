// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

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
  procedure Done;

  function CanSlide:TChannelAttributes;
  function CanFadeMusic:boolean;
 end;

implementation
uses Apus.MyServis, SysUtils, SDL2, sdl2_mixer;

type
 TMediaFileSDL=class(TMediaFile)
  chunk,music:pointer;
 end;

 TChannelSDL=class(TChannel)
  sampleChannel:integer; // negative - music
 end;

var
 globalMusicVolume,curMusicVolume,globalSoundVolume:single;

{ TSoundLibSDL }

function TSoundLibSDL.CanSlide: TChannelAttributes;
 begin
  result:=[];
 end;

function TSoundLibSDL.CanFadeMusic:boolean;
 begin
  result:=true;
 end;

procedure TSoundLibSDL.Init(windowHandle: THandle);
 var
  res,flags:integer;
 begin
  LogMessage('[SDL_MIX] Init');
  flags:=MIX_INIT_OGG;
  res:=Mix_Init(flags);
  if res<>flags then raise EError.Create('[SDL_MIX] init failed: '+Mix_GetError);
  res:=Mix_OpenAudio(44100,AUDIO_S16,2,1764);
  if res<>0 then raise EError.Create('[SDL_MIX] open audio error '+Mix_GetError);
  globalMusicVolume:=1.0;
  globalSoundVolume:=1.0;
 end;

procedure TSoundLibSDL.Done;
 begin
  LogMessage('[SDL_MIX] stopping');
  Mix_CloseAudio;
  Mix_Quit;
 end;


function TSoundLibSDL.OpenMediaFile(fname: string;
  mode: TMediaLoadingMode): TMediaFile;
 var
  st:String8;
  chunk,music:pointer;
  media:TMediaFileSDL;
  ext:string;
 begin
  result:=nil;
  st:=fname;
  ext:=Lowercase(ExtractFileExt(fName));

  if (mode=mlmLoadUnpack) and ((ext='.wav') or (ext='.ogg')) then begin
   // Load as sample
   chunk:=Mix_LoadWAV(PAnsiChar(st));
   if chunk=nil then begin
    LogMessage('[SDL_MIX] Failed to load media file %s: %s ',[fName,Mix_GetError]);
    exit(nil);
   end;
   media:=TMediaFileSDL.Create;
   media.chunk:=chunk;
  end else begin
   // Load as music
   music:=Mix_LoadMUS(PAnsiChar(st));
   if music=nil then begin
    LogMessage('[SDL_MIX] Failed to load music file %s: %s ',[fname,Mix_GetError]);
    exit(nil);
   end;
   media:=TMediaFileSDL.Create;
   media.music:=music;
  end;

  media.source:=fName;
  result:=media;
 end;

procedure UpdateCurMusicVolume;
 begin
  Mix_VolumeMusic(round(curMusicVolume*globalMusicVolume*MIX_MAX_VOLUME));
 end;

function TSoundLibSDL.PlayMedia(media: TMediaFile;
  const settings: TPlaySettings): TChannel;
 var
  m:TMediaFileSDL;
  loops:integer;
  res:integer;
  ch:TChannelSDL;
 begin
  ASSERT(media is TMediaFileSDL);
  m:=TMediaFileSDL(media);
  if settings.loop then loops:=-1 else loops:=0;
  if m.chunk<>nil then begin
   // Play sample
   res:=Mix_PlayChannel(-1,m.chunk,loops);
   if res=-1 then begin
    ForceLogMessage('[SDL_MIX] failed to play sample: '+m.source);
    exit(nil);
   end;
   Mix_Volume(res,round(settings.volume*globalSoundVolume*MIX_MAX_VOLUME));
  end else begin
   // Play music
   res:=Mix_PlayMusic(m.music,loops);
   if res<>0 then begin
    ForceLogMessage('[SDL_MIX] failed to play music: '+m.source);
    exit(nil);
   end;
   curMusicVolume:=settings.volume;
   UpdateCurMusicVolume;
   res:=-999;
  end;
  ch:=TChannelSDL.Create;
  ch.sampleChannel:=res;
  result:=ch;
 end;

procedure TSoundLibSDL.SetChannelAttribute(channel: TChannel;
  attr: TChannelAttribute; value: single);
 begin

 end;

procedure TSoundLibSDL.SetVolume(volumeType: TVolumeType; volume: single);
 begin
  case volumeType of
   vtSounds:globalSoundVolume:=volume;
   vtMusic:begin
    globalMusicVolume:=volume;
    UpdateCurMusicVolume;
   end;
  end;
 end;

procedure TSoundLibSDL.SlideChannel(channel: TChannel; attr: TChannelAttribute;
  newValue, timeInterval: single);
 begin
  if (channel is TChannelSDL) and (attr=caVolume) then begin
   if newValue=0 then Mix_FadeOutMusic(round(timeInterval*1000));
  end;
 end;

procedure TSoundLibSDL.StopChannel(var channel: TChannel);
 var
  ch:TChannelSDL;
 begin
  ASSERT(channel is TChannelSDL);
  ch:=TChannelSDL(channel);
  if ch.sampleChannel>=0 then
   Mix_HaltChannel(ch.sampleChannel)
  else
   Mix_HaltMusic;
 end;

end.
