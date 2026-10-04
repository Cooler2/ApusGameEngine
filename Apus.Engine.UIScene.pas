// Common useful UI-related classes and routines
//
// Copyright (C) 2003-2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.UIScene;
interface
 uses Apus.Core, Apus.Engine.Scene, Apus.Engine.UITypes, Apus.Engine.Window, Apus.Engine.Keys;

var
 defaultScale:single=1.0;
 windowScale:single=1.0;

const
 defaultHintStyle:integer=0; // style of hints, can be changed

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
  function DispatchKey(key:TKey;scancode:integer;shift:byte;pressed:boolean):boolean; override;
  procedure WriteChar(ch:cardinal); override;
  function GetUIRoot:TObject; override;

  // These are markers for drawing scenes background to properly handle alpha channel of the render target to avoid wrong alpha blending
  // This is important ONLY if you are drawing semi-transparent pixels over the undefined (previous) content
  procedure BackgroundRenderBegin; virtual;
  procedure BackgroundRenderEnd; virtual;

 private
  lastRenderTime:int64;
  lastHandleTime:int64; // when Process last advanced the element timers, 0 - not yet
//  prevModal:TUIControl;
 end;

 // Get scene by name
 function UIScene(name:String8):TUIScene;

 // Window-level mouse dispatch (called once per window per event from TWindow,
 // NOT per active scene). They run the global UI hit-test once — so the topmost
 // UI element receives its event exactly once even with several active UIScene —
 // then forward raw events to gameplay scenes.
 procedure DispatchMouseMove(wnd:TWindow);
 procedure DispatchMouseButton(wnd:TWindow;btn:byte;pressed:boolean);
 procedure DispatchMouseWheel(wnd:TWindow;delta:integer);
 // Drop the mouse capture of wnd without a button release (its captor gets onLostFocus,
 // as when it is hidden) and stop a design-mode drag. Window's thread.
 procedure CancelMouseCapture(wnd:TWindow);

 // No need to call manually as it is called when any UIScene object is created
 procedure InitUI;

 // Create a popup hint and attach it to the given parent (nil: the root under the mouse of
 // the thread's window). Any thread. One such hint per window: the next call removes the
 // previous one (see TUIHint.Current). A parent outside any window shows nothing.
 procedure ShowSimpleHint(msg:string8;parent:TUIElement;x,y,time:integer;font:cardinal=0);

