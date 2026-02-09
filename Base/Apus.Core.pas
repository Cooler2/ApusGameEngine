// Core low-level utilities: types, CPU detection, math primitives, memory operations, bit manipulation
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.Core;
interface

{$SCOPEDENUMS ON}
type
  TCPUType = (X86, ARM);

const
  {$IFDEF CPUX86}
  CPU_TYPE = TCPUType.X86;
  CPU_BIT  = 32;
  {$ENDIF}
  {$IFDEF CPUX64}
  CPU_TYPE = TCPUType.X86;
  CPU_BIT  = 64;
  {$ENDIF}
  {$IFDEF CPUARM64}
  CPU_TYPE = TCPUType.ARM;
  CPU_BIT  = 64;
  {$ENDIF}

type
  // =============================================================================
  // Basic types
  // =============================================================================

  // Integer type aliases
  DWORD = cardinal;
  QWORD = uint64;

  // Pointer-sized unsigned integer
  {$IF not Declared(UIntPtr)}
  UIntPtr = NativeUInt;
  {$IFEND}
  PtrUInt = UIntPtr;

  // 8-bit string (UTF-8 encoding)
  Char8 = UTF8Char;
  String8 = UTF8String;
  PString8 = ^String8;

  // 16-bit string (UTF-16 or UCS-2)
  {$IFDEF UNICODE}
  Char16 = Char;
  String16 = UnicodeString;
  {$ELSE}
  Char16 = WideChar;
  String16 = WideString;
  {$ENDIF}
  PString16 = ^String16;

  // 32-bit string (UCS-4)
  String32 = UCS4String;
  PString32 = ^String32;

  // Array types
  ByteArray = {$IF Declared(TBytes)}TBytes{$ELSE}array of byte{$IFEND};
  WordArray = array of word;
  IntArray = array of integer;
  UIntArray = array of cardinal;
  SingleArray = array of single;
  FloatArray = array of double;
  PointerArray = array of pointer;
  VariantArray = array of variant;
  TObjectArray = array of TObject;

  // String arrays
  Strings8 = array of String8;
  Strings16 = array of String16;
  Strings32 = array of String32;
  Strings = array of string;
  StringArray = Strings; // alias for compatibility

  // Short string
  ShortStr = string[31];

  // Procedure types
  TProcedure = procedure;
  TObjProcedure = procedure of object;

  // 128-bit vector data
  m128 = record
    case byte of
      0: (x,y,z,t:single);
      1: (b:array[0..15] of byte);
      2: (w:array[0..7] of word);
      3: (dw:array[0..3] of dword);
      4: (qw:array[0..1] of qword);
      5: (f:array[0..3] of single);
      6: (d:array[0..1] of double);
  end;

  // 16-bit floating point value (half-precision)
  half = record
    value:word;
    class operator Implicit(const f:single):half;
    class operator Implicit(const h:half):single;
  end;

  // =============================================================================
  // CPU features detection
  // =============================================================================
  TCPUFeatures = record
    version:cardinal;
    flags1,flags2,flags3:cardinal; // EDX, ECX and EBX flags from CPUID
    MMX:boolean;
    SSE:boolean;
    SSE2,SSE3,SSSE3,SSE4,SSE42:boolean;
    AVX,AVX2:boolean;
    AES,RDRAND:boolean;
    HYPERVISOR:boolean;
    BMI1,BMI2:boolean;
    ERMSB:boolean; // Enhanced REP MOVSB/STOSB
  end;

var
  cpuFeatures:TCPUFeatures;

