// Shared building blocks for the Networking demo: protocol constants, colours,
// a scrolling "feed" model and DPI-aware drawing helpers. The server and client
// scenes both derive from TNetSceneBase.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit NetCommon;
interface
uses Types,Apus.Core,Apus.Types,Apus.Engine.API,Apus.Engine.Scene;

const
  SERVER_PORT = 18790;
  LOGIN       = 'player';        // base login; the slot number is appended per client
  PASSWORD    = 'demo';
  CLIENT_INFO = 'NetworkingDemo';
  MAX_FEED    = 256;             // feed ring-buffer size
  MAX_INPUT   = 200;            // max characters in the input line
  WIN_W       = 470;            // base (logical) window footprint — tall & narrow
  WIN_H       = 840;

  // colours
  COL_BG       = $FF11151D;
  COL_HEADER   = $FF1B2740;
  COL_STATUS   = $FF15202F;
  COL_PANEL    = $FF1A2230;
  COL_PANELHDR = $FF253449;
  COL_BORDER   = $FF34465F;
  COL_INPUT    = $FF202C40;
  COL_INPUTBRD = $FF3E5273;
  COL_BTN      = $FF2C5C84;
  COL_BTN_HOV  = $FF3D78A8;
  COL_BTN_DIS  = $FF243140;
  COL_WHITE    = $FFEFF4FC;
  COL_DIM      = $FF8FA6C4;
  COL_OK       = $FF9BE08C;
  COL_WARN     = $FFFFC080;
  COL_CHAT_SYS = $FF8FA6C4;
  COL_CHAT_OWN = $FFFFE7A0;
  COL_CHAT_PEER= $FF9CD2FF;
  COL_LOG_CLI  = $FF7FE0FF;      // client-side protocol events (cyan)
  COL_LOG_SRV  = $FFFFD27A;      // server-side protocol events (amber)

type
  TFeedLine=record
    color:cardinal;
    text:String8;
  end;

  // Base scene shared by server and client: fonts, DPI scaling, a feed ring
  // buffer and panel/button/text helpers. Sizes passed to the helpers are
  // LOGICAL units; S() scales them to device pixels by DPI (game.screenScale).
  TNetSceneBase=class(TGameScene)
    titleFont,smallFont,uiFont:TFontHandle;
    sc:single;                    // DPI scale factor
    feed:array[0..MAX_FEED-1] of TFeedLine;
    feedHead,feedCount:integer;
    connState:String8;
    placed:boolean;               // window already positioned?
    constructor Create(const sceneName:string;wnd:TWindow);
    procedure Load; override;
    function GetArea:TRect; override;
    function S(v:integer):integer;
    procedure AddFeed(color:cardinal;const text:String8);
    function Hit(const r:TRect):boolean;
    function FitWidth(font:TFontHandle;const s:String8;maxW:integer):String8;
    function FitTail(font:TFontHandle;const prefix,s,suffix:String8;maxW:integer):String8;
    procedure DrawHeader(const title,subtitle:String8);
    procedure DrawStatus(const text:String8;ok:boolean);
    function DrawPanel(const r:TRect;const title:String8):TRect; // returns inner content rect
    procedure DrawButton(const r:TRect;const caption:String8;enabled:boolean);
    procedure DrawFeed(const r:TRect);
    procedure PlaceWindow(slot:integer); // size+position the window for its slot
  end;

// ShortMD5(x)=copy(MD5(x),1,10) — the hash the client uses to derive PWDHASH/signatures.
function ShortMD5(const st:String8):String8;
// Launch another instance of this exe with the given argument (non-blocking).
procedure LaunchSelf(const arg:String8);
// True if the command line contains the given switch (case-insensitive, '-name').
function HasSwitch(const name:String8):boolean;
// Slot index from '-client N' (default 1 if missing/non-numeric).
function GetClientSlot:integer;

