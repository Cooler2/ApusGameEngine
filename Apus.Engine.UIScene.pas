// Common useful UI-related classes and routines
//
// Copyright (C) 2003-2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.UIScene;
interface
 uses Apus.Crossplatform, Apus.Types, Apus.Engine.Scene, Apus.Engine.UITypes;

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
  constructor Create(scenename:string='';fullScreen:boolean=true);
  procedure SetStatus(st:TSceneStatus); override;
  function Process:boolean; override;
  procedure Render; override;
  procedure onResize; override;
  function GetArea:TRect; override; // screen area occupied by any non-transparent UI elements (i.e. which part of screen can't be ignored)
  procedure WriteKey(key:cardinal); override;
  procedure onMouseMove(x,y:integer); override;
  procedure onMouseBtn(btn:byte;pressed:boolean); override;
  procedure onMouseWheel(delta:integer); override;

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

 // Установка размера (виртуального) экрана для UI (зачем!?)
 procedure SetDisplaySize(width,height:integer);

 // Создать всплывающее окно, прицепить его к указанному предку
 procedure ShowSimpleHint(msg:string;parent:TUIElement;x,y,time:integer;font:cardinal=0);

implementation
 uses SysUtils, Types,
   Apus.MyServis, Apus.EventMan, Apus.Publics, Apus.Geom2D,
   Apus.Engine.UI, Apus.Engine.UIWidgets, Apus.Engine.UIRender,
   Apus.Engine.CmdProc, Apus.Engine.Console, Apus.Engine.API;

const
 statuses:array[TSceneStatus] of string=('frozen','background','active');

var
 curCursor:integer;
 initialized:boolean=false;
 rootWidth,rootHeight,oldRootWidth,oldAreaHeight:integer; // размер области отрисовки

 LastHandleTime:int64;

 // параметры хинтов
 curHint:TUIHint=nil;
 hintRect:tRect; // область, к которой относится хинт
 // переменные для работы с хинтами элементов
 hintMode:cardinal; // время (в тиках), до которого длится режим показа хинтов
                   // в этом режиме хинты выпадают гораздо быстрее
 itemShowHintTime:cardinal; // момент времени, когда элемент должен показать хинт
 lastHint:string; // текст хинта, соответствующего элементу, над которым была мышь в предыдущем кадре

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

