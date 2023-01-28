program TestTCP;

{$APPTYPE CONSOLE}
uses
  SysUtils, Apus.Common, Apus.Types, Apus.TCP;

const
 SERVER_PORT = 3456;

type
 // Server-side object created for each connected user
 TUser=class(TTCPServerUser)
  procedure onConnected; override;
  procedure onDisconnected; override;
  procedure onDataReceived(var buf:TBuffer); override;
 end;

 TServer=class(TTCPServer)
  terminated:boolean;
 end;

 TClient=class(TTCPClient)
  hasResponse:boolean;
  procedure onDataReceived(var buf:TBuffer); override;
  procedure onConnect; override;
  procedure onDisconnect; override;
 end;

{ TUser }

procedure TUser.onConnected;
begin
  writeln('Client connected: ',IpToStr(remoteIP),':',remotePort);
end;

procedure TUser.onDisconnected;
begin
  Writeln('Client disconnected: ',IpToStr(remoteIP),':',remotePort);
end;

// Process received data
procedure TUser.onDataReceived(var buf:TBuffer);
var
 b:byte;
 i,s:integer;
 data:array[0..255] of byte;
begin
 b:=buf.ReadByte; // payload size
 if buf.BytesLeft<b then begin
   // Not enough data available
   buf.Skip(-1); // return back
   exit;
 end;
 writeln('Request received - ',b,' bytes');
 ASSERT(b<length(data)); // always true
 buf.read(data,b);
 // Calc sum of bytes
 s:=0;
 for i:=0 to b-1 do
  inc(s,data[i]);
 // Send it as response
 SendData(TBuffer.CreateFrom(s,4));
end;

// MAIN CODE -----------------

procedure RunServer;
 var
  server:TServer;
 begin
  server:=TServer.Create(SERVER_PORT,TUser);
  writeln('Server started');
  repeat
   server.Poll;
   Sleep(1);
  until server.terminated;
  server.Free;
  writeln('Server finished');
 end;

procedure RunClient;
 var
  client:TClient;
  n:integer;
  buf:TWriteBuffer;
 begin
  client:=TClient.Create;
  Writeln('Connecting to server...');
  client.Connect('localhost:'+inttostr(SERVER_PORT),3000);
  if not client.connected then begin
    writeln('Failed to connect! Press Enter to exit.');
    readln;
    halt;
  end;
  repeat
   write('Enter n (0 - exit): ');
   readln(n);
   if n=0 then break;
   n:=Clamp(n,0,255);
   if not client.connected then break;
   // Send data
   buf.Init(n+1);
   buf.WriteByte(n);
   while n>0 do begin
     buf.WriteByte(n);
     dec(n);
   end;
   client.SendData(buf.AsBuffer);
   client.hasResponse:=false;
   // Read response
   repeat
     client.Poll;
   until client.hasResponse;
  until false;
 end;

{ TClient }

procedure TClient.onDataReceived(var buf:TBuffer);
var
  v:integer;
begin
  if buf.size<4 then exit;
  v:=buf.ReadInt;
  writeln('Response received: ',v);
  hasResponse:=true;
end;

procedure TClient.onConnect;
begin
  Writeln('Connected');
end;

procedure TClient.onDisconnect;
begin
  Writeln('Disconnected');
end;

begin
  try
    if ParamCount=0 then begin
      writeln('Usage:');
      writeln('  TestTCP server  -- run as server');
      writeln('  TestTCP client  -- run as client');
    end;
    if HasParam('server') then RunServer;
    if HasParam('client') then RunClient;
  except
    on E: Exception do
      Writeln('Error: '+ExceptionMsg(e));
  end;
end.