// =============================================================================
// Standalone functions
// =============================================================================

  // Min/Max
  function Min(a,b:integer):integer; overload; inline;
  function Min(a,b:cardinal):integer; overload; inline;
  function Min(a,b:int64):integer; overload; inline;
  function Min(a,b:uint64):integer; overload; inline;
  function Min(a,b:single):single; overload; inline;
  function Min(a,b:double):double; overload; inline;
  function Min(a,b,c:integer):integer; overload;
  function Min(a,b,c:single):integer; overload;
  function Max(a,b:integer):integer; overload; inline;
  function Max(a,b:cardinal):integer; overload; inline;
  function Max(a,b:int64):integer; overload; inline;
  function Max(a,b:uint64):integer; overload; inline;
  function Max(a,b:single):single; overload; inline;
  function Max(a,b:double):double; overload; inline;
  function Max(a,b,c:integer):integer; overload;
  function Max(a,b,c:single):integer; overload;

  // Clamp
  function Clamp(v,min,max:integer):integer; overload; inline;
  function Clamp(v,min,max:single):single; overload; inline;
  function Clamp(v,min,max:double):double; overload; inline;

  // Sat - Clamp to 0..1
  function Sat(v:single):single; overload; inline;
  function Sat(v:double):double; overload; inline;

  // Lerp
  function Lerp(a,b,t:single):single; overload; inline;
  function LerpC(a,b,t:single):single; overload; inline; // clamp t
  function Lerp(a,b,t:double):double; overload; inline;

  // Swap
  procedure Swap(var a,b:integer); overload; inline;
  procedure Swap(var a,b:single); overload; inline;
  procedure Swap(var a,b:double); overload; inline;
  procedure Swap(var a,b:pointer); overload; inline;
  procedure Swap(var a,b:byte); overload; inline;
  procedure Swap(var a,b:string); overload; inline;
  procedure Swap(var a,b:string8); overload; inline;
  procedure Swap(var a,b;size:integer); overload; inline;

  // Pow2
  function GetPow2(v:integer):integer; inline; // smallest power of 2 >= v
  function Pow2(e:integer):int64; inline;      // 2^e
  function Log2i(v:integer):integer;           // ceil(log2(v))

  // --- Alignment ---  (align must be a power of 2)
  function AlignUp(val:UIntPtr; align:cardinal):UIntPtr; overload; inline;
  function AlignUp(val:pointer; align:cardinal):pointer; overload; inline;
  function AlignDown(val:UIntPtr; align:cardinal):UIntPtr; overload; inline;
  function AlignDown(val:pointer; align:cardinal):pointer; overload; inline;
  function IsAligned(val:UIntPtr; align:cardinal):boolean; overload; inline;
  function IsAligned(val:pointer; align:cardinal):boolean; overload; inline;

  // Misc
  procedure Toggle(var b:boolean); inline;
  function IsNaN(const v:single):boolean; overload; inline;
  function IsNaN(const v:double):boolean; overload; inline;

  function PtrInside(ptr,base:pointer;size:UIntPtr):boolean; inline; // check if ptr is inside memory block

  procedure SpinLock(var lock:integer); inline;

// =============================================================================
// Cross-platform primitives
// =============================================================================

  procedure Sleep(time:integer); inline;
  function GetTickCount:cardinal; inline;
  function GetCurrentThreadID:{$IFDEF MSWINDOWS}cardinal{$ELSE}TThreadID{$ENDIF}; inline;
  function IsDebuggerPresent:boolean; inline;
  {$IF not DECLARED(MemoryBarrier)}
  {$DEFINE NEED_MEMORY_BARRIER}
  procedure MemoryBarrier; inline;
  {$IFEND}

  // High-resolution timer
  procedure StartTimer(out timer:int64); overload; inline;
  function TimerSec(const timer:int64):double; overload;
  procedure StartTimer; overload;
  function TimerSec:double; overload;

  // Error handling
  function GetLastErrorCode:cardinal;
  function GetLastErrorDesc:string;

// =============================================================================
// Mem scope - memory operations
// =============================================================================
type
  Mem=record
    class procedure Clear(var data;size:UIntPtr); static; inline;
    class function IsZero(var data;size:UIntPtr):boolean; static;
    class procedure Fill(var data;count:UIntPtr;value:byte); static;
    class procedure FillW(var data;count:UIntPtr;value:word); static;
    class procedure FillD(var data;count:UIntPtr;value:cardinal); static;
    class procedure FillQ(var data;count:UIntPtr;value:uint64); static;
    class procedure FillF(var data;count:UIntPtr;value:single); static;
    class procedure Shift(var data;sizeInBytes,shiftOffset:integer); static; // offset>0 - shift forward
    class procedure Copy(const src; var dst;size:UIntPtr); static;
  end;

