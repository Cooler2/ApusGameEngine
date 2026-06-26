// Game-session HTTP server: the server-side counterpart of Apus.Engine.HttpGameClient.
// Reimplements the net.pas message protocol (login/auth, batched POST, comet long-poll)
// on top of the cross-platform Apus.HttpServer, byte-compatible with the client.

// Copyright (C) 2026 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.HttpGameServer;
interface
uses Apus.Core, Apus.Types, Apus.Strings, Apus.HashMaps, Apus.HttpServer;

type
  // Pluggable account storage. The demo provides an in-memory one; a game plugs its DB.
  IAccountProvider = interface
    // Find account by login. Returns true + pwdHash(=ShortMD5(password)) + displayName if it exists.
    function FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
    // Create account. Returns '' on success, or an 'ERROR: reason' string. pwdHash is pre-hashed by the client.
    function CreateAccount(const name,login,pwdHash,extras:String8):String8;
    // Name availability. true if the name is free.
    function CheckName(const name:String8):boolean;
  end;

  TUserEvent        = procedure(userID:integer; const login:String8) of object;
  TUserMessageEvent = procedure(userID:integer; var msg:TStringsReader) of object;

  TGameServer = class
  private
    fServer:THttpServer;
    fAccounts:IAccountProvider;
    fUsers:array of TObject;          // online TGameUser objects (compact, swap-removed)
    fById:THashMapNum<TObject>;       // userID -> TGameUser
    fLoginToId:THashMap<integer>;     // login -> authorized userID (stable across reconnects)
    fNextTempID:integer;              // next unauthorized id (>=10000)
    fNextAuthID:integer;              // next authorized id (1..9999)
    fOnUserLogin,fOnUserLogout:TUserEvent;
    fOnUserMessage:TUserMessageEvent;
    procedure OnHttpRequest(ctx:THttpContext);
    function  OnHttpDeferExpired(handle:THttpReqHandle):String8;
    function  FindUser(userID:integer):TObject;
    function  AddUser(userID:integer):TObject;
    procedure RemoveUser(userID:integer);
    procedure HandleLogin(ctx:THttpContext);
    procedure HandleLogout(ctx:THttpContext);
    procedure HandleNewAcc(ctx:THttpContext);
    procedure HandleUserMsgs(ctx:THttpContext;u:TObject;const serialStr,sign:String8);
    procedure HandleComet(ctx:THttpContext;u:TObject;const serialStr,sign:String8);
    procedure QueueMsg(u:TObject;const msg:String8);
    function  DrainOutbox(u:TObject):String8;
  public
    constructor Create(port:word;accounts:IAccountProvider;bindAll:boolean=false);
    destructor Destroy; override;
    procedure Poll;                                  // pump (wraps the owned THttpServer.Poll)
    procedure SendToUser(userID:integer;data:array of const); // queued; delivered on the user's poll
    procedure Broadcast(data:array of const);
    procedure Kick(userID:integer;reason:String8='');
    function  IsOnline(userID:integer):boolean;
    function  OnlineCount:integer;
    function  HttpServer:THttpServer;                // expose for GeoIP/penalty config etc.
    property onUserLogin:TUserEvent read fOnUserLogin write fOnUserLogin;
    property onUserLogout:TUserEvent read fOnUserLogout write fOnUserLogout;
    property onUserMessage:TUserMessageEvent read fOnUserMessage write fOnUserMessage;
  end;

implementation
uses SysUtils, Apus.Conv, Apus.Log, DCPmd5a;

const
  TEMP_ID_BASE=10000; // ids below this are authorized (and sign their polls); at/above are temporary

type
  // Per-user session state (mirrors net.pas users[]).
  TGameUser=class
    userID:integer;
    login,displayName,pwdHash:String8;
    remoteIP:cardinal;
    lastPostSerial,lastPollSerial:integer;
    outbox:String8;                  // CRLF-joined, each line already Escape'd; awaiting delivery
    parkedHandle:THttpReqHandle;     // current parked long-poll handle (0=none)
    lastActivity:int64;
  end;

// ShortMD5(x)=copy(MD5(x),1,10) — same routine the client uses, so signatures match byte-for-byte.
function ShortMD5(const st:String8):String8;
begin
  result:=copy(DCPmd5a.MD5(st),1,10);
end;

