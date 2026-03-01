// Image loading queue for multithreading preload of images
// PNG/JPG/TGA/DDS/PVR only
// JPEG with external RAW alpha channel NOT SUPPORTED!
//
// Copyright (C) 2019 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.ImgLoadQueue;
interface
 uses Apus.Core, Apus.Images;

 type
  // What happens when requested image is queued, but not ready
  TQueueRequestMode=(
     qrmWait,          // block and wait until image is ready (requested image get highest priority)
     qrmReturnSource,  // if file is loaded but not yet unpacked - return its content in imageSource and abort task
     qrmAbort,         // abort task
     qrmIgnore);       // do nothing, return nothing

 threadvar
  imageSource:ByteArray;

 // Queue file for loading, name must be with extension
 procedure QueueFileLoad(fname:String8);
 // Starts one loading thread and 1..4 unpacking threads
 procedure StartLoadingThreads(unpackThreadsNum:integer=2);
 // Get raw image from queue if exists or nil elsewere
 // Waits if image is queued, but not yet processed
 function GetImageFromQueue(fname:String8;mode:TQueueRequestMode=qrmWait):TRawImage;

implementation
 uses
  Apus.Lib,
  Apus.Strings,
  Classes,
  Apus.GfxFormats;

 // Queue
 type
  TLoadQueueStatus=(lqsNone,        // No entry
                    lqsWaiting,     // Load operation queued
                    lqsLoading,     // File is loading
                    lqsLoaded,      // Loading done, waiting for unpack
                    lqsUnpacking,   // Processing by an unpacking thread
                    lqsReady,       // All done! Final RAW image data is ready
                    lqsError);      // Failed to load the image

  PQueueEntry=^TQueueEntry;
  TQueueEntry=record
   status:TLoadQueueStatus;
   fname:String8;
   srcData:ByteArray;
   img:TRawImage;
   format:TImageFileType;
   info:TImageFileInfo;
   timeLoaded,timeUnpacked:int64;
   next:PQueueEntry;
  end;
 var
  cSect:TLock;
  firstItem,lastItem:PQueueEntry;

 // Threads
 type
  TLoadingThread=class(TThread)
   procedure Execute; override;
  end;
  TUnpackThread=class(TThread)
   procedure Execute; override;
  end;
 var
  // This thread load image files
  loadingThread:TLoadingThread;
  // These threads are unpacking compressed images (JPG/PNG)
  unpackThreads:array[1..4] of TUnpackThread;

  maxUnpackTime:integer;

 function GetImageFromQueue(fname:String8;mode:TQueueRequestMode=qrmWait):TRawImage;
  var
   item,prev:PQueueEntry;
   found:boolean;
  begin
   result:=nil;
   if firstItem=nil then exit;
   cSect.Enter;
   try
    item:=firstItem;
    prev:=nil;
    found:=false;
    while item<>nil do begin
     if (item.status<>lqsNone) and fname.Same(item.fname) then begin
      found:=true;
      break;
     end;
     prev:=item;
     item:=item.next;
    end;
    if not found then exit;
    if item.status=lqsReady then exit(item.img); // success
    case mode of
     qrmIgnore:exit;
     qrmAbort:begin
      item.status:=lqsNone;
      exit;
     end;
     qrmReturnSource:
      if (item.status in [lqsLoaded,lqsUnpacking]) then begin
       if item.status=lqsLoaded then item.status:=lqsNone;
       imageSource:=item.srcData;
       exit;
      end;
     qrmWait:begin
      Log.Msg('Waiting for %s, status %d',[fname,ord(item.status)]);
      // try to handle this earlier -> move on top
      if (prev<>nil) and (item.status in [lqsWaiting,lqsLoaded]) then begin
       prev.next:=item.next;
       item.next:=firstItem;
       MemoryBarrier;
       firstItem:=item;
      end;
     end;
    end;
   finally
    cSect.Leave;
   end;
   // Wait for result
   while not (item.status in [lqsNone,lqsReady,lqsError]) do Time.Sleep(0);
   if item.status=lqsReady then result:=item.img;
  end;

 procedure QueueFileLoad(fname:String8);
  var
   item:PQueueEntry;
  begin
   fname:=Files.FixName(fname);
   cSect.Enter;
   try
    New(item);
    Mem.Clear(item^,sizeof(TQueueEntry));
    item.status:=lqsWaiting;
    item.fname:=fname;
    if lastItem<>nil then lastItem.next:=item;
    MemoryBarrier;
    lastItem:=item;
    if firstItem=nil then firstItem:=item;
   finally
    cSect.Leave;
   end;
  end;

 procedure LockImgQueue;
  begin
   cSect.Enter;
  end;

 procedure UnlockImgQueue;
  begin
   cSect.Leave;
  end;

 procedure StartLoadingThreads(unpackThreadsNum:integer=2);
  var
   i:integer;
  begin
   loadingThread:=TLoadingThread.Create(false);
   for i:=1 to Min(unpackThreadsNum,high(unpackThreads)) do
    unpackThreads[i]:=TUnpackThread.Create(false);
  end;

