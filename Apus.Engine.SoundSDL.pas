// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

// SDL2_mixer sound backend: covers level 1 of the audio requirements
// (play samples and stream music as-is + volume control). Its ceiling is known:
// panning for samples only and a single music stream (so music crossfade is
// impossible here) - these belong to the miniaudio backend.
// See Work/R-28_audio_activation.md.
// Own mixing: samples, procedural streams and music with loop points play on
// SDL_mixer channels that play a silent looped carrier, and a channel effect
// replaces the carrier data with a source (TSource): decoded PCM read at any
// speed, or a stream procedure. This gives pitch, loop points (a track with a loop
// region is decoded whole) and streams, none of which SDL_mixer has; volume,
// panning, pause and fades of the channel still apply after the effect.
// Only music without loop points goes through Mix_Music.
unit Apus.Engine.SoundSDL;
interface
uses Apus.Engine.Sound;

type
 TSoundLibSDL=class(TInterfacedObject,ISoundLib)
  procedure Init(windowHandle:THandle=0);
  procedure SetVolume(volumeType:TVolumeType;volume:single); // 0..1
  function OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
  function PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
  function PlayStream(proc:TSoundStreamProc;userData:pointer;channels:integer;volume:single):TChannel;
  procedure StopChannel(var channel:TChannel);
  procedure SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
  procedure SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue:single;timeInterval:single);
  procedure Pause(pause:boolean);
  procedure Update;
  procedure Done;

  function CanSlide:TChannelAttributes;
  function CanFadeMusic:boolean;
  function HasSingleMusicStream:boolean;
  function IsPlaying(channel:TChannel):boolean;
 end;

implementation
uses SysUtils, SDL2, sdl2_mixer,
  Apus.Core,
  Apus.Files,
  Apus.Log,
  Apus.Types;

const
 // SDL_mixer channels 0..MUSIC_CHANNELS-1 are reserved for music with loop points
 MUSIC_CHANNELS = 1;
 // Number of simultaneously playing samples and streams
 SAMPLE_CHANNELS = 32;
 MIXING_CHANNELS = MUSIC_CHANNELS+SAMPLE_CHANNELS;
 // Slot of the music stream: slots 0..MIXING_CHANNELS-1 are SDL_mixer channels
 MUSIC_SLOT = MIXING_CHANNELS;
 // Silent data a channel plays under its source, bytes
 CARRIER_SIZE = 4096;
 // Values per channel a stream procedure generates at most in one call
 STREAM_PIECE = 1024;
 // An early stop fades out over this time (sec): a cut in the middle of a wave clicks
 STOP_FADE_TIME = 0.01;
 // Speed range of decoded PCM
 MIN_SPEED = 0.05;
 MAX_SPEED = 20;
 // Channel handle layout: low 8 bits = slot+1 (so 0 is "no channel"),
 // high 24 bits = generation of the slot at the moment the playback started
 SLOT_BITS = 8;
 SLOT_MASK = $FF;
 GENERATION_MASK = $FFFFFF;

type
 TMediaFileSDL=class(TMediaFile)
  chunk:PMix_Chunk;   // loaded sample
  music:PMix_Music;   // music stream
  data:ByteArray;     // file content the music stream decodes from while playing
  pcm:PMix_Chunk;     // whole track decoded for playback with loop points (on demand)
  destructor Destroy; override;
 end;

 // Mixing slot: an SDL_mixer channel or the music stream
 TSlotSDL=record
  generation:cardinal; // bumped on every playback start, so older handles of the slot become stale
  relVolume:single;    // volume requested for the current playback (before the global one)
 end;

 TSamples=array[0..$7FFFFFF] of smallint;
 PSamples=^TSamples;

 TSourceKind=(skNone,skPCM,skStream);

 // What a mixing channel plays. Positions are counted in frames: a frame is one
 // value for every device channel. The effect runs in the audio thread: the fields
 // are set while the channel is halted (halting waits for the mixer), before the
 // effect is registered. Later the sound thread writes only targetSpeed,
 // speedRate and fadeLength, and the audio thread only finished (aligned 32-bit
 // fields: plain reads and writes are atomic)
 TSource=record
  kind:TSourceKind;
  media:TMediaFileSDL;  // PCM: the media the data belongs to
  data:PSamples;        // PCM: decoded in the device format
  loop:boolean;         // PCM: continue from loopStart at endPos
  loopStart,endPos:integer; // PCM: the playback ends (or loops) at endPos
  pos:double;           // PCM: current position (fractional when the speed is not 1)
  speed:double;         // PCM: current speed (audio thread)
  targetSpeed:single;   // PCM: speed requested by the sound thread
  speedRate:single;     // PCM: speed change per frame on the way to targetSpeed, 0 = at once
  proc:TSoundStreamProc; // stream
  userData:pointer;
  streamChannels:integer;
  buf:array of single;  // stream: one piece from proc
  fadeLength:integer;   // frames of the fade-out to the stop (0 = no stop requested)
  fadePos:integer;      // audio thread: frames of the fade-out played
  finished:integer;     // the source has ended: Update halts the channel
 end;
 PSource=^TSource;