implementation
 uses SysUtils, Apus.Lib, Types,
   Apus.Engine.Types,
   Apus.EventMan, Apus.Publics,
   Apus.Engine.UI, Apus.Engine.UIWidgets, Apus.Engine.UIShapes, Apus.Engine.UIRender,
   Apus.Engine.UIScript,
   Apus.Engine.CmdProc, Apus.Engine.API,
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

 designMode:boolean; // режим "дизайна", в котором можно таскать элементы по экрану правой кнопкой мыши
 hookedItem:TUIElement; // element to drag with mouse


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
   wnd:TWindow;
   area:TRect;
  begin
   Log.Debug('ShowHint: '+msg);
   msg:=Translate(msg);
   // the parent's window; without a parent the hint goes under the mouse of the thread's window
   if parent<>nil then wnd:=parent.GetWindow
    else wnd:=window;
   if wnd=nil then begin
    Log.Msg('ShowSimpleHint: no window for "'+msg+'"');
    exit;
   end;
   wnd.LockState;
   try
    if (x=-1) or (y=-1) then begin
     x:=wnd.mousePos.x; y:=wnd.mousePos.y;
     area:=Rect(x-8,y-8,x+8,y+8);
    end else
     area:=Rect(0,0,4000,4000);
    if parent=nil then begin
     FindElementAt(x,y,parent);
     if parent=nil then begin
      if wnd.topmostScene is TUIScene then
       parent:=TUIScene(wnd.topmostScene).UI;
     end else
      parent:=parent.GetRoot;
     if parent=nil then exit;
    end;
    if TUIHint.Current(wnd)<>nil then begin
     Log.Debug('Remove previous hint');
     TUIHint.Current(wnd).Remove;
    end;
    hint:=TUIHint.Create(X/parent.scale,(Y+10)/parent.scale,msg,parent);
    if defaultHintStyle<>0 then hint.drawer:=GetUIStyle(defaultHintStyle);
    hint.timer:=time;
    hint.order:=10000; // Top
    wnd.hint.area:=area;
    hint.MakeCurrent;
    Log.Debug('Hint created '+inttohex(UIntPtr(hint),16));
   finally
    wnd.UnlockState;
   end;
  end;

 procedure ActivateEventHandler(event:TEventStr;tag:TTag);
  begin
   window.LockState;
   try
    if tag=0 then
     SetFocusTo(nil);
   finally
    window.UnlockState;
   end;
 end;

 procedure SetUnderMouse(e:TUIElement);
  begin
   Apus.Engine.UITypes.underMouse:=e;
  end;

 procedure MouseEventHandler(event:TEventStr;tag:TTag);
  begin
   event:=UpperCase(copy(event,7,length(event)-6));
   // update mouse position when it is stale (e.g. after scroll or window move)
   if event='UPDATEPOS' then
    Signal('Engine\Cmd\UpdateMousePos');
  end;

 procedure PrintUIlog;
  var
   st:String8;
  begin
   st:=' mouse clipping: '+inttostr(ord(clipMouse))+' ('+
     inttostr(clipMouserect.left)+','+inttostr(clipMouserect.top)+':'+
     inttostr(clipMouserect.right)+','+inttostr(clipMouserect.bottom)+')'+LineBreak;
   st:=st+' Modal element: ';
   if window.modal.Root<>nil then st:=st+window.modal.Root.name else st:=st+'none';
   Log.Force('UI state'+LineBreak+st);
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
   if wnd=nil then wnd:=mainWindow;
   inherited Create(sceneName,fullscreen,wnd);
   wnd:=TWindow(ownerWindow);
   ASSERT(wnd<>nil,'Can''t resolve owner window for scene '+name);
   if sceneName='' then sceneName:=name;
   UI:=TUIElement.Create(wnd.canvasWidth,wnd.canvasHeight,nil,sceneName);
   UI.ownerScene:=self;
   UI.flags.enabled:=false;
   UI.flags.visible:=false;
   if fullscreen then begin
    UI.shape:=shapeFull;
    UI.SetScale(defaultScale);
   end else begin
    // windowed
    UI.shape:=shapeEmpty;
    UI.SetScale(windowScale);
   end;

   if classType=TUIScene then onCreate;
  end;

 function TUIScene.GetArea:TRect;
  var
   i:integer;
   r:TRect;
  begin
   result:=Rect(0,0,0,0); // empty
   if UI=nil then exit;
   if UI.shape<>shapeEmpty then
    result:=UI.GetPosOnScreen;
   for i:=0 to high(UI.children) do
    with UI.children[i] do
     if shape<>shapeEmpty then begin
      r:=GetPosOnScreen;
      if IsRectEmpty(result) then
       result:=r
      else
       UnionRect(result,result,r); // именно в таком порядке, иначе - косяк!
     end;
   // Root and children are already in screen coordinates.
  end;

 // Window-level UI button dispatch: run the global hit-test once, deliver the
 // button to the topmost UI element exactly once (so several active UIScene can't
 // each toggle the same element), then forward the raw event to gameplay scenes.
 procedure DispatchMouseButton(wnd:TWindow;btn:byte;pressed:boolean);
  var
   c,c2:TUIElement;
   e:boolean;
   st:String8;
   i:integer;
  begin
   wnd.LockState;
   try
    DropRemovedMouseState;
    // sync UI coords from window — button events arrive before FlushMouseInput
    curMouseX:=wnd.mousePos.x;
    curMouseY:=wnd.mousePos.y;
    e:=FindElementAt(curMouseX,curMouseY,c);
    // A mouse-captured element (e.g. a scrollbar slider being dragged) must keep
    // receiving button events — above all the release that ends the capture. The
    // captor sets cmVirtual clipping, so the real mouse pos used here can be off
    // the (thin) element; without this redirect the release goes elsewhere via
    // FindElementAt, the capture (hooked/clipMouse) never clears, and input for
    // that subtree stays frozen.
    if hooked<>nil then begin
     c:=hooked;
     e:=true;
    end;
    if pressed then begin
     if e and (c<>nil) then
      c.onMouseButtons(btn,true)
     else if c<>nil then
      if (not c.flags.enabled) and c.GetClassAttribute('handleMouseIfDisabled') then
       c.onMouseButtons(btn,true);
     // design mode: drag element with Ctrl+RMB
     if (btn=2) and (designMode or Bits.HasAll(wnd.shiftState,sscCtrl)) then hookedItem:=c;
     // debug: Ctrl+MMB shows element info
     if (btn=3) and Bits.HasAll(wnd.shiftState,sscCtrl) then begin
      if c<>nil then begin
       st:=c.name;
       c2:=c;
       while c2.parent<>nil do begin
        c2:=c2.parent;
        st:=c2.name+'->'+st;
       end;
       ShowSimpleHint(c.ClassName+'('+st+')',c.GetRoot,-1,-1,5000);
       Log.Msg(Format('%s: pos: %.1f,%.1f pivot: %.1f %.1f size: %.1f,%.1f gRect: (%d %d %d %d) ',
        [c.name,c.position.x,c.position.y,c.pivot.x,c.pivot.y,c.size.x,c.size.y,
         c.globalRect.Left,c.globalRect.top,c.globalRect.right,c.globalRect.bottom]));
       if (wnd.shiftState and 2>0) and (c.name<>'') then
        ExecCmd('use '+c.name);
      end else begin
       st:='No opaque item here';
       FindAnyElementAt(curMouseX,curMouseY,c);
       if c<>nil then st:=st+'; '+c.ClassName+'('+c.name+')';
       ShowSimpleHint(st,nil,-1,-1,500+4000*byte(c<>nil));
      end;
     end;
    end else begin
     if (hookedItem<>nil) and (btn=2) then begin
      Log.Msg('x='+inttostr(round(hookedItem.position.x))+' y='+inttostr(round(hookedItem.position.y)));
      hookedItem:=nil;
     end;
     if e and (c<>nil) then c.onMouseButtons(btn,false);
    end;
   finally
    wnd.UnlockState;
   end;
   // forward the raw button to gameplay scenes (custom onMouseBtn overrides).
   // The UI element above already got its onMouseButtons exactly once, so this
   // never produces a double toggle even with several active UIScene.
   for i:=low(wnd.scenes) to high(wnd.scenes) do
    if wnd.scenes[i].IsActive then
     wnd.scenes[i].onMouseBtn(btn,pressed);
  end;

 // Window-level UI move dispatch: tracks the hovered element (enter/leave/move),
 // cursor and hints once per window, then decides whether the world (gameplay
 // scenes) sees the move. While the cursor sits over a consuming UI control the
 // world stays idle (the prior consumer got a single mkLeave); a fullscreen scene
 // root is NOT a consumer, so empty areas still feed gameplay moves.
 procedure DispatchMouseMove(wnd:TWindow);
  var
   x,y:integer;
   prevUnder,curUnder:TUIElement;
   moved,overUI,wasOverUI,deliver:boolean;
   time:int64;
   st:String8;
   i:integer;
  begin
   deliver:=false;
   wnd.LockState;
   time:=CoreTime.Ticks;
   try
    DropRemovedMouseState;
    x:=wnd.mousePos.x; y:=wnd.mousePos.y;
    // apply mouse clipping
    if ClipMouse<>cmNo then with clipMouseRect do begin
     if x<left then x:=left;
     if x>=right then x:=right-1;
     if y<top then y:=top;
     if y>=bottom then y:=bottom-1;
     if (clipMouse in [cmReal,cmLimited]) and ((curMouseX<>x) or (curMouseY<>y)) then
      if clipMouse=cmReal then exit;
     // NB: do NOT assign curMouseX:=x here for cmVirtual — x,y are already clamped
     // above and curMouseX is set below. Assigning early made oldMouseX==curMouseX,
     // so the move was always swallowed by the equality check → cmVirtual drags
     // (scrollbar slider etc.) never received onMouseMove.
    end;
    oldMouseX:=curMouseX; oldMouseY:=curMouseY;
    curMouseX:=x; curMouseY:=y;
    moved:=(curMouseX<>oldMouseX) or (curMouseY<>oldMouseY);

    // hide hint if mouse left hint rect
    {$IFNDEF IOS}
    if moved and (TUIHint.Current(wnd)<>nil) and TUIHint.Current(wnd).flags.visible and
       not PtInRect(wnd.hint.area,types.Point(curMouseX,curMouseY)) then TUIHint.Current(wnd).Hide;
    {$ENDIF}

    // design mode drag
    if moved and (hookedItem<>nil) then
     hookedItem.MoveBy(curMouseX-oldMouseX,curMouseY-oldMouseY);

    // hit-test current point; track enter/leave against the previously hovered
    // element so geometry changes under a still cursor also fire properly.
    prevUnder:=underMouse;
    FindElementAt(curMouseX,curMouseY,curUnder);
    if hooked<>nil then curUnder:=hooked; // a captured element keeps the hover
    SetUnderMouse(curUnder);
    if prevUnder<>curUnder then begin
     if prevUnder<>nil then prevUnder.onMouseMove; // leave the old element
     if curUnder<>nil then curUnder.onMouseMove;   // enter the new one
    end else
     if moved and (curUnder<>nil) then curUnder.onMouseMove; // move within the same one

    // update cursor
    if (curUnder<>nil) and (curUnder.cursor<>curCursor) then begin
     if curCursor<>CursorID.Default then begin
      game.ToggleCursor(curCursor,false);
      Signal('UI\Cursor\OFF',curCursor);
     end;
     curCursor:=curUnder.cursor;
     game.ToggleCursor(curCursor,true);
     Signal('UI\Cursor\ON',curCursor);
    end;
    if (curUnder=nil) and (curCursor<>CursorID.Default) then begin
     Signal('UI\Cursor\OFF',curCursor);
     game.ToggleCursor(curCursor,false);
     curCursor:=CursorID.Default;
     game.ToggleCursor(curCursor);
    end;

    // hover signals
    if prevUnder<>curUnder then begin
     if prevUnder<>nil then Signal('UI\onMouseOut\'+prevUnder.ClassName+'\'+prevUnder.name);
     if curUnder<>nil then Signal('UI\onMouseOver\'+curUnder.ClassName+'\'+curUnder.name);
    end;

    // hint timing
    if (curUnder<>nil) and (curUnder.flags.enabled and (curUnder.hint<>'') or
       not curUnder.flags.enabled and (curUnder.attributes.Item['hintIfDisabled']<>'')) then begin
     if curUnder.flags.enabled then st:=curUnder.hint
      else st:=curUnder.attributes.Item['hintIfDisabled'];
     with wnd.hint do begin
      if st<>lastText then begin
       if st='' then showTime:=0
       else begin
        if time<fastUntil then showTime:=time+250
         else showTime:=time+Conv.ToInt(curUnder.attributes.Item['hintDelay'],1000);
       end;
      end;
      lastText:=st;
     end;
    end else begin
     wnd.hint.showTime:=0;
     wnd.hint.lastText:='';
    end;

    // consumer model: a real control (not a fullscreen root) consumes the move;
    // decide what the world sees and which transition kind to tag it with.
    overUI:=(curUnder<>nil) and (curUnder.parent<>nil);
    wasOverUI:=wnd.mouseOverUI;
    if overUI then begin
     if not wasOverUI then begin wnd.moveKind:=mkLeave; deliver:=true; end
     // staying over UI → consumed, world stays idle
    end else begin
     if wasOverUI then wnd.moveKind:=mkEnter else wnd.moveKind:=mkMove;
     deliver:=moved or wasOverUI; // real movement, or the cursor just returned to the world
    end;
    wnd.mouseOverUI:=overUI;
   finally
    wnd.UnlockState;
   end;
   // forward the move to gameplay scenes (they read wnd.moveKind to know the kind)
   if deliver then
    for i:=low(wnd.scenes) to high(wnd.scenes) do
     if wnd.scenes[i].IsActive then
      wnd.scenes[i].onMouseMove(curMouseX,curMouseY);
  end;

 procedure CancelMouseCapture(wnd:TWindow);
  begin
   wnd.LockState;
   try
    DropRemovedMouseState;
    if hooked<>nil then begin
     hooked.onLostFocus;
     hooked:=nil;
    end;
    clipMouse:=cmNo;
    hookedItem:=nil;
   finally
    wnd.UnlockState;
   end;
  end;

 // Window-level UI wheel dispatch: the topmost UI element gets the wheel once; a
 // real control consumes it (gameplay doesn't see it), an empty area passes through.
 procedure DispatchMouseWheel(wnd:TWindow;delta:integer);
  var
   c:TUIElement;
   consumed:boolean;
   i:integer;
  begin
   consumed:=false;
   wnd.LockState;
   try
    DropRemovedMouseState;
    // sync UI coords from window — wheel events arrive before FlushMouseInput
    curMouseX:=wnd.mousePos.x;
    curMouseY:=wnd.mousePos.y;
    if FindElementAt(curMouseX,curMouseY,c) then begin
     c.onMouseScroll(delta);
     consumed:=c.parent<>nil; // a real control swallowed the wheel
    end;
   finally
    wnd.UnlockState;
   end;
   if not consumed then
    for i:=low(wnd.scenes) to high(wnd.scenes) do
     if wnd.scenes[i].IsActive then
      wnd.scenes[i].onMouseWheel(delta);
  end;

 procedure TUIScene.onResize;
  begin
    inherited;
    if UI<>nil then UI.Resize(window.canvasWidth,window.canvasHeight);
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
   window.LockState;
   // deferred removal of UI elements

   // Root UI element covers the whole screen.
  { if (UI.ClassType=TUIControl) and (UI.x=0) and (UI.y=0) then begin
    UI.width:=areaWidth;
    UI.height:=areaHeight;
   end;}

   try
    // NB: underMouse / hover transitions are owned by DispatchMouseMove (called once
    // per window every frame) — Process no longer touches it silently.

    // Focus handling: if focused element is hidden or disabled, clear focus.
    // Exception: root UI element, because scene close effects must clear it.
    c:=FocusedElement;
    if c<>nil then begin
     repeat
      if not (c.flags.visible and c.flags.enabled) or
       ((window.modal.Root<>nil) and (c.parent=nil) and (c<>window.modal.Root)) then begin
       SetFocusTo(nil);
       Log.Debug('Focus removed from: '+UI.name);
       break;
      end;
      c:=c.parent;
     until (c=nil) or (c.parent=nil);
    end;
    // Capture handling: if mouse captor is hidden or disabled, clear capture and focus.
    DropRemovedMouseState;
    if hooked<>nil then begin
     if not (hooked.IsVisible and hooked.IsEnabled) or
      ((window.modal.Root<>nil) and (hooked.GetRoot<>window.modal.Root)) then begin
      hooked.onLostFocus;
      hooked:=nil;
      clipMouse:=cmNo;
     end;
    end;

    if lastHandleTime=0 then begin // the first call only starts the clock
     lastHandleTime:=CoreTime.Ticks;
     exit;
    end;
    time:=CoreTime.Ticks;
    delta:=time-lastHandleTime;
    ProcessElementTree(UI);

    // обработка хинтов
    if (window.hint.showTime>lastHandleTime) and (window.hint.showTime<=Time) then begin
     FindElementAt(window.mousePos.x,window.mousePos.y,c);
     if (c<>nil) then begin
      if c.flags.enabled then st:=c.hint
       else st:=c.attributes.Item['hintIfDisabled'];
      if st<>'' then begin
       ShowSimpleHint(st,nil,-1,-1,Conv.ToInt(c.attributes.Item['hintDuration'],3000));
       window.hint.area:=c.globalRect;
       window.hint.fastUntil:=time+5000;
       Signal('UI\onHint\'+c.ClassName+'\'+c.name);
      end;
     end;
    end;
    lastHandleTime:=time;
   finally
    window.UnlockState;
   end;
  end;

  // the design-mode drag item must not outlive its element; elements are freed in their
  // window's thread, which owns hookedItem
  procedure onItemDestroyed(event:TEventStr;tag:TTag);
  begin
   if TObject(tag)=hookedItem then hookedItem:=nil;
  end;

  // registered with emQueued from each render thread (see TUIScene.Create)
  // safe to call from any thread: runs in the render thread owning the target element
  procedure onSetFocus(event:TEventStr;tag:TTag);
   var e:TUIElement; eName:String8;
  begin
   if window=nil then exit;
   delete(event,1,length('UI\SETFOCUS\'));
   eName:=event;
   window.LockState;
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
    window.UnlockState;
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
    window.LockState;
    try
     try
      gfx.SetCullMode(TCullMode.DrawAll);
      DrawUI(UI);
     except
      on e:exception do raise EError.Create('UI.DrawUI '+name+' Err '+e.message);
     end;
    finally
     window.UnlockState;
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
   window.LockState;
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
     window.UnlockState;
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
   // Keyboard is no longer consumed here: TGame buffers KBD\* into the kbd-topmost scene
   // and the engine drains it via TGameScene.PumpInput → TUIScene.DispatchKey (see below).
   SetEventHandler('Engine\ActivateWnd',ActivateEventHandler,emInstant);
   SetEventHandler('UI\ItemDestroyed',onItemDestroyed,emInstant);
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
    w:=window.canvasWidth;
    h:=window.canvasHeight;
    UI:=TUIElement.Create(w,h,nil);
    UI.name:=name;
    UI.ownerScene:=self;
    UI.flags.enabled:=false;
    UI.flags.visible:=false;
   end;
   if UI<>nil then begin
    UI.flags.enabled:=status=ssActive;
    ui.flags.visible:=ui.flags.enabled;
    if ui.flags.enabled and (UI is TUIWindow) then
     UI.SetFocus;
   end;
  end;

 // UI scene keyboard routing: focused element / hotkeys first, then gameplay (onKeyDown/Up).
 // Gameplay keys fire only when no UI element holds focus — so typing into a (modal) field
 // never leaks a gameplay key like [C] to the scene logic.
 function TUIScene.DispatchKey(key:TKey;scancode:integer;shift:byte;pressed:boolean):boolean;
  var
   c:TUIElement;
   keyc:integer;
   uiConsumed,hasFocus:boolean;
  begin
   uiConsumed:=false;
   hasFocus:=false;
   keyc:=ord(key);
   window.LockState;
   try
    if (UI<>nil) and UI.flags.enabled then begin
     if pressed and (keyc=ord('S')) and (shift=8+2) then PrintUILog; // Win+Ctrl+S
     c:=FocusedElement;
     if c<>nil then begin
      hasFocus:=true;
      if c.IsEnabled then
       if pressed then begin
        if c.onKey(keyc,true,shift) then
         uiConsumed:=ProcessHotKey(keyc,shift) // onKey allowed hotkey processing
        else
         uiConsumed:=true;                     // focus consumed the key
       end else
        if not c.onKey(keyc,false,shift) then uiConsumed:=true;
     end else
      // no focus — UI hotkeys may still claim the key
      if pressed then uiConsumed:=ProcessHotKey(keyc,shift);
    end;
   finally
    window.UnlockState;
   end;
   if uiConsumed then exit(true);
   if hasFocus then exit(false); // a focused element captures input → gameplay is suppressed
   result:=inherited DispatchKey(key,scancode,shift,pressed); // scene hotkeys + onKeyDown/Up
  end;

 procedure TUIScene.WriteChar(ch:cardinal);
  var
   scanCode:byte;
   charCode:integer;
  begin
   if (UI<>nil) and (not UI.flags.enabled) then exit;
   inherited; // buffer for polling (ReadKey)

   if (FocusedElement<>nil) and (FocusedElement.HasParent(UI)) then begin
    charCode:=ch shr 16;
    scanCode:=(ch shr 8) and $FF;
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
  if e.flags.visible then result:='visible' else result:='hidden';
  if e.flags.enabled then result:=result+' enabled' else result:=result+' disabled';
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
  result:=result+LineBreak;
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
   window.LockState;
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
    window.UnlockState;
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
        result:=result+prefix+lines[j]+LineBreak;
  end;

  procedure AppendElementInfo(el:TUIElement;prefix:String8);
  var
    r:TRect;
    sb:TUIScrollBar;
  begin
    r:=el.GetPosOnScreen; // always compute current rect
    body:=body+
      prefix+'name: '+el.name+LineBreak+
      prefix+'class: '+String8(el.ClassName)+LineBreak+
      prefix+'position: '+Conv.ToStr(el.position.x,1)+','+Conv.ToStr(el.position.y,1)+LineBreak+
      prefix+'size: '+Conv.ToStr(el.size.x,1)+','+Conv.ToStr(el.size.y,1)+LineBreak+
      prefix+'clientSize: '+Conv.ToStr(el.clientWidth,1)+','+Conv.ToStr(el.clientHeight,1)+LineBreak+
      prefix+'anchors: '+Conv.ToStr(el.anchors.left,2)+','+Conv.ToStr(el.anchors.top,2)+','+
        Conv.ToStr(el.anchors.right,2)+','+Conv.ToStr(el.anchors.bottom,2)+LineBreak+
      prefix+'pivot: '+Conv.ToStr(el.pivot.x,1)+','+Conv.ToStr(el.pivot.y,1)+LineBreak+
      prefix+'scale: '+Conv.ToStr(el.scale,2)+LineBreak+
      prefix+'globalRect: '+RectToStr(r)+LineBreak+
      prefix+'visible: '+Conv.ToStr(el.flags.visible)+LineBreak+
      prefix+'visibleInternal: '+Conv.ToStr(el.flags.visible)+LineBreak+
      prefix+'visibleEffective: '+Conv.ToStr(el.IsVisible)+LineBreak+
      prefix+'enabled: '+Conv.ToStr(el.flags.enabled)+LineBreak+
      prefix+'enabledInternal: '+Conv.ToStr(el.flags.enabled)+LineBreak+
      prefix+'enabledEffective: '+Conv.ToStr(el.IsEnabled)+LineBreak+
      prefix+'noParentClip: '+Conv.ToStr(el.flags.noParentClip)+LineBreak+
      prefix+'dontClipChildren: '+Conv.ToStr(el.flags.dontClipChildren)+LineBreak+
      prefix+'order: '+Conv.ToStr(el.order)+LineBreak+
      prefix+'caption: '+el.caption+LineBreak+
      prefix+'hint: '+el.hint+LineBreak+
      prefix+'styleInfo: '+el.styleInfo+LineBreak+
      prefix+'color: '+el.GetStyleValue('color','')+LineBreak;
    if el is TUIScrollBar then begin
      sb:=TUIScrollBar(el);
      body:=body+
        prefix+'scrollMin: '+Conv.ToStr(sb.min,2)+LineBreak+
        prefix+'scrollMax: '+Conv.ToStr(sb.max,2)+LineBreak+
        prefix+'scrollPageSize: '+Conv.ToStr(sb.pagesize,2)+LineBreak+
        prefix+'scrollValue: '+Conv.ToStr(sb.value,2)+LineBreak+
        prefix+'scrollStep: '+Conv.ToStr(sb.step,2)+LineBreak+
        prefix+'scrollHorizontal: '+Conv.ToStr(sb.horizontal)+LineBreak+
        prefix+'scrollSlider: '+Conv.ToStr(sb.sliderStart,3)+'..'+Conv.ToStr(sb.sliderEnd,3)+LineBreak;
    end;
    if el.layout<>nil then
      body:=body+PrefixLines(DescribeLayouter(el.layout,el),prefix);
    if el.parent<>nil then
      body:=body+prefix+'parent: '+el.parent.name+LineBreak
    else
      body:=body+prefix+'parent: (none)'+LineBreak;
    body:=body+prefix+'childCount: '+Conv.ToStr(length(el.children))+LineBreak+
      prefix+'focused: '+Conv.ToStr(FocusedElement=el)+LineBreak+
      prefix+'underMouse: '+Conv.ToStr(underMouse=el)+LineBreak;
  end;
begin
  eName:=req.Param('NAME');
  includeHierarchy:=IsTrueValue(req.Param('HIERARCHY'));
  if eName='' then begin body:='NAME parameter required'; exit(false) end;
 window.LockState;
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
      body:=body+'hierarchyCount: '+Conv.ToStr(length(chain))+LineBreak;
      for i:=0 to high(chain) do begin
        body:=body+'HIERARCHY: '+Conv.ToStr(i+1)+LineBreak;
        AppendElementInfo(chain[i],'  ');
      end;
    end;
 finally
  window.UnlockState;
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
    body:='hit: (none)'+LineBreak;
  end else begin
    chain:=c.name;
    p:=c.parent;
    while p<>nil do begin
      chain:=p.name+' > '+chain;
      p:=p.parent;
    end;
    body:='hit: '+c.name+LineBreak+
      'hitClass: '+String8(c.ClassName)+LineBreak+
      'chain: '+chain+LineBreak+
      'enabled: '+Conv.ToStr(enabled)+LineBreak;
  end;
  if window.modal.Root<>nil then
    body:=body+'modal: '+window.modal.Root.name+LineBreak
  else
    body:=body+'modal: (none)'+LineBreak;
  result:=true;
end;

// --- Robot API: virtual mouse (robot_api_protocol.md, "Mouse input") ---
// The handlers run in the main loop thread only, so the lists below need no lock.
// They never touch a window: only its TVirtualMouse, which outlives it.

type
 TRobotMouseRequest=record
  serial:int64;        // TRobotRequest.serial
  mouse:TVirtualMouse; // AddRef'ed
  ticket:int64;        // the request is answered once this operation is done
 end;

var
 robotMouseRequests:array of TRobotMouseRequest; // postponed (waiting) requests
 robotMice:array of TVirtualMouse; // mice the robot switched to the virtual mode (AddRef'ed)

function RobotFlag(const st:String8;default:boolean;out value:boolean):boolean;
 var
  v:String8;
 begin
  v:=st.Trim.ToLower;
  result:=true;
  if v='' then value:=default
  else if (v='1') or (v='yes') or (v='y') or (v='true') or (v='on') then value:=true
  else if (v='0') or (v='no') or (v='n') or (v='false') or (v='off') then value:=false
  else result:=false;
 end;

function RobotButtonsStr(buttons:byte):String8;
 const
  names:array[0..4] of String8=('left','right','middle','x1','x2');
 var
  i:integer;
 begin
  result:='';
  for i:=0 to 4 do
   if (buttons and (1 shl i))<>0 then begin
    if result<>'' then result:=result+',';
    result:=result+names[i];
   end;
  if result='' then result:='none';
 end;

function RobotMouseReport(vm:TVirtualMouse;ticket:int64;done:boolean):String8;
 var
  st:TVirtualMouseState;
  wndName:String8;
 begin
  st:=vm.State;
  if vm.IsMainWindow then wndName:='main' else wndName:=vm.windowName;
  result:='window: '+wndName+LineBreak;
  if ticket>0 then begin
   result:=result+'ticket: '+Conv.ToStr(ticket)+LineBreak;
   if done then result:=result+'state: done'+LineBreak
    else result:=result+'state: queued'+LineBreak;
  end;
  if st.active then result:=result+'mode: virtual'+LineBreak
   else result:=result+'mode: physical'+LineBreak;
  if (st.pos.x>=$3FFF) or (st.pos.y>=$3FFF) then result:=result+'position: outside'+LineBreak
   else result:=result+'position: '+Conv.ToStr(st.pos.x)+','+Conv.ToStr(st.pos.y)+LineBreak;
  result:=result+'buttons: '+RobotButtonsStr(st.buttons)+LineBreak;
  if st.underClass='' then result:=result+'under: (none)'+LineBreak
   else result:=result+'under: '+st.under+LineBreak+'underClass: '+st.underClass+LineBreak;
  result:=result+'queued: '+Conv.ToStr(vm.QueuedCount)+LineBreak+
   'frame: '+Conv.ToStr(st.frame)+LineBreak;
 end;

// Mouse of the WINDOW parameter (AddRef'ed); needVirtual - the virtual mode must be on
// (as requested, i.e. after the operations queued so far)
function RobotMouseTarget(const req:TRobotRequest;needVirtual:boolean;
  out vm:TVirtualMouse;out err:String8):boolean;
 begin
  vm:=FindVirtualMouse(req.Param('WINDOW'));
  if vm=nil then begin
   err:='window not found: '+req.Param('WINDOW');
   exit(false);
  end;
  if needVirtual and not vm.RequestedActive then begin
   vm.Release;
   vm:=nil;
   err:='virtual mouse is off: send mouse.mode with MODE: virtual first';
   exit(false);
  end;
  result:=true;
 end;

procedure RobotMouseTrack(vm:TVirtualMouse;enabled:boolean);
 var
  i:integer;
 begin
  for i:=high(robotMice) downto 0 do
   if (robotMice[i]=vm) or robotMice[i].IsClosed then begin
    robotMice[i].Release;
    robotMice[i]:=robotMice[high(robotMice)];
    SetLength(robotMice,high(robotMice));
   end;
  if enabled then begin
   vm.AddRef;
   i:=length(robotMice);
   SetLength(robotMice,i+1);
   robotMice[i]:=vm;
  end;
 end;

// Queue the operations of a request, answer at once (WAIT: no) or postpone it until the
// last one is applied. Takes over the caller's reference to vm.
function RobotMouseQueue(const req:TRobotRequest;vm:TVirtualMouse;
  const ops:array of TVirtualMouseOp;out body:String8):boolean;
 var
  i,n:integer;
  ticket:int64;
  wait:boolean;
 begin
  result:=false;
  try
   if not RobotFlag(req.Param('WAIT'),true,wait) then begin
    body:='WAIT should be yes or no';
    exit;
   end;
   ticket:=0;
   for i:=0 to high(ops) do begin
    ticket:=vm.Queue(ops[i]);
    if ticket=0 then begin
     body:='window is closing';
     exit;
    end;
   end;
   if not wait then begin
    body:=RobotMouseReport(vm,ticket,vm.TicketState(ticket)=vmtDone);
    exit(true);
   end;
   n:=length(robotMouseRequests);
   SetLength(robotMouseRequests,n+1);
   robotMouseRequests[n].serial:=req.serial;
   robotMouseRequests[n].mouse:=vm;
   robotMouseRequests[n].ticket:=ticket;
   vm:=nil; // the entry holds the reference now
   body:=PENDING_ORDERED_TOKEN;
   result:=true;
  finally
   if vm<>nil then vm.Release;
  end;
 end;

// A postponed request is retried every poll: it only checks its operations, never
// queues them again
function RobotMouseContinue(const req:TRobotRequest;out body:String8):boolean;
 var
  i:integer;
  vm:TVirtualMouse;
  state:TVirtualMouseTicket;
 begin
  for i:=0 to high(robotMouseRequests) do
   if robotMouseRequests[i].serial=req.serial then begin
    vm:=robotMouseRequests[i].mouse;
    state:=vm.TicketState(robotMouseRequests[i].ticket);
    if state=vmtPending then begin
     body:=PENDING_ORDERED_TOKEN;
     exit(true);
    end;
    if state=vmtDone then begin
     body:=RobotMouseReport(vm,robotMouseRequests[i].ticket,true);
     result:=true;
    end else begin
     if vm.IsClosed then body:='window closed before the input was applied'
      else body:='input was cancelled before it was applied';
     result:=false;
    end;
    vm.Release;
    robotMouseRequests[i]:=robotMouseRequests[high(robotMouseRequests)];
    SetLength(robotMouseRequests,high(robotMouseRequests));
    exit;
   end;
  body:='request state lost';
  result:=false;
 end;

function RobotParseButton(const req:TRobotRequest;out btn:byte;out err:String8):boolean;
 var
  st:String8;
 begin
  st:=req.Param('BUTTON').Trim.ToLower;
  result:=true;
  if (st='') or (st='left') or (st='1') then btn:=1
  else if (st='right') or (st='2') then btn:=2
  else if (st='middle') or (st='3') then btn:=3
  else begin
   err:='unknown BUTTON: '+st+' (expected left, right or middle)';
   result:=false;
  end;
 end;

// X,Y (+SPACE) into a move operation; optional - both may be absent (hasPos=false)
function RobotParseMove(const req:TRobotRequest;optional:boolean;out op:TVirtualMouseOp;
  out hasPos:boolean;out err:String8):boolean;
 var
  sx,sy,space:String8;
  x,y:integer;
 begin
  result:=false;
  FillChar(op,sizeof(op),0);
  op.kind:=vmoMove;
  sx:=req.Param('X').Trim;
  sy:=req.Param('Y').Trim;
  hasPos:=(sx<>'') or (sy<>'');
  if not hasPos then begin
   if not optional then err:='X and Y parameters required'
    else result:=true;
   exit;
  end;
  if (sx='') or (sy='') then begin
   err:='X and Y should be both specified or both omitted';
   exit;
  end;
  if not (TryStrToInt(string(sx),x) and TryStrToInt(string(sy),y)) then begin
   err:='X and Y should be integers';
   exit;
  end;
  op.pos:=Types.Point(x,y);
  space:=req.Param('SPACE').Trim.ToLower;
  if (space<>'') and (space<>'canvas') and (space<>'client') then begin
   err:='unknown SPACE: '+space+' (expected canvas or client)';
   exit;
  end;
  op.clientSpace:=space='client';
  result:=true;
 end;

function ButtonOp(btn:byte;pressed:boolean):TVirtualMouseOp;
 begin
  FillChar(result,sizeof(result),0);
  result.kind:=vmoButton;
  result.button:=btn;
  result.pressed:=pressed;
 end;

function RobotCmdMouseMode(const req:TRobotRequest; out body:String8):boolean;
 var
  vm:TVirtualMouse;
  mode:String8;
  op:TVirtualMouseOp;
 begin
  if req.attempt>0 then exit(RobotMouseContinue(req,body));
  mode:=req.Param('MODE').Trim.ToLower;
  if (mode<>'virtual') and (mode<>'physical') then begin
   body:='MODE should be virtual or physical';
   exit(false);
  end;
  if not RobotMouseTarget(req,false,vm,body) then exit(false);
  FillChar(op,sizeof(op),0);
  op.kind:=vmoMode;
  op.enable:=mode='virtual';
  RobotMouseTrack(vm,op.enable);
  result:=RobotMouseQueue(req,vm,[op],body);
 end;

function RobotCmdMouseReset(const req:TRobotRequest; out body:String8):boolean;
 var
  vm:TVirtualMouse;
  op:TVirtualMouseOp;
 begin
  if req.attempt>0 then exit(RobotMouseContinue(req,body));
  if not RobotMouseTarget(req,false,vm,body) then exit(false);
  if not vm.RequestedActive then begin // physical mode: nothing to reset
   body:=RobotMouseReport(vm,0,true);
   vm.Release;
   exit(true);
  end;
  FillChar(op,sizeof(op),0);
  op.kind:=vmoReset;
  result:=RobotMouseQueue(req,vm,[op],body);
 end;

function RobotCmdMouseMove(const req:TRobotRequest; out body:String8):boolean;
 var
  vm:TVirtualMouse;
  op:TVirtualMouseOp;
  hasPos:boolean;
 begin
  if req.attempt>0 then exit(RobotMouseContinue(req,body));
  if not RobotParseMove(req,false,op,hasPos,body) then exit(false);
  if not RobotMouseTarget(req,true,vm,body) then exit(false);
  result:=RobotMouseQueue(req,vm,[op],body);
 end;

// mouse.down, mouse.up, mouse.click
function RobotMouseButtonCmd(const req:TRobotRequest;down,up:boolean;out body:String8):boolean;
 var
  vm:TVirtualMouse;
  move:TVirtualMouseOp;
  ops:array of TVirtualMouseOp;
  hasPos,isDown:boolean;
  btn:byte;
 begin
  if req.attempt>0 then exit(RobotMouseContinue(req,body));
  if not RobotParseButton(req,btn,body) then exit(false);
  if not RobotParseMove(req,true,move,hasPos,body) then exit(false);
  if not RobotMouseTarget(req,true,vm,body) then exit(false);
  isDown:=(vm.RequestedButtons and (1 shl (btn-1)))<>0;
  if down and isDown then body:='button is already down: '+req.Param('BUTTON')
  else if up and not down and not isDown then body:='button is not down: '+req.Param('BUTTON')
  else body:='';
  if body<>'' then begin
   vm.Release;
   exit(false);
  end;
  SetLength(ops,0);
  if hasPos then ops:=[move];
  if down then ops:=ops+[ButtonOp(btn,true)];
  if up then ops:=ops+[ButtonOp(btn,false)];
  result:=RobotMouseQueue(req,vm,ops,body);
 end;

function RobotCmdMouseDown(const req:TRobotRequest; out body:String8):boolean;
 begin
  result:=RobotMouseButtonCmd(req,true,false,body);
 end;

function RobotCmdMouseUp(const req:TRobotRequest; out body:String8):boolean;
 begin
  result:=RobotMouseButtonCmd(req,false,true,body);
 end;

function RobotCmdMouseClick(const req:TRobotRequest; out body:String8):boolean;
 begin
  result:=RobotMouseButtonCmd(req,true,true,body);
 end;

function RobotCmdMouseState(const req:TRobotRequest; out body:String8):boolean;
 var
  vm:TVirtualMouse;
 begin
  if not RobotMouseTarget(req,false,vm,body) then exit(false);
  body:=RobotMouseReport(vm,0,true);
  vm.Release;
  result:=true;
 end;

// Postponed until every operation queued for the window so far is applied
function RobotCmdMouseWait(const req:TRobotRequest; out body:String8):boolean;
 var
  vm:TVirtualMouse;
  n:integer;
 begin
  if req.attempt>0 then exit(RobotMouseContinue(req,body));
  if not RobotMouseTarget(req,false,vm,body) then exit(false);
  if vm.TicketState(vm.LastTicket)<>vmtPending then begin
   body:=RobotMouseReport(vm,0,true);
   vm.Release;
   exit(true);
  end;
  n:=length(robotMouseRequests);
  SetLength(robotMouseRequests,n+1);
  robotMouseRequests[n].serial:=req.serial;
  robotMouseRequests[n].mouse:=vm;
  robotMouseRequests[n].ticket:=vm.LastTicket;
  body:=PENDING_ORDERED_TOKEN;
  result:=true;
 end;

// Robot API is shutting down: its pending requests are gone, and no window must stay
// in the virtual mode with nobody to drive it
procedure RobotMouseShutdown;
 var
  i:integer;
  op:TVirtualMouseOp;
 begin
  for i:=0 to high(robotMouseRequests) do
   robotMouseRequests[i].mouse.Release;
  SetLength(robotMouseRequests,0);
  FillChar(op,sizeof(op),0);
  op.kind:=vmoMode;
  op.enable:=false;
  for i:=0 to high(robotMice) do begin
   robotMice[i].Cancel;
   robotMice[i].Queue(op); // no-op for a closed window
   robotMice[i].Release;
  end;
  SetLength(robotMice,0);
 end;

// update UI scale for all scenes of the rebuilt window after a DPI change
procedure OnSurfaceChanged(event:TEventStr;tag:TTag);
 var
  i:integer;
  scene:TGameScene;
  wnd:TWindow;
 begin
  wnd:=TWindow(UIntPtr(tag));
  if wnd=nil then exit;
  if not (TSurfaceChange.dpi in wnd.surface.changes) then exit;
  wnd.LockState;
  try
   for i:=0 to high(wnd.scenes) do begin
    scene:=wnd.scenes[i];
    if scene is TUIScene then
     with TUIScene(scene) do
      if UI<>nil then begin
       if fullscreen then UI.SetScale(defaultScale)
        else UI.SetScale(windowScale);
      end;
   end;
  finally
   wnd.UnlockState;
  end;
 end;

initialization
 SetEventHandler('ENGINE\SURFACECHANGED',OnSurfaceChanged,emInstant);
 RegisterRobotCommand('ui.tree',@RobotCmdUITree);
 RegisterRobotCommand('ui.element',@RobotCmdUIElement);
 RegisterRobotCommand('ui.hittest',@RobotCmdUIHitTest);
 RegisterRobotCommand('mouse.mode',@RobotCmdMouseMode);
 RegisterRobotCommand('mouse.reset',@RobotCmdMouseReset);
 RegisterRobotCommand('mouse.move',@RobotCmdMouseMove);
 RegisterRobotCommand('mouse.down',@RobotCmdMouseDown);
 RegisterRobotCommand('mouse.up',@RobotCmdMouseUp);
 RegisterRobotCommand('mouse.click',@RobotCmdMouseClick);
 RegisterRobotCommand('mouse.state',@RobotCmdMouseState);
 RegisterRobotCommand('mouse.wait',@RobotCmdMouseWait);
 RegisterRobotShutdownHandler(RobotMouseShutdown);
 end.
