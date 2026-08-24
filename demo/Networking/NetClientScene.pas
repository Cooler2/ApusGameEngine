// Client scene for the Networking demo: connects to the loopback server via
// Apus.Engine.HttpGameClient and shows a single combined chat/protocol feed,
// Connect/Disconnect buttons and an input line.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit NetClientScene;
interface
uses Types,Apus.Types,Apus.Core,Apus.Strings,Apus.EventMan,
  Apus.Engine.API,Apus.Engine.Scene,Apus.Engine.Keys,
  NetCommon;

type
  TClientScene=class(TNetSceneBase)
    myLogin:String8;
    myUserID:integer;
    input:String32;               // edit buffer as UCS-4 codepoints (1 element = 1 char)
    started:boolean;
    btnConnect,btnDisconnect:TRect;
    constructor Create(wnd:TWindow);
    destructor Destroy; override;
    function Process:boolean; override;
    procedure Render; override;
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    procedure StartClient;        // runs on the main thread (first Process call)
    procedure DoConnect;
    procedure DoDisconnect;
    procedure SendInput;
  end;

var
  clientScene:TClientScene;

implementation
uses SysUtils,Apus.Engine.Types,Apus.Engine.HttpGameClient;

// Client signals arrive queued on the main thread (SetEventHandler emQueued in
// StartClient, called from Process — NOT from Load, which runs off the render
// thread), so it is safe to mutate scene state from here.
procedure NetHandler(event:TEventStr;tag:TTag);
var
  sub:TEventStr;
  reader:TStringsReader;
  kind,who,text:String8;
begin
  if clientScene=nil then exit;
  if not EventOfClass(event,'NET\Conn3',sub) then exit;

  if sub='CONNECTED' then begin
    clientScene.connState:='connected (authorizing...)';
    clientScene.AddFeed(COL_LOG_CLI,'connected, got temporary id');
    exit;
  end;
  if sub='LOGGED' then begin
    clientScene.myUserID:=integer(tag);
    clientScene.connState:='logged in as '+clientScene.myLogin+' (uid '+IntToStr(integer(tag))+')';
    clientScene.AddFeed(COL_LOG_CLI,'authorized -> uid '+IntToStr(integer(tag))+'; polling (comet)');
    clientScene.AddFeed(COL_CHAT_SYS,'Connected. Type a message and press Enter.');
    exit;
  end;
  if sub='ACCESSDENIED' then begin
    clientScene.connState:='access denied: '+HGCErrorMessage;
    clientScene.AddFeed(COL_WARN,'access denied: '+HGCErrorMessage);
    exit;
  end;
  if (sub='CONNECTIONFAILED') or (sub='CONNECTIONREJECTED') then begin
    clientScene.connState:='connection failed (is the server running?)';
    clientScene.AddFeed(COL_WARN,'connection failed');
    exit;
  end;
  if (sub='CONNECTIONBROKEN') or (sub='CONNECTIONCLOSED') then begin
    clientScene.connState:='disconnected';
    clientScene.AddFeed(COL_LOG_CLI,'connection closed');
    exit;
  end;
  if sub='DATARECEIVED' then begin
    GetNetMessage(integer(tag),reader);
    kind:=reader.NextStr;
    if kind='msg' then begin
      who:=reader.NextStr;
      text:=reader.NextStr;
      clientScene.AddFeed(COL_LOG_CLI,'comet <- "'+text+'" from '+who);
      if who.Same(clientScene.myLogin) then
        clientScene.AddFeed(COL_CHAT_OWN,who+': '+text)       // our own line, echoed by the server
      else
        clientScene.AddFeed(COL_CHAT_PEER,who+': '+text);
    end else
    if kind='sys' then begin
      text:=reader.NextStr;
      clientScene.AddFeed(COL_CHAT_SYS,text);
    end;
    exit;
  end;
end;

{ TClientScene }

constructor TClientScene.Create(wnd:TWindow);
begin
  inherited Create('Net',wnd);
  myUserID:=0;
  connState:='starting client...';
  clientScene:=self;
end;

destructor TClientScene.Destroy;
begin
  Disconnect;
  RemoveEventHandler(NetHandler);
  clientScene:=nil;
  inherited;
end;