// Reverse the client's account-creation obfuscation: hex-decode, then XOR with a rolling key.
function DecodeAccObf(const hex:String8):String8;
var raw:String8; b:byte; i:integer;
begin
  raw:=Conv.DecodeHex(hex);
  b:=47;
  for i:=1 to length(raw) do begin
    raw[i]:=AnsiChar(byte(raw[i]) xor b);
    inc(b,39); // byte wraps mod 256, matching the client
  end;
  result:=raw;
end;

// Parse a text/plain POST body: CRLF-separated, line 0 = batch sign, lines 1.. = escaped messages.
function ParseTextBody(const body:String8):Strings8;
var i:integer;
begin
  result:=body.SplitLines;
  for i:=1 to high(result) do
    result[i]:=result[i].Unescape;
end;

// Parse an application/octet-stream POST body: length-prefixed parts (1 byte, or 255 + 3 bytes).
function ParseBinaryBody(const body:String8):Strings8;
var i,n,l:integer;
begin
  SetLength(result,16); // up to 15 messages + sign
  n:=0; i:=1;
  while (i<=length(body)) and (n<16) do begin
    l:=byte(body[i]); inc(i);
    if l=255 then begin
      if i+2>length(body) then break;
      l:=byte(body[i])+byte(body[i+1])*256+byte(body[i+2])*65536;
      inc(i,3);
    end;
    if i+l-1<=length(body) then begin
      SetLength(result[n],l);
      if l>0 then move(body[i],result[n][1],l);
      inc(n);
    end;
    inc(i,l);
  end;
  SetLength(result,n);
end;

{ TGameServer }

constructor TGameServer.Create(port:word;accounts:IAccountProvider;bindAll:boolean=false);
begin
  fAccounts:=accounts;
  fNextTempID:=TEMP_ID_BASE;
  fNextAuthID:=1;
  fById.Init(64);
  fLoginToId.Init(64);
  fServer:=THttpServer.Create(port,bindAll);
  fServer.onRequest:=OnHttpRequest;
  fServer.onDeferExpired:=OnHttpDeferExpired;
end;

destructor TGameServer.Destroy;
var i:integer;
begin
  FreeAndNil(fServer); // close connections first (no more callbacks into us)
  for i:=0 to high(fUsers) do fUsers[i].Free;
  SetLength(fUsers,0);
  inherited;
end;

procedure TGameServer.Poll;
begin
  fServer.Poll;
end;

function TGameServer.HttpServer:THttpServer;
begin
  result:=fServer;
end;

// --- user registry -----------------------------------------------------------

function TGameServer.FindUser(userID:integer):TObject;
begin
  if not fById.Get(userID,result) then result:=nil;
end;

function TGameServer.AddUser(userID:integer):TObject;
var u:TGameUser;
begin
  result:=FindUser(userID);
  if result<>nil then exit;
  u:=TGameUser.Create;
  u.userID:=userID;
  u.lastActivity:=CoreTime.Ticks;
  SetLength(fUsers,length(fUsers)+1);
  fUsers[high(fUsers)]:=u;
  fById.Put(userID,u);
  result:=u;
end;

procedure TGameServer.RemoveUser(userID:integer);
var u:TObject; i:integer;
begin
  u:=FindUser(userID);
  if u=nil then exit;
  fById.Remove(userID);
  for i:=0 to high(fUsers) do
    if fUsers[i]=u then begin
      fUsers[i]:=fUsers[high(fUsers)];
      SetLength(fUsers,length(fUsers)-1);
      break;
    end;
  u.Free;
end;

function TGameServer.IsOnline(userID:integer):boolean;
begin
  result:=FindUser(userID)<>nil;
end;

function TGameServer.OnlineCount:integer;
begin
  result:=length(fUsers);
end;

// --- outbound delivery -------------------------------------------------------

// Return the user's pending wire body (escaped, CRLF-joined) and clear it.
function TGameServer.DrainOutbox(u:TObject):String8;
begin
  result:=TGameUser(u).outbox;
  TGameUser(u).outbox:='';
end;

// Append one (already ~/_-joined) message to the outbox; flush immediately if a poll is parked.
procedure TGameServer.QueueMsg(u:TObject;const msg:String8);
var usr:TGameUser;
begin
  usr:=TGameUser(u);
  if usr.outbox<>'' then usr.outbox:=usr.outbox+#13#10+msg.Escape
  else usr.outbox:=msg.Escape;
  if (usr.parkedHandle<>0) and fServer.IsAlive(usr.parkedHandle) then begin
    fServer.Respond(usr.parkedHandle,DrainOutbox(usr));
    usr.parkedHandle:=0;
  end;
end;

