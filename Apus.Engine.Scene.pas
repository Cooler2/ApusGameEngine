// Base Scene and SceneEffect classes
//
// Copyright (C) 2022 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Scene;
interface
uses Apus.Core, Apus.Classes, Apus.Containers, Apus.Engine.Keys;

type
 TGameScene=class;

 // Scene-level hotkey handler (see TGameScene.RegisterHotKey)
 TKeyHandler=procedure(key:TKey;shift:byte) of object;

 // One entry in a scene's declarative hotkey table
 TSceneHotKey=record
  vKey:TKey;
  shiftState:byte;
  handler:TKeyHandler;
 end;

 // Базовый эффект для background-сцены
 TSceneEffect=class
  timer:integer; // время (в тысячных секунды), прошедшее с момента начала эффекта
  duration:integer;  // время, за которое эффект должен выполнится
  done:boolean;  // Флаг, сигнализирующий о том, что эффект завершен
  target:TGameScene;
  name:String8; // description for debug reasons
  constructor Create(scene:TGameScene;TotalTime:integer); // создать эффект на заданное время (в мс.)
  procedure DrawScene; virtual; abstract; // Процедура должна полностью выполнить отрисовку сцены с эффектом (в текущий RT)
  destructor Destroy; override;
 end;

 // Base scene switcher interface
 TSceneSwitcher=class
  class var defaultSwitcher:TSceneSwitcher; // global scene switcher is here
  procedure SwitchToScene(name:string8); virtual; abstract; // switch to a fullscreen scene
  procedure ShowWindowScene(name:string8;modal:boolean=true); virtual; abstract; // show a windowed scene
  procedure HideWindowScene(name:string8); virtual; abstract; // hide a windowed scene
 end;


  TSceneStatus=(ssFrozen,     // scene is completely frozen (not processed, not rendered)
               ssBackground, // scene is processed but not rendered
               ssActive);    // scene is active: processed and rendered

 // -------------------------------------------------------------------
 // TGameScene — a visual layer bound to a window.
 //
 // Lifecycle:
 //   Create(window)  — any thread. Set up all state not requiring a render context.
 //   Load            — called automatically, not from the render thread.
 //                      Load heavy resources here (textures, data).
 //   InitGfx         — render thread, once, automatic. Allocate render targets, shaders, etc.
 //                      Most scenes leave this empty. Never call manually.
 //   Process         — called at specified frequency while not frozen.
 //   Render          — render thread, each frame while active.
 // -------------------------------------------------------------------
