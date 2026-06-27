// Networking demo for Apus Engine: a chat client and an in-process game server.
//
// Demonstrates the full R-27 networking stack end to end:
//   Apus.Engine.HttpGameClient  <-- HTTP -->  Apus.Engine.HttpGameServer
//          (worker thread)                          (Poll-driven)
// The server runs in the SAME process on a loopback port, so a single window
// shows both sides of a real authenticated session (login + batched POST +
// long-poll comet). Type a line and press Enter: it travels client -> server,
// the server broadcasts it back to every connected user, and it reappears in
// the chat as a received message — proving the round trip visually.
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
  MAX_LINES    = 256;       // chat history ring-buffer size
  MAX_INPUT    = 200;       // max characters in the input line

type
  // One rendered chat line. kind drives the colour: own/peer/system.
  TChatKind=(ckSystem,ckPeer,ckOwn,ckLocal);
  TChatLine=record
    kind:TChatKind;
    text:String8;
  end;

  // In-memory account store: a single pre-seeded account. A real game plugs its DB here.
  TDemoAccounts=class(TInterfacedObject,IAccountProvider)
    function FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
    function CreateAccount(const name,login,pwdHash,extras:String8):String8;
    function CheckName(const name:String8):boolean;
  end;

  TChatScene=class(TGameScene)
    titleFont,statusFont,chatFont,inputFont:TFontHandle;
    server:TGameServer;
    accounts:IAccountProvider;
    // server-side userID -> login map (populated by the login callback)
    srvUsers:array of record id:integer; name:String8; end;

    lines:array[0..MAX_LINES-1] of TChatLine;
    lineHead,lineCount:integer;
    input:String8;
    connState:String8;        // human-readable client state for the status bar
    myUserID:integer;

    constructor Create(const name:string;wnd:TWindow);
    destructor Destroy; override;
    procedure Load; override;
    function Process:boolean; override;
    procedure Render; override;
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    function GetArea:TRect; override;

    procedure AddLine(kind:TChatKind;const text:String8);
    procedure SendInput;
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

