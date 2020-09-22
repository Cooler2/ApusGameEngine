// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit VideoCapture;
interface
 uses EngineAPI,BasicGame,Images;

 // Инициализирует захват видео, стартует потоки и т.д.
 function StartVideoCapture(game:TBasicGame;outfile:string;options:cardinal=0;threads:integer=2):boolean;
 // Видеозахват завершен (однако упаковка и запись могут еще продолжаться)
 procedure FinishVideoCapture;
 // Используется для передачи кадра на сжатие
 procedure StoreFrame(img:TRAWImage);

implementation
 uses windows,SysUtils,MyServis,classes,{AVS,}GFXFormats;
 const
  MAX_FRAMES = 50000;
 type

  // Главный поток - принимает входящие кадры, генерирует задания
  TVideoThread=class(TThread)
   procedure Execute; override;
  end;

  // Рабочий поток - исполняет задания из очереди
  TWorkerThread=class(TThread)
   procedure Execute; override;
  end;

  // Поток записывает готовые данные в файл
  TWriterThread=class(TThread)
   procedure Execute; override;
  end;

  // Кадр для сжатия
  TFrameData=class
   source:TRAWImage; // исходные RAW-данные в 32bpp
   timestamp:cardinal; // время захвата кадра в мс (со старта видеопотока)
   frameType:cardinal;
   frameNum:integer;
   chunks:array[1..15] of ByteArray;
   chunksCount:integer;
   chunksFinished:integer;
   next,prev:TFrameData;
   constructor Create(raw:TRAWImage);
   destructor Destroy; override;
   procedure FreeSource;
  end;

  // Задание
  TJob=record
   frame:TFrameData; // Какой кадр обрабатывать
   rect:TRect;   // область кадра для обработки
   task:cardinal; // что делать
   chunk:integer; // в какой чанк писать результат
  end;

 var
  videoThread:TVideoThread;
  workers:array[1..8] of TWorkerThread;
  gameObj:TBasicGame;
  // Кадры для обработки
  firstFrame,lastFrame:TFrameData;
  unhandledFrame:TFrameData; // следующий для обработки кадр
  dFrames:integer; // кол-во последовательных D-кадров

  // Очередь заданий
  jobQueue:array[0..255] of TJob;
  jStart,jEnd:byte;
  jCount:integer; // кол-во заданий в очереди

  cSect:TMyCriticalSection;
  capStarted:int64;
  filename:string; // имя файла для записи результата
  captureMode:boolean=false;
  readyState:boolean=true;

  // Готовые кадры после обработки
  fCount:integer;

 function StartVideoCapture(game:TBasicGame;outfile:string;options:cardinal=0;threads:integer=2):boolean;
  var
   i:integer;
  begin
   result:=false;
   if not readyState then exit;
   LogMessage('Starting video capture to '+outfile);
   EnterCriticalSection(cSect);
   try
    // Free any old frame data if exists
    while firstFrame<>nil do firstFrame.Free;
    unhandledFrame:=nil;
    readyState:=false;
    captureMode:=true;
    gameObj:=game;
    capStarted:=MyTickCount;
    fCount:=0;
    dFrames:=0;
    jCount:=0;
    filename:=outfile;
    videoThread:=TVideoThread.Create(false);
    for i:=1 to threads do
     workers[i]:=TWorkerThread.Create(false);
    TWriterThread.Create(false);
    result:=true;
   finally
    LeaveCriticalSection(cSect);
   end;
  end;

 procedure FinishVideoCapture;
  begin
   LogMessage('Finishing video capture');
   captureMode:=false;
   videoThread.Terminate;
  end;

 procedure StoreFrame(img:TRAWImage);
  var
   frame:TFrameData;
   fType:cardinal;
  begin
   EnterCriticalSection(cSect);
   try
    frame:=TFrameData.Create(img);
    if unhandledFrame=nil then unhandledFrame:=frame;
   finally
    LeaveCriticalSection(cSect);
   end;
  end;