// =============================================================================
// Bits scope - bit manipulation
// =============================================================================
type
  Bits=record
    // Query flags
    class function HasAll(v,flagMask:cardinal):boolean; overload; static; inline;
    class function HasAll(v,flagMask:uint64):boolean; overload; static; inline;
    class function HasAny(v,flagMask:cardinal):boolean; overload; static; inline;
    class function HasAny(v,flagMask:uint64):boolean; overload; static; inline;
    // Set/reset flags
    class procedure SetFlag(var v:byte; flagMask:byte); overload; static; inline;
    class procedure SetFlag(var v:word; flagMask:word); overload; static; inline;
    class procedure SetFlag(var v:cardinal; flagMask:cardinal); overload; static; inline;
    class procedure SetFlag(var v:uint64; flagMask:uint64); overload; static; inline;
    class procedure Clear(var v:byte; flagMask:byte); overload; static; inline;
    class procedure Clear(var v:word; flagMask:word); overload; static; inline;
    class procedure Clear(var v:cardinal; flagMask:cardinal); overload; static; inline;
    class procedure Clear(var v:uint64; flagMask:uint64); overload; static; inline;
    // Update flags
    class procedure Modify(var v:byte; flagMask:byte; newValue:boolean); overload; static; inline;
    class procedure Modify(var v:word; flagMask:word; newValue:boolean); overload; static; inline;
    class procedure Modify(var v:cardinal; flagMask:cardinal; newValue:boolean); overload; static; inline;
    class procedure Modify(var v:uint64; flagMask:uint64; newValue:boolean); overload; static; inline;
    // Single bits
    class function Get(data:cardinal; index:integer):boolean; static; inline;
    class procedure SetBit(var data:byte; index:integer; value:boolean=true); overload; static; inline;
    class procedure SetBit(var data:word; index:integer; value:boolean=true); overload; static; inline;
    class procedure SetBit(var data:cardinal; index:integer; value:boolean=true); overload; static; inline;
    class procedure SetBit(var data:uint64; index:integer; value:boolean=true); overload; static; inline;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
{$IFDEF UNIX}
  BaseUnix,
  {$IFDEF LINUX}Linux,{$ENDIF}
{$ENDIF}
  SysUtils;

// =============================================================================
// Standalone functions implementation
// =============================================================================

procedure SpinLock(var lock:integer); inline;
begin
  while {$IFDEF FPC}InterLockedCompareExchange{$ELSE}AtomicCmpExchange{$ENDIF}(lock,1,0)<>0 do Sleep(0);
end;

// =============================================================================
// Cross-platform primitives implementation
// =============================================================================

procedure Sleep(time:integer); inline;
begin
{$IFDEF MSWINDOWS}
  windows.Sleep(time);
{$ELSE}
  SysUtils.Sleep(time);
{$ENDIF}
end;

function GetTickCount:cardinal; inline;
{$IFDEF MSWINDOWS}
begin
  result:=windows.GetTickCount;
end;
{$ELSE}
var
  tp:TTimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC,@tp);
  result:=tp.tv_sec*1000+tp.tv_nsec div 1000000;
end;
{$ENDIF}

function GetCurrentThreadID:{$IFDEF MSWINDOWS}cardinal{$ELSE}TThreadID{$ENDIF}; inline;
begin
{$IFDEF MSWINDOWS}
  result:=windows.GetCurrentThreadId;
{$ELSE}
  result:=system.GetCurrentThreadID;
{$ENDIF}
end;

{$IFDEF UNIX}
{$IFNDEF IOS}
const
  PTRACE_TRACEME = 0;
  PTRACE_DETACH = 17;
function ptrace(__request:integer; PID:{$IFDEF FPC}pid_t{$ELSE}integer{$ENDIF};
  Address:Pointer; Data:Longint):longint; cdecl; external 'c' name 'ptrace';
{$ENDIF}
{$ENDIF}

function IsDebuggerPresent:boolean; inline;
begin
{$IFDEF MSWINDOWS}
  result:=windows.IsDebuggerPresent;
{$ELSE}
  {$IFDEF IOS}
  result:=false;
  {$ELSE}
  if ptrace(PTRACE_TRACEME,0,nil,0)<0 then
    result:=true
  else begin
    ptrace(PTRACE_DETACH,0,nil,0);
    result:=false;
  end;
  {$ENDIF}
{$ENDIF}
end;

{$IFDEF NEED_MEMORY_BARRIER}
procedure MemoryBarrier; inline;
begin
  {$IF DEFINED(CPUX86) OR DEFINED(CPUX64)}
  asm mfence end;
  {$ELSE}
  // ARM and other architectures: compiler barrier
  {$ENDIF}
end;
{$ENDIF}

