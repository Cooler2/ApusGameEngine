program TestFillD_Debug;

{$APPTYPE CONSOLE}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  SysUtils,
  Apus.Core;

procedure TestDynamicArray;
var
  buf: array of Cardinal;
  i: Integer;
begin
  Writeln('Testing with dynamic array...');
  
  SetLength(buf, 10);
  Writeln('Array length: ', Length(buf));
  Writeln('Array addr: ', UIntPtr(@buf[0]));
  
  Mem.FillD(buf[0], 10, $12345678);
  
  for i := 0 to 9 do
    Writeln('  buf[', i, '] = $', IntToHex(buf[i], 8));
    
  Writeln('Test passed.');
end;

procedure TestStaticArray;
var
  buf: array[0..9] of Cardinal;
  i: Integer;
begin
  Writeln('Testing with static array...');
  
  Mem.FillD(buf, 10, $87654321);
  
  for i := 0 to 9 do
    Writeln('  buf[', i, '] = $', IntToHex(buf[i], 8));
    
  Writeln('Test passed.');
end;

begin
  try
    Writeln('Debug Mem.FillD');
    Writeln('CPU SSE: ', cpuFeatures.SSE);
    Writeln;
    
    TestStaticArray;
    Writeln;
    
    TestDynamicArray;
    
    Writeln('All debug tests completed.');
  except
    on E: Exception do
      Writeln('Error: ', E.ClassName, ': ', E.Message);
  end;
  
  Writeln('Press Enter to exit...');
  Readln;
end.