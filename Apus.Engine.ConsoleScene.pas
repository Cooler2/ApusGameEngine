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
  defWidth,defHeight:integer; // default window size, for the reset-on-show safety net
  procedure ResetWindowIfOffscreen;
 end;

var
 consoleScene:TConsoleScene;

 procedure AddConsoleScene;

implementation
 uses SysUtils, Classes, Types, Apus.Core, Apus.Strings, Apus.EventMan, Apus.Lib, Apus.Log,
  Apus.Clipboard,
  Apus.Engine.UIWidgets, Apus.Engine.UITypes,
  Apus.Engine.CmdProc;

 const
  CON_BUFFER_SIZE=2048; // max console lines kept in memory
  CON_LINE_HEIGHT=16;   // base rendered line height (px) before UI scale
  CON_TOOLBAR_H=18;     // view-control toolbar row height (px) at top of client area
  // Line colors: color = f(kind, level). Two families by source:
  //  - log/diagnostics: neutral->warm severity ramp (minor grey ... hot red);
  //  - command I/O: cool/vivid (clearly not a log line).
  CON_COLOR_DEBUG:cardinal =$FF6E7A8A; // diag Debug  - dim slate (least important)
  CON_COLOR_INFO:cardinal  =$FF98A4B0; // diag Info   - muted grey-blue
  CON_COLOR_NORMAL:cardinal=$FFCFD6DC; // diag Normal - neutral light grey (default)
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
  conCaptureLevel:TSeverity=TSeverity.Info; // tier-1: min severity captured from the log
  lastShownTotal:int64; // last conTotal observed by DrawContent
  showTimestamps:boolean=false; // F1: prepend per-line capture time (toggled via toolbar)
  filterGroup:TUIGroupBox;      // F2: display-filter radio group (0=All,1=Err,2=Warn,3=Cmd)

 // Rendered console line height in pixels at the given UI scale.
 function ConLineHeight(scale:single):integer;
  begin
   result:=round(CON_LINE_HEIGHT*scale);
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

 // F5: `loglevel [sev]` reads or sets the tier-1 capture threshold (non-retrospective:
 // controls which new log lines enter the bounded ring; does not re-filter old ones).
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
    CmdOutput('Console capture level: '+SeverityName(conCaptureLevel),TConsoleKind.Command);
    exit;
   end;
   if not ParseSeverity(arg,sev) then
    raise EWarning.Create('Unknown severity: '+arg+' (debug|info|normal|warn|error|fatal)');
   conCaptureLevel:=sev;
   CmdOutput('Console capture level set to '+SeverityName(sev),TConsoleKind.Command);
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

 // Tier-2 display filter: is this line visible under the given filter index?
 // 0=All, 1=Errors, 2=Warnings+, 3=Commands.
 function ConsoleLineVisible(const line:TConsoleLine;filter:integer):boolean;
  begin
   case filter of
    1:result:=((line.kind=TConsoleKind.Diag) and (line.level>=TSeverity.Error)) or
              (line.kind=TConsoleKind.CmdError);
    2:result:=((line.kind=TConsoleKind.Diag) and (line.level>=TSeverity.Warn)) or
              (line.kind=TConsoleKind.CmdError);
    3:result:=line.kind in [TConsoleKind.Command,TConsoleKind.CmdError,TConsoleKind.Echo];
    else result:=true; // All
   end;
  end;

 // Active display-filter index from the toolbar radio group (0=All if none/unset).
 function CurrentFilter:integer;
  begin
   result:=0;
   if filterGroup<>nil then begin
    result:=TUIToggleButton.GetSwitchIndex(filterGroup);
    if result<0 then result:=0;
   end;
  end;

 // Count lines currently visible under the given filter (thread-safe).
 function ConsoleVisibleCount(filter:integer):integer;
  var
   i,idx:integer;
  begin
   conLock.Enter;
   try
    if filter=0 then begin result:=conCount; exit; end;
    result:=0;
    for i:=0 to conCount-1 do begin
     idx:=conHead-1-i;
     while idx<0 do inc(idx,CON_BUFFER_SIZE);
     if ConsoleLineVisible(conBuf[idx],filter) then inc(result);
    end;
   finally
    conLock.Leave;
   end;
  end;

 // Copy the currently visible (filtered) console lines to the clipboard as plain
 // text, oldest first. The buffer is held only to snapshot line references.
 procedure ConsoleCopyToClipboard;
  var
   i,idx,filter,n:integer;
   lines:array of String8;
   s:String8;
  begin
   filter:=CurrentFilter;
   conLock.Enter;
   try
    setLength(lines,conCount);
    n:=0;
    for i:=conCount-1 downto 0 do begin // oldest -> newest
     idx:=conHead-1-i;
     while idx<0 do inc(idx,CON_BUFFER_SIZE);
     if not ConsoleLineVisible(conBuf[idx],filter) then continue;
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
 i,cnt,vcnt,ypos,lineHeight,ll,idx,filter:integer;
 total:int64;
 col,font:cardinal;