procedure SetDisplaySize(width,height:integer);
 begin
  LogMessage('UIScene.SDS');
  oldRootWidth:=rootWidth;
  oldAreaHeight:=rootHeight;
  rootWidth:=width;
  rootHeight:=height;
 end;

 procedure ShowSimpleHint;
  var
   hint:TUIHint;
   i:integer;
  begin
   LogMessage('ShowHint: '+msg);
   msg:=Translate(Str16(msg));
   if (x=-1) or (y=-1) then begin
    x:=curMouseX; y:=curMouseY;
    hintRect:=Rect(x-8,y-8,x+8,y+8);
   end else begin
    hintRect:=Rect(0,0,4000,4000);
   end;
   if parent=nil then begin
    FindControlAt(x,y,parent);
    if parent=nil then begin
     for i:=0 to high(rootElements) do
      if rootElements[i].visible then begin
       parent:=rootElements[i]; break;
      end;
    end else
     parent:=parent.GetRoot;
   end;
   if curhint<>nil then begin
    LogMessage('Free previous hint');
    curHint.Free;
    curHint:=nil;
   end;
   hint:=TUIHint.Create(X,Y+10,msg,false,parent);
   hint.font:=font;
   hint.style:=defaultHintStyle;
   hint.timer:=time;
   hint.order:=10000; // Top
   curhint:=hint;
   LogMessage('Hint created '+inttohex(cardinal(hint),8));
  end;

 procedure ActivateEventHandler(event:TEventStr;tag:TTag);
  begin
   EnterCriticalSection(UICritSect);
   try
    if tag=0 then
     SetFocusTo(nil);
   finally
    LeaveCriticalSection(UICritSect);
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
   st:string;
  begin
   event:=UpperCase(copy(event,7,length(event)-6));
   EnterCriticalSection(UICritSect);
   time:=MyTickCount;
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

     e1:=FindControlAt(oldMouseX,oldMouseY,c);
     e2:=FindControlAt(curMouseX,curMouseY,c2);
     if e2 then SetUnderMouse(c2)
      else SetUnderMouse(nil);
     if e1 then c.onMouseMove;
     if e2 and (c2<>c) then c2.onMouseMove;
     e2:=FindControlAt(curMouseX,curMouseY,c2);

     // Курсор
     if e2 and (c2.cursor<>curCursor) then begin
      if curCursor<>crDefault then begin
       game.ToggleCursor(curCursor,false);
       Signal('UI\Cursor\OFF',curCursor);
      end;
      curCursor:=c2.cursor;
      game.ToggleCursor(curCursor,true);
      Signal('UI\Cursor\ON',curCursor);
     end;
     if not e2 and (curCursor<>crDefault) then begin
      Signal('UI\Cursor\OFF',curCursor);
      game.ToggleCursor(curCursor,false);
      curCursor:=crDefault;
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
     e:=FindControlAt(curMouseX,curMouseY,c);
     if e and (c<>nil) then
      c.onMouseButtons(tag,true)
     else
      if (c<>nil) and (not c.enabled) and (c.GetClassAttribute('handleMouseIfDisabled')) then
       c.onMouseButtons(tag,true);

     // DEBUG FACILITIES
     // Drag elements with Ctrl+RMB
     if (tag=2) and
        (designmode or HasFlag(lastShiftState,sscCtrl)) then hookedItem:=c;
     // Показать название и св-ва элемента
     if (tag=3) and HasFlag(lastShiftState,sscCtrl) then
      if c<>nil then begin
        st:=c.name;
        c2:=c;
        while c2.parent<>nil do begin
         c2:=c2.parent;
         st:=c2.name+'->'+st;
        end;
        ShowSimpleHint(c.ClassName+'('+st+')',c.GetRoot,-1,-1,5000);
        PutMsg(Format('%s: %.1f,%.1f %.1f,%.1f',[c.name,c.position.x,c.position.y,c.size.x,c.size.y]));
        if game.shiftstate and 2>0 then // Shift pressed => select item
          ExecCmd('use '+c.name);
      end else begin
       st:='No opaque item here';
       FindAnyControlAt(curMouseX,curMouseY,c);
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
     if FindControlAt(curMouseX,curMouseY,c) then
      c.onMouseButtons(tag,false);
    end;
    // Скроллинг
    if copy(event,1,6)='SCROLL' then
     if FindControlAt(curMouseX,curMouseY,c) then
      c.onMouseScroll(tag);

   finally
    LeaveCriticalSection(UICritSect);
   end;

  end;

 procedure PrintUIlog;
  var
   st:string;
  begin
   st:=' mouse clipping: '+inttostr(ord(clipMouse))+' ('+
     inttostr(clipMouserect.left)+','+inttostr(clipMouserect.top)+':'+
     inttostr(clipMouserect.right)+','+inttostr(clipMouserect.bottom)+')'#13#10;
   st:=st+' Modal control: ';
   if modalElement<>nil then st:=st+modalElement.name else st:=st+'none';
   ForceLogMessage('UI state'#13#10+st);
  end;

 procedure KbdEventHandler(event:TEventStr;tag:TTag);
  var
   c:TUIElement;
   shift:byte;
   key,scancode:integer;
  begin
   EnterCriticalSection(UICritSect);
   try
    lastShiftState:=game.shiftState;
    shift:=game.shiftState;
    key:=GetKeyEventVirtualCode(tag); // virtual key code
    scancode:=GetKeyEventScancode(tag);
    event:=UpperCase(copy(event,5,length(event)-4));
    if event='KEYDOWN' then // Win+Ctrl+S
     if (key=ord('S')) and (shift=8+2) then PrintUILog;

    c:=FocusedElement;
    // No focused element - handle hotkey for all elements
    if (event='KEYDOWN') and (c=nil) then ProcessHotKey(key,shift);

    if c.IsEnabled then begin
     if event='KEYDOWN' then
      if c.onKey(key,true,shift) then
       ProcessHotKey(key,shift); // Hotkey processing is allowed by onKey handler

      if event='KEYUP' then
       if not FocusedElement.onKey(key,false,shift) then exit;

  {   if event='CHAR' then
      focusedControl.onChar(chr(tag and $FF),tag shr 8);

     if event='UNICHAR' then
      focusedControl.onUniChar(WideChar(tag and $FFFF),tag shr 16);}
    end;

   finally
    LeaveCriticalSection(UICritSect);
   end;
  end;

 { TUIScene }

 constructor TUIScene.Create;
  begin
   InitUI;
   inherited Create(fullscreen);
   if sceneName='' then sceneName:=ClassName;
   name:=scenename;
   UI:=TUIElement.Create(rootWidth,rootHeight,nil,sceneName);
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
   if game<>nil then game.AddScene(self);
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
    rootWidth:=game.renderWidth;
    rootHeight:=game.renderHeight;
    if UI<>nil then UI.Resize(rootWidth,rootHeight);
  end;

 function TUIScene.Process: boolean;
  var
   delta:integer;
   c:TUIElement;
   time:cardinal;
   st:string;
   procedure ProcessControl(c:TUIElement);
    var
     j:integer;
     cnt:integer;
     list:array[0..255] of TUIElement;
    begin
     if c=nil then exit;
     if c.timer>0 then
      if c.timer<=delta then begin
       c.timer:=0;
       c.onTimer;
      end else dec(c.timer,delta);

     cnt:=clamp(length(c.children),0,length(list)); // Can't process more than 255 nested elements
     if cnt>0 then begin
      for j:=0 to cnt-1 do list[j]:=c.children[j];
      for j:=0 to cnt-1 do ProcessControl(list[j]);
     end;
    end;
  begin
   result:=true;
   Signal('Scenes\ProcessScene\'+name);
   EnterCriticalSection(UICritSect);
   // отложенное удаление элементов

   // Размер корневого эл-та - полный экран
  { if (UI.ClassType=TUIControl) and (UI.x=0) and (UI.y=0) then begin
    UI.width:=areaWidth;
    UI.height:=areaHeight;
   end;}

   try
    FindControlAt(curMouseX,curMouseY,c);
    SetUnderMouse(c);

    // Обработка фокуса: если элемент с фокусом невидим или недоступен - убрать с него фокус
    // Исключение: корневой UI-элемент (при закрытии сцены фокус должен убрать эффект перехода)
    c:=FocusedElement;
    if c<>nil then begin
     repeat
      if not (c.visible and c.enabled) or
       ((modalElement<>nil) and (c.parent=nil) and (c<>modalElement)) then begin
       SetFocusTo(nil);
       LogMessage(UI.name);
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
     LastHandleTime:=MyTickCount;
     exit;
    end;
    time:=MyTickCount;
    delta:=time-LastHandleTime;
    if UI<>nil then ProcessControl(UI);

    // обработка хинтов
    if (itemShowHintTime>LastHandleTime) and (itemShowHintTime<=Time) then begin
     FindControlAt(game.mouseX,game.mouseY,c);
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
    LeaveCriticalSection(UICritSect);
   end;
  end;

  // tag: low 8 bit - new shadow value, next 16 bit - duration in ms
  procedure onSetGlobalShadow(event:TEventStr;tag:TTag);
  begin
   startShadowChange:=MyTickCount;
   shadowChangeDuration:=tag shr 8;
   oldShadowValue:=curShadowValue;
   needShadowValue:=tag and $FF;
  end;

  // tag: low 8 bit - new shadow value, next 16 bit - duration in ms
  procedure onSetFocus(event:TEventStr;tag:TTag);
  begin
   delete(event,1,length('UI\SETFOCUS\'));
   if (event<>'') and (event<>'NIL') then
    FindControl(event,true).setFocus
   else
    SetFocusTo(nil);
  end;


 procedure TUIScene.Render;
  var
   t:int64;
  begin
   t:=MyTickCount;
   if t>=lastRenderTime then
    frametime:=t-lastRenderTime
   else begin
     frameTime:=1;
     ForceLogMessage('Kosyak! '+inttostr(t)+' '+inttostr(lastRenderTime));
    end;
   lastRenderTime:=t;

   //Apus.Engine.UIRender.Frametime:=frametime;
   Signal('Scenes\'+name+'\BeforeRender');
   StartMeasure(11);
   if UI<>nil then begin
    Signal('Scenes\'+name+'\BeforeUIRender');
    EnterCriticalSection(UICritSect);
    try
     try
      DrawUI(UI);
     except
      on e:exception do raise EError.Create('UI.DrawUI '+name+' Err '+e.message);
     end;
    finally
     LeaveCriticalSection(UICritSect);
    end;
    Signal('Scenes\'+name+'\AfterUIRender');
   end;
   EndMeasure2(11);
  end;

 procedure InitUI;
  begin
   if initialized then exit;
   // асинхронная обработка: сигналы обрабатываются в том же потоке, что и вызываются,
   // независимо от того из какого потока вызывается ф-ция InitUI
   SetEventHandler('Mouse',MouseEventHandler,emInstant);
   SetEventHandler('Kbd',KbdEventHandler,emInstant);
   SetEventHandler('Engine\ActivateWnd',ActivateEventHandler,emInstant);
   SetEventHandler('UI\SetGlobalShadow',onSetGlobalShadow,emInstant);
   SetEventHandler('UI\SetFocus',onSetFocus,emInstant);

   PublishVar(@rootWidth,'rootWidth',TVarTypeInteger);
   PublishVar(@rootHeight,'rootHeight',TVarTypeInteger);

   initialized:=true;
  end;

 procedure TUIScene.SetStatus(st:TSceneStatus);
  begin
   inherited;
   ForceLogMessage('Scene '+name+' status changed to '+statuses[st]);
  // LogMessage('Scene '+name+' status changed to '+statuses[st],5);
   if (status=ssActive) and (UI=nil) then begin
    UI:=TUIElement.Create(rootWidth,rootHeight,nil);
    UI.name:=name;
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
    FocusedElement.onUniChar(WideChar(charCode),scanCode);
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

end.
