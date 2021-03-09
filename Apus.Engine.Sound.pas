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
unit Apus.Engine.Sound;
interface
uses Apus.MyServis, Apus.AnimatedValues;
var
 soundFolderPath:string = 'Audio\';
 soundConfigFile:string = 'sounds.ctl';

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
  procedure StopChannel(var channel:TChannel); // frees and set to nil channel if success
  procedure SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
  // Which channel attributes can be slided
  function CanSlide:TChannelAttributes;
  // If full volume slide not supported: can it fade in/out music?
  function CanFadeMusic:boolean;
  // timeInterval - in seconds
  procedure SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue:single;timeInterval:single);
  procedure Done;
 end;

// Инициализация звуковой системы
procedure InitSoundSystem(useLibrary:TSoundLib; windowHandle:cardinal=0; waitForPreload:boolean=true);
// Завершение работы
procedure DoneSoundSystem;


implementation

uses SysUtils, Apus.ControlFiles, Apus.Structs, Apus.EventMan, Classes
  {$IFDEF IMX},Apus.Engine.SoundImx{$ENDIF}
  {$IFDEF SDLMIX},Apus.Engine.SoundSDL{$ENDIF}
  {$IFDEF ANDROID},Apus.Android,Apus.AndroidSoundPool,Apus.AndroidMediaPlayer{$ENDIF}
  ;

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
  loopCount:integer; // Android: -1 - infinite loop, 0 - no loop
  curVolume:TAnimatedValue;
  {$IFDEF ANDROID}
  player:TJNIMediaPlayer;
  {$ENDIF}
 end;

 // Thread processing sound events
 TSoundThread=class(TThread)
  waitForPreload:boolean;
  procedure Execute; override;
 end;

var
 soundLib:ISoundLib;
 initialized:boolean=false; // ready to process events
 failed:boolean;
 thread:TSoundThread;
 wndHandle:THandle=0;
 ctl:integer;

 evtHash:TStrHash; // event -> TSoundEvent
 musHash:TStrHash; // event -> TMusicEntry
 mediaFilesHash:TSimpleHashS; // filename (uppercase) -> TMediaFile

 // Need to start this music entry with these parameters
 needMusic:TMusicEntry;
 needMusicPlayFrom:double; // position to play from (sec)
 needMusicStartTime:int64;       // Time to start playback
 needSlide:integer;    // Fade-in duration
 curMusic:TMusicEntry;

 sampleLib:array[1..5] of TMusicEntry;
 sampleLibCnt:integer;

 // Global volume levels (multiply by particular volume)
 soundVolume:single=1.0;
 musicVolume:single=1.0;

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
  begin
   data.Seek(2);

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
  if (c and $FFF=$FFF) or (c=$03334449) then ParseMP3;
 end;

procedure TMediaFile.DetectParams(fName: string);
 var
  data:ByteArray;
 begin
  data:=LoadFileAsBytes(fName,2000);
  DetectParams(TBuffer.CreateFrom(data));
 end;

// Load media file and put it's reference to the mediaFilesHash
function LoadMediaAsSample(fName:string):TMediaFile;
 var
  st:string;
 begin
  st:=FileName(soundFolderPath+fName);
  LogMessage('[SOUND] Load sample from '+st);
  result:=soundLib.OpenMediaFile(st,mlmLoadUnpack);
  if result<>nil then
   mediaFilesHash.Put(UpperCase(fName),UIntPtr(result));
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
   p:=mediaFilesHash.Get(fileName);
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
  {$IFDEF ANDROID}
  try
   s.handle:=0;
//   st:=Lowercase(s.fname);
   st:=s.fname;
   for i:=0 to high(pools) do begin
    if pools[i]=nil then pools[i]:=TSoundPool.Create;
    if pools[i].count<8 then begin
     DebugMessage('[SOUND] Loading '+st+' to pool '+inttostr(i));
     s.handle:=pools[i].LoadSoundFile('Audio/'+st);
     s.pool:=i;
     break;
    end;
   end;
  except
   on e:exception do LogMessage('[Sound] '+ExceptionMsg(e));
  end;
  {$ENDIF}

  if s.handle=0 then
   LogMessage('[Sound] Warning: cannot load sample '+s.fname)
  else begin
   result:=true;
   LogMessage('[Sound] Sample loaded: '+s.fname+' = '+inttostr(s.handle))
  end;
 end;  *)