// Append a Unicode codepoint to a UTF-8 String8 (the input line is UTF-8).
procedure AppendUtf8(var s:String8;cp:integer);
begin
  if cp<$80 then
    s:=s+AnsiChar(cp)
  else if cp<$800 then
    s:=s+AnsiChar($C0 or (cp shr 6))+AnsiChar($80 or (cp and $3F))
  else
    s:=s+AnsiChar($E0 or (cp shr 12))+AnsiChar($80 or ((cp shr 6) and $3F))+
         AnsiChar($80 or (cp and $3F));
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
    exit;
  end;
  if sub='LOGGED' then begin
    chatScene.myUserID:=integer(tag);
    chatScene.connState:='logged in as '+LOGIN+' (uid '+IntToStr(integer(tag))+')';
    chatScene.AddLine(ckSystem,'Connected to server. Say hello!');
    exit;
  end;
  if sub='ACCESSDENIED' then begin
    chatScene.connState:='access denied: '+HGCErrorMessage;
    chatScene.AddLine(ckSystem,'Login failed: '+HGCErrorMessage);
    exit;
  end;
  if (sub='CONNECTIONFAILED') or (sub='CONNECTIONREJECTED') then begin
    chatScene.connState:='connection failed';
    chatScene.AddLine(ckSystem,'Could not reach the server.');
    exit;
  end;
  if (sub='CONNECTIONBROKEN') or (sub='CONNECTIONCLOSED') then begin
    chatScene.connState:='disconnected';
    chatScene.AddLine(ckSystem,'Connection closed.');
    exit;
  end;
  if sub='DATARECEIVED' then begin
    GetNetMessage(integer(tag),reader);
    kind:=reader.NextStr;
    if kind='msg' then begin
      who:=reader.NextStr;
      text:=reader.NextStr;
      if who.Same(LOGIN) then
        chatScene.AddLine(ckOwn,who+': '+text)        // our own line, echoed by the server
      else
        chatScene.AddLine(ckPeer,who+': '+text);
    end else
    if kind='sys' then
      chatScene.AddLine(ckSystem,reader.NextStr);
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
  titleFont:=txt.GetFont('Default',14);
  statusFont:=txt.GetFont('Default',9);
  chatFont:=txt.GetFont('Default',10);
  inputFont:=txt.GetFont('Default',11);

  accounts:=TDemoAccounts.Create;
  server:=TGameServer.Create(SERVER_PORT,accounts);  // loopback by default
  server.onUserLogin:=SrvUserLogin;
  server.onUserLogout:=SrvUserLogout;
  server.onUserMessage:=SrvUserMessage;

  AddLine(ckSystem,'Server listening on 127.0.0.1:'+IntToStr(SERVER_PORT));

  // client signals -> main-thread queue (the engine drains it each frame)
  SetEventHandler('NET\Conn3\',NetHandler,emQueued);

  // kick off the asynchronous advanced login; the worker thread drives it,
  // Process() pumps the server so the handshake can complete.
  Connect('127.0.0.1:'+IntToStr(SERVER_PORT),LOGIN,PASSWORD,CLIENT_INFO);
  connState:='connecting...';

  loaded:=true;
end;

function TChatScene.GetArea:TRect;
begin
  result:=Rect(0,0,window.renderWidth,window.renderHeight);
end;

procedure TChatScene.AddLine(kind:TChatKind;const text:String8);
begin
  lines[lineHead].kind:=kind;
  lines[lineHead].text:=text;
  lineHead:=(lineHead+1) mod MAX_LINES;
  if lineCount<MAX_LINES then inc(lineCount);
end;

procedure TChatScene.SendInput;
begin
  if input='' then exit;
  if Connected then begin
    SendData(['msg',input]);   // server echoes it back, so we DON'T add it locally
  end else
    AddLine(ckLocal,'(not connected) '+input);
  input:='';
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
  server.Broadcast(['sys',login+' left']);
end;

procedure TChatScene.SrvUserMessage(userID:integer; var msg:TStringsReader);
var kind,text:String8;
begin
  kind:=msg.NextStr;
  if kind='msg' then begin
    text:=msg.NextStr;
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
    if (uCode>=32) and (length(input)<MAX_INPUT) then
      AppendUtf8(input,uCode);
  until false;

  result:=true;
end;

function TChatScene.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
begin
  result:=true;
  case key of
    TKey.Enter:     SendInput;
    TKey.Backspace: if input<>'' then input:=copy(input,1,length(input)-1);
    TKey.Escape:    input:='';
  else
    result:=false;
  end;
end;

procedure TChatScene.Render;
var
  w,h,top,bottom,inputTop,y,i,idx:integer;
  col:cardinal;
  caret:String8;
begin
  w:=window.renderWidth;
  h:=window.renderHeight;

  gfx.target.Clear($FF12161F);

  // --- title bar ---
  draw.FillRect(0,0,w,46,$FF1B2740);
  txt.Write(titleFont,18,30,$FFE8F0FA,'Apus Engine — Networking Demo (in-process client + server)',taLeft,toAddBaseline);

  // --- status bar ---
  draw.FillRect(0,46,w,72,$FF15202F);
  col:=$FFFFC080;
  if connState.Contains('logged') then col:=$FF9BE08C;
  txt.Write(statusFont,18,64,col,'Status: '+connState+'   |   online: '+
    IntToStr(server.OnlineCount),taLeft,toAddBaseline);

  // --- chat area ---
  top:=84;
  inputTop:=h-52;
  bottom:=inputTop-10;
  draw.FillRRect(12,top,w-12,bottom,$FF1A2230,8);
  draw.RRect(12,top,w-12,bottom,1,8,$FF31415A);

  // newest line at the bottom, older lines above
  y:=bottom-14;
  for i:=0 to lineCount-1 do begin
    if y<top+18 then break;
    idx:=(lineHead-1-i+MAX_LINES) mod MAX_LINES;
    case lines[idx].kind of
      ckSystem: col:=$FF8FA6C4;
      ckPeer:   col:=$FF9CD2FF;
      ckOwn:    col:=$FFFFE7A0;
    else
      col:=$FFB0B8C4;
    end;
    txt.Write(chatFont,26,y,col,lines[idx].text,taLeft,toAddBaseline);
    dec(y,20);
  end;

  // --- input line ---
  draw.FillRRect(12,inputTop,w-12,h-8,$FF202C40,8);
  draw.RRect(12,inputTop,w-12,h-8,1,8,$FF3E5273);
  if (CoreTime.Ticks div 500) and 1=0 then caret:='_' else caret:=' ';
  txt.Write(inputFont,26,inputTop+30,$FFEFF4FC,'> '+input+caret,taLeft,toAddBaseline);

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
  windowWidth:=1000;
  windowHeight:=680;
  windowSizeable:=true;
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmWindow;
end;

procedure TMainApp.CreateScenes;
begin
  inherited;
  chatScene:=TChatScene.Create('Chat',window);
  game.SwitchToScene('Chat');
end;

end.