TGameScene=class(TNamedObject)
  ownerWindow:pointer; // window that owns this scene (Apus.Engine.Window.TWindow)
  status:TSceneStatus;
  fullscreen:boolean; // true - opaque scene, no any underlying scenes can be seen, false - scene layer is drawn above underlying image
  frequency:integer; // Сколько раз в секунду нужно вызывать обработчик сцены (0 - каждый кадр)
  effect:TSceneEffect; // Эффект, применяемый при выводе сцены
  zOrder:integer; // Определяет порядок отрисовки сцен
  activated:boolean; // true если сцена уже начала показываться или показалась, но еще не имеет эффекта закрытия
  shadowColor:cardinal; // если не 0, то рисуется перед отрисовкой сцены
  ignoreKeyboardEvents:boolean; // если true - такая сцена не будет получать сигналы о клавиатурном вводе, даже будучи верхней
  gfxInitialized:boolean; // true after InitGfx was called by the render loop
  loaded:boolean; // true after Load has completed

  // Внутренние величины
  accumTime:integer; // накопленное время (в мс)

  constructor Create(fullscreen:boolean=true); overload;
  // Unified constructor: optional scene name and optional owner window object.
  // If wnd=nil then scene is attached to global window (when available).
  constructor Create(sceneName:string='';fullscreen:boolean=true;wnd:TObject=nil); overload;
  destructor Destroy; override;

  // Вызывается из конструктора, можно переопределить для инициализации без влезания в конструктор
  // !!! Call this manually from constructor!
  procedure onCreate; virtual;

  // Для изменения статуса использовать только это!
  procedure SetStatus(st:TSceneStatus); virtual;

  // status=ssActive
  function IsActive:boolean;

  // Called automatically outside the render thread to load heavy resources
  procedure Load; virtual;

  // Called once by the render loop before the first Render(). Never call manually.
  // Override only to allocate GPU resources (render targets, shaders, etc.)
  procedure InitGfx; virtual;

  // Called with the specified frequency (regardless of the FPS) unless scene is Frozen
  // Can return false if scene doesn't change and doesn't need to be rendered
  function Process:boolean; virtual;

  // Рисование сцены. Вызывается каждый кадр только если сцена активна и изменилась
  // На момент вызова установлен RenderTarget и все готово к рисованию
  // Если сцена соержит свой слой UI, то этот метод должен вызвать
  // рисовалку UI для его отображения
  procedure Render; virtual;

  // --- Keyboard callbacks (synchronous; dispatched by the engine once per frame) ---
  // Final receivers: override in scenes to handle keys not consumed by UI focus or
  // hotkeys. Return true if the key was consumed. Symmetric with onMouseDown/onMouseUp.
  function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; virtual;
  function onKeyUp(key:TKey;scancode:integer;shift:byte):boolean; virtual;
  // Dispatcher seam, invoked per buffered key by PumpInput. Default runs the RegisterHotKey
  // table (on press) then the onKeyDown/onKeyUp receivers. UI scenes override it to run
  // focus/hotkey logic first and fall through to inherited for gameplay.
  function DispatchKey(key:TKey;scancode:integer;shift:byte;pressed:boolean):boolean; virtual;
  // Declarative scene-level hotkeys, matched by the default DispatchKey before onKeyDown.
  procedure RegisterHotKey(key:TKey;shift:byte;handler:TKeyHandler);
  procedure UnregisterHotKeys;
  // Drain the key buffer and dispatch each event. Called by the engine before Process.
  procedure PumpInput(shift:byte);

  // Check if there are any buffered text-input chars (polling channel, see ReadKey)
  function KeyPressed:boolean; virtual;
  // Read buffered text char: 0xAAAABBCC or 0 if none.
  // AAAA - unicode char, BB - scancode, CC - ansi char
  function ReadKey:cardinal; virtual;
  // Записать клавишу (нажатие/отпускание) в буфер клавиш (упаковка: keyCode|scancode<<16|pressed<<24)
  procedure WriteKey(key:cardinal); virtual;
  // Записать введённый символ в буфер текста (для polling через ReadKey)
  procedure WriteChar(ch:cardinal); virtual;
  // Очистить буферы ввода
  procedure ClearKeyBuf; virtual;

  // Смена режима (что именно изменилось - можно узнать косвенно)
  procedure ModeChanged; virtual;

  // Сообщение о том, что область отрисовки (она может быть частью окна) изменила размер, сцена может отреагировать на это
  procedure onResize; virtual;
  // События мыши
  procedure onMouseMove(x,y:integer); virtual;
  procedure onMouseBtn(btn:byte;pressed:boolean); virtual;
  procedure onMouseWheel(delta:integer); virtual;
  procedure onShow; virtual; // called when status changed to Active
  procedure onHide; virtual; // called when status changed from Active
  procedure onEvent(eventPart:String8;tag:NativeInt); virtual; // called when 'Scenes\[SceneName]\xxx' event is fired, "xxx" part is passed

  // For non-fullscreen scenes return occupied area
  function GetArea:TRect; virtual; abstract;
  // Return scene UI root object when available (nil for non-UI scenes)
  function GetUIRoot:TObject; virtual;

  // Call "Load" for all scenes (if applicable)
  class procedure LoadAllScenes;

 protected
  class function ClassHash:pointer; override;

 private
   // Keyboard input
   keyBuffer:TQueue;  // key down/up events (dispatched via PumpInput → DispatchKey)
   charBuffer:TQueue; // text chars (polling channel via ReadKey)
   sceneHotKeys:array of TSceneHotKey;
 end;

