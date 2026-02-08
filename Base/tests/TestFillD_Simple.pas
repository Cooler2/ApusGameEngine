program TestFillD_Simple;

{$APPTYPE CONSOLE}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  SysUtils,
  Apus.Core;

procedure Test1;
var
  buf: array[0..3] of Cardinal;
  i: Integer;
begin
  Writeln('Test 1: 4 elements');
  Mem.FillD(buf, 4, $12345678);
  for i := 0 to 3 do
    Writeln('  buf[', i, '] = $', IntToHex(buf[i], 8));
end;

procedure Test2;
var
  buf: array[0..7] of Cardinal;
  i: Integer;
begin
  Writeln('Test 2: 8 elements (aligned)');
  Mem.FillD(buf, 8, $87654321);
  for i := 0 to 7 do
    Writeln('  buf[', i, '] = $', IntToHex(buf[i], 8));
end;

procedure Test3;
var
  buf: array[0..2] of Cardinal;
  i: Integer;
begin
  Writeln('Test 3: 3 elements (less than 4)');
  Mem.FillD(buf, 3, $AABBCCDD);
  for i := 0 to 2 do
    Writeln('  buf[', i, '] = $', IntToHex(buf[i], 8));
end;

begin
  try
    Writeln('Testing Mem.FillD (simple tests)');
    Writeln('CPU Features: SSE=', cpuFeatures.SSE);
    Writeln;
    
    Test1;
    Test2;
    Test3;
    
    Writeln('Done.');
  except
    on E: Exception do
      Writeln('Error: ', E.ClassName, ': ', E.Message);
  end;
  
  Writeln('Press Enter to exit...');
  Readln;
end.