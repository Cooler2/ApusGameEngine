// Main runtime unit of the engine
//
// IMPORTANT: Nevertheless DXGame is implemented as class, it is
//            NOT thread-safe itself i.e. does not allow multiple instances!
//            (at least between Run/Stop calls)
//            If you want to access private data (buffers, images) from other
//            threads, use your own synchronization methods
//
// Copyright (C) 2003 Apus Software (www.games4win.com, www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by)
unit SDLgame;
interface
 uses CrossPlatform,SDLmini,EngineCls,Images,engineTools,classes,myservis;

var
 // Перехват переключения раскладки клавиатуры (защита от зависания)
 HookKbdLayout:boolean=false;
 MaxWindowWidth:integer=10000;
 MaxWindowHeight:integer=10000;

type
 // Это важная структура, задающая параметры работы движка
 // На ее основе движок будет конфигурировать другие объекты, например device
 // Важно понимать смысл каждого ее поля, хотя не обязательно каждое из них будет учтено
 TGameSettings=record
  title:string;  // Заголовок окна/программы
  width,height:integer; // Размер окна/экрана
  colorDepth:integer; // глубина цвета (16/24/32)
  refresh:integer;   // Частота регенерации экрана (0 - default)
  windowed:boolean; // Оконный режим?
  showSystemCursor:boolean; // Показывать ли системный курсор?
  zbuffer:byte; // желательная глубина z-буфера (0 - не нужен)
  stencil:boolean; // нужен ли stencil-буфер (8-bit)
  HW_TL:boolean; // использовать аппаратный T&L (если есть)
  multisampling:byte; // включить мультисэмплинг (fs-антиалиасинг) - кол-во сэмплов (<2 - отключен)
  slowmotion:boolean; // true - если преобладают медленные сцены или если есть большой разброс
                      // в скорости - тогда возможна (но не гарантируется) оптимизация перерисовки
  HW_cursor:boolean; // если truе, то по событиям от мыши курсор будет перемещаться
 end;

 // Функция для параллельного исполнения
 TThreadFunc=function(param:cardinal):integer;

 // Основной класс. Можно использовать его напрямую, но лучше унаследовать
 // от него свой собственный и определить для него события
 TSDLGame=class
  constructor Create(vidmem:integer); // Создать экземпляр (желательный объем видеопамяти под текстуры в мегабайтах)
  procedure Run; // запустить движок (создание окна, переключение режима и пр.)
  procedure Stop; // остановить и освободить все ресурсы (требуется повторный запуск через Run)
  destructor Destroy; virtual; // автоматически останавливает, если это не было сделано

  // Управление параметрами во время работы
  // Задать новые размеры/положение окна
  procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0); virtual;
  procedure SetWindowCaption(text:string); virtual; // Сменить заголовок (оконный режим)
  procedure Minimize; // свернуть окно (полезно в полноэкранном режиме)

  // Events
  // Этот метод вызывается из главного цикла всякий раз перед попыткой рендеринга кадра, даже если программа неактивна или девайс потерян
  function OnFrame:boolean; virtual; // true означает что на экране что-то должно изменится поэтому экран нужно перерисовать. Иначе перерисовка выполнена не будет (движение мыши отслеживается отдельно)
  procedure RenderFrame; virtual; // этот метод должен отрисовать кадр в backbuffer
  function OnRestore:boolean; virtual; // Этот метод должен восстановить девайс и вернуть true если это удалось

  // Сцены
  procedure AddScene(scene:TGameScene); virtual;    // Добавить сцену в список сцен
  procedure RemoveScene(scene:TGameScene); virtual;  // Убрать сцену из списка сцен

  // Курсоры
  procedure RegisterCursor(CursorID,priority:integer;CursorImage:string); // Объявить курсор
  procedure ToggleCursor(CursorID:integer;state:boolean=true); // Включить/выключить указанный курсор
  procedure ResetAllCursors; // Выключить все курсоры

  // Потоки
  // Запустить функцию на параллельное выполнение (ttl - лимит времени в секундах, если есть)
  // По завершению будет выдано событие engine\thread\done с кодом, возвращенным ф-цией, либо -1 если завершится по таймауту
  function RunAsync(threadFunc:pointer;param:cardinal;ttl:single=0;name:string=''):THandle;
  // Функция все еще выполняется? если да - вернет 0,
  // если прервана по таймауту - -1, если неверный хэндл - -2, иначе - результат функции
  function GetThreadResult(h:THandle):integer;

  procedure FLog(st:string);
 protected
  running:boolean;
  canExitNow:boolean; // флаг того, что теперь можно начать деинициализацию
  params:TGameSettings;
  loopThread:TThread;
  BestVidMem,VidmemLimit:integer;
  cursors:array[1..32] of TObject;

  LastOnFrameTime:cardinal; // момент последнего вызова обработки кадра
  LastRenderTime:cardinal; // Момент последней отрисовки кадра
  capturedName:string;
  capturedTime:cardinal;

  shiftstate:byte; // состояние клавиш сдвига

  crSect:TMyCriticalSection;

  procedure ChangeSettings(s:TGameSettings); virtual; // этот метод служит для изменения режима или его параметров
  procedure ApplySettings; virtual;
  procedure ShowMouse(m:boolean); virtual; // управление курсором мыши (системным либо своим)

  // Эти методы используются при смене режима работы (вызов только из главного потока)
  procedure InitGraph; virtual; // Инициализация графической части (переключить режим и все такое прочее)
  procedure DoneGraph; virtual; // Финализация графической части

 public
  // Глобально доступные переменные
  window:TSDL_Window;
  context:TSDL_GLContext;
  terminated:boolean;   // Работа цикла завершена, можно начинать деинициализацию и выходить
  ScreenRect:TRect;      // область вывода в окне (после инициализации - все окно)
  active:boolean;       // Окно активно, цикл перерисовки выполняется
  paused:boolean;       // Режим паузы (изначально сброшен, движком не изменяется и не используется)
  initialized:boolean;  // Завершена ли инициализация (если нет - перерисовка запрещена)
  changed:boolean;      // Нужно ли перерисовывать экран (аналог результата onFrame, только можно менять в разных местах)
  mouseVisible:boolean; // курсор мыши включен
  FrameNum:integer;     // Номер кадра
  FPS:single;
  ShowDebugInfo:integer; // Кол-во строк отладочной инфы
  FrameLog,prevFrameLog:string;
  FrameStartTime:int64;

  keystate:array[0..1023] of byte; // 0-й бит - клавиша нажата, 1-й - была нажата в пред. раз
  mouseX,mouseY:integer; // положение мыши внутри окна/экрана
  OldMouseX,OldMouseY:integer; // предыдущее положение мыши
  mouseButtons:byte;     // Флаги "нажатости" кнопок мыши (0-левая, 1-правая, 2-средняя)
  OldMouseButtons:byte;

  // параметры выставляются при смене режима, указыают что именно изменялось
  resChanged,pfChanged:boolean;
  scenes:array[1..50] of TGameScene;
  topmostScene:TGameScene;

  // properties
  property Settings:TGameSettings read params write ChangeSettings;
  property mouseOn:boolean read mouseVisible write ShowMouse;
  property IsRunning:boolean read running;
 end;

 // Для использования из главного потока
 procedure ProcessMessages;
 procedure Delay(time:integer);