var
 globalMusicVolume:single=1.0;
 globalSoundVolume:single=1.0;
 slots:array[0..MUSIC_SLOT] of TSlotSDL;
 sources:array[0..MIXING_CHANNELS-1] of TSource;
 carrierData:ByteArray;
 carrier:PMix_Chunk;
 deviceFreq:integer=44100;
 deviceChannels:integer=2;
 frameSize:integer=4; // bytes per frame
 ownAudioSubsystem:boolean; // did this backend initialize SDL's audio subsystem?

{ TMediaFileSDL }

destructor TMediaFileSDL.Destroy;
 var
  i:integer;
 begin
  // the mixer must not read the decoded data after it's freed
  for i:=0 to high(sources) do
   if sources[i].media=self then begin
    Mix_HaltChannel(i);
    sources[i].media:=nil;
    sources[i].kind:=skNone;
   end;
  if chunk<>nil then Mix_FreeChunk(chunk);
  if music<>nil then Mix_FreeMusic(music);
  if pcm<>nil then Mix_FreeChunk(pcm);
  chunk:=nil;
  music:=nil;
  pcm:=nil;
  inherited;
 end;

{ Helpers }

function IsMusicSlot(slot:integer):boolean; inline;
 begin
  result:=(slot<MUSIC_CHANNELS) or (slot=MUSIC_SLOT);
 end;

function ClampSpeed(speed:single):single;
 begin
  result:=speed;
  if result<MIN_SPEED then result:=MIN_SPEED;
  if result>MAX_SPEED then result:=MAX_SPEED;
 end;

// Audio thread: fill frames from decoded PCM, with linear interpolation when the speed is not 1
procedure FillPCM(var src:TSource;dst:PSmallInt;frames:integer);
 var
  target,rate:single;
  n,c,p0,p1:integer;
  f:double;
  a,b:PSamples;
 begin
  target:=src.targetSpeed;
  rate:=src.speedRate;
  while frames>0 do begin
   if src.pos>=src.endPos then begin
    if not src.loop then begin
     src.finished:=1;
     FillChar(dst^,frames*frameSize,0);
     exit;
    end;
    src.pos:=src.pos-(src.endPos-src.loopStart);
    continue;
   end;
   if (src.speed=1) and (target=1) and (frac(src.pos)=0) then begin
    // straight copy: the data plays bit-exact
    p0:=trunc(src.pos);
    n:=src.endPos-p0;
    if n>frames then n:=frames;
    move(src.data^[p0*deviceChannels],dst^,n*frameSize);
    inc(dst,n*deviceChannels);
    dec(frames,n);
    src.pos:=src.pos+n;
   end else begin
    if src.speed<>target then
     if rate<=0 then src.speed:=target
     else
     if src.speed<target then begin
      src.speed:=src.speed+rate;
      if src.speed>target then src.speed:=target;
     end else begin
      src.speed:=src.speed-rate;
      if src.speed<target then src.speed:=target;
     end;
    p0:=trunc(src.pos);
    f:=src.pos-p0;
    p1:=p0+1;
    if p1>=src.endPos then
     if src.loop then p1:=src.loopStart else p1:=p0;
    a:=PSamples(@src.data^[p0*deviceChannels]);
    b:=PSamples(@src.data^[p1*deviceChannels]);
    for c:=0 to deviceChannels-1 do begin
     dst^:=round(a^[c]+(b^[c]-a^[c])*f);
     inc(dst);
    end;
    dec(frames);
    src.pos:=src.pos+src.speed;
   end;
  end;
 end;