// Загрузка конфигурации
procedure LoadConfig;
 var
  ctlRoot:string;
  path,st:string;
  sa:stringArr;
  fl:boolean;

 procedure AddEvent(st,name:string);
  var
   params,param:stringArr;
   i,j:integer;
   evt:TSoundEvent;
  begin
   evt:=TSoundEvent.Create(name);
   params:=Split(',',st,'"');
   for i:=0 to length(params)-1 do begin
    param:=Split('=',params[i],#0);
    param[0]:=UpperCase(param[0]);
    if param[0]='FILE' then begin
     evt.fileName:=param[1];
     // проверить, есть ли уже такой медиафайл
     if mediaFilesHash.HasValue(evt.fileName) then
      evt.sample:=pointer(mediaFilesHash.Get(evt.fileName));
    end;
    if param[0]='VOL' then evt.volume:=StrToInt(param[1])/100;
    if param[0]='PAN' then evt.pan:=StrToInt(param[1])/100;
    if param[0]='FREQ' then evt.speed:=StrToInt(param[1])/44100;
    if param[0]='SPEED' then evt.speed:=ParseFloat(param[1]);
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
   name:=UpperCase(name);
   if ctlGetKeyType(path)<>cktSection then exit;
   item:=TMusicEntry.Create;
   item.name:=name;
   fname:=ctlGetStr(path+'\file');
   loop:=ctlGetBool(path+'\loop',false);
   looppos:=ctlGetInt(path+'\loopPos',0);
   fExt:=UpperCase(ExtractFileExt(fname));
   if (fExt='.OGG') or (fExt='.MP3') or (fExt='.WAW') then begin
    {$IFDEF ANDROID}
    // Copy file to data folder
    fname:=CopyAssetFile('Audio/'+lowercase(fname));
    try
     item.player:=TJNIMediaPlayer.Create;
     item.player.SetDataSource(fname,loop);
     item.handle:=UIntPtr(item.player);
     item.isModule:=false;
     item.loopPos:=0;
     if loop then item.loopCount:=-1
      else item.loopCount:=0;
     item.curVolume.Init;
     LogMessage('[SOUND] Music loaded: %s = %d '[fname,item.handle]);
    except
     on e:Exception do begin
       LogMessage('[SOUND] Music loading failed: '+ExceptionMsg(e));
     end;
    end;
    {$ENDIF}

    // Load as stream
    item.media:=soundLib.OpenMediaFile(FileName(soundFolderPath+fname),mlmJustOpen);
    item.isModule:=false;
   end else
   if (fExt='.MOD') or (fExt='.S3M') or (fExt='.XM') then begin
    // load as module
    item.media:=soundLib.OpenMediaFile(FileName(soundFolderPath+fname),mlmLoad);
    item.isModule:=true;
   end;
   if item.media=nil then begin
     ForceLogMessage('[SOUND] Failed to load music file '+fName);
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
   sa:=split(' ',st);
   path:=path+'\';
   for i:=0 to length(sa)-1 do begin
    kt:=ctlGetKeyType(path+sa[i]);
    if kt=cktString then try
     // событие определено в виде строки
     AddEvent('file='+ctlGetStr(path+sa[i]),UpperCase(sa[i]));
    except
     on e:Exception do raise EError.Create('Error in sound event definition: '+ExceptionMsg(e));
    end;
   end;
  end;

 procedure PreloadSamples;
  var
   evt:TSoundEvent;
   i:integer;
   st,fName:string;
   list:PointerArray;
  begin
   path:=ctlRoot+'Settings\';
   st:=UpperCase(ctlGetStr(path+'PreloadSamples'));
   DebugMessage('[SOUND] Preloading mode: '+st);
   if st<>'NONE' then LogMessage('[SOUND] Preloading');
   if st='ALL' then begin
    // preload all
    list:=evtHash.GetValues;
    for i:=0 to high(list) do
     TSoundEvent(list[i]).Preload;
   end else
   if st='NONE' then
   else begin
    // preload listed
    sa:=split(',',st,#0);
    for fName in sa do LoadMediaAsSample(fName);
   end;
   if st<>'NONE' then LogMessage('[SOUND] samples preloading done');
  end;

 procedure LoadMusicEntries;
  var
   i:integer;
  begin
   // Load music entries
   path:=ctlRoot+'Music';
   st:=ctlGetKeys(path);
   sa:=split(' ',st,#0);
   for i:=0 to length(sa)-1 do
    AddMusicEntry(sa[i]);
  end;

 begin
  LogMessage('[SOUND] Loading config');
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
   LogMessage('[SOUND] Config loaded');
  except
   on e:Exception do begin
    ForceLogMessage('[SOUND] config loading error: '+ExceptionMsg(e));
    failed:=true;
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

procedure PlaySound(event:string;tag:TTag);
 var
  sa:StringArr;
  evt:TSoundEvent;
  settings:TPlaySettings;
  par:TNameValue;
  slide:integer;
  newVolume,newSpeed,newPan:single;
  i,p:integer;
  volRelative:boolean;
  ptr:int64;
 begin
   LogMessage('[SOUND] '+event+' '+IntToHex(tag,6));
   if soundvolume=0 then exit;
   delete(event,1,5);
   sa:=split(',',event,'"');
   event:=sa[0];
   // Get sample object
   evt:=EvtHash.Get(event);
   if evt=nil then begin
     LogMessage('[SOUND] Event not found: '+event);
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
   // 2. Override
   for i:=1 to high(sa) do begin
     par.Init(sa[i]);
     if par.Named('vol') or par.named('v') then begin
      if par.value.EndsWith('%') then
       settings.volume:=settings.volume*par.GetInt/100
      else
       settings.volume:=par.GetInt/100;
     end else
     if par.Named('pan') or par.Named('p') then settings.pan:=par.GetInt/100
     else
     if par.Named('freq') or par.Named('f') then settings.speed:=par.GetInt/evt.sample.sampleRate
     else
     if par.Named('speed') or par.Named('r') then settings.speed:=par.GetFloat
     else
     if par.Named('slide') or par.Named('s') then slide:=par.GetInt
     else
     if par.Named('newvol') or par.Named('nv') then newVolume:=par.GetInt/100
     else
     if par.Named('newpan') or par.Named('np') then newpan:=par.GetInt/100
     else
     if par.Named('newfreq') or par.Named('nf') then newSpeed:=par.GetInt/evt.sample.sampleRate;
   end;


   // Low byte of tag overrides volume (in %)
   p:=tag and 255;
   if p<>0 then settings.volume:=settings.volume*p;

   // 8..23 bits of tag = override sample frequency (if >250) or speed (1..250 in %)
   p:=(tag shr 8) and $FFFF;
   if p>0 then begin
    if p>250 then settings.speed:=p/evt.sample.sampleRate
     else settings.speed:=p/100;
   end;
   p:=shortint(tag shr 24);
   if p<>0 then settings.pan:=Clamp(p*100,-100,100);

   evt.lastChannel:=soundLib.PlayMedia(evt.sample, settings);
   if slide>0 then begin
    if newVolume<>settings.volume then
     soundLib.SlideChannel(evt.lastChannel,caVolume,newVolume,slide/1000);
    if newSpeed<>settings.speed then
     soundLib.SlideChannel(evt.lastChannel,caSpeed,newSpeed,slide/1000);
    if newPan<>settings.pan then
     soundLib.SlideChannel(evt.lastChannel,caPanning,newPan,slide/1000);
   end;

  {$IFDEF ANDROID}
  evt.channel:=pools[evt.sample.pool].PlaySound(evt.sample.handle,v/100,v/100,1.0,false);
  {$ENDIF}
 end;

procedure PlayMusic(event:TEventStr;tag:TTag);
 var
  mus:TMusicEntry;
  downtime:integer;
  i:integer;
 begin
   mus:=nil;
   if event<>'NONE' then
    mus:=MusHash.Get(event);
   // Позиция проигрывания
   needMusicPlayFrom:=(tag shr 8)/100000;
   tag:=tag and $FF;
   if (tag and 128)>0 then
    tag:=tag and $7F
   else begin
    // Может нужный трэк уже играет?
    if (mus<>nil) and (curMusic=mus) then exit;
   end;

   case tag of
    0:begin // обычный эффект: музыка гасится, затем запускается новая
       downtime:=1200;
       needslide:=0;
       needMusicStartTime:=MyTickCount+1000;
    end;
    1:begin // музыка гасится быстро, новая запускается почти сразу же
       downtime:=400;
       needslide:=0;
       needMusicStartTime:=MyTickCount+300;
    end;
    2:begin // музыка гасится очень медленно
       downtime:=2500;
       needslide:=0;
       needMusicStartTime:=MyTickCount+3000;
    end;
    3:begin // музыка гасится медленно, новая нарастает плавно - кроссфейдинг
       downtime:=2000;
       needslide:=2000;
       needMusicStartTime:=MyTickCount+800;
    end;
    4:begin // музыка гасится медленно, новая нарастает плавно - без фейдинга
       downtime:=2500;
       needslide:=2000;
       needMusicStartTime:=MyTickCount+2000;
    end;
    5:begin // музыка гасится быстро, новая нарастает медленно - кроссфейдинг
       downtime:=500;
       needslide:=2000;
       needMusicStartTime:=MyTickCount+400;
    end;
    6:begin // музыка гасится быстро, новая нарастает средне - кроссфейдинг
       downtime:=500;
       needslide:=500;
       needMusicStartTime:=MyTickCount+250;
    end;
   end;
   // Fade-Out all playing music streams
   if curMusic<>nil then begin
     if downTime>0 then begin
      LogMessage('[SOUND] Fading out current music during '+inttostr(downtime));
      if (caVolume in soundLib.CanSlide) or (soundLib.CanFadeMusic) then
       soundLib.SlideChannel(curMusic.channel,caVolume,0,downTime/1000)
      else begin
       curMusic.curVolume.Init(curMusic.volume);
      end;
      curMusic.stopTime:=MyTickCount+downTime;
     end else begin
      LogMessage('[SOUND] Stop current music immediately');
      soundLib.StopChannel(curMusic.channel);
      curMusic:=nil;
     end;
   end else
    needMusicStartTime:=MyTickCount;

   if event<>'NONE' then begin
    mus:=MusHash.Get(event);
    if mus<>nil then needMusic:=mus
     else LogMessage('[SOUND] Music not found: '+event);
   end;
 end;

 procedure PauseMusic(pause:boolean);
  var
   mus:TMusicEntry;
   st:string;
  begin
   st:=MusHash.FirstKey;
   while st<>'' do begin
    mus:=MusHash.Get(st);
    if mus.channel<>nil then begin
     {$IFDEF ANDROID}
     if pause then begin
      LogMessage('Pause music track '+mus.name);
      mus.player.Pause;
     end else begin
      LogMessage('Resume music track '+mus.name);
      mus.player.Resume;
     end;
     {$ENDIF}
    end;
    st:=MusHash.NextKey;
   end;
  end;

procedure EventHandler(event:TEventStr;tag:TTag);
 var
  sa,sa2:stringarr;
  st:string;
  i,p,v,freq,vol,pan,newpan,newfreq,slide:integer;
  fl,volRelative:boolean;
  chan:integer;
  multFreq:single;
  rVol:single;
 begin
  try
  delete(event,1,6);
  event:=UpperCase(event);

(* TODO
  if event='ANIMATEMUSICVOL' then begin
   mus:=pointer(cardinal(tag));
   if not (mus is TMusic) then exit;
   {$IFDEF ANDROID}
   rVol:=mus.curVolume.Value/100;
   mus.player.SetVolume(rVol,rVol);
   if mus.curVolume.IsAnimating then
     DelayedSignal(event,10,tag);
   {$ENDIF}
   exit;
  end;  *)

(* TODO
  // Unload all loaded audio samples
  if pos('CLEARCACHE\',event)=1 then begin
   delete(event,1,11);
   evt:=evtHash.Get(event);
   if evt<>nil then begin

    {$IFDEF IMX}
    IMXSampleUnload(evt.sample.handle);
    {$ENDIF}
    {$IFDEF ANDROID}
    pools[evt.sample.pool].UnloadSound(evt.sample.handle);
    {$ENDIF}
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

   sa:=split(',',event,'"');
   event:=sa[0];
   pan:=-101;
   v:=-1;
   slide:=1;
   if length(sa)>1 then begin
    newfreq:=-1; newpan:=-101;
    for i:=1 to length(sa)-1 do begin
     sa2:=split('=',sa[i],#0);
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
    LogMessage('SOUND: sound event not found - '+event);
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
   PauseMusic(event.StartsWith('PAUSE'));

  if pos('PLAYMUSIC\',event)=1 then begin
   LogMessage('[SOUND] '+event);
   delete(event,1,10);
   PlayMusic(event,tag);
  end;
  except
   on e:exception do ForceLogMessage('Sound event ('+event+') error: '+ExceptionMsg(e));
  end;
 end;

procedure InitSoundSystem(useLibrary:TSoundLib; windowHandle:cardinal=0; waitForPreload:boolean=true);
 begin
  wndHandle:=windowHandle;
  if useLibrary=slDefault then begin
   {$IFDEF WIN32}
   useLibrary:=slIMixer;
   {$ELSE}
   useLibrary:=slSDL;
   {$ENDIF}
  end;
  case useLibrary of
   slIMixer:{$IFDEF IMX}soundLib:=TSoundLibImx.Create; {$ELSE} raise EError.Create('Define IMX'); {$ENDIF}
   slSDL:{$IFDEF SDLMIX}soundLib:=TSoundLibSDL.Create; {$ELSE} raise EError.Create('Define SDLMIX'); {$ENDIF}
  end;
  thread:=TSoundThread.Create(false);
  thread.waitForPreload:=waitForPreload;
  repeat
   sleep(10);
   HandleSignals;
  until initialized or failed;
  if failed then begin
   thread.Free;
   raise EError.Create('[SOUND] Initialization failed!');
  end;
  thread.Priority:=tpHigher;
 end;

procedure DoneSoundSystem;
 begin
  if not initialized then exit;
  thread.Free; // stop & wait
 end;

procedure PlayNeededMusic;
var
 settings:TPlaySettings;
 chan:TChannel;
begin
 if needMusic=nil then exit;
 needMusic.stopTime:=0;
 settings:=DefaultSettings;
 if needSlide=0 then settings.volume:=needMusic.volume
  else settings.volume:=0;
 if needMusic.loopCount>0 then begin
  settings.loop:=true;
  settings.loopStart:=needMusic.loopPos;
  settings.loopEnd:=0;
 end;
 curMusic:=needMusic;
 curMusic.channel:=soundLib.PlayMedia(needMusic.media,settings);
 if needSlide>0 then begin
  soundLib.SlideChannel(curMusic.channel,caVolume,needMusic.volume,needSlide/1000);
 end;
 needmusic:=nil;
end;

procedure StopMusicChannels;
var
 keys:StringArr;
 st:string;
 mus:TMusicEntry;
 t:int64;
begin
 t:=MyTickCount;
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
  RegisterThread('Sound(E3)');
  // initialization
  soundLib.Init(wndHandle);
  soundLib.SetVolume(vtSounds,soundVolume);
  soundLib.SetVolume(vtMusic,musicVolume);

  {$IFDEF ANDROID}
  pools[0]:=TSoundPool.Create; // Also registers current thread
  {$ENDIF}

  ctl:=UseControlFile(soundConfigFile,'');
  SetEventHandler('SOUND',EventHandler,emQueued);
  if not waitForPreload then initialized:=true;
  LoadConfig;
  needmusic:=nil;
  initialized:=true;
  // Main loop
  repeat
   try
    PingThread;
    HandleSignals;
    sleep(5);
    if (needmusic<>nil) and (MyTickCount>needMusicStartTime) then PlayNeededMusic;
    StopMusicChannels;
   except
    on e:exception do ForceLogMessage('[SOUND] Error: '+ExceptionMsg(e));
   end;
  until Terminated;
  // Termination

  soundLib.Done;

  FreeControlFile(ctl);
  MusHash.Free;
  EvtHash.Free;
 except
  on e:Exception do begin
   failed:=true;
   ForceLogMessage('[SOUND] '+ExceptionMsg(e))
  end;
 end;
 UnregisterThread;
end;


end.
