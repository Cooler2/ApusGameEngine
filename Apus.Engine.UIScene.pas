// Common useful UI-related classes and routines
//
// Copyright (C) 2003-2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.UIScene;
interface
 uses Apus.Core, Apus.Engine.Scene, Apus.Engine.UITypes, Apus.Engine.Window;

var
 defaultScale:single=1.0;
 windowScale:single=1.0;

const
 defaultHintStyle:integer=0; // style of hints, can be changed
 modalShadowColor:cardinal=0; // color of global "under modal" shadow

type
 // Very useful simple scene that contains an UI layer
 // Almost all game scenes can be instances from this type, however sometimes
 // it is reasonable to use different scene(s)
 TUIScene=class(TGameScene)
  UI:TUIElement; // root UI element: size = render area size
  frameTime:int64; // time elapsed from the last frame
  constructor Create(scenename:string='';fullScreen:boolean=true;wnd:TWindow=nil);
  procedure SetStatus(st:TSceneStatus); override;
  function Process:boolean; override;
  procedure Render; override;
  procedure onResize; override;
  function GetArea:TRect; override; // screen area occupied by any non-transparent UI elements (i.e. which part of screen can't be ignored)
  procedure WriteKey(key:cardinal); override;
  procedure onMouseMove(x,y:integer); override;
  procedure onMouseBtn(btn:byte;pressed:boolean); override;
  procedure onMouseWheel(delta:integer); override;
  function GetUIRoot:TObject; override;

  // These are markers for drawing scenes background to properly handle alpha channel of the render target to avoid wrong alpha blending
  // This is important ONLY if you are drawing semi-transparent pixels over the undefined (previous) content
  procedure BackgroundRenderBegin; virtual;
  procedure BackgroundRenderEnd; virtual;

 private
  lastRenderTime:int64;
//  prevModal:TUIControl;
 end;

 // Get scene by name
 function UIScene(name:String8):TUIScene;

 // No need to call manually as it is called when any UIScene object is created
 procedure InitUI;

 // Создать всплывающее окно, прицепить его к указанному предку
 procedure ShowSimpleHint(msg:string8;parent:TUIElement;x,y,time:integer;font:cardinal=0);

implementation
 uses SysUtils, Apus.Lib, Types,
   Apus.EventMan, Apus.Publics,
   Apus.Engine.UI, Apus.Engine.UIWidgets, Apus.Engine.UIRender,
   Apus.Engine.CmdProc, Apus.Engine.Console, Apus.Engine.API,
  Apus.Engine.RobotAPI,
  Apus.Engine.UILayout,
  Apus.Log,
  Apus.Conv,
  Apus.Strings,
  Apus.Threads;

const
 statuses:array[TSceneStatus] of string=('frozen','background','active');

var
 curCursor:integer;
 initialized:boolean=false;

threadvar
 threadHandlersRegistered:boolean; // true after emQueued handlers registered for this render thread

 LastHandleTime:int64;


 // параметры хинтов
 curHint:TUIHint;
 hintRect:tRect; // область, к которой относится хинт
 // переменные для работы с хинтами элементов
 hintMode:cardinal; // время (в тиках), до которого длится режим показа хинтов
                   // в этом режиме хинты выпадают гораздо быстрее
 itemShowHintTime:cardinal; // момент времени, когда элемент должен показать хинт
 lastHint:String8; // text of the hint for the element under cursor in the previous frame

 designMode:boolean; // режим "дизайна", в котором можно таскать элементы по экрану правой кнопкой мыши
 hookedItem:TUIElement; // element to drag with mouse

 curShadowValue,oldShadowValue,needShadowValue:integer; // 0..255
 startShadowChange,shadowChangeDuration:int64;

 lastShiftState:byte;

