// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R-}
unit Apus.Engine.Sound;
interface

var
 // global sound settings
 musicVolume:integer=-1; // 0..100
 soundVolume:integer=-1; // 0..100

// Инициализация звуковой системы
procedure Initialize(windowHandle:cardinal; waitForPreload:boolean=true);
// Завершение работы
procedure Finalize;

// channel handle of current MOD
function GetCurrentModHandle:cardinal;

implementation
// Under windows use IMixer Sound System (iMixEx.dll) by Igor Lobanchikov
{$IFDEF MSWINDOWS}{$DEFINE IMX}{$ENDIF}

uses SysUtils, Apus.MyServis, Apus.ControlFiles, Apus.Structs, Apus.EventMan, Classes
  {$IFDEF IMX},Ole2,IMixEx{$ENDIF}
  {$IFDEF ANDROID},Apus.Android,Apus.AndroidSoundPool,Apus.AndroidMediaPlayer{$ENDIF}
  ;

type
 {$IFDEF IMX}
 TChannel=HChannel;
 {$ENDIF}
 {$IFDEF UNIX}
 TChannel=cardinal;
 {$ENDIF}

 TSample=class
  fname:string;
  handle,pool:integer;
 end;

 // Звуковое событие
 TSoundEvent=class
  name:string;
  sample:TSample;
  volume,pan,freq:integer;
  channel:TChannel;
 end;

 // Music entry (audio stream file or module)
 TMusic=class
  name:string;
  handle:cardinal;
  volume:integer; // Required relative volume (100=normal volume), actual volume may be different
  isModule:boolean;
  playing:boolean;
  loopPos:integer;
  loopCount:integer; // Android: -1 - infinite loop, 0 - no loop
  {$IFDEF ANDROID}
  curVolume:TAnimatedValue;
  player:TJNIMediaPlayer;
  {$ENDIF}
 end;

 TSoundThread=class(TThread)
  waitForPreload:boolean;
  procedure Execute; override;
 end;

var
 initialized:boolean=false;
 failed:boolean;
 thread:TSoundThread;
 wndHandle:cardinal=0;
 ctl:integer;

 EvtHash,SmpHash,MusHash:TStrHash;

 // Need to start this music entry with these parameters
 needMusic:TMusic;
 needMusicPos:integer; // Number of sample from start
 needTime:int64;       // Time to start playback
 needSlide:integer;    // Fade-in duration
 curModuleHandle:integer=-1;

 SampleLib:array[1..5] of TMusic;
 sampleLibCnt:integer;

 {$IFDEF ANDROID}
 pools:array[0..20] of TSoundPool;
 {$ENDIF}


