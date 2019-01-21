// Main runtime unit of the engine
//
// IMPORTANT: Nevertheless DXGame is implemented as class, it is
//            NOT thread-safe itself i.e. does not allow multiple instances!
//            (at least between Run/Stop calls)
//            If you want to access private data (buffers, images) from other
//            threads, use your own synchronization methods
//
// Copyright (C) 2003-2013 Apus Software (www.games4win.com, www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by)
{$IFDEF IOS}{$S-}{$ENDIF}
{$R-}
unit BasicGame;
interface
 uses {$IFDEF MSWINDOWS}windows,messages,{$ENDIF}EngineCls,Images,classes,CrossPlatform,MyServis;

var
 HookKbdLayout:boolean=false; // Перехват переключения раскладки клавиатуры (защита от зависания, теперь уже не требуется, т.к. баг устранен)
 MaxWindowWidth:integer=10000;
 MaxWindowHeight:integer=10000;

 SaveScreenshotsToJPEG:boolean=true;
 onFrameDelay:integer=1; // Задержка каждый кадр
  
type
 // Функция для асинхронного (параллельного) исполнения
 TThreadFunc=function(param:cardinal):integer;

 // Основной класс. Можно использовать его напрямую, но лучше унаследовать
 // от него свой собственный и определить для него события

 { TBasicGame }

 TBasicGame=class
  constructor Create(vidmem:integer=0); // Создать экземпляр (желательный объем видеопамяти под текстуры в мегабайтах)
  procedure Run; virtual; // запустить движок (создание окна, переключение режима и пр.)
  procedure Stop; virtual; // остановить и освободить все ресурсы (требуется повторный запуск через Run)
  destructor Destroy; override; // автоматически останавливает, если это не было сделано

  // Управление параметрами во время работы
  // Задать новые размеры/положение окна
  procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0); virtual;
  procedure SetWindowCaption(text:string); virtual; // Сменить заголовок (оконный режим)
  procedure Minimize; virtual; // свернуть окно (полезно в полноэкранном режиме)
  procedure FlashWindow(count:integer); virtual; // помигать кнопкой окна (0 - мигать пока юзер не переключится в окно, -1 - остановить)

  // Events
  // Этот метод вызывается из главного цикла всякий раз перед попыткой рендеринга кадра, даже если программа неактивна или девайс потерян
  function OnFrame:boolean; virtual; // true означает что на экране что-то должно изменится поэтому экран нужно перерисовать. Иначе перерисовка выполнена не будет (движение мыши отслеживается отдельно)
  procedure RenderFrame; virtual; // этот метод должен отрисовать кадр в backbuffer

  // Сцены
  procedure AddScene(scene:TGameScene); virtual;    // Добавить сцену в список сцен
  procedure RemoveScene(scene:TGameScene); virtual;  // Убрать сцену из списка сцен
  function TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene; virtual;

  // Курсоры
  procedure RegisterCursor(CursorID,priority:integer;cursorHandle:cardinal); virtual; // Объявить курсор, сопоставить ему системный хэндл
  procedure ToggleCursor(CursorID:integer;state:boolean=true); virtual; // Включить/выключить указанный курсор
  procedure ResetAllCursors; virtual; // Выключить все курсоры

  // Трансляция координат
  procedure ScreenToGame(var p:TPoint); virtual;
  procedure GameToScreen(var p:TPoint); virtual;

  // Потоки
  // Запустить функцию на параллельное выполнение (ttl - лимит времени в секундах, если есть)
  // По завершению будет выдано событие engine\thread\done с кодом, возвращенным ф-цией, либо -1 если завершится по таймауту
  function RunAsync(threadFunc:pointer;param:cardinal;ttl:single=0;name:string=''):THandle; virtual;
  // Функция все еще выполняется? если да - вернет 0,
  // если прервана по таймауту - -1, если неверный хэндл - -2, иначе - результат функции
  function GetThreadResult(h:THandle):integer; virtual;

  // Добавляет строку в "кадровый лог" - невидимый лог, который обнуляется каждый кадр, но может быть сохранен в случае какой-либо аварийной ситуации 
  procedure FLog(st:string); virtual;
  function GetStatus(n:integer):string; virtual; abstract;
  // Show message in engine-driven pop-up (3 sec)
  procedure FireMessage(st:string); virtual;

  // Использование критсекции движка
  procedure EnterCritSect; virtual;
  procedure LeaveCritSect; virtual;

  // Устанавливает флаги о необходимости сделать скриншот (JPEG или BMP)
  // obj - либо nil, либо заранее созданный объект типа TBitmap
  procedure WantToCaptureSingleFrame(jpeg:boolean=true;obj:TRAWImage=nil); virtual;
  procedure StartVideoCap(filename:string); virtual;
  procedure FinishVideoCap; virtual;

  // При включенной видеозаписи вызывается видеокодером для освобождения памяти кадра
  procedure ReleaseFrameData(obj:TRAWImage); virtual; 
  
 protected
  running:boolean;
  useMainThread:boolean; // true - launch "main" thread with main loop,
                         // false - no main thread, catch frame events
  canExitNow:boolean; // флаг того, что теперь можно начать деинициализацию
  params:TGameSettings;
  aspectRatio:single;
  loopThread:TThread;
  controlThread:TThreadID;
  BestVidMem,VidmemLimit:integer;
  cursors:array[1..32] of TObject;

  LastOnFrameTime:int64; // момент последнего вызова обработки кадра
  LastRenderTime:int64; // Момент последней отрисовки кадра
  capturedName:string;
  capturedTime:int64;

  // Интерфейсы отрисовки и управления ресурсами 
  texman:TTextureMan;
  painter:TPainter;

  wndCursor:HCURSOR;
  // Для расчета FPS
  LastFrameNum:integer;
  LastTickCount:cardinal;
  frameTime:cardinal;
  // Захват видео и скриншотов
  videoCaptureMode:boolean; // режим видеозахвата
  captureSingleFrame:boolean; // флаг необходимости захвата одного кадра
  screenshotTarget:integer; // что сделать с захваченным кадром
  // 0 - ничего (оставить в памяти), 1 - сохранить в файл BMP и удалить, 2 - сохранить в файл JPEG и удалить
//  {$IFDEF MSWINDOWS}
  screenshotDataExt:TRAWImage; // если скриншот запрошен внешним кодом - нужно скопировать его сюда
  screenshotDataRAW:TRAWImage; // здесь данные скриншота (TRAWImage), доступны только во время CaptureFrame
//  {$ENDIF}
  debugOverlay:integer; // индекс отладочного оверлея, включаемого клавишами Alt+Fn (0 - отсутствует)

  curPrior:integer; // приоритет текущего отображаемого курсора

  procedure ChangeSettings(s:TGameSettings); virtual; // этот метод служит для изменения режима или его параметров
  procedure ApplySettings; virtual; abstract;
  procedure ShowMouse(m:boolean); virtual; // управление курсором мыши (системным либо своим)

  // Производит настройку подчинённых объектов/интерфейсов (Painter, UI и т.д)
  // Вызывается после инициализации а также при изменения размеров окна, области или режима отрисовки
  procedure SetupRenderArea; virtual;

  // Эти методы используются при смене режима работы (вызов только из главного потока)
  procedure InitGraph; virtual; // Инициализация графической части (переключить режим и все такое прочее)
  procedure AfterInitGraph; virtual; // Вызывается после инициализации графики 
  procedure DoneGraph; virtual; // Финализация графической части
  // Определить форматы пикселя для загружаемых изображений с учетом
  // а) рекомендуемого объема видеопамяти для игры
  // б) возможностей железа
  procedure CalcPixelFormats(needMem:integer); virtual; abstract;

  procedure FrameLoop; virtual;
  procedure PresentFrame; virtual; abstract;
  procedure CreateMainWindow; virtual;
  procedure ConfigureMainWindow; virtual;
  procedure DestroyMainWindow; virtual;
  // Create texman and painter objects
  procedure InitObjects; virtual; abstract;
  procedure InitMainLoop; virtual;

  // Производит захват кадра и производит с ним необходимые действия
  procedure CaptureFrame; virtual;

  procedure NotifyAboutMouseMove; virtual;
  procedure NotifyAboutMouseBtn(c:byte;pressed:boolean); virtual;

  // находит сцену, которая должна получать сигналы о клавиатурном вводе
  function TopmostSceneForKbd:TGameScene; virtual;

 public
  // Глобально доступные переменные
  crSect:TMyCriticalSection;
  unicode:boolean;      // unicode mode ON?
  window:cardinal;      // main window handle
  terminated:boolean;   // Работа цикла завершена, можно начинать деинициализацию и выходить
  renderRect:Trect;     // область вывода в окне (после инициализации - все окно) в реальных экранных пикселях
  displayWidth,displayHeight:integer; // реальный размер всего экрана
  windowWidth,windowHeight:integer; // размеры клиентской части окна в реальных пикселях
  active:boolean;       // Окно активно, цикл перерисовки выполняется
  paused:boolean;       // Режим паузы (изначально сброшен, движком не изменяется и не используется)
  initialized:boolean;  // Завершена ли инициализация (если нет - перерисовка запрещена)
  changed:boolean;      // Нужно ли перерисовывать экран (аналог результата onFrame, только можно менять в разных местах)
  mouseVisible:boolean; // курсор мыши включен
  frameNum:integer;     // Номер кадра
  FPS,smoothFPS:single;
  showFPS:boolean;      // отображать FPS в углу экрана
  showDebugInfo:integer; // Кол-во строк отладочной инфы
  frameLog,prevFrameLog:string;
  frameStartTime:int64; // MyTickCount в начале кадра
  avgTime,avgTime2:double;
  timerFrame:cardinal;

  videoCapturePath:string; // путь для сохранения файлов видеозахвата (по умолчанию - тек. каталог)

  keyState:array[0..255] of byte; // 0-й бит - клавиша нажата, 1-й - была нажата в пред. раз
  shiftstate:byte; // состояние клавиш сдвига (1-shift, 2-ctrl, 4-alt, 8-win)
  mouseX,mouseY:integer; // положение мыши внутри окна/экрана
  oldMouseX,oldMouseY:integer; // предыдущее положение мыши (не на предыдущем кадре, а вообще!)
  mouseMoved:int64; // Момент времени, когда положение мыши изменилось
  mouseButtons:byte;     // Флаги "нажатости" кнопок мыши (0-левая, 1-правая, 2-средняя)
  oldMouseButtons:byte;  // предыдущее (отличающееся) значение mouseButtons
  textLink:cardinal; // Вычисленный на предыдущем кадре номер ссылки под мышью записывается здесь (сам по себе он не вычисляется, для этого надо запускать отрисовку текста особым образом)
                     // TODO: плохо, что этот параметр глобальный, надо сделать его свойством сцен либо элементов UI, чтобы можно было проверять объект под мышью с учётом наложений
  textLinkRect:TRect; // область ссылки, по номеру textLink

  // параметры выставляются при смене режима, указыают что именно изменялось
  resChanged,pfChanged:boolean;
  scenes:array[1..60] of TGameScene;
  topmostScene:TGameScene;

  // properties
  property Settings:TGameSettings read params write ChangeSettings;
  property mouseOn:boolean read mouseVisible write ShowMouse;
  property IsRunning:boolean read running;
  procedure Delay(time:integer); // alias  
 end;

 // Для использования из главного потока
 procedure ProcessMessages;
 procedure Delay(time:integer);