implementation
 uses SysUtils,dglOpenGL,cmdproc{$IFDEF DELPHI},graphics{$ENDIF},
     GlImages,EventMan,ImageMan,UIClasses,CommonUI,gfxformats,
     Console,painterGL;

type
 TMainThread=class(TThread)
  owner:TSDLGame;
  procedure Execute; override;
 end;

 TCustomThread=class(TThread)
  id:integer;
  TimeToKill:cardinal;
  running:boolean;
  func:TThreadFunc;
  FinishTime:cardinal;
  param:cardinal;
  name:string;
  procedure Execute; override;
 end;

 TGameCursor=class
  ID:integer;
  priority:integer;
  image:THandle;
  visible:boolean;
 end;

var
 game:TSDLGame; // указатель на текущий объект игры (равен owner'у главного потока)
 // Для расчета FPS
 LastFrameNum:integer;
 LastTickCount:integer;

 curPrior:integer; // приоритет текущего отображаемого курсора

 keytimer:cardinal;
 keycode:integer; // для повторения нажатий

 lastThreadID:integer;
 threads:array[1..16] of TCustomThread;
 RA_sect:TMyCriticalSection;

 // ссылки-копии объектов - нужны потому что тут используются более конкретные типы,
 // привязанные к версии API
 texman:TGLTextureMan;
 painter:TGLPainter;

 // Определить форматы пикселя для загружаемых изображений с учетом
 // а) рекомендуемого объема видеопамяти для игры
 // б) возможностей железа
 procedure CalcPixelFormats(needMem:integer); forward;

 procedure testSDLerror;
  var
   error:PChar;
  begin
   error:=SDL_GetError;
   if error<>'' then
    raise EError.Create('SDL Error: '+error);   
  end;

{ TSDLGame }

procedure TSDLGame.ChangeSettings(s: TGameSettings);
begin
 resChanged:=(s.width<>params.width) or (s.height<>params.height);
 pfChanged:=s.colorDepth<>params.colorDepth;
 params:=s;

 if running and (GetCurrentThreadID<>loopThread.ThreadID) then begin
  // Вызов из другого потока - синхронизируем!
  Signal('Engine\cmd\ChangeSettings');
  exit;
 end else
  ApplySettings;
end;

procedure TSDLGame.ApplySettings;
var
 i:integer;
begin
 if running then begin // смена параметров во время работы
  //if texman<>nil then (texman as TDXTextureMan).releaseAll;
  Signal('Debug\Settings Changing');
 end;
 if running then begin
  InitGraph;
  //if texman<>nil then (texman as TDXTextureMan).ReCreateAll;
  if painter<>nil then (painter as TGLPainter).Reset;
  for i:=1 to length(scenes) do
   if scenes[i]<>nil then scenes[i].ModeChanged;
 end;
end;

constructor TSDLGame.Create;
begin
 running:=false;
 canExitNow:=false;
 terminated:=false;
 active:=false;
 paused:=false;
 initialized:=false;
 loopThread:=nil;
 FrameNum:=0;
 window:=nil;
 fps:=0;
 ShowDebugInfo:=0;
 fillchar(keystate,sizeof(keystate),0);
 BestVidMem:=VidMem;
 InitCritSect(crSect,'SDLGame');
 PublishInt('ShowDebugInfo',showDebugInfo);
 fillchar(scenes,sizeof(scenes),0);
end;

destructor TSDLGame.Destroy;
begin
 if running then Stop;
 DeleteCritSect(crSect);
 DeleteVariable('ShowDebugInfo');
end;

procedure TSDLGame.DoneGraph;
begin
 Signal('Engine\BeforeDoneGraph');
 painter.Free;
 painter:=nil;
 LogMessage('DoneGraph1');
 texman.Free;
 texman:=nil;
 LogMessage('DoneGraph3');
 SDL_DestroyWindow(window);
 Signal('Engine\AfterDoneGraph');
end;

