// Networking demo for Apus Engine: a chat client and an in-process game server.
//
// Demonstrates the full R-27 networking stack end to end:
//   Apus.Engine.HttpGameClient  <-- HTTP -->  Apus.Engine.HttpGameServer
//          (worker thread)                          (Poll-driven)
// The server runs in the SAME process on a loopback port, so a single window
// shows BOTH sides of a real authenticated session. The right panel is the
// human-readable chat; the left panel is a live protocol log so you can watch
// the actual network events (login, POST send, comet poll, broadcast).
//
// Type a line and press Enter: it travels client -> server, the server
// broadcasts it back to every connected user, and it reappears in the chat —
// proving the round trip visually.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit NetworkingApp;
interface
uses Apus.Engine.GameApp,Apus.Engine.API;

type
  TMainApp=class(TGameApplication)
    constructor Create;
    procedure SetupGameSettings(var settings:TGameSettings); override;
    procedure CreateScenes; override;
  end;

var
  application:TMainApp;

implementation
uses
  SysUtils,
  Types,
  Apus.Core,
  Apus.Types,
  Apus.Conv,
  Apus.Strings,
  Apus.EventMan,
  DCPmd5a,
  Apus.HttpServer,
  Apus.Engine.HttpGameServer,
  Apus.Engine.HttpGameClient,
  Apus.Engine.Keys,
  Apus.Engine.Types,
  Apus.Engine.Scene;

const
  SERVER_PORT  = 18790;
  LOGIN        = 'player';
  PASSWORD     = 'demo';
  CLIENT_INFO  = 'NetworkingDemo';
  MAX_CHAT     = 256;       // chat history ring-buffer size
  MAX_LOG      = 256;       // protocol log ring-buffer size
  MAX_INPUT    = 200;       // max characters in the input line

  // colours
  COL_BG       = $FF11151D;
  COL_HEADER   = $FF1B2740;
  COL_STATUS   = $FF15202F;
  COL_PANEL    = $FF1A2230;
  COL_PANELHDR = $FF253449;
  COL_BORDER   = $FF34465F;
  COL_INPUT    = $FF202C40;
  COL_INPUTBRD = $FF3E5273;
  COL_WHITE    = $FFEFF4FC;
  COL_DIM      = $FF8FA6C4;
  COL_OK       = $FF9BE08C;
  COL_WARN     = $FFFFC080;
  COL_CHAT_SYS = $FF8FA6C4;
  COL_CHAT_OWN = $FFFFE7A0;
  COL_CHAT_PEER= $FF9CD2FF;
  COL_LOG_CLI  = $FF7FE0FF;  // client-side events (cyan)
  COL_LOG_SRV  = $FFFFD27A;  // server-side events (amber)
  COL_LOG_INFO = $FF99A6B8;  // neutral info

type
  TChatKind=(ckSystem,ckPeer,ckOwn);
  TChatLine=record
    kind:TChatKind;
    text:String8;
  end;

  TLogSide=(lsClient,lsServer,lsInfo);
  TLogLine=record
    side:TLogSide;
    text:String8;
  end;

  // In-memory account store: a single pre-seeded account. A real game plugs its DB here.
  TDemoAccounts=class(TInterfacedObject,IAccountProvider)
    function FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
    function CreateAccount(const name,login,pwdHash,extras:String8):String8;
    function CheckName(const name:String8):boolean;
  end;

  TChatScene=class(TGameScene)
    titleFont,smallFont,chatFont,logFont:TFontHandle;
    server:TGameServer;
    accounts:IAccountProvider;
    // server-side userID -> login map (populated by the login callback)
    srvUsers:array of record id:integer; name:String8; end;

    chat:array[0..MAX_CHAT-1] of TChatLine;
    chatHead,chatCount:integer;
    log:array[0..MAX_LOG-1] of TLogLine;
    logHead,logCount:integer;

    input:String32;           // edit buffer as UCS-4 codepoints (1 element = 1 char)
    connState:String8;        // human-readable client state for the status bar
    myUserID:integer;

    constructor Create(const name:string;wnd:TWindow);
    destructor Destroy; override;
    procedure Load; override;
    function Process:boolean; override;
    procedure Render; override;
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    function GetArea:TRect; override;

    procedure AddChat(kind:TChatKind;const text:String8);
    procedure AddLog(side:TLogSide;const text:String8);
    procedure SendInput;
    function DrawPanel(const r:TRect;const title:String8):TRect; // returns inner content rect
    // server-side callbacks (run on the main thread during server.Poll — safe to touch state)
    procedure SrvUserLogin(userID:integer; const login:String8);
    procedure SrvUserLogout(userID:integer; const login:String8);
    procedure SrvUserMessage(userID:integer; var msg:TStringsReader);
    function SrvNameOf(userID:integer):String8;
  end;

