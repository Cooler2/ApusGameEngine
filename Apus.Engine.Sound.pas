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
// Sound\PlayFile\Path[,vol=N][,group=Name]
//  Load a file (VFS path, not inside the audio folder) and play it once as a sample;
//  it is unloaded when finished. Group "file" is used by default
// Sound\StopFile\Path, Sound\StopGroup\Name, Sound\StopAllFiles (= StopGroup\file)
//  Stop file playback (short fade-out), no notification is sent
// Sound\SetGroup\Name[,duck=N][,exclusive=0|1]
//  Group playback policy: duck = music volume (in %) while any file of the group plays,
//  exclusive = a new file stops other files of the group. Default: no ducking, not exclusive
// Sound\ClearCache[\EventName]
//  Unload the sample of this event (or all samples): it is loaded again when played
//
// Outgoing: Sound\FilePlayed\Path - a file played to the end (not sent if it was stopped)
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


 // Playback handle: an opaque value, 0 = no playback. ISoundSystem and the backend
 // (ISoundLib) give out handles of their own. A handle is not reused right after its
 // playback ends, so a stale handle stays safe for a reasonable time: IsPlaying
 // returns false and other operations ignore it
 TChannel=type cardinal;
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
  // Loop region in seconds of the media file: a looped playback continues from
  // loopStart when it reaches loopEnd (0 = the end of the file). Seconds stay
  // valid when the file is resampled; double keeps sample positions exact
  loopStart,loopEnd:double;
  startPos:double; // music: position to start from, seconds
 end;

const
 DefaultSettings:TPlaySettings=(
  volume: 1.0;
  pan:0;
  speed:1.0;
  loop:false;
  loopStart:0;
  loopEnd:0;
  startPos:0;
 );

type
 // Generates the next piece of a procedural sound into data: count values per
 // channel, interleaved (stereo: L,R,L,R...), in -1..1, sampleRate values per
 // second for each channel, so data holds count*channels singles.
 // Called in the audio thread: no allocations, logging, exceptions or waiting for
 // locks the game thread may hold; read the game's parameters through atomics.
 // Return false when the sound is over: playback stops after this piece.
 // A stopped stream fades out over a few milliseconds and the procedure is still
 // called meanwhile: userData must stay valid until IsPlaying turns false.
 TSoundStreamProc=function(data:PSingle;count,channels,sampleRate:integer;userData:pointer):boolean;

 // Interface for the backend sound library (API)
 ISoundLib=interface
  procedure Init(windowHandle:THandle=0);
  procedure SetVolume(volumeType:TVolumeType;volume:single); // 0..1
  function OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
  function PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
  // Start a procedural sound: it's mixed as a sample
  function PlayStream(proc:TSoundStreamProc;userData:pointer;channels:integer;volume:single):TChannel;
  // Stops playback and clears the handle
  procedure StopChannel(var channel:TChannel);
  procedure SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
  // Which channel attributes can be slided
  function CanSlide:TChannelAttributes;
  // If full volume slide not supported: can it fade in/out music?
  function CanFadeMusic:boolean;
  // Can several music streams play at the same time? If not, starting a new
  // track implicitly ends the previous one.
  function HasSingleMusicStream:boolean;
  // Is this playback still going on? (paused counts as playing, a stale handle yields false)
  function IsPlaying(channel:TChannel):boolean;
  // timeInterval - in seconds
  procedure SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue:single;timeInterval:single);
  // Pause/resume everything that plays (e.g. when the application loses focus)
  procedure Pause(pause:boolean);
  // Housekeeping, called by the sound thread on every cycle
  procedure Update;
  procedure Done;
 end;

 // Game-side sound API (the backend interface is ISoundLib). Calls from any thread
 // return at once: the work is done by the sound thread, so a handle can refer to
 // a playback that has not started yet. The Sound\... events do the same work
 ISoundSystem=interface
  // Start the sound thread with this backend (slDefault - whichever is compiled
  // in) and load the configuration soundConfigFile
  procedure Init(useLibrary:TSoundLib=slDefault;windowHandle:THandle=0;waitForPreload:boolean=true);
  procedure Done;
  // Global
  procedure SetVolume(volumeType:TVolumeType;volume:single); // 0..1
  procedure Pause(pause:boolean);
  // Samples: events of the config (Sound\Play). Volume and speed multiply the
  // configured values, pan is added to the configured one
  function Play(const event:String8;volume:single=1;pan:single=0;speed:single=1):TChannel;
  procedure ClearCache(const event:String8=''); // '' = all samples
  // Music (Sound\PlayMusic): fadeOut - of the current track, startAfter - delay of
  // the new one (when something plays), fadeIn - of the new one, all in seconds;
  // fromPos - position in the new track (sec), restart - even if it already plays
  procedure PlayMusic(const name:String8;fadeOut:single=1.2;startAfter:single=1;fadeIn:single=0;
    fromPos:double=0;restart:boolean=false);
  procedure StopMusic(fadeOut:single=1.2);
  // Is a music track playing right now? (the sound thread can change it at any moment)
  function IsMusicPlaying:boolean;
  // Files outside the config (Sound\PlayFile): played once, unloaded when finished
  function PlayFile(const path:String8;volume:single=1;const group:String8='file'):TChannel;
  procedure StopFile(const path:String8);
  procedure StopGroup(const group:String8);
  // Playback policy of a file group (Sound\SetGroup): duck - music volume (0..1)
  // while a file of the group plays, exclusive - a new file stops the others
  procedure SetGroup(const group:String8;duck:single=1;exclusive:boolean=false);
  // Procedural sound: mixed with the samples, follows the sounds volume and pause
  function PlayStream(proc:TSoundStreamProc;userData:pointer;channels:integer=2;volume:single=1):TChannel;
  // Any playback started above; time>0 changes the value smoothly over time seconds
  procedure SetChannelVolume(channel:TChannel;volume:single;time:single=0); // 1 = as started
  procedure SetChannelPan(channel:TChannel;pan:single;time:single=0); // -1 = left, 1 = right
  procedure SetChannelSpeed(channel:TChannel;speed:single;time:single=0); // 1 = original speed (and pitch)
  // Stop with a short fade-out (a cut would click) and clear the handle;
  // IsPlaying of a copy of the handle turns false when the fade-out is over
  procedure StopChannel(var channel:TChannel);
  function IsPlaying(channel:TChannel):boolean;
 end;