procedure TGameServer.SendToUser(userID:integer;data:array of const);
var u:TObject; sa:Strings8; i:integer;
begin
  u:=FindUser(userID);
  if u=nil then exit;
  SetLength(sa,length(data));
  for i:=0 to high(data) do sa[i]:=VarRecToStr(data[i]);
  QueueMsg(u,sa.JoinEscaped('~','_'));
end;

procedure TGameServer.Broadcast(data:array of const);
var sa:Strings8; msg:String8; i:integer;
begin
  SetLength(sa,length(data));
  for i:=0 to high(data) do sa[i]:=VarRecToStr(data[i]);
  msg:=sa.JoinEscaped('~','_');
  for i:=0 to high(fUsers) do QueueMsg(fUsers[i],msg);
end;

procedure TGameServer.Kick(userID:integer;reason:String8='');
var u:TGameUser;
begin
  u:=TGameUser(FindUser(userID));
  if u=nil then exit;
  if (u.parkedHandle<>0) and fServer.IsAlive(u.parkedHandle) then
    fServer.Close(u.parkedHandle);
  RemoveUser(userID);
end;

// --- request dispatch --------------------------------------------------------

procedure TGameServer.OnHttpRequest(ctx:THttpContext);
var uri:String8; parts:Strings8; u:TObject; uid:integer;
begin
  uri:=ctx.uri.ToLower;
  if uri='login'  then begin HandleLogin(ctx);  exit; end;
  if uri='logout' then begin HandleLogout(ctx); exit; end;
  if uri='newacc' then begin HandleNewAcc(ctx); exit; end;
  // game route: uid-serial-sign (POST=messages, GET=comet poll)
  if ctx.uri.Contains('-') then begin
    parts:=ctx.uri.Split('-');
    if length(parts)>=2 then begin
      uid:=Conv.ToInt(parts[0],0);
      u:=FindUser(uid);
      if u<>nil then begin
        if length(parts)>=3 then begin
          if ctx.method.Same('POST') and (ctx.body<>'') then
            HandleUserMsgs(ctx,u,parts[1],parts[2])
          else
            HandleComet(ctx,u,parts[1],parts[2]);
        end else
          HandleComet(ctx,u,parts[1],''); // unsigned poll (temp user)
        exit;
      end;
    end;
  end;
  ctx.RespondError('404 Not Found');
end;

function TGameServer.OnHttpDeferExpired(handle:THttpReqHandle):String8;
var i:integer; u:TGameUser;
begin
  result:='';
  for i:=0 to high(fUsers) do begin
    u:=TGameUser(fUsers[i]);
    if u.parkedHandle=handle then begin
      result:=DrainOutbox(u); // usually '' => empty 200, client re-polls
      u.parkedHandle:=0;
      exit;
    end;
  end;
end;

procedure TGameServer.HandleLogin(ctx:THttpContext);
var tempID,authID:integer; login,info,sign,pwdHash,displayName,A:String8; u:TGameUser;
begin
  // simple login: GET /login?<rnd> — query is a bare number, no named params
  if not ctx.HasParam('A') then begin
    tempID:=fNextTempID; inc(fNextTempID);
    u:=TGameUser(AddUser(tempID));
    u.remoteIP:=ctx.remoteIP;
    ctx.Respond(IntToStr(tempID));
    exit;
  end;
  // advanced login: A=tempUID, B=login, C=clientInfo, D=sign
  A:=ctx.Param('A');
  login:=ctx.Param('B');
  info:=ctx.Param('C');
  sign:=ctx.Param('D');
  if not fAccounts.FindAccount(login,pwdHash,displayName) then begin
    fServer.PenalizeIP(ctx.remoteIP,10);
    ctx.Respond('ERROR: unknown account');
    exit;
  end;
  if sign<>ShortMD5(A+login+info+pwdHash) then begin
    fServer.PenalizeIP(ctx.remoteIP,20);
    ctx.Respond('ERROR: wrong password');
    exit;
  end;
  // allocate (or reuse) an authorized id for this login; replace any previous session
  if fLoginToId.Get(login,authID) then
    RemoveUser(authID)
  else begin
    authID:=fNextAuthID; inc(fNextAuthID);
    fLoginToId.Put(login,authID);
  end;
  RemoveUser(Conv.ToInt(A,0)); // drop the temporary session
  u:=TGameUser(AddUser(authID));
  u.login:=login; u.displayName:=displayName; u.pwdHash:=pwdHash;
  u.remoteIP:=ctx.remoteIP;
  ctx.Respond(IntToStr(authID));
  if Assigned(fOnUserLogin) then fOnUserLogin(authID,login);
