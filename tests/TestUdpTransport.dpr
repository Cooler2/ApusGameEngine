{$APPTYPE CONSOLE}
program TestUdpTransport;

uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.EventMan,
  Apus.Network,
  Apus.Engine.UdpTransport;

{$I ..\Base\tests\Test.inc}

type
  TPacketInfo=record
    count:integer;
    firstSize:integer;
    secondSize:integer;
    firstNum:word;
    secondNum:word;
    firstData:array of byte;
    secondData:array of byte;
  end;

  TTestConnection=class(TConnection)
    procedure MarkConnected;
    procedure SnapshotPackets(var info:TPacketInfo);
  end;

procedure TTestConnection.MarkConnected;
begin
  connected:=true;
end;

procedure TTestConnection.SnapshotPackets(var info:TPacketInfo);
var
  p:TDataPacket;
begin
  info.count:=0;
  info.firstSize:=0;
  info.secondSize:=0;
  info.firstNum:=0;
  info.secondNum:=0;
  SetLength(info.firstData,0);
  SetLength(info.secondData,0);
  p:=firstSend;
  while p<>nil do begin
    inc(info.count);
    if info.count=1 then begin
      info.firstSize:=Length(p.data);
      info.firstNum:=p.num;
      SetLength(info.firstData,Length(p.data));
      if Length(p.data)>0 then
        Move(p.data[0],info.firstData[0],Length(p.data));
    end else
    if info.count=2 then begin
      info.secondSize:=Length(p.data);
      info.secondNum:=p.num;
      SetLength(info.secondData,Length(p.data));
      if Length(p.data)>0 then
        Move(p.data[0],info.secondData[0],Length(p.data));
    end;
    p:=p.next;
  end;
end;

function ReadIntLE(const data:array of byte; offset:integer):integer;
begin
  result:=0;
  if offset+SizeOf(result)<=Length(data) then
    Move(data[offset],result,SizeOf(result));
end;

procedure TestSmallMessagesSharePacket;
var
  con:TTestConnection;
  info:TPacketInfo;
  a,b:array[0..2] of byte;
begin
  StartTest('UdpTransport small message packing');
  con:=TTestConnection.Create;
  try
    con.MarkConnected;
    a[0]:=1;
    a[1]:=2;
    a[2]:=3;
    b[0]:=4;
    b[1]:=5;
    b[2]:=6;
    con.SendData(@a[0],Length(a),0);
    con.SendData(@b[0],Length(b),0);
    con.SnapshotPackets(info);

    Check(info.count=1,'small messages should share one packet');
    Check(info.firstSize=14,'packet size should include two length headers');
    Check(ReadIntLE(info.firstData,0)=3,'first message length');
    Check((Length(info.firstData)>6) and (info.firstData[4]=1) and
      (info.firstData[5]=2) and (info.firstData[6]=3),'first payload bytes');
    Check(ReadIntLE(info.firstData,7)=3,'second message length');
    Check((Length(info.firstData)>13) and (info.firstData[11]=4) and
      (info.firstData[12]=5) and (info.firstData[13]=6),'second payload bytes');
  finally
    con.Free;
  end;
  EndTest;
end;

procedure TestLargeMessageSplitsPackets;
var
  con:TTestConnection;
  info:TPacketInfo;
  payload:array of byte;
  i:integer;
begin
  StartTest('UdpTransport large message split');
  SetLength(payload,MAX_PACKET+20);
  for i:=0 to High(payload) do
    payload[i]:=byte(i and $FF);

  con:=TTestConnection.Create;
  try
    con.MarkConnected;
    con.SendData(@payload[0],Length(payload),0);
    con.SnapshotPackets(info);

    Check(info.count=2,'large message should split into two packets');
    Check(info.firstSize=MAX_PACKET,'first packet should be capped at MAX_PACKET');
    Check(info.secondSize=24,'second packet should contain remaining bytes');
    Check(ReadIntLE(info.firstData,0)=Length(payload),'first packet stores full message length');
    Check((Length(info.firstData)>5) and (info.firstData[4]=0) and
      (info.firstData[5]=1),'first payload bytes');
    Check((Length(info.secondData)>1) and (info.secondData[0]=byte((MAX_PACKET-4) and $FF)) and
      (info.secondData[1]=byte((MAX_PACKET-3) and $FF)),'continuation payload bytes');
    Check(info.secondNum=word(info.firstNum+1),'split packets use sequential numbers');
  finally
    con.Free;
  end;
  EndTest;
