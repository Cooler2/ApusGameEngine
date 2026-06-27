// Networking demo for Apus Engine: a multi-process chat over the R-27 stack.
//
//   Apus.Engine.HttpGameClient  <-- HTTP -->  Apus.Engine.HttpGameServer
//          (client process)                        (server process)
//
// The client keeps its session in unit globals, so it is one-client-per-process.
// To show a real multi-user chat we therefore run SEPARATE processes:
//   (no args)   server process; also auto-launches one client process
//   -server     server only (no auto client)
//   -client     client only; connects to the server on 127.0.0.1:<port>
// The server window has a "Launch client" button (or press C) that spawns more
// client processes. Each client logs in, sends messages, and the server
// broadcasts them back to everyone — so all client windows stay in sync.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit NetworkingApp;
interface
uses Apus.Engine.GameApp,Apus.Engine.API;

type
  TAppRole=(roServer,roClient);

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
  {$IFDEF MSWINDOWS}Windows,ShellApi,{$ELSE}Process,{$ENDIF}
  Types,  // after Windows so Types.Rect/Point (functions) win over Windows.Rect/Point (types)
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
  LOGIN        = 'player';        // base login; clients append their pid to be distinct
  PASSWORD     = 'demo';
  CLIENT_INFO  = 'NetworkingDemo';
  MAX_CHAT     = 256;            // chat history ring-buffer size
  MAX_LOG      = 256;            // protocol log ring-buffer size
  MAX_INPUT    = 200;           // max characters in the input line

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
  COL_WHITE    = $FFEFF4FC;
  COL_DIM      = $FF8FA6C4;
  COL_OK       = $FF9BE08C;
  COL_WARN     = $FFFFC080;
  COL_CHAT_SYS = $FF8FA6C4;
  COL_CHAT_OWN = $FFFFE7A0;
  COL_CHAT_PEER= $FF9CD2FF;
  COL_LOG_CLI  = $FF7FE0FF;      // client-side events (cyan)
  COL_LOG_SRV  = $FFFFD27A;      // server-side events (amber)
  COL_LOG_INFO = $FF99A6B8;      // neutral info

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

  // In-memory account store: any login starting with LOGIN is accepted (each client
  // process uses a distinct '<login><pid>'). A real game plugs its DB here instead.
  TDemoAccounts=class(TInterfacedObject,IAccountProvider)
    function FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
    function CreateAccount(const name,login,pwdHash,extras:String8):String8;
    function CheckName(const name:String8):boolean;
  end;

  TNetScene=class(TGameScene)
    role:TAppRole;
    autoSpawnClient:boolean;
    titleFont,smallFont,chatFont,logFont:TFontHandle;

    // server side
    server:TGameServer;
    accounts:IAccountProvider;
    srvUsers:array of record id:integer; name:String8; end;
    btnRect:TRect;
    btnHover:boolean;

    // client side
    myLogin:String8;
    input:String32;               // edit buffer as UCS-4 codepoints (1 element = 1 char)
    myUserID:integer;

    // shared UI state
    chat:array[0..MAX_CHAT-1] of TChatLine;
    chatHead,chatCount:integer;
    log:array[0..MAX_LOG-1] of TLogLine;
    logHead,logCount:integer;
    connState:String8;
    started:boolean;              // networking brought up on the main thread

    constructor Create(const name:string;aRole:TAppRole;spawnClient:boolean;wnd:TWindow);
    destructor Destroy; override;
    procedure Load; override;
    procedure StartNetworking;    // runs on the main thread (first Process call)
    function Process:boolean; override;
    procedure Render; override;
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    function GetArea:TRect; override;

    procedure AddChat(kind:TChatKind;const text:String8);
    procedure AddLog(side:TLogSide;const text:String8);
    procedure SendInput;
    procedure SpawnClient;
    function DrawPanel(const r:TRect;const title:String8):TRect; // returns inner content rect
    procedure DrawLog(const r:TRect);
    // server-side callbacks (run on the main thread during server.Poll — safe to touch state)
    procedure SrvUserLogin(userID:integer; const login:String8);
    procedure SrvUserLogout(userID:integer; const login:String8);
    procedure SrvUserMessage(userID:integer; var msg:TStringsReader);
    function SrvNameOf(userID:integer):String8;
  end;

