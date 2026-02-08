program TestFillD;

{$APPTYPE CONSOLE}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  SysUtils,
  Apus.Core;

procedure TestBasic;
var
  buf: array[0..63] of Cardinal;
  i: Integer;
begin
  Write('Testing basic FillD... ');
  Mem.FillD(buf, Length(buf), $12345678);
  for i := 0 to High(buf) do
    if buf[i] <> $12345678 then
    begin
      Writeln('FAIL at index ', i, ': expected $12345678, got $', IntToHex(buf[i], 8));
      Exit;
    end;
  Writeln('OK');
end;

procedure TestSmallCounts;
var
  buf: array[0..7] of Cardinal;
  i, j: Integer;
begin
  Write('Testing small counts (1..8)... ');
  for i := 1 to 8 do
  begin
    FillChar(buf, SizeOf(buf), $FF);
    Mem.FillD(buf, i, $87654321);
    
    // Check filled part
    for j := 0 to i-1 do
      if buf[j] <> $87654321 then
      begin
        Writeln('FAIL: count=', i, ' index=', j, ' expected $87654321, got $', IntToHex(buf[j], 8));
        Exit;
      end;
    
    // Check untouched part (should remain $FFFFFFFF)
    for j := i to High(buf) do
      if buf[j] <> $FFFFFFFF then
      begin
        Writeln('FAIL: count=', i, ' index=', j, ' should remain $FFFFFFFF, got $', IntToHex(buf[j], 8));
        Exit;
      end;
  end;
  Writeln('OK');
end;

procedure TestUnaligned;
var
  buf: array[0..31] of Byte;
  p: PCardinal;
  i: Integer;
begin
  Write('Testing unaligned memory... ');
  FillChar(buf, SizeOf(buf), $00);
  
  // Start from unaligned address (buf+1)
  p := PCardinal(@buf[1]);
  Mem.FillD(p^, 7, $AABBCCDD);
  
  // Check results
  for i := 0 to 6 do
    if PCardinal(@buf[1 + i*4])^ <> $AABBCCDD then
    begin
      Writeln('FAIL at offset ', i, ': expected $AABBCCDD, got $', 
        IntToHex(PCardinal(@buf[1 + i*4])^, 8));
      Exit;
    end;
    
  // Check that bytes before and after are untouched
  if buf[0] <> $00 then
    Writeln('FAIL: byte before overwritten');
  if buf[29] <> $00 then
    Writeln('FAIL: byte after overwritten');
    
  Writeln('OK');
end;

procedure TestLargeBuffer;
const
  SIZE = 10000;
var
  buf: array of Cardinal;
  i: Integer;
begin
  Write('Testing large buffer (', SIZE, ' elements)... ');
  SetLength(buf, SIZE);
  
  Mem.FillD(buf[0], Length(buf), $DEADBEEF);
  
  for i := 0 to High(buf) do
    if buf[i] <> $DEADBEEF then
    begin
      Writeln('FAIL at index ', i, ': expected $DEADBEEF, got $', IntToHex(buf[i], 8));
      Exit;
    end;
    
  Writeln('OK');
end;

begin
  try
    Writeln('Testing Mem.FillD implementation');
    Writeln('CPU Features: SSE=', cpuFeatures.SSE, ' MMX=', cpuFeatures.MMX);
    Writeln;
    
    TestBasic;
    TestSmallCounts;
    TestUnaligned;
    TestLargeBuffer;
    
    Writeln;
    Writeln('All tests passed!');
  except
    on E: Exception do
      Writeln('Error: ', E.ClassName, ': ', E.Message);
  end;
  
  Writeln('Press Enter to exit...');
  Readln;
end.