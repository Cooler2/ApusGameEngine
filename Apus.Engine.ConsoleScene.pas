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
  wnd:TUIWindow;
  severityBox:TUIComboBox;
  defWidth,defHeight:integer; // default window size, for the reset-on-show safety net
  procedure ResetWindowIfOffscreen;
 end;

var
 consoleScene:TConsoleScene;

 procedure AddConsoleScene;

implementation
 uses SysUtils, Classes, Types, Apus.Core, Apus.Strings, Apus.EventMan, Apus.Lib, Apus.Log,
  Apus.Clipboard,
  Apus.Engine.Types,
  Apus.Engine.UIWidgets, Apus.Engine.UITypes,
  Apus.Engine.CmdProc;

 const
  CON_BUFFER_SIZE=2048; // max console lines kept in memory
  CON_LINE_HEIGHT=19;   // base rendered line height (px) before UI scale
  CON_TEXT_SIZE=8.5;    // base console font size before UI scale
  CON_OVERLAY_H=22;     // filter button height (px) at top of the text area
  // Line colors: color = f(kind, level). Two families by source:
  //  - log/diagnostics: neutral->warm severity ramp (minor grey ... hot red);
  //  - command I/O: cool/vivid (clearly not a log line).
  CON_COLOR_DEBUG:cardinal =$FF7896B8; // diag Debug  - dim blue (least important)
  CON_COLOR_INFO:cardinal  =$FF9FCBFF; // diag Info   - clear blue
  CON_COLOR_NORMAL:cardinal=$FFC6E8FF; // diag Normal - readable cyan (default)
  CON_COLOR_FORCED:cardinal=$FFF2F2F2; // diag Forced - bright white (important, not a problem)
  CON_COLOR_WARN:cardinal  =$FFF2C24E; // diag Warn   - amber
  CON_COLOR_ERROR:cardinal =$FFFF6A4D; // diag Error  - red-orange
  CON_COLOR_FATAL:cardinal =$FFFF3B30; // diag Fatal  - bright red (most important)
  CON_COLOR_ECHO:cardinal  =$FF7CC4FF; // command echo (user input)  - sky blue
  CON_COLOR_CMD:cardinal   =$FF86E8B0; // command result             - mint green
  CON_COLOR_CMDERR:cardinal=$FFFFA53C; // command failed / eval error - orange

 type
  TConsoleLine=record
   text:String8;
   level:TSeverity;     // for diagnostics; command I/O uses kind for coloring
   kind:TConsoleKind;   // Diag / Command / CmdError / Echo
   stamp:TDateTime;     // capture time, for the timestamp toggle (F1)
  end;

 var
  cmdList:TStringList;
  cmdPos:integer;
  // Console line ring buffer. Written by any thread via the log mirror or command
  // sink, read by the render thread in DrawContent — guarded by conLock.
  conLock:TLock;
  conBuf:array[0..CON_BUFFER_SIZE-1] of TConsoleLine;
  conCount:integer;     // lines currently stored (<=CON_BUFFER_SIZE)
  conHead:integer;      // index where the next line will be written
  conTotal:int64;       // monotonic count of all lines ever added (auto-scroll trigger)
  conCaptureLevel:TSeverity=TSeverity.Normal; // min severity captured from the log
  lastShownTotal:int64; // last conTotal observed by DrawContent
  showTimestamps:boolean=false; // Ctrl+Alt+1: prepend per-line capture time (toggled via overlay)
  visibleSeverity:TSeverity=TSeverity.Normal; // display threshold for diagnostic lines

 // Rendered console line height in pixels at the given UI scale.
 function ConLineHeight(scale:single):integer;
  begin
   result:=round(CON_LINE_HEIGHT*scale);
  end;

 procedure StyleConsoleButton(btn:TUIButton;const hint:String8);
  begin
   btn.hint:=hint;
   btn.style.SetAttr('font-size','7.5');
   btn.style.SetAttr('fill','$D0303A46');
   btn.style.SetAttr('color','$FFE8F7FF');
   btn.style.SetAttr('hover.fill','$F0445668');
   btn.style.SetAttr('hover.color','$FFFFFFFF');
   btn.style.SetAttr('pressed.fill','$F05A6F84');
   btn.style.SetAttr('pressed.color','$FFFFFFFF');
   btn.style.SetAttr('border-light','$90FFFFFF');
   btn.style.SetAttr('border-dark','$B0000000');
  end;

 procedure SetVisibleSeverity(sev:TSeverity);
  begin
   visibleSeverity:=sev;
   conCaptureLevel:=sev;
   if (consoleScene<>nil) and (consoleScene.severityBox<>nil) then
    consoleScene.severityBox.SetCurItemByTag(ord(sev));
  end;

 procedure ChangeVisibleSeverity(delta:integer);
  var
   n:integer;
  begin
   n:=ord(visibleSeverity)+delta;
   n:=Clamp(n,ord(TSeverity.Debug),ord(TSeverity.Fatal));
   SetVisibleSeverity(TSeverity(n));
  end;

 // Short capture-time prefix for the timestamp toggle.
 function StampStr(t:TDateTime):String8;
  begin
   result:=String8(FormatDateTime('hh:nn:ss ',t));
  end;

 // Append a line to the ring buffer (thread-safe).
 procedure ConsoleAddLine(const text:String8;level:TSeverity;kind:TConsoleKind);
  begin
   conLock.Enter;
   try
    conBuf[conHead].text:=text;
    conBuf[conHead].level:=level;
    conBuf[conHead].kind:=kind;
    conBuf[conHead].stamp:=CoreTime.Now;
    conHead:=(conHead+1) mod CON_BUFFER_SIZE;
    if conCount<CON_BUFFER_SIZE then inc(conCount);
    inc(conTotal);
   finally
    conLock.Leave;
   end;
  end;

 // Flush the console ring buffer (the `clear` command). conTotal stays monotonic
 // so the next added line still triggers auto-scroll.
 procedure ConsoleClear;
  begin
   conLock.Enter;
   try
    conCount:=0;
    conHead:=0;
   finally
    conLock.Leave;
   end;
  end;

 procedure ClearCmd(cmd:string8);
  begin
   ConsoleClear;
  end;

 function SeverityName(sev:TSeverity):String8;
  begin
   case sev of
    TSeverity.Debug:result:='debug';
    TSeverity.Info:result:='info';
    TSeverity.Normal:result:='normal';
    TSeverity.Forced:result:='forced';
    TSeverity.Warn:result:='warn';
    TSeverity.Error:result:='error';
    TSeverity.Fatal:result:='fatal';
    else result:='?';
   end;
  end;

 function ParseSeverity(const s:String8;out sev:TSeverity):boolean;
  begin
   result:=true;
   if s='debug' then sev:=TSeverity.Debug
   else if s='info' then sev:=TSeverity.Info
   else if s='normal' then sev:=TSeverity.Normal
   else if s='forced' then sev:=TSeverity.Forced
   else if (s='warn') or (s='warning') then sev:=TSeverity.Warn
   else if s='error' then sev:=TSeverity.Error
   else if s='fatal' then sev:=TSeverity.Fatal
   else result:=false;
  end;

 // `loglevel [sev]` reads or sets the console severity threshold (non-retrospective:
 // hidden low-severity lines are not stored in the bounded ring).
 procedure LogLevelCmd(cmd:string8);
  var
   arg:String8;
   p:integer;
   sev:TSeverity;
  begin
   arg:=cmd;
   p:=pos(' ',arg);
   if p=0 then arg:='' else delete(arg,1,p); // drop the operator word
   arg:=arg.Trim.ToLower;
   if arg='' then begin
    CmdOutput('Console severity level: '+SeverityName(conCaptureLevel),TConsoleKind.Command);
    exit;
   end;
   if not ParseSeverity(arg,sev) then
    raise EWarning.Create('Unknown severity: '+arg+' (debug|info|normal|warn|error|fatal)');
   SetVisibleSeverity(sev);
   CmdOutput('Console severity level set to '+SeverityName(sev),TConsoleKind.Command);
  end;

 // Resolve a line color from its kind and severity.
 function ConsoleColor(const line:TConsoleLine):cardinal;
  begin
   case line.kind of
    TConsoleKind.Command:result:=CON_COLOR_CMD;
    TConsoleKind.CmdError:result:=CON_COLOR_CMDERR;
    TConsoleKind.Echo:result:=CON_COLOR_ECHO;
    else begin // Diag - severity gradient
     case line.level of
      TSeverity.Debug:result:=CON_COLOR_DEBUG;
      TSeverity.Info:result:=CON_COLOR_INFO;
      TSeverity.Forced:result:=CON_COLOR_FORCED;
      TSeverity.Warn:result:=CON_COLOR_WARN;
      TSeverity.Error:result:=CON_COLOR_ERROR;
      TSeverity.Fatal:result:=CON_COLOR_FATAL;
      else result:=CON_COLOR_NORMAL; // Normal
     end;
    end;
   end;
  end;

 // Display filter: command I/O is always visible, diagnostics use the active severity.
 function ConsoleLineVisible(const line:TConsoleLine):boolean;
  begin
   case line.kind of
    TConsoleKind.Command,
    TConsoleKind.Echo,
    TConsoleKind.CmdError:result:=true;
    else begin // Diag
     result:=line.level>=visibleSeverity;
    end;
   end;
  end;

 // Count lines currently visible under the active severity (thread-safe).
 function ConsoleVisibleCount:integer;
  var
   i,idx:integer;
  begin
   conLock.Enter;
   try
    result:=0;
    for i:=0 to conCount-1 do begin
     idx:=conHead-1-i;
     while idx<0 do inc(idx,CON_BUFFER_SIZE);
     if ConsoleLineVisible(conBuf[idx]) then inc(result);
    end;
   finally
    conLock.Leave;
   end;
  end;

 // Copy the currently visible (filtered) console lines to the clipboard as plain
 // text, oldest first. The buffer is held only to snapshot line references.
 procedure ConsoleCopyToClipboard;
  var
   i,idx,n:integer;
   lines:array of String8;
   s:String8;
  begin
   conLock.Enter;
   try
    setLength(lines,conCount);
    n:=0;
    for i:=conCount-1 downto 0 do begin // oldest -> newest
     idx:=conHead-1-i;
     while idx<0 do inc(idx,CON_BUFFER_SIZE);
     if not ConsoleLineVisible(conBuf[idx]) then continue;
     if showTimestamps then lines[n]:=StampStr(conBuf[idx].stamp)+conBuf[idx].text
      else lines[n]:=conBuf[idx].text;
     inc(n);
    end;
   finally
    conLock.Leave;
   end;
   s:='';
   for i:=0 to n-1 do s:=s+lines[i]+#13#10;
   if s<>'' then CopyStrToClipboard(UTF8String(s));
  end;

 // Log mirror: feeds engine diagnostics into the console buffer. Any thread.
 procedure ConsoleLogHandler(msg:String8;category:byte;level:TSeverity);
  begin
   if level<conCaptureLevel then exit;    // tier-1 capture threshold (non-retrospective)
   if category=CAT_CONSOLE_CMD then exit; // command I/O arrives via the command sink
   ConsoleAddLine(msg,level,TConsoleKind.Diag);
  end;

 // Command output sink (assigned to CmdProc.OnOutput).
 procedure ConsoleCmdOutput(const line:String8;kind:TConsoleKind);
  var
   level:TSeverity;
  begin
   case kind of
    TConsoleKind.CmdError:level:=TSeverity.Error;
    TConsoleKind.Echo:level:=TSeverity.Info;
    else level:=TSeverity.Normal;
   end;
   ConsoleAddLine(line,level,kind);
  end;

 procedure SeveritySelectHandler(event:TEventStr;tag:TTag);
  begin
   if (consoleScene=nil) or (consoleScene.severityBox=nil) then exit;
   SetVisibleSeverity(TSeverity(consoleScene.severityBox.curTag));
   consoleScene.ScrollToEnd;
  end;

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

 // Console view hotkeys: Ctrl+Alt+1..3, so function keys stay available to demos.
 if (consoleScene.activated) and ((window.shiftState and sscBaseMask)=(sscCtrl+sscAlt)) then begin
  case TKey(tag and $FF) of
   TKey.D1:begin
    showTimestamps:=not showTimestamps;
    game.SuppressKbdEvent;
    exit;
   end;
   TKey.D2:begin
    ChangeVisibleSeverity(-1);
    consoleScene.ScrollToEnd;
    game.SuppressKbdEvent;
    exit;
   end;
   TKey.D3:begin
    ChangeVisibleSeverity(1);
    consoleScene.ScrollToEnd;
    game.SuppressKbdEvent;
    exit;
   end;
  end;
 end;

 // Ctrl+C with an empty input line - copy the visible console lines to the clipboard
 // (a non-empty input keeps the edit box's own copy behavior).
 if (consoleScene.activated) and
    (TKey(tag and $FF)=TKey.C) and
    (window.shiftState and sscCtrl>0) and
    (consoleScene.editbox.text='') then
  ConsoleCopyToClipboard;

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
  conLock.Init('Console');
  i:=wcTitleHeight;
  wcTitleHeight:=20;
  consoleScene:=TConsoleScene.Create;
  wcTitleHeight:=i;
  SetEventHandler('KBD\KeyDown',KbdHandler);
  cmdList:=TStringList.Create;
  Logger.SetCustomHandler(@ConsoleLogHandler,false); // mirror the log into the console buffer
  OnOutput:=@ConsoleCmdOutput;                       // receive command I/O directly
  SetCmdFunc('CLEAR',opFirst,ClearCmd);              // `clear` flushes the console buffer
  SetCmdFunc('LOGLEVEL',opFirst,LogLevelCmd);        // `loglevel [sev]` tier-1 capture threshold
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
 CmdOutput(e.text,TConsoleKind.Echo); // echo input: logs it and shows it in the console
 ExecCmd(e.text);
 e.text:='';
 e.cursorpos:=0;
