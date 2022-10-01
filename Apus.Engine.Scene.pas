// Base Scene and SceneEffect classes
//
// Copyright (C) 2022 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Scene;
interface
uses Types, Apus.Classes, Apus.Structs;

type
 TGameScene=class;

 // Базовый эффект для background-сцены
 TSceneEffect=class
  timer:integer; // время (в тысячных секунды), прошедшее с момента начала эффекта
  duration:integer;  // время, за которое эффект должен выполнится
  done:boolean;  // Флаг, сигнализирующий о том, что эффект завершен
  target:TGameScene;
  name:string; // description for debug reasons
  constructor Create(scene:TGameScene;TotalTime:integer); // создать эффект на заданное время (в мс.)
  procedure DrawScene; virtual; abstract; // Процедура должна полностью выполнить отрисовку сцены с эффектом (в текущий RT)
  destructor Destroy; override;
 end;

 // Base scene switcher interface
 TSceneSwitcher=class
  class var defaultSwitcher:TSceneSwitcher; // global scene switcher is here
  procedure SwitchToScene(name:string); virtual; abstract; // switch to a fullscreen scene
  procedure ShowWindowScene(name:string;modal:boolean=true); virtual; abstract; // show a windowed scene
  procedure HideWindowScene(name:string); virtual; abstract; // hide a windowed scene
 end;


 // -------------------------------------------------------------------
 // TGameScene - произвольная сцена
 // -------------------------------------------------------------------
 TSceneStatus=(ssFrozen,     // сцена полностью "заморожена"
               ssBackground, // сцена обрабатывается, но не рисуется
                             // (живет где-то в фоновом режиме и не влияет на экран)
               ssActive);    // сцена активна, т.е. обрабатывается и рисуется

 TGameScene=class(TNamedObject)
  status:TSceneStatus;
  fullscreen:boolean; // true - opaque scene, no any underlying scenes can be seen, false - scene layer is drawn above underlying image
  frequency:integer; // Сколько раз в секунду нужно вызывать обработчик сцены (0 - каждый кадр)
  effect:TSceneEffect; // Эффект, применяемый при выводе сцены
  zOrder:integer; // Определяет порядок отрисовки сцен
  activated:boolean; // true если сцена уже начала показываться или показалась, но еще не имеет эффекта закрытия
  shadowColor:cardinal; // если не 0, то рисуется перед отрисовкой сцены
  ignoreKeyboardEvents:boolean; // если true - такая сцена не будет получать сигналы о клавиатурном вводе, даже будучи верхней
  initialized:boolean; // true if Initialize is called
  loaded:boolean;

  // Внутренние величины
  accumTime:integer; // накопленное время (в мс)

  constructor Create(fullscreen:boolean=true);
  destructor Destroy; override;

  // Вызывается из конструктора, можно переопределить для инициализации без влезания в конструктор
  // !!! Call this manually from constructor!
  procedure onCreate; virtual;

  // Для изменения статуса использовать только это!
  procedure SetStatus(st:TSceneStatus); virtual;

  // status=ssActive
  function IsActive:boolean;

  // Called once during game initialization outside of the main thread (load required resources here)
  procedure Load; virtual;

  // Called only once from the MAIN (render) thread before the first Render() call (so must be fast)
  procedure Initialize; virtual;

  // Called with the specified frequency (regardless of the FPS) unless scene is Frozen
  // Can return false if scene doesn't change and doesn't need to be rendered
  function Process:boolean; virtual;

  // Рисование сцены. Вызывается каждый кадр только если сцена активна и изменилась
  // На момент вызова установлен RenderTarget и все готово к рисованию
  // Если сцена соержит свой слой UI, то этот метод должен вызвать
  // рисовалку UI для его отображения
  procedure Render; virtual;

  // Check if there are any key events in the keys buffer
  function KeyPressed:boolean; virtual;
  // Read buffered key event: 0xAAAABBCC or 0 if no any keys were pressed
  // AAAA - unicode char, BB - scancode, CC - ansi char
  function ReadKey:cardinal; virtual;
  // Записать клавишу в буфер
  procedure WriteKey(key:cardinal); virtual;
  // Очистить буфер нажатий
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

  // For non-fullscreen scenes return occupied area
  function GetArea:TRect; virtual; abstract;

  // Call "Load" for all scenes (if applicable)
  class procedure LoadAllScenes;

 protected
  class function ClassHash:pointer; override;

 private
  // Keyboard input
  keyBuffer:TQueue;
 end;