procedure TSDLGame.FLog(st: string);
var
 v,w:int64;
begin
 FrameLog:=FrameLog+st+#13#10;
end;

// Эта процедура пытается установить запрошенный видеорежим
// В случае ошибки она просто бросит исключение
procedure TSDLGame.InitGraph;
var
 pf,displayWidth,displayHeight:integer;
 r,displayRect:Trect;
 scale,scale2:single;
begin
 Signal('Engine\BeforeInitGraph');
 // Установить размеры окна и включить его
 ScreenRect:=rect(0,0,params.width,params.height);
 SetWindowArea(params.width,params.height,screenRect);

 SDL_GL_SetAttribute(SDL_GL_RED_SIZE,8);
 SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,8);
 SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,8);
 SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
 SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);

 SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
 SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 8);
 testSDLerror;

 if params.windowed then begin
  window:=SDL_CreateWindow('',SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,
    params.width,params.height,SDL_WINDOW_OPENGL);
 end else begin

 end;
 if window=nil then raise EError.Create('Failed to create main window');
 ShowMouse(true);

 // OpenGL activation
 context:=SDL_GL_CreateContext(window);
 testSDLerror;
 InitOpenGL;
 ReadOpenGLCore;

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
 console.ShowMessages:=params.windowed;
 Signal('Engine\AfterInitGraph');
end;

procedure TSDLGame.Run;
var
 i:integer;
begin
 if running then exit;
 loopThread:=TMainThread.Create(true);
 with loopthread as TMainThread do begin
  owner:=self;
 end;
 game:=self;

 loopthread.Resume;
 for i:=1 to 200 do
  if not running then sleep(50) else break;
 if i=200 then raise EFatalError.Create('Initialization timeout');

 if not running then
   raise EFatalError.Create('Can''t run: see log for details.');
// SetThreadPriority(GetCurrentThread,THREAD_PRIORITY_ABOVE_NORMAL);
end;

procedure TSDLGame.Stop;
var
 i,j:integer;
 h:integer;
 fl:boolean;
begin
 if not running then exit;

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
 if fl then
  for i:=1 to 16 do
   if (threads[i]<>nil) and (threads[i].running) then
    TerminateThread(threads[i].Handle,0);

 loopThread.Terminate; // Для экономии времени
 canExitNow:=true;

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

 active:=false;
end;


procedure HandleEvent(event:TSDL_Event);
var
 i,c:integer;
 pnt,pnt2:TPoint;
begin
 if game=nil then exit;
 case event.type_ of
  SDL_WINDOWEVENT:begin
   if event.windowEvent.event in
     [SDL_WINDOWEVENT_SHOWN,SDL_WINDOWEVENT_RESTORED] then game.active:=true;
   if event.windowEvent.event in
     [SDL_WINDOW_HIDDEN,SDL_WINDOWEVENT_MINIMIZED] then game.active:=false;
  end;

  SDL_MOUSEMOTION:with game do begin
    OldMouseX:=mouseX;
    OldMouseY:=MouseY;
    mouseX:=event.mouseMotion.x;
    mouseY:=event.mouseMotion.y;
    Signal('Mouse\Move',mouseX+mouseY shl 16);
    EnterCriticalSection(crSect);
    try
    for i:=1 to 50 do
     if (game.scenes[i]<>nil) and
        (game.scenes[i].status=ssActive) and
        (game.scenes[i] is TUIScene) and
        (TUIScene(game.scenes[i]).UI.enabled) then
      game.scenes[i].onMouseMove(mouseX,mouseY);
    finally
     LeaveCriticalSection(crSect);
    end;
  end;

  SDL_MOUSEBUTTONDOWN:with game do begin
   if event.mouseButton.button=SDL_BUTTON_LEFT then begin Signal('Mouse\BtnDown\Left',1); c:=1; end;
   if event.mouseButton.button=SDL_BUTTON_RIGHT then begin Signal('Mouse\BtnDown\Right',2); c:=2; end;
   if event.mouseButton.button=SDL_BUTTON_MIDDLE then begin Signal('Mouse\BtnDown\Middle',4); c:=3; end;
   EnterCriticalSection(crSect);
   try
   for i:=1 to 50 do
    if (game.scenes[i]<>nil) and
       (game.scenes[i].status=ssActive) and
       (game.scenes[i] is TUIScene) and
       (TUIScene(game.scenes[i]).UI.enabled) then
     game.scenes[i].onMouseBtn(c,true);
   finally
    LeaveCriticalSection(crSect);
   end;
  end;
  
  SDL_MOUSEBUTTONUP:with game do begin
   if event.mouseButton.button=SDL_BUTTON_LEFT then begin Signal('Mouse\BtnUp\Left',1); c:=1; end;
   if event.mouseButton.button=SDL_BUTTON_RIGHT then begin Signal('Mouse\BtnUp\Right',2); c:=2; end;
   if event.mouseButton.button=SDL_BUTTON_MIDDLE then begin Signal('Mouse\BtnUp\Middle',4); c:=3; end;
   EnterCriticalSection(crSect);
   try
   for i:=1 to 50 do
    if (game.scenes[i]<>nil) and
       (game.scenes[i].status=ssActive) and
       (game.scenes[i] is TUIScene) and
       (TUIScene(game.scenes[i]).UI.enabled) then
     game.scenes[i].onMouseBtn(c,false);
   finally
    LeaveCriticalSection(crSect);
   end;
  end;

  SDL_KEYDOWN:with game do begin
   EnterCriticalSection(crSect);
   try
    c:=(event.key.keysym.sym and $FF)+
       (ScanCodeFromUSBcode(event.key.keysym.scancode) and $FF) shl 8;
    if event.key.keysym.sym<65536 then begin
     for i:=1 to 50 do
      if (game.scenes[i]<>nil) and
      (game.scenes[i].status=ssActive) and
      (game.scenes[i] is TUIScene) and
      (TUIScene(game.scenes[i]).UI.enabled) then
       game.scenes[i].WriteKey(c);
     Signal('Kbd\Char',c);
    end;

    for i:=1 to 50 do
     if (game.scenes[i]<>nil) and
        (game.scenes[i].status=ssActive) and
        (game.scenes[i] is TUIScene) and
        (TUIScene(game.scenes[i]).UI.enabled) then
           with scenes[i] as TUIScene do begin
               if (modalcontrol=nil)or(modalcontrol=UI) then
               begin
                Signal('UI\'+name+'\KeyDown',
                   event.key.keysym.sym);
                break;
               end;
           end;
   finally
    LeaveCriticalSection(crSect);
   end;
  end;

  SDL_QUIT_:Signal('Engine\Cmd\Exit',0);
 end;