implementation
uses SysUtils,
  Apus.Strings,
  Apus.EventMan,
  Apus.Conv,
  Apus.Lib,
  Apus.Engine.Window,
  Apus.Engine.API;

 var
  scenesHash:TObjectHash; // used to search scenes by name
  scenesToLoad:TObjectList; // order of scenes to load
  eventSet:boolean=false;

 // SCENES\* handler
 procedure EventHandler(event:TEventStr;tag:TTag);
  var
   scene:TGameScene;
   p:integer;
   name:String8;
  begin
   p:=event.IndexOf('\',8);
   name:=Copy(event,8,p-8);
   scene:=TGameScene.FindByName(name) as TGameScene;
   if scene<>nil then
    scene.onEvent(Copy(event,p+1,1000),tag);
  end;

 { TGameScene }

 class function TGameScene.ClassHash: pointer;
  begin
   result:=@scenesHash;
  end;

 procedure TGameScene.ClearKeyBuf;
  begin
   keyBuffer.Clear;
   charBuffer.Clear;
  end;

constructor TGameScene.Create(fullScreen:boolean=true);
  begin
   ownerWindow:=nil;
   status:=ssFrozen;
   self.fullscreen:=fullscreen;
   frequency:=0;
   keyBuffer.Init(64);
   charBuffer.Init(64);
   zorder:=0;
   activated:=false;
   effect:=nil;
   name:=ClassName;
   ignoreKeyboardEvents:=false;
   if classType=TGameScene then onCreate; // each generic child class must call this in the constructors last string
   scenesToLoad.Add(self);

   if not eventSet then begin
    eventSet:=true;
    SetEventHandler('SCENES\',eventHandler,emInstant);
   end;
  end;

constructor TGameScene.Create(sceneName:string;fullscreen:boolean;wnd:TObject);
 var
  targetWnd:TWindow;
 begin
  Create(fullscreen);
  if sceneName<>'' then
   name:=sceneName;
  if wnd=nil then
   targetWnd:=window
  else
  if wnd is TWindow then
   targetWnd:=TWindow(wnd)
  else
   targetWnd:=nil;
  if (targetWnd<>nil) and (ownerWindow=nil) then
   targetWnd.AddScene(self);
 end;

 destructor TGameScene.Destroy;
  begin
   if status<>ssFrozen then
     raise EError.Create('Scene must be frozen before deletion: '+name+' ('+ClassName+')');
   scenesToLoad.Remove(self);
  end;

 procedure TGameScene.InitGfx;
  begin
  end;

 function TGameScene.IsActive: boolean;
  begin
   result:=status=ssActive;
  end;

procedure TGameScene.ModeChanged;
  begin
  end;

 procedure TGameScene.onMouseBtn(btn: byte; pressed: boolean);
  begin
  end;

 procedure TGameScene.onMouseMove(x, y: integer);
  begin
  end;

 procedure TGameScene.onMouseWheel(delta:integer);
  begin
  end;

 procedure TGameScene.onResize;
  begin
  end;

 procedure TGameScene.onShow;
  begin
  end;

 procedure TGameScene.onHide;
  begin
  end;

function TGameScene.Process:boolean;
  begin
   result:=true;
  end;

function TGameScene.GetUIRoot:TObject;
 begin
  result:=nil;
 end;

 procedure TGameScene.onCreate;
  begin
  end;

 procedure TGameScene.onEvent(eventPart:String8;tag:NativeInt);
  begin
  end;

 procedure TGameScene.Load;
  begin
   loaded:=true;
  end;

class procedure TGameScene.LoadAllScenes;
  var
   scene:TGameScene;
  begin
   Log.Force('Loading all scenes');
   repeat
    scene:=scenesToLoad.RemoveFirst as TGameScene;
    if scene=nil then break;
    if not scene.loaded then begin
     Log.Msg('Loading scene: "%s"',[scene.name]);
     scene.Load;
     Log.Msg('Scene "%s" loaded!',[scene.name]);
     scene.loaded:=true;
    end;
   until false;
  Log.Force('All scenes loaded!');
 end;

 function TGameScene.KeyPressed:boolean;
  begin
   result:=not charBuffer.Empty;
  end;

 function TGameScene.ReadKey:cardinal;
  var
   item:TDataItem;
  begin
   if charBuffer.Get(item) then
    result:=cardinal(item.data)
   else
    result:=0;
  end;

 procedure TGameScene.WriteKey(key:cardinal);
  var
   item:TDataItem;
  begin
   item.data:=integer(key);
   keyBuffer.Add(item);
  end;

 procedure TGameScene.WriteChar(ch:cardinal);
  var
   item:TDataItem;
  begin
   item.data:=integer(ch);
   charBuffer.Add(item);
  end;

 function TGameScene.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
  begin
   result:=false;
  end;

 function TGameScene.onKeyUp(key:TKey;scancode:integer;shift:byte):boolean;
  begin
   result:=false;
  end;

 function TGameScene.DispatchKey(key:TKey;scancode:integer;shift:byte;pressed:boolean):boolean;
  var
   i:integer;
   reg:byte;
  begin
   if pressed then begin
    // declarative scene hotkeys take priority over the onKeyDown receiver
    for i:=0 to high(sceneHotKeys) do
     if sceneHotKeys[i].vKey=key then begin
      reg:=sceneHotKeys[i].shiftState;
      if (reg=shift) or ((reg>0) and (reg and shift=reg)) then begin
       sceneHotKeys[i].handler(key,shift);
       exit(true);
      end;
     end;
    result:=onKeyDown(key,scancode,shift);
   end else
    result:=onKeyUp(key,scancode,shift);
  end;

 procedure TGameScene.RegisterHotKey(key:TKey;shift:byte;handler:TKeyHandler);
  var
   n:integer;
  begin
   n:=length(sceneHotKeys);
   SetLength(sceneHotKeys,n+1);
   sceneHotKeys[n].vKey:=key;
   sceneHotKeys[n].shiftState:=shift;
   sceneHotKeys[n].handler:=handler;
  end;

 procedure TGameScene.UnregisterHotKeys;
  begin
   SetLength(sceneHotKeys,0);
  end;

 procedure TGameScene.PumpInput(shift:byte);
  var
   item:TDataItem;
   k:cardinal;
  begin
   while keyBuffer.Get(item) do begin
    k:=cardinal(item.data);
    DispatchKey(TKey(k and $FFFF),(k shr 16) and $FF,shift,(k shr 24) and 1<>0);
   end;
  end;

 procedure TGameScene.Render;
  begin
  end;

 procedure TGameScene.SetStatus(st:TSceneStatus);
  var
   wasActive:boolean;
  begin
   if status=st then exit; // no change
   wasActive:=status=ssActive;
   if (st=ssActive) and not loaded then
    Log.Msg('WARN! Activating scene "%s" which was not loaded',[name]);
   if st=ssActive then onShow; // make sure to call this BEFORE the scene become active
   status:=st;
   activated:=st=ssActive;
   if wasActive and (status<>ssActive) then begin
    ClearKeyBuf; // drop any buffered input so it isn't dispatched on reactivation
    onHide;
   end;
  end;

 { TSceneEffect }

 constructor TSceneEffect.Create(scene:TGameScene;TotalTime:integer);
  begin
   done:=false;
   duration:=TotalTime;
   if duration=0 then duration:=10;
   timer:=0;
   if scene.effect<>nil then begin
    Log.Force('New scene effect replaces old one! '+scene.name+' previous='+scene.effect.name);
    scene.effect.Free;
   end;
   scene.effect:=self;
   target:=scene;
   name:=self.ClassName+' for '+scene.name+' created '+FormatDateTime('nn:ss.zzz',Now);
   Log.Msg('Effect %s: %s',[Conv.ToStr(self),name]);
  end;

 destructor TSceneEffect.Destroy;
  begin
    Log.Msg('Scene effect %s deleted: %s',[Conv.ToStr(self),name]);
    inherited;
  end;

initialization
 scenesHash.Init(40);
end.
