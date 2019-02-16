// Image loading queue for multithreading preload of images
// PNG/JPG/TGA/DDS/PVR only
// JPEG with external alpha channel NOT SUPPORTED!
//
// Copyright (C) 2019 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
unit ImgLoadQueue;
interface
 uses Images;

 // Queue file for loading, name must be with extension
 procedure QueueFileLoad(fname:string);
 // Starts one loading thread and 1..4 unpacking threads
 procedure StartLoadingThreads(unpackThreadsNum:integer=2);
 // Get raw image from queue if exists or nil elsewere
 // Waits if image is queued, but not yet processed
 function GetImageFromQueue(fname:string;wait:boolean=true):TRawImage;

 procedure LockImgQueue;
 procedure UnlockImgQueue;


implementation
 uses MyServis,SysUtils,Classes,gfxFormats;

 // Queue
 type
  TLoadQueueStatus=(lqsNone,        // No entry
                    lqsWaiting,     // Load operation queued
                    lqsLoading,     // File is loading
                    lqsLoaded,      // Loading done, waiting for unpack
                    lqsUnpacking,   // Processing by an unpacking thread
                    lqsReady,       // All done! Final RAW image data is ready
                    lqsError);      // Failed to load the image

  TQueueEntry=record
   status:TLoadQueueStatus;
   fname:string;
   srcData:ByteArray;
   img:TRawImage;
   format:TImageFormat;
   info:TImageInfo;
  end;
 var
  cSect:TMyCriticalSection;
  loadQueue:array of TQueueEntry;

 // Threads
 type
  TLoadingThread=class(TThread)
   procedure Execute; override;
  end;
  TUnpackThread=class(TThread)
   procedure Execute; override;
  end;
 var
  loadingThread:TLoadingThread;
  unpackThreads:array[1..4] of TUnpackThread;

 function GetImageFromQueue(fname:string;wait:boolean=true):TRawImage;
  var
   i,n:integer;
  begin
   result:=nil;
   if length(loadQueue)=0 then exit;
   cSect.Enter;
   try
    n:=-1;
    for i:=0 to high(loadQueue) do
     if CompareText(fname,loadQueue[i].fname)=0 then begin
      n:=i; break;
     end;
    if n>=0 then begin
     if loadQueue[n].status=lqsReady then begin
      result:=loadQueue[n].img;
      exit;
     end;
     if wait and (loadQueue[n].status in [lqsWaiting,lqsLoaded]) then begin
      // Try to load this earlier
      for i:=0 to n-1 do
       if loadQueue[i].status in [lqsWaiting,lqsLoaded] then begin
        Swap(loadQueue[i],loadQueue[n],sizeof(loadQueue[i]));
        n:=i;
        break;
       end;
     end;
    end else
     exit;
   finally
    cSect.Leave;
   end;
   if (n>=0) then begin
    repeat
      sleep(1);
    until loadQueue[n].status in [lqsReady,lqsError];
    result:=GetImageFromQueue(fname,true); // try once again because N may become obsolete at this point
   end;
  end;

 procedure QueueFileLoad(fname:string);
  var
   i:integer;
  begin
   fname:=FileName(fname);
   cSect.Enter;
   try
    i:=length(loadQueue);
    SetLength(loadQueue,i+1);
    loadQueue[i].fname:=fname;
    loadQueue[i].status:=lqsWaiting;
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
   loadingThread:=TLoadingThread.Create;
   if unpackThreadsNum>=high(unpackThreads) then unpackThreadsNum:=high(unpackThreads);
   for i:=1 to unpackThreadsNum do
    unpackThreads[i]:=TUnpackThread.Create;
  end;

{ TLoadingThread }

procedure TLoadingThread.Execute;
 var
  i,n:integer;
 begin
  try
  repeat
   // Find the first waiting entry
   cSect.Enter;
   try
    n:=-1;
    for i:=0 to high(loadQueue) do
     if loadQueue[i].status=lqsWaiting then begin
      n:=i;
      break;
     end;
    if n<0 then break; // No more unprocessed items
    loadQueue[n].status:=lqsLoading; // locked by this thread
   finally
    cSect.Leave;
   end;
   // Load file data
   with loadQueue[n] do begin
    LogMessage('Preloading '+fname);
    srcData:=LoadFileAsBytes(fname);
    if length(srcData)<30 then begin
     ForceLogMessage('Failed to load file: '+fname);
     status:=lqsError;
     continue;
    end;
    format:=CheckImageFormat(srcData);
    info:=imgInfo;
    status:=lqsLoaded; // unlocked
   end;
  until terminated;
  except
   on e:Exception do ErrorMessage('Error in LoadingThread: '+ExceptionMsg(e));
  end;
 end;

{ TUnpackThread }

procedure TUnpackThread.Execute;
 var
  i,n:integer;
  shouldWait:boolean;
  t:int64;
 begin
  try
  repeat
   // Find the first waiting entry
   cSect.Enter;
   try
    n:=-1;
    shouldWait:=false;
    for i:=0 to high(loadQueue) do
     if loadQueue[i].status=lqsLoaded then begin
      n:=i;
      break;
     end else
     if loadQueue[i].status in [lqsWaiting,lqsLoading] then shouldWait:=true;
    if n<0 then begin
     if shouldWait then begin
      sleep(1); continue;
     end else
      break; // No more unprocessed items and no items to wait
    end;
    loadQueue[n].status:=lqsUnpacking;
   finally
    cSect.Leave;
   end;
   // Unpack image
   t:=MyTickCount;
   with loadQueue[n] do begin
    try
     img:=nil;
     if format=ifTGA then LoadTGA(srcData,img,true) else
     if format=ifJPEG then LoadJPEG(srcData,img) else
     if format=ifPNG then LoadPNG(srcData,img) else
     if format=ifPVR then LoadPVR(srcData,img,true) else
     if format=ifDDS then LoadDDS(srcData,img,true) else begin
      ForceLogMessage('Image format not supported for async load: '+fname);
      Setlength(srcData,0);
      status:=lqsError;
      continue;
     end;
     LogMessage('Preloaded: '+fname+', time='+IntToStr(MyTickCount-t));
     Setlength(srcData,0);
     status:=lqsReady;
    except
     on e:exception do begin
      ForceLogMessage('Error unpacking '+fname+': '+ExceptionMsg(e));
      Setlength(srcData,0);
      status:=lqsError;
     end;
    end;
   end;
  until terminated;
  except
   on e:Exception do ErrorMessage('Error in UnpackingThread: '+ExceptionMsg(e));
  end;
 end;

procedure TerminateThreads;
 var
  i:integer;
 begin
  if (loadingThread<>nil) and not loadingThread.Terminated then begin
   loadingThread.Terminate;
   loadingThread.WaitFor;
  end;
  for i:=1 to high(unpackThreads) do
   if (unpackThreads[i]<>nil) and not unpackThreads[i].Terminated then begin
    unpackThreads[i].Terminate;
    unpackThreads[i].WaitFor;
   end;
 end;

initialization
 InitCritSect(cSect,'ImgloadQueue');
finalization
 TerminateThreads;
 DeleteCritSect(cSect);
end.