(*  wm_Destroy: if game<>nil then Signal('Engine\Cmd\Exit',0);
                //game.loopThread.Terminate;
  WM_SYSKEYUP:begin result:=0; exit; end;

  WM_MOUSEMOVE:if game<>nil then with game do begin
//                if not params.HW_cursor then SetCursor(WndCursor);
                if not game.params.showSystemCursor then SetCursor(0);
                OldMouseX:=mouseX;
                OldMouseY:=MouseY;
                pnt:=Point(LoWord(lParam),HiWord(lParam));
                ClientToScreen(game.window,pnt);
                ScreenToGame(pnt);
                mouseX:=pnt.X;
                mouseY:=pnt.y;
                Signal('Mouse\Move',pnt.x+pnt.Y shl 16);
                for i:=1 to 50 do
                 if (game.scenes[i]<>nil) and (game.scenes[i].status=ssActive) and (game.scenes[i] is TUIScene) and (TUIScene(game.scenes[i]).UI.enabled) then
                  game.scenes[i].onMouseMove(mouseX,mouseY);
                // Если курсор рисуется вручную, то нужно обновить экран
                if MouseVisible and
                   not game.params.HW_cursor and
                   not game.params.showSystemCursor then changed:=true;
               end;

  WM_CHAR:if game<>nil then with game do begin
           // Младший байт - код символа, старший - сканкод
           c:=wparam and $FF+(lparam shr 8) and $FF00;
           for i:=1 to 50 do
            if (game.scenes[i]<>nil) and (game.scenes[i].status=ssActive) and (game.scenes[i] is TUIScene) and (TUIScene(game.scenes[i]).UI.enabled) then
             game.scenes[i].WriteKey(c);
           Signal('Kbd\Char',c);
          end;

  WM_KeyDown:if game<>nil then with game do
             begin
              for i:=1 to 50 do
              if (game.scenes[i]<>nil) and (game.scenes[i].status=ssActive) and (game.scenes[i] is TUIScene) and (TUIScene(game.scenes[i]).UI.enabled) then
              with scenes[i] as TUIScene do
              begin
               if (modalcontrol=nil)or(modalcontrol=UI) then
               begin
                Signal('UI\'+name+'\KeyDown',wparam);
                break;
               end;
              end;
             end;

  WM_LButtonDown,wm_RButtonDown,wm_MButtonDown:begin
   SetCapture(window);
   if not game.params.showSystemCursor then SetCursor(0);

{   if not game.params.HW_cursor then SetCursor(WndCursor)
    else    device.ShowCursor(true);}
   if message=wm_LButtonDown then begin Signal('Mouse\BtnDown\Left',1); c:=1; end;
   if message=wm_RButtonDown then begin Signal('Mouse\BtnDown\Right',2); c:=2; end;
   if message=wm_MButtonDown then begin Signal('Mouse\BtnDown\Middle',4); c:=3; end;
   for i:=1 to 50 do
    if (game.scenes[i]<>nil) and (game.scenes[i].status=ssActive) and (game.scenes[i] is TUIScene) and (TUIScene(game.scenes[i]).UI.enabled) then
     game.scenes[i].onMouseBtn(c,true);
  end;

  WM_LButtonUp,wm_RButtonUp,wm_MButtonUp:begin
   ReleaseCapture;
   if not game.params.showSystemCursor then SetCursor(0);
{   if not game.params.HW_cursor then SetCursor(WndCursor)
    else device.ShowCursor(true);}
   if message=wm_LButtonUp then begin Signal('Mouse\BtnUp\Left',1); c:=1; end;
   if message=wm_RButtonUp then begin Signal('Mouse\BtnUp\Right',2); c:=2; end;
   if message=wm_MButtonUp then begin Signal('Mouse\BtnUp\Middle',4); c:=3; end;
   for i:=1 to 50 do
    if (game.scenes[i]<>nil) and (game.scenes[i].status=ssActive) and (game.scenes[i] is TUIScene) and (TUIScene(game.scenes[i]).UI.enabled) then
     game.scenes[i].onMouseBtn(c,false);
  end;

  WM_MOUSEWHEEL:begin
                 Signal('Mouse\Scroll',wParam div 65536);
                 if game<>nil then with game do
                 begin
                  for i:=1 to 50 do
                  if (game.scenes[i]<>nil) and
                     (game.scenes[i].status=ssActive) and
                     (game.scenes[i] is TUIScene) and
                     (TUIScene(game.scenes[i]).UI.enabled) then
                  with scenes[i] as TUIScene do
                  begin
                   onMouseWheel(wParam div 65536);
                   if (modalcontrol=nil)or(modalcontrol=UI) then
                   begin
                    Signal('UI\'+name+'\MouseWheel',wparam div 65536);
                    break;
                   end;
                  end;
                 end;
                end;

  wm_Activate:begin
               if loword(wparam)<>wa_inactive then game.active:=true else game.active:=false;
               Signal('Engine\ActivateWnd',byte(game.active));
              end;
  WM_INPUTLANGCHANGEREQUEST:if HookKbdLayout then begin
    ActivateKeyboardLayout(lparam,0);
{   c:=GetKeyboardLayout(0);
   if layouts>0 then begin
    i:=1;
    while (i<=layouts) and (LayoutList[i]<>c) do inc(i);
    inc(i);
    if i>layouts then i:=1;
    ActivateKeyboardLayout(layoutList[i],)
   end;}
   exit;
  end;
 end;

 result:=DefWindowProc(Window,Message,WParam,LParam); *)
end;

procedure ProcessMessages;
var
 event:TSDL_Event;
begin
 while SDL_PollEvent(event) do
  HandleEvent(event);
end;

procedure Delay(time:integer);
begin
 if (game<>nil) and (GetCurrentThreadId=game.loopThread.ThreadID) then
  ProcessMessages;
 HandleSignals;
 while time>100 do begin
  sleep(100);
  time:=time-100;
  if (game<>nil) and (GetCurrentThreadId=game.loopThread.ThreadID) then
   Processmessages;
  HandleSignals;
 end;
 sleep(time);
end;


function TSDLGame.OnFrame:boolean;
var
 i,cnt,v,n:integer;
 deltaTime,time:integer;
 p:pointer;
begin
 result:=false;
 EnterCriticalSection(crSect);
 try
 // Выбор курсора с наименьшим приоритетом (но >0)
 v:=10000000;
 for i:=1 to 32 do
  if cursors[i]<>nil then with cursors[i] as TGameCursor do
   if (priority<v) and (priority>0) then begin
    v:=priority; n:=i;
   end;
 if v<10000000 then begin
  (cursors[n] as TGameCursor).visible:=true;
  if (v>curPrior) and not params.HW_cursor then changed:=true;
 end;
 // Сортировка сцен
 cnt:=0;
 for i:=1 to 50 do
  if scenes[i]<>nil then inc(cnt);

 if cnt>0 then begin
  for i:=49 downto 1 do
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
 deltaTime:=GetTickCount-LastOnFrameTime;
 LastOnFrameTime:=GetTickCount;
 // Обработка всех активных сцен
 EnterCriticalSection(crSect);
 try
 for i:=1 to 50 do
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
 finally
  LeaveCriticalSection(crSect);
 end;

// LastOnFrameTime:=GetTickCount;
end;

procedure TSDLGame.RenderFrame;
var
 i,j,n,x,y:integer;
 sc:array[1..50] of TGameScene;
 effect:TSceneEffect;
 DeltaTime:integer;
 fl,border:boolean;
 z:single;
 s:integer;
 {$IFDEF DELPHI}
 memState:TMemoryManagerState; // real-time memory manager state
 {$ENDIF}
begin
 DeltaTime:=MyGetTime2-LastRenderTime;
 LastRenderTime:=MyGetTime2;
 FLog('Render1');
 painter.ResetTarget;
 // в полноэкранном режиме вывод по центру
 border:=false;
 /// TODO
{ if not params.windowed and
   ((d3d8.params.BackBufferWidth>params.width) or
    (d3d8.params.BackBufferHeight>params.height)) then begin
  painter.ScreenOffset((d3d8.params.BackBufferWidth-params.width) div 2,
    (d3d8.params.BackBufferHeight-params.height) div 2);
  painter.screenRect:=rect(0,0,params.width,params.height);
  border:=true;
 end;}
 EnterCriticalSection(crSect);
 try
  painter.ResetTarget;
  try
  // Очистим экран если нет ни одной background-сцены или они не покрывают всю область вывода
  fl:=true;
  if not border then
   for i:=1 to 50 do
    if (scenes[i]<>nil) and (scenes[i].sceneType=stBackground) and (scenes[i].status=ssActive)
     then fl:=false;
  FLog('Clear '+booltostr(fl));
  if fl then begin
   if params.zbuffer>0 then z:=0 else z:=-1;
   if params.stencil then s:=0 else s:=-1;
   painter.Clear(0,z,s);
  end;
  except
   on e:exception do CritMsg('RFrame1 '+e.Message);
  end;
  FLog('Eff');
  try
  // Обработка эффектов на ВСЕХ сценах
  for i:=1 to 50 do
   if (scenes[i]<>nil) and (scenes[i].effect<>nil) then begin
    FLog('Eff on '+scenes[i].ClassName+' is '+scenes[i].effect.ClassName+' : '+
     inttostr(scenes[i].effect.timer)+','+booltostr(scenes[i].effect.done));
    effect:=scenes[i].effect;
    FLog('Eff ret');
    inc(effect.timer,DeltaTime);
    if effect.done then begin // Эффект завершился
     Signal('ENGINE\EffectDone',cardinal(scenes[i])); // Посылаем сообщение о завершении эффекта
     effect.Destroy;
     scenes[i].effect:=nil;
    end;
   end;
   except
    on e:exception do CritMsg('RFrame2 '+e.Message);
   end;

// LogMessage('RenderFrame('+inttostr(gettickcount mod 10000)+') {');
 // sort scenes by Z order
  FLog('Sorting');
  try
  n:=0;
  for i:=1 to 50 do
   if (scenes[i]<>nil) and (scenes[i].status=ssActive) then begin
    // Сортировка вставкой. Найдем положение для вставки и вставим туда
    if n=0 then begin
     sc[1]:=scenes[i]; inc(n); continue;
    end;
    for j:=n downto 1 do
     if sc[j].zorder>scenes[i].zorder then sc[j+1]:=sc[j]
      else begin sc[j+1]:=scenes[i]; break; end;
    if j=0 then sc[1]:=scenes[i];
    inc(n);
   end;
  topmostScene:=sc[n];

  for i:=1 to n do try
   StartMeasure(i+4);
   if sc[i].effect<>nil then begin
    painter.BeginPaint(nil);
    if sc[i].shadowColor<>0 then
     painter.FillRect(0,0,game.settings.width,game.settings.height,sc[i].shadowColor);
    painter.EndPaint;
    FLog('Drawing eff on '+sc[i].ClassName);
    sc[i].effect.DrawScene;
    FLog('Drawing ret');
   end
    else begin
     painter.BeginPaint(nil);
     if sc[i].shadowColor<>0 then
      painter.FillRect(0,0,game.settings.width,game.settings.height,sc[i].shadowColor);
     FLog('Drawing '+sc[i].ClassName);
     sc[i].Render;
     FLog('Drawing ret');
     painter.EndPaint;
    end;
   EndMeasure2(i+4);
  except
   on e:exception do CritMsg('SceneRender '+sc[i].ClassName+' error '+e.Message);
  end;
  except
   on e:exception do CritMsg('RFrame3 '+e.Message);
  end;

  FLog('RCursor');
// LogMessage('ScenesDone');
  try
  // Вывод курсора
  if mouseVisible then begin
   n:=0; j:=-10000;
   for i:=1 to 32 do
    if cursors[i]<>nil then with cursors[i] as TGameCursor do
     if visible and (priority>j) then begin
      j:=priority; n:=image;
     end;
   if n>0 then begin
    if not params.showSystemCursor then begin
     painter.BeginPaint(nil);
     DrawImage(n,mouseX,mouseY,$FF808080,0,0,0,0);
     painter.EndPaint;
    end else
     DrawImage(n,mouseX,mouseY,$FF808080,0,0,0,0);
    curPrior:=j;
   end;
  end;
  except
   on e:exception do CritMsg('RFrame4 '+e.Message);
  end;
 FLog('RDebug');
// ResetAllCursors;
 if (ShowDebugInfo>0) and (painter<>nil) then begin
  painter.BeginPaint(nil);
  painter.SetFont(1);
  painter.WriteSimple(10,10,$FFFFFFFF,inttostr(round(fps)));
  for i:=1 to 15 do
   painter.WriteSimple(i*60,10,$FFFFFFFF,FloatToStrF(PerformanceMeasures[i],ffFixed,5,2));
  if (ShowDebugInfo=2) then begin
   {$IFDEF DELPHI}
   GetMemoryManagerState(memState);
   painter.WriteSimple(10,30,$FFFFFFFF,
    IntToHex(memState.TotalAllocatedMediumBlockSize,8)+' / '+
    inttostr(memState.AllocatedMediumBlockCount));
   painter.WriteSimple(10,50,$FFFFFFFF,
    IntToHex(memState.TotalAllocatedLargeBlockSize,8)+' / '+
    inttostr(memState.AllocatedLargeBlockCount));
   {$ENDIF}
  end;

  if (ShowDebugInfo=1) and (texman<>nil) then begin
   painter.WriteSimple(10,30,$FFFFFFFF,texman.GetStatus(1));
   painter.WriteSimple(10,50,$FFFFFFFF,texman.GetStatus(2));
//   painter.WriteSimple(10,70,$FFFFFFFF,inttostr(device.GetAvailableTextureMem div 1024));
  end;
  painter.EndPaint;
 end;
 if (CapturedTime>0) and (GetTickCount<CapturedTime+3000) and (painter<>nil) then begin
  painter.BeginPaint(nil);
  painter.SetFont(1);
  x:=game.params.width div 2;
  y:=game.params.height div 2;
  painter.FillRect(x-200,y-40,x+200,y+40,$60000000);
  painter.Rect(x-200,y-40,x+200,y+40,$A0FFFFFF);
  painter.WriteSimple(x,y-24,$FFFFFFFF,'Screen captured to:',engineCls.taCenter);
  painter.WriteSimple(x,y+4,$FFFFFFFF,capturedName,engineCls.taCenter);
  painter.EndPaint;
 end;
 finally
  LeaveCriticalSection(crSect);
 end;
// LogMessage('} '+inttostr(gettickcount mod 10000));
 FLog('RDone');
end;

function TSDLGame.OnRestore:boolean;
var
 res:integer;
begin
 Signal('Engine\BeforeRestore');
 if texman<>nil then texman.ReleaseAll;
 // Reset device
 /// TODO
 //ChangeMode(d3d8.params);
 if texman<>nil then texman.ReCreateAll;
 if painter<>nil then painter.Reset;
 Signal('Engine\AfterRestore');
end;

procedure TSDLGame.AddScene(scene: TGameScene);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 scene.accumTime:=0;
 for i:=1 to 50 do
  if scenes[i]=nil then begin
   scenes[i]:=scene; exit;
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TSDLGame.RemoveScene(scene: TGameScene);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=1 to 50 do
  if scenes[i]=scene then begin
   scenes[i]:=nil; exit;
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TSDLGame.MoveWindowTo(x, y, width, height: integer);
var
 r:TRect;
 dx,dy:integer;
begin
 if window=nil then exit;
// SDL_Se
{ getWindowRect(window,r);
 dx:=x-r.left; dy:=y-r.top;
 inc(r.left,dx); inc(r.right,dx);
 inc(r.top,dy); inc(r.Bottom,dy);
 if (width>0) and (height>0) then begin
  r.Right:=r.left+width;
  r.Bottom:=r.top+height;
 end;
 MoveWindow(window,r.left,r.top,r.right-r.left,r.Bottom-r.top,true);}
end;

// Обработка событий, являющихся командами движку
function EngineCmdEvent(event:EventStr;tag:integer):boolean;
begin
 delete(event,1,length('Engine\Cmd\'));
 event:=UpperCase(event);
 if game=nil then exit;
 if event='CHANGESETTINGS' then game.ApplySettings;
 if event='EXIT' then game.loopThread.Terminate;
 if event='MAKESCREENSHOT' then;
end;

procedure TSDLGame.SetWindowCaption(text: string);
begin
 SDL_SetWindowTitle(window,PChar(text));
end;

procedure TSDLGame.ShowMouse(m: boolean);
begin
 if m=mousevisible then exit;
 mouseVisible:=m;
{ if params.showSystemCursor then WndCursor:=LoadCursor(0,IDC_ARROW)
  else WndCursor:=0;
 if not params.HW_cursor then changed:=true;}
end;

procedure TSDLGame.RegisterCursor(CursorID, priority: integer;
  CursorImage: string);
var
 i:integer;
 cursor:TGameCursor;
begin
 EnterCriticalSection(crSect);
 try
 for i:=1 to 32 do
  if cursors[i]=nil then begin
   cursor:=TGameCursor.Create;
   cursor.ID:=CursorID;
   cursor.priority:=priority;
   cursor.image:=PrepareImage(CursorImage);
   cursor.visible:=false;
   cursors[i]:=cursor;
   exit;
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TSDLGame.ResetAllCursors;
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

procedure TSDLGame.ToggleCursor(CursorID: integer; state: boolean);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=1 to 32 do
  if cursors[i]<>nil then
   with cursors[i] as TGameCursor do
    if ID=CursorID then visible:=state;
 if not params.HW_cursor then changed:=true;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

function TSDLGame.GetThreadResult(h: THandle): integer;
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

function TSDLGame.RunAsync(threadFunc:pointer; param:cardinal; ttl: single;name:string): THandle;
var
 i,best:integer;
 t:double;
begin
 result:=0;
 best:=0; t:=gettickcount;
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
 if ttl>0 then threads[best].timetokill:=gettickcount+round(ttl*1000)
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
 LogMessage('New thread, pos='+inttostr(best)+', id='+inttostr(result)+
   ', func='+inttohex(integer(threadFunc),8)+', time: '+inttostr(threads[best].TimeToKill),8);
end;

procedure TSDLGame.Minimize;
begin
 SDL_MinimizeWindow(window);
end;

{ TCustomThread }

procedure TCustomThread.Execute;
begin
 RegisterThread(name);
 running:=true;
 try
  ReturnValue:=func(param);
 except
  on e:exception do ForceLogMessage('RunAsync: failure - '+e.Message);
 end;
 FinishTime:=gettickcount;
 running:=false;
 Signal('engine\thread\done\'+inttohex(integer(@func),8),ReturnValue);
 UnregisterThread;
end;

{ TMainThread }
procedure TMainThread.Execute;
 type
  Tkeys=array[0..1024] of byte;
  PKeys=^TKeys;
 var
  ticks,frametime:cardinal;
  i,numKeys:integer;
  adr:pointer;
  f:text;
  keys:PKeys;
  scancode:integer;

begin
 // Инициализация
 try
  LogMessage(TimeStamp+' Main thread started - '+inttostr(GetCurrentThreadID));
  RegisterThread('MainThread');
  if SDL_Init(SDL_INIT_VIDEO)<0 then begin
   ForceLogMessage('Failed to init SDL!');
   halt;
  end;
  SDL_ClearError;
  owner.InitGraph;
  SetEventHandler('Engine\Cmd',EngineCmdEvent,sync);

  LastFrameNum:=0; LastTickCount:=GetTickCount;  FrameTime:=getTickCount;

  owner.LastOnFrameTime:=GetTickCount;
  owner.LastRenderTime:=MyGetTime2;

  // Эвристическая формула
{  i:=device.GetAvailableTextureMem div (1024*1024);
  if i>owner.BestVidMem then i:=(i+owner.BestVidMem*2) div 3 else
   if i>32 then i:=i-(i div 3);}

  texman:=TGLTextureMan.Create(1024*i);
  painter:=TGLPainter.Create(texman,owner.params.width,owner.params.height);
  engineTools.texman:=texman;
  engineTools.painter:=painter;

  Signal('Engine\BeforeMainLoop');
  owner.running:=true; // Это как-бы семафор для завершения функции Run

  // Главный цикл
  repeat
   try
    PingThread;

    // Обновление ввода с клавиатуры
    if owner.active then with owner do begin
     keys:=PKeys(SDL_GetKeyboardState(numKeys));
     shiftstate:=0;
     if (keys[SDL_SCANCODE_LSHIFT]<>0) or
        (keys[SDL_SCANCODE_RSHIFT]<>0) then shiftstate:=shiftstate+1;    // Shift
     if (keys[SDL_SCANCODE_LCTRL]<>0) or
        (keys[SDL_SCANCODE_RCTRL]<>0) then shiftstate:=shiftstate+2;   // Ctrl
     if (keys[SDL_SCANCODE_LALT]<>0) or
        (keys[SDL_SCANCODE_RALT]<>0) then shiftstate:=shiftstate+4;   // Alt
     if (keys[SDL_SCANCODE_LGUI]<>0) or
        (keys[SDL_SCANCODE_RGUI]<>0) then shiftstate:=shiftstate+8;   // Win

     for i:=0 to numKeys do begin
      scancode:=ScanCodeFromUSBcode(i);
      owner.keystate[i]:=(owner.keystate[i] shl 1) and 2 or byte(keys[i]<>0);
      if owner.keystate[i]=1 then begin // Клавиша нажата
       Signal('KBD\KeyDown',ScanCode+shiftstate shl 16);
       keytimer:=gettickcount+400;
       keycode:=scancode;
      end;
      if owner.keystate[i]=2 then begin // Клавиша отпущена
       Signal('KBD\KeyUp',ScanCode+shiftstate shl 16);
       if keycode=scancode then keycode:=0;
      end;
     end;
     // Симуляция повторения нажатия
     if (keycode>0) and (gettickcount>keytimer) then begin
      keytimer:=getTickCount+80;
      Signal('KBD\KeyDown',keycode+shiftstate shl 16);
     end;
    end;

    // Alt+F1 - Создание отладочных логов
    if ((owner.keystate[56]=3) or (owner.keystate[184]=3)) and
        (owner.keystate[59]=1) then begin
     assign(f,'framelog.log');
     rewrite(f);
     writeln(f,'Previous:');
     write(f,owner.prevFrameLog);
     writeln(f,'Current:');
     write(f,owner.FrameLog);
     close(f);
     DumpUIdata;
     texman.Dump('User request');
    end;

    // Alt+Enter
    if ((owner.keystate[56]=3) or (owner.keystate[184]=3)) and
        (owner.keystate[28]=1) then begin
     owner.params.windowed:=not owner.params.windowed;
     owner.ChangeSettings(owner.params);
    end;

    // Расчет fps
    ticks:=GetTickCount;
    if ticks>LastTickCount+200 then begin
     owner.fps:=owner.FPS*0.3+(1000*(owner.framenum-LastFrameNum)/(ticks-LastTickCount))*0.7;
     LastFrameNum:=owner.FrameNum;
     LastTickCount:=ticks;
    end;

    i:=GetTickCount-FrameTime;
    if i>200 then
     LogMessage('Warning: main loop stall for '+inttostr(i)+' ms');
    FrameTime:=GetTickCount;

    Signal('DXGame\Idle'); //
    StartMeasure(14);

    if owner.active then begin
     ProcessMessages;
     HandleSignals;
    end else
     Delay(20);
    EndMeasure2(14);

    // Обработка кадра
    StartMeasure(3);
    if owner.OnFrame then
     owner.changed:=true; // это чтобы можно было и в других местах выставлять флаг!
    EndMeasure(3);
    HandleSignals;
    if owner.active or owner.params.windowed then begin
     // Если программа активна, то выполним отрисовку кадра
     if owner.changed and owner.initialized then begin
      try
       owner.PrevFrameLog:=owner.frameLog;
       owner.frameLog:='';
       owner.RenderFrame;
      except
       on E:Exception do CritMsg('Error in renderframe: '+e.Message);
      end;
     end;
    end;

    // Здесь можно что-нибудь сделать
    Sleep(0);
    // Обработка thread'ов
    EnterCriticalSection(RA_sect);
    try
    for i:=1 to 16 do
     if threads[i]<>nil then with threads[i] do
      if running and (timetokill<gettickcount) then begin
       ForceLogMessage(timestamp+' ALERT: thread terminated by timeout, '+inttohex(cardinal(@func),8)+
        ', curtime: '+inttostr(gettickcount));
       TerminateThread(Handle,0);
       ReturnValue:=-1;
       Signal('Engine\thread\done\'+inttohex(cardinal(@func),8),-1);
       Signal('Error\Thread TimeOut',0);
       running:=false;
     end;
    finally
     LeaveCriticalSection(RA_sect);
    end;

    // Теперь нужно вывести кадр на экран
    if owner.active or owner.params.windowed then begin
     if owner.changed and owner.initialized then begin
      if owner.params.windowed then begin
       adr:=@owner.ScreenRect;
       SetWindowArea(owner.params.width,owner.params.height,owner.screenRect);
      end else
       adr:=nil;
      game.FLog('Present');
      SDL_GL_SwapWindow(owner.window);
      inc(owner.FrameNum);
      painter.outputPos:=Point(0,0);
     end else
      sleep(5);
    end;
    game.Flog('LEnd');

   except
    on e:Exception do CritMsg('Error in main loop: '+e.message);
   end;
  until terminated;
  game.terminated:=true;
  Signal('Engine\AfterMainLoop');

  // Состояние ожидания команды остановки потока из безопасного места
  while not game.canExitNow do sleep(20);

  // Финализация
  owner.DoneGraph;
 except
  on e:Exception do CritMsg('Global error: '+e.message);
 end;

 UnregisterThread;
 owner.running:=false; // Эта строчка должна быть ПОСЛЕДНЕЙ!
end;

procedure CalcPixelFormats(needMem:integer);
var
 i,n:integer;
begin
 pfTrueColor:=ipfXRGB;
 pfTrueColorAlpha:=ipfARGB;
 pfTrueColorLow:=ipfXRGB;
 pfTrueColorAlphaLow:=ipfARGB;

 pfRTLow:=ipfXRGB;
 pfRTNorm:=ipfXRGB;
 pfRTHigh:=ipfXRGB;
 pfRTAlphaLow:=ipfARGB;
 pfRTAlphaNorm:=ipfARGB;
 pfRTAlphaHigh:=ipfARGB;
end;

initialization
 InitCritSect(RA_sect,'GLGame_RA');
end.