implementation
 uses types,SysUtils,cmdproc{$IFDEF DELPHI},graphics{$ENDIF}
     {$IFDEF VIDEOCAPTURE},VideoCapture{$ENDIF},BasicPainter,
     EventMan,ImageMan,UIClasses,CommonUI,Console,EngineTools,publics,gfxFormats;

type
 TMainThread=class(TThread)
  errorMsg:string;
  owner:TBasicGame;
  procedure Execute; override;
 end;

 TCustomThread=class(TThread)
  id:cardinal;
  TimeToKill:int64;
  running:boolean;
  func:TThreadFunc;
  FinishTime:int64;
  param:cardinal;
  name:string;
  procedure Execute; override;
 end;

 TGameCursor=class
  ID:integer;
  priority:integer;
  handle:cardinal;
  visible:boolean;
 end;

var
  game:TBasicGame; // указатель на текущий объект игры (равен owner'у главного потока)

  {$IFDEF MSWINDOWS}
  LayoutList:array[1..10] of HKL; // Keyboard layouts (workaround to fix windows freeze)
  Layouts:integer;
  {$ENDIF}

  lastThreadID:integer;
  threads:array[1..16] of TCustomThread;
  RA_sect:TMyCriticalSection;

// Default raster fonts (size 6.2 and 7.5)
{$I defaultFont8.inc}
{$I defaultFont10.inc}

{ TBasicGame }

procedure TBasicGame.WantToCaptureSingleFrame(jpeg:boolean=true;obj:TRAWImage=nil);
begin
  captureSingleFrame:=true;
  if obj<>nil then screenshotTarget:=0
   else if jpeg then screenshotTarget:=2
    else screenshotTarget:=1;
  screenshotDataExt:=obj;
end;

procedure TBasicGame.ReleaseFrameData(obj:TRAWImage);
begin

end;

procedure TBasicGame.ChangeSettings(s: TGameSettings);
begin
 resChanged:=(s.width<>params.width) or (s.height<>params.height);
 pfChanged:=s.colorDepth<>params.colorDepth;
 params:=s;

 {$IFNDEF IOS} // no realtime settings change for IOS
 if running and
    ((loopThread=nil) or (GetCurrentThreadID<>loopThread.ThreadID)) then begin
  // Вызов из другого потока - синхронизируем!
  Signal('Engine\cmd\ChangeSettings');
  exit;
 end else
  ApplySettings;
 {$ENDIF}
end;

constructor TBasicGame.Create;
begin
 ForceLogMessage('Creating '+self.ClassName);
 running:=false;
 unicode:=true;
 canExitNow:=false;
 terminated:=false;
 useMainThread:=true;
 controlThread:=GetCurrentThreadId;
 active:=false;
 paused:=false;
 initialized:=false;
 loopThread:=nil;
 FrameNum:=0;
 fps:=0;
 SmoothFPS:=60;
 params.VSync:=1;
 ShowDebugInfo:=0;
 fillchar(keystate,sizeof(keystate),0);
 BestVidMem:=VidMem;
 InitCritSect(crSect,'MainGameObj',20);
// InitializeCriticalSection(crSect);
 // Primary display
 {$IFDEF MSWINDOWS}
 displayWidth:=GetSystemMetrics(SM_CXSCREEN);
 displayHeight:=GetSystemMetrics(SM_CYSCREEN);
 {$ENDIF}

 PublishVar(@showDebugInfo,'ShowDebugInfo',TVarTypeInteger);
 PublishVar(@showFPS,'showFPS',TVarTypeBool);
 fillchar(scenes,sizeof(scenes),0);
 PublishVar(@displayWidth,'DisplayWidth',TVarTypeInteger);
 PublishVar(@displayHeight,'DisplayHeight',TVarTypeInteger);
 PublishVar(@windowWidth,'WindowWidth',TVarTypeInteger);
 PublishVar(@windowHeight,'WindowHeight',TVarTypeInteger);    
end;

procedure TBasicGame.Delay(time: integer);
begin
 BasicGame.Delay(time);
end;

destructor TBasicGame.Destroy;
begin
 if running then Stop;
 DeleteCritSect(crSect);
 UnpublishVar(@ShowDebugInfo);
 Inherited;
end;

procedure TBasicGame.DoneGraph;
begin
 Signal('Engine\BeforeDoneGraph');
 painter.Free;
 painter:=nil;
 LogMessage('DoneGraph1');
// if texman<>nil then texman.releaseAll;
// LogMessage('DoneGraph2');
 texman.Free;
 texman:=nil;
 LogMessage('DoneGraph3');
 {$IFDEF MSWINDOWS}
 ShowWindow(window,SW_HIDE);
 {$ENDIF}
 Signal('Engine\AfterDoneGraph');
end;

procedure TBasicGame.FLog(st: string);
var
 v,w:int64;
begin
{ w:=MyTickCount;
 v:=w-FrameStartTime;}
 FrameLog:=FrameLog+{inttostr(w mod 1000)+' '+IntToStr(v mod 1000)+': '+}st+#13#10;
end;

procedure TBasicGame.EnterCritSect;
begin
 EnterCriticalSection(crSect);
end;

procedure TBasicGame.LeaveCritSect;
begin
 LeaveCriticalSection(crSect);
end;

// Инициализация области вывода
procedure TBasicGame.InitGraph;
begin
 Signal('Engine\BeforeInitGraph');
end;


procedure TBasicGame.AfterInitGraph;
begin
 if aspectRatio=0 then begin
  aspectRatio:=params.width/params.height;
 end;
 CalcPixelFormats(BestVidMem);

 LogMessage('Selected pixel formats:');
 LogMessage('      TrueColor: '+PixFmt2Str(pfTrueColor));
 LogMessage(' TrueColorAlpha: '+PixFmt2Str(pfTrueColorAlpha));
 LogMessage('      TrueColorLow: '+PixFmt2Str(pfTrueColorLow));
 LogMessage(' TrueColorAlphaLow: '+PixFmt2Str(pfTrueColorAlphaLow));
 LogMessage('      Indexed: '+PixFmt2Str(pfIndexed));
 LogMessage(' IndexedAlpha: '+PixFmt2Str(pfIndexedAlpha));
 LogMessage(' as render target:');
 LogMessage('       Low: '+PixFmt2Str(pfRTLow));
 LogMessage('    Normal: '+PixFmt2Str(pfRTNorm));
 LogMessage('      High: '+PixFmt2Str(pfRTHigh));
 LogMessage('    AlphaLow: '+PixFmt2Str(pfRTAlphaLow));
 LogMessage(' AlphaNormal: '+PixFmt2Str(pfRTAlphaNorm));
 LogMessage('   AlphaHigh: '+PixFmt2Str(pfRTAlphaHigh));

 ProcessMessages;
 console.ShowMessages:=params.mode<>dmSwitchResolution;
 Signal('Engine\AfterInitGraph');
end;

