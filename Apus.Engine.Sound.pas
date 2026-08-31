// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

// Events syntax:
// Sound\Play\EventName[,param1=value1,...,paramN=valueN]
//  Start playing sample defined by EventName
//  Parameters can override default playback settings
//
// Sound\PlayMusic\MusicName
//

{$I defines.inc}
unit Apus.Engine.Sound;
interface
uses Apus.Core, Apus.Types, Apus.AnimatedValues;
var
 soundFolderPath:string8 = 'Audio\';
 soundConfigFile:string8 = 'sounds.ctl';

type
 TSoundLib = (
  slDefault,   // platform default selection
  slNative,    // AndroidSoundPool / AVAudioPlayer
  slIMixer,    // IMixerPro (ImxEx.dll, Win32-only)
  slBass,      // BASS (bass.dll)
  slSDL);      // SDL Mixer

 TMediaLoadingMode = (
   mlmJustOpen,     // open file but don't load its content
   mlmLoad,         // load file content, don't unpack it
   mlmLoadUnpack);  // load and unpack data

 TVolumeType = (
   vtSounds,   // sounds volume
   vtMusic);   // music volume (streams and modules)

 TChannelAttribute = (
  caVolume,   // relative volume (0..1)
  caPanning,  // -1=left, 1=right
  caSpeed);   // 1.0 - normal speed

 TChannelAttributes = set of TChannelAttribute;


 TChannel=TObject;
 TMediaFile=class
  source:string;
  numChannels,sampleRate,bitDepth:integer;
  duration:single; // in seconds
  procedure DetectParams(fName:string); overload;
  procedure DetectParams(data:TBuffer); overload;
 end;

 TPlaySettings=record
  volume,pan,speed:single;
  loop:boolean;
  loopStart,loopEnd:single;
 end;

const
 DefaultSettings:TPlaySettings=(
  volume: 1.0;
  pan:0;
  speed:1.0;
  loop:false;
  loopStart:0;
  loopEnd:0;
 );

type
 // Interface for the backend sound library (API)
 ISoundLib=interface
  procedure Init(windowHandle:THandle=0);
  procedure SetVolume(volumeType:TVolumeType;volume:single); // 0..1
  function OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
  function PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
  // Stops playback and clears the reference. The channel object belongs to the
  // backend (it can be pooled and reused), so callers must never free it.
  procedure StopChannel(var channel:TChannel);
  procedure SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
  // Which channel attributes can be slided
  function CanSlide:TChannelAttributes;
  // If full volume slide not supported: can it fade in/out music?
  function CanFadeMusic:boolean;
  // Can several music streams play at the same time? If not, starting a new
  // track implicitly ends the previous one.
  function HasSingleMusicStream:boolean;
  // Is this channel still playing? (a stale channel reference yields false)
  function IsPlaying(channel:TChannel):boolean;
  // timeInterval - in seconds
  procedure SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue:single;timeInterval:single);
  // Pause/resume everything that plays (e.g. when the application loses focus)
  procedure Pause(pause:boolean);
  procedure Done;
 end;

// Is a music track playing right now? (diagnostics: the sound thread can
// change the current track at any moment)
function IsMusicPlaying:boolean;
// Initialize sound system
procedure InitSoundSystem(useLibrary:TSoundLib; windowHandle:THandle=0; waitForPreload:boolean=true);
// Shutdown sound system
procedure DoneSoundSystem;


implementation

// The old Java SoundPool/MediaPlayer path is opt-in until it is migrated away
// from the removed MyServis API. SDL-first Android builds currently defer audio.
uses SysUtils, Apus.ControlFiles, Apus.HashMaps, Apus.Utils, Apus.EventMan, Classes
  {$IFDEF IMX},Apus.Engine.SoundImx{$ENDIF}
  {$IFDEF SDLMIX},Apus.Engine.SoundSDL{$ENDIF}
  {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)},Apus.Android,Apus.AndroidSoundPool,Apus.AndroidMediaPlayer{$IFEND}
  ,
  Apus.Conv,
  Apus.Files,
  Apus.Log,
  Apus.Strings,
  Apus.Threads;