var
  netScene:TNetScene;

// ShortMD5(x)=copy(MD5(x),1,10) — the hash the client uses to derive PWDHASH and signatures.
function ShortMD5(const st:String8):String8;
begin
  result:=copy(DCPmd5a.MD5(st),1,10);
end;

// Launch another instance of this exe with the given argument (non-blocking).
procedure LaunchSelf(const arg:String8);
{$IFNDEF MSWINDOWS}var p:TProcess;{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0,'open',PChar(ParamStr(0)),PChar(string(arg)),nil,SW_SHOWNORMAL);
{$ELSE}
  p:=TProcess.Create(nil);
  try
    p.Executable:=ParamStr(0);
    p.Parameters.Add(string(arg));
    p.Execute;                    // returns immediately (no poWaitOnExit)
  finally
    p.Free;
  end;
{$ENDIF}
end;

// True if the command line contains the given switch (case-insensitive, '-name').
function HasSwitch(const name:String8):boolean;
var i:integer;
begin
  result:=false;
  for i:=1 to ParamCount do
    if String8(ParamStr(i)).Same('-'+name) then exit(true);
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
  result:=login.StartsWith(LOGIN);     // accept player, player1234, ...
  if result then begin
    pwdHash:=ShortMD5(PASSWORD);        // server signs with the same hash the client uses
    displayName:=login;
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

// Client signals arrive queued on the main thread (SetEventHandler emQueued in
// StartNetworking, called from Process — NOT from Load, which runs off the render
// thread), so it is safe to mutate scene state from here.
procedure NetHandler(event:TEventStr;tag:TTag);
var
  sub:TEventStr;
  reader:TStringsReader;
  kind,who,text:String8;
begin
  if netScene=nil then exit;
  if not EventOfClass(event,'NET\Conn3',sub) then exit;

  if sub='CONNECTED' then begin
    netScene.connState:='connected (authorizing...)';
    netScene.AddLog(lsClient,'connected, got temporary id');
    exit;
  end;
  if sub='LOGGED' then begin
    netScene.myUserID:=integer(tag);
    netScene.connState:='logged in as '+netScene.myLogin+' (uid '+IntToStr(integer(tag))+')';
    netScene.AddLog(lsClient,'authorized -> uid '+IntToStr(integer(tag))+'; polling (comet)');
    netScene.AddChat(ckSystem,'Connected. Type a message and press Enter.');
    exit;
  end;
  if sub='ACCESSDENIED' then begin
    netScene.connState:='access denied: '+HGCErrorMessage;
    netScene.AddLog(lsClient,'access denied: '+HGCErrorMessage);
    exit;
  end;
  if (sub='CONNECTIONFAILED') or (sub='CONNECTIONREJECTED') then begin
    netScene.connState:='connection failed (is the server running?)';
    netScene.AddLog(lsClient,'connection failed');
    exit;
  end;
  if (sub='CONNECTIONBROKEN') or (sub='CONNECTIONCLOSED') then begin
    netScene.connState:='disconnected';
    netScene.AddLog(lsClient,'connection closed');
    exit;
  end;
  if sub='DATARECEIVED' then begin
    GetNetMessage(integer(tag),reader);
    kind:=reader.NextStr;
    if kind='msg' then begin
      who:=reader.NextStr;
      text:=reader.NextStr;
      netScene.AddLog(lsClient,'comet <- "'+text+'" from '+who);
      if who.Same(netScene.myLogin) then
        netScene.AddChat(ckOwn,who+': '+text)        // our own line, echoed by the server
      else
        netScene.AddChat(ckPeer,who+': '+text);
    end else
    if kind='sys' then begin
      text:=reader.NextStr;
      netScene.AddLog(lsClient,'comet <- system message');
      netScene.AddChat(ckSystem,text);
    end;
    exit;
  end;