procedure TBasicGame.InitMainLoop;
begin
 try
  LogMessage('Init main loop');
  InitGraph;
  LastFrameNum:=0;
  LastTickCount:=MyTickCount;
  FrameTime:=MyTickCount;
  LastOnFrameTime:=MyTickCount;
  LastRenderTime:=MyTickCount;
  InitObjects;
  SetupRenderArea;
  painter.LoadFont(defaultFont8);
  painter.LoadFont(defaultFont10);
  // Set global object references
  engineTools.texman:=texman;
  engineTools.painter:=painter;
  engineTools.game:=self;

  Signal('Engine\BeforeMainLoop');
  LogMessage('Game is running...');
  running:=true;
  {$IFDEF ANDROID}
  active:=true; // window is initially active
  {$ENDIF}
 except
  on e:Exception do begin
   ForceLogMessage('Error in InitMainLoop: '+ExceptionMsg(e));
   ErrorMessage(ExceptionMsg(e));
   running:=false;
   {$IFDEF MSWINDOWS}
   ExitProcess(254);
   {$ELSE}
   Halt(254);
   {$ENDIF}
  end;
 end;
end;

function EngineCmdEvent(Event:EventStr;tag:integer):boolean; forward;

function EngineKbdEvent(Event:EventStr;tag:integer):boolean;
var
 code,shiftState,d:integer;
 f:text;
 dm:TDisplayMode;
 st:string;
begin
 result:=false;
 code:=tag and $FFFF;
 shiftState:=tag shr 16;
 if game<>nil then
  with game do begin
   if (shiftState and sscAlt>0) then begin
    d:=0;
    case code of
     VK_F1:d:=1;
     VK_F2:d:=2;
     VK_F3:d:=3;
     VK_F4:d:=4;
     VK_F5:d:=5;
    end;
    if (debugOverlay<>d) then begin
     if d>0 then debugOverlay:=d;
    end else
     debugOverlay:=0;
   end;
   // F12 - скриншот
   if (code=VK_F12) and
      (shiftState and sscAlt=0) then begin
    SaveScreenshotsToJPEG:=(shiftState and 1=0);
    captureSingleFrame:=true;
    screenshotTarget:=2;
   end;

    // Alt+F12 - захват видео
    if (shiftState and sscAlt>0) and
       (code=VK_F12) then begin
     {$IFDEF DELPHI}
     if not videoCaptureMode then begin
      st:=FormatDateTime('MMDD HHNNSS',now)+'.avs';
      game.StartVideoCap(st);
     end else
      FinishVideoCap;
     {$ENDIF}
    end;


   // Alt+F1 - Создание отладочных логов
   if (code=VK_F1) and (shiftState and sscAlt>0) then begin
    assign(f,'framelog.log');
    rewrite(f);
    writeln(f,'Previous:');
    write(f,prevFrameLog);
    writeln(f,'Current:');
    write(f,FrameLog);
    close(f);
    DumpUIdata;
    texman.Dump('User request');
   end;

   // Alt+Enter
   if (code=VK_RETURN) and (shiftstate and sscAlt>0) then
     if (params.mode<>params.altMode) and
        (params.altMode<>dmNone) then begin
       dm:=params.mode;
       params.mode:=params.altMode;
       params.altMode:=dm;
       ChangeSettings(params);
     end;
  end;
end;


function EngineEvent(Event:EventStr;tag:integer):boolean;
var
  t,fr:int64;
  p:TPoint;
procedure Timing;
 var
  t2:int64;
 begin
  t2:=MyTickCount;
  fr:=t2 div 1000;
  if game.timerFrame<>fr then begin
   game.avgTime2:=0;
   game.timerFrame:=fr;
  end;
  game.avgTime2:=game.avgTime2+(t2-t);
 end;

begin
 result:=false;
 if game=nil then exit;
 delete(event,1,7);
 event:=UpperCase(event);
 if event='ONFRAME' then begin
  try
   game.FrameLoop;
  except
   on e:Exception do CritMsg('Error in main loop: '+ExceptionMsg(e));
  end;
 end else
 if event='MAINLOOPINIT' then begin
  game.InitMainLoop;
 end else
 if event='MAINLOOPDONE' then begin
  game.DoneGraph;
 end else
 if event='SINGLETOUCHSTART' then with game do begin
   t:=MyTickCount;
   OldMouseX:=mouseX;
   OldMouseY:=MouseY;
   p:=Point(tag and $FFFF,tag shr 16);
   ScreenToGame(p);
   MouseX:=p.x;
   MouseY:=p.y;
   mouseMoved:=MyTickCount;
   Signal('Mouse\Move',mouseX+mouseY shl 16);
   game.NotifyAboutMouseMove;
   Signal('Mouse\BtnDown\Left',1);
   game.NotifyAboutMouseBtn(1,true);
   sleep(0);
   Timing;
 end else
 if event='SINGLETOUCHMOVE' then with game do begin
   t:=MyTickCount;
   OldMouseX:=mouseX;
   OldMouseY:=MouseY;
   p:=Point(tag and $FFFF,tag shr 16);
   ScreenToGame(p);
   MouseX:=p.x;
   MouseY:=p.y;
   mouseMoved:=MyTickCount;
   Signal('Mouse\Move',mouseX+mouseY shl 16);
   game.NotifyAboutMouseMove;
   Timing;
 end else
 if event='SINGLETOUCHRELEASE' then with game do begin
   t:=MyTickCount;
   Signal('Mouse\BtnUp\Left',1);
   game.NotifyAboutMouseBtn(1,false);
   OldMouseX:=mouseX;
   OldMouseY:=MouseY;
   mouseX:=4095; mouseY:=4095;
   mouseMoved:=MyTickCount;
   Signal('Mouse\Move',mouseX+mouseY shl 16);
   game.NotifyAboutMouseMove;
   Timing;
 end else
 if event='ACTIVATEWND' then begin
  game.active:=(tag<>0);
 end;

 result:=false;
end;

procedure TBasicGame.Run;
var
 i:integer;