implementation
 uses Apus.Common, SysUtils;

 var
  scenesHash:TObjectHash; // used to search scenes by name
  scenesToLoad:TObjectList; // order of scenes to load

 { TGameScene }

 class function TGameScene.ClassHash: pointer;
  begin
   result:=@scenesHash;
  end;

 procedure TGameScene.ClearKeyBuf;
  begin
   keyBuffer.Clear;
  end;

 constructor TGameScene.Create(fullScreen:boolean=true);
  var
   m:procedure of object;
   base:pointer;
  begin
   status:=ssFrozen;
   self.fullscreen:=fullscreen;
   frequency:=60;
   keyBuffer.Init(64);
   zorder:=0;
   activated:=false;
   effect:=nil;
   name:=ClassName;
   ignoreKeyboardEvents:=false;
   if classType=TGameScene then onCreate; // each generic child class must call this in the constructors last string
   // Check if Load method is overriden
   m:=self.Load;
   base:=@TGameScene.Load;
   if @m<>base then begin
    loaded:=false;
    scenesToLoad.Add(self);
   end else
    loaded:=true;
  end;

 destructor TGameScene.Destroy;
  begin
   if status<>ssFrozen then raise EError.Create('Scene must be frozen before deletion: '+name+' ('+ClassName+')');
   scenesToLoad.Remove(self);
  end;

 procedure TGameScene.Initialize;
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

 procedure TGameScene.onCreate;
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
   ForceLogMessage('Loading all scenes');
   repeat
    scene:=scenesToLoad.RemoveFirst as TGameScene;
    if scene=nil then break;
    if not scene.loaded then begin
     LogMessage('Loading scene: "%s"',[scene.name]);
     scene.Load;
     LogMessage('Scene "%s" loaded!',[scene.name]);
     scene.loaded:=true;
    end;
   until false;
   ForceLogMessage('All scenes loaded!');
  end;

 function TGameScene.KeyPressed:boolean;
  begin
   result:=not keyBuffer.Empty;
  end;

 function TGameScene.ReadKey:cardinal;
  var
   item,next:TDataItem;
  begin
   if keyBuffer.Get(item) then begin
    result:=cardinal(item.data);
    if not keyBuffer.Empty then begin
     // It's possible that one keystroke event is logged twice: once for KEY event and then for CHAR event
     // So check this out: if this event is for KEY and there is another for CHAR - drop this one and return the second one.
     keyBuffer.Get(next);
     if (next.data) and $FF00=(item.data) and $FF00 then  // same scancode
      result:=cardinal(item.data)
     else
      keyBuffer.Add(next); // put back (although order may change)
    end;
   end else
    result:=0;
  end;

 procedure TGameScene.WriteKey(key:cardinal);
  var
   item:TDataItem;
  begin
   item.data:=integer(key);
   keyBuffer.Add(item);
  end;

 procedure TGameScene.Render;
  begin
  end;

 procedure TGameScene.SetStatus(st:TSceneStatus);
  begin
   if status=st then exit; // no change
   if (st=ssActive) and not loaded then
    LogMessage('WARN! Activating scene "%s" which was not loaded',[name]);
   if st=ssActive then onShow; // make sure to call this BEFORE the scene become active
   status:=st;
   if status=ssActive then activated:=true
    else activated:=false;
   if status<>ssActive then onHide;
  end;

 { TSceneEffect }

 constructor TSceneEffect.Create(scene:TGameScene;TotalTime:integer);
  begin
   done:=false;
   duration:=TotalTime;
   if duration=0 then duration:=10;
   timer:=0;
   if scene.effect<>nil then begin
    ForceLogMessage('New scene effect replaces old one! '+scene.name+' previous='+scene.effect.name);
    scene.effect.Free;
   end;
   scene.effect:=self;
   target:=scene;
   name:=self.ClassName+' for '+scene.name+' created '+FormatDateTime('nn:ss.zzz',Now);
   LogMessage('Effect %s: %s',[PtrToStr(self),name]);
  end;

 destructor TSceneEffect.Destroy;
  begin
    LogMessage('Scene effect %s deleted: %s',[PtrToStr(self),name]);
    inherited;
  end;

initialization
 scenesHash.Init(40);
end.