type
 // Sound event: play sound sample
 TSoundEvent=class
  name:string; // Sound\Play event name
  fileName:string; // name inside audio folder
  sample:TMediaFile; // can be shared across multiple events
  // default playback settings
  volume, // 1.0 = original volume (can be >1)
  pan, // -1.0 - full left, 0.0 - center, 1.0 - full right
  speed:single; // 1.0 - original rate
  loop:boolean;
  lastChannel:TChannel; // used to control playback of the last instance
  constructor Create(name:string);
  procedure Preload;
 end;

 // Music entry (audio stream file or module)
 TMusicEntry=class
  name:string;    // Sound\PlayMusic entry name
  media:TMediaFile;
  volume:single; // Required relative volume (1.0=normal volume), actual volume may be different
  isModule:boolean;
  channel:TChannel;
  stopTime:int64; // stop channel at this time
  loopPos:double; // in seconds
  loop:boolean;
  curVolume:TAnimatedValue;
  {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
  player:TJNIMediaPlayer;
  {$IFEND}
 end;

 // Thread processing sound events
 TSoundThread=class(TThread)
  waitForPreload:boolean;
  procedure Execute; override;
 end;

var
 soundLib:ISoundLib;
 // Written by the sound thread, read by the main thread: touch them only
 // through RaiseFlag/FlagIsSet so that the access is atomic on every platform
 initialized:integer=0; // ready to process events
 failed:integer=0;
 soundThread:TSoundThread;
 wndHandle:THandle=0;
 ctl:integer;

 evtHash:TStrHash; // event -> TSoundEvent
 musHash:TStrHash; // event -> TMusicEntry
 mediaFilesHash:TSimpleHashS; // Files.FixName (uppercase) -> TMediaFile

 // Need to start this music entry with these parameters
 needMusic:TMusicEntry;
 needMusicPlayFrom:double; // position to play from (sec)
 needMusicStartTime:int64;       // Time to start playback
 needSlide:integer;    // Fade-in duration (ms)
 curMusic:TMusicEntry;

 // Global volume levels (multiply by particular volume)
 soundVolume:single=1.0;
 musicVolume:single=1.0;

// Cross-thread boolean flags
procedure RaiseFlag(var flag:integer); inline;
 begin
  Atomic.Exchange(flag,1);
 end;

function FlagIsSet(var flag:integer):boolean; inline;
 begin
  result:=Atomic.CmpExchange(flag,0,0)<>0;
 end;

// Sample rate of a media file with a safe fallback: it is used as a divisor,
// and some formats can leave it unknown
function SampleRateOf(media:TMediaFile):integer;
 begin
  result:=media.sampleRate;
  if result<=0 then result:=44100;
 end;

{ TMediaFile }

procedure TMediaFile.DetectParams(data:TBuffer);
 procedure ParseWAV;
  begin
   data.Skip(4);
   if data.ReadUInt<>$45564157 {'WAVE'} then raise EError.Create('Invalid WAV format');
   if data.ReadUInt<>$20746d66 {'fmt '} then raise EError.Create('Unrecognized WAV format');
   data.Skip(6);
   numChannels:=data.ReadWord;
   sampleRate:=data.ReadInt;
   data.Skip(6);
   bitDepth:=data.ReadWord;
   duration:=0;
   if data.ReadUInt=$61746164 then
    duration:=data.ReadInt div (sampleRate*numChannels*bitDepth div 8);
  end;

 procedure ParseOGG;
  begin
   data.Seek($27);
   numChannels:=data.ReadByte;
   sampleRate:=data.ReadInt;
   bitDepth:=16;
   duration:=0; // not easy to parse
  end;

 procedure ParseMP3;
  const
   // [version][sample rate index]
   rates:array[0..3,0..2] of integer=(
    (11025,12000,8000),    // MPEG 2.5
    (0,0,0),               // reserved
    (22050,24000,16000),   // MPEG 2
    (44100,48000,32000));  // MPEG 1
  var
   i,ver,srIndex,mode:integer;
   pc:PAnsiChar;
  begin
   numChannels:=2;
   sampleRate:=0;
   bitDepth:=16;
   duration:=0; // needs the whole file (or a VBR header) to be known
   // Scan for the first frame header (11 sync bits): it can be preceded by an ID3 tag
   pc:=PAnsiChar(data.data);
   for i:=0 to data.size-4 do begin
    if (ord(pc[i])=$FF) and (ord(pc[i+1]) and $E0=$E0) then begin
     ver:=(ord(pc[i+1]) shr 3) and 3;
     srIndex:=(ord(pc[i+2]) shr 2) and 3;
     if (ver=1) or (srIndex=3) then continue; // reserved values: not a frame header
     sampleRate:=rates[ver,srIndex];
     mode:=(ord(pc[i+3]) shr 6) and 3;
     if mode=3 then numChannels:=1; // single channel
     break;
    end;
   end;
   if sampleRate=0 then Log.Warn('[SOUND] MP3 frame header not found');
  end;

 var
  c:cardinal;
 begin
  ASSERT(data.size>100);
  c:=data.ReadUInt;
  if c=$5367674F then ParseOGG
  else
  if c=$46464952 then ParseWAV
  else
  if ((c and $FF=$FF) and ((c shr 8) and $E0=$E0)) or (c=$03334449) then ParseMP3;
 end;

procedure TMediaFile.DetectParams(fName: string);
 var
  data:ByteArray;
 begin
  data:=Files.LoadAsBytes(fName,2000);
  DetectParams(TBuffer.CreateFrom(data));
 end;

// Load media file and put it's reference to the mediaFilesHash
function LoadMediaAsSample(fName:string):TMediaFile;
 var
  st:string;
 begin
  st:=Files.FixName(soundFolderPath+fName);
  Log.Msg('[SOUND] Load sample from '+st);
  result:=soundLib.OpenMediaFile(st,mlmLoadUnpack);
  if result<>nil then
   mediaFilesHash.Put(UpperCase {TODO: use st.ToUpper}(fName),UIntPtr(result));
 end;

constructor TSoundEvent.Create(name: string);
 begin
  self.name:=name;
  volume:=DefaultSettings.volume;
  pan:=DefaultSettings.pan;
  speed:=DefaultSettings.speed;
  loop:=false;
 end;

procedure TSoundEvent.Preload;
 var
  p:int64;
 begin
  if sample=nil then begin
   p:=mediaFilesHash.Get(UpperCase(fileName));
   if p=-1 then begin
    sample:=LoadMediaAsSample(fileName);
   end else
    sample:=TMediaFile(pointer(p));
  end;
 end;


(* TODO
function LoadSample(s:TSample):boolean;
 var
  st:string;
  i:integer;
 begin
  result:=false;
  if s=nil then exit;
  if s.handle>0 then exit;
  {$IFDEF IMX}
  s.handle:=IMXSampleLoad(false,PAnsiChar(AnsiString(soundFolderPath+s.fname)));
  {$ENDIF}
  {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
  try
   s.handle:=0;
//   st:=Lowercase {TODO: use st.ToLower}(s.fname);
   st:=s.fname;
   for i:=0 to high(pools) do begin
    if pools[i]=nil then pools[i]:=TSoundPool.Create;
    if pools[i].count<8 then begin
     Log.Force('[SOUND] Loading '+st+' to pool '+inttostr(i));
     s.handle:=pools[i].LoadSoundFile('Audio/'+st);
     s.pool:=i;
     break;
    end;
   end;
  except
   on e:exception do Log.Msg('[Sound] '+ExceptionMsg(e));
  end;
  {$IFEND}

  if s.handle=0 then
   Log.Msg('[Sound] Warning: cannot load sample '+s.fname)
  else begin
   result:=true;
   Log.Msg('[Sound] Sample loaded: '+s.fname+' = '+inttostr(s.handle))
  end;
 end;  *)

// Load sound configuration
procedure LoadConfig;
 var
  ctlRoot:string8;
  path,st:string8;
  sa:Strings8;
  fl:boolean;

 procedure AddEvent(st,name:string8);
  var
   params,param:Strings8;
   i,j:integer;
   evt:TSoundEvent;
  begin
   evt:=TSoundEvent.Create(name);
   params:=st.Split(',','"');
   for i:=0 to length(params)-1 do begin
    param:=params[i].Split('=');
    param[0]:=UpperCase {TODO: use st.ToUpper}(param[0]);
    if param[0]='FILE' then begin
     evt.fileName:=param[1];
     // check if this media file is already loaded
     if mediaFilesHash.HasValue(UpperCase(evt.fileName)) then
      evt.sample:=pointer(mediaFilesHash.Get(UpperCase(evt.fileName)));
    end;
    if param[0]='VOL' then evt.volume:=StrToInt(param[1])/100;
    if param[0]='PAN' then evt.pan:=StrToInt(param[1])/100;
    if param[0]='FREQ' then evt.speed:=StrToInt(param[1])/44100;
    if param[0]='SPEED' then evt.speed:=Conv.ToFloat(param[1]);
   end;
   evtHash.Put(evt.name,evt);
  end;

 procedure AddMusicEntry(name:string);
  var
   item:TMusicEntry;
   fname,lname,fExt:string;
   loop,found:boolean;
   looppos:integer;
   i:integer;
  begin
   path:=ctlRoot+'Music\'+name;
   name:=UpperCase {TODO: use st.ToUpper}(name);
   if ctlGetKeyType(path)<>cktSection then exit;
   item:=TMusicEntry.Create;
   item.name:=name;
   fname:=ctlGetStr(path+'\file');
   item.loop:=ctlGetBool(path+'\loop',false);
   item.looppos:=ctlGetInt(path+'\loopPos',0);
   fExt:=UpperCase {TODO: use st.ToUpper}(ExtractFileExt(fname));
   if (fExt='.OGG') or (fExt='.MP3') or (fExt='.WAV') then begin
    {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
    // Copy file to data folder
    fname:=CopyAssetFile('Audio/'+lowercase {TODO: use st.ToLower}(fname));
    try
     item.player:=TJNIMediaPlayer.Create;
     item.player.SetDataSource(fname,loop);
     item.handle:=UIntPtr(item.player);
     item.isModule:=false;
     item.loopPos:=0;
     if loop then item.loopCount:=-1
      else item.loopCount:=0;
     item.curVolume.Init;
     Log.Msg('[SOUND] Music loaded: %s = %d '[fname,item.handle]);
    except
     on e:Exception do begin
       Log.Msg('[SOUND] Music loading failed: '+ExceptionMsg(e));
     end;
    end;
    {$IFEND}

    // Load as stream
    item.media:=soundLib.OpenMediaFile(Files.FixName(soundFolderPath+fname),mlmJustOpen);
    item.isModule:=false;
   end else
   if (fExt='.MOD') or (fExt='.S3M') or (fExt='.XM') then begin
    // load as module
    item.media:=soundLib.OpenMediaFile(Files.FixName(soundFolderPath+fname),mlmLoad);
    item.isModule:=true;
   end;
   if item.media=nil then begin
     Log.Force('[SOUND] Failed to load music file '+fName);
    exit;
   end;
   item.volume:=ctlGetInt(path+'\volume',75)/100;
   MusHash.Put(item.name,item);
  end;

 procedure LoadSoundEvents;
  var
   kt:ctlKeyTypes;
   i:integer;
  begin
   path:=ctlRoot+'SoundEvents';
   st:=ctlGetKeys(path);
   sa:=st.Split(' ');
   path:=path+'\';
   for i:=0 to length(sa)-1 do begin
    kt:=ctlGetKeyType(path+sa[i]);
    if kt=cktString then try
     // event defined as a string value
     AddEvent('file='+ctlGetStr(path+sa[i]),UpperCase {TODO: use st.ToUpper}(sa[i]));
    except
     on e:Exception do raise EError.Create('Error in sound event definition: '+ExceptionMsg(e));
    end;
   end;
  end;

 procedure PreloadSamples;
  var
   evt:TSoundEvent;
   i:integer;
   st,mode,fName:string8;
   list:PointerArray;
  begin
   path:=ctlRoot+'Settings\';
   st:=ctlGetStr(path+'PreloadSamples');
   mode:=UpperCase {TODO: use st.ToUpper}(st);
   Log.Force('[SOUND] Preloading mode: '+mode);
   if mode<>'NONE' then Log.Msg('[SOUND] Preloading');
   if mode='ALL' then begin
    // preload all
    list:=evtHash.GetValues;
    for i:=0 to high(list) do
     TSoundEvent(list[i]).Preload;
   end else
   if mode='NONE' then
   else begin
    // preload listed
    sa:=st.Split(',');
    for fName in sa do LoadMediaAsSample(fName);
   end;
   if mode<>'NONE' then Log.Msg('[SOUND] samples preloading done');
  end;

 procedure LoadMusicEntries;
  var
   i:integer;
  begin
   // Load music entries
   path:=ctlRoot+'Music';
   st:=ctlGetKeys(path);
   sa:=st.Split(' ');
   for i:=0 to length(sa)-1 do
    AddMusicEntry(sa[i]);
  end;

 begin
  Log.Msg('[SOUND] Loading config');
  try
   evtHash:=TStrHash.Create;
   mediaFilesHash.Init(100);
   musHash:=TStrHash.Create;
   ctlRoot:=ExtractFileName(soundConfigFile)+':\';
   path:=ctlRoot+'Settings\';
{  SetSoundVolume(ctlGetInt(path+'SoundVolume'));
  SetMusicVolume(ctlGetInt(path+'MusicVolume'));}

   LoadSoundEvents;
   PreloadSamples;
   LoadMusicEntries;
   Log.Msg('[SOUND] Config loaded');
  except
   on e:Exception do begin
    Log.Force('[SOUND] config loading error: '+ExceptionMsg(e));
    RaiseFlag(failed);
   end;
  end;
 end;


(* TODO
// Callback для зацикливания потоковой музыки
procedure LoopMusicProc(sync,chan,data,user:cardinal); stdcall;
 var
  item:TMusicEntry;
 begin
  {$IFDEF IMX}
  item:=pointer(user);
  if item.loopcount<>0 then
    IMXChannelSetPosition(item.handle,item.loopPos);
  inc(item.loopcount);
  {$ENDIF}
 end;
*)

procedure PlaySound(event:TEventStr;tag:TTag);
 var
  sa:Strings8;
  evt:TSoundEvent;
  settings:TPlaySettings;
  par:TNameValue;
  slide:integer;
  newVolume,newSpeed,newPan:single;
  i,p:integer;
 begin
   Log.Msg('[SOUND] '+event+' '+IntToHex(tag,6));
   if soundvolume=0 then exit;
   delete(event,1,5);
   sa:=event.Split(',','"');
   event:=sa[0];
   // Get sample object
   evt:=EvtHash.Get(event);
   if evt=nil then begin
     Log.Msg('[SOUND] Event not found: '+event);
     exit;
   end;
   evt.Preload;
   if evt.sample=nil then exit;   // Can't load sample => exit

   // Configure playback settings
   // 1. Load defaults
   settings:=DefaultSettings;
   with settings do begin
    volume:=evt.volume;
    pan:=evt.pan;
    speed:=evt.speed;
    loop:=evt.loop;
   end;
   slide:=0;
   newVolume:=settings.volume;
   newSpeed:=settings.speed;
   newPan:=settings.pan;
   // 2. Override
   for i:=1 to high(sa) do begin
     par.InitFrom(sa[i]);
     if par.Named('vol') or par.named('v') then begin
      if par.value.EndsWith('%') then
       settings.volume:=settings.volume*par.GetInt/100
      else
       settings.volume:=par.GetInt/100;
     end else
     if par.Named('pan') or par.Named('p') then settings.pan:=par.GetInt/100
     else
     if par.Named('freq') or par.Named('f') then settings.speed:=par.GetInt/SampleRateOf(evt.sample)
     else
     if par.Named('speed') or par.Named('r') then settings.speed:=par.GetFloat
     else
     if par.Named('slide') or par.Named('s') then slide:=par.GetInt
     else
     if par.Named('newvol') or par.Named('nv') then newVolume:=par.GetInt/100
     else
     if par.Named('newpan') or par.Named('np') then newpan:=par.GetInt/100
     else
     if par.Named('newfreq') or par.Named('nf') then newSpeed:=par.GetInt/SampleRateOf(evt.sample);
   end;


   // Low byte of tag overrides volume (in %)
   p:=tag and 255;
   if p<>0 then settings.volume:=settings.volume*p/100;

   // 8..23 bits of tag = override sample frequency (if >250) or speed (1..250 in %)
   p:=(tag shr 8) and $FFFF;
   if p>0 then begin
    if p>250 then settings.speed:=p/SampleRateOf(evt.sample)
     else settings.speed:=p/100;
   end;
   // High byte of tag overrides pan (-128..127 -> -1.0..1.0)
   p:=shortint(tag shr 24);
   if p<>0 then settings.pan:=Clamp(p/100.0,-1.0,1.0);

   evt.lastChannel:=soundLib.PlayMedia(evt.sample, settings);
   if slide>0 then begin
    if newVolume<>settings.volume then
     soundLib.SlideChannel(evt.lastChannel,caVolume,newVolume,slide/1000);
    if newSpeed<>settings.speed then
     soundLib.SlideChannel(evt.lastChannel,caSpeed,newSpeed,slide/1000);
    if newPan<>settings.pan then
     soundLib.SlideChannel(evt.lastChannel,caPanning,newPan,slide/1000);
   end;

  {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
  evt.channel:=pools[evt.sample.pool].PlaySound(evt.sample.handle,v/100,v/100,1.0,false);
  {$IFEND}
 end;

procedure PlayMusic(event:TEventStr;tag:TTag);
 var
  mus:TMusicEntry;
  downtime:integer;
 begin
   mus:=nil;
   if event<>'NONE' then
    mus:=MusHash.Get(event);
   // Playback position
   needMusicPlayFrom:=(tag shr 8)/100000;
   tag:=tag and $FF;
   if (tag and 128)>0 then
    tag:=tag and $7F
   else begin
    // Already playing the requested track?
    if (mus<>nil) and (curMusic=mus) then exit;
   end;

   case tag of
    0:begin // normal: fade-out old music, then start new
       downtime:=1200;
       needslide:=0;
       needMusicStartTime:=CoreTime.Ticks+1000;
    end;
    1:begin // fast fade-out, start new almost immediately
       downtime:=400;
       needslide:=0;
       needMusicStartTime:=CoreTime.Ticks+300;
    end;
    2:begin // very slow fade-out
       downtime:=2500;
       needslide:=0;
       needMusicStartTime:=CoreTime.Ticks+3000;
    end;
    3:begin // slow fade-out, smooth fade-in crossfade
       downtime:=2000;
       needslide:=2000;
       needMusicStartTime:=CoreTime.Ticks+800;
    end;
    4:begin // slow fade-out, smooth fade-in without crossfade
       downtime:=2500;
       needslide:=2000;
       needMusicStartTime:=CoreTime.Ticks+2000;
    end;
    5:begin // fast fade-out, slow fade-in crossfade
       downtime:=500;
       needslide:=2000;
       needMusicStartTime:=CoreTime.Ticks+400;
    end;
    6:begin // fast fade-out, medium fade-in crossfade
       downtime:=500;
       needslide:=500;
       needMusicStartTime:=CoreTime.Ticks+250;
    end;
    else begin
     Log.Msg('[SOUND] PlayMusic: unknown tag %d',[tag]);
     exit;
    end;
   end;
   // Fade-Out all playing music streams
   if curMusic<>nil then begin
     if downTime>0 then begin
      Log.Msg('[SOUND] Fading out current music during '+inttostr(downtime));
      if (caVolume in soundLib.CanSlide) or (soundLib.CanFadeMusic) then
       soundLib.SlideChannel(curMusic.channel,caVolume,0,downTime/1000)
      else begin
       curMusic.curVolume.Init(curMusic.volume);
      end;
      curMusic.stopTime:=CoreTime.Ticks+downTime;
     end else begin
      Log.Msg('[SOUND] Stop current music immediately');
      soundLib.StopChannel(curMusic.channel);
      curMusic:=nil;
     end;
   end else
    needMusicStartTime:=CoreTime.Ticks;

   if event<>'NONE' then begin
    mus:=MusHash.Get(event);
    if mus<>nil then needMusic:=mus
     else Log.Msg('[SOUND] Music not found: '+event);
   end;
 end;

 // Pause/resume all playback
 procedure PauseAll(pause:boolean);
  var
   mus:TMusicEntry;
   st:string;
  begin
   if soundLib<>nil then begin
    if pause then Log.Info('[SOUND] Pause')
     else Log.Info('[SOUND] Resume');
    soundLib.Pause(pause);
   end;
   st:=MusHash.FirstKey;
   while st<>'' do begin
    mus:=MusHash.Get(st);
    if mus.channel<>nil then begin
     {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
     if pause then begin
      Log.Msg('Pause music track '+mus.name);
      mus.player.Pause;
     end else begin
      Log.Msg('Resume music track '+mus.name);
      mus.player.Resume;
     end;
     {$IFEND}
    end;
    st:=MusHash.NextKey;
   end;
  end;

procedure AnimateMusicVolume(mus:TMusicEntry);
 var
  v:single;
 begin
  v:=mus.curVolume.Value;
  soundLib.SetChannelAttribute(mus.channel,caVolume,v);
  {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
  rVol:=mus.curVolume.Value/100;
  mus.player.SetVolume(rVol,rVol);
  if mus.curVolume.IsAnimating then
    DelayedSignal(event,10,tag);
  {$IFEND}
  if mus.curVolume.IsAnimating then
   DelayedSignal('SOUND\AnimateMusicVol',10,TTag(mus));
 end;

procedure EventHandler(event:TEventStr;tag:TTag);
 var
  i,p,v,freq,vol,pan,newpan,newfreq,slide:integer;
 begin
  try
  delete(event,1,6);
  event:=UpperCase {TODO: use st.ToUpper}(event);

  if event='ANIMATEMUSICVOL' then AnimateMusicVolume(TMusicEntry(tag));

(* TODO
  // Unload all loaded audio samples
  if pos('CLEARCACHE\',event)=1 then begin
   delete(event,1,11);
   evt:=evtHash.Get(event);
   if evt<>nil then begin

    {$IFDEF IMX}
    IMXSampleUnload(evt.sample.handle);
    {$ENDIF}
    {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
    pools[evt.sample.pool].UnloadSound(evt.sample.handle);
    {$IFEND}
    evt.sample.handle:=0;
   end;
   exit;
  end; *)

  // Play sound sample (load if not loaded)
  if event.StartsWith('PLAY\') then
   PlaySound(event,tag)
  else
  if event.StartsWith('CHANGE\') then
   /// TODO
   //SlideChannel(event,tag)
  else

  (*
  // Change channel attributes
  if pos('CHANGE\',event)=1 then begin
   delete(event,1,7);

   sa:=split {TODO: use st.Split(char)}(',',event,'"');
   event:=sa[0];
   pan:=-101;
   v:=-1;
   slide:=1;
   if length(sa)>1 then begin
    newfreq:=-1; newpan:=-101;
    for i:=1 to length(sa)-1 do begin
     sa2:=split {TODO: use st.Split(char)}('=',sa[i],#0);
     if length(sa2)<2 then continue;
     if (sa2[0]='VOL') or (sa2[0]='V') then v:=StrToInt(sa2[1]);
     if (sa2[0]='PAN') or (sa2[0]='P') then pan:=StrToInt(sa2[1]);
     if (sa2[0]='SLIDE') or (sa2[0]='S') then slide:=StrToInt(sa2[1]);
     if (sa2[0]='NEWPAN') or (sa2[0]='NP') then newpan:=StrToInt(sa2[1]);
     if (sa2[0]='NEWFREQ') or (sa2[0]='NF') then newfreq:=StrToInt(sa2[1]);
    end;
   end;
   evt:=EvtHash.Get(event);
   if evt=nil then begin
    Log.Msg('SOUND: sound event not found - '+event);
    exit;
   end;
   if evt.channel=0 then exit;
   if tag and 255<>0 then v:=tag and 255;
   freq:=(tag shr 8) and $FFFF;
   if tag and $FF000000<>0 then p:=shortint(tag shr 24) else p:=evt.pan;
   if pan<>-101 then p:=pan;  // тут хрень какая-то!

   {$IFDEF IMX}
   IMXChannelSlide(evt.channel,v,newpan,newfreq,slide);
   {$ENDIF}

   exit;
  end;  *)

  if event.StartsWith('SETVOLUME\') then begin
   delete(event,1,10);
   if event='SOUND' then begin
    soundVolume:=tag/100;
    soundLib.SetVolume(vtSounds,soundVolume);
   end else
   if event='MUSIC' then begin
    musicvolume:=tag/100;
    soundLib.SetVolume(vtMusic,musicvolume);
   end;
   exit;
  end;

  if event.StartsWith('MUSICPOS') then begin
   needMusicPlayFrom:=tag/100000;
   exit;
  end;

  if event.StartsWith('PAUSE') or event.startsWith('RESUME') then
   PauseAll(event.StartsWith('PAUSE'));

  if pos('PLAYMUSIC\',event)=1 then begin
   Log.Msg('[SOUND] '+event);
   delete(event,1,10);
   PlayMusic(event,tag);
  end;
  except
   on e:exception do Log.Force('Sound event ('+event+') error: '+ExceptionMsg(e));
  end;
 end;

function IsMusicPlaying:boolean;
 var
  mus:TMusicEntry;
 begin
  mus:=curMusic;
  result:=(soundLib<>nil) and (mus<>nil) and (mus.channel<>nil) and soundLib.IsPlaying(mus.channel);
 end;

procedure InitSoundSystem(useLibrary:TSoundLib; windowHandle:THandle=0; waitForPreload:boolean=true);
 begin
  {$IF NOT DEFINED(SDLMIX) AND NOT DEFINED(IMX)}
  // Audio backends are opt-in (see defines.inc). With none of them compiled in
  // the sound system just stays inactive: this is a build-time choice, not a
  // runtime failure, so no exception is raised here.
  if useLibrary=slDefault then begin
   Log.Msg('[SOUND] No sound backend is compiled in, audio is disabled. Build with -dSDLMIX to enable it.');
   exit;
  end;
  {$IFEND}
  if not FileExists(soundConfigFile) then begin
   Log.Msg('[SOUND] No config file found (%s). Sound system won''t initialize.',[soundConfigFile]);
   exit;
  end;
  wndHandle:=windowHandle;
  if useLibrary=slDefault then begin
   {$IF DEFINED(SDLMIX)}
   useLibrary:=slSDL;
   {$ELSEIF DEFINED(IMX)}
   useLibrary:=slIMixer;
   {$ELSE}
   raise EError.Create('No sound backend is compiled in: build with -dSDLMIX (SDL2_mixer)');
   {$IFEND}
  end;
  case useLibrary of
   slIMixer:{$IFDEF IMX}soundLib:=TSoundLibImx.Create;{$ELSE}raise EError.Create('IMixer sound backend is not compiled in (define IMX)');{$ENDIF}
   slSDL:{$IFDEF SDLMIX}soundLib:=TSoundLibSDL.Create;{$ELSE}raise EError.Create('SDL_mixer sound backend is not compiled in (define SDLMIX)');{$ENDIF}
   slBass:raise EError.Create('BASS sound backend is not implemented');
   slNative:raise EError.Create('Native sound backend is not implemented');
   else raise EError.Create('Unknown sound library id: '+IntToStr(ord(useLibrary)));
  end;
  soundThread:=TSoundThread.Create(false);
  soundThread.waitForPreload:=waitForPreload;
  repeat
   CoreTime.Sleep(10);
   HandleSignals;
  until FlagIsSet(initialized) or FlagIsSet(failed);
  if FlagIsSet(failed) then begin
   soundThread.Free;
   raise EError.Create('[SOUND] Initialization failed!');
  end;
  soundThread.Priority:=tpHigher;
 end;

procedure DoneSoundSystem;
 begin
  if not FlagIsSet(initialized) then exit;
  soundThread.Free; // stop & wait
 end;

// A single-stream backend replaces the previous track when a new one starts:
// forget the old channel so that its pending stop doesn't kill the new track
procedure DropOtherMusicChannels(keep:TMusicEntry);
var
 keys:Strings;
 st:string;
 mus:TMusicEntry;
begin
 keys:=musHash.GetKeys;
 for st in keys do begin
  mus:=TMusicEntry(musHash.Get(st));
  if (mus<>keep) and (mus.channel<>nil) then begin
   mus.channel:=nil;
   mus.stopTime:=0;
  end;
 end;
end;

procedure PlayNeededMusic;
var
 settings:TPlaySettings;
begin
 if needMusic=nil then exit;
 needMusic.stopTime:=0;
 settings:=DefaultSettings;
 if needSlide=0 then settings.volume:=needMusic.volume
  else settings.volume:=0;
 if needMusic.loop then begin
  settings.loop:=true;
  settings.loopStart:=needMusic.loopPos;
  settings.loopEnd:=0;
 end;
 curMusic:=needMusic;
 curMusic.channel:=soundLib.PlayMedia(needMusic.media,settings);
 if (curMusic.channel<>nil) and soundLib.HasSingleMusicStream then
  DropOtherMusicChannels(curMusic);
 if needSlide>0 then begin
  if caVolume in soundLib.CanSlide then
   soundLib.SlideChannel(curMusic.channel,caVolume,curMusic.volume,needSlide/1000)
  else begin
   curMusic.curVolume.Init(0);
   curMusic.curVolume.Animate(curMusic.volume,needSlide,spline0);
   DelayedSignal('SOUND\AnimateMusicVol',10,TTag(curMusic));
  end;
 end;
 needmusic:=nil;
end;

procedure StopMusicChannels;
var
 keys:Strings;
 st:string;
 mus:TMusicEntry;
 t:int64;
begin
 t:=CoreTime.Ticks;
 keys:=musHash.GetKeys;
 for st in keys do begin
  mus:=TMusicEntry(musHash.Get(st));
  if (mus.channel<>nil) and (mus.stopTime>0) and (t>mus.stopTime) then begin
   mus.stopTime:=0;
   soundLib.StopChannel(mus.channel);
  end;
 end;
end;

{ TSoundThread }
procedure TSoundThread.Execute;
begin
 try
  Thread.Register('Sound(E3)');
  // initialization
  soundLib.Init(wndHandle);
  soundLib.SetVolume(vtSounds,soundVolume);
  soundLib.SetVolume(vtMusic,musicVolume);

  {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
  pools[0]:=TSoundPool.Create; // Also registers current thread
  {$IFEND}

  ctl:=UseControlFile(soundConfigFile,'');
  SetEventHandler('SOUND',EventHandler,emQueued);
  if not waitForPreload then RaiseFlag(initialized);
  LoadConfig;
  needmusic:=nil;
  RaiseFlag(initialized);
  // Main loop
  repeat
   try
    Thread.Ping;
    try
     HandleSignals;
    except
     on e:Exception do
      Log.Msg('Error '+ExceptionMsg(e));
    end;

    if (needmusic<>nil) and (CoreTime.Ticks>needMusicStartTime) then PlayNeededMusic;
    StopMusicChannels;
   except
    on e:exception do Log.Force('[SOUND] Error: '+ExceptionMsg(e));
   end;
   CoreTime.Sleep(5);
  until Terminated;
  // Termination

  soundLib.Done;

  FreeControlFile(ctl);
  MusHash.Free;
  EvtHash.Free;
 except
  on e:Exception do begin
   RaiseFlag(failed);
   Log.Force('[SOUND] '+ExceptionMsg(e))
  end;
 end;
 Thread.Unregister;
end;


end.