// Audio thread: fill frames from the stream procedure
procedure FillStream(var src:TSource;dst:PSmallInt;frames:integer);
 var
  n,i,c,sc:integer;
  v:single;
 begin
  sc:=src.streamChannels;
  while frames>0 do begin
   if src.finished<>0 then begin
    FillChar(dst^,frames*frameSize,0);
    exit;
   end;
   n:=frames;
   if n>STREAM_PIECE then n:=STREAM_PIECE;
   if not src.proc(@src.buf[0],n,sc,deviceFreq,src.userData) then
    src.finished:=1; // this piece still plays
   // a mono stream goes to every device channel, extra stream channels are dropped
   for i:=0 to n-1 do
    for c:=0 to deviceChannels-1 do begin
     if sc=1 then v:=src.buf[i]
     else
     if c<sc then v:=src.buf[i*sc+c]
     else v:=0;
     if v>1 then v:=1
     else
     if v<-1 then v:=-1;
     dst^:=round(v*32767);
     inc(dst);
    end;
   dec(frames,n);
  end;
 end;

// Audio thread: fade the filled frames out on the way to the stop, silence after it
procedure ApplyFade(var src:TSource;dst:PSmallInt;frames,length:integer);
 var
  i,c:integer;
  gain:single;
 begin
  for i:=0 to frames-1 do begin
   if src.fadePos>=length then begin
    src.finished:=1;
    FillChar(dst^,(frames-i)*frameSize,0);
    exit;
   end;
   gain:=1-src.fadePos/length;
   for c:=0 to deviceChannels-1 do begin
    dst^:=round(dst^*gain);
    inc(dst);
   end;
   inc(src.fadePos);
  end;
 end;

// Mixer effect of a channel (audio thread): replace the carrier data with the source
procedure SourceEffect(chan:integer;stream:pointer;len:integer;udata:pointer); cdecl;
 var
  src:PSource;
  frames,fade:integer;
 begin
  src:=udata;
  frames:=len div frameSize;
  if src.finished<>0 then begin
   FillChar(stream^,len,0);
   exit;
  end;
  case src.kind of
   skPCM:FillPCM(src^,stream,frames);
   skStream:FillStream(src^,stream,frames);
  end;
  fade:=src.fadeLength;
  if fade>0 then ApplyFade(src^,stream,frames,fade);
 end;

// Fade a mixing channel out over time seconds, then it stops (Update halts it).
// SDL_mixer's own fade changes the volume once per mixed buffer, in audible steps
procedure FadeToStop(slot:integer;time:single);
 var
  frames:integer;
 begin
  if sources[slot].kind=skNone then begin
   Mix_HaltChannel(slot);
   exit;
  end;
  if sources[slot].fadeLength>0 then exit; // already on its way to the stop
  frames:=round(time*deviceFreq);
  if frames<1 then frames:=1;
  sources[slot].fadeLength:=frames;
 end;

// Frame in the decoded track (it's decoded at the device rate) for a time in seconds
function TrackPos(time:double):int64;
 begin
  result:=round(time*deviceFreq);
 end;

// Halt the loop channels: the backend plays one music stream at a time
procedure HaltLoopChannels;
 var
  i:integer;
 begin
  for i:=0 to MUSIC_CHANNELS-1 do
   if Mix_Playing(i)<>0 then Mix_HaltChannel(i);
 end;

// A sample channel for a new playback: a free one, or one whose source has ended
function FindSampleChannel:integer;
 var
  i:integer;
 begin
  for i:=MUSIC_CHANNELS to MIXING_CHANNELS-1 do
   if Mix_Playing(i)=0 then exit(i);
  for i:=MUSIC_CHANNELS to MIXING_CHANNELS-1 do
   if sources[i].finished<>0 then exit(i);
  result:=-1;
 end;

// Reset the source of a channel for a new playback. The channel is halted first,
// so the mixer doesn't read the source meanwhile (halting also drops the effects)
function PrepareSource(slot:integer):PSource;
 begin
  if Mix_Playing(slot)<>0 then Mix_HaltChannel(slot);
  result:=@sources[slot];
  result^:=Default(TSource);
 end;

// Prepare decoded PCM (in the device format) to play on a channel
procedure SetPCMSource(slot:integer;m:TMediaFileSDL;chunk:PMix_Chunk;loop:boolean;
  loopStart,endPos:integer;pos:double;speed:single);
 var
  src:PSource;
 begin
  src:=PrepareSource(slot);
  src.kind:=skPCM;
  src.media:=m;
  src.data:=PSamples(chunk.abuf);
  src.loop:=loop and (endPos>loopStart); // an empty region can't loop
  src.loopStart:=loopStart;
  src.endPos:=endPos;
  src.pos:=pos;
  speed:=ClampSpeed(speed);
  src.speed:=speed;
  src.targetSpeed:=speed;
 end;

