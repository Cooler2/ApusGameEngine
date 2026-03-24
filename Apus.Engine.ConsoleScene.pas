// Standard scene for console window and command interpreter
//
// Copyright (C) 2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.ConsoleScene;
interface
 uses Apus.Engine.API, Apus.Engine.UI, Apus.Engine.UIScene;
type
 TConsoleScene=class(TUIScene)
  constructor Create;
  procedure ScrollToEnd;
  procedure SetStatus(status:TSceneStatus); override;
  function Process:boolean; override;
 private
  editbox:TUIEditBox;
  scroll:TUIScrollBar;
  img:TUIImage;
 end;

var
 consoleScene:TConsoleScene;

 procedure AddConsoleScene;

implementation
 uses Classes, Types, Apus.EventMan, Apus.Lib,
  Apus.Engine.UIWidgets, Apus.Engine.UITypes,
  Apus.Engine.CmdProc, Apus.Engine.Console;

 var
  LastMsgNum:cardinal;
  cmdList:TStringList;
  cmdPos:integer;

procedure KbdHandler(event:TEventStr;tag:TTag);
var
 c:TUIElement;
begin
 // Win+[~] - show/hide console window
 if (TKey(tag and 255)=TKey.Tilde) and (window.shiftState and sscWin>0) then begin
  if consoleScene.activated then begin
   if consoleScene.UI.hasFocus then
    consoleScene.SetStatus(TSceneStatus.ssFrozen)
   else
    consoleScene.UI.SetFocus;
   end else begin
    consoleScene.SetStatus(TSceneStatus.ssActive);
    game.SuppressKbdEvent; // avoid [`] in the edit box
   end;
 end;

 // When console is active and nothing is focused, focus the edit box.
 if (consoleScene.Activated) and
    (focusedElement=nil) then
    SetFocusTo(consoleScene.editbox);

 // TAB - mirror console window (debug helper, currently disabled)
{ if (consoleScene.activated) and
    (TKey.From(byte(tag and $FF))=TKey.Tab) then begin
  c:=FindControl('ConsoleWnd');
  c.x:=screenWidth-c.x-c.width;
 end;}

 // Select from command history
 if (consoleScene.activated) and
    (window.shiftState and sscBaseMask=0) and
    (focusedElement=consoleScene.editbox) then
  with consoleScene do begin
   // [UP] / {DOWN] - select previous commands
    if (TKey(tag and $FF)=TKey.Up) or (TKey(tag and $FF)=TKey.Down) then begin
     if TKey(tag and $FF)=TKey.Up then
      if cmdPos>0 then dec(cmdPos);
     if TKey(tag and $FF)=TKey.Down then
      if cmdPos<cmdList.Count-1 then inc(cmdPos);
    if cmdPos<cmdList.Count then begin
     editBox.text:=cmdList[cmdPos];
     editBox.SelectAll;
    end;
   end;
  end;

 // Move/resize current element with arrow keys
 if consoleScene.activated and
    (curObj<>nil) and
    (curObjClass.ClassNameIs('TVarTypeUIControl')) and
    (TKey(tag and $FF) in [TKey.Left,TKey.Right,TKey.Up,TKey.Down]) then begin
  c:=curObj;
  // SHIFT+CTRL+arrows - move
   if window.shiftState and sscCtrl>0 then begin
    if TKey(tag and $FF)=TKey.Left then c.position.x:=c.position.x-1;
    if TKey(tag and $FF)=TKey.Up then c.position.y:=c.position.y-1;
    if TKey(tag and $FF)=TKey.Right then c.position.x:=c.position.x+1;
    if TKey(tag and $FF)=TKey.Down then c.position.y:=c.position.y+1;
   end;
  // SHIFT+ALT+arrows - resize
   if window.shiftState and sscAlt>0 then begin
    if TKey(tag and $FF)=TKey.Left then c.size.x:=c.size.x-1;
    if TKey(tag and $FF)=TKey.Up then c.size.y:=c.size.y-1;
    if TKey(tag and $FF)=TKey.Right then c.size.x:=c.size.x+1;
    if TKey(tag and $FF)=TKey.Down then c.size.y:=c.size.y+1;
   end;
 end;
end;

procedure AddConsoleScene;
 var
  i:integer;
 begin
  SetupConsole(true,false,false,true,true,'game.log');
  i:=wcTitleHeight;
  wcTitleHeight:=20;
  consoleScene:=TConsoleScene.Create;
  wcTitleHeight:=i;
  SetEventHandler('KBD\KeyDown',KbdHandler);
  cmdList:=TStringList.Create;
 end;

procedure ConsoleOnEnter(event:TEventStr;tag:TTag);
var
 e:TUIEditBox;
 i:integer;
begin
 e:=FindControl('Console\Input',false) as TUIEditBox;
 if e=nil then exit;
 i:=cmdList.IndexOf(e.text);
 if i>=0 then begin
  cmdList.Delete(i);
  if cmdPos>=i then dec(cmdPos);
 end;
 cmdList.Add(e.text);
 cmdPos:=cmdList.Count;
 PutMsg(e.text,false,55000);
 ExecCmd(e.text);
 e.text:='';
 e.cursorpos:=0;