function LoadSample(s:TSample):boolean;
 var
  st:string;
  i:integer;
 begin
  result:=false;
  if s=nil then exit;
  if s.handle>0 then exit;
  {$IFDEF IMX}
  s.handle:=IMXSampleLoad(false,PAnsiChar(AnsiString('AUDIO\'+s.fname)));
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
 end;

procedure SetSoundVolume(vol:integer);
 begin
  {$IFDEF IMX}
  IMXSetGlobalVolumes(-1,vol,-1);
  {$ENDIF}
  soundvolume:=vol;
 end;

procedure SetMusicVolume(vol:integer);
 begin
  {$IFDEF IMX}
  IMXSetGlobalVolumes(vol,-1,vol);
  {$ENDIF}
  musicvolume:=vol;
 end;

// Callback для зацикливания потоковой музыки
procedure LoopMusicProc(sync,chan,data,user:cardinal); stdcall;
 var
  item:TMusic;
 begin
  {$IFDEF IMX}
  item:=pointer(user);
  if item.loopcount<>0 then
    IMXChannelSetPosition(item.handle,item.loopPos);
  inc(item.loopcount);
  {$ENDIF}
 end;


procedure EventHandler(event:TEventStr;tag:TTag);
 var
  evt:TSoundEvent;
  sa,sa2:stringarr;
  mus:TMusic;
  st:string;
  i,p,downtime,v,freq,vol,pan,newpan,newfreq,slide:integer;
  fl,volRelative:boolean;
  chan:integer;
  multFreq:single;
  rVol:single;
 begin
  try
  delete(event,1,6);
  event:=UpperCase(event);

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
  end;

  // Unload all loaded audio samples
  if pos('CLEARCACHE\',event)=1 then begin
   delete(event,1,11);
   evt:=EvtHash.Get(event);
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
  end;

  // Play sound sample (load if not loaded)
  if pos('PLAY\',event)=1 then begin
   LogMessage('SOUND: '+event+' '+IntToHex(tag,6));
   if soundvolume=0 then exit;
   delete(event,1,5);

   sa:=split(',',event,'"');
   event:=sa[0];
   pan:=-101;
   slide:=0;
   newfreq:=-1; newpan:=-101;  multFreq:=1;  freq:=0; vol:=-1;
   if length(sa)>1 then begin
    for i:=1 to length(sa)-1 do begin
     sa2:=split('=',sa[i],#0);
     if length(sa2)<2 then continue;
     if (sa2[0]='VOL') or (sa2[0]='V') then begin
      if sa2[1][length(sa2[1])]='%' then begin
       volRelative:=true;
       SetLength(sa2[1],length(sa2[1])-1);
      end else
       volRelative:=false;
      vol:=StrToInt(sa2[1]);
     end;
     if (sa2[0]='PAN') or (sa2[0]='P') then pan:=StrToInt(sa2[1]);
     if (sa2[0]='FREQ') or (sa2[0]='F') then freq:=StrToInt(sa2[1]);
     if (sa2[0]='SLIDE') or (sa2[0]='S') then slide:=StrToInt(sa2[1]);
     if (sa2[0]='NEWPAN') or (sa2[0]='NP') then newpan:=StrToInt(sa2[1]);
     if (sa2[0]='NEWFREQ') or (sa2[0]='NF') then newfreq:=StrToInt(sa2[1]);
//     if (sa2[0]='MULTFREQ') or (sa2[0]='MF') then multfreq:=StrToFloat(sa2[1]);
    end;
   end;
   evt:=EvtHash.Get(event);
   if evt=nil then begin
    LogMessage('SOUND: sound event not found - '+event);
    exit;
   end;
   if evt.sample.handle=0 then
    if not LoadSample(evt.sample) then exit;

   if tag and 255<>0 then v:=tag and 255 else v:=evt.volume;
   if freq=0 then freq:=(tag shr 8) and $FFFF;
   if freq=0 then freq:=evt.freq;
   if tag and $FF000000<>0 then p:=shortint(tag shr 24) else p:=evt.pan;
   if pan<>-101 then p:=pan;

   if vol>=0 then begin
    if volRelative then v:=round(v*vol/100)
     else v:=vol;
   end;

   // Start actual playback
   {$IFDEF IMX}
   chan:=IMXSamplePlay(evt.sample.handle,v,p,freq);
   evt.channel:=chan;
   if slide>0 then
     IMXChannelSlide(chan,-1,newpan,newfreq,slide);
   {$ENDIF}
   {$IFDEF ANDROID}
   evt.channel:=pools[evt.sample.pool].PlaySound(evt.sample.handle,v/100,v/100,1.0,false);
   {$ENDIF}

   exit;
  end;

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
  end;

  if pos('SETVOLUME\',event)=1 then begin
   delete(event,1,10);
   if event='SOUND' then SetSoundVolume(tag);
   if event='MUSIC' then SetMusicVolume(tag);
   exit;
  end;

  if pos('MUSICPOS',event)=1 then begin
   needMusicPos:=tag;
   exit;
  end;

  if (event='PAUSE') or (event='RESUME') then begin
   st:=MusHash.FirstKey;
   while st<>'' do begin
    mus:=MusHash.Get(st);
    if mus.playing then begin
     {$IFDEF ANDROID}
     if event='PAUSE' then begin
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

  if pos('PLAYMUSIC\',event)=1 then begin
   LogMessage('SOUND: '+event);
   delete(event,1,10);
   mus:=nil;
   if event<>'NONE' then
    mus:=MusHash.Get(event);
   // Позиция проигрывания
   needMusicPos:=tag shr 8;
   tag:=tag and $FF;

   if (tag and 128)>0 then
    tag:=tag and $7F
   else begin
    // Может нужный трэк уже играет?
    if (mus<>nil) and mus.playing then exit;
   end;

   case tag of
    0:begin // обычный эффект: музыка гасится, затем запускается новая
       downtime:=1200;
       needslide:=0;
       needtime:=MyTickCount+1000;
    end;
    1:begin // музыка гасится быстро, новая запускается почти сразу же
       downtime:=400;
       needslide:=0;
       needtime:=MyTickCount+300;
    end;
    2:begin // музыка гасится очень медленно
       downtime:=2500;
       needslide:=0;
       needtime:=MyTickCount+3000;
    end;
    3:begin // музыка гасится медленно, новая нарастает плавно - кроссфейдинг
       downtime:=2000;
       needslide:=2000;
       needtime:=MyTickCount+800;
    end;
    4:begin // музыка гасится медленно, новая нарастает плавно - без фейдинга
       downtime:=2500;
       needslide:=2000;
       needtime:=MyTickCount+2000;
    end;
    5:begin // музыка гасится быстро, новая нарастает медленно - кроссфейдинг
       downtime:=500;
       needslide:=2000;
       needtime:=MyTickCount+400;
    end;
    6:begin // музыка гасится быстро, новая нарастает средне - кроссфейдинг
       downtime:=500;
       needslide:=500;
       needtime:=MyTickCount+250;
    end;
   end;
   // Fade-Out all playing music streams
   fl:=false;
   st:=MusHash.FirstKey;
   while st<>'' do begin
    mus:=MusHash.Get(st);
    if mus.playing then begin
     LogMessage('Fading out music '+mus.name+' during '+inttostr(downtime));
     {$IFDEF IMX}
     IMXChannelSlide(mus.handle,0,-101,0,downtime);
     {$ENDIF}
     {$IFDEF ANDROID}
     // Start fade-out
     mus.curVolume.Animate(0,downtime,spline1);
     DelayedSignal('Sound\AnimateMusicVol',10,PtrInt(mus));
     {$ENDIF}
     mus.playing:=false;
     fl:=true;
    end;
    st:=MusHash.NextKey;
   end;
   if not fl then needtime:=MyTickCount;
   if event<>'NONE' then begin
    mus:=MusHash.Get(event);
    if mus<>nil then needmusic:=mus
     else LogMessage('SOUND: music not found - '+event);
   end;
   exit;
  end;
  except
   on e:exception do ForceLogMessage('Sound event ('+event+') error: '+ExceptionMsg(e));
  end;
 end;

procedure Initialize(windowHandle:cardinal;waitForPreload:boolean=true);
 begin
  wndHandle:=wndHandle;
  thread:=TSoundThread.Create(false);
  thread.waitForPreload:=waitForPreload;
  repeat
   sleep(20);
   HandleSignals;
  until initialized or failed;
  if failed then
   raise EError.Create('[SOUND] Initialization failed!');
  thread.Priority:=tpHigher;
 end;

procedure Finalize;
 begin
  if not initialized then exit;
  thread.Terminate;
  thread.WaitFor;
  thread.Free;
 end;

// Загрузка конфигурации
procedure LoadConfig;
 var
  path,st:string;
  sa:stringArr;
  i:integer;
  kt:ctlKeyTypes;
  fl:boolean;

 procedure AddEvent(st,name:string);
  var
   params,param:stringArr;
   i,j:integer;
   evt:TSoundEvent;
   smp:TSample;
  begin
   evt:=TSoundEvent.Create;
   evt.name:=name;
   evt.sample:=nil;
   evt.volume:=75;
   evt.pan:=0;
   evt.freq:=0;
   //DebugMessage('st='+st+'; name='+name);
   params:=Split(',',st,'"');
//   params[0]:=UpperCase(params[0]);
   for i:=0 to length(params)-1 do begin
    param:=Split('=',params[i],#0);
    param[0]:=UpperCase(param[0]);
    if param[0]='FILE' then begin
     // проверить, есть ли такой сэмпл
     // если есть - использовать его, если нет - создать
     evt.sample:=SmpHash.Get(param[1]);
     if evt.sample=nil then begin
      // создать сэмпл
      smp:=TSample.Create;
      smp.fname:=param[1];
      smp.handle:=0;
      smpHash.Put(smp.fname,smp);
      evt.sample:=smp;
     end;
    end;
    if param[0]='VOL' then evt.volume:=StrToInt(param[1]);
    if param[0]='PAN' then evt.pan:=StrToInt(param[1]);
    if param[0]='FREQ' then evt.freq:=StrToInt(param[1]);
   end;
   evtHash.Put(evt.name,evt);
  end;

 procedure AddMusicEntry(name:string);
  var
   item:TMusic;
   fname,lname,fExt:string;
   loop,found:boolean;
   looppos:integer;
   i:integer;
  begin
   path:='sounds.ctl:\Music\'+name;
   name:=UpperCase(name);
   if ctlGetKeyType(path)<>cktSection then exit;
   item:=TMusic.Create;
   item.name:=name;
   item.playing:=false;
   fname:=ctlGetStr(path+'\file');
   loop:=ctlGetBool(path+'\loop',false);
   looppos:=ctlGetInt(path+'\LoopPos',0);
   fExt:=UpperCase(ExtractFileExt(fname));
   if (fExt='.OGG') or (fExt='.MP3') or (fExt='.WAW') then begin
    // load as stream
    {$IFDEF IMX}
    item.handle:=IMXStreamOpenFile(false,PAnsiChar(AnsiString('Audio\'+fname)),0,0,IMX_STREAM_LOOP*byte(loop));
    item.isModule:=false;
    item.loopPos:=loopPos;
    if LoopPos>0 then
     IMXChannelSetSync(item.handle,IMX_SYNC_POS+IMX_SYNC_MIXTIME,1,LoopMusicProc,cardinal(item));
    {$ENDIF}
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
     LogMessage('[Sound] Music loaded: '+fname+' = '+inttostr(item.handle));
    except
     on e:Exception do begin
       LogMessage('[Sound] Music loading failed: '+ExceptionMsg(e));
     end;
    end;
    {$ENDIF}
    if item.handle=0 then
      LogMessage('[Sound] Warning: cannot open stream '+fname);
   end else begin
    // load as module
    {$IFDEF IMX}
    item.handle:=IMXModuleLoad(false,PAnsiChar(AnsiString('Audio\'+fname)),0,0,IMX_MODULE_LOOP*byte(loop));
    if item.handle=0 then
     LogMessage('[Sound] Warning: cannot open module '+fname);
    item.isModule:=true;
    lname:=Uppercase(ctlGetStr(path+'\lib',''));
    if lname<>'' then begin
     found:=false;
     for i:=1 to sampleLibCnt do
      if sampleLib[i].name=lname then begin
       found:=true; break;
      end;
     if not found then begin
      inc(sampleLibCnt); i:=SampleLibCnt;
      sampleLib[i]:=TMusic.Create;
      sampleLib[i].name:=lname;
      sampleLib[i].handle:=IMXModuleLoad(false,PAnsiChar(AnsiString('Audio\'+lname)),0,0,0);
     end;
     IMXModuleAttachInstruments(item.handle,samplelib[i].handle);
    end;
    {$ELSE}
    raise EWarning.Create('[Sound]: Unsupported music file format: '+fname);
    {$ENDIF}
   end;
   item.volume:=ctlGetInt(path+'\volume',75);
   MusHash.Put(item.name,item);
  end;
 begin
  LogMessage('[Sound] Loading config');
  EvtHash:=TStrHash.Create;
  SmpHash:=TStrHash.Create;
  MusHash:=TStrHash.Create;
  path:='sounds.ctl:\Settings\';
{  SetSoundVolume(ctlGetInt(path+'SoundVolume'));
  SetMusicVolume(ctlGetInt(path+'MusicVolume'));}
  path:='sounds.ctl:\SoundEvents';
  st:=ctlGetKeys(path);
  sa:=split(' ',st,#0);
  for i:=0 to length(sa)-1 do begin
   kt:=ctlGetKeyType(path+'\'+sa[i]);
   if kt=cktString then try
    // событие определено в виде строки
    AddEvent('file='+ctlGetStr(path+'\'+sa[i]),UpperCase(sa[i]));
   except
    on e:Exception do raise EError.Create('Error in sound event definition: '+ExceptionMsg(e));
   end;
  end;
  // Preload samples
  path:='sounds.ctl:\Settings\';
  st:=UpperCase(ctlGetStr(path+'PreloadSamples'));
  DebugMessage('[Sound] Preloading mode: '+st);
  if st<>'NONE' then LogMessage('[Sound] Preloading');
  if st='ALL' then begin
   // preload all
   st:=smpHash.FirstKey;
   while st<>'' do begin
    LoadSample(smpHash.Get(st));
    st:=smpHash.NextKey;
   end;
  end else
  if st='NONE' then
  else begin
   // preload listed
   sa:=split(',',st,#0);
   for i:=0 to length(sa)-1 do
    LoadSample(smpHash.Get(sa[i]));
  end;
  if st<>'NONE' then LogMessage('[Sound] samples preloading done');

  // Load music settings
  path:='sounds.ctl:\Music';
  st:=ctlGetKeys(path);
  sa:=split(' ',st,#0);
  for i:=0 to length(sa)-1 do
   AddMusicEntry(sa[i]);

  LogMessage('[Sound] Config loaded');
 end;

procedure PlayNeededMusic;
begin
 {$IFDEF IMX}
 If needmusic.isModule then begin
  IMXModulePlay(needMusic.handle);
  curModuleHandle:=needMusic.handle;
 end else begin
  needmusic.loopCount:=0;
  IMXStreamPlay(needMusic.handle);
  if NeedMusicPos<>0 then begin
   IMXChannelSetPosition(needMusic.handle,needMusicPos);
   needMusicPos:=0;
  end;
 end;
 if needSlide>0 then begin
  IMXChannelSetAttributes(needmusic.handle,1,-101,-1);
  IMXChannelSlide(needMusic.handle,needMusic.volume,-101,0,needSlide);
 end else
  IMXChannelSetAttributes(needmusic.handle,needmusic.volume,-101,-1);
 needmusic.playing:=true;
 {$ENDIF}
 {$IFDEF ANDROID}
 if needMusic.handle<>0 then begin
  needMusic.player.Start;
  needMusic.curVolume.Assign(0);
  needMusic.curVolume.Animate(needMusic.volume,needSlide,spline2rev);
  DelayedSignal('Sound\AnimateMusicVol',10,PtrInt(needMusic));
 end;
 {$ENDIF}
 LogMessage(Format('Starting music: %s within %d',[needMusic.name,needSlide]));
 needmusic:=nil;
end;

{ TSoundThread }
procedure TSoundThread.Execute;
begin
 try
 RegisterThread('Sound(E3)');
 // initialization
 {$IFDEF IMX}
 if not ImxInit(wndHandle,44100,0,-1) then
   raise EError.Create('IMX initialization failed');
 if not ImxStart then
   raise EError.Create('IMX can''t start');
 {$ENDIF}
 {$IFDEF ANDROID}
 pools[0]:=TSoundPool.Create; // Also registers current thread
 {$ENDIF}

 ctl:=UseControlFile('sounds.ctl','');
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
  sleep(10);
  if (needmusic<>nil) and (MyTickCount>needtime) then PlayNeededMusic;
  except
   on e:exception do ForceLogMessage('Error in sound: '+ExceptionMsg(e));
  end;
 until Terminated;
 // Termination

 {$IFDEF IMX}
 IMXStop;
 IMXUninit;
 {$ENDIF}

 FreeControlFile(ctl);
 MusHash.Free;
 SmpHash.Free;
 EvtHash.Free;
 except
  on e:Exception do begin
   failed:=true;
   ForceLogMessage('[SOUND] '+ExceptionMsg(e))
  end;
 end;
 UnregisterThread;
end;

function GetCurrentModHandle:cardinal;
begin
 result:=curModuleHandle;
end;

end.