procedure ApplySlotVolume(slot:integer);
 begin
  if slot=MUSIC_SLOT then
   Mix_VolumeMusic(round(slots[slot].relVolume*globalMusicVolume*MIX_MAX_VOLUME))
  else
  if IsMusicSlot(slot) then
   Mix_Volume(slot,round(slots[slot].relVolume*globalMusicVolume*MIX_MAX_VOLUME))
  else
   Mix_Volume(slot,round(slots[slot].relVolume*globalSoundVolume*MIX_MAX_VOLUME));
 end;

// Play the prepared source of a channel: SDL_mixer plays the carrier, the effect replaces its data
function StartSource(slot:integer;volume:single;const what:string):boolean;
 begin
  result:=false;
  if Mix_RegisterEffect(slot,SourceEffect,nil,@sources[slot])=0 then begin
   Log.Error('[SDL_MIX] failed to set up the playback of %s: %s',[what,string(Mix_GetError)]);
   exit;
  end;
  slots[slot].relVolume:=volume;
  ApplySlotVolume(slot);
  if Mix_PlayChannel(slot,carrier,-1)<0 then begin
   Log.Error('[SDL_MIX] failed to play %s: %s',[what,string(Mix_GetError)]);
   Mix_UnregisterAllEffects(slot);
   exit;
  end;
  result:=true;
 end;

// Decode the whole track once: loop points need random access to it
function DecodeTrack(m:TMediaFileSDL):boolean;
 var
  t:int64;
 begin
  if m.pcm=nil then begin
   t:=CoreTime.Ticks;
   m.pcm:=Mix_LoadWAV_RW(SDL_RWFromConstMem(@m.data[0],length(m.data)),1);
   if m.pcm=nil then begin
    Log.Error('[SDL_MIX] Failed to decode %s for loop points: %s',[m.source,string(Mix_GetError)]);
    exit(false);
   end;
   Log.Info('[SDL_MIX] %s decoded for loop points: %d KB in %d ms',
     [m.source,m.pcm.alen div 1024,CoreTime.Ticks-t]);
  end;
  result:=true;
 end;

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

// Music with a loop region: plays the decoded track on a loop channel
function PlayLooped(m:TMediaFileSDL;const settings:TPlaySettings):TChannel;
 const
  slot=0;
 var
  total,loopStart,loopEnd,startPos:int64;
 begin
  result:=0;
  if not DecodeTrack(m) then exit;
  total:=int64(m.pcm.alen) div frameSize;
  loopStart:=TrackPos(settings.loopStart);
  loopEnd:=total;
  if settings.loopEnd>0 then loopEnd:=TrackPos(settings.loopEnd);
  if loopEnd>total then loopEnd:=total;
  if loopEnd<=0 then exit;
  if loopStart>=loopEnd then begin
   Log.Warn('[SDL_MIX] %s: loop start %.3f s is not before the loop end, the whole track loops',
     [m.source,settings.loopStart]);
   loopStart:=0;
  end;
  startPos:=TrackPos(settings.startPos);
  if (startPos<0) or (startPos>=loopEnd) then startPos:=loopStart;
  // one music stream: this track replaces whatever music plays
  Mix_HaltMusic;
  HaltLoopChannels;
  SetPCMSource(slot,m,m.pcm,true,loopStart,loopEnd,startPos,1);
  if not StartSource(slot,settings.volume,'music '+m.source) then exit;
  result:=NewHandle(slot);
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
  result:=[caSpeed]; // the speed of decoded PCM changes in the effect; volume can only fade out
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
  else // a paused channel counts as playing; an ended source waits for Update to halt it
   result:=(Mix_Playing(slot)<>0) and (sources[slot].finished=0);
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
  // the sources mix 16-bit samples of the host byte order (little endian on every target)
  if Mix_OpenAudio(44100,AUDIO_S16,2,1024)<>0 then
   raise EError.Create('[SDL_MIX] open audio error: '+Mix_GetError);
  Mix_AllocateChannels(MIXING_CHANNELS);
  Mix_ReserveChannels(MUSIC_CHANNELS); // samples never take the loop channels
  // generations are kept: handles from an earlier Init must stay stale
  for i:=0 to MUSIC_SLOT do slots[i].relVolume:=1.0;
  // Diagnostics: what the device actually gave us
  ver:=Mix_Linked_Version;
  if ver<>nil then
   Log.Info('[SDL_MIX] SDL2_mixer %d.%d.%d (headers: %d.%d.%d)',
     [ver.major,ver.minor,ver.patch,SDL_MIXER_MAJOR_VERSION,SDL_MIXER_MINOR_VERSION,SDL_MIXER_PATCHLEVEL]);
  freq:=0; format:=0; chan:=0;
  if Mix_QuerySpec(@freq,@format,@chan)<>0 then begin
   Log.Info('[SDL_MIX] Device: driver=%s, %d Hz, format $%x, %d channels, %d mixing channels',
     [string(SDL_GetCurrentAudioDriver),freq,format,chan,MIXING_CHANNELS]);
   // Mix_OpenAudio lets the device change the rate and the channels, but not the format
   if format<>AUDIO_S16 then
    raise EError.Create('[SDL_MIX] unexpected device format $'+IntToHex(format,4));
   deviceFreq:=freq;
   deviceChannels:=chan;
   frameSize:=chan*2;
  end else
   Log.Warn('[SDL_MIX] Device query failed: '+Mix_GetError);
  SetLength(carrierData,CARRIER_SIZE div frameSize*frameSize);
  FillChar(carrierData[0],length(carrierData),0);
  carrier:=Mix_QuickLoad_RAW(@carrierData[0],length(carrierData));
 end;

