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

const
  HOLD_MS=10000; // send latency: the network thread must not touch the inspected queue

procedure TestSmallMessagesSharePacket;
var
  con:TTestConnection;
  info:TPacketInfo;
  a,b:array[0..2] of byte;
begin
  StartTest('UdpTransport small message packing');
  NetInit(0);
  con:=TTestConnection.Create;
  try
    con.MarkConnected;
    a[0]:=1;
    a[1]:=2;
    a[2]:=3;
    b[0]:=4;
    b[1]:=5;
    b[2]:=6;
    con.SendData(@a[0],Length(a),HOLD_MS);
    con.SendData(@b[0],Length(b),HOLD_MS);
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
    NetDone;
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

  NetInit(0);
  con:=TTestConnection.Create;
  try
    con.MarkConnected;
    con.SendData(@payload[0],Length(payload),HOLD_MS);
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
    NetDone;
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

// from=nil - the main peer socket
procedure PeerSend(sid:cardinal;pnum:word;cmd:byte;payload:PByte;size:integer;from:UDPSocket2=nil);
var
  buf:array[0..1499] of byte;
begin
  if from=nil then from:=peer;
  FillChar(buf,8,0);
  Move(sid,buf[0],4);
  Move(pnum,buf[4],2);
  buf[6]:=cmd;
  if size>0 then Move(payload^,buf[8],size);
  from.Send(LOCALHOST,netPort,buf,8+size);
end;

// Wait for a packet with the given command from the transport, return its size (0 - timeout)
function PeerWait(cmd:byte;var buf:array of byte;from:UDPSocket2=nil):integer;
var
  deadline:int64;
  adr:cardinal;
  port:word;
  size:integer;
begin
  result:=0;
  if from=nil then from:=peer;
  deadline:=Time.Ticks+WAIT_MS;
  repeat
    size:=Length(buf);
    if from.Receive(adr,port,buf[0],size) then begin
      if (size>=8) and (buf[6]=cmd) then exit(size);
    end else
      Time.Sleep(5);
  until Time.Ticks>deadline;
end;

// Connect the peer to an accepting connection, return the connection's session ID (0 - failed)
function PeerConnect(peerSID:cardinal;from:UDPSocket2=nil):cardinal;
var
  buf:array[0..1499] of byte;
  attempt:integer;
begin
  result:=0;
  for attempt:=1 to 10 do begin // a lost datagram is repeated, as a real client would do
    PeerSend(peerSID,0,CMD_REQUEST,nil,0,from);
    if PeerWait(CMD_ACCEPT,buf,from)=12 then begin
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

// Strict bind, readiness on return, unbalanced and immediate stop
procedure TestLifecycle;
var
  holder,probe:UDPSocket2;
  con:TConnection;
  port:word;
  failed:boolean;
  i,cnt:integer;
begin
  StartTest('UdpTransport lifecycle');
  NetDone; // without NetInit: ignored
  NetDone;
  cnt:=conCnt;
  failed:=false;
  try
    TConnection.Create.Free;
  except
    on e:EError do failed:=true;
  end;
  Check(failed and (conCnt=cnt),'a connection can''t be created without NetInit');

  // a busy port is an error, not a silent move to another port
  port:=20000+Random(20000);
  holder:=UDPSocket2.Create(port,false);
  try
    failed:=false;
    try
      NetInit(port);
    except
      on e:EError do failed:=true;
    end;
    Check(failed,'NetInit fails on a busy port');
    probe:=nil;
    try
      probe:=UDPSocket2.Create(port+100,false);
    except
    end;
    Check(probe<>nil,'no fallback socket is opened on port+100');
    probe.Free;
    failed:=false;
    try
      TConnection.Create.Free;
    except
      on e:EError do failed:=true;
    end;
    Check(failed,'the transport stays uninitialized after a failed NetInit');
  finally
    holder.Free;
  end;

  // the socket is bound on return from NetInit and released on return from NetDone
  for i:=1 to 20 do begin
    NetInit(port);
    NetDone;
  end;
  probe:=nil;
  try
    probe:=UDPSocket2.Create(port,false);
  except
  end;
  Check(probe<>nil,'repeated start/stop releases the port');
  probe.Free;

  // nested calls
  NetInit(port);
  NetInit(port+1);
  NetDone;
  con:=nil;
  try
    con:=TConnection.Create;
  except
  end;
  Check(con<>nil,'nested NetDone keeps the transport running');
  con.Free;
  NetDone;
  NetDone; // extra call: ignored
  EndTest;
end;

// Session IDs don't use the application RNG; peers with the same session ID are told apart by address
procedure TestSessionIdentity;
var
  conA,conB,first,second:TConnection;
  peer2:UDPSocket2;
  r1,r2:integer;
  sidA,sidB:cardinal;
begin
  StartTest('UdpTransport session identity');
  netPort:=20000+Random(20000);
  peerPort:=netPort+1;
  tagClosed:=0;
  SetEventHandler('NET\Conn\ConnectionClosed',OnClosed);
  peer:=UDPSocket2.Create(peerPort,false);
  peer2:=UDPSocket2.Create(peerPort+1,false);
  NetInit(netPort);
  conA:=nil; conB:=nil;
  try
    RandSeed:=12345;
    r1:=Random(MaxInt);
    RandSeed:=12345;
    conA:=TConnection.Create(true);
    conB:=TConnection.Create(true);
    r2:=Random(MaxInt);
    Check(r1=r2,'session IDs don''t touch the application RNG');

    sidA:=PeerConnect($5555AAAA);
    sidB:=PeerConnect($5555AAAA,peer2);
    Check((sidA<>0) and (sidB<>0) and (sidA<>sidB),'same session ID from another address gets its own connection');
    Check(PeerConnect($5555AAAA)=sidA,'repeated request from the same address is confirmed again');
    // either acceptor may take the first request
    if conA.sessID=sidA then begin
      first:=conA; second:=conB;
    end else begin
      first:=conB; second:=conA;
    end;
    Check((first.sessID=sidA) and (second.sessID=sidB) and
      (first.remPort=peerPort) and (second.remPort=peerPort+1),'connections keep their addresses');

    PeerSend(sidB,0,CMD_CLOSE,nil,0,peer2);
    Check(WaitTag(tagClosed) and (tagClosed=TTag(UIntPtr(second))),'second connection closed');
    Check(first.connected and not second.connected,'closing one connection keeps the other');
  finally
    conA.Free;
    conB.Free;
    NetDone;
    peer2.Free;
    FreeAndNil(peer);
    RemoveEventHandler(OnClosed);
    tagClosed:=0;
  end;
  EndTest;
end;

begin
  writeln('=== TestUdpTransport ===');
  Randomize;
  TestLifecycle;
  TestSessionIdentity;
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