var
 sound:ISoundSystem; // always assigned; without a backend the calls do nothing


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
  loopPos:double; // loop start in seconds, see TPlaySettings
  loop:boolean;
  curVolume:TAnimatedValue;
  {$IF DEFINED(ANDROID) AND DEFINED(ANDROID_LEGACY_AUDIO)}
  player:TJNIMediaPlayer;
  {$IFEND}
 end;

 // Group of file playbacks: the playback policy belongs to the group, not to the verbs
 TFileGroup=class
  name:string8; // uppercase
  duck:single;  // music volume factor while a file of the group plays (1.0 = no ducking)
  exclusive:boolean; // a new file stops the other files of the group
 end;

 // One-shot file playback (Sound\PlayFile)
 TFilePlayback=class
  path:string8; // as given by the caller: Sound\FilePlayed carries it back
  group:TFileGroup;
  media:TMediaFile; // owned: unloaded together with the playback
  channel:TChannel;
  stopped:boolean; // stopped explicitly: fading out, no notification
  destructor Destroy; override;
 end;

 // Thread processing sound events
 TSoundThread=class(TThread)
  waitForPreload:boolean;
  procedure Execute; override;
 end;

 TVoiceState=(vsFree,vsPending,vsPlaying);

 // Playback started through ISoundSystem: its handle is given out at once, and the
 // sound thread binds it to a backend channel when it runs the command
 TVoice=record
  generation:cardinal; // bumped on every new playback, so older handles of the voice become stale
  state:TVoiceState;   // changed under soundLock
  // sound thread only
  channel:TChannel;    // backend channel
  baseVolume:single;   // volume the playback started with
  sliding:TChannelAttributes; // slides the backend can't do: animated in UpdateVoices
  volume,pan:TAnimatedValue;
 end;

 TCommandKind=(ckPlay,ckPlayFile,ckPlayStream,ckPlayMusic,ckStopMusic,ckStopFile,
  ckStopGroup,ckSetGroup,ckClearCache,ckSetVolume,ckPause,ckSetChannel,ckStopChannel);

 // ISoundSystem call for the sound thread
 TSoundCommand=record
  kind:TCommandKind;
  voice:TChannel;      // ISoundSystem handle of the playback
  name,group:String8;
  a,b,c:single;        // numeric parameters in the order of the ISoundSystem method
  pos:double;
  flag:boolean;
  attr:TChannelAttribute;
  volumeType:TVolumeType;
  proc:TSoundStreamProc;
  userData:pointer;
  channels:integer;
 end;
 TSoundCommands=array of TSoundCommand;

 TSoundSystem=class(TInterfacedObject,ISoundSystem)
  procedure Init(useLibrary:TSoundLib;windowHandle:THandle;waitForPreload:boolean);
  procedure Done;
  procedure SetVolume(volumeType:TVolumeType;volume:single);
  procedure Pause(pause:boolean);
  function Play(const event:String8;volume,pan,speed:single):TChannel;
  procedure ClearCache(const event:String8);
  procedure PlayMusic(const name:String8;fadeOut,startAfter,fadeIn:single;fromPos:double;restart:boolean);
  procedure StopMusic(fadeOut:single);
  function IsMusicPlaying:boolean;
  function PlayFile(const path:String8;volume:single;const group:String8):TChannel;
  procedure StopFile(const path:String8);
  procedure StopGroup(const group:String8);
  procedure SetGroup(const group:String8;duck:single;exclusive:boolean);
  function PlayStream(proc:TSoundStreamProc;userData:pointer;channels:integer;volume:single):TChannel;
  procedure SetChannelVolume(channel:TChannel;volume,time:single);
  procedure SetChannelPan(channel:TChannel;pan,time:single);
  procedure SetChannelSpeed(channel:TChannel;speed,time:single);
  procedure StopChannel(var channel:TChannel);
  function IsPlaying(channel:TChannel):boolean;
 private
  // Queue the command for the sound thread; newVoice - it starts a playback: returns its handle
  function Post(var cmd:TSoundCommand;newVoice:boolean=false):TChannel;
  procedure SetAttribute(channel:TChannel;attr:TChannelAttribute;value,time:single);
 end;