implementation
uses SysUtils,
  {$IFDEF MSWINDOWS}Windows,ShellApi,{$ELSE}Process,{$ENDIF}
  Apus.Strings,Apus.Engine.Types,DCPmd5a;
// NB: Rect/Point/PtInRect are qualified as Types.* below because the Windows unit
// (in implementation scope) defines its own conflicting Rect/Point.

function ShortMD5(const st:String8):String8;
begin
  result:=copy(DCPmd5a.MD5(st),1,10);
end;

procedure LaunchSelf(const arg:String8);
{$IFNDEF MSWINDOWS}
var p:TProcess; token:String8;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0,'open',PChar(ParamStr(0)),PChar(string(arg)),nil,SW_SHOWNORMAL);
{$ELSE}
  p:=TProcess.Create(nil);
  try
    p.Executable:=ParamStr(0);
    for token in arg.Split(' ') do
      if token<>'' then p.Parameters.Add(string(token));
    p.Execute;                    // returns immediately (no poWaitOnExit)
  finally
    p.Free;
  end;
{$ENDIF}
end;

function HasSwitch(const name:String8):boolean;
var i:integer;
begin
  result:=false;
  for i:=1 to ParamCount do
    if String8(ParamStr(i)).Same('-'+name) then exit(true);
end;

function GetClientSlot:integer;
var i:integer;
begin
  result:=1;
  for i:=1 to ParamCount do
    if String8(ParamStr(i)).Same('-client') then begin
      if i<ParamCount then result:=StrToIntDef(ParamStr(i+1),1);
      break;
    end;
  if result<1 then result:=1;
end;

{ TNetSceneBase }

constructor TNetSceneBase.Create(const sceneName:string;wnd:TWindow);
begin
  inherited Create(sceneName,true,wnd);
  sc:=1.0;
end;

procedure TNetSceneBase.Load;
begin
  sc:=game.screenScale;
  if sc<1 then sc:=1.0;
  titleFont:=txt.GetFont('Default',round(18*sc));
  smallFont:=txt.GetFont('Default',round(11*sc));
  uiFont:=txt.GetFont('Default',round(13*sc));
  loaded:=true;
end;

function TNetSceneBase.GetArea:TRect;
begin
  result:=Types.Rect(0,0,window.renderWidth,window.renderHeight);
end;

function TNetSceneBase.S(v:integer):integer;
begin
  result:=round(v*sc);
end;

procedure TNetSceneBase.AddFeed(color:cardinal;const text:String8);
begin
  feed[feedHead].color:=color;
  feed[feedHead].text:=text;
  feedHead:=(feedHead+1) mod MAX_FEED;
  if feedCount<MAX_FEED then inc(feedCount);
end;

function TNetSceneBase.Hit(const r:TRect):boolean;
begin
  result:=Types.PtInRect(r,Types.Point(window.mousePos.x,window.mousePos.y));
end;

// Truncate the END of a string to fit maxW pixels (keeps the start, adds an ellipsis).
function TNetSceneBase.FitWidth(font:TFontHandle;const s:String8;maxW:integer):String8;
begin
  if txt.Width(font,s)<=maxW then exit(s);
  result:=s;
  while (result<>'') and (txt.Width(font,result+'...')>maxW) do
    delete(result,length(result),1);
  result:=result+'...';
end;

// Keep the TAIL of the input that fits maxW pixels (so the caret stays visible).
function TNetSceneBase.FitTail(font:TFontHandle;const prefix,s,suffix:String8;maxW:integer):String8;
begin
  result:=s;
  while (result<>'') and (txt.Width(font,prefix+result+suffix)>maxW) do
    delete(result,1,1);
end;

procedure TNetSceneBase.DrawHeader(const title,subtitle:String8);
var w:integer;
begin
  w:=window.renderWidth;
  draw.FillRect(0,0,w,S(58),COL_HEADER);
  txt.Write(titleFont,S(16),S(12),COL_WHITE,title,taLeft,toAddBaseline);
  txt.Write(smallFont,S(16),S(40),COL_DIM,FitWidth(smallFont,subtitle,w-S(32)),taLeft,toAddBaseline);