var
  timerMul:double; // 1/frequency, initialized in unit init
  internalTimer:int64;

procedure QPC(out value:int64); inline;
{$IFDEF MSWINDOWS}
begin
  windows.QueryPerformanceCounter(value);
end;
{$ELSE}
var
  tp:TTimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC,@tp);
  value:=int64(tp.tv_sec)*1000000+tp.tv_nsec div 1000;
end;
{$ENDIF}

procedure StartTimer(out timer:int64); inline;
begin
  QPC(timer);
end;

function TimerSec(const timer:int64):double;
var
  now:int64;
begin
  QPC(now);
  result:=(now-timer)*timerMul;
end;

procedure StartTimer;
begin
  QPC(internalTimer);
end;

function TimerSec:double;
var
  now:int64;
begin
  QPC(now);
  result:=(now-internalTimer)*timerMul;
end;

function GetLastErrorCode:cardinal;
begin
{$IF declared(GetLastError)}
  result:=GetLastError;
{$ELSE}
  {$IF Declared(fpGetErrno)}
  result:=fpGetErrno;
  {$ELSE}
  result:=0;
  {$ENDIF}
{$ENDIF}
end;

function GetLastErrorDesc:string;
var
  code:cardinal;
begin
  code:=GetLastErrorCode;
{$IF Declared(SysErrorMessage)}
  result:=SysErrorMessage(code)+Format(' (%d)',[code]);
{$ELSE}
  if code=0 then result:='NO ERROR'
   else result:=Format('CODE %d (%8x)',[code,code]);
{$ENDIF}
end;

function Min(a,b:integer):integer;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:cardinal):integer;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:int64):integer;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:uint64):integer;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:single):single;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:double):double;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b,c:integer):integer;
begin
  result:=a;
  if b<result then result:=b;
  if c<result then result:=c;
end;

function Min(a,b,c:single):integer;
begin
  result:=trunc(a);
  if b<result then result:=trunc(b);
  if c<result then result:=trunc(c);
end;

function Max(a,b:integer):integer;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:cardinal):integer;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:int64):integer;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:uint64):integer;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:single):single;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:double):double;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b,c:integer):integer;
begin
  result:=a;
  if b>result then result:=b;
  if c>result then result:=c;
end;

function Max(a,b,c:single):integer;
begin
  result:=trunc(a);
  if b>result then result:=trunc(b);
  if c>result then result:=trunc(c);
end;

function Clamp(v,min,max:integer):integer;
begin
  result:=v;
  if v>max then result:=max;
  if v<min then result:=min;
end;

function Clamp(v,min,max:single):single;
begin
  result:=v;
  if v>max then result:=max;
  if v<min then result:=min;
end;

function Clamp(v,min,max:double):double;
begin
  result:=v;
  if v>max then result:=max;
  if v<min then result:=min;
end;

function Sat(v:single):single;
begin
  result:=v;
  if v>1.0 then result:=1.0;
  if v<0.0 then result:=0.0;
end;

function Sat(v:double):double;
begin
  result:=v;
  if v>1.0 then result:=1.0;
  if v<0.0 then result:=0.0;
end;

function Lerp(a,b,t:single):single;
begin
  result:=a+(b-a)*t;
end;

function LerpC(a,b,t:single):single;
begin
  if t<0 then t:=0;
  if t>1 then t:=1;
  result:=a+(b-a)*t;
end;

function Lerp(a,b,t:double):double;
begin
  result:=a+(b-a)*t;
end;

procedure Swap(var a,b:integer);
var
  c:integer;
begin
  c:=a; a:=b; b:=c;
end;

procedure Swap(var a,b:single);
var
  c:single;
begin
  c:=a; a:=b; b:=c;
end;

procedure Swap(var a,b:double);
var
  c:double;
begin
  c:=a; a:=b; b:=c;
end;

procedure Swap(var a,b:pointer);
var
  c:pointer;
begin
  c:=a; a:=b; b:=c;
end;

procedure Swap(var a,b:byte);
var
  c:byte;
begin
  c:=a; a:=b; b:=c;
end;

procedure Swap(var a,b:string);
var
  c:string;
begin
  c:=a; a:=b; b:=c;
end;

procedure Swap(var a,b:string8);
var
  c:string8;
begin
  c:=a; a:=b; b:=c;
end;

procedure Swap(var a,b;size:integer);
var
  buf:array[0..4095] of byte;