end;

{ TNetScene }

constructor TNetScene.Create(const name:string;aRole:TAppRole;spawnClient:boolean;wnd:TWindow);
begin
  inherited Create(name,true,wnd);
  role:=aRole;
  autoSpawnClient:=spawnClient;
  myUserID:=0;
  if role=roServer then connState:='starting server...'
  else connState:='starting client...';
end;

destructor TNetScene.Destroy;
begin
  if role=roClient then begin
    Disconnect;
    RemoveEventHandler(NetHandler);
  end;
  FreeAndNil(server);
  inherited;
end;

procedure TNetScene.Load;
begin
  titleFont:=txt.GetFont('Default',16);
  smallFont:=txt.GetFont('Default',9);
  chatFont:=txt.GetFont('Default',11);
  logFont:=txt.GetFont('Default',9);
  loaded:=true;
end;

procedure TNetScene.StartNetworking;
begin
  if role=roServer then begin
    accounts:=TDemoAccounts.Create;
    server:=TGameServer.Create(SERVER_PORT,accounts);   // loopback by default
    server.onUserLogin:=SrvUserLogin;
    server.onUserLogout:=SrvUserLogout;
    server.onUserMessage:=SrvUserMessage;
    AddLog(lsServer,'listening on 127.0.0.1:'+IntToStr(SERVER_PORT));
    connState:='listening';
    if autoSpawnClient then SpawnClient;
  end else begin
    // distinct login per client process so several can be online at once
    myLogin:=LOGIN+IntToStr(GetCurrentProcessId and $FFFF);
    SetEventHandler('NET\Conn3\',NetHandler,emQueued);
    AddLog(lsClient,'connecting to 127.0.0.1:'+IntToStr(SERVER_PORT)+' as '+myLogin);
    Connect('127.0.0.1:'+IntToStr(SERVER_PORT),myLogin,PASSWORD,CLIENT_INFO);
    connState:='connecting...';
  end;
end;

function TNetScene.GetArea:TRect;
begin
  result:=Rect(0,0,window.renderWidth,window.renderHeight);
end;

procedure TNetScene.AddChat(kind:TChatKind;const text:String8);
begin
  chat[chatHead].kind:=kind;
  chat[chatHead].text:=text;
  chatHead:=(chatHead+1) mod MAX_CHAT;
  if chatCount<MAX_CHAT then inc(chatCount);
end;

procedure TNetScene.AddLog(side:TLogSide;const text:String8);
begin
  log[logHead].side:=side;
  log[logHead].text:=text;
  logHead:=(logHead+1) mod MAX_LOG;
  if logCount<MAX_LOG then inc(logCount);
end;

procedure TNetScene.SpawnClient;
begin
  AddLog(lsServer,'launching a client process...');
  LaunchSelf('-client');
end;

procedure TNetScene.SendInput;
var text:String8;
begin
  if System.Length(input)=0 then exit;
  text:=UTF8.Encode(input);     // codepoints -> UTF-8 only at the boundary
  if Connected then begin
    AddLog(lsClient,'POST -> "'+text+'"');
    SendData(['msg',text]);      // server echoes it back, so we DON'T add it locally
  end else
    AddChat(ckSystem,'(not connected) '+text);
  SetLength(input,0);
end;

function TNetScene.SrvNameOf(userID:integer):String8;
var i:integer;
begin
  for i:=0 to high(srvUsers) do
    if srvUsers[i].id=userID then exit(srvUsers[i].name);
  result:='user'+IntToStr(userID);
end;

procedure TNetScene.SrvUserLogin(userID:integer; const login:String8);
begin
  SetLength(srvUsers,length(srvUsers)+1);
  srvUsers[high(srvUsers)].id:=userID;
  srvUsers[high(srvUsers)].name:=login;
  AddLog(lsServer,'login '+login+' -> uid '+IntToStr(userID));
  server.SendToUser(userID,['sys','Welcome to the Apus chat demo!']);
  server.Broadcast(['sys',login+' joined ('+IntToStr(server.OnlineCount)+' online)']);
end;

procedure TNetScene.SrvUserLogout(userID:integer; const login:String8);
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

procedure TNetScene.SrvUserMessage(userID:integer; var msg:TStringsReader);
var kind,text:String8;
begin
  kind:=msg.NextStr;
  if kind='msg' then begin
    text:=msg.NextStr;
    AddLog(lsServer,'recv "'+text+'" from '+SrvNameOf(userID)+'; broadcast to '+IntToStr(server.OnlineCount));
    server.Broadcast(['msg',SrvNameOf(userID),text]);  // fan out to all (incl. sender)
  end;
end;

function TNetScene.Process:boolean;
var
  key:cardinal;
  uCode:integer;
  clickLMB:boolean;
begin
  if not started then begin
    StartNetworking;
    started:=true;
  end;

  if role=roServer then begin
    server.Poll;                  // pump the in-process server
    btnHover:=PtInRect(btnRect,Point(window.mousePos.x,window.mousePos.y));
    clickLMB:=Bits.HasAll(window.mouseButtons,mbLeft) and
              not Bits.HasAll(window.oldMouseButtons,mbLeft);
    if clickLMB and btnHover then SpawnClient;
  end else begin
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
  end;

  result:=true;
end;

function TNetScene.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
begin
  result:=true;
  if role=roServer then begin
    if key=TKey(ord('C')) then SpawnClient
    else result:=false;
    exit;
  end;
  case key of
    TKey.Enter:     SendInput;
    TKey.Backspace: if System.Length(input)>0 then SetLength(input,System.Length(input)-1);
    TKey.Escape:    SetLength(input,0);
  else
    result:=false;
  end;
end;

// Draw a titled panel; returns the inner content rectangle (below the header bar, padded).
function TNetScene.DrawPanel(const r:TRect;const title:String8):TRect;
const HDR=26;
begin
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,COL_PANEL,8);
  draw.FillRect(r.Left+1,r.Top+1,r.Right-1,r.Top+HDR,COL_PANELHDR);
  draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,8,COL_BORDER);
  txt.Write(smallFont,r.Left+12,r.Top+8,COL_WHITE,title,taLeft,toAddBaseline);
  result:=Rect(r.Left+12,r.Top+HDR+8,r.Right-12,r.Bottom-10);
