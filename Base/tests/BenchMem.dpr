{$APPTYPE CONSOLE}
program BenchMem;

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
  SysUtils,
  Apus.Core;

{$I test.inc}

type
  TFillDProc=procedure(var data; count:UIntPtr; value:Cardinal);
  TCopyProc=procedure(const src; var dst; count:UIntPtr);

// ============================================================================
// Fill implementations
// ============================================================================

procedure FillChar_Base(var data; count:UIntPtr; value:Cardinal);
begin
  {$IFDEF FPC}
  FillDword(data,count,value);
  {$ELSE}
  FillChar(data,count*4,value);
  {$ENDIF}
end;

{$IFNDEF CPU386}
procedure FillD_SSE2(var data; count:UIntPtr; value:Cardinal);
 asm
  // RCX = @data
  // RDX = count
  // R8D = value

  test    rdx, rdx
  jz      @@exit

  // 'д®а¬Ёа®ў вм xmm0 = {value,value,value,value}
  movd    xmm0, r8d
  pshufd  xmm0, xmm0, 0

  // Џа®ўҐаЁ¬ ўла ў­Ёў ­ЁҐ
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

procedure FillD_NT(var data; count:UIntPtr; value:Cardinal);
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
  movntdq  [rcx], xmm0   // non-temporal store
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
procedure FillD_SSE_X86(var data; count:UIntPtr; value:Cardinal);
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

procedure FillD_Delphi(var data; count:UIntPtr; value:Cardinal);
type
  arr=array[0..65535] of cardinal;
var
  p:^arr;
  i:UIntPtr;
begin
  p:=@data;
  for i:=0 to count-1 do
    p^[i]:=value;
end;

// ============================================================================
// Copy implementations
// ============================================================================

procedure Copy_Base(const src; var dst; count:UIntPtr);
begin
  Move(src,dst,count*4);
end;

{$IFNDEF CPU386}
procedure Copy_SSE2(const src; var dst; count:UIntPtr);
 asm
  // RCX = @src
  // RDX = @dst
  // R8  = count (dwords)

  test    r8, r8
  jz      @@exit

  // align destination to 16 bytes
  test    rdx, 15
  jz      @@aligned

@@align_loop:
  mov     eax, dword ptr [rcx]
  mov     dword ptr [rdx], eax
  add     rcx, 4
  add     rdx, 4
  dec     r8
  test    rdx, 15
  jz      @@aligned
  test    r8, r8
  jnz     @@align_loop
  jmp     @@exit

@@aligned:
  mov     r9, r8
  shr     r9, 2          // r9 = count div 4
  jz      @@tail

@@loop:
  movdqu  xmm0, [rcx]    // unaligned read (src may not be aligned)
  movdqa  [rdx], xmm0    // aligned write
  add     rcx, 16
  add     rdx, 16
  dec     r9
  jnz     @@loop

@@tail:
  and     r8, 3
  jz      @@exit

@@tail_loop:
  mov     eax, dword ptr [rcx]
  mov     dword ptr [rdx], eax
  add     rcx, 4
  add     rdx, 4
  dec     r8
  jnz     @@tail_loop

@@exit:
end;

procedure Copy_SSE2_NT(const src; var dst; count:UIntPtr);
 asm
  // RCX = @src
  // RDX = @dst
  // R8  = count (dwords)

  test    r8, r8
  jz      @@exit

  // align destination to 16 bytes
  test    rdx, 15
  jz      @@aligned

@@align_loop:
  mov     eax, dword ptr [rcx]
  mov     dword ptr [rdx], eax
  add     rcx, 4
  add     rdx, 4
  dec     r8
  test    rdx, 15
  jz      @@aligned
  test    r8, r8
  jnz     @@align_loop
  jmp     @@exit

@@aligned:
  mov     r9, r8
  shr     r9, 2
  jz      @@tail

@@loop:
  movdqu  xmm0, [rcx]    // regular read
  movntdq [rdx], xmm0    // non-temporal write
  add     rcx, 16
  add     rdx, 16
  dec     r9
  jnz     @@loop

  sfence

@@tail:
  and     r8, 3
  jz      @@exit