begin
  ASSERT(size<=length(buf));
  move(a,buf,size);
  move(b,a,size);
  move(buf,b,size);
end;

function GetPow2(v:integer):integer;
begin
  if v<256 then result:=1
  else result:=256;
  while result<v do result:=result*2;
end;

function Pow2(e:integer):int64;
begin
  result:=0;
  if (e>=0) and (e<64) then
    result:=int64(1) shl e;
end;

function Log2i(v:integer):integer;
begin
  if v<=1 then Exit(0);
  dec(v);
  result:=0;
  if v and $FFFF0000 <> 0 then begin v:=v shr 16; inc(Result,16); end;
  if v and $FF00 <> 0     then begin v:=v shr 8;  inc(Result,8);  end;
  if v and $F0 <> 0       then begin v:=v shr 4;  inc(Result,4);  end;
  if v and $C <> 0        then begin v:=v shr 2;  inc(Result,2);  end;
  if v and $2 <> 0        then begin inc(Result,1); end;
  if v <> 0               then begin Result:=Result + 1; end;
end;

procedure Toggle(var b:boolean);
begin
  b:=not b;
end;

function IsNaN(const v:single):boolean;
var
  bits:cardinal;
begin
  // bit check to avoid FPU exception in FPC
  Move(v,bits,4);
  result:=(bits and $7F800000=$7F800000) and (bits and $007FFFFF<>0);
end;

function IsNaN(const v:double):boolean;
var
  bits:uint64;
begin
  Move(v,bits,8);
  result:=(bits and $7FF0000000000000=$7FF0000000000000) and (bits and $000FFFFFFFFFFFFF<>0);
end;

function PtrInside(ptr,base:pointer;size:UIntPtr):boolean;
var
  b,p:UIntPtr;
begin
  b:=UIntPtr(base);
  p:=UIntPtr(ptr);
  result:=(p>=b) and (p<b+size);
end;

function AlignUp(val:UIntPtr;align:cardinal):UIntPtr;
begin
  result:=(val+align-1) and not (align-1);
end;

function AlignUp(val:pointer;align:cardinal):pointer;
begin
  result:=pointer((UIntPtr(val)+align-1) and not (align-1));
end;

function AlignDown(val:UIntPtr;align:cardinal):UIntPtr;
begin
  result:=val and not (align-1);
end;

function AlignDown(val:pointer;align:cardinal):pointer;
begin
  result:=pointer(UIntPtr(val) and not (align - 1));
end;

function IsAligned(val:UIntPtr;align:cardinal):boolean;
begin
  result:=(val and (align - 1)) = 0;
end;

function IsAligned(val:pointer;align:cardinal):boolean;
begin
  result:=(UIntPtr(val) and (align - 1)) = 0;
end;

// =============================================================================
// Mem scope implementation
// =============================================================================

class procedure Mem.Clear(var data;size:UIntPtr);
begin
  FillChar(data,size,0);
end;

class function Mem.IsZero(var data;size:UIntPtr):boolean;
var
  pb:PByte;
  pc:^NativeUInt;
  i:UIntPtr;
begin
  result:=false;
  pb:=@data;
  if size<=8 then begin
    // unaligned version
    while size>0 do begin
      if pb^<>0 then exit;
      inc(pb); dec(size);
    end;
  end else begin
    // aligned version
    while UIntPtr(pb) and 7<>0 do begin
      if pb^<>0 then exit;
      inc(pb); dec(size);
    end;
    i:=size div sizeof(NativeUInt);
    pc:=pointer(pb);
    while i>0 do begin
      if pc^<>0 then exit;
      inc(pc);
      dec(i); dec(size,sizeof(NativeUInt));
    end;
    pb:=pointer(pc);
    while size>0 do begin
      if pb^<>0 then exit;
      inc(pb); dec(size);
    end;
  end;
  result:=true;
end;

class procedure Mem.Fill(var data;count:UIntPtr;value:byte);
begin
  FillChar(data,count,value);
end;

class procedure Mem.FillW(var data;count:UIntPtr;value:word);
var
  p:PWord;
begin
  p:=@data;
  while count>0 do begin
    p^:=value;
    inc(p);
    dec(count);
  end;
end;

{$IF Defined(CPUX64) or Defined(CPUX86)}
// SSE-optimized FillD implementation
procedure FillD_SSE(var data; count: UIntPtr; value: cardinal); forward;