end;

procedure TNetSceneBase.DrawStatus(const text:String8;ok:boolean);
var w:integer; col:cardinal;
begin
  w:=window.renderWidth;
  draw.FillRect(0,S(58),w,S(84),COL_STATUS);
  if ok then col:=COL_OK else col:=COL_WARN;
  txt.Write(smallFont,S(16),S(66),col,FitWidth(smallFont,text,w-S(32)),taLeft,toAddBaseline);
end;

// Draw a titled panel; returns the inner content rectangle (below the header bar, padded).
function TNetSceneBase.DrawPanel(const r:TRect;const title:String8):TRect;
var hdr:integer;
begin
  hdr:=S(26);
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,COL_PANEL,S(8));
  draw.FillRect(r.Left+1,r.Top+1,r.Right-1,r.Top+hdr,COL_PANELHDR);
  draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,S(8),COL_BORDER);
  txt.Write(smallFont,r.Left+S(12),r.Top+S(8),COL_WHITE,title,taLeft,toAddBaseline);
  result:=Types.Rect(r.Left+S(12),r.Top+hdr+S(8),r.Right-S(12),r.Bottom-S(10));
end;

procedure TNetSceneBase.DrawButton(const r:TRect;const caption:String8;enabled:boolean);
var col:cardinal;
begin
  if not enabled then col:=COL_BTN_DIS
  else if Hit(r) then col:=COL_BTN_HOV
  else col:=COL_BTN;
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,col,S(8));
  draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,S(8),COL_INPUTBRD);
  txt.Write(uiFont,r.Left+(r.Right-r.Left-txt.Width(uiFont,caption)) div 2,
    r.Top+(r.Bottom-r.Top-txt.Height(uiFont)) div 2,COL_WHITE,caption,taLeft,toAddBaseline);
end;

// Draw the feed inside rect r (oldest at top, newest at bottom). Each line keeps its colour.
procedure TNetSceneBase.DrawFeed(const r:TRect);
var rowH,y,i,idx:integer;
begin
  rowH:=txt.Height(uiFont)+S(6);
  y:=r.Bottom-rowH;
  for i:=0 to feedCount-1 do begin
    if y<r.Top then break;
    idx:=(feedHead-1-i+MAX_FEED) mod MAX_FEED;
    txt.Write(uiFont,r.Left,y,feed[idx].color,FitWidth(uiFont,feed[idx].text,r.Right-r.Left),taLeft,toAddBaseline);
    dec(y,rowH);
  end;
end;

// Position+size the window so server (slot 0) and clients (slot 1..) tile across
// the screen without overlapping. The screen is split into as many equal columns
// as windows fit (capped at 4); slots beyond that cascade anywhere.
procedure TNetSceneBase.PlaceWindow(slot:integer);
var ww,wh,sw,sh,parts,partW,x,y:integer;
begin
  ww:=S(WIN_W); wh:=S(WIN_H);
  sw:=game.screenWidth; sh:=game.screenHeight;
  if (sw<=0) or (sh<=0) then begin sw:=1920; sh:=1080; end;
  parts:=sw div ww;
  if parts<1 then parts:=1;
  if parts>4 then parts:=4;
  if slot<parts then begin
    partW:=sw div parts;
    x:=slot*partW+(partW-ww) div 2;
    y:=(sh-wh) div 2;
  end else begin                  // not enough columns — cascade
    x:=S(40)+slot*S(36);
    y:=S(40)+slot*S(36);
  end;
  if x<0 then x:=0;
  if y<0 then y:=0;
  window.MoveTo(x,y,ww,wh);
  window.ProcessMessages;         // WM_SIZE -> SizeChanged -> SetupRenderArea
  window.GetSize(window.windowWidth,window.windowHeight);
end;

end.