@@tail_loop:
  mov     eax, dword ptr [rcx]
  mov     dword ptr [rdx], eax
  add     rcx, 4
  add     rdx, 4
  dec     r8
  jnz     @@tail_loop

@@exit:
end;

{$ENDIF}

{$IFDEF CPU386}
procedure Copy_SSE_X86(const src; var dst; count:UIntPtr);
 asm
  push    esi
  push    edi
  mov     esi, src
  mov     edi, dst
  mov     ecx, count
  test    ecx, ecx
  jz      @@exit

  // align destination to 16 bytes
@@align:
  test    edi, 15
  jz      @@aligned
  mov     eax, [esi]
  mov     [edi], eax
  add     esi, 4
  add     edi, 4
  dec     ecx
  jnz     @@align
  jmp     @@exit

@@aligned:
  mov     edx, ecx
  shr     edx, 2
  jz      @@tail

@@loop:
  movdqu  xmm0, [esi]
  movdqa  [edi], xmm0
  add     esi, 16
  add     edi, 16
  dec     edx
  jnz     @@loop

@@tail:
  and     ecx, 3
  jz      @@exit

@@tail_loop:
  mov     eax, [esi]
  mov     [edi], eax
  add     esi, 4
  add     edi, 4
  dec     ecx
  jnz     @@tail_loop

@@exit:
  pop     edi
  pop     esi
end;

{$ENDIF}

procedure Copy_Delphi(const src; var dst; count:UIntPtr);
type
  arr=array[0..65535] of cardinal;
var
  s,d:^arr;
  i:UIntPtr;
begin
  s:=@src;
  d:=@dst;
  for i:=0 to count-1 do
    d^[i]:=s^[i];
end;

// ============================================================================
// Benchmark runners
// ============================================================================

procedure RunFillBench(const name:string; proc:TFillDProc; buffer:Pointer;
  count:UIntPtr; iterations:integer);
type
  TArr=array[0..65535] of cardinal;
var
  i:integer;
  checksum:cardinal;
  p:^TArr;
  elapsed,gbps:double;
begin
  for i:=1 to 8 do // warm-up
    proc(buffer^,count,$12345678);
  checksum:=0;
  p:=buffer;
  StartBench(name,iterations);
  for i:=1 to iterations do begin
    proc(buffer^,count,Cardinal(i));
    Inc(checksum,p^[(i*1315423911) and (count-1)]); // anti-DCE
  end;
  elapsed:=Timer.Get(benchTimer);
  gbps:=count*4.0*iterations/elapsed/1e9;
  EndBench(Format('%.2f GB/s',[gbps]));
end;

procedure RunCopyBench(const name:string; proc:TCopyProc; src,dst:Pointer;
  count:UIntPtr; iterations:integer);
type
  TArr=array[0..65535] of cardinal;
var
  i:integer;
  checksum:cardinal;
  p:^TArr;
  elapsed,gbps:double;
begin
  for i:=1 to 8 do // warm-up
    proc(src^,dst^,count);
  checksum:=0;
  p:=dst;
  StartBench(name,iterations);
  for i:=1 to iterations do begin
    proc(src^,dst^,count);
    Inc(checksum,p^[(i*1315423911) and (count-1)]); // anti-DCE
  end;
  elapsed:=Timer.Get(benchTimer);
  gbps:=count*4.0*iterations/elapsed/1e9; // useful data throughput
  EndBench(Format('%.2f GB/s',[gbps]));
end;

// ============================================================================
// Main
// ============================================================================

// TODO: try multithreaded fill/copy for large buffers (>L3 cache) — a single core
// can't saturate memory bandwidth; 2-4 threads with NT stores should give 2-3x speedup

procedure RunFillBenches;
var
  buffer:Pointer;
  bufferDWords:UIntPtr;
  iterations:integer;
  i:integer;
