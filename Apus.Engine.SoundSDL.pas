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

  function CanSlide:boolean;
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

{ TSoundLibSDL }

function TSoundLibSDL.CanSlide: boolean;
 begin
  result:=false;
 end;

procedure TSoundLibSDL.Init(windowHandle: THandle);
 var
  res:integer;
 begin
  LogMessage('[SDL_MIX] Init');
  res:=Mix_Init(MIX_INIT_MOD+MIX_INIT_MP3+MIX_INIT_OGG);
  if res=0 then raise EError.Create('[SDL_MIX] init failed');
  res:=Mix_OpenAudio(44100,AUDIO_S16,2,1764);
  if res<>0 then raise EError.Create('[SDL_MIX] open audio error '+Mix_GetError);
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
    LogMessage('[SDL_MIX] Failed to load media file: '+fName);
    exit(nil);
   end;
   media:=TMediaFileSDL.Create;
   media.chunk:=chunk;
  end else begin
   // Load as music
   music:=Mix_LoadMUS(PAnsiChar(st));
   if music=nil then begin
    LogMessage('[SDL_MIX] Failed to load music file: '+fname);
    exit(nil);
   end;
   media:=TMediaFileSDL.Create;
   media.music:=music;
  end;

  media.source:=fName;
  result:=media;
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
  end else begin
   // Play music
   res:=Mix_PlayMusic(m.music,loops);
   if res<>0 then begin
    ForceLogMessage('[SDL_MIX] failed to play music: '+m.source);
    exit(nil);
   end;
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
   vtSounds:;
   vtMusic:Mix_VolumeMusic(round(volume*MIX_MAX_VOLUME));
  end;
 end;

procedure TSoundLibSDL.SlideChannel(channel: TChannel; attr: TChannelAttribute;
  newValue, timeInterval: single);
 begin

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
