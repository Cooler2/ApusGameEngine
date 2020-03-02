// iOS version of sound system
// Copyright (C) Apus Software
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$modeswitch objectivec1}
unit SoundI;
interface

var
 // sound settings
 musicVolume:integer;
 soundVolume:integer;

 debugStr:string;
 avgTime:double;

// Инициализация звуковой системы
procedure Initialize(path:string);
// Завершение работы
procedure Finalize;

// channel handle of current MOD
function GetCurrentModHandle:cardinal;

implementation
uses sysutils,MyServis,ControlFiles2,structs,EventMan,
  classes,console,CrossPlatform,iPhoneAll,AVFoundation;

type
 TSample=class
  fname:string;
  player:AVAudioPlayer;
 end;

 // Звуковое событие
 TSoundEvent=class
  name:string;
  sample:TSample;
  volume,pan:integer;
 end;

 TMusic=class
  name:string;
  player:AVAudioPlayer;
  volume:integer;
  playing:boolean;
  loopPos:integer;
  loopCount:integer;
 end;

 TSoundThread=class(TThread)
  procedure Execute; override;
 end;

var
 initialized:boolean=false;
 failed:boolean;
 thread:TThread;
 ctl:integer;

 EvtHash,SmpHash,MusHash:TStrHash;

 needMusic,curMusic:TMusic;
 needMusicPos:integer;
 needTime:cardinal;
 needSlide:integer;
 curModuleHandle:integer=-1;

 SampleLib:array[1..5] of TMusic;
 sampleLibCnt:integer;

 skip:boolean;
 rootDir:string;
 counter:integer;

procedure LoadSample(s:TSample);
 var
  url:NSURL;
  uname:string;
 begin
  if s=nil then exit;
  if s.player<>nil then exit;
  LogMessage('Loading sample: '+s.fname);
  uname:=UpperCase(s.fname);
  if uname='NONE' then exit;
  if pos('.OGG',uname)>0 then begin
   LogMessage('Unsupported format OGG');
   exit;
  end;
  url:=NSURL.fileURLwithPath(NSStr(PChar(FileName(rootDir+'Audio/'+s.fname))));
  s.player:=AVAudioPlayer.alloc.initWithContentsOfURL_error(url,nil);
  if s.player=nil then raise EWarning.Create('Failed to load sample file: '+s.fname);
  s.player.prepareToPlay;
 end;

procedure SetSoundVolume(vol:integer);
 begin
  {$IFDEF MSWINDOWS}
  IMXSetGlobalVolumes(-1,vol,-1);
  {$ENDIF}
  soundvolume:=vol;
 end;

procedure SetMusicVolume(vol:integer);
 begin
  {$IFDEF MSWINDOWS}
  IMXSetGlobalVolumes(vol,-1,vol);
  {$ENDIF}
  musicvolume:=vol;
  if curMusic<>nil then
   curMusic.player.setVolume(musicVolume*curMusic.volume/10000);
 end;

// Callback для зацикливания потоковой музыки
procedure LoopMusicProc(sync,chan,data,user:cardinal); stdcall;
 var
  item:TMusic;
 begin
  {$IFDEF MSWINDOWS}
  item:=pointer(user);
  if item.loopcount<>0 then
    IMXChannelSetPosition(item.handle,item.loopPos);
  inc(item.loopcount);
  {$ENDIF}
 end;