begin
  bufferDWords:=1024;
  iterations:=2*1024*1024;
  for i:=1 to 6 do begin
    GetMem(buffer,bufferDWords*4);
    BenchWriteln(Format('--- Buffer: %d KB ---',[bufferDWords*4 div 1024]));
    RunFillBench('FillDword',FillChar_Base,buffer,bufferDWords,iterations);
    RunFillBench('FillD Pascal',FillD_Delphi,buffer,bufferDWords,iterations);
    {$IFDEF CPUX64}
    RunFillBench('FillD SSE2',FillD_SSE2,buffer,bufferDWords,iterations);
    RunFillBench('FillD SSE2 NT',FillD_NT,buffer,bufferDWords,iterations);
    {$ENDIF}
    {$IFDEF CPU386}
    RunFillBench('FillD x86 ASM',FillD_SSE_X86,buffer,bufferDWords,iterations);
    {$ENDIF}
    BenchWriteln;
    FreeMem(buffer);
    bufferDWords:=bufferDWords*8;
    iterations:=iterations div 8;
    if i=4 then
      iterations:=iterations div 2;
  end;
end;

procedure RunCopyBenches;
var
  src,dst:Pointer;
  bufferDWords:UIntPtr;
  iterations:integer;
  i:integer;
begin
  bufferDWords:=1024;
  iterations:=2*1024*1024;
  for i:=1 to 6 do begin
    GetMem(src,bufferDWords*4);
    GetMem(dst,bufferDWords*4);
    FillChar(src^,bufferDWords*4,$AA); // pre-fill source
    BenchWriteln(Format('--- Buffer: %d KB ---',[bufferDWords*4 div 1024]));
    RunCopyBench('CopyMem (Move)',Copy_Base,src,dst,bufferDWords,iterations);
    RunCopyBench('Copy Pascal',Copy_Delphi,src,dst,bufferDWords,iterations);
    {$IFDEF CPUX64}
    RunCopyBench('Copy SSE2',Copy_SSE2,src,dst,bufferDWords,iterations);
    RunCopyBench('Copy SSE2 NT',Copy_SSE2_NT,src,dst,bufferDWords,iterations);
    {$ENDIF}
    {$IFDEF CPU386}
    RunCopyBench('Copy x86 ASM',Copy_SSE_X86,src,dst,bufferDWords,iterations);
    {$ENDIF}
    BenchWriteln;
    FreeMem(dst);
    FreeMem(src);
    bufferDWords:=bufferDWords*8;
    iterations:=iterations div 8;
    if i=4 then
      iterations:=iterations div 2;
  end;
end;

begin
  try
    OpenBenchLog('mem',1);
    BenchWriteln('Fill methods:');
  BenchWriteln('  FillDword      - RTL FillDword (FPC) / FillChar (Delphi)');
  BenchWriteln('  FillD Pascal   - naive Pascal loop: p[i]:=value');
  {$IFDEF CPUX64}
  BenchWriteln('  FillD SSE2     - x64 ASM, aligned 128-bit movdqa stores');
  BenchWriteln('  FillD SSE2 NT  - x64 ASM, non-temporal movntdq (bypasses cache)');
  {$ENDIF}
  {$IFDEF CPU386}
  BenchWriteln('  FillD x86 ASM  - x86 ASM, aligned 128-bit movdqa stores');
  {$ENDIF}
  BenchWriteln('Copy methods:');
  BenchWriteln('  CopyMem (Move) - RTL Move');
  BenchWriteln('  Copy Pascal    - naive Pascal loop: d[i]:=s[i]');
  {$IFDEF CPUX64}
  BenchWriteln('  Copy SSE2      - x64 ASM, movdqu read + movdqa write');
  BenchWriteln('  Copy SSE2 NT   - x64 ASM, movdqu read + movntdq write');
  {$ENDIF}
  {$IFDEF CPU386}
  BenchWriteln('  Copy x86 ASM   - x86 ASM, movdqu read + movdqa write');
  {$ENDIF}
  BenchWriteln('GB/s = useful data throughput (copy: actual memory traffic is ~2x)');
  BenchWriteln;

  BenchWriteln('====== FILL ======');
  RunFillBenches;

  BenchWriteln('====== COPY ======');
  RunCopyBenches;

  CloseBenchLog;
  writeln('=== BENCHMARK DONE ===');
  except
    on e:Exception do begin
      writeln;
      writeln('BENCHMARK FAILED: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press ENTER to exit');
    readln;
  end;
end.