begin
 if running then exit;
 game:=self;

 aspectRatio:=0;
 if params.height>0 then
  aspectRatio:=params.width/params.height;
 if params.mode=dmFullScreen then
  aspectRatio:=displayWidth/displayHeight;

 if useMainThread then begin
  {$IFDEF MSWINDOWS}
  loopThread:=TMainThread.Create(true);
  with loopthread as TMainThread do begin
   owner:=self;
  end;
  loopthread.Resume;
  {$ENDIF}
 end else begin
  loopThread:=nil;
  SetEventHandler('Engine\Cmd',EngineCmdEvent,emQueued);
  SetEventHandler('Engine\',EngineEvent,emInstant);
  Signal('Engine\MainLoopInit');
 end;
 SetEventHandler('Kbd\KeyDown',EngineKbdEvent,emInstant);

 for i:=1 to 400 do
  if not running then sleep(50) else break;
// if i=200 then raise EFatalError.Create('Initialization timeout');

 if not running then begin
  ForceLogMessage('Main thread timeout');
  {$IFDEF MSWINDOWS}
   if TMainThread(loopThread).errormsg>'' then ErrorMessage(TMainThread(loopThread).errormsg);
  {$ENDIF}
   raise EFatalError.Create('Can''t run: see log for details.');
 end;
// SetThreadPriority(GetCurrentThread,THREAD_PRIORITY_ABOVE_NORMAL);

 {$IFDEF MSWINDOWS}
 if params.showSystemCursor then begin
  RegisterCursor(crDefault,1,LoadCursor(0,IDC_ARROW));
  RegisterCursor(crLink,2,LoadCursor(0,IDC_HAND));
  RegisterCursor(crWait,9,LoadCursor(0,IDC_WAIT));
  RegisterCursor(crInput,3,LoadCursor(0,IDC_IBEAM));
  RegisterCursor(crHelp,3,LoadCursor(0,IDC_HELP));
  RegisterCursor(crResizeH,5,LoadCursor(0,IDC_SIZENS));
  RegisterCursor(crResizeW,5,LoadCursor(0,IDC_SIZEWE));
  RegisterCursor(crResizeHW,6,LoadCursor(0,IDC_SIZEALL));
 end;
 {$ENDIF}
end;

procedure TBasicGame.StartVideoCap(filename: string);
begin
 {$IFDEF VIDEOCAPTURE}
 if videoCaptureMode then exit;
 videoCaptureMode:=true;
 if pos('\',filename)=0 then filename:=videoCapturePath+filename;
 StartVideoCapture(game,filename);
 {$ENDIF}
end;

procedure TBasicGame.FinishVideoCap;
begin
 {$IFDEF VIDEOCAPTURE}
 if videoCaptureMode then FinishVideoCapture;
 videoCaptureMode:=false;
 {$ENDIF}
end;

procedure TBasicGame.Stop;
var
 i,j:integer;
 h:TThreadID;
 fl:boolean;
begin
 if not running then exit;
 active:=false;

 // Остановить все потоки
 for i:=1 to 16 do
  if (threads[i]<>nil) and (threads[i].running) then
   threads[i].Terminate;

 // подождем...
 for i:=1 to 10 do begin
  fl:=false;
  for j:=1 to 16 do
   if (threads[j]<>nil) and (threads[j].running) then fl:=true;
  if not fl then break;
  sleep(50);
 end;

 // Кто не завершился - я не виноват!
 {$IFDEF MSWINDOWS}
 if fl then
  for i:=1 to 16 do
   if (threads[i]<>nil) and (threads[i].running) then
    TerminateThread(threads[i].Handle,0);
 {$ENDIF}

 if LoopThread=nil then
  Signal('Engine\MainLoopDone')
 else begin
  loopThread.Terminate; // Для экономии времени
  canExitNow:=true;

  {$IFDEF MSWINDOWS}
  // Прибить главный поток (только в случае вызова из другого потока)
  h:=GetCurrentThreadId;
  if h<>loopThread.ThreadID then begin
   // Ждем 2 секунды пока поток не завершится по-хорошему
   for i:=1 to 40 do
    if running then sleep(50);
   // Иначе прибиваем силой
   if running then begin
    Signal('Error\MainThreadHangs');
    TerminateThread(loopThread.Handle,0);
   end;
  end;
  {$ENDIF}
 end;

 active:=false;
end;

procedure TBasicGame.CaptureFrame;
var
 img:TRAWImage;
 n:integer;
 st:string;
 {$IFDEF DELPHI}
 bmp,src:TBitmap;
 {$ENDIF}
 res:ByteArray;
 ext:string;
begin
 if screenshotDataRAW=nil then exit; // объект с данными должен быть создан потомками этого класса
 {$IFDEF VIDEOCAPTURE}
 if videoCaptureMode then begin
  // Передача данных потоку видеосжатия
  if screenshotDataRAW<>nil then StoreFrame(screenshotDataRAW);
 end;
 {$ENDIF}
 case screenshotTarget of
  0:if screenshotDataExt<>nil then begin
   {$IFDEF DELPHI}
   bmp:=TBitmap(screenshotDataExt);
   if (screenshotDataRAW.tag<>0) and
      (TObject(pointer(screenshotDataRAW.tag)) is TBitmap) then begin
    src:=TBitmap(pointer(screenshotDataRAW.tag));
    bmp.Assign(src);
   end;
   Signal('Engine\BitmapCaptured',cardinal(screenshotDataExt));
   {$ENDIF}
  end;
  {$IFDEF MSWINDOWS}
  2:if screenshotDataRAW<>nil then begin
   n:=1;
   if not DirectoryExists('Screenshots') then
    CreateDir('Screenshots');
   if SaveScreenshotsToJPEG then ext:='.jpg' else ext:='.tga';
   st:='Screenshots\'+FormatDateTime('yymmdd_hhnnss',Now)+ext;
   img:=screenshotDataRAW;
   if SaveScreenshotsToJPEG then
     SaveJPEG(img,st,95)
   else begin
    res:=SaveTGA(img);
    WriteFile(st,@res[0],0,length(res));
   end;
   capturedName:=st;
   capturedTime:=MyTickCount;
  end;
  {$ENDIF}
 end;
 if not videoCaptureMode then
  ReleaseFrameData(screenshotDataRaw);
 captureSingleFrame:=false;
end;

procedure TBasicGame.NotifyAboutMouseMove;
var
  i:integer;
begin
 for i:=1 to High(scenes) do
  if (game.scenes[i]<>nil) and
     (game.scenes[i].status=ssActive) and
     not (game.scenes[i] is TUIScene) or
     ((game.scenes[i] is TUIScene) and
      (TUIScene(game.scenes[i]).UI<>nil) and
      (TUIScene(game.scenes[i]).UI.enabled)) then
   game.scenes[i].onMouseMove(mouseX,mouseY);
end;

procedure TBasicGame.NotifyAboutMouseBtn(c:byte;pressed:boolean);
var
  i:integer;
begin
 for i:=1 to length(scenes) do
  if (game.scenes[i]<>nil) and (game.scenes[i].status=ssActive) and
     (game.scenes[i] is TUIScene) and
     (TUIScene(game.scenes[i]).UI.enabled) then
   game.scenes[i].onMouseBtn(c,pressed);
end;


{$IFDEF MSWINDOWS}
function WindowProc(Window:HWnd;Message,WParam:Longint;LParam:LongInt):LongInt; stdcall;
var
 i,c:integer;
 key:cardinal;
 wst:WideString;
 st:string;
 pnt:TPoint;
 scancode:word;
 scene:TGameScene;
begin
 try
 game.EnterCritSect;

 result:=0;
 case Message of
  wm_Destroy: if game<>nil then Signal('Engine\Cmd\Exit',0);

//  WM_SYSKEYUP:begin result:=0; exit; end;
{  WM_SYSKEYDOWN:if game<>nil then with game do begin
    scancode:=(lParam shr 16) and $FF;
    keyState[scanCode]:=keyState[scanCode] or 1;
    Signal('KBD\KeyDown',scancode+shiftstate shl 16);
  end;}

  WM_MOUSEMOVE:if game<>nil then with game do begin
    if not game.params.showSystemCursor then SetCursor(0);
    OldMouseX:=mouseX;
    OldMouseY:=MouseY;
    pnt:=Point(SmallInt(LoWord(lParam)),SmallInt(HiWord(lParam)));
    ClientToScreen(game.window,pnt);
    ScreenToGame(pnt);
    mouseX:=pnt.X;
    mouseY:=pnt.y;
    mouseMoved:=MyTickCount;
    Signal('Mouse\Move',mouseX and $FFFF+(mouseY and $FFFF) shl 16);
    NotifyAboutMouseMove;
    // Если курсор рисуется вручную, то нужно обновить экран
    if MouseVisible and
//       game.params.customCursor and
       not params.showSystemCursor then changed:=true;
  end;

  WM_MOUSELEAVE:if game<>nil then with game do begin
    if MouseVisible and
      not params.showSystemCursor then changed:=true;
    mouseX:=4095;
    mouseY:=4095;
  end;

  WM_UNICHAR:begin
//   LogMessage(inttostr(wparam)+' '+inttostr(lparam));
  end;

  WM_CHAR:if game<>nil then with game do begin
    // Младший байт - код символа, старший - сканкод
    key:=wparam and $FF+(lparam shr 8) and $FF00+wparam shl 16;
    if shiftstate=2 then exit; 
    for i:=1 to length(scenes) do
      if (game.scenes[i]<>nil) and
         (game.scenes[i].status=ssActive) and
         (game.scenes[i] is TUIScene) and
         (TUIScene(game.scenes[i]).UI.enabled) then
           game.scenes[i].WriteKey(key);
    if not unicode then begin
      // Символ в 8-битной кодировке
      Signal('Kbd\Char',key);
      wst:=chr(key and $FF);
      Signal('Kbd\UniChar',word(wst[1])+(lparam and $FF0000));
    end else begin
      // Символ в 16-битном юникоде
      Signal('Kbd\UniChar',wparam and $FFFF+(lparam and $FF0000));
      wst:=WideChar(wparam and $FFFF);
      st:=wst;
      Signal('Kbd\Char',byte(st[1])+key and $FF00);
    end;
  end;

  WM_KEYDOWN,WM_SYSKEYDOWN:if game<>nil then with game do begin
    // wParam = Virtual Code lParam[23..16] = Scancode
    scancode:=(lParam shr 16) and $FF;
    keyState[scanCode]:=keyState[scanCode] or 1;
//    LogMessage('KeyDown: '+IntToStr(wParam));
    Signal('KBD\KeyDown',wParam and $FFFF+shiftstate shl 16+scancode shr 24);
    scene:=TopmostSceneForKbd;
    if scene<>nil then Signal('UI\'+scene.name+'\KeyDown',wparam);
  end;
                    
  WM_KEYUP,WM_SYSKEYUP:if game<>nil then begin
    if wparam=44 then
    begin
     SaveScreenshotsToJPEG:=true;
     game.captureSingleFrame:=true;
     game.screenshotTarget:=2;
    end;
    scancode:=(lParam shr 16) and $FF;
    game.keyState[scanCode]:=game.keyState[scanCode] and $FE;
    Signal('KBD\KeyUp',wParam and $FFFF+game.shiftstate shl 16+scancode shl 24);
    scene:=game.TopmostSceneForKbd;
    if scene<>nil then Signal('UI\'+scene.name+'\KeyUp',wparam);
    if message=WM_SYSKEYUP then begin
     result:=0; exit;
    end;
  end;

  WM_SYSCHAR:if game<>nil then begin
    scancode:=(lParam shr 16) and $FF;
//    Signal('KBD\KeyDown',wParam and $FFFF+game.shiftState shl 16+scancode shl 24);
  end;

  WM_LBUTTONDOWN,WM_RBUTTONDOWN,WM_MBUTTONDOWN:begin
    SetCapture(window);
    if not game.params.showSystemCursor then SetCursor(0);
    c:=0;
    if message=wm_LButtonDown then begin Signal('Mouse\BtnDown\Left',1); c:=1; end;
    if message=wm_RButtonDown then begin Signal('Mouse\BtnDown\Right',2); c:=2; end;
    if message=wm_MButtonDown then begin Signal('Mouse\BtnDown\Middle',4); c:=3; end;
    game.NotifyAboutMouseBtn(c,true);
  end;

  WM_LBUTTONUP,WM_RBUTTONUP,WM_MBUTTONUP:begin
    ReleaseCapture;
    if not game.params.showSystemCursor then SetCursor(0);
    c:=0;
    if message=wm_LButtonUp then begin Signal('Mouse\BtnUp\Left',1); c:=1; end;
    if message=wm_RButtonUp then begin Signal('Mouse\BtnUp\Right',2); c:=2; end;
    if message=wm_MButtonUp then begin Signal('Mouse\BtnUp\Middle',4); c:=3; end;
    game.NotifyAboutMouseBtn(c,false);
  end;

  WM_MOUSEWHEEL:begin
    Signal('Mouse\Scroll',wParam div 65536);
    if game<>nil then with game do begin
     for i:=1 to length(scenes) do
      if (game.scenes[i]<>nil) and
         (game.scenes[i].status=ssActive) and
         (game.scenes[i] is TUIScene) and
         (TUIScene(game.scenes[i]).UI.enabled) then
        with scenes[i] as TUIScene do begin
          onMouseWheel(wParam div 65536);
          if (modalcontrol=nil)or(modalcontrol=UI) then begin
            Signal('UI\'+name+'\MouseWheel',wparam div 65536);
            break;
          end;
        end;
    end;
  end;

  WM_SIZE:if game<>nil then begin
   if game.active and (lParam>0) then begin
    if (game.windowWidth<>lParam and $FFFF) or
       (game.windowHeight<>lParam shr 16) then begin
      game.windowWidth:=lParam and $FFFF;
      game.windowHeight:=lParam shr 16;
      game.SetupRenderArea;
    end;
   end;
  end;

  WM_ACTIVATE:if game<>nil then begin
   if loword(wparam)<>wa_inactive then
    game.active:=true
   else begin
    game.active:=false;
    if game.params.mode=dmFullScreen then game.Minimize;
   end;
   Signal('Engine\ActivateWnd',byte(game.active));
   if game.params.showSystemCursor then
    game.wndCursor:=0;
  end;

  WM_INPUTLANGCHANGEREQUEST:if HookKbdLayout then begin
    ActivateKeyboardLayout(lparam,0);
    exit;
  end;
  WM_HOTKEY:begin                 
             if wparam=312 then
             begin
              SaveScreenshotsToJPEG:=true;
              game.captureSingleFrame:=true;
              game.screenshotTarget:=2;
             end;
            end;
 end;

 if (game<>nil) and (game.unicode) then
  result:=DefWindowProcW(Window,Message,WParam,LParam)
 else
  result:=DefWindowProc(Window,Message,WParam,LParam);
 finally
  game.LeaveCritSect;
 end;
end;

procedure ProcessMessages;
var
 mes:TagMSG;
begin
 if game.unicode then
  while PeekMessageW(mes,0,0,0,pm_NoRemove) do begin
    if not GetMessageW(mes,0,0,0) then
     raise EWarning.Create('Failed to get message');

    if mes.message=wm_quit then // Если послана команда на выход
     Signal('Engine\Cmd\Exit',0);

    TranslateMessage(Mes);
    DispatchMessageW(Mes);
 end else
  while PeekMessage(mes,0,0,0,pm_NoRemove) do begin
    if not GetMessage(mes,0,0,0) then
     raise EWarning.Create('Failed to get message');

    if mes.message=wm_quit then // Если послана команда на выход
     Signal('Engine\Cmd\Exit',0);

    TranslateMessage(Mes);
    DispatchMessage(Mes);
  end;
end;
{$ELSE}
procedure ProcessMessages;
begin
end;
{$ENDIF}

procedure Delay(time:integer);
begin
 {$IFDEF MSWINDOWS}
 if (game<>nil) and (GetCurrentThreadId=game.loopThread.ThreadID) then
  ProcessMessages;
 {$ENDIF}
 HandleSignals;
 while time>100 do begin
  sleep(100);
  time:=time-100;
  {$IFDEF MSWINDOWS}
  if (game<>nil) and
     ((GetCurrentThreadId=game.loopThread.ThreadID) or
      (GetCurrentThreadId=game.controlThread)) then
   Processmessages;
  {$ENDIF}
  HandleSignals;
 end;
 sleep(time);
end;


function TBasicGame.OnFrame:boolean;
var
 i,cnt,v,n:integer;
 deltaTime,time:int64;
 p:pointer;
begin
 result:=false;
 EnterCriticalSection(crSect);
 try
 // Выбор курсора с наименьшим приоритетом (но >0)
{ v:=10000000; n:=0;
 for i:=1 to 32 do
  if cursors[i]<>nil then with cursors[i] as TGameCursor do
   if (priority<v) and (priority>0) then begin
    v:=priority; n:=i;
   end;
 if v<10000000 then begin
  (cursors[n] as TGameCursor).visible:=true;
  if (v>curPrior) and params.customCursor then changed:=true;
 end;}
 // Сортировка сцен
 cnt:=0;
 for i:=1 to length(scenes) do
  if scenes[i]<>nil then inc(cnt);

 if cnt>0 then begin
  for i:=length(scenes)-1 downto 1 do
   for n:=1 to i do
    if (scenes[n]=nil) and (scenes[n+1]<>nil) then begin
     scenes[n]:=scenes[n+1];                                
     scenes[n+1]:=nil;
    end;
  for i:=1 to cnt-1 do
   for n:=cnt downto i+1 do
    if scenes[n].zorder>scenes[n-1].zorder then begin
     p:=scenes[n]; scenes[n]:=scenes[n-1]; scenes[n-1]:=p;
    end;
 end;
 finally
  LeaveCriticalSection(crSect);
 end;
 EnterCriticalSection(UICritSect);
 try
  // Перечисление корневых эл-тов UI в соответствии со сценами
  // (связь сцен и UI)
//  rootControlsCnt:=0;
  for i:=1 to cnt do begin
   if (scenes[i] is TUIScene) then
    with scenes[i] as TUIScene do
     if (UI<>nil) then begin
//      inc(rootControlsCnt);
//      UI.visible:=scenes[i].status=ssActive;
      ui.order:=scenes[i].zorder;
//      rootControls[rootControlsCnt]:=UI;
     end;
  end;
 finally
  LeaveCriticalSection(UICritSect);
 end;
 deltaTime:=MyTickCount-LastOnFrameTime;
 LastOnFrameTime:=MyTickCount;
 // Обработка всех активных сцен
 for i:=1 to length(scenes) do
  if (scenes[i]<>nil) and (scenes[i].status<>ssFrozen) then begin
   // Обработка сцены
   if scenes[i].frequency>0 then begin // Сцена обрабатывается с заданной частотой
    time:=1000 div scenes[i].frequency;
    inc(scenes[i].accumTime,DeltaTime);
    cnt:=0;
    while scenes[i].accumTime>0 do begin
     result:=scenes[i].Process or result;
     dec(scenes[i].accumTime,time);
     inc(cnt);
     if cnt>5 then begin
      scenes[i].accumTime:=0;
      break; // запрет слишком высокой частоты обработки
     end;
    end;
   end else begin
    result:=scenes[i].Process or result;  // обрабатывать каждый раз
   end;
  end;
// LastOnFrameTime:=MyTickCount;
end;

// Устанавливает область отрисовки внутри окна в соответствии с текущими настройками
// При изменении размеров области вывода - адаптирует расположение/размеры сцен
// (которые, в свою очередь, при необходимости корректируют UI)
// Необходимо вызвать ПОСЛЕ инициализации объектов движка 
procedure TBasicGame.SetupRenderArea;
var
 i:integer;
 w,h:integer;
 scale:single;
begin
 w:=0; h:=0;
 case params.fitMode of
  dfmCenter:begin
   w:=params.width;
   h:=params.height;
  end;
  dfmStretch:begin
   w:=windowWidth;
   h:=windowHeight;
  end;
  dfmKeepAspectRatio:begin
   if (windowWidth/params.width)>(windowHeight/params.height) then scale:=windowHeight/params.height
    else scale:=windowWidth/params.width;
   w:=round(params.width*scale);
   h:=round(params.height*scale);
  end;
 end;
 RenderRect:=rect(0,0,w,h);
 types.OffsetRect(RenderRect,(windowWidth-w) div 2,(windowHeight-h) div 2);
// SetWindowArea(w,h);
 SetWindowArea(params.width,params.height);
{ for i:=1 to High(scenes) do
  if scenes[i]<>nil then
   scenes[i].onResize(w,h);
 Signal('ENGINE\RESIZED');}
end;

procedure DrawCursor;
var
 n,i,j:integer;
 c:cardinal;
begin
 with game do begin
  n:=0; j:=-10000;
  if mouseVisible then begin
   for i:=1 to 32 do
    if cursors[i]<>nil then with cursors[i] as TGameCursor do
     if visible and (priority>j) then begin
      j:=priority; n:=i;
     end;

   if not params.showSystemCursor and (n>0) then begin
    // check if cursor is visible
    {$IFDEF MSWINDOWS}

    {$ENDIF}
    painter.BeginPaint(nil);
    try
     DrawImage(TGameCursor(cursors[n]).handle,mouseX,mouseY,$FF808080,0,0,0,0);
    finally
     painter.EndPaint;
    end;
   end
  end;
  if params.showSystemCursor then begin
   c:=wndCursor;
   if n=0 then wndCursor:=0
    else wndCursor:=TGameCursor(cursors[n]).handle;
   {$IFDEF MSWINDOWS}
   SetCursor(wndCursor);
   {$ENDIF}
  end;
  curPrior:=j;
 end;
end;

procedure TBasicGame.RenderFrame;
var
 i,j,n,x,y:integer;
 sc:array[1..50] of TGameScene;
 effect:TSceneEffect;
 DeltaTime:integer;
 fl:boolean;
 z:single;
 s:integer;
// c:cardinal;
 font:cardinal;
 {$IFDEF DELPHI}
 memState:TMemoryManagerState; // real-time memory manager state
 {$ENDIF}
begin
 DeltaTime:=MyTickCount-LastRenderTime;
 LastRenderTime:=MyTickCOunt;
 FLog('RF1');

 // в полноэкранном режиме вывод по центру
 EnterCriticalSection(crSect);
 try
  curTextLink:=0;
  painter.ResetTarget;
  try
  // Очистим экран если нет ни одной background-сцены или они не покрывают всю область вывода
  fl:=true;
  for i:=1 to length(scenes) do
   if (scenes[i]<>nil) and (scenes[i].sceneType=stBackground) and (scenes[i].status=ssActive)
    then fl:=false;
  FLog('Clear '+booltostr(fl));
  if fl or (frameNum and 15=0) then begin
   if params.zbuffer>0 then z:=0 else z:=-1;
   if params.stencil then s:=0 else s:=-1;
   painter.Clear($FF000000,z,s);
  end;
  except
   on e:exception do CritMsg('RFrame1 '+ExceptionMsg(e));
  end;
  FLog('Eff');
  try
  // Обработка эффектов на ВСЕХ сценах
  for i:=1 to length(scenes) do
   if (scenes[i]<>nil) and (scenes[i].effect<>nil) then begin
    FLog('Eff on '+scenes[i].ClassName+' is '+scenes[i].effect.ClassName+' : '+
     inttostr(scenes[i].effect.timer)+','+booltostr(scenes[i].effect.done));
    effect:=scenes[i].effect;
    FLog('Eff ret');
    inc(effect.timer,DeltaTime);
    if effect.done then begin // Эффект завершился
     Signal('ENGINE\EffectDone',cardinal(scenes[i])); // Посылаем сообщение о завершении эффекта
     effect.Free;
     scenes[i].effect:=nil;
    end;
   end;
  except
   on e:exception do CritMsg('RFrame2 '+ExceptionMsg(e));
  end;

// LogMessage('RenderFrame('+inttostr(gettickcount mod 10000)+') {');
 // Sort active scenes by Z order
  FLog('Sorting');
  try
  n:=0;
  for i:=1 to length(scenes) do
   if (scenes[i]<>nil) and (scenes[i].status=ssActive) then begin
    // Сортировка вставкой. Найдем положение для вставки и вставим туда
    if n=0 then begin
     sc[1]:=scenes[i]; inc(n); continue;
    end;
    fl:=true;
    for j:=n downto 1 do
     if sc[j].zorder>scenes[i].zorder then sc[j+1]:=sc[j]
      else begin sc[j+1]:=scenes[i]; fl:=false; break; end;
    if fl then sc[1]:=scenes[i];
    inc(n);
   end;
  except
   on e:exception do CritMsg('RFrame3 '+ExceptionMsg(e));
  end;
  topmostScene:=sc[n];
 finally
  LeaveCriticalSection(crSect); // активные сцены вынесены в отдельный массив - их нельзя удалять в процессе отрисовки
 end;

 // Draw all active scenes
 for i:=1 to n do try
  StartMeasure(i+4);
  // Draw shadow
  if sc[i].shadowColor<>0 then begin
   painter.BeginPaint(nil);
   try
    painter.FillRect(0,0,game.settings.width,game.settings.height,sc[i].shadowColor);
   finally
    painter.EndPaint;
   end;
  end;
  if sc[i].effect<>nil then begin
   FLog('Drawing eff on '+sc[i].name);
   sc[i].effect.DrawScene;
   FLog('Drawing ret');
  end else begin
   painter.BeginPaint(nil);
   try
   FLog('Drawing '+sc[i].ClassName);
   sc[i].Render;
   FLog('Drawing ret');
   finally
    painter.EndPaint;
   end;
  end;
  EndMeasure2(i+4);
 except
  on e:exception do
   if sc[i] is TUIScene then CritMsg('SceneRender '+(sc[i] as TUIScene).name+' error '+ExceptionMsg(e)+' FLog: '+frameLog)
    else CritMsg('SceneRender '+sc[i].ClassName+' error '+ExceptionMsg(e));
 end;

 EnterCriticalSection(crSect);
 try
  FLog('RCursor');
// LogMessage('ScenesDone');
  try  // Вывод курсора
   DrawCursor;
  except
   on e:exception do CritMsg('RFrame4 '+ExceptionMsg(e));
  end;
  FLog('RDebug');

  // Additional output
  try
  if (painter<>nil) and (texman<>nil) and
     ((showDebugInfo>0) or (showFPS) or (debugOverlay>0)) then begin
    painter.BeginPaint(nil);

    if ShowDebugInfo>0 then begin
     font:=painter.GetFont('Default',7);

     painter.TextOut(font,10,20,$FFFFFFFF,inttostr(round(fps)));
   {  for i:=1 to 15 do
      painter.WriteSimple(i*60,10,$FFFFFFFF,FloatToStrF(PerformanceMeasures[i],ffFixed,5,2));}
     if (ShowDebugInfo>1) and (texman<>nil) then begin
      painter.TextOut(font,10,40,$FFFFFFFF,texman.GetStatus(1));
      painter.TextOut(font,10,60,$FFFFFFFF,texman.GetStatus(2));
      painter.TextOut(font,10,80,$FFFFFFFF,GetStatus(1));
     end;
    end else
     case debugOverlay of
      2:TBasicPainter(painter).DebugScreen1;
     end;

    if showFPS or (debugOverlay>0) then begin
     x:=params.width-50; y:=1;
     font:=painter.GetFont('Default',7);
     painter.FillRect(x,y,x+48,y+30,$80000000);
     painter.TextOut(font,x+45,y+10,$FFFFFFFF,FloatToStrF(FPS,ffFixed,5,1),taRight);
     painter.TextOut(font,x+45,y+27,$FFFFFFFF,FloatToStrF(SmoothFPS,ffFixed,5,1),taRight);
    end;

    painter.EndPaint;
  end;
  textLink:=curTextLink;
  textLinkRect:=curTextLinkRect;
  except
   on e:exception do CritMsg('RFrame5 '+ExceptionMsg(e));
  end;

  // Capture screenshot?
  if (CapturedTime>0) and (MyTickCount<CapturedTime+3000) and (painter<>nil) then begin
   painter.BeginPaint(nil);
   try
    painter.SetFont(1);
    x:=game.params.width div 2;
    y:=game.params.height div 2;
    painter.FillRect(x-200,y-40,x+200,y+40,$60000000);
    painter.Rect(x-200,y-40,x+200,y+40,$A0FFFFFF);
    font:=painter.GetFont('Default',7);
    painter.TextOut(font,x,y-24,$FFFFFFFF,'Screen captured to:',engineCls.taCenter);
    painter.TextOut(font,x,y+4,$FFFFFFFF,capturedName,engineCls.taCenter);
   finally
    painter.EndPaint;
   end;
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
 {$IFDEF ANDROID}
 //DebugMessage(framelog);
 {$ENDIF}

 FLog('RDone');
end;

procedure TBasicGame.AddScene(scene: TGameScene);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 // Already added?
 for i:=1 to high(scenes) do
  if scenes[i]=scene then exit;
 // Add
 scene.accumTime:=0;
 for i:=1 to high(scenes) do
  if scenes[i]=nil then begin
   scenes[i]:=scene; exit;
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TBasicGame.RemoveScene(scene: TGameScene);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=1 to length(scenes) do
  if scenes[i]=scene then begin
   scenes[i]:=nil; exit;
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

function TBasicGame.TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene; 
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 result:=nil;
 for i:=1 to length(scenes) do
  if (scenes[i]<>nil) and (scenes[i].status=ssActive) then begin
   if fullscreenOnly and (scenes[i].sceneType=stForeground) then continue;
   if result=nil then
    result:=scenes[i]
   else
    if scenes[i].zorder>result.zorder then result:=scenes[i];
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TBasicGame.MoveWindowTo(x, y, width, height: integer);
var
 r:TRect;
 dx,dy:integer;
begin
 if window=0 then exit;
 {$IFDEF MSWINDOWS}
 getWindowRect(window,r);
 dx:=x-r.left; dy:=y-r.top;
 inc(r.left,dx); inc(r.right,dx);
 inc(r.top,dy); inc(r.Bottom,dy);
 if (width>0) and (height>0) then begin
  r.Right:=r.left+width;
  r.Bottom:=r.top+height;
 end;
 if not MoveWindow(window,r.left,r.top,r.right-r.left,r.Bottom-r.top,true) then
  ForceLogMessage('MoveWindow error: '+inttostr(GetLastError));
 {$ENDIF}
end;

procedure TBasicGame.Minimize;
begin
 {$IFDEF MSWINDOWS}
 ShowWindow(window,SW_MINIMIZE);
 {$ENDIF}
end;

procedure TBasicGame.FireMessage(st: string);
begin

end;

procedure TBasicGame.FlashWindow(count: integer);
begin
 Signal('Engine\Cmd\Flash',count);
end;

procedure TBasicGame.SetWindowCaption(text: string);
var
 wst:WideString;
begin
 {$IFDEF MSWINDOWS}
 if unicode then begin
  wst:=text;
  SetWindowTextW(window,PWideChar(wst))
 end else
  SetWindowText(window,PChar(text));
 {$ENDIF}
end;

procedure TBasicGame.ScreenToGame(var p:TPoint);
 begin
  {$IFDEF MSWINDOWS}
  ScreenToClient(window,p);
  p.X:=round((p.X-RenderRect.Left)*settings.width/(RenderRect.Right-RenderRect.Left));
  p.Y:=round((p.Y-RenderRect.top)*settings.height/(RenderRect.Bottom-RenderRect.Top));
  {$ENDIF}
 end;

procedure TBasicGame.GameToScreen(var p:TPoint);
 begin
  {$IFDEF MSWINDOWS}
  p.X:=round(RenderRect.Left+p.X*(RenderRect.Right-RenderRect.Left)/settings.width);
  p.Y:=round(RenderRect.top+p.Y*(RenderRect.Bottom-RenderRect.Top)/settings.height);
  ClientToScreen(window,p);
  {$ENDIF}
 end;

{$IFDEF FPC}
{$IFDEF MSWINDOWS}
const
  FLASHW_STOP = $0;
  FLASHW_CAPTION = $1;
  FLASHW_TRAY = $2;
  FLASHW_ALL = FLASHW_CAPTION or FLASHW_TRAY;
  FLASHW_TIMER = $4;
  FLASHW_TIMERNOFG = $C;
type
 TFlashWInfo = packed record
  cbSize: DWORD;
  hwnd: HWND;
  dwFlags: DWORD;
  uCount: DWORD;
  dwTimeout: DWORD;
 end;
function FlashWindowEx(var pfwi: TFlashWInfo): LongBool; stdcall; external 'user32' Name 'FlashWindowEx';
{$ENDIF}
{$ENDIF}

// Обработка событий, являющихся командами движку
function EngineCmdEvent(event:EventStr;tag:integer):boolean;
var
{$IFDEF MSWINDOWS}
 fi:TFlashWInfo;
{$ENDIF}
 pnt:TPoint;
begin
 result:=false;
 delete(event,1,length('Engine\Cmd\'));
 event:=UpperCase(event);
 if game=nil then exit;
 if event='CHANGESETTINGS' then game.ApplySettings;
 if event='EXIT' then
  if game.loopThread<>nil then
   game.loopThread.Terminate;

 {$IFDEF DELPHI}
 if event='MAKESCREENSHOT' then begin
  game.WantToCaptureSingleFrame(false,TRAWImage(pointer(tag)));
  exit;
 end;
 {$ENDIF}

 {$IFDEF MSWINDOWS}
 if event='UPDATEMOUSEPOS' then begin
   GetCursorPos(pnt);
   game.ScreenToGame(pnt);
//   ScreenToClient(engineCls.windowHandle,pnt);
   tag:=pnt.X+pnt.Y shl 16;
   Signal('Mouse\Move',tag);
 end;
 if event='FLASH' then begin
  fillchar(fi,sizeof(fi),0);
  fi.cbSize:=sizeof(fi);
  fi.hwnd:=game.window;
  fi.dwTimeout:=400;
  if tag=-1 then
   fi.dwFlags:=FLASHW_STOP
  else
   fi.dwFlags:=FLASHW_ALL+FLASHW_TIMERNOFG*byte(tag=0);
  if tag<=0 then tag:=100;
  fi.uCount:=tag;
  FlashWindowEx(fi);
 end;
 {$ENDIF}
end;

procedure TBasicGame.ShowMouse(m: boolean);
begin
 if m=mousevisible then exit;
 mouseVisible:=m;
 WndCursor:=0;
 if not params.showSystemCursor then changed:=true;
end;

procedure TBasicGame.RegisterCursor(CursorID, priority: integer;
  cursorHandle: cardinal);
var
 i,n:integer;
 cursor:TGameCursor;
begin
 EnterCriticalSection(crSect);
 try
 n:=0;
 for i:=1 to 32 do
  if (cursors[i]<>nil) and
     (TGameCursor(cursors[i]).ID=cursorID) then begin
    n:=i; break;
  end;
 if n=0 then
  for i:=1 to 32 do
   if (cursors[i]=nil) then begin
    n:=i; break;
   end;

 if cursors[n]=nil then begin
  cursor:=TGameCursor.Create;
  cursors[n]:=cursor;
 end else
  cursor:=TGameCursor(cursors[i]);
 cursor.ID:=CursorID;
 cursor.priority:=priority;
 cursor.handle:=cursorHandle;
 cursor.visible:=false;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TBasicGame.ResetAllCursors;
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=1 to 32 do
  if cursors[i]<>nil then
   with cursors[i] as TGameCursor do
    visible:=false;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TBasicGame.ToggleCursor(CursorID: integer; state: boolean);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=1 to 32 do
  if cursors[i]<>nil then
   with cursors[i] as TGameCursor do
    if ID=CursorID then visible:=state;
 if not params.showSystemCursor then changed:=true;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

function TBasicGame.TopmostSceneForKbd: TGameScene;
var
 i:integer;
 maxZ:integer;
 sc:TUIScene;
begin
 EnterCriticalSection(crSect);
 try
  result:=nil;
  maxZ:=-10000000;
  for i:=1 to length(scenes) do
   if (scenes[i]<>nil) and
      (scenes[i].status=ssActive) and
      not scenes[i].ignoreKeyboardEvents then begin
    // UI Scene?
    if scenes[i] is TUIScene then begin
     sc:=TUIScene(scenes[i]);
     if not sc.UI.enabled then exit;
     if (modalControl<>nil) and not modalControl.HasParent(sc.UI) then exit;
    end;
    // Topmost?
    if scenes[i].zorder>maxZ then begin
     result:=scenes[i];
     maxZ:=scenes[i].zorder;
    end;
   end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

function TBasicGame.GetThreadResult(h: THandle): integer;
var
 i:integer;
begin
 result:=-2;
 EnterCriticalSection(RA_sect);
 try
 for i:=1 to 16 do
  if (threads[i]<>nil) and (threads[i].id=h) then begin
   if threads[i].running then result:=0  // еще выполняется
    else result:=threads[i].ReturnValue;
   exit;
  end;
 finally
  LeaveCriticalSection(RA_sect);
 end;
end;

function TBasicGame.RunAsync(threadFunc:pointer; param:cardinal; ttl: single;name:string): THandle;
var
 i,best:integer;
 t:int64;
begin
 result:=0;
 best:=0; t:=mytickcount;
 EnterCriticalSection(RA_Sect);
 try
 for i:=1 to 16 do
  if threads[i]=nil then begin best:=i; break; end
   else
    if (not threads[i].running) and (threads[i].FinishTime<t) then
     begin t:=threads[i].FinishTime; best:=i; end;

 if best=0 then raise EError.Create('Can''t start new thread - no free handles!');
 if threads[best]<>nil then threads[best].Free;
 threads[best]:=TCustomThread.Create(true);
 if ttl>0 then threads[best].timetokill:=Mytickcount+round(ttl*1000)
  else threads[best].TimeToKill:=$FFFFFFFF;
 threads[best].running:=true;
 threads[best].func:=threadFunc;
 threads[best].param:=param;
 if name='' then name:=inttohex(cardinal(threadFunc),8);
 threads[best].name:='RA_'+name;
 inc(LastThreadID);
 threads[best].id:=lastThreadID;
 threads[best].Resume;
 result:=lastThreadID;
 finally
  LeaveCriticalSection(RA_Sect);
 end;
 LogMessage('[RA] thread launched, pos='+inttostr(best)+', id='+inttostr(result)+
   ', func='+inttohex(integer(threadFunc),8)+', time: '+inttostr(threads[best].TimeToKill),8);
end;

procedure TBasicGame.FrameLoop;
 var
  i:integer;
  ticks:int64;
  t:int64;
  mb:byte;
 begin
   t:=MyTickCount;
    PingThread;
    // Обновление ввода с клавиатуры (и кнопок мыши)
    {$IFDEF MSWINDOWS}
    shiftstate:=0; mb:=0;
    if GetAsyncKeyState(VK_SHIFT)<0 then inc(shiftState,1);
    if GetAsyncKeyState(VK_CONTROL)<0 then inc(shiftState,2);
    if GetAsyncKeyState(VK_MENU)<0 then inc(shiftState,4);
    if (GetAsyncKeyState(VK_LWIN)<0) or
       (GetAsyncKeyState(VK_RWIN)<0) then inc(shiftState,8);
    if GetAsyncKeyState(VK_LBUTTON)<0 then inc(mb,1);
    if GetAsyncKeyState(VK_RBUTTON)<0 then inc(mb,2);
    if GetAsyncKeyState(VK_MBUTTON)<0 then inc(mb,4);
    if mb<>mouseButtons then begin
     oldMouseButtons:=mouseButtons;
     mouseButtons:=mb;
    end;
    {$ENDIF}

    for i:=0 to High(keyState) do keyState[i]:=keyState[i] shl 1;
    StartMeasure(14);
    ProcessMessages;
    if active then try
     HandleSignals;
    except
     on e:exception do ForceLogMessage('Error in FrameLoop 1: '+ExceptionMsg(e));
    end else
     Delay(20);
    EndMeasure2(14);

    // Расчет fps
    ticks:=GetTickCount;
    if (ticks>LastTickCount+500) and (lastTickCount<>0) then begin
     FPS:=(1000*(framenum-LastFrameNum)/(ticks-LastTickCount));
     SmoothFPS:=SmoothFPS*0.9+FPS*0.1;
     LastFrameNum:=FrameNum;
     LastTickCount:=ticks;
    end;

    i:=MyTickCount-FrameTime;
    if i>500 then
     LogMessage('Warning: main loop stall for '+inttostr(i)+' ms');
    FrameTime:=MyTickCount;

    // Обработка кадра
    FrameStartTime:=MyTickCount;
    StartMeasure(3);
    if OnFrame then changed:=true; // это чтобы можно было и в других местах выставлять флаг!
    EndMeasure(3);
    try
     HandleSignals;
    except
     on e:exception do ForceLogMessage('Error in FrameLoop 2: '+ExceptionMsg(e));
    end;

    if active or (params.mode<>dmSwitchResolution) then begin
     // Если программа активна, то выполним отрисовку кадра
     if changed and initialized then begin
      try
       PrevFrameLog:=frameLog;
       frameLog:='';
       StartMeasure(2);
       RenderFrame;
       EndMeasure2(2);
      except
       on E:Exception do CritMsg('Error in renderframe: '+ExceptionMsg(e)+' framelog: '+framelog);
      end;
     end;
    end;

    // Здесь можно что-нибудь сделать
    Sleep(onFrameDelay);
    // Обработка thread'ов
    EnterCriticalSection(RA_sect);
    try
    for i:=1 to 16 do
     if threads[i]<>nil then with threads[i] do
      if threads[i].running and (timetokill<MyTickCount) then begin
       ForceLogMessage(timestamp+' ALERT: thread terminated by timeout, '+inttohex(cardinal(@func),8)+
        ', curtime: '+inttostr(MyTickCount));
       {$IFNDEF IOS}
       TerminateThread(Handle,0);
       {$ENDIF}
       ReturnValue:=-1;
       Signal('Engine\thread\done\'+inttohex(cardinal(@func),8),-1);
       Signal('Error\Thread TimeOut',0);
       threads[i].running:=false;
     end;
    finally
     LeaveCriticalSection(RA_sect);
    end;

    // Теперь нужно вывести кадр на экран
    if (active or (params.mode<>dmSwitchResolution)) and
       changed and
       initialized then begin
     PresentFrame;
     {$IFDEF DELPHI}
     if captureSingleFrame or videoCaptureMode then
      CaptureFrame;
     {$ENDIF}
    end else
     sleep(5);
    game.Flog('LEnd');
  t:=MyTickCount-t;
  if t<500 then avgTime:=avgTime*0.9+t*0.1;
 end;

 // Создать окно
 procedure TBasicGame.CreateMainWindow;
  {$IFDEF MSWINDOWS}
  var
   WindowClass:TWndClass;
   style:cardinal;
   i:integer;
  begin
   LogMessage('CreateMainWindow');
   with WindowClass do begin
    Style:=cs_HRedraw or cs_VRedraw;
    lpfnWndProc:=@WindowProc;
    cbClsExtra:=0;
    cbWndExtra:=0;
    hInstance:=0;
    hIcon:=LoadIcon(MainInstance,'MAINICON');
    WndCursor:=0;//LoadCursor(0, idc_Arrow);
    hCursor:=WndCursor;
    hbrBackground:=GetStockObject (Black_Brush);
    lpszMenuName:='';
    lpszClassName:='GameWindowClass';
   end;
   If windows.RegisterClass(WindowClass)=0 then
    raise EFatalError.Create('Cannot register window class');

   style:=0;
   Window:=CreateWindow('GameWindowClass', PChar(settings.title),
    style, 0, 0, 100, 100, 0, 0, HInstance, nil);
   //EngineCls.windowHandle:=window;
   if unicode then begin
    SetWindowLongW(window,GWL_WNDPROC,cardinal(@WindowProc));
    SetWindowCaption(settings.title);
   end;

   Layouts:=GetKeyboardLayoutList(10,LayoutList);
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

 procedure TBasicGame.ConfigureMainWindow;
  {$IFDEF MSWINDOWS}
  var
   r,r2:TRect;
   style:cardinal;
   w,h:integer;
  begin
   style:=ws_popup;
   if params.mode=dmWindow then inc(style,WS_SIZEBOX+WS_MAXIMIZEBOX);
   if params.mode in [dmWindow,dmFixedWindow] then
    inc(style,ws_Caption+WS_MINIMIZEBOX+WS_SYSMENU);

   SystemParametersInfo(SPI_GETWORKAREA,0,@r2,0);

   w:=params.width;
   if (MaxWindowWidth>0) and (w>MaxWindowWidth) then w:=MaxWindowWidth;
   h:=params.height;
   if (MaxWindowHeight>0) and (h>MaxWindowHeight) then h:=MaxWindowHeight;
   // Центрирование окна в области десктопа
   r.Left:=(r2.Right-r2.left-params.width) div 2;
   r.Top:=(r2.Bottom-r2.Top-params.height+
     GetSystemMetrics(SM_CYCAPTION)) div 2;
   r.right:=r.left+w;
   r.Bottom:=r.top+h;
   AdjustWindowRect(r,style,false);

   if params.mode=dmFullScreen then begin
    r.Left:=0; r.Top:=0;
    r.Right:=displayWidth; r.bottom:=displayHeight;
   end;

   if params.mode<>dmSwitchResolution then begin
    // Определим, можно ли использовать рамку окна
    if (r.Right-r.left>displayWidth+20) or (r.bottom-r.top>DisplayHeight) then begin
     // Окно с рамкой не влезает -> сделать окно без рамки на весь экран
{     scale:=DisplayWidth/params.width;
     scale2:=DisplayHeight/params.height;
     if scale2<scale then scale:=scale2;
     r.Right:=round(params.width*scale);
     r.bottom:=round(params.height*scale);
     r.left:=0; r.top:=0;}
     // Временно убираем
     SetWindowLong(window,GWL_STYLE,integer(ws_popup)); // убираем все элементы рамки
     MoveWindowTo(0,0,displayWidth,displayHeight);
    end else begin
     // Окно с рамкой помещается
{     style:=ws_popup+ws_Caption+WS_MINIMIZEBOX+WS_SYSMENU;
     if params.mode=dmWindow then style:=style+WS_SIZEBOX+WS_MAXIMIZEBOX;}
     SetWindowLong(window,GWL_STYLE,style);
     MoveWindowTo(r.left,r.top,r.Right-r.left,r.Bottom-r.top);
    end;
    SetWindowPos(window,HWND_NOTOPMOST,0,0,0,0,SWP_NOSIZE+SWP_NOMOVE);
   end else begin
    // полный экран с переключением режима
    SetWindowLong(window,GWL_STYLE,integer(ws_popup));
    MoveWindowTo(0,0,displayWidth,displayHeight);
   end;
   ShowWindow(Window, SW_SHOW);
   UpdateWindow(Window);
   ShowMouse(true);

   GetWindowRect(window,r);
   LogMessage('WindowRect: '+inttostr(r.Right-r.Left)+':'+inttostr(r.Bottom-r.top));
   GetClientRect(window,r);
   LogMessage('ClientRect: '+inttostr(r.Right-r.Left)+':'+inttostr(r.Bottom-r.top));
   windowWidth:=r.Right-r.Left;
   windowHeight:=r.Bottom-r.top;
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

 procedure TBasicGame.DestroyMainWindow;
  begin
   {$IFDEF MSWINDOWS}
   ShowWindow(window,SW_HIDE);
   DestroyWindow(window);
   UnregisterClassA('GameWindowClass',0);
   {$ENDIF}
  end;

{ TCustomThread }
procedure TCustomThread.Execute;
begin
 LogMessage('CustomThread '+name+' started!');
 RegisterThread(name);
 running:=true;
 try
  ReturnValue:=func(param);
  LogMessage('CustomThread done');
 except
  on e:exception do ForceLogMessage('RunAsync: failure - '+ExceptionMsg(e));
 end;
 FinishTime:=MyTickCount;
 running:=false;
 Signal('engine\thread\done\'+PtrToStr(@func),ReturnValue);
 UnregisterThread;
end;


{ TMainThread }
procedure TMainThread.Execute;
begin
 // Инициализация
 errorMsg:='';
 try
  LogMessage(TimeStamp+' Main thread started - '+inttostr(cardinal(GetCurrentThreadID)));
  RegisterThread('MainThread');
  LogMessage(GetSystemInfo);
  {$IFDEF MSWINDOWS}
  owner.CreateMainWindow;
  {$ENDIF}
  SetEventHandler('Engine\Cmd',EngineCmdEvent,emQueued);
  owner.InitMainLoop; // вызывает InitGraph
  owner.running:=true; // Это как-бы семафор для завершения функции Run
  LogMessage('MainLoop started');
  // Главный цикл
  repeat
   try
    owner.FrameLoop;
   except
    on e:Exception do CritMsg('Error in main loop: '+ExceptionMsg(e));
   end;
  until terminated;
  owner.terminated:=true;
  Signal('Engine\AfterMainLoop');

  // Состояние ожидания команды остановки потока из безопасного места
  while not owner.canExitNow do sleep(20);

  // Финализация
  {$IFDEF MSWINDOWS}
  owner.DestroyMainWindow;
  {$ENDIF}
  owner.DoneGraph;
 except
  on e:Exception do begin
   errorMsg:=ExceptionMsg(e);
   CritMsg('Global error: '+ExceptionMsg(e));
  end;
 end;

 UnregisterThread;
 owner.running:=false; // Эта строчка должна быть ПОСЛЕДНЕЙ!
end;

initialization
 InitCritSect(RA_sect,'Game_RA',110);
 PublishVar(@onFrameDelay,'onFrameDelay',TVarTypeInteger);
end.
