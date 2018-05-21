unit AVSPlayer;
interface
 uses MyServis,Images;
 type
  // Класс для проигрывания/распаковки AVS
  TAVSPlayer=class
   width,height:integer; // размеры видео
   duration:cardinal;
   position:cardinal; // текущая позиция в потоке
   preloadFrames:integer;
   constructor Create(filename:string;preload:integer=20);
   destructor Destroy; override;
   procedure SetPos(time:cardinal); // Устанавливает текущую позицию в ms, останавливает декомпрессию и очищает буфера
   procedure StartDecompression(threads:integer); // Начинает распаковку кадров и заполнение буферов
   function ReadyFrames:integer; // сколько кадров уже распаковано и готово к работе?
   function GetFrameTime:cardinal; // Возвращает timestamp текущего кадра
   function GetFrameImage:TRAWImage; // Возвращает содержание текущего кадра
   procedure NextFrame; // Переходит на следующий кадр
   procedure StopDecompression;
  private
   F:file;
   curFrame,lastFrame:TObject;
   fCount:integer; // Количество загруженных фреймов
   cSect:TMyCriticalSection;
   function ReadFrame:TObject; // Читает из файла фрейм
   procedure FreeAllFrames; // Удаляет все загруженные фреймы
  end;

implementation
 uses SysUtils,AVS;

 type
  TAVSFrame=class
   owner:TAVSPlayer;
   frameType:word;
   frameNum:word;
   timestamp:cardinal;
   chunks:array[1..15] of ByteArray;
   chunksCount:integer;
   image:TRAWImage;
   status:byte; // 0 - empty, 1 - chunks loaded, 2 - being decompressed, 3 - ready
   prev,next:TAVSFrame;
   constructor Create(player:TAVSPlayer);
   destructor Destroy; override;
  end;

{ TAVSPlayer }
constructor TAVSPlayer.Create(filename: string;preload:integer=20);
var
 frame:TAVSFrame;
begin
 curFrame:=nil;
 lastFrame:=nil;
 preloadFrames:=preload;
 assign(F,filename);
 reset(F,1);
 SetPos(0);
 repeat
  frame:=ReadFrame as TAVSFrame;
 until frame=nil;
end;

destructor TAVSPlayer.Destroy;
begin
 close(F);
 inherited;
end;

procedure TAVSPlayer.FreeAllFrames;
var
 frame,oldFrame:TAVSFrame;
begin
 EnterCriticalSection(cSect);
 try
  frame:=curFrame as TAVSFrame;
  while frame<>nil do begin
   oldFrame:=frame;
   frame:=frame.next;
   frame.prev:=nil;
   oldFrame.Free;
  end;

 finally
  LeaveCriticalSection(cSect);
 end;
end;

function TAVSPlayer.GetFrameImage: TRAWImage;
begin

end;

function TAVSPlayer.GetFrameTime: cardinal;
begin

end;

procedure TAVSPlayer.NextFrame;
begin

end;

function TAVSPlayer.ReadFrame: TObject;
var
 frame:TAVSFrame;
begin
 result:=nil;
 if fCount>=preloadFrames then exit;
 if eof(F) then exit;
 frame:=TAVSFrame.Create(self);
end;

function TAVSPlayer.ReadyFrames: integer;
var
 frame:TAVSFrame;
begin
 result:=0;
 EnterCriticalSection(cSect);
 try
  frame:=curFrame as TAVSFrame;
  while (frame<>nil) and (frame.status=3) do begin
   inc(result);
   frame:=frame.next;
  end;
 finally
  LeaveCriticalSection(cSect);
 end;
end;

procedure TAVSPlayer.SetPos(time: cardinal);
begin
 Seek(F,0);
 position:=time;
 if time=0 then exit;
end;

procedure TAVSPlayer.StartDecompression(threads: integer);
begin

end;

procedure TAVSPlayer.StopDecompression;
begin

end;

{ TAVSFrame }

constructor TAVSFrame.Create(player:TAVSPlayer);
begin
 owner:=player;
 EnterCriticalSection(owner.cSect);
 try
  TAVSFrame(owner.lastFrame).next:=self;
  owner.lastFrame:=self;
  if owner.curFrame=nil then owner.curFrame:=self;
 finally
  LeaveCriticalSection(owner.cSect);
 end;
end;

destructor TAVSFrame.Destroy;
var
 i:integer;
begin
 for i:=1 to chunksCount do
  SetLength(chunks[i],0);
 FreeAndNil(image);

 EnterCriticalSection(owner.cSect);
 try
  if owner.curFrame=self then owner.curFrame:=next;
  if owner.lastFrame=self then owner.lastFrame:=prev;
  if prev<>nil then prev.next:=next;
  if next<>nil then next.prev:=prev;
 finally
  LeaveCriticalSection(owner.cSect);
 end;
 inherited;
end;

end.

