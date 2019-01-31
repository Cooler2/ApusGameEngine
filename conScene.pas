// Standard scene for console window and command interpreter
//
// Copyright (C) 2004 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
unit conScene;
interface
 uses EngineCls,UIClasses,CommonUI;
type
 TConsoleScene=class(TUIScene)
  constructor Create;
  procedure ScrollToEnd;
  procedure SetStatus(status:TSceneStatus); override;
 private
  editbox:TUIEditBox;
  scroll:TUIScrollBar;
  img:TUIImage;
 end;

var
 consoleScene:TConsoleScene;

 procedure AddConsoleScene;

implementation
 uses SysUtils,CrossPlatform,myservis,classes,EventMan,ImageMan,cmdproc,engineTools,console;

 var
  LastMsgNum:cardinal;
  cmdList:TStringList;
  cmdPos:integer;

function KbdHandler(event:EventStr;tag:integer):boolean;
var
 c:TUIControl;
begin
 result:=false;
 // Win+[~] - показать/скрыть консоль
 if (tag and 255=$C0) and (tag and $80000>0) then begin
  result:=true;
  if consoleScene.activated then begin
   if consoleScene.UI.hasFocus then
    consoleScene.SetStatus(ssFrozen)
   else
    consoleScene.UI.SetFocus;
   end else consoleScene.SetStatus(ssActive);
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

 // Позиционирование текущего элемента
 if consoleScene.activated and
    (curObj<>nil) and
    (curObjClass.ClassNameIs('TVarTypeUIControl')) and
    (tag and $FF in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN]) then begin
  c:=curObj;
  if game.shiftState and sscCtrl>0 then begin
   if tag and $FF=VK_LEFT then dec(c.x);
   if tag and $FF=VK_UP then dec(c.y);
   if tag and $FF=VK_RIGHT then inc(c.x);
   if tag and $FF=VK_DOWN then inc(c.y);
  end;
  if game.shiftState and sscAlt>0 then begin
   if tag and $FF=VK_LEFT then dec(c.width);
   if tag and $FF=VK_UP then dec(c.height);
   if tag and $FF=VK_RIGHT then inc(c.width);
   if tag and $FF=VK_DOWN then inc(c.height);
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
  game.AddScene(consoleScene);
  wcTitleHeight:=i;
  SetEventHandler('KBD\KeyDown',KbdHandler);
  cmdList:=TStringList.Create;
 end;

function ConsoleOnEnter(event:EventStr;tag:integer):boolean;
var
 e:TUIEditBox;
 i:integer;
begin
 result:=true;
 e:=FindControl('console\input',false) as TUIEditBox;
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

procedure ConsoleImageLoader(reason:TReason;var image:TImgDescriptor);
begin
end;

procedure ConsoleImageDrawer(image:TImgDescriptor;x,y:integer;color:cardinal;p1,p2,p3,p4:single);
var
 w,h,i,n,cnt,ypos,cls:integer;
 st:string;
 col,font:cardinal;
begin
 w:=trunc(p1); h:=trunc(p2);
 painter.SetClipping(Rect(x,y,x+w-1,y+h-3));
 // Write all text
 cnt:=GetMsgCount;
 consoleScene.scroll.max:=cnt*16+10;
 consolescene.scroll.pagesize:=h;
 with ConsoleScene.img do begin
  if cnt*16-scrollY<height-12 then
   scrollY:=cnt*16-(height-12);
  if (cnt*16-scrollY>height-12) and (scrollY<0) then
   inc(ScrollY,cnt*16-scrollY-height+12);
  consolescene.scroll.value:=scrollY;
 end;

 n:=GetLastMsgNum;
 if n<>LastMsgNum then begin
  consoleScene.ScrollToEnd;
  LastMsgNum:=n;
 end;
 ypos:=cnt*16-consoleScene.img.scrollY+20;
 font:=painter.GetFont('Default',7);
 painter.BeginTextBlock;
 for i:=1 to cnt do begin
  dec(n); dec(ypos,16);
  if (ypos<-15) or (ypos>=h+8) then continue;
  st:=GetSavedMsg(n+1,cls);
  case cls of
   -1:col:=$FFFF6060;
   55000:col:=$FF80FF80;
   41001:col:=$FFFFD040;
   41000:col:=$FFA0FFF0;
   else col:=$FFD0D0D0;
  end;
  painter.TextOut(font,x+2,y+yPos,col,DecodeUTF8(st));
{  if i and 16=0 then begin
   painter.EndTextBlock;
   painter.BeginTextBlock;
  end;}
 end;
 painter.EndTextBlock;
 painter.ResetClipping;
 painter.DrawLine(x,y+h-1,x+w+17,y+h-1,$40FFFFFF);
end;

{ TConsoleScene }
constructor TConsoleScene.Create;
var
 wnd:TUIWindow;
 font:cardinal;
 h:integer;
begin
 inherited Create('CONSOLE',false); // pure foreground scene
 ignoreKeyboardEvents:=true;
 status:=ssFrozen;
 frequency:=12;

 font:=painter.GetFont('Default',7);
 h:=round(game.renderHeight*0.7);
 wnd:=TUIWindow.Create(10,10,480,h,true,'ConsoleWnd','Console',font,UI);
 wnd.moveable:=true;
 wnd.minW:=120; wnd.minH:=160;
 wnd.color:=$80202020;
 zorder:=$FF0000;

 img:=TUIImage.Create(0,0,462,h-18,'ConsoleMain',wnd);
 img.AnchorRight:=true;
 img.AnchorBottom:=true;
 SetDrawer('Images\ConsoleMain',ConsoleImageLoader,ConsoleImageDrawer);

 editbox:=TUIEditBox.Create(0,h-18,480,18,'console\input',font,$FFE0FFD0,wnd);
 editbox.backgnd:=$40000000;
 editbox.AnchorTop:=false;
 editbox.AnchorRight:=true;
 editbox.AnchorBottom:=true;
 editbox.noborder:=true;
 editbox.encoding:=teUTF8;

 scroll:=TUIScrollBar.Create(462,0,18,h-19,'console\scroll',0,0,0,wnd);
 scroll.color:=$90808090;
 scroll.step:=32;
 scroll.AnchorLeft:=false;
 scroll.AnchorRight:=true;
 scroll.AnchorBottom:=true;
 scroll.Link(img);
 img.scrollerV:=scroll;

 SetEventHandler('UI\console\input\Enter',ConsoleOnEnter);
end;

procedure TConsoleScene.ScrollToEnd;
begin
 img.scrollY:=GetMsgCount*16-(consoleScene.img.height-12);
end;

procedure TConsoleScene.SetStatus(status: TSceneStatus);
begin
 inherited;
 ScrollToEnd;
 SetFocusTo(editbox);
end;

end.
