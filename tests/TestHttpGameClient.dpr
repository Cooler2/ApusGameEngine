{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
// Loopback integration test: the real HttpGameClient talks to a real
// HttpGameServer over 127.0.0.1, exercising the full wire protocol
// (login/auth, signed message batches, comet long-poll delivery, logout).
// This is the byte-compatibility spine of R-27.
program TestHttpGameClient;

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Strings,
  Apus.EventMan,
  DCPmd5a,
  Apus.HttpServer,
  Apus.Engine.HttpGameServer,
  Apus.Engine.HttpGameClient;

{$I ..\Base\tests\Test.inc}

const
  PORT       = 18789;
  LOGIN      = 'tester';
  PASSWORD   = 'secret';
  CLIENTINFO = 'testclient';

// Same short hash the client/server use, so the seeded account matches.
function ShortMD5(const st:String8):String8;
begin
  result:=copy(DCPmd5a.MD5(st),1,10);
end;

type
  // In-memory account store with one pre-seeded account.
  TMemAccounts=class(TInterfacedObject,IAccountProvider)
    function FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
    function CreateAccount(const name,login,pwdHash,extras:String8):String8;
    function CheckName(const name:String8):boolean;
  end;

  // Holds the server-side callbacks (TUserEvent/TUserMessageEvent are "of object").
  THarness=class
    loginCount,logoutCount,msgCount:integer;
    msgF0,msgF1:String8;
    msgF2:integer;
    procedure OnLogin(userID:integer; const login:String8);
    procedure OnLogout(userID:integer; const login:String8);
    procedure OnMessage(userID:integer; var msg:TStringsReader);
  end;

function TMemAccounts.FindAccount(const login:String8; out pwdHash,displayName:String8):boolean;
begin
  result:=login=LOGIN;
  if result then begin
    pwdHash:=ShortMD5(PASSWORD);
    displayName:='Tester';
  end;
end;

function TMemAccounts.CreateAccount(const name,login,pwdHash,extras:String8):String8;
begin
  result:=''; // accept anything (not exercised here)
end;

function TMemAccounts.CheckName(const name:String8):boolean;
begin
  result:=true;
end;

procedure THarness.OnLogin(userID:integer; const login:String8);
begin
  inc(loginCount);
end;

procedure THarness.OnLogout(userID:integer; const login:String8);
begin
  inc(logoutCount);
end;

procedure THarness.OnMessage(userID:integer; var msg:TStringsReader);
begin
  inc(msgCount);
  msgF0:=msg.NextStr;
  msgF1:=msg.NextStr;
  msgF2:=msg.NextInt;
end;

var
  srv:TGameServer;
  // client-side signal capture (TEventHandler is a plain procedure)
  cliLoggedCount,cliConnectedCount,cliDeniedCount,cliFailedCount:integer;
  cliUserID:integer;
  cliMsgCount:integer;
  cliF0,cliF1:String8;
  cliF2:integer;

procedure OnConnected(event:TEventStr;tag:TTag);
begin
  inc(cliConnectedCount);
end;

procedure OnLogged(event:TEventStr;tag:TTag);
begin
  inc(cliLoggedCount);
  cliUserID:=tag;
end;

procedure OnDenied(event:TEventStr;tag:TTag);
begin
  inc(cliDeniedCount);
end;

procedure OnFailed(event:TEventStr;tag:TTag);
begin
  inc(cliFailedCount);
end;

procedure OnData(event:TEventStr;tag:TTag);
var msg:TStringsReader;
begin
  GetNetMessage(tag,msg);
  inc(cliMsgCount);
  cliF0:=msg.NextStr;
  cliF1:=msg.NextStr;
  cliF2:=msg.NextInt;
end;

// Pump the server + dispatch queued client signals until counter reaches target or timeout.
function PumpUntil(counter:PInteger; target,ms:integer):boolean;
var deadline:int64;
begin
  deadline:=CoreTime.Ticks+ms;
  repeat
    if srv<>nil then srv.Poll;
    HandleSignals;
    if counter^>=target then break;
    CoreTime.Sleep(5);
  until CoreTime.Ticks>=deadline;
  result:=counter^>=target;
end;

var
  harness:THarness;

begin
  harness:=THarness.Create;
  srv:=TGameServer.Create(PORT,TMemAccounts.Create); // loopback only
  srv.onUserLogin:=harness.OnLogin;
  srv.onUserLogout:=harness.OnLogout;
  srv.onUserMessage:=harness.OnMessage;

  SetEventHandler('NET\Conn3\Connected',OnConnected,emQueued);
  SetEventHandler('NET\Conn3\Logged',OnLogged,emQueued);
  SetEventHandler('Net\Conn3\AccessDenied',OnDenied,emQueued);
  SetEventHandler('NET\Conn3\ConnectionFailed',OnFailed,emQueued);
  SetEventHandler('Net\Conn3\DataReceived',OnData,emQueued);

  // --- authentication ---
  Connect('127.0.0.1:'+IntToStr(PORT),LOGIN,PASSWORD,CLIENTINFO);
  StartTest('login/auth handshake');
  Check(PumpUntil(@cliLoggedCount,1,8000),'client reaches Logged state');
  EndTest;

  StartTest('server registers the authorized user');
  Check((harness.loginCount=1) and (cliUserID>0) and srv.IsOnline(cliUserID) and
        (srv.OnlineCount=1) and (cliDeniedCount=0) and (cliFailedCount=0),
        'one user online, no denial/failure');
  EndTest;

  // --- client -> server message ---
  SendData(['chat','hello world',42]);
  StartTest('client->server message delivery');
  Check(PumpUntil(@harness.msgCount,1,8000),'server receives one message');
  EndTest;

  StartTest('client->server message contents');
  Check((harness.msgF0='chat') and (harness.msgF1='hello world') and (harness.msgF2=42),
        'fields decode byte-compatibly');
  EndTest;

  // --- server -> client message (comet long-poll) ---
  srv.SendToUser(cliUserID,['notify','ping',7]);
  StartTest('server->client message delivery');
  Check(PumpUntil(@cliMsgCount,1,8000),'client receives one message');
  EndTest;

  StartTest('server->client message contents');
  Check((cliF0='notify') and (cliF1='ping') and (cliF2=7),
        'fields decode byte-compatibly');
  EndTest;

  // --- broadcast ---
  srv.Broadcast(['bc','everyone',99]);
  StartTest('server broadcast delivery');
  Check(PumpUntil(@cliMsgCount,2,8000),'client receives the broadcast');
  EndTest;

  StartTest('broadcast contents');
  Check((cliF0='bc') and (cliF1='everyone') and (cliF2=99),'broadcast fields decode');
  EndTest;

  // --- logout ---
  Disconnect;
  StartTest('logout removes the user');
  Check(PumpUntil(@harness.logoutCount,1,8000),'server sees the logout');
  EndTest;

  StartTest('no users online after logout');
  // give RemoveUser a moment (logout handler runs inside Poll)
  PumpUntil(@harness.logoutCount,2,300); // harmless extra pumping
  Check(srv.OnlineCount=0,'online count back to zero');
  EndTest;

  RemoveEventHandler(OnConnected);
  RemoveEventHandler(OnLogged);
  RemoveEventHandler(OnDenied);
  RemoveEventHandler(OnFailed);
  RemoveEventHandler(OnData);
  srv.Free;
  harness.Free;

  if testsFailed>0 then ExitCode:=1;
end.