const
 DEFAULT_FILE_GROUP = 'FILE';
 FILE_FADE_TIME = 0.1; // fade-out of a stopped file (sec)
 DUCK_DOWN_TIME = 1000; // music ducking (ms)
 DUCK_RESTORE_TIME = 1500;
 // ISoundSystem handle layout: low 8 bits = voice index+1 (so 0 is "no playback"),
 // high 24 bits = generation of the voice
 MAX_VOICES = 255;
 VOICE_BITS = 8;
 VOICE_MASK = $FF;
 GENERATION_MASK = $FFFFFF;

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

 // File playback (sound thread only)
 fileGroups:array of TFileGroup;
 filePlaybacks:array of TFilePlayback;
 musicDuck:TAnimatedValue; // music volume factor requested by playing files
 appliedDuck:single=1.0;   // the factor music volume is currently set with

 // ISoundSystem: the queue of calls and the playbacks they started
 soundLock:TLock;
 commands:TSoundCommands;
 voices:array[0..MAX_VOICES-1] of TVoice;
 musicPlaying:integer; // published by the sound thread for IsMusicPlaying

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
   // Loop start: "loopTime" in seconds (survives resampling of the file) wins over
   // "loopPos" in samples of the file (the unit of the original Engine 2 configs)
   case ctlGetKeyType(path+'\loopTime') of
    cktReal:item.loopPos:=ctlGetReal(path+'\loopTime');
    cktInteger:item.loopPos:=ctlGetInt(path+'\loopTime');
    else begin
     looppos:=ctlGetInt(path+'\loopPos',0);
     if looppos>0 then begin
      if item.media.sampleRate<=0 then
       Log.Warn('[SOUND] %s: unknown sample rate, loopPos assumes %d Hz',[fname,SampleRateOf(item.media)]);
      item.loopPos:=looppos/SampleRateOf(item.media);
     end;
    end;
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


// Sound event (uppercase name) with its sample loaded, nil if there is none
function GetEventSample(const name:string8):TSoundEvent;
 begin
  result:=EvtHash.Get(name);
  if result=nil then begin
   Log.Msg('[SOUND] Event not found: '+name);
   exit;
  end;
  result.Preload;
  if result.sample=nil then result:=nil; // can't load the sample
 end;

// ISoundSystem.Play: volume and speed multiply the configured values, pan is added
function PlayEvent(const name:string8;volume,pan,speed:single;out settings:TPlaySettings):TChannel;
 var
  evt:TSoundEvent;
 begin
  result:=0;
  settings:=DefaultSettings;
  if soundVolume=0 then exit;
  evt:=GetEventSample(UpperCase(name));
  if evt=nil then exit;
  settings.volume:=evt.volume*volume;
  settings.pan:=Clamp(evt.pan+pan,-1.0,1.0);
  settings.speed:=evt.speed*speed;
  settings.loop:=evt.loop;
  evt.lastChannel:=soundLib.PlayMedia(evt.sample,settings);
  result:=evt.lastChannel;
 end;

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
   evt:=GetEventSample(event);
   if evt=nil then exit;

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

// Switch the music: fade the current track out over fadeOut seconds (0 = stop it at
// once) and start the new one (none if the name is empty or NONE) startAfter seconds
// later (at once if nothing plays) with a fade-in of fadeIn seconds, from fromPos seconds
procedure StartMusic(name:string8;fadeOut,startAfter,fadeIn:single;fromPos:double;restart:boolean);
 var
  mus:TMusicEntry;
  downtime:integer;
 begin
   if name='NONE' then name:='';
   mus:=nil;
   if name<>'' then mus:=MusHash.Get(name);
   // Already playing the requested track?
   if not restart and (mus<>nil) and (curMusic=mus) then exit;
   needMusicPlayFrom:=fromPos;
   needSlide:=round(fadeIn*1000);
   needMusicStartTime:=CoreTime.Ticks+round(startAfter*1000);
   downtime:=round(fadeOut*1000);
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

   // a track that waits for its start is replaced too
   needMusic:=mus;
   if (name<>'') and (mus=nil) then Log.Msg('[SOUND] Music not found: '+name);
 end;

