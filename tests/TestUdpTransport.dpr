{$APPTYPE CONSOLE}
program TestUdpTransport;

uses
  SysUtils,
  Apus.Core,
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

begin
  writeln('=== TestUdpTransport ===');
  TestSmallMessagesSharePacket;
  TestLargeMessageSplitsPackets;
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