end;

{ Receive path: a hand-written wire peer talks to the transport over loopback }

const
  LOCALHOST=$0100007F; // 127.0.0.1 in network byte order
  WAIT_MS=3000;
  // wire commands
  CMD_REQUEST=1;
  CMD_ACCEPT=2;
  CMD_REJECT=3;
  CMD_CLOSE=4;
  CMD_DATA=5;

type
  // Connection object placed above 4 GB where the platform allows it: object addresses
  // must survive the trip through event tags and message handles
  THighConnection=class(TConnection)
    class function NewInstance:TObject; override;
    procedure FreeInstance; override;
  end;

var
  peer:UDPSocket2;
  netPort,peerPort:word;
  // filled by event handlers in the network thread
  tagConnected,tagRejected,tagClosed,tagUserMsg:TTag;
  userMsgCalls,userMsgSize:integer;
  userMsgCon:TConnection;

class function THighConnection.NewInstance:TObject;
{$IFDEF MSWINDOWS}
const
  MEM_TOP_DOWN_FLAG=$100000;
var
  p:pointer;
begin
  p:=VirtualAlloc(nil,InstanceSize,MEM_COMMIT or MEM_RESERVE or MEM_TOP_DOWN_FLAG,PAGE_READWRITE);
  result:=InitInstance(p);
end;
{$ELSE}
begin
  result:=inherited NewInstance; // the heap is already above 4 GB on 64-bit Linux and macOS
end;
{$ENDIF}

procedure THighConnection.FreeInstance;
begin
  {$IFDEF MSWINDOWS}
  CleanupInstance;
  VirtualFree(self,0,MEM_RELEASE);
  {$ELSE}
  inherited;
  {$ENDIF}
end;

procedure OnConnected(event:TEventStr;tag:TTag);
begin
  tagConnected:=tag;
end;

procedure OnRejected(event:TEventStr;tag:TTag);
begin
  tagRejected:=tag;
end;

procedure OnClosed(event:TEventStr;tag:TTag);
begin
  tagClosed:=tag;
end;

procedure OnUserMsgSignal(event:TEventStr;tag:TTag);
begin
  tagUserMsg:=tag;
end;

// Direct route handler that disposes of the connection on the first message
procedure OnUserMsgFree(con:TConnection;buf:pointer;size:integer;ip:cardinal;port:word);
begin
  inc(userMsgCalls);
  userMsgCon:=con;
  userMsgSize:=size;
  con.Free;
end;

function WaitTag(var tag:TTag):boolean;
var
  deadline:int64;
begin
  deadline:=Time.Ticks+WAIT_MS;
  while (tag=0) and (Time.Ticks<deadline) do Time.Sleep(5);
  result:=tag<>0;
end;

procedure PeerSend(sid:cardinal;pnum:word;cmd:byte;payload:PByte;size:integer);
var
  buf:array[0..1499] of byte;
begin
  FillChar(buf,8,0);
  Move(sid,buf[0],4);
  Move(pnum,buf[4],2);
  buf[6]:=cmd;
  if size>0 then Move(payload^,buf[8],size);
  peer.Send(LOCALHOST,netPort,buf,8+size);
end;

// Wait for a packet with the given command from the transport, return its size (0 - timeout)
function PeerWait(cmd:byte;var buf:array of byte):integer;
var
  deadline:int64;
  adr:cardinal;
  port:word;
  size:integer;
begin
  result:=0;
  deadline:=Time.Ticks+WAIT_MS;
  repeat
    size:=Length(buf);
    if peer.Receive(adr,port,buf[0],size) then begin
      if (size>=8) and (buf[6]=cmd) then exit(size);
    end else
      Time.Sleep(5);
  until Time.Ticks>deadline;
end;

// Connect the peer to an accepting connection, return the connection's session ID (0 - failed)
function PeerConnect(peerSID:cardinal):cardinal;
var
  buf:array[0..1499] of byte;
  attempt:integer;
begin
  result:=0;
  for attempt:=1 to 10 do begin // the transport socket may not be bound yet
    PeerSend(peerSID,0,CMD_REQUEST,nil,0);
    if PeerWait(CMD_ACCEPT,buf)=12 then begin
      Move(buf[8],result,4);
      exit;
    end;
  end;