// Sound\PlayMusic\Name: the low 7 bits of the tag select a transition, bit 7 restarts
// the track that already plays, the bits from 8 up give the start position (1/100000 s)
procedure PlayMusicEvent(const name:string8;tag:TTag);
 const
  // fade-out, start delay, fade-in (sec)
  TRANSITIONS:array[0..6,0..2] of single=(
   (1.2, 1.0, 0),    // normal: fade-out old music, then start new
   (0.4, 0.3, 0),    // fast fade-out, start new almost immediately
   (2.5, 3.0, 0),    // very slow fade-out
   (2.0, 0.8, 2.0),  // slow fade-out, smooth fade-in crossfade
   (2.5, 2.0, 2.0),  // slow fade-out, smooth fade-in without crossfade
   (0.5, 0.4, 2.0),  // fast fade-out, slow fade-in crossfade
   (0.5, 0.25, 0.5)); // fast fade-out, medium fade-in crossfade
 var
  mode:integer;
 begin
  mode:=tag and $7F;
  if mode>high(TRANSITIONS) then begin
   Log.Msg('[SOUND] PlayMusic: unknown tag %d',[mode]);
   exit;
  end;
  StartMusic(name,TRANSITIONS[mode,0],TRANSITIONS[mode,1],TRANSITIONS[mode,2],
    (tag shr 8)/100000,tag and 128<>0);
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
    if mus.channel<>0 then begin
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

{ TFilePlayback }

destructor TFilePlayback.Destroy;
 begin
  soundLib.StopChannel(channel);
  media.Free;
  inherited;
 end;

// Find a group by name, create it with the default policy if needed
function GetFileGroup(name:string8):TFileGroup;
 var
  g:TFileGroup;
 begin
  name:=UpperCase(name);
  for g in fileGroups do
   if g.name=name then exit(g);
  result:=TFileGroup.Create;
  result.name:=name;
  result.duck:=1.0;
  SetLength(fileGroups,length(fileGroups)+1);
  fileGroups[high(fileGroups)]:=result;
 end;

// Name[,duck=N][,exclusive=0|1]
procedure SetFileGroup(const params:string8);
 var
  sa:Strings8;
  par:TNameValue;
  g:TFileGroup;
  i:integer;
 begin
  sa:=params.Split(',','"');
  if (length(sa)=0) or (sa[0]='') then exit;
  g:=GetFileGroup(sa[0]);
  for i:=1 to high(sa) do begin
   par.InitFrom(sa[i]);
   if par.Named('duck') then g.duck:=Clamp(par.GetInt/100,0.0,1.0)
   else
   if par.Named('exclusive') then g.exclusive:=par.GetBool
   else
    Log.Warn('[SOUND] SetGroup: unknown parameter '+sa[i]);
  end;
 end;

procedure StopFilePlayback(pb:TFilePlayback);
 begin
  if pb.stopped then exit;
  pb.stopped:=true;
  // the playback is unloaded when the fade-out ends
  if (caVolume in soundLib.CanSlide) or soundLib.CanFadeMusic then
   soundLib.SlideChannel(pb.channel,caVolume,0,FILE_FADE_TIME)
  else
   soundLib.StopChannel(pb.channel);
 end;

// Stop files matching the path (any if empty) and the group (any if nil)
procedure StopFiles(const path:string8;group:TFileGroup);
 var
  pb:TFilePlayback;
 begin
  for pb in filePlaybacks do
   if ((group=nil) or (pb.group=group)) and
      ((path='') or SameText(Files.FixName(path),Files.FixName(pb.path))) then
    StopFilePlayback(pb);
 end;

// Play a file once as a sample, it's unloaded when finished. Returns the backend channel
function StartFile(const path:string8;volume:single;group:TFileGroup):TChannel;
 var
  settings:TPlaySettings;
  media:TMediaFile;
  pb:TFilePlayback;
 begin
  result:=0;
  if path='' then exit;
  settings:=DefaultSettings;
  settings.volume:=volume;
  Log.Msg('[SOUND] Play file '+path);
  media:=soundLib.OpenMediaFile(Files.FixName(path),mlmLoadUnpack);
  if media=nil then exit; // the backend has logged the reason
  if group.exclusive then StopFiles('',group);
  pb:=TFilePlayback.Create;
  pb.path:=path;
  pb.group:=group;
  pb.media:=media;
  pb.channel:=soundLib.PlayMedia(media,settings);
  if pb.channel=0 then begin
   pb.Free;
   exit;
  end;
  SetLength(filePlaybacks,length(filePlaybacks)+1);
  filePlaybacks[high(filePlaybacks)]:=pb;
  result:=pb.channel;
 end;

// Path[,vol=N][,group=Name]
procedure PlayFile(const params:string8);
 var
  sa:Strings8;
  par:TNameValue;
  group:TFileGroup;
  volume:single;
  i:integer;
 begin
  sa:=params.Split(',','"');
  if length(sa)=0 then exit;
  group:=GetFileGroup(DEFAULT_FILE_GROUP);
  volume:=DefaultSettings.volume;
  for i:=1 to high(sa) do begin
   par.InitFrom(sa[i]);
   if par.Named('vol') or par.Named('v') then volume:=par.GetInt/100
   else
   if par.Named('group') then group:=GetFileGroup(par.value)
   else
    Log.Warn('[SOUND] PlayFile: unknown parameter '+sa[i]);
  end;
  StartFile(sa[0],volume,group);
 end;

