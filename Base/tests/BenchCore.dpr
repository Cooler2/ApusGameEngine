{$APPTYPE CONSOLE}
program BenchCore;
uses
 {$IFDEF MSWINDOWS}
  Windows,
 {$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Conv;

{$I test.inc}

const
  N_FAST = 10000000;
  N_DEF  = 1000000;

// ============================================================================
// Memory operations
// ============================================================================

procedure BenchMem_Clear_64;
var i:integer; buf:array[0..63] of byte;
begin
  StartBench('Mem.Clear 64B',N_DEF);
  for i:=1 to N_DEF do
    Mem.Clear(buf,64);
  EndBench;
end;

procedure BenchMem_Clear_1K;
var i:integer; buf:array[0..1023] of byte;
begin
  StartBench('Mem.Clear 1K',N_DEF);
  for i:=1 to N_DEF do
    Mem.Clear(buf,1024);
  EndBench;
end;

procedure BenchMem_Clear_64K;
var i:integer; buf:array[0..65535] of byte;
begin
  StartBench('Mem.Clear 64K',N_DEF);
  for i:=1 to N_DEF do
    Mem.Clear(buf,65536);
  EndBench;
end;

procedure BenchMem_Fill_1K;
var i:integer; buf:array[0..1023] of byte;
begin
  StartBench('Mem.Fill 1K',N_DEF);
  for i:=1 to N_DEF do
    Mem.Fill(buf,1024,$AA);
  EndBench;
end;

procedure BenchMem_FillD_1K;
var i:integer; buf:array[0..255+16] of cardinal;
begin
  StartBench('Mem.FillD 256 dwords',N_DEF);
  for i:=1 to N_DEF do
    Mem.FillD(buf,256,$DEADBEEF);
  EndBench;
end;

procedure BenchMem_FillD_16K;
var i:integer; buf:array[0..4095] of cardinal;
begin
  StartBench('Mem.FillD 4K dwords',N_DEF);
  for i:=1 to N_DEF do
    Mem.FillD(buf,4096,$DEADBEEF);
  EndBench;
end;

procedure BenchMem_Copy_64;
var i:integer; src,dst:array[0..63] of byte;
begin
  StartBench('Mem.Copy 64B',N_DEF);
  for i:=1 to N_DEF do
    Mem.Copy(src,dst,64);
  EndBench;
end;

procedure BenchMem_Copy_1K;
var i:integer; src,dst:array[0..1023] of byte;
begin
  StartBench('Mem.Copy 1K',N_DEF);
  for i:=1 to N_DEF do
    Mem.Copy(src,dst,1024);
  EndBench;
end;

procedure BenchMem_Copy_64K;
var i:integer; src,dst:array[0..65535] of byte;
begin
  StartBench('Mem.Copy 64K',N_DEF);
  for i:=1 to N_DEF do
    Mem.Copy(src,dst,65536);
  EndBench;
end;

procedure BenchMem_IsZero_1K;
var i:integer; buf:array[0..1023] of byte; b:boolean;
begin
  StartBench('Mem.IsZero 1K',N_DEF);
  Mem.Clear(buf,1024);
  for i:=1 to N_DEF do
    b:=Mem.IsZero(buf,1024);
  EndBench;
end;

procedure BenchMem_Shift_1K;
var i:integer; buf:array[0..1023] of byte;
begin
  StartBench('Mem.Shift 1K +16',N_DEF);
  for i:=1 to N_DEF do
    Mem.Shift(buf,1024,16);
  EndBench;
end;

// ============================================================================
// Math primitives
// ============================================================================

procedure BenchMinMax_Int;
var i,a,b,r:integer;
begin
  StartBench('Min/Max integer',N_FAST);
  a:=42; b:=17;
  for i:=1 to N_FAST do begin
    r:=Min(a,b);
    r:=Max(a,b);
  end;
  EndBench;
end;

procedure BenchClamp_Int;
var i,v,r:integer;
begin
  StartBench('Clamp integer',N_FAST);
  v:=150;
  for i:=1 to N_FAST do
    r:=Clamp(v,0,100);
  EndBench;
end;

procedure BenchClamp_Single;
var i:integer; v,r:single;
begin
  StartBench('Clamp single',N_FAST);
  v:=1.5;
  for i:=1 to N_FAST do
    r:=Clamp(v,0.0,1.0);
  EndBench;
end;

procedure BenchSat;
var i:integer; v,r:single;
begin
  StartBench('Sat',N_FAST);
  v:=1.5;
  for i:=1 to N_FAST do
    r:=Sat(v);
  EndBench;
end;

procedure BenchLerp;
var i:integer; r:single;
begin
  StartBench('Lerp',N_FAST);
  for i:=1 to N_FAST do
    r:=Lerp(0.0,100.0,0.5);
  EndBench;
end;

procedure BenchSwap_Int;
var i,a,b:integer;
begin
  StartBench('Swap integer',N_FAST);
  a:=1; b:=2;
  for i:=1 to N_FAST do
    Swap(a,b);
  EndBench;
end;

// ============================================================================
// Bit operations
// ============================================================================

procedure BenchBits_HasAll;
var i:integer; v:cardinal; b:boolean;
begin
  StartBench('Bits.HasAll',N_FAST);
  v:=$FFFFFFFF;
  for i:=1 to N_FAST do
    b:=Bits.HasAll(v,$FF00);
  EndBench;
end;

procedure BenchBits_SetFlag;
var i:integer; v:cardinal;
begin
  StartBench('Bits.SetFlag',N_FAST);
  v:=0;
  for i:=1 to N_FAST do
    Bits.SetFlag(v,$FF);
  EndBench;
end;

procedure BenchBits_SetBit;
var i:integer; v:cardinal;
begin
  StartBench('Bits.SetBit',N_FAST);
  v:=0;
  for i:=1 to N_FAST do
    Bits.SetBit(v,7);
  EndBench;
end;

procedure BenchBits_Get;
var i:integer; v:cardinal; b:boolean;
begin
  StartBench('Bits.Get',N_FAST);
  v:=$FFFFFFFF;
  for i:=1 to N_FAST do
    b:=Bits.Get(v,15);
  EndBench;
end;

// ============================================================================
// Misc
// ============================================================================

procedure BenchNextPow2;
var i,r:integer;
begin
  StartBench('NextPow2',N_FAST);
  for i:=1 to N_FAST do
    r:=NextPow2(1000);
  EndBench;
end;

procedure BenchLog2i;
var i,r:integer;
begin
  StartBench('Log2i',N_FAST);
  for i:=1 to N_FAST do
    r:=Log2i(1000);
  EndBench;
end;

procedure BenchIsNaN_Single;
var i:integer; v:single; b:boolean;
begin
  StartBench('IsNaN single',N_FAST);
  v:=3.14;
  for i:=1 to N_FAST do
    b:=IsNaN(v);
  EndBench;
end;

procedure BenchHalf_ToSingle;
var i:integer; h:half; f:single;
begin
  StartBench('half -> single',N_FAST);
  h.value:=$3C00; // 1.0
  for i:=1 to N_FAST do
    f:=h;
  EndBench;
end;

procedure BenchHalf_FromSingle;
var i:integer; h:half; f:single;
begin
  StartBench('single -> half',N_FAST);
  f:=3.14;
  for i:=1 to N_FAST do
    h:=f;
  EndBench;
end;

procedure BenchSpinLock;
var i:integer; lock:integer;
begin
  StartBench('SpinLock (uncontended)',N_FAST);
  lock:=0;
  for i:=1 to N_FAST do begin
    SpinLock(lock);
    lock:=0;
  end;
  EndBench;
end;

// ============================================================================
// Stack operations
// ============================================================================

procedure BenchStack_Caller;
var i:integer; p:pointer;
begin
  StartBench('Stack.Caller',N_FAST);
  for i:=1 to N_FAST do
    p:=Stack.Caller;
  EndBench;
end;

procedure BenchStack_Trace;
var i:integer; frames:TCallStack; count:integer;
begin
  StartBench('Stack.Trace',N_DEF);
  for i:=1 to N_DEF do
    count:=Stack.Trace(frames,0);
  EndBench;
end;

// ============================================================================
// Time operations
// ============================================================================

procedure BenchTime_UTC;
var i:integer; dt:TDateTime;
begin
  StartBench('Time.UTC',N_DEF);
  for i:=1 to N_DEF do
    dt:=Time.UTC;
  EndBench;
end;

procedure BenchTime_Now;
var i:integer; dt:TDateTime;
begin
  StartBench('Time.Now',N_DEF);
  for i:=1 to N_DEF do
    dt:=Time.Now;
  EndBench;
end;

procedure BenchTime_Stamp;
var i:integer; s:string;
begin
  StartBench('Time.Stamp',N_DEF);
  for i:=1 to N_DEF do
    s:=Time.Stamp;
  EndBench;
end;

procedure BenchGetTickCount64;
var i:integer; t:int64;
begin
  StartBench('GetTickCount64',N_FAST);
  for i:=1 to N_FAST do
    t:=GetTickCount64;
  EndBench;
end;

procedure BenchQueryPerformanceCounter;
var i:integer; t:int64;
begin
  StartBench('QueryPerformanceCounter',N_FAST);
  for i:=1 to N_FAST do
    QueryPerformanceCounter(t);
  EndBench;
end;

procedure BenchTime_Ticks(const suffix:string='');
var i:integer; t:int64;
begin
  StartBench('Time.Ticks'+suffix,N_FAST);
  for i:=1 to N_FAST do
    t:=Time.Ticks;
  EndBench;
end;

procedure BenchTime_TicksUs(const suffix:string='');
var i:integer; t:int64;
begin
  StartBench('Time.TicksUs'+suffix,N_FAST);
  for i:=1 to N_FAST do
    t:=Time.TicksUs;
  EndBench;
end;

procedure BenchTime_TicksSec;
var i:integer; t:double;
begin
  StartBench('Time.TicksSec',N_FAST);
  for i:=1 to N_FAST do
    t:=Time.TicksSec;
  EndBench;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    OpenBenchLog('core',N_DEF);
    BenchWriteln;

    BenchWriteln('--- Memory ---');
  BenchMem_Clear_64;
  BenchMem_Clear_1K;
  BenchMem_Clear_64K;
  BenchMem_Fill_1K;
  BenchMem_FillD_1K;
  BenchMem_FillD_16K;
  BenchMem_Copy_64;
  BenchMem_Copy_1K;
  BenchMem_Copy_64K;
  BenchMem_IsZero_1K;
  BenchMem_Shift_1K;
  BenchWriteln;

  BenchWriteln('--- Math ---');
  BenchMinMax_Int;
  BenchClamp_Int;
  BenchClamp_Single;
  BenchSat;
  BenchLerp;
  BenchSwap_Int;
  BenchWriteln;

  BenchWriteln('--- Bits ---');
  BenchBits_HasAll;
  BenchBits_SetFlag;
  BenchBits_SetBit;
  BenchBits_Get;
  BenchWriteln;

  BenchWriteln('--- Misc ---');
  BenchNextPow2;
  BenchLog2i;
  BenchIsNaN_Single;
  BenchHalf_ToSingle;
  BenchHalf_FromSingle;
  BenchSpinLock;
  BenchWriteln;

  BenchWriteln('--- Stack ---');
  BenchStack_Caller;
  BenchStack_Trace;
  BenchWriteln;

  BenchWriteln('--- Time ---');
  BenchTime_UTC;
  BenchTime_Now;
  BenchTime_Stamp;
  BenchGetTickCount64;
  BenchQueryPerformanceCounter;
  // ABBA order reduces systematic bias from CPU warm-up and frequency changes.
  BenchTime_Ticks(' A');
  BenchTime_TicksUs(' A');
  BenchTime_TicksUs(' B');
  BenchTime_Ticks(' B');
  BenchTime_TicksSec;
  BenchWriteln;

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