{ TVideoThread }

 procedure AddJob(var job:TJob);
  begin
   while jCount>250 do sleep(5);
   EnterCriticalSection(cSect);
   try
    jobQueue[jEnd]:=job;
    inc(jEnd);
    inc(jCount);
   finally
    LeaveCriticalSection(cSect);
   end;
  end;

 // разбирается с кадром и создает задания
 procedure ProcessFrame(frame,oldFrame:TFrameData);
  var
   job:TJob;
  begin
   frame.frameType:=1;
{   if (oldFrame<>nil) and (dFrames<50) then
    if CompareFrames(oldFrame.source,Frame.source) then frame.frameType:=2;}

   // process P-Frame
   if frame.frameType=1 then begin
    frame.chunksCount:=1;
    job.frame:=frame;
    job.task:=1;
    job.chunk:=1;
    job.rect:=Rect(0,0,frame.source.width,frame.source.height);
    AddJob(job);
   end;

   // Process D-Frame
   if frame.frameType=2 then begin
    frame.chunksCount:=1;
    job.frame:=frame;
    job.task:=2;
    job.chunk:=1;
    job.rect:=Rect(0,0,frame.source.width,frame.source.height);
    AddJob(job);
   end;
  end;

 procedure TVideoThread.Execute;
  var
   frame,oldFrame:TFrameData;
  begin
   repeat // Главный цикл
    EnterCriticalSection(cSect);
    try
     // Есть ли необработанный кадр?
     frame:=nil;
     if unhandledFrame<>nil then begin
      frame:=unhandledFrame;
      oldFrame:=unhandledFrame.prev;
      unhandledFrame:=frame.next;
     end;
    finally
     LeaveCriticalSection(cSect);
    end;
    if frame<>nil then ProcessFrame(frame,oldFrame)
     else sleep(5);
   until terminated;
   FreeAndNil(videoThread);
  end;

{ TWorkerThread }
procedure DoJob(var job:TJob);
 var
  t:integer;
 begin
  try
  with job do begin
   t:=task and $FF;
   case t of
    1:PackPFrame(frame.source,rect,frame.chunks[chunk],AVS_RAW18);
 //   2:PackPFrame(
   end;
   InterlockedIncrement(frame.chunksFinished);
  end;
  except
   on e:exception do LogMessage('Error processing job: '+IntToHex(cardinal(job.frame),8)+
     ' Frame# '+IntToStr(job.frame.frameNum)+
     ' Chunk: '+IntToStr(job.chunk)+' task: '+IntToHex(job.task,8));
  end;
 end;

procedure TWorkerThread.Execute;
 var
  job:TJob;
 begin
  freeOnTerminate:=true;
  repeat
   job.task:=0;
   EnterCriticalSection(cSect);
   try
    if jStart<>jEnd then begin
     job:=jobQueue[jStart];
     inc(jStart);
     dec(jCount);
    end else
     if videoThread=nil then Terminate; // everything done
   finally
    LeaveCriticalSection(cSect);
   end;
   if job.task<>0 then DoJob(job)
    else sleep(1);
  until terminated;
 end;

 { TFrameData }
constructor TFrameData.Create;
 begin
  source:=raw;
  timeStamp:=MyTickCount-capStarted;
  next:=nil;
  prev:=lastFrame;
  if lastFrame<>nil then lastFrame.next:=self;
  lastFrame:=self;
  if firstFrame=nil then firstFrame:=self;
  chunksCount:=0;
  chunksFinished:=0;
  inc(fCount);
  frameNum:=fCount;
 end;

destructor TFrameData.Destroy;
 var
  i:integer;
 begin
  EnterCriticalSection(cSect);
  try
  FreeSource;
  for i:=1 to chunksCount do
   SetLength(chunks[i],0);
  chunksCount:=0;
  if firstFrame=self then firstFrame:=next;
  if lastFrame=self then lastFrame:=nil;
  inherited;
  finally
   LeaveCriticalSection(cSect);
  end;
 end;

procedure TFrameData.FreeSource;
 begin
  if source<>nil then gameObj.ReleaseFrameData(source);
  source:=nil;
 end;

{ TWriterThread }

procedure TWriterThread.Execute;
var
 f:file;
 frame:TFrameData;
 i:integer;
 header:TFrameHeader;
 data:ByteArray;
begin
 FreeOnTerminate:=true;
 assign(f,filename);
 rewrite(f,1);
 repeat
  frame:=nil;
  EnterCriticalSection(cSect);
  try
   if (firstFrame<>nil) and
      (firstFrame.chunksCount>0) and
      (firstFrame.chunksCount=firstFrame.chunksFinished) then frame:=firstFrame;
  finally
   LeaveCriticalSection(cSect);
  end;
  if frame<>nil then begin
   with frame do begin
    // Покадровая запись в файлы
    data:=SaveTGA(frame.source);
    WriteFile(filename+IntToStr(frame.frameNum)+'.tga',@data[0],0,length(data));
    SetLength(data,0);

{    // Frame header
    header.magic:=MAGIC_DWORD;
    header.timestamp:=timestamp;
    header.frameType:=frameType;
    header.frameNum:=frameNum;
    header.frameSize:=sizeof(header);
    for i:=1 to chunksCount do
     inc(header.frameSize,length(chunks[i]));
    BlockWrite(f,header,sizeof(header));
    // Chunks
    for i:=1 to chunksCount do
     BlockWrite(f,chunks[i][0],length(chunks[i]));      }
    frame.Free; // передвигает указатель firstFrame на след. кадр
   end;
  end else
   if videoThread=nil then break;
 until false;
 close(f);
 readyState:=true;
end;

initialization
 InitCritSect(cSect,'videoCap');
finalization
 DeleteCritSect(cSect);
end.