// Drop finished playbacks (notify about the natural ends) and duck music while files play
procedure UpdateFilePlaybacks;
 var
  i:integer;
  pb:TFilePlayback;
  duck,v:single;
 begin
  duck:=1.0;
  i:=0;
  while i<length(filePlaybacks) do begin
   pb:=filePlaybacks[i];
   if not soundLib.IsPlaying(pb.channel) then begin
    if not pb.stopped then begin
     Log.Msg('[SOUND] File played: '+pb.path);
     Signal('Sound\FilePlayed\'+pb.path);
    end;
    pb.Free;
    filePlaybacks[i]:=filePlaybacks[high(filePlaybacks)];
    SetLength(filePlaybacks,length(filePlaybacks)-1);
    continue;
   end;
   if not pb.stopped and (pb.group.duck<duck) then duck:=pb.group.duck;
   inc(i);
  end;

  if duck<>musicDuck.FinalValue then begin
   Log.Msg('[SOUND] Music ducking: %d%%',[round(duck*100)]);
   if duck<musicDuck.FinalValue then musicDuck.Animate(duck,DUCK_DOWN_TIME)
    else musicDuck.Animate(duck,DUCK_RESTORE_TIME);
  end;
  v:=musicDuck.Value;
  if v=appliedDuck then exit;
  appliedDuck:=v;
  // a fading out track is left alone, a fading in one takes the factor in AnimateMusicVolume
  if (curMusic<>nil) and (curMusic.stopTime=0) and not curMusic.curVolume.IsAnimating then
   soundLib.SetChannelAttribute(curMusic.channel,caVolume,curMusic.volume*v);
 end;

procedure FreeFilePlaybacks;
 var
  pb:TFilePlayback;
  g:TFileGroup;
 begin
  for pb in filePlaybacks do pb.Free;
  filePlaybacks:=nil;
  for g in fileGroups do g.Free;
  fileGroups:=nil;
 end;

// Unload a sample: the events using it load it again when played
procedure UnloadSample(const key:string);
 var
  p:int64;
  media:TMediaFile;
  list:PointerArray;
  i:integer;
 begin
  p:=mediaFilesHash.Get(key);
  if p=-1 then exit;
  media:=TMediaFile(pointer(p));
  mediaFilesHash.Remove(key);
  list:=evtHash.GetValues;
  for i:=0 to high(list) do
   with TSoundEvent(list[i]) do
    if sample=media then begin
     sample:=nil;
     lastChannel:=0;
    end;
  Log.Msg('[SOUND] Unload sample '+key);
  media.Free; // stops its playback
 end;

// Unload the sample of the event, or all samples if no event is given
procedure ClearCache(const eventName:string8);
 var
  evt:TSoundEvent;
  keys:Strings;
  st:string;
 begin
  if eventName<>'' then begin
   evt:=evtHash.Get(eventName);
   if evt<>nil then UnloadSample(UpperCase(evt.fileName));
  end else begin
   keys:=Copy(mediaFilesHash.keys); // the hash changes while unloading
   for st in keys do
    if st<>'' then UnloadSample(st);
  end;
 end;

procedure AnimateMusicVolume(mus:TMusicEntry);
 var
  v:single;
 begin
  v:=mus.curVolume.Value*appliedDuck;
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

procedure SetGlobalVolume(volumeType:TVolumeType;volume:single);
 begin
  case volumeType of
   vtSounds:soundVolume:=volume;
   vtMusic:musicVolume:=volume;
  end;
  soundLib.SetVolume(volumeType,volume);
 end;

procedure EventHandler(event:TEventStr;tag:TTag);
 var
  orig:TEventStr;
 begin
  try
  delete(event,1,6);
  orig:=event; // file paths keep their case
  event:=UpperCase {TODO: use st.ToUpper}(event);

  if event='ANIMATEMUSICVOL' then AnimateMusicVolume(TMusicEntry(tag));

  // File playback
  if event.StartsWith('PLAYFILE\') then begin
   PlayFile(copy(orig,10,length(orig)));
   exit;
  end;
  if event.StartsWith('STOPFILE\') then begin
   StopFiles(copy(orig,10,length(orig)),nil);
   exit;
  end;
  if event.StartsWith('STOPGROUP\') then begin
   StopFiles('',GetFileGroup(copy(event,11,length(event))));
   exit;
  end;
  if event='STOPALLFILES' then begin
   StopFiles('',GetFileGroup(DEFAULT_FILE_GROUP));
   exit;
  end;
  if event.StartsWith('SETGROUP\') then begin
   SetFileGroup(copy(orig,10,length(orig)));
   exit;
  end;
  if event='CLEARCACHE' then begin
   ClearCache('');
   exit;
  end;
  if event.StartsWith('CLEARCACHE\') then begin
   ClearCache(copy(event,12,length(event)));
   exit;
  end;

  // Play sound sample (load if not loaded)
  if event.StartsWith('PLAY\') then begin
   PlaySound(event,tag);
   exit;
  end;

  if event.StartsWith('SETVOLUME\') then begin
   delete(event,1,10);
   if event='SOUND' then SetGlobalVolume(vtSounds,tag/100)
   else
   if event='MUSIC' then SetGlobalVolume(vtMusic,tag/100);
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
   PlayMusicEvent(event,tag);
  end;
  except
   on e:exception do Log.Force('Sound event ('+event+') error: '+ExceptionMsg(e));
  end;
 end;

{ ISoundSystem: voices and commands }

// Index of the voice of a live handle, -1 for an empty or stale one (under soundLock)
function VoiceIndex(handle:TChannel):integer;
 begin
  result:=integer(cardinal(handle) and VOICE_MASK)-1;
  if (result<0) or (result>=MAX_VOICES) then exit(-1);
  if (voices[result].state=vsFree) or
     (voices[result].generation<>cardinal(handle) shr VOICE_BITS) then result:=-1;
 end;

// Take a free voice for a new playback (under soundLock), 0 if all are busy
function AllocVoice:TChannel;
 var
  i:integer;
 begin
  for i:=0 to high(voices) do
   with voices[i] do
    if state=vsFree then begin
     generation:=(generation+1) and GENERATION_MASK;
     state:=vsPending;
     exit(TChannel((generation shl VOICE_BITS) or cardinal(i+1)));
    end;
  result:=0;
 end;

// Sound thread: index of a voice whose playback goes on, -1 if it has ended or not started
function PlayingVoice(handle:TChannel):integer;
 begin
  soundLock.Enter;
  try
   result:=VoiceIndex(handle);
   if (result>=0) and (voices[result].state<>vsPlaying) then result:=-1;
  finally
   soundLock.Leave;
  end;
 end;

// Sound thread: the playback of a voice has started on this backend channel (0 = it failed)
procedure BindVoice(handle,ch:TChannel;vol,panPos:single);
 var
  i:integer;
 begin
  soundLock.Enter;
  try
   i:=VoiceIndex(handle);
   if i<0 then exit;
   with voices[i] do
    if ch=0 then state:=vsFree
    else begin
     state:=vsPlaying;
     channel:=ch;
     baseVolume:=vol;
     sliding:=[];
     volume.Init(1.0);
     pan.Init(panPos);
    end;
  finally
   soundLock.Leave;
  end;
 end;

// Sound thread: drop the voices whose playback has ended, animate the slides the backend can't do
procedure UpdateVoices;
 var
  i:integer;
 begin
  // only this thread turns a voice into vsPlaying and out of it, so reading that needs no lock
  for i:=0 to high(voices) do
   with voices[i] do begin
    if state<>vsPlaying then continue;
    if not soundLib.IsPlaying(channel) then begin
     soundLock.Enter;
     state:=vsFree;
     soundLock.Leave;
     continue;
    end;
    if caVolume in sliding then begin
     soundLib.SetChannelAttribute(channel,caVolume,baseVolume*volume.Value);
     if not volume.IsAnimating then exclude(sliding,caVolume);
    end;
    if caPanning in sliding then begin
     soundLib.SetChannelAttribute(channel,caPanning,pan.Value);
     if not pan.IsAnimating then exclude(sliding,caPanning);
    end;
   end;
 end;

// Sound thread: ISoundSystem.SetChannelVolume/Pan/Speed
procedure SetVoice(const cmd:TSoundCommand);
 var
  i:integer;
  value:single;
 begin
  i:=PlayingVoice(cmd.voice);
  if i<0 then exit;
  with voices[i] do
   if (cmd.b>0) and (cmd.attr in [caVolume,caPanning]) and not (cmd.attr in soundLib.CanSlide) then begin
    // the backend can't slide it: UpdateVoices animates the value
    if cmd.attr=caVolume then volume.Animate(cmd.a,cardinal(round(cmd.b*1000)))
     else pan.Animate(cmd.a,cardinal(round(cmd.b*1000)));
    include(sliding,cmd.attr);
   end else begin
    exclude(sliding,cmd.attr);
    value:=cmd.a;
    if cmd.attr=caVolume then begin
     volume.Assign(cmd.a);
     value:=baseVolume*cmd.a;
    end else
    if cmd.attr=caPanning then pan.Assign(cmd.a);
    if cmd.b>0 then soundLib.SlideChannel(channel,cmd.attr,value,cmd.b)
     else soundLib.SetChannelAttribute(channel,cmd.attr,value);
   end;
 end;

// Sound thread: ISoundSystem.StopChannel
procedure StopVoice(handle:TChannel);
 var
  i:integer;
  ch:TChannel;
  pb:TFilePlayback;
 begin
  i:=PlayingVoice(handle);
  if i<0 then exit;
  ch:=voices[i].channel;
  // a file stops through its playback: with a short fade-out and no Sound\FilePlayed
  for pb in filePlaybacks do
   if pb.channel=ch then begin
    StopFilePlayback(pb);
    exit;
   end;
  soundLib.StopChannel(ch); // it fades out: UpdateVoices frees the voice when it's over
 end;

// Sound thread: run an ISoundSystem call
procedure RunCommand(const cmd:TSoundCommand);
 var
  settings:TPlaySettings;
  ch:TChannel;
  g:TFileGroup;
 begin
  case cmd.kind of
   ckPlay:begin
    ch:=PlayEvent(cmd.name,cmd.a,cmd.b,cmd.c,settings);
    BindVoice(cmd.voice,ch,settings.volume,settings.pan);
   end;
   ckPlayFile:begin
    ch:=StartFile(cmd.name,cmd.a,GetFileGroup(cmd.group));
    BindVoice(cmd.voice,ch,cmd.a,0);
   end;
   ckPlayStream:begin
    ch:=soundLib.PlayStream(cmd.proc,cmd.userData,cmd.channels,cmd.a);
    BindVoice(cmd.voice,ch,cmd.a,0);
   end;
   ckPlayMusic:StartMusic(UpperCase(cmd.name),cmd.a,cmd.b,cmd.c,cmd.pos,cmd.flag);
   ckStopMusic:StartMusic('',cmd.a,0,0,0,false);
   ckStopFile:StopFiles(cmd.name,nil);
   ckStopGroup:StopFiles('',GetFileGroup(cmd.group));
   ckSetGroup:begin
    g:=GetFileGroup(cmd.group);
    g.duck:=Clamp(cmd.a,0.0,1.0);
    g.exclusive:=cmd.flag;
   end;
   ckClearCache:ClearCache(UpperCase(cmd.name));
   ckSetVolume:SetGlobalVolume(cmd.volumeType,cmd.a);
   ckPause:PauseAll(cmd.flag);
   ckSetChannel:SetVoice(cmd);
   ckStopChannel:StopVoice(cmd.voice);
  end;
 end;

// Sound thread: run the queued ISoundSystem calls
procedure RunCommands;
 var
  list:TSoundCommands;
  i:integer;
 begin
  soundLock.Enter;
  list:=commands;
  commands:=nil;
  soundLock.Leave;
  for i:=0 to high(list) do
   try
    RunCommand(list[i]);
   except
    on e:Exception do begin
     Log.Error('[SOUND] command %d failed: %s',[ord(list[i].kind),ExceptionMsg(e)]);
     // the playback it was to start won't come
     if list[i].kind in [ckPlay,ckPlayFile,ckPlayStream] then BindVoice(list[i].voice,0,0,0);
    end;
   end;
 end;

{ TSoundSystem }

function NewCommand(kind:TCommandKind):TSoundCommand;
 begin
  result:=Default(TSoundCommand);
  result.kind:=kind;
 end;

function TSoundSystem.Post(var cmd:TSoundCommand;newVoice:boolean):TChannel;
 begin
  result:=0;
  if not FlagIsSet(initialized) then exit;
  soundLock.Enter;
  try
   if newVoice then begin
    result:=AllocVoice;
    cmd.voice:=result;
   end;
   if not newVoice or (result<>0) then begin
    SetLength(commands,length(commands)+1);
    commands[high(commands)]:=cmd;
   end;
  finally
   soundLock.Leave;
  end;
  if newVoice and (result=0) then
   Log.Warn('[SOUND] %d playbacks at once: no handle for a new one',[MAX_VOICES]);
 end;

procedure TSoundSystem.Init(useLibrary:TSoundLib;windowHandle:THandle;waitForPreload:boolean);
 begin
  if FlagIsSet(initialized) then exit;
  {$IF NOT DEFINED(SDLMIX) AND NOT DEFINED(IMX)}
  // Audio backends are opt-in (see defines.inc). With none of them compiled in
  // the sound system just stays inactive: this is a build-time choice, not a
  // runtime failure, so no exception is raised here.
  if useLibrary=slDefault then begin
   Log.Msg('[SOUND] No sound backend is compiled in, audio is disabled. Build with -dSDLMIX to enable it.');
   exit;
  end;
  {$IFEND}
  if not Files.Exists(soundConfigFile) then begin
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
   soundThread:=nil;
   raise EError.Create('[SOUND] Initialization failed!');
  end;
  soundThread.Priority:=tpHigher;
 end;

procedure TSoundSystem.Done;
 var
  i:integer;
 begin
  if not FlagIsSet(initialized) then exit;
  Atomic.Exchange(initialized,0); // the calls from now on do nothing
  soundThread.Free; // stop & wait
  soundThread:=nil;
  soundLock.Enter;
  commands:=nil;
  for i:=0 to high(voices) do voices[i].state:=vsFree;
  soundLock.Leave;
  Atomic.Exchange(musicPlaying,0);
 end;

procedure TSoundSystem.SetVolume(volumeType:TVolumeType;volume:single);
 var
  cmd:TSoundCommand;
 begin
  if not FlagIsSet(initialized) then begin
   // the sound thread applies it when it starts
   case volumeType of
    vtSounds:soundVolume:=volume;
    vtMusic:musicVolume:=volume;
   end;
   exit;
  end;
  cmd:=NewCommand(ckSetVolume);
  cmd.volumeType:=volumeType;
  cmd.a:=volume;
  Post(cmd);
 end;

procedure TSoundSystem.Pause(pause:boolean);
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckPause);
  cmd.flag:=pause;
  Post(cmd);
 end;

function TSoundSystem.Play(const event:String8;volume,pan,speed:single):TChannel;
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckPlay);
  cmd.name:=event;
  cmd.a:=volume;
  cmd.b:=pan;
  cmd.c:=speed;
  result:=Post(cmd,true);
 end;

procedure TSoundSystem.ClearCache(const event:String8);
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckClearCache);
  cmd.name:=event;
  Post(cmd);
 end;

procedure TSoundSystem.PlayMusic(const name:String8;fadeOut,startAfter,fadeIn:single;fromPos:double;restart:boolean);
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckPlayMusic);
  cmd.name:=name;
  cmd.a:=fadeOut;
  cmd.b:=startAfter;
  cmd.c:=fadeIn;
  cmd.pos:=fromPos;
  cmd.flag:=restart;
  Post(cmd);
 end;

procedure TSoundSystem.StopMusic(fadeOut:single);
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckStopMusic);
  cmd.a:=fadeOut;
  Post(cmd);
 end;

function TSoundSystem.IsMusicPlaying:boolean;
 begin
  result:=FlagIsSet(musicPlaying);
 end;

function TSoundSystem.PlayFile(const path:String8;volume:single;const group:String8):TChannel;
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckPlayFile);
  cmd.name:=path;
  cmd.a:=volume;
  cmd.group:=group;
  result:=Post(cmd,true);
 end;

procedure TSoundSystem.StopFile(const path:String8);
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckStopFile);
  cmd.name:=path;
  Post(cmd);
 end;

procedure TSoundSystem.StopGroup(const group:String8);
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckStopGroup);
  cmd.group:=group;
  Post(cmd);
 end;