var
  chatScene:TChatScene;

// ShortMD5(x)=copy(MD5(x),1,10) — the hash the client uses to derive PWDHASH and signatures.
function ShortMD5(const st:String8):String8;
begin
  result:=copy(DCPmd5a.MD5(st),1,10);
end;

// Truncate the END of a string so it fits maxW pixels (keeps the start, adds an ellipsis).
function FitWidth(font:TFontHandle;const s:String8;maxW:integer):String8;
begin
  if txt.Width(font,s)<=maxW then exit(s);
  result:=s;
  while (result<>'') and (txt.Width(font,result+'...')>maxW) do
    delete(result,length(result),1);
  result:=result+'...';
end;

// Keep the TAIL of the input that fits maxW pixels (so the caret stays visible while typing).
function FitTail(font:TFontHandle;const prefix,s,suffix:String8;maxW:integer):String8;
begin
  result:=s;
  while (result<>'') and (txt.Width(font,prefix+result+suffix)>maxW) do
    delete(result,1,1);
end;

{ TDemoAccounts }

function TDemoAccounts.FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
begin
  result:=login.Same(LOGIN);
  if result then begin
    pwdHash:=ShortMD5(PASSWORD);   // server signs with the same hash the client uses
    displayName:='Player';
  end;
end;

function TDemoAccounts.CreateAccount(const name,login,pwdHash,extras:String8):String8;
begin
  result:='ERROR: registration disabled in the demo';
end;

function TDemoAccounts.CheckName(const name:String8):boolean;
begin
  result:=false;
end;

{ network signal handler (client side) }

// Client signals arrive queued on the main thread (see SetEventHandler emQueued in Load),
// so it is safe to mutate scene state from here.
procedure NetHandler(event:TEventStr;tag:TTag);
var
  sub:TEventStr;
  reader:TStringsReader;
  kind,who,text:String8;
begin
  if chatScene=nil then exit;
  if not EventOfClass(event,'NET\Conn3',sub) then exit;

  if sub='CONNECTED' then begin
    chatScene.connState:='connected (authorizing...)';
    chatScene.AddLog(lsClient,'connected, got temporary id');
    exit;
  end;
  if sub='LOGGED' then begin
    chatScene.myUserID:=integer(tag);
    chatScene.connState:='logged in as '+LOGIN+' (uid '+IntToStr(integer(tag))+')';
    chatScene.AddLog(lsClient,'authorized -> uid '+IntToStr(integer(tag))+'; polling (comet)');
    chatScene.AddChat(ckSystem,'Connected. Type a message and press Enter.');
    exit;
  end;
  if sub='ACCESSDENIED' then begin
    chatScene.connState:='access denied: '+HGCErrorMessage;
    chatScene.AddLog(lsClient,'access denied: '+HGCErrorMessage);
    exit;
  end;
  if (sub='CONNECTIONFAILED') or (sub='CONNECTIONREJECTED') then begin
    chatScene.connState:='connection failed';
    chatScene.AddLog(lsClient,'connection failed');
    exit;
  end;
  if (sub='CONNECTIONBROKEN') or (sub='CONNECTIONCLOSED') then begin
    chatScene.connState:='disconnected';
    chatScene.AddLog(lsClient,'connection closed');
    exit;
  end;
  if sub='DATARECEIVED' then begin
    GetNetMessage(integer(tag),reader);
    kind:=reader.NextStr;
    if kind='msg' then begin
      who:=reader.NextStr;
      text:=reader.NextStr;
      chatScene.AddLog(lsClient,'comet <- "'+text+'" from '+who);
      if who.Same(LOGIN) then
        chatScene.AddChat(ckOwn,who+': '+text)        // our own line, echoed by the server
      else
        chatScene.AddChat(ckPeer,who+': '+text);
    end else
    if kind='sys' then begin
      text:=reader.NextStr;
      chatScene.AddLog(lsClient,'comet <- system message');
      chatScene.AddChat(ckSystem,text);
    end;
    exit;
  end;
end;

{ TChatScene }

constructor TChatScene.Create(const name:string;wnd:TWindow);
begin
  inherited Create(name,true,wnd);
  myUserID:=0;
  connState:='starting...';
end;

destructor TChatScene.Destroy;
begin
  Disconnect;            // tell the server we are leaving
  RemoveEventHandler(NetHandler);
  FreeAndNil(server);    // closes the listener and drops all sessions
  inherited;
end;