end;

// Draw the protocol log inside rect r (oldest at top, newest at bottom).
procedure TNetScene.DrawLog(const r:TRect);
var rowH,y,i,idx:integer; col:cardinal; tag:String8;
begin
  rowH:=txt.Height(logFont)+9;
  y:=r.Bottom-rowH;
  for i:=0 to logCount-1 do begin
    if y<r.Top then break;
    idx:=(logHead-1-i+MAX_LOG) mod MAX_LOG;
    case log[idx].side of
      lsClient: begin col:=COL_LOG_CLI; tag:='client  '; end;
      lsServer: begin col:=COL_LOG_SRV; tag:='server  '; end;
    else
      col:=COL_LOG_INFO; tag:='        ';
    end;
    txt.Write(logFont,r.Left,y,col,FitWidth(logFont,tag+log[idx].text,r.Right-r.Left),taLeft,toAddBaseline);
    dec(y,rowH);
  end;
end;

procedure TNetScene.Render;
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
  if role=roServer then begin
    txt.Write(titleFont,16,12,COL_WHITE,'Apus Networking Demo — Server',taLeft,toAddBaseline);
    txt.Write(smallFont,16,40,COL_DIM,
      'Game server over loopback HTTP. Click "Launch client" (or press C) to start more client processes.',
      taLeft,toAddBaseline);
  end else begin
    txt.Write(titleFont,16,12,COL_WHITE,'Apus Networking Demo — Client',taLeft,toAddBaseline);
    txt.Write(smallFont,16,40,COL_DIM,
      'Type a line + Enter: it round-trips client -> server -> broadcast -> all clients.',
      taLeft,toAddBaseline);
  end;

  // --- status strip ---
  draw.FillRect(0,58,w,82,COL_STATUS);
  if connState.Contains('logged') or (connState='listening') then col:=COL_OK else col:=COL_WARN;
  if role=roServer then
    txt.Write(smallFont,16,65,col,
      'Server 127.0.0.1:'+IntToStr(SERVER_PORT)+' — '+connState+
      '      users online: '+IntToStr(server.OnlineCount),taLeft,toAddBaseline)
  else
    txt.Write(smallFont,16,65,col,
      'Client: '+connState+'      server 127.0.0.1:'+IntToStr(SERVER_PORT),taLeft,toAddBaseline);

  top:=92;

  if role=roServer then begin
    // log panel fills the window; a "Launch client" button sits at the bottom
    inputTop:=h-12-40;
    inner:=DrawPanel(Rect(12,top,w-12,inputTop-10),'Server Activity  (logins / messages / broadcasts)');
    DrawLog(inner);
    // button
    btnRect:=Rect(w-12-200,inputTop,w-12,h-12);
    if btnHover then col:=COL_BTN_HOV else col:=COL_BTN;
    draw.FillRRect(btnRect.Left,btnRect.Top,btnRect.Right,btnRect.Bottom,col,8);
    draw.RRect(btnRect.Left,btnRect.Top,btnRect.Right,btnRect.Bottom,1,8,COL_INPUTBRD);
    txt.Write(chatFont,btnRect.Left+(btnRect.Right-btnRect.Left-txt.Width(chatFont,'Launch client')) div 2,
      btnRect.Top+(40-txt.Height(chatFont)) div 2,COL_WHITE,'Launch client',taLeft,toAddBaseline);
    exit;
  end;

  // --- client layout: left protocol log, right chat, input at bottom ---
  inputTop:=h-12-40;
  leftW:=round(w*0.46);
  leftRect:=Rect(12,top,12+leftW,inputTop-10);
  rightRect:=Rect(12+leftW+10,top,w-12,inputTop-10);

  inner:=DrawPanel(leftRect,'Network Activity  (live protocol events)');
  DrawLog(inner);

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
    txt.Write(chatFont,inner.Left,y,col,FitWidth(chatFont,chat[idx].text,inner.Right-inner.Left),taLeft,toAddBaseline);
    dec(y,rowH);
  end;

  // input line (full width)
  draw.FillRRect(12,inputTop,w-12,h-12,COL_INPUT,8);
  draw.RRect(12,inputTop,w-12,h-12,1,8,COL_INPUTBRD);
  if (CoreTime.Ticks div 500) and 1=0 then caret:='_' else caret:=' ';
  vis:=FitTail(chatFont,'> ',UTF8.Encode(input),caret,(w-24)-24);
  txt.Write(chatFont,24,inputTop+(40-txt.Height(chatFont)) div 2,COL_WHITE,'> '+vis+caret,taLeft,toAddBaseline);

  inherited;
end;

{ TMainApp }

constructor TMainApp.Create;
begin
  inherited;
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  useRealDPI:=false;
  windowSizeable:=false;
  if HasSwitch('client') then begin
    gameTitle:='Apus Networking Demo — Client';
    windowWidth:=1000;
    windowHeight:=640;
  end else begin
    gameTitle:='Apus Networking Demo — Server';
    windowWidth:=760;
    windowHeight:=560;
  end;
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmFixedWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;  // 1:1 pixels, predictable layout
end;

procedure TMainApp.CreateScenes;
var role:TAppRole; spawn:boolean;
begin
  inherited;
  if HasSwitch('client') then begin
    role:=roClient; spawn:=false;
  end else begin
    role:=roServer;
    spawn:=not HasSwitch('server');  // bare launch also auto-starts one client
  end;
  netScene:=TNetScene.Create('Net',role,spawn,window);
  game.SwitchToScene('Net');
end;

end.