procedure TSoundSystem.SetGroup(const group:String8;duck:single;exclusive:boolean);
 var
  cmd:TSoundCommand;
 begin
  cmd:=NewCommand(ckSetGroup);
  cmd.group:=group;
  cmd.a:=duck;
  cmd.flag:=exclusive;
  Post(cmd);
 end;

function TSoundSystem.PlayStream(proc:TSoundStreamProc;userData:pointer;channels:integer;volume:single):TChannel;
 var
  cmd:TSoundCommand;
 begin
  if not Assigned(proc) or (channels<1) then exit(0);
  cmd:=NewCommand(ckPlayStream);
  cmd.proc:=proc;
  cmd.userData:=userData;
  cmd.channels:=channels;
  cmd.a:=volume;
  result:=Post(cmd,true);
 end;

procedure TSoundSystem.SetAttribute(channel:TChannel;attr:TChannelAttribute;value,time:single);
 var
  cmd:TSoundCommand;
 begin
  if channel=0 then exit;
  cmd:=NewCommand(ckSetChannel);
  cmd.voice:=channel;
  cmd.attr:=attr;
  cmd.a:=value;
  cmd.b:=time;
  Post(cmd);
 end;

procedure TSoundSystem.SetChannelVolume(channel:TChannel;volume,time:single);
 begin
  SetAttribute(channel,caVolume,volume,time);
 end;