procedure TChatScene.Load;
begin
  titleFont:=txt.GetFont('Default',16);
  smallFont:=txt.GetFont('Default',9);
  chatFont:=txt.GetFont('Default',11);
  logFont:=txt.GetFont('Default',9);

  accounts:=TDemoAccounts.Create;
  server:=TGameServer.Create(SERVER_PORT,accounts);  // loopback by default
  server.onUserLogin:=SrvUserLogin;
  server.onUserLogout:=SrvUserLogout;
  server.onUserMessage:=SrvUserMessage;

  AddLog(lsServer,'listening on 127.0.0.1:'+IntToStr(SERVER_PORT));

  // client signals -> main-thread queue (the engine drains it each frame)
  SetEventHandler('NET\Conn3\',NetHandler,emQueued);

  // kick off the asynchronous advanced login; the worker thread drives it,
  // Process() pumps the server so the handshake can complete.
  AddLog(lsClient,'connecting to 127.0.0.1:'+IntToStr(SERVER_PORT)+' as '+LOGIN);
  Connect('127.0.0.1:'+IntToStr(SERVER_PORT),LOGIN,PASSWORD,CLIENT_INFO);
  connState:='connecting...';

  loaded:=true;
end;

function TChatScene.GetArea:TRect;
begin
  result:=Rect(0,0,window.renderWidth,window.renderHeight);
end;

procedure TChatScene.AddChat(kind:TChatKind;const text:String8);
begin
  chat[chatHead].kind:=kind;
  chat[chatHead].text:=text;
  chatHead:=(chatHead+1) mod MAX_CHAT;
  if chatCount<MAX_CHAT then inc(chatCount);
end;

procedure TChatScene.AddLog(side:TLogSide;const text:String8);
begin
  log[logHead].side:=side;
  log[logHead].text:=text;
  logHead:=(logHead+1) mod MAX_LOG;
  if logCount<MAX_LOG then inc(logCount);
end;

procedure TChatScene.SendInput;
var text:String8;
begin
  if System.Length(input)=0 then exit;
  text:=UTF8.Encode(input);    // codepoints -> UTF-8 only at the boundary
  if Connected then begin
    AddLog(lsClient,'POST -> "'+text+'"');
    SendData(['msg',text]);     // server echoes it back, so we DON'T add it to the chat locally
  end else
    AddChat(ckSystem,'(not connected) '+text);
  SetLength(input,0);
end;

function TChatScene.SrvNameOf(userID:integer):String8;
var i:integer;
begin
  for i:=0 to high(srvUsers) do
    if srvUsers[i].id=userID then exit(srvUsers[i].name);
  result:='user'+IntToStr(userID);
end;

procedure TChatScene.SrvUserLogin(userID:integer; const login:String8);
begin
  SetLength(srvUsers,length(srvUsers)+1);
  srvUsers[high(srvUsers)].id:=userID;
  srvUsers[high(srvUsers)].name:=login;
  AddLog(lsServer,'login '+login+' -> uid '+IntToStr(userID));
  server.SendToUser(userID,['sys','Welcome to the Apus chat demo!']);
  server.Broadcast(['sys',login+' joined ('+IntToStr(server.OnlineCount)+' online)']);
end;

procedure TChatScene.SrvUserLogout(userID:integer; const login:String8);
var i:integer;
begin
  for i:=0 to high(srvUsers) do
    if srvUsers[i].id=userID then begin
      srvUsers[i]:=srvUsers[high(srvUsers)];
      SetLength(srvUsers,length(srvUsers)-1);
      break;
    end;
  AddLog(lsServer,'logout uid '+IntToStr(userID));
  server.Broadcast(['sys',login+' left']);
end;

procedure TChatScene.SrvUserMessage(userID:integer; var msg:TStringsReader);
var kind,text:String8;
begin
  kind:=msg.NextStr;
  if kind='msg' then begin
    text:=msg.NextStr;
    AddLog(lsServer,'recv "'+text+'" from '+SrvNameOf(userID)+'; broadcast to '+IntToStr(server.OnlineCount));
    server.Broadcast(['msg',SrvNameOf(userID),text]);  // fan out to all (incl. sender)
  end;
end;

function TChatScene.Process:boolean;
var
  key:cardinal;
  uCode:integer;
begin
  if server<>nil then server.Poll;   // pump the in-process server (accept/read/dispatch/expire)

  // collect typed printable characters (text-input channel)
  repeat
    key:=ReadKey;
    if key=0 then break;
    uCode:=Bits.GetWord(key,1);       // AAAA = unicode codepoint
    if (uCode>=32) and (System.Length(input)<MAX_INPUT) then begin
      SetLength(input,System.Length(input)+1);
      input[high(input)]:=uCode;
    end;
  until false;

  result:=true;
end;

function TChatScene.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
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

// Draw a titled panel; returns the inner content rectangle (below the header bar, padded).
function TChatScene.DrawPanel(const r:TRect;const title:String8):TRect;
const HDR=26;
begin
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,COL_PANEL,8);
  draw.FillRect(r.Left+1,r.Top+1,r.Right-1,r.Top+HDR,COL_PANELHDR);
  draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,8,COL_BORDER);
  txt.Write(smallFont,r.Left+12,r.Top+8,COL_WHITE,title,taLeft,toAddBaseline);
  result:=Rect(r.Left+12,r.Top+HDR+8,r.Right-12,r.Bottom-10);
