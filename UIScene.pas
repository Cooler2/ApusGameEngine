// Common useful UI-related classes and routines
//
// Copyright (C) 2003-2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit UIScene;
interface
 uses {$IFDEF MSWINDOWS}windows,{$ENDIF}EngineAPI,UIClasses,CrossPlatform,types;

const
 defaultHintStyle:integer=0; // style of hints, can be changed
 modalShadowColor:cardinal=0; // color of global "under modal" shadow

type
 // Very useful simple scene that contains an UI layer
 // Almost all game scenes can be instances from this type, however sometimes
 // it is reasonable to use different scene(s)
 TUIScene=class(TGameScene)
  UI:TUIControl; // root UI element: size = render area size
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

var
 curHint:TUIHint=nil;

 // No need to call manually as it is called when any UIScene object is created
 procedure InitUI;

 // Установка размера (виртуального) экрана для UI (зачем!?)
 procedure SetDisplaySize(width,height:integer);

 // Полезные функции общего применения
 // -------
 // Создать всплывающее окно, прицепить его к указанному предку
 procedure ShowSimpleHint(msg:string;parent:TUIControl;x,y,time:integer;font:cardinal=0);

 procedure DumpUIdata;

implementation
 uses SysUtils,MyServis,EventMan,UIRender,EngineTools,CmdProc,console,UDict,publics,geom2d;

const
 statuses:array[TSceneStatus] of string=('frozen','background','active');

var
 curCursor:integer;
 initialized:boolean=false;
 rootWidth,rootHeight,oldRootWidth,oldAreaHeight:integer; // размер области отрисовки

 LastHandleTime:int64;

 // параметры хинтов
 hintRect:tRect; // область, к которой относится хинт
 // переменные для работы с хинтами элементов
 hintMode:cardinal; // время (в тиках), до которого длится режим показа хинтов
                   // в этом режиме хинты выпадают гораздо быстрее
 itemShowHintTime:cardinal; // момент времени, когда элемент должен показать хинт
 lastHint:string; // текст хинта, соответствующего элементу, над которым была мышь в предыдущем кадре

 designMode:boolean; // режим "дизайна", в котором можно таскать элементы по экрану правой кнопкой мыши
 hookedItem:TUIControl;

 curShadowValue,oldShadowValue,needShadowValue:integer; // 0..255
 startShadowChange,shadowChangeDuration:int64;

 lastShiftState:byte;

procedure SetDisplaySize(width,height:integer);
 begin
  LogMessage('UIScene.SDS');
  oldRootWidth:=rootWidth;
  oldAreaHeight:=rootHeight;
  rootWidth:=width;
  rootHeight:=height;
  UIClasses.SetDisplaySize(width,height);
 end;


procedure ActivateEventHandler(event:EventStr;tag:TTag);
begin
 EnterCriticalSection(UICritSect);
 try
  if tag=0 then
   SetFocusTo(nil);
 finally
  LeaveCriticalSection(UICritSect);
 end;
end;