end;

procedure TGameServer.HandleLogout(ctx:THttpContext);
var uid:integer; sign:String8; u:TGameUser;
begin
  uid:=Conv.ToInt(ctx.Param('A'),0);
  sign:=ctx.Param('B');
  u:=TGameUser(FindUser(uid));
  if (u<>nil) and (sign=ShortMD5(IntToStr(uid)+u.pwdHash)) then begin
    if Assigned(fOnUserLogout) then fOnUserLogout(uid,u.login);
    RemoveUser(uid);
  end;
  ctx.Respond(''); // ack (the client does not wait for the body)
end;

procedure TGameServer.HandleNewAcc(ctx:THttpContext);
var raw,extras,res:String8; fields:Strings8;
begin
  raw:=DecodeAccObf(ctx.Param('A')); // name#9login#9pwdhash#9extras
  fields:=raw.Split(#9);
  if length(fields)<3 then begin
    ctx.Respond('ERROR: malformed request');
    exit;
  end;
  if length(fields)>=4 then extras:=fields[3] else extras:='';
  res:=fAccounts.CreateAccount(fields[0],fields[1],fields[2],extras);
  if res='' then ctx.Respond('OK')
  else if res.StartsWith('ERROR') then ctx.Respond(res)
  else ctx.Respond('ERROR: '+res);
end;

procedure TGameServer.HandleUserMsgs(ctx:THttpContext;u:TObject;const serialStr,sign:String8);
var usr:TGameUser; serial,i:integer; sa:Strings8; whole:String8; msg:TStringsReader;
begin
  usr:=TGameUser(u);
  serial:=Conv.ToInt(serialStr,0);
  if sign<>ShortMD5(IntToStr(usr.userID)+serialStr+usr.pwdHash) then begin
    fServer.PenalizeIP(ctx.remoteIP,10);
    ctx.RespondError('500 Internal Server Error');
    exit;
  end;
  if serial<usr.lastPostSerial then begin
    ctx.RespondError('500 Internal Server Error'); // out of order
    exit;
  end;
  if serial=usr.lastPostSerial then begin
    ctx.Respond('IGNORED'); // duplicate (POST and GET share the serial counter)
    exit;
  end;
  // serial>lastPostSerial: extract the batch
  if ctx.contentType.Contains('octet-stream') then sa:=ParseBinaryBody(ctx.body)
  else sa:=ParseTextBody(ctx.body);
  // verify the per-batch signature over the concatenated message bodies
  whole:='';
  for i:=1 to high(sa) do whole:=whole+sa[i];
  if (length(sa)=0) or (ShortMD5(whole+usr.pwdHash)<>sa[0]) then begin
    fServer.PenalizeIP(ctx.remoteIP,5);
    ctx.RespondError('500 Internal Server Error'); // bad signature
    exit;
  end;
  usr.lastPostSerial:=serial;
  usr.lastActivity:=CoreTime.Ticks;
  ctx.Respond('OK');
  if Assigned(fOnUserMessage) then
    for i:=1 to high(sa) do begin
      msg.values:=sa[i].SplitEscaped('~','_');
      msg.index:=0;
      fOnUserMessage(usr.userID,msg);
    end;
end;

procedure TGameServer.HandleComet(ctx:THttpContext;u:TObject;const serialStr,sign:String8);
var usr:TGameUser; serial:integer; body:String8;
begin
  usr:=TGameUser(u);
  serial:=Conv.ToInt(serialStr,0);
  // authorized users (id<10000) sign their polls; temporary users don't
  if (usr.userID<TEMP_ID_BASE) and (sign<>ShortMD5(IntToStr(usr.userID)+serialStr+usr.pwdHash)) then begin
    fServer.PenalizeIP(ctx.remoteIP,10);
    ctx.RespondError('403 Forbidden');
    exit;
  end;
  if serial<usr.lastPollSerial then begin
    ctx.Respond('WTF!? '+IntToStr(usr.lastPollSerial)); // client treats this as a broken connection
    exit;
  end;
  if serial=usr.lastPollSerial then begin
    ctx.Respond(''); // duplicate poll => empty, client re-polls
    exit;
  end;
  usr.lastPollSerial:=serial;
  usr.lastActivity:=CoreTime.Ticks;
  body:=DrainOutbox(usr);
  if body<>'' then
    ctx.Respond(body)
  else begin
    usr.parkedHandle:=ctx.Handle;
    ctx.Defer(0); // hold open until a message arrives or the default comet timeout
  end;
end;

end.