end;

procedure TChatScene.Render;
var
  w,h,top,inputTop,leftW,y,rowH,i,idx:integer;
  col:cardinal;
  inner,leftRect,rightRect:TRect;
  caret,vis:String8;
begin
  w:=window.renderWidth;
  h:=window.renderHeight;

  gfx.target.Clear(COL_BG);

  // --- header ---
  draw.FillRect(0,0,w,58,COL_HEADER);
  txt.Write(titleFont,16,12,COL_WHITE,'Apus Engine — Networking Demo',taLeft,toAddBaseline);
  txt.Write(smallFont,16,40,COL_DIM,
    'One process runs a game server AND a client over loopback HTTP. '+
    'Type a line + Enter: it round-trips client -> server -> broadcast -> client.',
    taLeft,toAddBaseline);

  // --- status strip ---
  draw.FillRect(0,58,w,82,COL_STATUS);
  if connState.Contains('logged') then col:=COL_OK else col:=COL_WARN;
  txt.Write(smallFont,16,65,col,
    'Client: '+connState+'      Server: 127.0.0.1:'+IntToStr(SERVER_PORT)+
    '   online: '+IntToStr(server.OnlineCount),
    taLeft,toAddBaseline);

  // --- panels layout ---
  top:=92;
  inputTop:=h-12-40;
  leftW:=round(w*0.46);
  leftRect:=Rect(12,top,12+leftW,inputTop-10);
  rightRect:=Rect(12+leftW+10,top,w-12,inputTop-10);

  // left: protocol log (oldest at top, newest at bottom)
  inner:=DrawPanel(leftRect,'Network Activity  (live protocol events)');
  rowH:=txt.Height(logFont)+9;
  y:=inner.Bottom-rowH;
  for i:=0 to logCount-1 do begin
    if y<inner.Top then break;
    idx:=(logHead-1-i+MAX_LOG) mod MAX_LOG;
    case log[idx].side of
      lsClient: begin col:=COL_LOG_CLI; vis:='client  '; end;
      lsServer: begin col:=COL_LOG_SRV; vis:='server  '; end;
    else
      col:=COL_LOG_INFO; vis:='        ';
    end;
    txt.Write(logFont,inner.Left,y,col,
      FitWidth(logFont,vis+log[idx].text,inner.Right-inner.Left),taLeft,toAddBaseline);
    dec(y,rowH);
  end;

  // right: chat (oldest at top, newest at bottom)
  inner:=DrawPanel(rightRect,'Chat');
  rowH:=txt.Height(chatFont)+10;
  y:=inner.Bottom-rowH;
  for i:=0 to chatCount-1 do begin
    if y<inner.Top then break;
    idx:=(chatHead-1-i+MAX_CHAT) mod MAX_CHAT;
    case chat[idx].kind of
      ckSystem: col:=COL_CHAT_SYS;
      ckOwn:    col:=COL_CHAT_OWN;
    else
      col:=COL_CHAT_PEER;
    end;
    txt.Write(chatFont,inner.Left,y,col,
      FitWidth(chatFont,chat[idx].text,inner.Right-inner.Left),taLeft,toAddBaseline);
    dec(y,rowH);
  end;

  // --- input line (full width) ---
  draw.FillRRect(12,inputTop,w-12,h-12,COL_INPUT,8);
  draw.RRect(12,inputTop,w-12,h-12,1,8,COL_INPUTBRD);
  if (CoreTime.Ticks div 500) and 1=0 then caret:='_' else caret:=' ';
  vis:=FitTail(chatFont,'> ',UTF8.Encode(input),caret,(w-24)-24);
  txt.Write(chatFont,24,inputTop+(40-txt.Height(chatFont)) div 2,COL_WHITE,
    '> '+vis+caret,taLeft,toAddBaseline);

  inherited;
end;

{ TMainApp }

constructor TMainApp.Create;
begin
  inherited;
  gameTitle:='Apus Engine: Networking Demo';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  useRealDPI:=false;
  windowWidth:=1100;
  windowHeight:=700;
  windowSizeable:=false;
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmFixedWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;  // 1:1 pixels, predictable layout
end;

procedure TMainApp.CreateScenes;
begin
  inherited;
  chatScene:=TChatScene.Create('Chat',window);
  game.SwitchToScene('Chat');
end;

end.
