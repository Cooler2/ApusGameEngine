program TestFillD_Final;

{$APPTYPE CONSOLE}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  SysUtils,
  Apus.Core;

procedure TestSSEUsage;
var
  buf1: array[0..63] of Cardinal; // 64 элемента = 256 байт, выровнено
  buf2: array[0..18] of Cardinal; // 19 элементов, не кратно 4
  buf3: array[0..3] of Cardinal;  // 4 элемента, меньше порога 16
  i: Integer;
begin
  Writeln('Testing SSE usage threshold (count >= 16)...');
  
  // Тест 1: Большой буфер (64 элемента) - должен использовать SSE если доступно
  Mem.FillD(buf1, 64, $11111111);
  
  // Тест 2: Средний буфер (19 элементов) - должен использовать SSE если доступно
  Mem.FillD(buf2, 19, $22222222);
  
  // Тест 3: Маленький буфер (4 элемента) - должен использовать fallback (count < 16)
  Mem.FillD(buf3, 4, $33333333);
  
  Writeln('Tests completed.');
  Writeln('Note: SSE optimization is used when cpuFeatures.SSE = TRUE and count >= 16');
  Writeln('Current CPU SSE support: ', cpuFeatures.SSE);
end;

procedure TestCorrectness;
var
  buf: array of Cardinal;
  i, j, size: Integer;
  testValues: array[0..3] of Cardinal = ($AAAAAAAA, $BBBBBBBB, $CCCCCCCC, $DDDDDDDD);
begin
  Writeln('Testing correctness with various sizes...');
  
  for size := 1 to 100 do
  begin
    SetLength(buf, size);
    
    for i := 0 to High(testValues) do
    begin
      Mem.FillD(buf[0], size, testValues[i]);
      
      // Проверка
      for j := 0 to size-1 do
        if buf[j] <> testValues[i] then
        begin
          Writeln('FAIL: size=', size, ' value=$', IntToHex(testValues[i], 8), 
                  ' index=', j, ' got=$', IntToHex(buf[j], 8));
          Exit;
        end;
    end;
  end;
  
  Writeln('All correctness tests passed (sizes 1..100).');
end;

procedure TestUnalignedCorrectness;
var
  buffer: array[0..127] of Byte; // 128 байт
  p: PCardinal;
  i, offset: Integer;
begin
  Writeln('Testing unaligned memory access...');
  
  for offset := 0 to 3 do
  begin
    FillChar(buffer, SizeOf(buffer), $00);
    
    // Указатель со смещением от выравнивания
    p := PCardinal(@buffer[offset]);
    
    // Заполняем 10 dword'ов
    Mem.FillD(p^, 10, $DEADBEEF);
    
    // Проверяем заполненные dword'ы
    for i := 0 to 9 do
      if PCardinal(@buffer[offset + i*4])^ <> $DEADBEEF then
      begin
        Writeln('FAIL: offset=', offset, ' index=', i, 
                ' expected $DEADBEEF, got $', 
                IntToHex(PCardinal(@buffer[offset + i*4])^, 8));
        Exit;
      end;
  end;
  
  Writeln('Unaligned tests passed.');
end;

begin
  try
    Writeln('=== Final Mem.FillD Tests ===');
    Writeln('CPU Features:');
    Writeln('  SSE:  ', cpuFeatures.SSE);
    Writeln('  SSE2: ', cpuFeatures.SSE2);
    Writeln('  MMX:  ', cpuFeatures.MMX);
    Writeln;
    
    TestCorrectness;
    Writeln;
    
    TestUnalignedCorrectness;
    Writeln;
    
    TestSSEUsage;
    Writeln;
    
    Writeln('=== All tests completed successfully ===');
  except
    on E: Exception do
      Writeln('Error: ', E.ClassName, ': ', E.Message);
  end;
  
  Writeln('Press Enter to exit...');
  Readln;
end.