function EventHandler(event:EventStr;tag:integer):boolean;
 var
  evt:TSoundEvent;
  sa,sa2:stringarr;
  mus:TMusic;
  st:string;
  i,p,downtime,v,freq,pan,newpan,newfreq,slide:integer;
  fl:boolean;
  chan:integer;
 begin
  result:=false;
  LogMessage(event);
  delete(event,1,6);
  event:=UpperCase(event);
  if pos('PLAY\',event)=1 then begin
   delete(event,1,5);

   sa:=split(',',event,'"');
   event:=sa[0];
   pan:=-101;
   if length(sa)>1 then begin
    slide:=0;
    newfreq:=-1; newpan:=-101;
    for i:=1 to length(sa)-1 do begin
     sa2:=split('=',sa[i],#0);
     if length(sa2)<2 then continue;
     if (sa2[0]='PAN') or (sa2[0]='P') then pan:=StrToInt(sa2[1]);
     if (sa2[0]='SLIDE') or (sa2[0]='S') then slide:=StrToInt(sa2[1]);
     if (sa2[0]='NEWPAN') or (sa2[0]='NP') then newpan:=StrToInt(sa2[1]);
     if (sa2[0]='NEWFREQ') or (sa2[0]='NF') then newfreq:=StrToInt(sa2[1]);
    end;
   end;
   evt:=EvtHash.Get(event);
   if evt=nil then begin
    PutMsg('SOUND: sound event not found - '+event);
    exit;
   end;
   LoadSample(evt.sample);

   if evt.sample.player.isPlaying then begin
     evt.sample.player.Stop;
     evt.sample.player.SetCurrentTime(0);
   end;
   if tag and 255<>0 then v:=tag and 255 else v:=evt.volume;
   freq:=(tag shr 8) and $FFFF;
   if tag and $FF000000<>0 then p:=shortint(tag shr 24) else p:=evt.pan;
   if pan<>-101 then p:=pan;
   if pan<>0 then evt.sample.player.setPan(p/100);
   evt.sample.player.setVolume(v*soundVolume/10000);
   evt.sample.player.play;
   if pos('SUMMON',evt.name)>0 then begin
    inc(counter);
    debugStr:=inttostr(counter)+' '+evt.name+' '+inttostr(round(evt.sample.player.volume*100))+
       ' '+inttostr(byte(evt.sample.player.isPlaying));
   end;
   exit;
  end;
  // Preload sample
  if pos('PRELOAD\',event)=1 then begin
   delete(event,1,8);
   evt:=EvtHash.Get(event);
   if evt=nil then begin
    PutMsg('SOUND: sound event not found - '+event);
    exit;
   end;
   LoadSample(evt.sample);
   exit;
  end;

  if pos('SETVOLUME\',event)=1 then begin
   delete(event,1,10);
   if event='SOUND' then SetSoundVolume(tag);
   if event='MUSIC' then SetMusicVolume(tag);
  end;

  if pos('MUSICPOS',event)=1 then begin
   needMusicPos:=tag;
  end;
  if pos('PLAYMUSIC\',event)=1 then begin
   delete(event,1,10);
   case tag of
    0:begin // обычный эффект: музыка гасится, затем запускается новая
       downtime:=1200;
       needslide:=0;
       needtime:=gettickcount+1000;
    end;
    1:begin // музыка гасится быстро, новая запускается почти сразу же
       downtime:=400;
       needslide:=0;
       needtime:=gettickcount+300;
    end;
    2:begin // музыка гасится очень медленно
       downtime:=2500;
       needslide:=0;
       needtime:=gettickcount+3000;
    end;
    3:begin // музыка гасится медленно, новая нарастает плавно - кроссфейдинг
       downtime:=2000;
       needslide:=2000;
       needtime:=gettickcount+800;
    end;
    4:begin // музыка гасится медленно, новая нарастает плавно - без фейдинга
       downtime:=2500;
       needslide:=2000;
       needtime:=gettickcount+2000;
    end;
   end;
   // Гасим все играющие музыки
   fl:=false;
   st:=MusHash.FirstKey;
   while st<>'' do begin
    mus:=MusHash.Get(st);
    if mus.playing then begin
     mus.player.stop;
     mus.playing:=false;
     fl:=true;
    end;
    st:=MusHash.NextKey;
   end;
   if not fl then needtime:=gettickcount;
   LogMessage('PlayMusic: '+event);
   if event<>'NONE' then begin
    mus:=MusHash.Get(event);
    if mus<>nil then needmusic:=mus else
     PutMsg('SOUND: music not found - '+event);
   end;
  end;
 end;

procedure Initialize;
 begin
  rootDir:=path;
  thread:=TSoundThread.Create(false);
  thread.Priority:=tpHigher;
  repeat
   sleep(20);
  until initialized or failed;
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
   params:=Split(',',st,'"');
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
      smpHash.Put(smp.fname,smp);
      evt.sample:=smp;
     end;
    end;
    if param[0]='VOL' then evt.volume:=StrToInt(param[1]);
    if param[0]='PAN' then evt.pan:=StrToInt(param[1]);
   end;
   evtHash.Put(evt.name,evt);
  end;

 procedure AddMusicEntry(name:string);
  var
   item:TMusic;
   fname,lname:string;
   loop,found:boolean;
   looppos:integer;
   i:integer;
   url:NSURL;
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
   // load as stream

   ForceLogMessage('Loading music: '+fname);
   url:=NSURL.fileURLwithPath(NSStr(PChar(FileName(rootDir+'Audio/'+fname))));
   item.player:=AVAudioPlayer.alloc.initWithContentsOfURL_error(url,nil);
   if loop then item.player.setNumberOfLoops(1000);
   item.loopPos:=loopPos;
   item.volume:=ctlGetInt(path+'\volume',75);
   item.player.setVolume(item.volume/100);
   MusHash.Put(item.name,item);
   ForceLogMessage('Music loaded');
  end;

 begin
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
    on e:Exception do raise EError.Create('Error in sound event definition: '+e.message);
   end;
  end;
  // Preload samples
  path:='sounds.ctl:\Settings\';
  st:=UpperCase(ctlGetStr(path+'PreloadSamples'));
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
   // preload listed (filenames)
   sa:=split(',',st,#0);
   for i:=0 to length(sa)-1 do
    LoadSample(smpHash.Get(sa[i]));
  end;

  // Load music settings
  path:='sounds.ctl:\Music';
  st:=ctlGetKeys(path);
  sa:=split(' ',st,#0);
  for i:=0 to length(sa)-1 do
   AddMusicEntry(sa[i]);

 end;

{ TSoundThread }
var
  pool : NSAutoreleasePool;
procedure TSoundThread.Execute;
var
  t:cardinal;
begin
 avgtime:=0;
 pool := NSAutoreleasePool.alloc.init;
 try
 RegisterThread('Sound(E2)');

 ctl:=UseControlFIle(FileName(rootDir+'sounds.ctl'),'');
 LoadConfig;
 SetEventHandler('SOUND',EventHandler,sync);
 needmusic:=nil;
 initialized:=true;
 // Main loop
 repeat
  sleep(10);
  t:=getTickCount;
  PingThread;
  HandleSignals;
  if (needmusic<>nil) and (getTickCount>needtime) then begin
   needMusic.player.setCurrentTime(0);
   needMusic.player.setVolume(needMusic.volume*musicvolume/10000);
   needMusic.player.Play;
   needmusic.playing:=true;
   curMusic:=needMusic;
   needmusic:=nil;
  end;
  t:=getTickCount-t;
  avgtime:=avgtime*0.99+t*0.01;
 until Terminated;
 // Termination

 FreeControlFile(ctl);
 MusHash.Free;
 SmpHash.Free;
 EvtHash.Free;
 except
  on e:Exception do begin
   failed:=true;
   CritMsg('SOUND: '+e.Message);
  end;
 end;
 UnregisterThread;
 pool.release;
end;

function GetCurrentModHandle:cardinal;
begin
 result:=curModuleHandle;
end;

end.