end;

procedure DrawContent(item:TUIImage);
var
 r:TRect;
 i,n,cnt,ypos,msgClass,lineHeight,ll:integer;
 st:UTF8String;
 col,font:cardinal;
begin
 r:=item.globalRect;
 gfx.clip.Rect(r);
 lineHeight:=round(16*item.globalScale);
 // Write all text
 cnt:=GetMsgCount;
 consoleScene.scroll.max:=cnt*lineHeight+lineHeight*0.6;
 consolescene.scroll.pagesize:=r.height;
 ll:=round(lineHeight*0.75);
 with item do begin
  if cnt*lineHeight-scroll.Y<r.height-ll then
   scroll.Y:=cnt*lineHeight-(r.height-ll);
  if (cnt*lineHeight-scroll.Y>r.height-ll) and (scroll.Y<0) then
   scroll.Y:=scroll.Y+cnt*lineHeight-scroll.Y-r.height+ll;
  consolescene.scroll.value:=scroll.Y;
 end;

 n:=GetLastMsgNum;
 if n<>LastMsgNum then begin
  consoleScene.ScrollToEnd;
  LastMsgNum:=n;
 end;
 ypos:=cnt*lineHeight-round(item.scroll.Y)+round(lineHeight*1.3);
 font:=txt.GetFont('Default',7);
 txt.BeginBlock;
 for i:=1 to cnt do begin
  dec(n); dec(ypos,lineHeight);
  if (ypos<-lineHeight) or (ypos>=r.height+8) then continue;
  st:=GetSavedMsg(n+1,msgClass);
  case msgClass of
   -1:col:=$FFFF6060;
   55000:col:=$FF80FF80;
   41001:col:=$FFFFD040;
   41000:col:=$FFA0FFF0;
   else col:=$FFD0D0D0;
  end;
  txt.Write(font,r.left+2,r.top+yPos,col,st);
 end;
 txt.EndBlock;
 gfx.clip.Restore;
 draw.Line(r.left,r.bottom-1,r.right+17,r.Bottom-1,$40FFFFFF);
end;

{ TConsoleScene }
constructor TConsoleScene.Create;
var
 wndRef:TWindow;
 wnd:TUIWindow;
 font:cardinal;
 h:integer;
 dpi:integer;
begin
 inherited Create('CONSOLE',false); // pure foreground scene
 wndRef:=window;
 if wndRef=nil then wndRef:=mainWindow;
 if wndRef<>nil then dpi:=wndRef.screenDPI
  else dpi:=96;
 if dpi>120 then
  ui.SetScale(dpi/96);
 //ignoreKeyboardEvents:=true;
 status:=TSceneStatus.ssFrozen;
 frequency:=12;

 font:=txt.GetFont('Default',7*ui.scale,fsIgnoreScale);
 h:=round(ui.clientHeight*0.7);
 wnd:=TUIWindow.Create(480,h,true,UI,'ConsoleWnd','Console');
 wnd.SetPos(10,10,pivotTopLeft);
 wnd.moveable:=true;
 wnd.minW:=120; wnd.minH:=160;
 wnd.style.SetAttr('color','$80202020');
 zorder:=$FF0000;

 img:=TUIImage.Create(462,h-18,wnd,'ConsoleMain');
 img.SetAnchors(0,0,1,1);
 img.src:='proc:'+Conv.ToStr(@DrawContent);

 editbox:=TUIEditBox.Create(460,18,wnd,'Console\Input');
 editbox.style.SetAttr('color','$FFE0FFD0');
 editBox.SetPos(0,h,pivotBottomLeft);
 editBox.SetAnchors(0,1,1,1);

 TUIButton.Create(20,18,wnd,'Console\Enter').Setup('>').SetPos(480,h,pivotBottomRight).SetAnchors(1,1,1,1);
 Link('UI\Console\Enter\OnClick','UI\Console\Input\Enter');

 scroll:=TUIScrollBar.CreateV(18,h-19,wnd,'Console\Scroll');
 scroll.SetPos(480,0,pivotTopRight);
 scroll.style.SetAttr('color','$90808090');
 scroll.step:=32;
 scroll.SetAnchors(1,0,1,1);
 scroll.Link(img);
 img.scrollerV:=scroll.GetScroller;

 SetEventHandler('UI\Console\Input\Enter',ConsoleOnEnter);
end;

function TConsoleScene.Process:boolean;
begin
 ignoreKeyboardEvents:=(FocusedElement<>editBox);
 result:=inherited;
end;

procedure TConsoleScene.ScrollToEnd;
var
 lineHeight:integer;
begin
 lineHeight:=round(16*img.globalScale);
 img.scroll.Y:=GetMsgCount*lineHeight-round(img.size.y-12);
end;

procedure TConsoleScene.SetStatus(status: TSceneStatus);
begin
 inherited;
 ScrollToEnd;
 SetFocusTo(editbox);
end;

end.



