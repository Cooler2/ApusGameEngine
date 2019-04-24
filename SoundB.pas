// Copyright (C) Apus Software, 2004
// Author: Ivan Polyacov, ivan@apus-software.com
unit SoundB;
interface
type
 TStreamProc=function(buf:pointer;size:integer):integer;
var
 // sound settings
 musicVolume:integer;
 soundVolume:integer;

// Инициализация звуковой системы
procedure Initialize(wndHandle:cardinal);
// Завершение работы
procedure Finalize;

// channel handle of current MOD
function GetCurrentModHandle:cardinal;
function GetStreamHandle(name:string):cardinal;

implementation
uses windows,sysutils,MyServis,bass,ControlFiles2,structs,EventMan,classes,console;

type
 TSample=class
  fname:string;
  handle:integer;
 end;

 // Звуковое событие
 TSoundEvent=class
  name:string;
  sample:TSample;
  volume,pan:integer;
 end;

 TMusic=class
  name:string;
  handle:cardinal;
  volume:integer;
  isModule:boolean;
  playing:boolean;
 end;

 TSoundThread=class(TThread)
  procedure Execute; override;
 end;

var
 initialized:boolean=false;
 failed:boolean;
 thread:TThread;
 hnd:cardinal;
 ctl:integer;

 EvtHash,SmpHash,MusHash:TStrHash;

 needMusic:TMusic;
 needTime:cardinal;
 needSlide:integer;
 curModuleHandle:integer=-1;
 curMusic:TMusic;

 SampleLib:array[1..5] of TMusic;
 sampleLibCnt:integer;

 streams:array[1..10] of TMusic;
 streamcnt:integer;

function GetStreamHandle(name:string):cardinal;
 var
  i:integer;
 begin
  result:=0;
  name:=uppercase(name);
  for i:=1 to streamcnt do
   if (streams[i]<>nil) and (streams[i].name=name) then begin
    result:=streams[i].handle;
    exit;
   end;
 end;

