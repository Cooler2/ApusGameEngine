program FillDBenchmark;

{$APPTYPE CONSOLE}

{$IFDEF FPC}
  {$MODE DELPHI}
  {$ASMMODE INTEL}
  {$OPTIMIZATION LEVEL3}
  {$OPTIMIZATION REGVAR}
  {$OPTIMIZATION PEEPHOLE}
  {$OPTIMIZATION LOOPUNROLL}
  {$OPTIMIZATION CSE}
{$ELSE}
  {$OPTIMIZATION ON}
{$ENDIF}
{$R-,Q-}

uses
  Windows,
  SysUtils;

type
  UIntPtr = {$IFDEF WIN64}NativeUInt{$ELSE}Cardinal{$ENDIF};

  TFillDProc = procedure(var data; count: UIntPtr; value: Cardinal);

procedure FillChar_Base(var data; count: UIntPtr; value: Cardinal);
begin
  {$IFDEF FPC}
  FillDword(data,count,value);
  {$ELSE}
  FillChar(data,count*4,value);
  {$ENDIF}
end;

{$IFNDEF CPU386}
procedure FillD_SSE2(var data; count: UIntPtr; value: Cardinal);
asm
  // RCX = @data
  // RDX = count
  // R8D = value

  test    rdx, rdx
  jz      @@exit

  // ‘д®а¬Ёа®ў вм xmm0 = {value,value,value,value}
  movd    xmm0, r8d
  pshufd  xmm0, xmm0, 0

  // Џа®ўҐаЁ¬ ўла ў­Ёў ­ЁҐ
  test    rcx, 15
  jz      @@aligned

@@align_loop:
  mov     dword ptr [rcx], r8d
  add     rcx, 4
  dec     rdx
  test    rcx, 15
  jz      @@aligned
  test    rdx, rdx
  jnz     @@align_loop
  jmp     @@exit

@@aligned:
  mov     r9, rdx
  shr     r9, 2          // r9 = count div 4
  jz      @@tail

@@loop:
  movdqa  [rcx], xmm0
  add     rcx, 16
  dec     r9
  jnz     @@loop

@@tail:
  and     rdx, 3
  jz      @@exit

@@tail_loop:
  mov     dword ptr [rcx], r8d
  add     rcx, 4
  dec     rdx
  jnz     @@tail_loop

@@exit:
end;

procedure FillD_NT(var data; count: UIntPtr; value: Cardinal);
asm
  // RCX = @data
  // RDX = count
  // R8D = value

  test    rdx, rdx
  jz      @@exit

  // xmm0 = {value,value,value,value}
  movd    xmm0, r8d
  pshufd  xmm0, xmm0, 0

  // Выравниваем адрес на 16 байт
  test    rcx, 15
  jz      @@aligned

@@align_loop:
  mov     dword ptr [rcx], r8d
  add     rcx, 4
  dec     rdx
  test    rcx, 15
  jz      @@aligned
  test    rdx, rdx
  jnz     @@align_loop
  jmp     @@exit

@@aligned:
  mov     r9, rdx
  shr     r9, 2          // r9 = count div 4
  jz      @@tail

@@loop:
  movntdq  [rcx], xmm0   // <-- non-temporal store
  add      rcx, 16
  dec      r9
  jnz      @@loop

@@tail:
  and     rdx, 3
  jz      @@exit

@@tail_loop:
  mov     dword ptr [rcx], r8d
  add     rcx, 4
  dec     rdx
  jnz     @@tail_loop

  sfence                  // синхронизация для NT store

@@exit:
end;

{$ENDIF}

{$IFDEF CPU386}
procedure FillD_SSE_X86(var data; count: UIntPtr; value: Cardinal);
asm
  push    edi
  mov     edi, data
  mov     ecx, count
  test    ecx, ecx
  jz      @@exit

  mov     eax, value
  movd    xmm0, eax
  pshufd  xmm0, xmm0, 0

  // align
@@align:
  test    edi, 15
  jz      @@aligned
  mov     [edi], eax
  add     edi, 4
  dec     ecx
  jnz     @@align
  jmp     @@exit