end;

procedure TestReceivePath;
var
  conA,conB,conC:TConnection;
  sid:cardinal;
  stream:array of byte;
  msg:array[0..15] of byte;
  buf:array[0..1499] of byte;
  data:pointer;
  size,i:integer;
  same:boolean;
  ip:cardinal;
  port:word;
begin
  StartTest('UdpTransport receive path');
  Randomize;
  netPort:=20000+Random(20000);
  peerPort:=netPort+1;
  SetEventHandler('NET\Conn\Connected',OnConnected);
  SetEventHandler('NET\Conn\ConnectionRejected',OnRejected);
  SetEventHandler('NET\Conn\ConnectionClosed',OnClosed);
  SetEventHandler('NET\Conn\UserMsg',OnUserMsgSignal);
  peer:=UDPSocket2.Create(peerPort,false);
  NetInit(netPort);
  conA:=nil; conC:=nil;
  try
    // Accept: the event tag is the connection object
    conA:=THighConnection.Create(true);
    {$IFDEF CPU64}
    Check(UIntPtr(conA)>$FFFFFFFF,'connection object lies above 4 GB');
    {$ENDIF}
    sid:=PeerConnect($1234567);
    Check(sid=conA.sessID,'acceptance carries the session ID');
    Check(WaitTag(tagConnected) and (tagConnected=TTag(UIntPtr(conA))),'Connected tag is the connection');

    // A message fragmented over two packets: the UserMsg tag is a message handle
    SetLength(stream,4+2000);
    size:=2000;
    Move(size,stream[0],4);
    for i:=4 to High(stream) do stream[i]:=byte(i*7);
    PeerSend(sid,1,CMD_DATA,@stream[0],MAX_PACKET);
    PeerSend(sid,2,CMD_DATA,@stream[MAX_PACKET],Length(stream)-MAX_PACKET);
    Check(WaitTag(tagUserMsg),'UserMsg signal');
    size:=GetMsg(tagUserMsg,data);
    same:=size=2000;
    if same then
      for i:=0 to size-1 do
        if PByte(PByte(data)+i)^<>stream[i+4] then same:=false;
    Check(same,'GetMsg returns the reassembled message');
    GetMsgOrigin(tagUserMsg,ip,port);
    Check((ip=LOCALHOST) and (port=peerPort),'GetMsgOrigin returns the peer address');

    // Remote close
    PeerSend(sid,0,CMD_CLOSE,nil,0);
    Check(WaitTag(tagClosed) and (tagClosed=TTag(UIntPtr(conA))),'ConnectionClosed tag is the connection');

    // Direct route: the handler frees the connection on the first of two messages in one packet
    conB:=THighConnection.Create(true);
    sid:=PeerConnect($2345678);
    Check(sid=conB.sessID,'second connection accepted');
    onUserMsg:=OnUserMsgFree;
    try
      size:=3;
      Move(size,msg[0],4);
      msg[4]:=1; msg[5]:=2; msg[6]:=3;
      Move(msg[0],msg[7],7);
      PeerSend(sid,1,CMD_DATA,@msg[0],14);
      i:=0;
      while (userMsgCalls=0) and (i<WAIT_MS) do begin
        Time.Sleep(5); inc(i,5);
      end;
      Time.Sleep(100); // let the second message be dispatched
      Check((userMsgCalls=1) and (userMsgCon=conB) and (userMsgSize=3),
        'messages of a connection freed by the handler are dropped');
    finally
      onUserMsg:=nil;
    end;

    // Rejection of an outgoing connection
    conC:=THighConnection.Create;
    conC.Connect(LOCALHOST,peerPort);
    Check(PeerWait(CMD_REQUEST,buf)>=8,'connection request sent');
    Move(buf[0],sid,4);
    PeerSend(sid,0,CMD_REJECT,nil,0);
    Check(WaitTag(tagRejected) and (tagRejected=TTag(UIntPtr(conC))),'ConnectionRejected tag is the connection');
  finally
    conA.Free;
    conC.Free;
    NetDone;
    peer.Free;
  end;
  EndTest;
end;

begin
  writeln('=== TestUdpTransport ===');
  TestSmallMessagesSharePacket;
  TestLargeMessageSplitsPackets;
  TestReceivePath;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
