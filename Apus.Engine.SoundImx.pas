// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.SoundImx;
interface
 uses Apus.Engine.Sound;

type
 TSoundLibImx=class(TInterfacedObject,ISoundLib)
  procedure Init(windowHandle:THandle=0);
  procedure SetVolume(volumeType:TVolumeType;volume:single); // 0..1
  function OpenMediaFile(fname:string;mode:TMediaLoadingMode):TMediaFile;
  function PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
  procedure StopChannel(var channel:TChannel);
  procedure SetChannelAttribute(channel:TChannel;attr:TChannelAttribute;value:single);
  function CanSlide:TChannelAttributes;
  function CanFadeMusic:boolean;
  procedure SlideChannel(channel:TChannel;attr:TChannelAttribute;newValue:single;timeInterval:single);
  procedure Done;
 end;

implementation
 uses Apus.MyServis,SysUtils,IMixEx,Windows;

type
 TMediaType=(mtSample,mtStream,mtModule);
 TIMXHandle=DWORD;

 TMediaFileImx=class(TMediaFile)
  handle:TIMXHandle;
  mType:TMediaType;
  mData:ByteArray;
  constructor Create(h:HSample;mediaType:TMediaType;data:ByteArray);
  destructor Destroy;
 end;

 TChannelImx=class(TChannel)
  handle:HChannel;
  sampleRate:integer;
  constructor Create(h:HChannel;sampleRate:integer=0);
 end;
 TChannelImxStream=class(TChannelImx)
 end;
 TChannelImxModule=class(TChannelImx)
 end;

 constructor TChannelImx.Create(h:HChannel;sampleRate:integer=0);
  begin
   handle:=h;
   self.sampleRate:=sampleRate;
  end;

{ TSoundLibImx }

procedure TSoundLibImx.Init(windowHandle:THandle);
 begin
  try
   LogMessage('Init ImxEx sound system');
   if not ImxInit(windowHandle,44100,0,-1) then
     raise EError.Create('IMX initialization failed');
   if not ImxStart then
     raise EError.Create('IMX can''t start');
  except
   on e:exception do begin
    ForceLogMessage('Imx Init error: '+ExceptionMsg(e));
    raise EError.Create('IMX Init Error: '+ExceptionMsg(e));
   end;
  end;
 end;

function TSoundLibImx.CanSlide:TChannelAttributes;
 begin
  result:=[caVolume,caPanning,caSpeed];
 end;

function TSoundLibImx.CanFadeMusic:boolean;
 begin
  result:=true;
 end;


procedure TSoundLibImx.Done;
 begin
  IMXStop;
  IMXUninit;
 end;

function TSoundLibImx.OpenMediaFile(fname:string; mode:TMediaLoadingMode):TMediaFile;
 var
  h:TIMXHandle;
  mt:TMediaType;
  ext:string;
  data:ByteArray;
  st:String8;
 begin
  mt:=mtSample;
  ext:=ExtractFileExt(fname);
  if mode in [mlmJustOpen,mlmLoad] then mt:=mtStream;
  if SameText(ext,'.mod') or SameText(ext,'.s3m') or SameText(ext,'.xm') then mt:=mtModule;

  result:=TMediaFileImx.Create(h,mt,data);
  result.source:=fName;
  if mt in [mtSample,mtStream] then begin
   result.DetectParams(fName);
  end;
  st:=fName;
  case mt of
   mtSample: begin
     h:=IMXSampleLoad(false,PAnsiChar(st));
   end;
   mtModule: h:=IMXModuleLoad(false,PAnsiChar(st));
   mtStream: if mode=mlmJustOpen then begin
      h:=IMXStreamOpenFile(false,PAnsiChar(st),0,0,IMX_STREAM_LOOP)
    end
    else begin
      data:=LoadFileAsBytes(fname);
      h:=IMXStreamOpenFile(true,PAnsiChar(@data[0]),0,length(data),IMX_STREAM_LOOP);
    end;
  end;
  with result as TMediaFileImx do begin
   if h=0 then begin
    LogMessage('IMX: Failed to load media file: '+fName);
    FreeAndNil(result);
    exit;
   end;
   handle:=h;
  end;
 end;