function UIScene(name:String8):TUIScene;
 var
  scene:TObject;
 begin
  scene:=TUIScene.FindByName(name);
  ASSERT(scene<>nil,'Scene '+name+' not found!');
  ASSERT(scene is TUIScene,'Scene '+name+' is not a TUIScene');
  result:=scene as TUIScene;
 end;

 procedure ShowSimpleHint(msg:string8;parent:TUIElement;x,y,time:integer;font:cardinal=0);
  var
   hint:TUIHint;
   i:integer;
  begin
   Log.Msg('ShowHint: '+msg);
   msg:=Translate(msg);
   if (x=-1) or (y=-1) then begin
    x:=curMouseX; y:=curMouseY;
    hintRect:=Rect(x-8,y-8,x+8,y+8);
   end else begin
    hintRect:=Rect(0,0,4000,4000);
   end;
   if parent=nil then begin
    FindElementAt(x,y,parent);
    if parent=nil then begin
     if (window<>nil) and (window.topmostScene is TUIScene) then
      parent:=TUIScene(window.topmostScene).UI;
    end else
     parent:=parent.GetRoot;
   end;
   if parent=nil then exit;
   if curhint<>nil then begin
    Log.Msg('Free previous hint');
    curHint.Free;
    curHint:=nil;
   end;
   hint:=TUIHint.Create(X/parent.scale,(Y+10)/parent.scale,msg,parent);
   hint.font:=font;
   hint.styleClass:=defaultHintStyle;
   hint.timer:=time;
   hint.order:=10000; // Top
   curhint:=hint;
   Log.Msg('Hint created '+inttohex(UIntPtr(hint),16));
  end;

 procedure ActivateEventHandler(event:TEventStr;tag:TTag);
  begin
   window.Lock;
   try
    if tag=0 then
     SetFocusTo(nil);
   finally
    window.Unlock;
   end;
 end;

 procedure SetUnderMouse(e:TUIElement);
  begin
   Apus.Engine.UITypes.underMouse:=e;
  end;

 procedure MouseEventHandler(event:TEventStr;tag:TTag);
  var
   c,c2:TUIElement;
   e1,e2,e:boolean;
   x,y:integer;
   time:int64;
   st:String8;
  begin
   event:=UpperCase {TODO: use st.ToUpper}(copy(event,7,length(event)-6));
   window.Lock;
   time:=CoreTime.Ticks;
   try
    // обновить положение курсора если оно устарело
    if event='UPDATEPOS' then begin
     Signal('Engine\Cmd\UpdateMousePos');
    end;
    // Движение
    if event='MOVE' then begin
     oldMouseX:=curMouseX; oldMouseY:=curMouseY;
     curMouseX:=SmallInt(tag and $FFFF); curMouseY:=SmallInt((tag shr 16) and $FFFF);
     if ClipMouse<>cmNo then with clipMouseRect do begin
      x:=curMouseX; y:=curMouseY;
      if X<left then x:=left;
      if X>=right then x:=right-1;
      if Y<top then y:=top;
      if Y>=bottom then y:=bottom-1;
      if (clipMouse in [cmReal,cmLimited]) and ((curMouseX<>x) or (curMouseY<>y)) then begin
       if clipMouse=cmReal then exit;
      end;
      if clipmouse=cmVirtual then begin
       curMouseX:=x; curMouseY:=y;
      end;
     end;
     if (curMouseX=oldMouseX) and (curMouseY=oldMouseY) then exit;

     // если мышь покинула прямоугольник хинта - стереть его
     {$IFNDEF IOS}
     if (curhint<>nil) and (curhint.visible) and
        not PtInRect(hintRect,types.Point(curMouseX,curMouseY)) then curhint.Hide;
     {$ENDIF}

     if hookedItem<>nil then
      hookedItem.MoveBy(curMouseX-oldMouseX,curMouseY-oldMouseY);

     e1:=FindElementAt(oldMouseX,oldMouseY,c);
     e2:=FindElementAt(curMouseX,curMouseY,c2);
     if e2 then SetUnderMouse(c2)
      else SetUnderMouse(nil);
     if e1 then c.onMouseMove;
     if e2 and (c2<>c) then c2.onMouseMove;
     e2:=FindElementAt(curMouseX,curMouseY,c2);

     // Курсор
     if e2 and (c2.cursor<>curCursor) then begin
      if curCursor<>CursorID.Default then begin
       game.ToggleCursor(curCursor,false);
       Signal('UI\Cursor\OFF',curCursor);
      end;
      curCursor:=c2.cursor;
      game.ToggleCursor(curCursor,true);
      Signal('UI\Cursor\ON',curCursor);
     end;
     if not e2 and (curCursor<>CursorID.Default) then begin
      Signal('UI\Cursor\OFF',curCursor);
      game.ToggleCursor(curCursor,false);
      curCursor:=CursorID.Default;
      game.ToggleCursor(curCursor);
     end;

     if c<>c2 then begin
      // мышь перешла границу элемента
      if c<>nil then Signal('UI\onMouseOut\'+c.ClassName+'\'+c.name);
      if c2<>nil then Signal('UI\onMouseOver\'+c2.ClassName+'\'+c2.name);
     end;

     if (c2<>nil) and (c2.enabled and (c2.hint<>'') or not c2.enabled and (c2.hintIfDisabled<>'')) then begin
      if c2.enabled then st:=c2.hint
       else st:=c2.hintIfDisabled;
      if st<>lastHint then begin
       if st='' then begin
        ItemShowHintTime:=0;
       end else begin
        // этот элемент должен показать хинт
        if time<hintMode then ItemShowHintTime:=time+250
         else ItemShowHintTime:=time+c2.hintDelay;
       end;
      end;
      lastHint:=st;
     end else begin
      ItemShowHintTime:=0;
      lastHint:='';
     end;


     if clipMouse=cmLimited then begin // запомним скорректированное положение, чтобы не "прыгать" назад
      curMouseX:=x; curMouseY:=y;
     end;
    end;
    // Нажатие кнопки
    if copy(event,1,7)='BTNDOWN' then begin
     c:=nil;
     e:=FindElementAt(curMouseX,curMouseY,c);
     if e and (c<>nil) then
      c.onMouseButtons(tag,true)
     else if c<>nil then
      if (not c.enabled) and c.GetClassAttribute('handleMouseIfDisabled') then
       c.onMouseButtons(tag,true);

     // DEBUG FACILITIES
     // Drag elements with Ctrl+RMB
     if (tag=2) and
        (designmode or Bits.HasAll(lastShiftState,sscCtrl)) then hookedItem:=c;
     // Показать название и св-ва элемента
     if (tag=3) and Bits.HasAll(lastShiftState,sscCtrl) then
      if c<>nil then begin
        st:=c.name;
        c2:=c;
        while c2.parent<>nil do begin
         c2:=c2.parent;
         st:=c2.name+'->'+st;
        end;
        ShowSimpleHint(c.ClassName+'('+st+')',c.GetRoot,-1,-1,5000);
        PutMsg(Format('%s: pos: %.1f,%.1f pivot: %.1f %.1f size: %.1f,%.1f gRect: (%d %d %d %d) ',
         [c.name,c.position.x,c.position.y,c.pivot.x,c.pivot.y,c.size.x,c.size.y,
          c.globalRect.Left,c.globalRect.top,c.globalRect.right,c.globalRect.bottom]));
        if (window.shiftState and 2>0) and (c.name<>'') then // Shift pressed => select item
          ExecCmd('use '+c.name);
      end else begin
       st:='No opaque item here';
       FindAnyElementAt(curMouseX,curMouseY,c);
       if c<>nil then st:=st+'; '+c.ClassName+'('+c.name+')';
       ShowSimpleHint(st,nil,-1,-1,500+4000*byte(c<>nil));
      end;
    end;
    // Button release
    if copy(event,1,5)='BTNUP' then begin
     if (hookedItem<>nil) and (tag=2) then begin
      PutMsg('x='+inttostr(round(hookeditem.position.x))+' y='+inttostr(round(hookeditem.position.y)));
      hookedItem:=nil;
     end;
     if FindElementAt(curMouseX,curMouseY,c) then
      c.onMouseButtons(tag,false);
    end;
    // Скроллинг
    if copy(event,1,6)='SCROLL' then
     if FindElementAt(curMouseX,curMouseY,c) then
      c.onMouseScroll(tag);

   finally
    window.Unlock;
   end;
  end;

 procedure PrintUIlog;
  var
   st:String8;
  begin
   st:=' mouse clipping: '+inttostr(ord(clipMouse))+' ('+
     inttostr(clipMouserect.left)+','+inttostr(clipMouserect.top)+':'+
     inttostr(clipMouserect.right)+','+inttostr(clipMouserect.bottom)+')'#13#10;
   st:=st+' Modal element: ';
   if modalElement<>nil then st:=st+modalElement.name else st:=st+'none';
   Log.Force('UI state'#13#10+st);
  end;

 procedure KbdEventHandler(event:TEventStr;tag:TTag);
  var
   c:TUIElement;
   shift:byte;
   key:integer;
  begin
   window.Lock;
   try
    lastShiftState:=window.shiftState;
    shift:=window.shiftState;
    key:=GetKeyEventVirtualCode(tag); // virtual key code
    event:=UpperCase {TODO: use st.ToUpper}(copy(event,5,length(event)-4));
    if event='KEYDOWN' then // Win+Ctrl+S
     if (key=ord('S')) and (shift=8+2) then PrintUILog;

    c:=FocusedElement;
    // No focused element - handle hotkey for all elements
    if (event='KEYDOWN') and (c=nil) then begin
     ProcessHotKey(key,shift);
     exit;
    end;
    if c=nil then exit;

    if c.IsEnabled then begin
     if event='KEYDOWN' then
      if c.onKey(key,true,shift) then
       ProcessHotKey(key,shift); // hotkey processing is allowed by onKey handler
     if event='KEYUP' then
      if not FocusedElement.onKey(key,false,shift) then exit;
    end;

   finally
    window.Unlock;
   end;
  end;

 procedure onSimulateClick(event:TEventStr;tag:TTag); forward;
 procedure onSetFocus(event:TEventStr;tag:TTag); forward;

 { TUIScene }

 constructor TUIScene.Create;
  begin
   InitUI;
   // Register emQueued handlers once per render thread (not per scene).
   // emQueued binds the handler to the calling thread's queue — each window's render thread
   // gets its own entry and processes its own signals independently.
   // These signals are safe to send from any thread — they run in the correct render thread.
   if not threadHandlersRegistered then begin
    SetEventHandler('UI\CLICK',onSimulateClick,emQueued);
    SetEventHandler('UI\SetFocus',onSetFocus,emQueued);
    threadHandlersRegistered:=true;
   end;
   inherited Create(fullscreen);
   if sceneName='' then sceneName:=ClassName;
   name:=scenename;
   if wnd=nil then wnd:=mainWindow;
   UI:=TUIElement.Create(wnd.renderWidth,wnd.renderHeight,nil,sceneName);
   UI.ownerScene:=self;
   UI.enabled:=false;
   UI.visible:=false;
   if fullscreen then begin
    UI.shape:=shapeFull;
    UI.SetScale(defaultScale);
   end else begin
    // windowed
    UI.shape:=shapeEmpty;
    UI.SetScale(windowScale);
   end;

   if classType=TUIScene then onCreate;
   wnd.AddScene(self);
  end;

 function TUIScene.GetArea:TRect;
  var
   i:integer;
   r:TRect;
  begin
   result:=Rect(0,0,0,0); // empty
   if UI=nil then exit;
   if UI.shape<>shapeEmpty then
    result:=Rect(0,0,round(UI.size.x),round(UI.size.y));
   for i:=0 to high(UI.children) do
    with UI.children[i] do
     if shape<>shapeEmpty then begin
      r:=GetPosOnScreen;
      if IsRectEmpty(result) then
       result:=r
      else
       UnionRect(result,result,r); // именно в таком порядке, иначе - косяк!
     end;
   OffsetRect(result,round(UI.position.x),round(UI.position.y)); // actually, UI root shouldn't be displaced, but...
  end;

 procedure TUIScene.onMouseBtn(btn:byte;pressed:boolean);
  begin
   if (UI<>nil) and (not UI.enabled) then exit;
   inherited;
  end;

 procedure TUIScene.onMouseMove(x,y:integer);
  begin
   if (UI<>nil) and (not UI.enabled) then exit;
   inherited;
  end;

 procedure TUIScene.onMouseWheel(delta:integer);
  begin
   if (UI<>nil) and (not UI.enabled) then exit;
   inherited;
   if (modalElement=nil) or (modalElement=UI) then begin
     Signal('UI\'+name+'\MouseWheel',delta);
   end;
  end;

 procedure TUIScene.onResize;
  begin
    inherited;
    if UI<>nil then UI.Resize(window.renderWidth,window.renderHeight);
  end;

 function TUIScene.Process: boolean;
  var
   delta:integer;
   c:TUIElement;
   time:int64;
   st:String8;
   procedure ProcessElementTree(c:TUIElement);
    var
     cnt:integer;
     list:TUIElements;
     child:TUIElement;
    begin
     if c=nil then exit;
     if c.timer>0 then
      if c.timer<=delta then begin
       c.timer:=0;
       c.onTimer;
      end else dec(c.timer,delta);

     list:=c.children;
     for child in list do ProcessElementTree(child);
    end;
  begin
   result:=true;
   Signal('Scenes\ProcessScene\'+name);
   window.Lock;
   // отложенное удаление элементов

   // Размер корневого эл-та - полный экран
  { if (UI.ClassType=TUIControl) and (UI.x=0) and (UI.y=0) then begin
    UI.width:=areaWidth;
    UI.height:=areaHeight;
   end;}

   try
    FindElementAt(curMouseX,curMouseY,c);
    SetUnderMouse(c);

    // Обработка фокуса: если элемент с фокусом невидим или недоступен - убрать с него фокус
    // Исключение: корневой UI-элемент (при закрытии сцены фокус должен убрать эффект перехода)
    c:=FocusedElement;
    if c<>nil then begin
     repeat
      if not (c.visible and c.enabled) or
       ((modalElement<>nil) and (c.parent=nil) and (c<>modalElement)) then begin
       SetFocusTo(nil);
       Log.Msg(UI.name);
       break;
      end;
      c:=c.parent;
     until (c=nil) or (c.parent=nil);
    end;
    // Обработка захвата: если элемент, захвативший мышь, невидим или недоступен - убрать захват и фокус
    if hooked<>nil then begin
     if not (hooked.IsVisible and hooked.IsEnabled) or
      ((modalElement<>nil) and (hooked.GetRoot<>modalElement)) then begin
      hooked.onLostFocus;
      hooked:=nil;
      clipMouse:=cmNo;
     end;
    end;

    if LastHandleTime=0 then begin // первая обработка скипается
     LastHandleTime:=CoreTime.Ticks;
     exit;
    end;
    time:=CoreTime.Ticks;
    delta:=time-LastHandleTime;
    ProcessElementTree(UI);

    // обработка хинтов
    if (itemShowHintTime>LastHandleTime) and (itemShowHintTime<=Time) then begin
     FindElementAt(window.mouseX,window.mouseY,c);
     if (c<>nil) then begin
      if c.enabled then st:=c.hint
       else st:=c.hintIfDisabled;
      if st<>'' then begin
       ShowSimpleHint(st,nil,-1,-1,c.hintDuration);
       HintRect:=c.globalRect;
       HintMode:=time+5000;
       Signal('UI\onHint\'+c.ClassName+'\'+c.name);
      end;
     end;
    end;
    LastHandleTime:=time;
   finally
    window.Unlock;
   end;
  end;

  // tag: low 8 bit - new shadow value, next 16 bit - duration in ms
  procedure onSetGlobalShadow(event:TEventStr;tag:TTag);
  begin
   startShadowChange:=CoreTime.Ticks;
   shadowChangeDuration:=tag shr 8;
   oldShadowValue:=curShadowValue;
   needShadowValue:=tag and $FF;
  end;

  // registered with emQueued from each render thread (see TUIScene.Create)
  // safe to call from any thread: runs in the render thread owning the target element
  procedure onSetFocus(event:TEventStr;tag:TTag);
   var e:TUIElement; eName:String8;
  begin
   if window=nil then exit;
   delete(event,1,length('UI\SETFOCUS\'));
   eName:=event;
   window.Lock;
   try
    if (eName='') or (eName='NIL') then begin
     SetFocusTo(nil);
     exit;
    end;
    e:=FindElement(eName,false);
    if e=nil then exit; // element may belong to another window's handler
    if (e.GetRoot.ownerScene=nil) then exit;
    if TGameScene(e.GetRoot.ownerScene).ownerWindow<>window then exit;
    e.setFocus;
   finally
    window.Unlock;
   end;
  end;


 procedure TUIScene.Render;
  var
   t:int64;
  begin
   t:=CoreTime.Ticks;
   if t>=lastRenderTime then
    frametime:=t-lastRenderTime
   else begin
     frameTime:=1;
     Log.Force('Kosyak! '+inttostr(t)+' '+inttostr(lastRenderTime));
    end;
   lastRenderTime:=t;

   //Apus.Engine.UIRender.Frametime:=frametime;
   Signal('Scenes\'+name+'\BeforeRender');
   // StartMeasure(11); {TODO Migrate this}
   if UI<>nil then begin
    Signal('Scenes\'+name+'\BeforeUIRender');
    window.Lock;
    try
     try
      DrawUI(UI);
     except
      on e:exception do raise EError.Create('UI.DrawUI '+name+' Err '+e.message);
     end;
    finally
     window.Unlock;
    end;
    Signal('Scenes\'+name+'\AfterUIRender');
   end;
   //EndMeasure2(11);
  end;

 // signal UI\CLICK\{name}: simulate click on any UI element
 // registered with emQueued from each render thread — runs safely during HandleSignals
 // N handlers registered (one per render thread), only the one owning the element's window acts
 procedure onSimulateClick(event:TEventStr;tag:TTag);
 var
   name:String8; e:TUIElement; root:TUIElement;
 begin
   if window=nil then exit;
   name:=copy(event,length('UI\CLICK\')+1,length(event));
   if name='' then exit;
   window.Lock;
   try
     e:=FindElement(name,false);
     if e=nil then exit;
     if not e.IsVisible then exit;
     if not e.IsEnabled then exit;
     root:=e.GetRoot;
     if (root.ownerScene=nil) or (TGameScene(root.ownerScene).ownerWindow<>window) then exit;
     e.onMouseButtons(1,true);
     e.onMouseButtons(1,false);
   finally
     window.Unlock;
   end;
 end;

 // Called from TUIScene.Create (from whichever render thread creates the first scene).
 // Registers emInstant handlers that are ONLY sent by the platform layer (OS event dispatch)
 // from the render thread — Mouse, Kbd, ActivateWnd. emInstant fires in the calling thread,
 // so the 'window' threadvar is always valid. Multi-window works because each render thread
 // sends its own events.
 // EventMan deduplicates emInstant by (handler, event, threadNum=-1), so the 'initialized'
 // guard just avoids redundant lookups on subsequent TUIScene.Create calls.
 // WARNING: do NOT add emInstant handlers for signals that can be sent from non-render threads
 // (e.g. user signals from background logic) — 'window' threadvar will be nil there.
 // Such signals must use emQueued registered per render thread (see TUIScene.Create).
 procedure InitUI;
  begin
   if initialized then exit;
   SetEventHandler('Mouse',MouseEventHandler,emInstant);
   SetEventHandler('Kbd',KbdEventHandler,emInstant);
   SetEventHandler('Engine\ActivateWnd',ActivateEventHandler,emInstant);
   SetEventHandler('UI\SetGlobalShadow',onSetGlobalShadow,emInstant);
   initialized:=true;
  end;

 procedure TUIScene.SetStatus(st:TSceneStatus);
  var
   w,h:integer;
  begin
   inherited;
   Log.Force('Scene '+name+' status changed to '+statuses[st]);
  // Log.Msg('Scene '+name+' status changed to '+statuses[st],5);
   if (status=ssActive) and (UI=nil) then begin
    ASSERT(window<>nil,'TUIScene must be attached to a window before activation: '+name);
    w:=window.renderWidth;
    h:=window.renderHeight;
    UI:=TUIElement.Create(w,h,nil);
    UI.name:=name;
    UI.ownerScene:=self;
    UI.enabled:=false;
    UI.visible:=false;
   end;
   if UI<>nil then begin
    UI.enabled:=status=ssActive;
    ui.visible:=ui.enabled;
    if ui.enabled and (UI is TUIWindow) then
     UI.SetFocus;
   end;
  end;

 procedure TUIScene.WriteKey(key:cardinal);
  var
   scanCode:byte;
   charCode:integer;
  begin
   if (UI<>nil) and (not UI.enabled) then exit;
   inherited;

   if (FocusedElement<>nil) and (FocusedElement.HasParent(UI)) then begin
    charCode:=key shr 16;
    scanCode:=(key shr 8) and $FF;
    FocusedElement.onUniChar(Char32(charCode),scanCode);
   end;
  end;


 procedure TUIScene.BackgroundRenderBegin;
  begin
   Apus.Engine.UIRender.BackgroundRenderBegin;
  end;

procedure TUIScene.BackgroundRenderEnd;
  begin
   Apus.Engine.UIRender.BackgroundRenderEnd;
  end;

function TUIScene.GetUIRoot:TObject;
 begin
  result:=UI;
 end;

// --- Robot API command handlers ---

function ElementFlags(e:TUIElement):String8;
begin
  if e.visible then result:='visible' else result:='hidden';
  if e.enabled then result:=result+' enabled' else result:=result+' disabled';
end;

function ElementSummary(e:TUIElement; indent:integer):String8;
var
  pad:String8;
  r:TRect;
begin
  pad:='';
  while length(pad)<indent do pad:=pad+'  ';
  r:=e.GetPosOnScreen;
  result:=pad+'UI: '+e.name+' ['+String8(e.ClassName)+'] '+
    Conv.ToStr(r.Left)+','+Conv.ToStr(r.Top)+' '+
    Conv.ToStr(r.Width)+'x'+Conv.ToStr(r.Height)+' '+
    ElementFlags(e);
  if e.caption<>'' then
    result:=result+' caption="'+e.caption+'"';
  result:=result+#13#10;
end;

procedure DumpTree(e:TUIElement; depth,maxDepth:integer; var body:String8);
var
  i:integer;
begin
  body:=body+ElementSummary(e,depth);
  if (maxDepth>0) and (depth>=maxDepth) then exit;
  for i:=0 to high(e.children) do
    DumpTree(e.children[i],depth+1,maxDepth,body);
end;

function FindUISceneRoot(const sceneName:String8):TUIElement;
var
  s:TObject;
begin
  result:=nil;
  s:=TGameScene.FindByName(sceneName);
  if (s<>nil) and (s is TUIScene) then
    result:=TUIScene(s).UI;
end;

function RobotCmdUITree(const req:TRobotRequest; out body:String8):boolean;
var
  sceneName:String8;
  maxDepth,i:integer;
  root:TUIElement;
begin
  sceneName:=req.Param('SCENE');
  maxDepth:=Conv.ToInt(req.Param('DEPTH'));
  body:='';
   window.Lock;
  try
    if sceneName<>'' then begin
      root:=FindUISceneRoot(sceneName);
      if root=nil then begin
        body:='scene not found: '+sceneName;
        exit(false);
      end;
      DumpTree(root,0,maxDepth,body);
    end else begin
      if window<>nil then
       for i:=0 to high(window.scenes) do
        if (window.scenes[i] is TUIScene) and (TUIScene(window.scenes[i]).UI<>nil) then
          DumpTree(TUIScene(window.scenes[i]).UI,0,maxDepth,body);
    end;
   finally
    window.Unlock;
  end;
  result:=true;
end;

function RobotCmdUIElement(const req:TRobotRequest; out body:String8):boolean;
var
  eName:String8;
  includeHierarchy:boolean;
  e:TUIElement;
  chain:array of TUIElement;
  c:TUIElement;
  i,n:integer;

  function IsTrueValue(const st:String8):boolean;
  var
    v:String8;
  begin
    v:=st.Trim.ToLower;
    result:=(v='1') or (v='true') or (v='yes') or (v='on') or (v='y');
  end;

  function RectToStr(const r:TRect):String8;
  begin
    result:=Conv.ToStr(r.Left)+','+Conv.ToStr(r.Top)+','+Conv.ToStr(r.Right)+','+Conv.ToStr(r.Bottom);
  end;

  function PrefixLines(const text,prefix:String8):String8;
  var
    lines:Strings8;
    j:integer;
  begin
    result:='';
    lines:=text.SplitLines;
    for j:=0 to high(lines) do
      if lines[j]<>'' then
        result:=result+prefix+lines[j]+#13#10;
  end;

  procedure AppendElementInfo(el:TUIElement;prefix:String8);
  var
    r:TRect;
    sb:TUIScrollBar;
  begin
    r:=el.GetPosOnScreen; // always compute current rect
    body:=body+
      prefix+'name: '+el.name+#13#10+
      prefix+'class: '+String8(el.ClassName)+#13#10+
      prefix+'position: '+Conv.ToStr(el.position.x,1)+','+Conv.ToStr(el.position.y,1)+#13#10+
      prefix+'size: '+Conv.ToStr(el.size.x,1)+','+Conv.ToStr(el.size.y,1)+#13#10+
      prefix+'clientSize: '+Conv.ToStr(el.clientWidth,1)+','+Conv.ToStr(el.clientHeight,1)+#13#10+
      prefix+'anchors: '+Conv.ToStr(el.anchors.left,2)+','+Conv.ToStr(el.anchors.top,2)+','+
        Conv.ToStr(el.anchors.right,2)+','+Conv.ToStr(el.anchors.bottom,2)+#13#10+
      prefix+'pivot: '+Conv.ToStr(el.pivot.x,1)+','+Conv.ToStr(el.pivot.y,1)+#13#10+
      prefix+'scale: '+Conv.ToStr(el.scale,2)+#13#10+
      prefix+'globalRect: '+RectToStr(r)+#13#10+
      prefix+'visible: '+Conv.ToStr(el.visible)+#13#10+
      prefix+'visibleInternal: '+Conv.ToStr(el.visible)+#13#10+
      prefix+'visibleEffective: '+Conv.ToStr(el.IsVisible)+#13#10+
      prefix+'enabled: '+Conv.ToStr(el.enabled)+#13#10+
      prefix+'enabledInternal: '+Conv.ToStr(el.enabled)+#13#10+
      prefix+'enabledEffective: '+Conv.ToStr(el.IsEnabled)+#13#10+
      prefix+'parentClip: '+Conv.ToStr(el.parentClip)+#13#10+
      prefix+'clipChildren: '+Conv.ToStr(el.clipChildren)+#13#10+
      prefix+'order: '+Conv.ToStr(el.order)+#13#10+
      prefix+'caption: '+el.caption+#13#10+
      prefix+'hint: '+el.hint+#13#10+
      prefix+'styleInfo: '+el.styleInfo+#13#10+
      prefix+'color: '+Conv.ToHex(el.color)+#13#10+
      prefix+'font: '+Conv.ToStr(integer(el.font))+#13#10;
    if el is TUIScrollBar then begin
      sb:=TUIScrollBar(el);
      body:=body+
        prefix+'scrollMin: '+Conv.ToStr(sb.min,2)+#13#10+
        prefix+'scrollMax: '+Conv.ToStr(sb.max,2)+#13#10+
        prefix+'scrollPageSize: '+Conv.ToStr(sb.pagesize,2)+#13#10+
        prefix+'scrollValue: '+Conv.ToStr(sb.value,2)+#13#10+
        prefix+'scrollStep: '+Conv.ToStr(sb.step,2)+#13#10+
        prefix+'scrollHorizontal: '+Conv.ToStr(sb.horizontal)+#13#10+
        prefix+'scrollSlider: '+Conv.ToStr(sb.sliderStart,3)+'..'+Conv.ToStr(sb.sliderEnd,3)+#13#10;
    end;
    if el.layout<>nil then
      body:=body+PrefixLines(DescribeLayouter(el.layout,el),prefix);
    if el.parent<>nil then
      body:=body+prefix+'parent: '+el.parent.name+#13#10
    else
      body:=body+prefix+'parent: (none)'+#13#10;
    body:=body+prefix+'childCount: '+Conv.ToStr(length(el.children))+#13#10+
      prefix+'focused: '+Conv.ToStr(FocusedElement=el)+#13#10+
      prefix+'underMouse: '+Conv.ToStr(underMouse=el)+#13#10;
  end;
begin
  eName:=req.Param('NAME');
  includeHierarchy:=IsTrueValue(req.Param('HIERARCHY'));
  if eName='' then begin body:='NAME parameter required'; exit(false) end;
 window.Lock;
  try
    e:=FindElement(eName,false);
    if e=nil then begin body:='element not found: '+eName; exit(false) end;
    body:='';
    AppendElementInfo(e,'');
    if includeHierarchy then begin
      c:=e.parent; // requested element is already in the root block
      SetLength(chain,0);
      while c<>nil do begin
        n:=length(chain);
        SetLength(chain,n+1);
        chain[n]:=c;
        c:=c.parent;
      end;
      body:=body+'hierarchyCount: '+Conv.ToStr(length(chain))+#13#10;
      for i:=0 to high(chain) do begin
        body:=body+'HIERARCHY: '+Conv.ToStr(i+1)+#13#10;
        AppendElementInfo(chain[i],'  ');
      end;
    end;
 finally
  window.Unlock;
  end;
  result:=true;
end;

function RobotCmdUIHitTest(const req:TRobotRequest; out body:String8):boolean;
var
  x,y:integer;
  c,p:TUIElement;
  chain:String8;
  enabled:boolean;
begin
  x:=Conv.ToInt(req.Param('X'));
  y:=Conv.ToInt(req.Param('Y'));
  enabled:=FindAnyElementAt(x,y,c); // uses window lock internally
  if c=nil then begin
    body:='hit: (none)'+#13#10;
  end else begin
    chain:=c.name;
    p:=c.parent;
    while p<>nil do begin
      chain:=p.name+' > '+chain;
      p:=p.parent;
    end;
    body:='hit: '+c.name+#13#10+
      'hitClass: '+String8(c.ClassName)+#13#10+
      'chain: '+chain+#13#10+
      'enabled: '+Conv.ToStr(enabled)+#13#10;
  end;
  if modalElement<>nil then
    body:=body+'modal: '+modalElement.name+#13#10
  else
    body:=body+'modal: (none)'+#13#10;
  result:=true;
end;

// update UI scale for all scenes on the current window after DPI change
procedure OnDPIChanged(event:TEventStr;tag:TTag);
 var
  i:integer;
  scene:TGameScene;
 begin
  if window=nil then exit;
  window.Lock;
  try
   for i:=0 to high(window.scenes) do begin
    scene:=window.scenes[i];
    if scene is TUIScene then
     with TUIScene(scene) do
      if UI<>nil then begin
       if fullscreen then UI.SetScale(defaultScale)
        else UI.SetScale(windowScale);
      end;
   end;
  finally
   window.Unlock;
  end;
 end;

initialization
 SetEventHandler('ENGINE\DPICHANGED\DONE',OnDPIChanged,emInstant);
 RegisterRobotCommand('ui.tree',@RobotCmdUITree);
 RegisterRobotCommand('ui.element',@RobotCmdUIElement);
 RegisterRobotCommand('ui.hittest',@RobotCmdUIHitTest);
end.