procedure TSoundLibSDL.Done;
 begin
  Log.Info('[SDL_MIX] stopping');
  Mix_HaltChannel(-1);
  Mix_HaltMusic;
  if carrier<>nil then Mix_FreeChunk(carrier); // the data is ours: only the chunk is freed
  carrier:=nil;
  Mix_CloseAudio;
  Mix_Quit;
  if ownAudioSubsystem then begin
   SDL_QuitSubSystem(SDL_INIT_AUDIO);
   ownAudioSubsystem:=false;
  end;
 end;

function TSoundLibSDL.OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
 var
  data:ByteArray;
  rw:PSDL_RWops;
  chunk:PMix_Chunk;
  music:PMix_Music;
  media:TMediaFileSDL;
 begin
  result:=nil;
  // The file is read through the engine's file system, so it can come from any provider
  try
   data:=Files.LoadAsBytes(String8(fname));
  except
   on e:Exception do begin
    Log.Error('[SDL_MIX] Failed to read media file %s: %s',[fname,ExceptionMsg(e)]);
    exit;
   end;
  end;
  if length(data)=0 then begin
   Log.Error('[SDL_MIX] Media file %s is empty',[fname]);
   exit;
  end;
  rw:=SDL_RWFromConstMem(@data[0],length(data));

  media:=TMediaFileSDL.Create;
  if mode=mlmLoadUnpack then begin
   // Load as sample: any format SDL_mixer decodes. Never fall back to a music
   // stream here - a sample loaded that way would replace the current music
   chunk:=Mix_LoadWAV_RW(rw,1);
   if chunk=nil then begin
    Log.Error('[SDL_MIX] Failed to load media file %s: %s',[fName,string(Mix_GetError)]);
    media.Free;
    exit(nil);
   end;
   media.chunk:=chunk;
  end else begin
   // Load as music: it's decoded while playing, so the buffer must live as long as the media
   music:=Mix_LoadMUS_RW(rw,1);
   if music=nil then begin
    Log.Error('[SDL_MIX] Failed to load music file %s: %s',[fname,string(Mix_GetError)]);
    media.Free;
    exit(nil);
   end;
   media.music:=music;
   media.data:=data;
  end;

  media.source:=fName;
  // Fill in numChannels/sampleRate/bitDepth: the engine needs sampleRate to
  // convert the "freq=" playback parameter into a speed factor
  try
   media.DetectParams(TBuffer.CreateFrom(data));
  except
   on e:Exception do
    Log.Warn('[SDL_MIX] Cannot detect params of %s: %s',[fName,ExceptionMsg(e)]);
  end;
  result:=media;
 end;