function TSoundLibImx.PlayMedia(media:TMediaFile;const settings:TPlaySettings):TChannel;
 var
  chan:HChannel;
 begin
  ASSERT(media<>nil);
  chan:=0;
  with media as TMediaFileImx do begin
   case mType of
    mtSample:begin
      chan:=IMXSamplePlay(handle,round(settings.volume*100),
        round(settings.pan*100),round(settings.speed*sampleRate));
      if chan=0 then begin
       LogMessage('IMX: Failed to play sample: '+media.source);
       exit;
      end;
      result:=TChannelImx.Create(chan);
     end;
    mtStream:if not ImxStreamPlay(handle) then
       LogMessage('IMX: failed to play stream '+media.source)
      else begin
       IMXChannelSetAttributes(handle,Clamp(round(settings.volume*100),0,200),-101,-1);
       result:=TChannelImxStream.Create(handle);
      end;
    mtModule:if not IMXModulePlay(handle) then
       LogMessage('IMX: failed to play module '+media.source)
      else begin
       IMXChannelSetAttributes(handle,Clamp(round(settings.volume*100),0,200),-101,-1);
       result:=TChannelImxModule.Create(handle);
      end;
   end;
  end;
 end;

procedure TSoundLibImx.SetVolume(volumeType:TVolumeType; volume:single);
 begin
  case volumeType of
   vtSounds:IMXSetGlobalVolumes(-1,round(volume*100),-1);
   vtMusic:IMXSetGlobalVolumes(round(volume*100),-1,round(volume*100));
  end;
 end;

procedure TSoundLibImx.SetChannelAttribute(channel:TChannel; attr:TChannelAttribute; value:single);
 var
  newPan,newVol,newFreq:integer;
 begin
  ASSERT(channel is TChannelImx);
  newVol:=-1;
  newPan:=-101;
  newFreq:=0;
  case attr of
   caVolume:newVol:=Clamp(round(value*100),0,200);
   caPanning:newPan:=Clamp(round(value*100),-100,100);
   caSpeed:newFreq:=round(value*TChannelImx(channel).sampleRate);
  end;
  IMXChannelSetAttributes(TChannelImx(channel).handle,newVol,newPan,newFreq);
 end;

procedure TSoundLibImx.SlideChannel(channel:TChannel; attr:TChannelAttribute; newValue,timeInterval:single);
 var
  newPan,newVol,newFreq:integer;
 begin
  ASSERT(channel is TChannelImx);
  newVol:=-1;
  newPan:=-101;
  newFreq:=0;
  case attr of
   caVolume:newVol:=Clamp(round(newValue*100),0,200);
   caPanning:newPan:=Clamp(round(newValue*100),-100,100);
   caSpeed:newFreq:=round(newValue*TChannelImx(channel).sampleRate);
  end;
  IMXChannelSlide(TChannelImx(channel).handle,newVol,newpan,newfreq,round(timeInterval*1000));
 end;

procedure TSoundLibImx.StopChannel(var channel:TChannel);
 begin
  if channel is TChannelImx then begin
   IMXChannelStop(TChannelImx(channel).handle);
   FreeAndNil(channel);
  end;
 end;

{ TMediaFileImx }
constructor TMediaFileImx.Create(h: HSample;mediaType:TMediaType;data:ByteArray);
 begin
  handle:=h;
  mType:=mediaType;
  mData:=data;
 end;

destructor TMediaFileImx.Destroy;
 begin
  if handle=0 then exit;
  case mType of
   mtSample:IMXSampleUnload(handle);
   mtModule:IMXModuleUnload(handle);
   mtStream:IMXStreamClose(handle);
  end;
 end;

end.