procedure TClientScene.StartClient;
begin
  myLogin:=LOGIN+IntToStr(GetClientSlot);   // distinct login per client process
  SetEventHandler('NET\Conn3\',NetHandler,emQueued);
  DoConnect;
end;

procedure TClientScene.DoConnect;
begin
  if Connected then exit;
  AddFeed(COL_LOG_CLI,'connecting to 127.0.0.1:'+IntToStr(SERVER_PORT)+' as '+myLogin);
  Connect('127.0.0.1:'+IntToStr(SERVER_PORT),myLogin,PASSWORD,CLIENT_INFO);
  connState:='connecting...';
end;

procedure TClientScene.DoDisconnect;
begin
  if not Connected then exit;
  Disconnect;
  connState:='disconnected';
  AddFeed(COL_LOG_CLI,'disconnected by user');
end;

procedure TClientScene.SendInput;
var text:String8;
begin
  if System.Length(input)=0 then exit;
  text:=UTF8.Encode(input);       // codepoints -> UTF-8 only at the boundary
  if Connected then begin
    AddFeed(COL_LOG_CLI,'POST -> "'+text+'"');
    SendData(['msg',text]);        // server echoes it back, so we DON'T add it locally
  end else
    AddFeed(COL_CHAT_SYS,'(not connected) '+text);
  SetLength(input,0);
end;

function TClientScene.Process:boolean;
var key:cardinal; uCode:integer; clickLMB:boolean;
begin
  if not started then begin StartClient; started:=true; end;
  if not placed then begin PlaceWindow(GetClientSlot); placed:=true; end;

  clickLMB:=Bits.HasAll(window.mouseButtons,mbLeft) and
            not Bits.HasAll(window.oldMouseButtons,mbLeft);
  if clickLMB then begin
    if Hit(btnConnect) and not Connected then DoConnect
    else if Hit(btnDisconnect) and Connected then DoDisconnect;
  end;

  // collect typed printable characters (text-input channel)
  repeat
    key:=ReadKey;
    if key=0 then break;
    uCode:=Bits.GetWord(key,1);   // AAAA = unicode codepoint
    if (uCode>=32) and (System.Length(input)<MAX_INPUT) then begin
      SetLength(input,System.Length(input)+1);
      input[high(input)]:=uCode;
    end;
  until false;

  result:=true;
end;

procedure TClientScene.Render;
var w,h,by,bh,panelTop,inputTop:integer; inner:TRect; caret,vis:String8;
begin
  w:=window.canvasWidth; h:=window.canvasHeight;
  gfx.target.Clear(COL_BG);
  DrawHeader('Apus Networking Demo  Client',
    'Type a line + Enter: it round-trips client -> server -> broadcast -> all clients.');
  DrawStatus('client '+myLogin+': '+connState, connState.Contains('logged'));

  // connect/disconnect row
  by:=S(94); bh:=S(36);
  btnConnect:=Rect(S(12),by,S(12)+S(150),by+bh);
  btnDisconnect:=Rect(btnConnect.Right+S(10),by,btnConnect.Right+S(10)+S(150),by+bh);
  DrawButton(btnConnect,'Connect',not Connected);
  DrawButton(btnDisconnect,'Disconnect',Connected);

  // combined chat + protocol feed
  panelTop:=by+bh+S(10);
  inputTop:=h-S(12)-S(40);
  inner:=DrawPanel(Rect(S(12),panelTop,w-S(12),inputTop-S(10)),'Chat / network log');
  DrawFeed(inner);

  // input line
  draw.FillRRect(S(12),inputTop,w-S(12),h-S(12),COL_INPUT,S(8));
  draw.RRect(S(12),inputTop,w-S(12),h-S(12),1,S(8),COL_INPUTBRD);
  if (CoreTime.Ticks div 500) and 1=0 then caret:='_' else caret:=' ';
  vis:=FitTail(uiFont,'> ',UTF8.Encode(input),caret,(w-S(24))-S(24));
  txt.Write(uiFont,S(24),inputTop+(S(40)-txt.Height(uiFont)) div 2,COL_WHITE,'> '+vis+caret,taLeft,toAddBaseline);
  inherited;
end;

function TClientScene.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
begin
  result:=true;
  case key of
    TKey.Enter:     SendInput;
    TKey.Backspace: if System.Length(input)>0 then SetLength(input,System.Length(input)-1);
    TKey.Escape:    SetLength(input,0);
  else
    result:=false;
  end;
end;

end.