{$IFDEF CPUX64}
procedure FillD_SSE(var data; count: UIntPtr; value: cardinal);
// Windows x64 calling convention: RCX=data, RDX=count, R8=value
// Unix x64 calling convention: RDI=data, RSI=count, RDX=value
asm
  {$IFDEF MSWINDOWS}
  // Windows x64: RCX=data, RDX=count, R8=value
  mov rdi, rcx        // destination
  mov rcx, rdx        // count
  mov eax, r8d        // value
  {$ELSE}
  // Unix x64: RDI=data, RSI=count, RDX=value
  // RDI already contains destination
  mov rcx, rsi        // count
  mov eax, edx        // value
  {$ENDIF}
  
  test rcx, rcx
  jz @done
  
  // Prepare SSE register with replicated value
  movd xmm0, eax
  pshufd xmm0, xmm0, 0  // xmm0 = [value, value, value, value]
  
  // Handle unaligned start (up to 3 dwords)
@unaligned:
  test rdi, 15
  jz @aligned
  mov [rdi], eax
  add rdi, 4
  dec rcx
  jnz @unaligned
  
@aligned:
  // Calculate number of 16-byte blocks (4 dwords per block)
  mov rdx, rcx
  shr rdx, 2           // rdx = blocks
  jz @tail
  
  // Process aligned blocks
@block_loop:
  movdqa [rdi], xmm0
  add rdi, 16
  dec rdx
  jnz @block_loop
  
  // Handle remaining dwords (0-3)
  and rcx, 3
  jz @done
  
@tail:
  mov [rdi], eax
  add rdi, 4
  dec rcx
  jnz @tail
  
@done:
  ret
end;
{$ELSE}
// x86 SSE implementation
procedure FillD_SSE(var data; count: UIntPtr; value: cardinal);
// Calling convention: EAX=data, EDX=count, ECX=value
asm
  push edi
  push ebx
  
  mov edi, eax        // destination
  mov ebx, ecx        // save value to EBX
  mov ecx, edx        // count
  
  test ecx, ecx
  jz @done
  
  // Prepare SSE register with replicated value
  movd xmm0, ebx
  pshufd xmm0, xmm0, 0  // xmm0 = [value, value, value, value]
  
  // Handle unaligned start (up to 3 dwords)
@unaligned:
  test edi, 15
  jz @aligned
  mov [edi], ebx
  add edi, 4
  dec ecx
  jnz @unaligned
  
@aligned:
  // Calculate number of 16-byte blocks (4 dwords per block)
  mov edx, ecx
  shr edx, 2           // edx = blocks
  jz @tail
  
  // Process aligned blocks
@block_loop:
  movdqa [edi], xmm0
  add edi, 16
  dec edx
  jnz @block_loop
  
  // Handle remaining dwords (0-3)
  and ecx, 3
  jz @done
  
@tail:
  mov [edi], ebx
  add edi, 4
  dec ecx
  jnz @tail
  
@done:
  pop ebx
  pop edi
end;
{$ENDIF}
{$IFEND}

class procedure Mem.FillD(var data;count:UIntPtr;value:cardinal);
{$IF Defined(CPUX64) or Defined(CPUX86)}
var
  p: PCardinal;
begin
  // Use SSE optimization if available and count is reasonably large
  if cpuFeatures.SSE and (count >= 16) then
    FillD_SSE(data, count, value)
  else
  begin
    // Fallback to simple implementation
    p := @data;
    while count > 0 do
    begin
      p^ := value;
      inc(p);
      dec(count);
    end;
  end;
end;
{$ELSE}
var
  p:PCardinal;
begin
  // Fallback for non-x86 platforms
  p:=@data;
  while count>0 do begin
    p^:=value;
    inc(p);
    dec(count);
  end;
end;
{$IFEND}

class procedure Mem.FillQ(var data;count:UIntPtr;value:uint64);
var
  p:PUInt64;
begin
  p:=@data;
  while count>0 do begin
    p^:=value;
    inc(p);
    dec(count);
  end;
end;

class procedure Mem.FillF(var data;count:UIntPtr;value:single);
var
  p:PSingle;
begin
  p:=@data;
  while count>0 do begin
    p^:=value;
    inc(p);
    dec(count);
  end;
end;