procedure TSoundSystem.SetChannelPan(channel:TChannel;pan,time:single);
 begin
  SetAttribute(channel,caPanning,pan,time);
 end;

procedure TSoundSystem.SetChannelSpeed(channel:TChannel;speed,time:single);
 begin
  SetAttribute(channel,caSpeed,speed,time);
 end;

procedure TSoundSystem.StopChannel(var channel:TChannel);
 var
  cmd:TSoundCommand;
 begin
  if channel=0 then exit;
  cmd:=NewCommand(ckStopChannel);
  cmd.voice:=channel;
  Post(cmd);
  channel:=0;
 end;

function TSoundSystem.IsPlaying(channel:TChannel):boolean;
 begin
  soundLock.Enter;
  result:=VoiceIndex(channel)>=0;
  soundLock.Leave;
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
  if (mus<>keep) and (mus.channel<>0) then begin
   mus.channel:=0;
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
 if needSlide=0 then settings.volume:=needMusic.volume*appliedDuck
  else settings.volume:=0;
 if needMusic.loop then begin
  settings.loop:=true;
  settings.loopStart:=needMusic.loopPos;
  settings.loopEnd:=0;
 end;
 settings.startPos:=needMusicPlayFrom;
 needMusicPlayFrom:=0;
 curMusic:=needMusic;
 curMusic.channel:=soundLib.PlayMedia(needMusic.media,settings);
 if (curMusic.channel<>0) and soundLib.HasSingleMusicStream then
  DropOtherMusicChannels(curMusic);
 if needSlide>0 then begin
  if caVolume in soundLib.CanSlide then
   soundLib.SlideChannel(curMusic.channel,caVolume,curMusic.volume*appliedDuck,needSlide/1000)
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
  if (mus.channel<>0) and (mus.stopTime>0) and (t>mus.stopTime) then begin
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
  musicDuck.Init(1.0);
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

    RunCommands;
    if (needmusic<>nil) and (CoreTime.Ticks>needMusicStartTime) then PlayNeededMusic;
    StopMusicChannels;
    soundLib.Update;
    UpdateFilePlaybacks;
    UpdateVoices;
    Atomic.Exchange(musicPlaying,ord((curMusic<>nil) and soundLib.IsPlaying(curMusic.channel)));
   except
    on e:exception do Log.Force('[SOUND] Error: '+ExceptionMsg(e));
   end;
   CoreTime.Sleep(5);
  until Terminated;
  // Termination
  FreeFilePlaybacks;
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

initialization
 soundLock.Init('Sound');
 sound:=TSoundSystem.Create;
end.
