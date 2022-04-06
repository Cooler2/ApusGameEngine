// Standard scene for console window and command interpreter
//
// Copyright (C) 2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.ConsoleScene;
interface
 uses Apus.Engine.API, Apus.Engine.UIClasses, Apus.Engine.UIScene;
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
 uses SysUtils, Classes,
  Apus.CrossPlatform, Apus.MyServis, Apus.EventMan,
  Apus.Engine.CmdProc, Apus.Engine.Console;

 var
  LastMsgNum:cardinal;
  cmdList:TStringList;
  cmdPos:integer;

procedure KbdHandler(event:TEventStr;tag:TTag);
var
 c:TUIElement;
begin
 // Win+[~] - показать/скрыть консоль
 if (tag and 255=$C0) and (game.shiftState and sscWin>0) then begin
  if consoleScene.activated then begin
   if consoleScene.UI.hasFocus then
    consoleScene.SetStatus(ssFrozen)
   else
    consoleScene.UI.SetFocus;
   end else begin
    consoleScene.SetStatus(ssActive);
    game.SuppressKbdEvent; // avoid [`] in the edit box
   end;
 end;

 // Если консоль открыта, а фокуса нигде нет, то по любому нажатию перевести фокус на консоль
 if (consoleScene.Activated) and
    (focusedControl=nil) then
    SetFocusTo(consoleScene.editbox);

 // TAB - переместить консоль зеркально
{ if (consoleScene.activated) and
    (tag and $FF=VK_TAB) then begin
  c:=FindControl('ConsoleWnd');
  c.x:=screenWidth-c.x-c.width;
 end;}

 // Выбор из предыдущих команд
 if (consoleScene.activated) and
    (game.shiftState=0) and
    (focusedControl=consoleScene.editbox) then
  with consoleScene do begin
   // [UP] / {DOWN] - select previous commands
   if (tag and $FF=VK_UP) or (tag and $FF=VK_DOWN) then begin
    if tag and $FF=VK_UP then
     if cmdPos>0 then dec(cmdPos);
    if tag and $FF=VK_DOWN then
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
    (tag and $FF in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN]) then begin
  c:=curObj;
  // SHIFT+CTRL+arrows - move
  if game.shiftState and sscCtrl>0 then begin
   if tag and $FF=VK_LEFT then c.position.x:=c.position.x-1;
   if tag and $FF=VK_UP then c.position.y:=c.position.y-1;
   if tag and $FF=VK_RIGHT then c.position.x:=c.position.x+1;
   if tag and $FF=VK_DOWN then c.position.y:=c.position.y+1;
  end;
  // SHIFT+ALT+arrows - resize
  if game.shiftState and sscAlt>0 then begin
   if tag and $FF=VK_LEFT then c.size.x:=c.size.x-1;
   if tag and $FF=VK_UP then c.size.y:=c.size.y-1;
   if tag and $FF=VK_RIGHT then c.size.x:=c.size.x+1;
   if tag and $FF=VK_DOWN then c.size.y:=c.size.y+1;
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
 if cmdList.Find(e.text,i) then begin
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
 i,n,cnt,ypos,cls:integer;
 st:string;
 col,font:cardinal;
begin
 r:=item.globalRect;
 gfx.clip.Rect(r);
 // Write all text
 cnt:=GetMsgCount;
 consoleScene.scroll.max:=cnt*16+10;
 consolescene.scroll.pagesize:=r.height;
 with item do begin
  if cnt*16-scroll.Y<r.height-12 then
   scroll.Y:=cnt*16-(r.height-12);
  if (cnt*16-scroll.Y>r.height-12) and (scroll.Y<0) then
   scroll.Y:=scroll.Y+cnt*16-scroll.Y-r.height+12;
  consolescene.scroll.value:=scroll.Y;
 end;

 n:=GetLastMsgNum;
 if n<>LastMsgNum then begin
  consoleScene.ScrollToEnd;
  LastMsgNum:=n;
 end;
 ypos:=cnt*16-round(item.scroll.Y)+20;
 font:=txt.GetFont('Default',7);
 txt.BeginBlock;
 for i:=1 to cnt do begin
  dec(n); dec(ypos,16);
  if (ypos<-15) or (ypos>=r.height+8) then continue;
  st:=GetSavedMsg(n+1,cls);
  case cls of
   -1:col:=$FFFF6060;
   55000:col:=$FF80FF80;
   41001:col:=$FFFFD040;
   41000:col:=$FFA0FFF0;
   else col:=$FFD0D0D0;
  end;
  txt.Write(font,r.left+2,r.top+yPos,col,DecodeUTF8(st));
 end;
 txt.EndBlock;
 gfx.clip.Restore;
 draw.Line(r.left,r.bottom-1,r.right+17,r.Bottom-1,$40FFFFFF);
end;

{ TConsoleScene }
constructor TConsoleScene.Create;
var
 wnd:TUIWindow;
 font:cardinal;
 h:integer;
begin
 inherited Create('CONSOLE',false); // pure foreground scene
 //ignoreKeyboardEvents:=true;
 status:=ssFrozen;
 frequency:=12;

 font:=txt.GetFont('Default',7);
 h:=round(game.renderHeight*0.7);
 wnd:=TUIWindow.Create(480,h,true,'ConsoleWnd','Console',font,UI);
 wnd.SetPos(10,10,pivotTopLeft);
 wnd.moveable:=true;
 wnd.minW:=120; wnd.minH:=160;
 wnd.color:=$80202020;
 zorder:=$FF0000;

 img:=TUIImage.Create(462,h-18,'ConsoleMain',wnd);
 img.SetAnchors(0,0,1,1);
 img.src:='proc:'+PtrToStr(@DrawContent);

 editbox:=TUIEditBox.Create(460,18,'Console\Input',font,$FFE0FFD0,wnd);
 editBox.SetPos(0,h,pivotBottomLeft);
 editbox.backgnd:=$40000000;
 editBox.SetAnchors(0,1,1,1);
 editbox.noborder:=true;
 editbox.encoding:=teUTF8;

 TUIButton.Create(20,18,'Console\Enter','>',font,wnd).SetPos(480,h,pivotBottomRight).SetAnchors(1,1,1,1);
 Link('UI\Console\Enter\Click','UI\Console\Input\Enter');

 scroll:=TUIScrollBar.Create(18,h-19,'Console\Scroll',wnd);
 scroll.SetPos(480,0,pivotTopRight);
 scroll.color:=$90808090;
 scroll.step:=32;
 scroll.SetAnchors(1,0,1,1);
 scroll.Link(img);
 img.scrollerV:=scroll;

 SetEventHandler('UI\Console\Input\Enter',ConsoleOnEnter);
end;

function TConsoleScene.Process:boolean;
begin
 ignoreKeyboardEvents:=(FocusedControl<>editBox);
 result:=inherited;
end;

procedure TConsoleScene.ScrollToEnd;
begin
 img.scroll.Y:=GetMsgCount*16-round(consoleScene.img.size.y-12);
end;

procedure TConsoleScene.SetStatus(status: TSceneStatus);
begin
 inherited;
 ScrollToEnd;
 SetFocusTo(editbox);
end;

end.