class procedure Mem.Shift(var data;sizeInBytes,shiftOffset:integer);
var
  sour,dest:PByte;
begin
  sour:=@data; dest:=@data;
  if shiftOffset>0 then begin
    inc(dest,shiftOffset);
    move(sour^,dest^,sizeInBytes-shiftOffset);
  end else begin
    inc(sour,-shiftOffset);
    move(sour^,dest^,sizeInBytes+shiftOffset);
  end;
end;

class procedure Mem.Copy(const src;var dst;size:UIntPtr);
begin
  move(src,dst,size);
end;


// =============================================================================
// Bits scope implementation
// =============================================================================

class function Bits.HasAll(v,flagMask:cardinal):boolean;
begin
  result:=v and flagMask=flagMask;
end;

class function Bits.HasAll(v,flagMask:uint64):boolean;
begin
  result:=v and flagMask=flagMask;
end;

class function Bits.HasAny(v,flagMask:cardinal):boolean;
begin
  result:=v and flagMask<>0;
end;

class function Bits.HasAny(v,flagMask:uint64):boolean;
begin
  result:=v and flagMask<>0;
end;

class procedure Bits.SetFlag(var v:byte;flagMask:byte);
begin
  v:=v or flagMask;
end;

class procedure Bits.SetFlag(var v:word;flagMask:word);
begin
  v:=v or flagMask;
end;

class procedure Bits.SetFlag(var v:cardinal;flagMask:cardinal);
begin
  v:=v or flagMask;
end;

class procedure Bits.SetFlag(var v:uint64;flagMask:uint64);
begin
  v:=v or flagMask;
end;

class procedure Bits.Clear(var v:byte;flagMask:byte);
begin
  v:=v and not flagMask;
end;

class procedure Bits.Clear(var v:word;flagMask:word);
begin
  v:=v and not flagMask;
end;

class procedure Bits.Clear(var v:cardinal;flagMask:cardinal);
begin
  v:=v and not flagMask;
end;

class procedure Bits.Clear(var v:uint64;flagMask:uint64);
begin
  v:=v and not flagMask;
end;

class procedure Bits.Modify(var v:byte;flagMask:byte;newValue:boolean);
begin
  if newValue then v:=v or flagMask
  else v:=v and not flagMask;
end;

class procedure Bits.Modify(var v:word;flagMask:word;newValue:boolean);
begin
  if newValue then v:=v or flagMask
  else v:=v and not flagMask;
end;

class procedure Bits.Modify(var v:cardinal;flagMask:cardinal;newValue:boolean);
begin
  if newValue then v:=v or flagMask
  else v:=v and not flagMask;
end;

class procedure Bits.Modify(var v:uint64;flagMask:uint64;newValue:boolean);
begin
  if newValue then v:=v or flagMask
  else v:=v and not flagMask;
end;

class function Bits.Get(data:cardinal;index:integer):boolean;
begin
  result:=data and (cardinal(1) shl index)<>0;
end;

class procedure Bits.SetBit(var data:byte;index:integer;value:boolean=true);
begin
  if value then data:=data or (byte(1) shl index)
  else data:=data and not (byte(1) shl index);
end;

class procedure Bits.SetBit(var data:word;index:integer;value:boolean=true);
begin
  if value then data:=data or (word(1) shl index)
  else data:=data and not (word(1) shl index);
end;

class procedure Bits.SetBit(var data:cardinal;index:integer;value:boolean=true);
begin
  if value then data:=data or (cardinal(1) shl index)
  else data:=data and not (cardinal(1) shl index);
end;

class procedure Bits.SetBit(var data:uint64;index:integer;value:boolean=true);
begin
  if value then data:=data or (uint64(1) shl index)
  else data:=data and not (uint64(1) shl index);
end;

// =============================================================================
// half (16-bit float) implementation
// =============================================================================

class operator half.Implicit(const f:single):half;
var
  bits:cardinal absolute f;
  mant:cardinal;
  exp:integer;
begin
  exp:=(bits shr 23) and $FF; // source exponent
  exp:=Clamp(exp-127,-15,14); // clamped exponent
  mant:=bits and $7FFFFF;
  mant:=Min((mant+1) shr 13, 1023); // rounded mantissa
  result.value:=(exp+15) shl 10 + word(mant);
  if integer(bits)<0 then result.value:=result.value or $8000; // sign
end;