end;

procedure DrawContent(item:TUIImage);
var
 r:TRect;
 i,cnt,vcnt,ypos,lineHeight,ll,idx:integer;
 total:int64;
 col,font:cardinal;
begin
 r:=item.globalRect;
 gfx.clip.Rect(r);
 lineHeight:=ConLineHeight(item.globalScale);
 conLock.Enter;
 try
  cnt:=conCount;
  total:=conTotal;
  vcnt:=0; // only visible lines occupy rows / drive the scroll range
  for i:=0 to cnt-1 do begin
   idx:=conHead-1-i;
   while idx<0 do inc(idx,CON_BUFFER_SIZE);
   if ConsoleLineVisible(conBuf[idx]) then inc(vcnt);
  end;
 finally
  conLock.Leave;
 end;
 consoleScene.scroll.max:=vcnt*lineHeight+lineHeight*0.6;
 consolescene.scroll.pagesize:=r.height;
 ll:=round(lineHeight*0.75);

 if total<>lastShownTotal then begin
  if vcnt*lineHeight>r.height-ll then consoleScene.ScrollToEnd
   else item.scroll.Y:=0;
  lastShownTotal:=total;
 end;
 with item do begin
  if vcnt*lineHeight<=r.height-ll then
   scroll.Y:=0
  else begin
   if vcnt*lineHeight-scroll.Y<r.height-ll then
    scroll.Y:=vcnt*lineHeight-(r.height-ll);
   if scroll.Y<0 then scroll.Y:=0;
  end;
  consolescene.scroll.value:=scroll.Y;
 end;
 ypos:=vcnt*lineHeight-round(item.scroll.Y)+round(lineHeight*1.3);
 font:=txt.GetFont('Default',round(CON_TEXT_SIZE*item.globalScale),fsIgnoreScale); // scale glyphs with the line height (DPI-aware)
 txt.BeginBlock;
 conLock.Enter;
 try
  // Iterate newest-to-oldest; newest visible line sits at the bottom of the view.
  for i:=0 to cnt-1 do begin
   idx:=conHead-1-i;
   while idx<0 do inc(idx,CON_BUFFER_SIZE);
   if not ConsoleLineVisible(conBuf[idx]) then continue; // hidden: no row
   dec(ypos,lineHeight);
   if (ypos<-lineHeight) or (ypos>=r.height+8) then continue;   // offscreen: skip draw
   col:=ConsoleColor(conBuf[idx]);
   if showTimestamps then
    txt.Write(font,r.left+2,r.top+yPos,col,StampStr(conBuf[idx].stamp)+conBuf[idx].text,taLeft,toWithShadow)
   else
    txt.Write(font,r.left+2,r.top+yPos,col,conBuf[idx].text,taLeft,toWithShadow);
  end;
 finally
  conLock.Leave;
 end;
 txt.EndBlock;
 gfx.clip.Restore;
 draw.Line(r.left,r.bottom-1,r.right+17,r.Bottom-1,$40FFFFFF);