procedure LoadSample(s:TSample);
 begin
  if s=nil then exit;
  if s.handle<>0 then exit;
  Signal('SOUND\SampleLoading\'+s.fname);
  s.handle:=BASS_SampleLoad(false,PChar('AUDIO\'+s.fname),0,0,4,0);
  if s.handle=0 then
   PutMsg('Warning: cannot load sample '+s.fname);
  Signal('SOUND\SampleLoaded\'+s.fname);
 end;

procedure SetSoundVolume(vol:integer);
 begin
  BASS_SetConfig(BASS_CONFIG_GVOL_MUSIC,vol);
  BASS_SetConfig(BASS_CONFIG_GVOL_SAMPLE,vol);
  soundvolume:=vol;
 end;

procedure SetMusicVolume(vol:integer);
 begin
  BASS_SetConfig(BASS_CONFIG_GVOL_MUSIC,vol);
  BASS_SetConfig(BASS_CONFIG_GVOL_STREAM,vol);
  if curMusic<>nil then
   BASS_ChannelSetAttributes(curMusic.handle,-1,curMusic.volume,-1);
  musicvolume:=vol;
 end;

function StreamProc(handle:integer;buf:pointer;size,user:cardinal):cardinal; stdcall;
 var
  sp:TStreamProc;
 begin
  sp:=TStreamProc(user);
  result:=sp(buf,size);
 end;

function EventHandler(event:EventStr;tag:TTag):boolean;
 var
  evt:TSoundEvent;
  mus:TMusic;
  st,name:string;
  downtime,v,p,freq,i,ch,slide,newpan,newfreq,pan:integer;
  fl:boolean;
  hnd:cardinal;
  sa,sa2:StringArr;
 begin
  result:=false;
  delete(event,1,6);
  event:=UpperCase(event);
  if pos('CLEARCACHE\',event)=1 then begin
   delete(event,1,11);
   evt:=EvtHash.Get(event);
   if evt<>nil then begin
    BASS_SampleFree(evt.sample.handle);
    evt.sample.handle:=0;
   end;
  end;

  if pos('PLAYSTREAM\',event)=1 then begin
   delete(event,1,11);
   sa:=split(',',event,'"');
   freq:=44100;
   ch:=1;
   name:='';
   for i:=0 to length(sa)-1 do begin
    st:=sa[i];
    st:=UpperCase(st);
    sa2:=Split('=',st,#0);
    if length(sa2)<2 then continue;
    if sa2[0]='NAME' then name:=sa2[1];
    if sa2[0]='FREQ' then freq:=StrToInt(sa2[1]);
    if sa2[0]='CHAN' then ch:=StrToInt(sa2[1]);
   end;
   hnd:=BASS_StreamCreate(freq,ch,0,@StreamProc,tag);
   inc(streamcnt);
   streams[streamcnt]:=TMusic.Create;
   streams[streamcnt].name:=name;
   streams[streamcnt].handle:=hnd;
   BASS_ChannelPlay(hnd,true);
  end;

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
   if tag and 255<>0 then v:=tag and 255 else v:=evt.volume;
   freq:=(tag shr 8) and $FFFF;
   if tag and $FF000000<>0 then p:=shortint(tag shr 24) else p:=evt.pan;
   if pan<>-101 then p:=pan;
   hnd:=Bass_SampleGetChannel(evt.sample.handle,false);
   BASS_ChannelSetAttributes(hnd,freq,v,p);
   BASS_ChannelPlay(hnd,true);
   if slide>0 then
     BASS_ChannelSlideAttributes(hnd,newfreq,-1,newpan,slide);
  end;

  if pos('SETVOLUME\',event)=1 then begin
   delete(event,1,10);
   if event='SOUND' then SetSoundVolume(tag);
   if event='MUSIC' then SetMusicVolume(tag);
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
     BASS_ChannelSlideAttributes(mus.handle,-1,0,-1,downtime);
 //    IMXChannelSlide(mus.handle,0,-101,0,downtime);
     mus.playing:=false;
     fl:=true;
    end;
    st:=MusHash.NextKey;
   end;
   if not fl then needtime:=gettickcount;
   if event<>'NONE' then begin
    mus:=MusHash.Get(event);
    if mus<>nil then needmusic:=mus else
     PutMsg('SOUND: music not found - '+event);
   end;
  end;
 end;

procedure Initialize(wndHandle:cardinal);
 begin
  hnd:=wndHandle;
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
 procedure AddEvent(st,name:string);
  var
   params,param:stringArr;
   i:integer;
   evt:TSoundEvent;
   smp:TSample;
  begin
   evt:=TSoundEvent.Create;
   evt.name:=name;
   evt.sample:=nil;
   evt.volume:=75;
   evt.pan:=0;
   params:=Split(',',UpperCase(st),'"');
   for i:=0 to length(params)-1 do begin
    param:=Split('=',params[i],#0);
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
   end;
   evtHash.Put(evt.name,evt);
  end;
 procedure AddMusicEntry(name:string);
  var
   item:TMusic;
   fname,lname:string;
   loop,found:boolean;
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
   if UpperCase(ExtractFileExt(fname))='.OGG' then begin
    // load as stream
    item.handle:=BASS_StreamCreateFile(false,PChar('audio\'+fname),0,0,BASS_SAMPLE_LOOP*byte(loop));
    item.isModule:=false;
   end else begin
    // load as module
    BASS_MusicLoad(false,PChar('audio\'+fname),0,0,BASS_SAMPLE_LOOP*byte(loop),0);
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
//      sampleLib[i].handle:=IMXModuleLoad(false,PChar('audio\'+lname),0,0,0);
     end;
//     IMXModuleAttachInstruments(item.handle,samplelib[i].handle);
    end;
   end;
   item.volume:=ctlGetInt(path+'\volume',75);
   MusHash.Put(item.name,item);
  end;
 begin
  EvtHash:=TStrHash.Create;
  SmpHash:=TStrHash.Create;
  MusHash:=TStrHash.Create;
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

  // Load music settings
  path:='sounds.ctl:\Music';
  st:=ctlGetKeys(path);
  sa:=split(' ',st,#0);
  for i:=0 to length(sa)-1 do
   AddMusicEntry(sa[i]);

 end;

{ TSoundThread }
procedure TSoundThread.Execute;
begin
 try
 failed:=false;
 RegisterThread('Sound(E2)');
 // initialization
 BASS_Init(-1,44100,0,hnd,nil);
 Bass_Start;

 ctl:=UseControlFIle('sounds.ctl','');
 LoadConfig;
 SetEventHandler('SOUND',EventHandler,emQueued);
 needmusic:=nil;
 initialized:=true;
 // Main loop
 repeat
  PingThread;
  HandleSignals;
  sleep(20);
  if (needmusic<>nil) and (getTickCount>needtime) then begin
   If needmusic.isModule then begin
    BASS_ChannelPlay(needMusic.handle,true);
    curModuleHandle:=needMusic.handle;
   end else BASS_ChannelPlay(needMusic.handle,true);
   curMusic:=needMusic;

   if needSlide>0 then begin
    BASS_ChannelSetAttributes(needMusic.handle,-1,1,-1);
    BASS_ChannelSlideAttributes(needMusic.handle,-1,needMusic.volume,-1,needSlide)
   end else
    BASS_ChannelSetAttributes(needMusic.handle,-1,needmusic.volume,-1);
   needmusic.playing:=true;
   needmusic:=nil;
  end;
 until Terminated;
 // Termination
 curMusic:=nil;

 Bass_Stop;
 BASS_Free;
// SaveControlFile(ctl);
 FreeControlFile(ctl);
 MusHash.Free;
 SmpHash.Free;
 EvtHash.Free;
 except
  on e:Exception do begin
   failed:=true;
   CritMsg('SOUND: '+ExceptionMsg(e));
  end;
 end;
 UnregisterThread;
end;

function GetCurrentModHandle:cardinal;
begin
 result:=curModuleHandle;
end;

end.