{ TLoadingThread }

procedure TLoadingThread.Execute;
 var
  i,n:integer;
  item,start:PQueueEntry;
 procedure Restart;
  begin
   // Wait until queue not empty
   while firstItem=nil do Time.Sleep(10);
   start:=firstItem;
   item:=start;
  end;
 begin
  Thread.Register('QLoading');
  try
  Restart;
  repeat

   while (item<>nil) and (item.status<>lqsWaiting) do item:=item.next;
   if item=nil then begin
    Time.Sleep(10);
    Restart;
    continue;
   end;

   if item.status=lqsWaiting then
    with item^ do begin
     Log.Msg('Preloading '+fname);
     try
      srcData:=Files.LoadAsBytes(fname);
      timeLoaded:=CoreTime.Ticks;
     except
      on e:Exception do Log.Force('Loader error; '+ExceptionMsg(e));
     end;
     if length(srcData)<30 then begin
      Log.Force('Failed to load file: '+fname);
      status:=lqsError;
     end;
     format:=CheckImageFormat(srcData);
     info:=imgInfo;
     status:=lqsLoaded; // ready for processing
    end;

   if firstItem<>start then begin
    Restart;
    continue;
   end;
   item:=item.next;
  until terminated;
  except
   on e:Exception do SystemMessage('Error in LoadingThread: '+ExceptionMsg(e));
  end;
  Thread.Unregister;
 end;

{ TUnpackThread }

procedure TUnpackThread.Execute;
 var
  item:PQueueEntry;
  t:int64;
 begin
  Thread.Register('QUnpack');
  try
  repeat
   Time.Sleep(1); // Never wait inside CS!
   item:=firstItem;
   // Find the first waiting entry
   cSect.Enter;
   try
    while (item<>nil) and (item.status<>lqsLoaded) do item:=item.next;
    if item<>nil then
     item.status:=lqsUnpacking;
   finally
    cSect.Leave;
   end;

   if item<>nil then begin
    // Unpack image
    t:=CoreTime.Ticks;
    with item^ do
     try
      img:=nil;
      if format=ifTGA then LoadTGA(srcData,img,true) else
      if format=ifJPEG then LoadJPEG(srcData,img) else
      if format=ifPNG then LoadPNG(srcData,img) else
      if format=ifPVR then LoadPVR(srcData,img,true) else
      if format=ifDDS then LoadDDS(srcData,img,true) else begin
       Log.Force('Image format not supported for async load: '+fname);
       Setlength(srcData,0);
       status:=lqsError;
       continue;
      end;
      Log.Msg('Preloaded: '+fname+', time='+Conv.ToStr(CoreTime.Ticks-t));
      Setlength(srcData,0);
      status:=lqsReady;
      timeUnpacked:=CoreTime.Ticks;
      maxUnpackTime:=Max(maxUnpackTime,timeUnpacked-timeLoaded);
      Time.Sleep(0);
     except
      on e:exception do begin
       Log.Force('Error unpacking '+fname+': '+ExceptionMsg(e));
       Setlength(srcData,0);
       status:=lqsError;
      end;
     end;
   end;
  until terminated;
  except
   on e:Exception do SystemMessage('Error in UnpackingThread: '+ExceptionMsg(e));
  end;
  Thread.Unregister;
 end;

procedure TerminateThreads;
 var
   i:integer;
 begin
   Log.Force('Terminating ILQ threads');
   if (loadingThread<>nil) and not loadingThread.Terminated then begin
     loadingThread.Terminate;
     loadingThread.WaitFor;
   end;
   for i:=1 to high(unpackThreads) do
     if (unpackThreads[i]<>nil) and not unpackThreads[i].Terminated then begin
       unpackThreads[i].Terminate;
       unpackThreads[i].WaitFor;
     end;
   Log.Msg('ILQ threads terminated. Max unpack time was '+Conv.ToStr(maxUnpackTime));
 end;

initialization
  cSect.Init('ImgloadQueue');
finalization
  TerminateThreads;
  cSect.Cleanup;
end.