function TSoundLibSDL.PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
 var
  m:TMediaFileSDL;
  loops,slot:integer;
 begin
  ASSERT(media is TMediaFileSDL);
  m:=TMediaFileSDL(media);
  if m.chunk<>nil then begin
   // Play sample: the chunk is already in the device format
   slot:=FindSampleChannel;
   if slot<0 then begin
    Log.Error('[SDL_MIX] failed to play sample %s: no free channel',[m.source]);
    exit(0);
   end;
   SetPCMSource(slot,m,m.chunk,settings.loop,0,int64(m.chunk.alen) div frameSize,0,settings.speed);
   if not StartSource(slot,settings.volume,'sample '+m.source) then exit(0);
   SetPanning(slot,settings.pan);
   result:=NewHandle(slot);
  end else
  if settings.loop and ((settings.loopStart>0) or (settings.loopEnd>0)) then
   result:=PlayLooped(m,settings)
  else begin
   // Play music (SDL_mixer has a single music stream).
   // A fade-out started for the previous track keeps its own timer running: it
   // would halt whatever plays when it expires, i.e. this new track. Stop the
   // old stream explicitly instead of letting the fade finish on its own.
   if Mix_FadingMusic<>MIX_NO_FADING then Mix_HaltMusic;
   HaltLoopChannels;
   if settings.loop then loops:=-1 else loops:=0;
   if Mix_PlayMusic(m.music,loops)<>0 then begin
    Log.Error('[SDL_MIX] failed to play music %s: %s',[m.source,string(Mix_GetError)]);
    exit(0);
   end;
   if settings.startPos>0 then
    // a module takes the position as a pattern number, not as seconds
    if Mix_GetMusicType(m.music)=MUS_MOD then
     Log.Warn('[SDL_MIX] %s: a module can''t start from a position in seconds',[m.source])
    else
    if Mix_SetMusicPosition(settings.startPos)<>0 then
     Log.Warn('[SDL_MIX] %s: cannot start from %.3f s: %s',[m.source,settings.startPos,string(Mix_GetError)]);
   slots[MUSIC_SLOT].relVolume:=settings.volume;
   ApplySlotVolume(MUSIC_SLOT);
   result:=NewHandle(MUSIC_SLOT);
  end;
 end;

function TSoundLibSDL.PlayStream(proc:TSoundStreamProc;userData:pointer;channels:integer;volume:single):TChannel;
 var
  slot:integer;
  src:PSource;
 begin
  result:=0;
  if not Assigned(proc) or (channels<1) then exit;
  slot:=FindSampleChannel;
  if slot<0 then begin
   Log.Error('[SDL_MIX] failed to play a stream: no free channel');
   exit;
  end;
  src:=PrepareSource(slot);
  src.kind:=skStream;
  src.proc:=proc;
  src.userData:=userData;
  src.streamChannels:=channels;
  SetLength(src.buf,STREAM_PIECE*channels);
  if not StartSource(slot,volume,'a stream') then exit;
  result:=NewHandle(slot);
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
   caSpeed: // samples only: music keeps its pitch
    if not IsMusicSlot(slot) and (sources[slot].kind=skPCM) then begin
     sources[slot].speedRate:=0;
     sources[slot].targetSpeed:=ClampSpeed(value);
    end;
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
    for i:=MUSIC_CHANNELS to MIXING_CHANNELS-1 do
     if Mix_Playing(i)<>0 then ApplySlotVolume(i);
   end;
   vtMusic:begin
    globalMusicVolume:=volume;
    ApplySlotVolume(MUSIC_SLOT);
    for i:=0 to MUSIC_CHANNELS-1 do ApplySlotVolume(i);
   end;
  end;
 end;

procedure TSoundLibSDL.SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue,timeInterval:single);
 var
  slot:integer;
  src:PSource;
 begin
  slot:=SlotOf(channel);
  if slot<0 then exit;
  if attr=caSpeed then begin
   if IsMusicSlot(slot) or (sources[slot].kind<>skPCM) then exit;
   src:=@sources[slot];
   newValue:=ClampSpeed(newValue);
   // the rate goes first: the effect may read the new target at any moment
   if timeInterval>0 then
    src.speedRate:=abs(newValue-src.targetSpeed)/(timeInterval*deviceFreq)
   else
    src.speedRate:=0;
   src.targetSpeed:=newValue;
   exit;
  end;
  // the volume can only fade out to the stop: SDL_mixer has no generic slide
  if (attr<>caVolume) or (newValue>0) then exit;
  if slot=MUSIC_SLOT then
   Mix_FadeOutMusic(round(timeInterval*1000))
  else
   FadeToStop(slot,timeInterval);
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

procedure TSoundLibSDL.Update;
 var
  i:integer;
 begin
  // the effect can't halt its own channel: ended sources are halted here
  for i:=0 to MIXING_CHANNELS-1 do
   if (sources[i].finished<>0) and (Mix_Playing(i)<>0) then Mix_HaltChannel(i);
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
   FadeToStop(slot,STOP_FADE_TIME);
 end;

end.