begin
 r:=item.globalRect;
 gfx.clip.Rect(r);
 lineHeight:=ConLineHeight(item.globalScale);
 filter:=CurrentFilter;
 conLock.Enter;
 try
  cnt:=conCount;
  total:=conTotal;
  if filter=0 then vcnt:=cnt
  else begin
   vcnt:=0; // only visible lines occupy rows / drive the scroll range
   for i:=0 to cnt-1 do begin
    idx:=conHead-1-i;
    while idx<0 do inc(idx,CON_BUFFER_SIZE);
    if ConsoleLineVisible(conBuf[idx],filter) then inc(vcnt);
   end;
  end;
 finally
  conLock.Leave;
 end;
 consoleScene.scroll.max:=vcnt*lineHeight+lineHeight*0.6;
 consolescene.scroll.pagesize:=r.height;
 ll:=round(lineHeight*0.75);
 with item do begin
  if vcnt*lineHeight-scroll.Y<r.height-ll then
   scroll.Y:=vcnt*lineHeight-(r.height-ll);
  if (vcnt*lineHeight-scroll.Y>r.height-ll) and (scroll.Y<0) then
   scroll.Y:=scroll.Y+vcnt*lineHeight-scroll.Y-r.height+ll;
  consolescene.scroll.value:=scroll.Y;
 end;

 // Auto-scroll to the newest line. TODO (post-merge R-16): make this sticky-bottom and fix the
 // scroll unit mismatch (ScrollToEnd uses logical img.size.y, DrawContent uses screen r.height)
 // so wheel/scrollbar work and the view holds position while new lines arrive.
 if total<>lastShownTotal then begin
  consoleScene.ScrollToEnd;
  lastShownTotal:=total;
 end;
 ypos:=vcnt*lineHeight-round(item.scroll.Y)+round(lineHeight*1.3);
 font:=txt.GetFont('Default',round(7*item.globalScale),fsIgnoreScale); // scale glyphs with the line height (DPI-aware)
 txt.BeginBlock;
 conLock.Enter;
 try
  // Iterate newest-to-oldest; newest visible line sits at the bottom of the view.
  for i:=0 to cnt-1 do begin
   idx:=conHead-1-i;
   while idx<0 do inc(idx,CON_BUFFER_SIZE);
   if not ConsoleLineVisible(conBuf[idx],filter) then continue; // hidden: no row
   dec(ypos,lineHeight);
   if (ypos<-lineHeight) or (ypos>=r.height+8) then continue;   // offscreen: skip draw
   col:=ConsoleColor(conBuf[idx]);
   if showTimestamps then
    txt.Write(font,r.left+2,r.top+yPos,col,StampStr(conBuf[idx].stamp)+conBuf[idx].text)
   else
    txt.Write(font,r.left+2,r.top+yPos,col,conBuf[idx].text);
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
 defWidth:=480; defHeight:=h; // remembered for ResetWindowIfOffscreen
 wnd:=TUIWindow.Create(480,h,true,UI,'ConsoleWnd','Console');
 wnd.SetPos(10,10,pivotTopLeft);
 wnd.moveable:=true;
 wnd.minW:=120; wnd.minH:=160;
 wnd.style.SetAttr('color','$80202020');
 wnd.style.SetAttr('col','$80202020');
 zorder:=$FF0000;

 // View-control toolbar across the top of the client area.
 with TUIToggleButton.Create(44,CON_TOOLBAR_H-2,wnd,'Console\TimeBtn') do begin
  Setup('Time');
  SetPos(2,1,pivotTopLeft);
  linkedToggled:=@showTimestamps; // F1: toggle per-line timestamps
 end;

 // F2: display-filter radio group (TUIGroupBox parent → exactly one active).
 filterGroup:=TUIGroupBox.Create(168,CON_TOOLBAR_H-2,wnd,'Console\Filter');
 filterGroup.SetPos(52,1,pivotTopLeft);
 TUIToggleButton.Create(36,CON_TOOLBAR_H-2,filterGroup,'Console\FltAll').Setup('All',true).SetPos(0,0,pivotTopLeft);
 TUIToggleButton.Create(36,CON_TOOLBAR_H-2,filterGroup,'Console\FltErr').Setup('Err').SetPos(40,0,pivotTopLeft);
 TUIToggleButton.Create(40,CON_TOOLBAR_H-2,filterGroup,'Console\FltWarn').Setup('Warn').SetPos(80,0,pivotTopLeft);
 TUIToggleButton.Create(40,CON_TOOLBAR_H-2,filterGroup,'Console\FltCmd').Setup('Cmd').SetPos(124,0,pivotTopLeft);

 img:=TUIImage.Create(462,h-18-CON_TOOLBAR_H,wnd,'ConsoleMain');
 img.SetPos(0,CON_TOOLBAR_H,pivotTopLeft);
 img.SetAnchors(0,0,1,1);
 img.src:='proc:'+Conv.ToStr(@DrawContent);

 editbox:=TUIEditBox.Create(460,18,wnd,'Console\Input');
 editbox.style.SetAttr('color','$FFE0FFD0');
 editBox.SetPos(0,h,pivotBottomLeft);
 editBox.SetAnchors(0,1,1,1);

 TUIButton.Create(20,18,wnd,'Console\Enter').Setup('>').SetPos(480,h,pivotBottomRight).SetAnchors(1,1,1,1);
 Link('UI\Console\Enter\OnClick','UI\Console\Input\Enter');

 scroll:=TUIScrollBar.CreateV(18,h-19-CON_TOOLBAR_H,wnd,'Console\Scroll');
 scroll.SetPos(480,CON_TOOLBAR_H,pivotTopRight);
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
 lineHeight,cnt:integer;
begin
 lineHeight:=ConLineHeight(img.globalScale);
 cnt:=ConsoleVisibleCount(CurrentFilter); // end position depends on visible lines
 img.scroll.Y:=cnt*lineHeight-round(img.size.y-12);
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