end;

{ TConsoleScene }
constructor TConsoleScene.Create;
var
 wndRef:TWindow;
 btn:TUIToggleButton;
 filterPanel:TUIElement;
 h:integer;
 dpi:integer;
begin
 inherited Create('CONSOLE',false); // pure foreground scene
 wndRef:=window;
 if wndRef=nil then wndRef:=mainWindow;
 if wndRef<>nil then dpi:=wndRef.surface.dpi
  else dpi:=96;
 if dpi>120 then
  ui.SetScale(dpi/96);
 //ignoreKeyboardEvents:=true;
 status:=TSceneStatus.ssFrozen;
 frequency:=12;

 h:=round(ui.clientHeight*0.7);
 defWidth:=480; defHeight:=h; // remembered for ResetWindowIfOffscreen
 wnd:=TUIWindow.Create(480,h,true,UI,'ConsoleWnd','Console');
 wnd.SetPos(10,10,pivotTopLeft);
 wnd.moveable:=true;
 wnd.minW:=120; wnd.minH:=160;
 wnd.style.SetAttr('fill','$D0202020');
 zorder:=$FF0000;

 // View controls float over the text area in the top-right corner.
 filterPanel:=TUIElement.Create(160,CON_OVERLAY_H,wnd,'ConsoleFilter');
 filterPanel.SetPos(456,4,pivotTopRight);
 filterPanel.SetAnchors(1,0,1,0);
 filterPanel.order:=1000;
 btn:=TUIToggleButton.Create(38,CON_OVERLAY_H,filterPanel,'ConsoleTimeBtn');
 btn.Setup('Time');
 StyleConsoleButton(btn,'Show timestamps for console lines (Ctrl+Alt+1)');
 btn.SetPos(0,0,pivotTopLeft);
 btn.linkedToggled:=@showTimestamps; // Ctrl+Alt+1: toggle per-line timestamps

 severityBox:=TUIComboBox.Create(116,CON_OVERLAY_H,filterPanel,'ConsoleSeverity');
 severityBox.AddItem('Debug',ord(TSeverity.Debug),'Show debug and above');
 severityBox.AddItem('Info',ord(TSeverity.Info),'Show info and above');
 severityBox.AddItem('Normal',ord(TSeverity.Normal),'Show normal and above');
 severityBox.AddItem('Warn',ord(TSeverity.Warn),'Show warnings and above');
 severityBox.AddItem('Error',ord(TSeverity.Error),'Show errors and fatal only');
 severityBox.AddItem('Fatal',ord(TSeverity.Fatal),'Show fatal only');
 severityBox.SetCurItemByTag(ord(visibleSeverity));
 StyleConsoleButton(severityBox,'Minimum severity shown (Ctrl+Alt+2/Ctrl+Alt+3)');
 severityBox.SetPos(42,0,pivotTopLeft);
 severityBox.maxlines:=6;

 img:=TUIImage.Create(462,h-18,wnd,'ConsoleMain');
 img.SetPos(0,0,pivotTopLeft);
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
 SetEventHandler('UI\ConsoleSeverity\ONSELECT',SeveritySelectHandler);
