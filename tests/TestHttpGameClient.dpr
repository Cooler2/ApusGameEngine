{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestHttpGameClient;

uses
  SysUtils,
  Apus.Core,
  Apus.Engine.HttpGameClient;

{$I ..\Base\tests\Test.inc}

procedure TestNetMessageCursor;
var
  msg:TNetMessage;
begin
  StartTest('HttpGameClient.TNetMessage cursor');
  SetLength(msg.values,3);
  msg.values[0]:='42';
  msg.values[1]:='hello';
  msg.values[2]:='bad-int';
  msg.index:=0;

  Check(not msg.Empty,'message starts non-empty');
  Check(msg.NextInt=42,'NextInt parses integer field');
  Check(msg.NextStr='hello','NextStr returns string field');
  Check(msg.NextInt=-1,'NextInt returns -1 for invalid integer field');
  Check(msg.Empty,'message is empty after all fields');
  Check(msg.NextStr='','NextStr past end returns empty string');
  EndTest;
end;

procedure TestNetMessageIndexedAccess;
var
  msg:TNetMessage;
begin
  StartTest('HttpGameClient.TNetMessage indexed access');
  SetLength(msg.values,3);
  msg.values[0]:='7';
  msg.values[1]:='bad-int';
  msg.values[2]:='-5';
  msg.index:=0;

  Check(msg.Int(0)=7,'Int(0) parses first field');
  Check(msg.Int(1)=0,'Int returns 0 for invalid integer field');
  Check(msg.Int(2)=-5,'Int parses negative integer field');
  Check(msg.Int(-1)=0,'Int returns 0 before first field');
  Check(msg.Int(3)=0,'Int returns 0 past last field');
  Check(msg.index=0,'Int does not move cursor');
  EndTest;
end;

procedure TestInitialConnectionState;
begin
  StartTest('HttpGameClient initial state');
  Check(not Connected,'client is not connected before Connect');
  EndTest;
end;

begin
  TestNetMessageCursor;
  TestNetMessageIndexedAccess;
  TestInitialConnectionState;
  if testsFailed>0 then ExitCode:=1;
end.