class operator half.Implicit(const h:half):single;
var
  res:cardinal;
  exp:integer;
begin
  if h.value=0 then exit(0);
  exp:=(h.value shr 10) and $1F;
  exp:=(exp-15)+127; // new exponent
  res:=(h.value and $3FF) shl 13; // new mantissa
  res:=res+(cardinal(exp) shl 23);
  if h.value and $8000>0 then res:=res or $80000000;
  move(res,result,4);
end;

// =============================================================================
// CPU detection implementation
// =============================================================================

procedure CheckCPU;
{$IF Defined(CPUX64) or Defined(CPUx86_64) or Defined(CPUx86)}
{$IFDEF CPUx86}
const
  rip = 0;
{$ENDIF}
asm
  {$IFDEF CPUx86}
  push ebx
  {$ELSE}
  push rbx
  {$ENDIF}
  xor eax,eax
  cpuid
  cmp eax,7
  jb @01
  mov eax,7
  xor ecx,ecx
  cpuid
  {$IFDEF DELPHI}
  bt ebx,5
  adc cpuFeatures.avx2,0
  bt ebx,3
  adc cpuFeatures.bmi1,0
  bt ebx,8
  adc cpuFeatures.bmi2,0
  bt ebx,9        // ERMSB = EBX bit 9
  adc cpuFeatures.ermsb,0
  {$ELSE}
  bt ebx,5
  adc byte ptr [cpuFeatures.avx2+rip],0
  bt ebx,3
  adc byte ptr [cpuFeatures.bmi1+rip],0
  bt ebx,8
  adc byte ptr [cpuFeatures.bmi2+rip],0
  bt ebx,9        // ERMSB = EBX bit 9
  adc byte ptr [cpuFeatures.ermsb+rip],0
  {$ENDIF}
@01:
  mov eax,1
  cpuid
  mov [cpuFeatures.version+rip],eax
  mov [cpuFeatures.flags1+rip],edx
  mov [cpuFeatures.flags2+rip],ecx
  mov [cpuFeatures.flags3+rip],ebx
  {$IFDEF DELPHI}
  bt edx,23
  adc cpuFeatures.mmx,0
  bt edx,25
  adc cpuFeatures.sse,0
  bt edx,26
  adc cpuFeatures.sse2,0
  bt ecx,0
  adc cpuFeatures.sse3,0
  bt ecx,9
  adc cpuFeatures.ssse3,0
  bt ecx,19
  adc cpuFeatures.sse4,0
  bt ecx,20
  adc cpuFeatures.sse42,0
  bt ecx,28
  adc cpuFeatures.avx,0
  bt ecx,25
  adc cpuFeatures.aes,0
  bt ecx,30
  adc cpuFeatures.rdrand,0
  bt ecx,31
  adc cpuFeatures.hypervisor,0
  {$ELSE}
  bt edx,23
  adc byte ptr [cpuFeatures.mmx+rip],0
  bt edx,25
  adc byte ptr [cpuFeatures.sse+rip],0
  bt edx,26
  adc byte ptr [cpuFeatures.sse2+rip],0
  bt ecx,0
  adc byte ptr [cpuFeatures.sse3+rip],0
  bt ecx,9
  adc byte ptr [cpuFeatures.ssse3+rip],0
  bt ecx,19
  adc byte ptr [cpuFeatures.sse4+rip],0
  bt ecx,20
  adc byte ptr [cpuFeatures.sse42+rip],0
  bt ecx,28
  adc byte ptr [cpuFeatures.avx+rip],0
  bt ecx,25
  adc byte ptr [cpuFeatures.aes+rip],0
  bt ecx,30
  adc byte ptr [cpuFeatures.rdrand+rip],0
  bt ecx,31
  adc byte ptr [cpuFeatures.hypervisor+rip],0
  {$ENDIF}
  {$IFDEF CPUx86}
  pop ebx
  {$ELSE}
  pop rbx
  {$ENDIF}
end;
{$ELSE}
begin
  // non-x86 platforms: no CPUID available
end;
{$IFEND}

procedure InitTimer;
var
  freq:int64;
begin
{$IFDEF MSWINDOWS}
  windows.QueryPerformanceFrequency(freq);
{$ELSE}
  freq:=1000000;
{$ENDIF}
  timerMul:=1.0/freq;
end;

initialization
  CheckCPU;
  InitTimer;
end.
