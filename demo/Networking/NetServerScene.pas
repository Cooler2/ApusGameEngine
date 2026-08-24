// Server scene for the Networking demo: runs an in-process TGameServer over
// loopback, shows the list of online players + a journal of protocol events,
// and spawns client processes on demand.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit NetServerScene;
interface
uses Types,Apus.Core,Apus.Types,Apus.Strings,
  Apus.Engine.API,Apus.Engine.Scene,Apus.Engine.Keys,
  Apus.HttpServer,Apus.Engine.HttpGameServer,
  NetCommon;

type
  // In-memory account store: any login starting with LOGIN is accepted (each
  // client process uses a distinct '<login><slot>'). A real game plugs its DB here.
  TDemoAccounts=class(TInterfacedObject,IAccountProvider)
    function FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
    function CreateAccount(const name,login,pwdHash,extras:String8):String8;
    function CheckName(const name:String8):boolean;
  end;

  TServerScene=class(TNetSceneBase)
    server:TGameServer;
    accounts:IAccountProvider;
    users:array of record id:integer; name:String8; end;
    nextClientSlot:integer;       // slot index for the next spawned client
    autoSpawn:boolean;
    started:boolean;
    btnLaunch:TRect;
    constructor Create(autoSpawnClient:boolean;wnd:TWindow);
    destructor Destroy; override;
    function Process:boolean; override;
    procedure Render; override;
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    procedure StartServer;        // runs on the main thread (first Process call)
    procedure SpawnClient;
    function NameOf(userID:integer):String8;
    // callbacks fired from server.Poll on the main thread — safe to touch state
    procedure UserLogin(userID:integer; const login:String8);
    procedure UserLogout(userID:integer; const login:String8);
    procedure UserMessage(userID:integer; var msg:TStringsReader);
  end;

implementation
uses SysUtils,Apus.Engine.Types;

{ TDemoAccounts }

function TDemoAccounts.FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
begin
  result:=login.StartsWith(LOGIN);   // accept player, player1, player2, ...
  if result then begin
    pwdHash:=ShortMD5(PASSWORD);      // server signs with the same hash the client uses
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

{ TServerScene }

constructor TServerScene.Create(autoSpawnClient:boolean;wnd:TWindow);
begin
  inherited Create('Net',wnd);
  autoSpawn:=autoSpawnClient;
  nextClientSlot:=1;            // server is slot 0, clients start at 1
  connState:='starting server...';
end;

destructor TServerScene.Destroy;
begin
  FreeAndNil(server);
  inherited;
end;

procedure TServerScene.StartServer;
begin
  accounts:=TDemoAccounts.Create;
  server:=TGameServer.Create(SERVER_PORT,accounts);  // loopback by default
  server.onUserLogin:=UserLogin;
  server.onUserLogout:=UserLogout;
  server.onUserMessage:=UserMessage;
  AddFeed(COL_LOG_SRV,'listening on 127.0.0.1:'+IntToStr(SERVER_PORT));
  connState:='listening';
  if autoSpawn then SpawnClient;
end;

procedure TServerScene.SpawnClient;
begin
  AddFeed(COL_LOG_SRV,'launching client #'+IntToStr(nextClientSlot)+'...');
  LaunchSelf('-client '+IntToStr(nextClientSlot));
  inc(nextClientSlot);
end;

function TServerScene.NameOf(userID:integer):String8;
var i:integer;
begin
  for i:=0 to high(users) do
    if users[i].id=userID then exit(users[i].name);
  result:='user'+IntToStr(userID);
end;

procedure TServerScene.UserLogin(userID:integer; const login:String8);
begin
  SetLength(users,length(users)+1);
  users[high(users)].id:=userID;
  users[high(users)].name:=login;
  AddFeed(COL_LOG_SRV,'login '+login+' -> uid '+IntToStr(userID));
  server.SendToUser(userID,['sys','Welcome to the Apus chat demo!']);
  server.Broadcast(['sys',login+' joined ('+IntToStr(server.OnlineCount)+' online)']);
end;

procedure TServerScene.UserLogout(userID:integer; const login:String8);
var i:integer;
begin
  for i:=0 to high(users) do
    if users[i].id=userID then begin
      users[i]:=users[high(users)];
      SetLength(users,length(users)-1);
      break;
    end;
  AddFeed(COL_LOG_SRV,'logout uid '+IntToStr(userID));
  server.Broadcast(['sys',login+' left']);
end;

procedure TServerScene.UserMessage(userID:integer; var msg:TStringsReader);
var kind,text:String8;
begin
  kind:=msg.NextStr;
  if kind='msg' then begin
    text:=msg.NextStr;
    AddFeed(COL_LOG_SRV,'recv "'+text+'" from '+NameOf(userID)+'; broadcast to '+IntToStr(server.OnlineCount));
    server.Broadcast(['msg',NameOf(userID),text]);   // fan out to all (incl. sender)
  end;
end;

function TServerScene.Process:boolean;
var clickLMB:boolean;
begin
  if not started then begin StartServer; started:=true; end;
  if not placed then begin PlaceWindow(0); placed:=true; end;
  server.Poll;                    // pump the in-process server
  clickLMB:=Bits.HasAll(window.mouseButtons,mbLeft) and
            not Bits.HasAll(window.oldMouseButtons,mbLeft);
  if clickLMB and Hit(btnLaunch) then SpawnClient;
  result:=true;
end;

procedure TServerScene.Render;
var w,h,top,btnTop,playersBottom,y,rowH,i:integer; inner:TRect;
begin
  w:=window.canvasWidth; h:=window.canvasHeight;
  gfx.target.Clear(COL_BG);
  DrawHeader('Apus Networking Demo  Server',
    'Loopback game server. Press C or click "Launch client" to start more clients.');
  DrawStatus('127.0.0.1:'+IntToStr(SERVER_PORT)+'   '+connState+
    '   online: '+IntToStr(server.OnlineCount), connState='listening');

  top:=S(94);
  btnTop:=h-S(12)-S(40);
  playersBottom:=top+S(150);

  // players panel
  inner:=DrawPanel(Rect(S(12),top,w-S(12),playersBottom),
    'Players online ('+IntToStr(length(users))+')');
  rowH:=txt.Height(uiFont)+S(6);
  if length(users)=0 then
    txt.Write(uiFont,inner.Left,inner.Top,COL_DIM,'(no players yet)',taLeft,toAddBaseline)
  else begin
    y:=inner.Top;
    for i:=0 to high(users) do begin
      if y+rowH>inner.Bottom then break;
      txt.Write(uiFont,inner.Left,y,COL_CHAT_PEER,
        FitWidth(uiFont,users[i].name+'  (uid '+IntToStr(users[i].id)+')',inner.Right-inner.Left),
        taLeft,toAddBaseline);
      inc(y,rowH);
    end;
  end;

  // event log panel
  inner:=DrawPanel(Rect(S(12),playersBottom+S(10),w-S(12),btnTop-S(10)),'Event log');
  DrawFeed(inner);

  // launch button
  btnLaunch:=Rect(w-S(12)-S(200),btnTop,w-S(12),h-S(12));
  DrawButton(btnLaunch,'Launch client',true);
  inherited;
end;

function TServerScene.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
begin
  result:=true;
  if key=TKey(ord('C')) then SpawnClient
  else result:=false;
end;

end.