end;

function TConsoleScene.Process:boolean;
begin
 ignoreKeyboardEvents:=(FocusedElement<>editBox);
 result:=inherited;
end;

procedure TConsoleScene.ScrollToEnd;
var
 lineHeight,cnt:integer;
begin
 lineHeight:=ConLineHeight(img.globalScale);
 cnt:=ConsoleVisibleCount; // end position depends on visible lines
 img.scroll.Y:=cnt*lineHeight-round(img.size.y-12);
 if img.scroll.Y<0 then img.scroll.Y:=0;
end;

// Safety net: TUIWindow move/resize can leave the window off-screen or at an unusable size
// (a widget-level bug). On show, restore the default geometry if the current one is bad.
procedure TConsoleScene.ResetWindowIfOffscreen;
var
 cw,ch:single;
begin
 if wnd=nil then exit;
 cw:=ui.clientWidth;
 ch:=ui.clientHeight;
 if (wnd.position.x<0) or (wnd.position.y<0) or
    (wnd.position.x>cw-40) or (wnd.position.y>ch-40) or
    (wnd.size.x<wnd.minW) or (wnd.size.y<wnd.minH) or
    (wnd.size.x>cw) or (wnd.size.y>ch) then begin
  wnd.Resize(defWidth,defHeight);
  wnd.SetPos(10,10,pivotTopLeft);
 end;
end;

procedure TConsoleScene.SetStatus(status: TSceneStatus);
begin
 inherited;
 if status=TSceneStatus.ssActive then ResetWindowIfOffscreen; // before ScrollToEnd (uses window size)
 ScrollToEnd;
 if status=TSceneStatus.ssActive then SetFocusTo(editbox); // focus only when activating
end;

end.



