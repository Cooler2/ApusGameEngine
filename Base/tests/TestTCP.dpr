{$APPTYPE CONSOLE}
program TestTCP;
uses
  SysUtils,
  Classes,
  Apus.Core,
  Apus.Types,
  Apus.TCP;

{$INCLUDE Test.inc}

const
  SERVER_PORT=35432;
  CLIENT_COUNT=3;
  MSG_PER_CLIENT=200;

type
  TTestServerUser=class(TTCPServerUser)
    procedure onDataReceived(var buf:TBuffer); override;
  end;

  TServerThread=class(TThread)
    ready:boolean;
    failed:boolean;
    errMsg:string;
    stopRequested:boolean;
    constructor Create;
    procedure Execute; override;
  end;

  TTestClient=class(TTCPClient)
    expectedClient:integer;
    receivedCount:integer;
    invalidPayload:boolean;
    procedure onDataReceived(var buf:TBuffer); override;
  end;

  TClientThread=class(TThread)
    idx:integer;
    passed:boolean;
    failMsg:string;
    constructor Create(clientIndex:integer);
    procedure Execute; override;
  end;

procedure TTestServerUser.onDataReceived(var buf:TBuffer);
var
  wb:TWriteBuffer;
  v:integer;
begin
  while buf.BytesLeft>=4 do begin
    v:=buf.ReadInt;
    wb.Init(4);
    wb.WriteInt(v);
    SendData(wb.AsBuffer);
  end;
end;

constructor TServerThread.Create;
begin
  inherited Create(false);
  FreeOnTerminate:=false;
end;

procedure TServerThread.Execute;
var
  server:TTCPServer;
begin
  try
    server:=TTCPServer.Create(SERVER_PORT,TTestServerUser);
    ready:=true;
    try
      while not stopRequested do begin
        server.Poll;
        Sleep(1);
      end;
    finally
      server.Free;
    end;
  except
    on e:Exception do begin
      failed:=true;
      errMsg:=e.Message;
      ready:=true;
    end;
  end;
end;

procedure TTestClient.onDataReceived(var buf:TBuffer);
var
  v,clientId,seq:integer;
begin
  while buf.BytesLeft>=4 do begin
    v:=buf.ReadInt;
    clientId:=(v shr 24) and $FF;
    seq:=v and $00FFFFFF;
    if clientId<>expectedClient then
      invalidPayload:=true;
    if (seq<1) or (seq>MSG_PER_CLIENT) then
      invalidPayload:=true;
    inc(receivedCount);
  end;
end;

constructor TClientThread.Create(clientIndex:integer);
begin
  inherited Create(false);
  FreeOnTerminate:=false;
  idx:=clientIndex;
end;

procedure TClientThread.Execute;
var
  client:TTestClient;
  wb:TWriteBuffer;
  i:integer;
  deadline:int64;
begin
  try
    client:=TTestClient.Create;
    try
      client.expectedClient:=idx;
      client.Connect('127.0.0.1:'+IntToStr(SERVER_PORT),2000);
      if not client.connected then begin
        failMsg:='connect failed';
        exit;
      end;

      for i:=1 to MSG_PER_CLIENT do begin
        wb.Init(4);
        wb.WriteInt((idx shl 24) or i);
        client.SendData(wb.AsBuffer);
      end;

      deadline:=CoreTime.Ticks+5000;
      while client.receivedCount<MSG_PER_CLIENT do begin
        client.Poll;
        if not client.connected then begin
          failMsg:='unexpected disconnect';
          exit;
        end;
        if CoreTime.Ticks>=deadline then begin
          failMsg:='timeout waiting echoes';
          exit;
        end;
        Sleep(1);
      end;

      if client.invalidPayload then begin
        failMsg:='invalid echoed payload';
        exit;
      end;
      passed:=true;
    finally
      client.Disconnect;
      client.Free;
    end;
  except
    on e:Exception do
      failMsg:='thread exception: '+e.Message;
  end;
end;

procedure TestMultiThreadEcho;
var
  server:TServerThread;
  clients:array[0..CLIENT_COUNT-1] of TClientThread;
  i:integer;
  waitDeadline:int64;
begin
  StartTest('TCP multi-thread echo');
  FillChar(clients,SizeOf(clients),0);
  server:=TServerThread.Create;
  try
    waitDeadline:=CoreTime.Ticks+3000;
    while (not server.ready) and (CoreTime.Ticks<waitDeadline) do
      Sleep(1);

    Check(server.ready,'server not ready');
    Check(not server.failed,'server start failed: '+server.errMsg);

    if server.ready and (not server.failed) then begin
      for i:=0 to High(clients) do
        clients[i]:=TClientThread.Create(i+1);
      for i:=0 to High(clients) do
        if clients[i]<>nil then
          clients[i].WaitFor;
      for i:=0 to High(clients) do
        if clients[i]<>nil then begin
          Check(clients[i].passed,'client '+IntToStr(i+1)+' failed: '+clients[i].failMsg);
          clients[i].Free;
          clients[i]:=nil;
        end;
    end;
  finally
    server.stopRequested:=true;
    server.WaitFor;
    Check(not server.failed,'server runtime error: '+server.errMsg);
    server.Free;
    for i:=0 to High(clients) do
      if clients[i]<>nil then
        clients[i].Free;
  end;
  EndTest;
end;

begin
  writeln('=== TCP Tests ===');
  writeln;
  try
    TestMultiThreadEcho;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',e.Message);
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.