procedure MouseEventHandler(event:EventStr;tag:TTag);
var
 c,c2:TUIControl;
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
   if e2 then underMouse:=c2
    else undermouse:=nil;
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
   if e and (c<>nil) then begin
    if tag and 1>0 then c.onMouseButtons(1,true);
    if tag and 2>0 then c.onMouseButtons(2,true);
    if tag and 4>0 then c.onMouseButtons(3,true);
   end;
   if (c<>nil) and (not c.enabled) and (c.handleMouseIfDisabled) then begin
    if tag and 1>0 then c.onMouseButtons(1,true);
    if tag and 2>0 then c.onMouseButtons(2,true);
    if tag and 4>0 then c.onMouseButtons(3,true);
   end;

   // Таскание элементов правой кнопкой с Ctrl
   if (tag and 2>0) and
      (designmode or (lastShiftState and 2>0)) then hookedItem:=c;
   // Показать название и св-ва элемента
   if (tag=4) and (lastShiftState and 2>0) then
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
  // Отпускание кнопки
  if copy(event,1,5)='BTNUP' then begin
   if (hookedItem<>nil) and (tag and 2>0) then begin
    PutMsg('x='+inttostr(round(hookeditem.position.x))+' y='+inttostr(round(hookeditem.position.y)));
    hookedItem:=nil;
   end;
   if FindControlAt(curMouseX,curMouseY,c) then begin
    if tag and 1>0 then c.onMouseButtons(1,false);
    if tag and 2>0 then c.onMouseButtons(2,false);
    if tag and 4>0 then c.onMouseButtons(3,false);
   end;
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
 if modalcontrol<>nil then st:=st+modalcontrol.name else st:=st+'none';
 ForceLogMessage('UI state'#13#10+st);
end;

procedure KbdEventHandler(event:EventStr;tag:TTag);
var
 c:TUIControl;
 shift:byte;
 key:integer;
begin
 EnterCriticalSection(UICritSect);
 try
  shift:=(tag shr 16) and 255;
  lastShiftState:=shift;
  key:=tag and $FF;
  event:=UpperCase(copy(event,5,length(event)-4));
  if event='KEYDOWN' then // Win+Ctrl+S
   if (key=ord('S')) and (shift=8+2) then PrintUILog;

  c:=FocusedControl;
  if (event='KEYDOWN') and (c=nil) then begin
   {$IFDEF MSWINDOWS} /// TODO
   ProcessHotKey(MapVirtualKey(key,1),shift);
   {$ENDIF}
  end;
  if c<>nil then begin
   while c<>nil do begin
    if not c.enabled then exit;
    c:=c.parent;
   end;

   {$IFDEF MSWINDOWS} /// TODO!
   if event='KEYDOWN' then
    if focusedControl.onKey(key,true,shift) then
     ProcessHotKey(MapVirtualKey(key,1),shift);
   {$ENDIF}

   if event='KEYUP' then
    if not focusedControl.onKey(key,false,shift) then exit;

   if event='CHAR' then
    focusedControl.onChar(chr(tag and $FF),tag shr 8);

   if event='UNICHAR' then
    focusedControl.onUniChar(WideChar(tag and $FFFF),tag shr 16);
  end;

 finally
  LeaveCriticalSection(UICritSect);
 end;
end;

{ TUIScene }

procedure TUIScene.BackgroundRenderBegin;
begin
 if transpBgnd then painter.SetMode(blMove);
end;

procedure TUIScene.BackgroundRenderEnd;
begin
 if transpBgnd then painter.SetMode(blAlpha);
end;

constructor TUIScene.Create;
begin
 InitUI;
 inherited Create(fullscreen);
 if sceneName='' then sceneName:=ClassName;
 name:=scenename;
 UI:=TUIControl.Create(rootWidth,rootHeight,nil,sceneName);
 UI.enabled:=false;
 UI.visible:=false;
 if not fullscreen then ui.transpMode:=tmTransparent
  else ui.transpmode:=tmOpaque;

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
 if UI.transpmode<>tmTransparent then
  result:=Rect(0,0,round(UI.size.x),round(UI.size.y));
 for i:=0 to high(UI.children) do
  with UI.children[i] do
   if transpmode<>tmTransparent then begin
    r:=GetPosOnScreen;
    if IsRectEmpty(result) then
     result:=r
    else
     UnionRect(result,result,r); // именно в таком порядке, иначе - косяк!
   end;
 OffsetRect(result,round(UI.position.x),round(UI.position.y)); // actually, UI root shouldn't be displaced, but...
end;

procedure TUIScene.onMouseBtn(btn: byte; pressed: boolean);
begin
 if (UI<>nil) and (not UI.enabled) then exit;
 inherited;
end;

procedure TUIScene.onMouseMove(x, y: integer);
begin
 if (UI<>nil) and (not UI.enabled) then exit;
 inherited;
end;

procedure TUIScene.onMouseWheel(delta: integer);
begin
 if (UI<>nil) and (not UI.enabled) then exit;
 inherited;
 if (modalcontrol=nil) or (modalcontrol=UI) then begin
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
 i,delta:integer;
 c:TUIControl;
 time:cardinal;
 st:string;

 procedure ProcessControl(c:TUIControl);
  var
   j:integer;
   cnt:integer;
   list:array[0..255] of TUIControl;
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
 toDelete.Clear;

 // Размер корневого эл-та - полный экран
{ if (UI.ClassType=TUIControl) and (UI.x=0) and (UI.y=0) then begin
  UI.width:=areaWidth;
  UI.height:=areaHeight;
 end;}

 try
  FindControlAt(curMouseX,curMouseY,underMouse);

  // Обработка фокуса: если элемент с фокусом невидим или недоступен - убрать с него фокус
  // Исключение: корневой UI-элемент (при закрытии сцены фокус должен убрать эффект перехода)
  c:=focusedControl;
  if c<>nil then begin
   repeat
    if not (c.visible and c.enabled) or
     ((modalcontrol<>nil) and (c.parent=nil) and (c<>modalcontrol)) then begin
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
    ((modalcontrol<>nil) and (hooked.GetRoot<>modalControl)) then begin
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
procedure onSetGlobalShadow(event:eventstr;tag:TTag);
begin
 startShadowChange:=MyTickCount;
 shadowChangeDuration:=tag shr 8;
 oldShadowValue:=curShadowValue;
 needShadowValue:=tag and $FF;
end;

// tag: low 8 bit - new shadow value, next 16 bit - duration in ms
procedure onSetFocus(event:eventstr;tag:TTag);
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

 UIRender.Frametime:=frametime;
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

procedure TUIScene.SetStatus(st: TSceneStatus);
begin
 inherited;
 ForceLogMessage('Scene '+name+' status changed to '+statuses[st]);
// LogMessage('Scene '+name+' status changed to '+statuses[st],5);
 if (status=ssActive) and (UI=nil) then begin
  UI:=TUIControl.Create(rootWidth,rootHeight,nil);
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

procedure TUIScene.WriteKey(key: cardinal);
begin
 if (UI<>nil) and (not UI.enabled) then exit;
 inherited;
end;

procedure ShowSimpleHint;
var
 hint:TUIHint;
 i:integer;
begin
 LogMessage('ShowHint: '+msg);
 msg:=translate(msg);
 if (x=-1) or (y=-1) then begin
  x:=curMouseX; y:=curMouseY;
  hintRect:=rect(x-8,y-8,x+8,y+8);
 end else begin
  hintRect:=rect(0,0,4000,4000);
 end;
 if parent=nil then begin
  findControlAt(x,y,parent);
  if parent=nil then begin
   for i:=0 to high(rootControls) do
    if RootControls[i].visible then begin
     parent:=rootControls[i]; break;
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

procedure DumpUIdata;
var
 i:integer;
 f:text;
 procedure DumpControl(c:TUIControl;indent:string);
  var
   i:integer;
  begin
   writeln(f,indent,c.ClassName+':'+c.name+' = '+inttohex(cardinal(c),8));
   writeln(f,indent,c.order,' En=',c.enabled,' Vis=',c.visible,' trM=',ord(c.transpmode));
   writeln(f,indent,Format('x=%.1f, y=%.1f, w=%.1f, h=%.1f, left=%d, top=%d',
     [c.position.x,c.position.y,c.size.x,c.size.y,c.globalRect.Left,c.globalRect.Top]));
   writeln(f);
   for i:=0 to length(c.children)-1 do
    DumpControl(c.children[i],indent+'+ ');
  end;
 function SceneInfo(s:TGameScene):string;
  begin
   if s=nil then exit;
   result:=Format('  %-20s Z=%-10d  status=%-2d type=%-2d eff=%s',
     [s.name,s.zorder,ord(s.status),byte(s.fullscreen),PtrToStr(s.effect)]);
   if s is TUIScene then
    result:=result+Format(' UI=%s (%s)',[TUIScene(s).UI.name, PtrToStr(TUIScene(s).UI)]);
  end;
begin
 try
 assign(f,'UIdata.log');
 rewrite(f);
 writeln(f,'Scenes:');
 for i:=0 to high(game.scenes) do writeln(f,i:3,SceneInfo(game.scenes[i]));
 writeln(f,'Topmost scene = ',game.TopmostVisibleScene(false).name);
 writeln(f,'Topmost fullscreen scene = ',game.TopmostVisibleScene(true).name);
 writeln(f);
 writeln(f,'Modal: '+inttohex(cardinal(modalcontrol),8));
 writeln(f,'Focused: '+inttohex(cardinal(focusedControl),8));
 writeln(f,'Hooked: '+inttohex(cardinal(hooked),8));
 writeln(f);
 for i:=0 to high(rootControls) do
  DumpControl(rootControls[i],'');
 close(f);
 except
  on e:exception do ForceLogMessage('Error in DumpUI: '+ExceptionMsg(e));
 end;
end;

end.