@@aligned:
  mov     edx, ecx
  shr     edx, 2
  jz      @@tail

@@loop:
  movdqa  [edi], xmm0
  add     edi, 16
  dec     edx
  jnz     @@loop

@@tail:
  and     ecx, 3
  jz      @@exit

@@tail_loop:
  mov     [edi], eax
  add     edi, 4
  dec     ecx
  jnz     @@tail_loop

@@exit:
  pop     edi
end;

{$ENDIF}

procedure FillD_Delphi(var data; count: UIntPtr; value: Cardinal);
type
  arr=array[0..65535] of cardinal;
var
  p: ^arr;
  i: UIntPtr;
begin
  p := @data;
  for i := 0 to count - 1 do
    p^[i] := value;
end;

var
  QPFreq: Int64;

procedure InitTimer;
begin
  QueryPerformanceFrequency(QPFreq);
end;

function QPC: Int64; inline;
begin
  QueryPerformanceCounter(Result);
end;

procedure RunBenchmark(
  const Name: string;
  Proc: TFillDProc;
  Buffer: Pointer;
  Count: UIntPtr;
  Iterations: Integer
);
type
 arr = array[0..65535] of cardinal;
var
  t0, t1: Int64;
  i: Integer;
  checksum: Cardinal;
  p: ^arr;
  seconds: Double;
  bytes: UInt64;
  gbps: Double;
begin
  // Warm-up
  for i := 1 to 8 do
    Proc(Buffer^, Count, $12345678);

  checksum := 0;
  p := Buffer;

  t0 := QPC;
  for i := 1 to Iterations do
  begin
    Proc(Buffer^, Count, Cardinal(i));

    //  ­вЁ-DCE: зЁв Ґ¬ 1 н«Ґ¬Ґ­в
    Inc(checksum, p^[(i * 1315423911) and (Count - 1)]);
  end;
  t1 := QPC;

  seconds := (t1 - t0) / QPFreq;
  bytes   := UInt64(Count) * 4 * UInt64(Iterations);
  gbps    := (bytes / seconds) / 1e9;

  Writeln(Format(
    '%-24s  %8.3f ms   %6.2f GB/s',
    [Name, seconds * 1000, gbps, checksum]
  ));
end;

procedure Main;
const
//  BufferDWords = 32 * 1024 * 1024; // 128 MB
//  Iterations   = 64;
  BufferDWords:integer = 1024;
  Iterations:integer   = 2 * 1024 * 1024;
var
  Buffer: Pointer;
  i:integer;
begin
  InitTimer;

  try
    Writeln('FillD benchmark - ', {$IFDEF FPC} 'FPC' {$ELSE} 'DELPHI' {$ENDIF},
     {$IFDEF CPU386}' 32' {$ELSE} ' 64' {$ENDIF});

    for i:=1 to 6 do begin
      GetMem(Buffer, BufferDWords * 4);
      Writeln('----------------------');
      Writeln('Buffer size: ', BufferDWords * 4 div (1024), ' KB');
      Writeln('Iterations:  ', Iterations);
      Writeln;

      RunBenchmark('FillDword',       FillChar_Base, Buffer, BufferDWords, Iterations);
      RunBenchmark('FillD Pascal',   FillD_Delphi, Buffer, BufferDWords, Iterations);
      {$IFDEF CPUX64}
      RunBenchmark('FillD SSE2', FillD_SSE2,   Buffer, BufferDWords, Iterations);
      RunBenchmark('FillD SSE2 NT', FillD_NT,   Buffer, BufferDWords, Iterations);
      {$ENDIF}
      {$IFDEF CPU386}
      RunBenchmark('FillD x86 ASM',  FillD_SSE_X86,    Buffer, BufferDWords, Iterations);
      {$ENDIF}

      BufferDWords:=BufferDWords*8;
      Iterations:=Iterations div 8;
      if i=4 then
        Iterations:=Iterations div 2;
      FreeMem(Buffer);
    end;
  finally
  end;
end;

begin
  Main;
  Readln;
end.
