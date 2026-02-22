// Core low-level utilities - fundamental building blocks needed by almost every program
//
// SCOPE: Basic functionality required by nearly all applications - types, CPU detection,
// essential math/memory/bit operations, exceptions, stack traces, high-precision time.
// This is the foundation module that provides primitives used everywhere.
//
// ADD HERE: Universal utilities with zero/minimal dependencies that solve common problems.
// DON'T ADD: Domain-specific functionality (strings, files, networking, UI, etc.)
//
// Contains: Basic types (String8, UIntPtr, half), CPU detection, math (Min/Max/Clamp/Lerp),
// memory operations (Mem scope), bit manipulation (Bits scope), exceptions with stack traces,
// stack inspection (Stack scope), high-precision time (Time scope), spinlocks.
//
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)

{$I defines.inc}
unit Apus.Core;
interface
uses SysUtils;

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

  // 32-bit string (UCS-4): ZERO-INDEXED (0-indexed)!
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

  // Short string
  ShortStr = string[31];

  // Procedure types
  TProcedure = procedure;
  TObjProcedure = procedure of object;

  // Text encoding types
  TTextEncoding = (teUnknown, teANSI, teWin1251, teUTF8);

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
  function Min(a,b:cardinal):cardinal; overload; inline;
  function Min(a,b:int64):int64; overload; inline;
  function Min(a,b:uint64):uint64; overload; inline;
  function Min(a,b:single):single; overload; inline;
  function Min(a,b:double):double; overload; inline;
  function Min(a,b,c:integer):integer; overload;
  function Min(a,b,c:single):single; overload;
  function Max(a,b:integer):integer; overload; inline;
  function Max(a,b:cardinal):cardinal; overload; inline;
  function Max(a,b:int64):int64; overload; inline;
  function Max(a,b:uint64):uint64; overload; inline;
  function Max(a,b:single):single; overload; inline;
  function Max(a,b:double):double; overload; inline;
  function Max(a,b,c:integer):integer; overload;
  function Max(a,b,c:single):single; overload;

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

  // Wrap - wrap value into [0, max) range
  function Wrap(value,max:single):single; overload; inline;
  function Wrap(value,max:double):double; overload; inline;

  // Rounding helpers
  function FRound(v:double):integer; inline;  // fast round: 0.5->1, 1.5->2 (slightly biased)
  function PRound(v:double):integer; inline;  // precise round
  function SRound(v:single):integer;          // SSE-accelerated round

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
  function Pow2(e:integer):int64; inline;      // 2^e
  function NextPow2(v:uint64):uint64; inline; // smallest power of 2 >= v
  function Log2i(v:int64):integer;           // ceil(log2(v))

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

  // Check if variant has a value (not unassigned)
  function HasValue(const v:variant):boolean;

  function PtrInside(ptr,base:pointer;size:UIntPtr):boolean; inline; // check if ptr is inside memory block

  var
    // A global shared lock providing very-short-term protection against resource contention
    // via SpinLock/SpinUnlock (without parameters). Do not modify directly!
    globalSpinLock:integer=0;

  procedure SpinLock(var lock:integer); overload;
  procedure SpinLock; overload; inline; // uses globalLock
  procedure SpinUnlock(var lock:integer); overload;
  procedure SpinUnlock; overload; inline; // uses globalLock

  // Stack trace support
  type
    TCallStack = array[0..3] of pointer; // 4 addresses max

    Stack = record
      // Get immediate caller address. For fast caller use: {$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF}
      class function Caller:pointer; static;
      // Capture call stack frames
      class function Trace(var frames:TCallStack; skip:integer=0):integer; static;
    end;

// =============================================================================
// Cross-platform primitives
// =============================================================================

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
// Exception classes
// =============================================================================
type
  Exception = SysUtils.Exception; // reexport

  // Base exception with stack trace support
  EBaseException=class(Exception)
  private
    FAddress:NativeUInt;
  public
    constructor Create(const msg:string); overload;
    constructor Create(const msg:string; fields:array of const); overload;
    property Address:NativeUInt read FAddress;
  end;

  // Warning: abnormal situation which doesn't prevent normal operation
  EWarning=class(EBaseException);
  // Error: program execution is violated, upper level must handle
  EError=class(EBaseException);
  // Fatal error: continuation is impossible, must terminate
  EFatalError=class(EBaseException);

  // Returns e.Message with exception address and call stack (if available)
  function ExceptionMsg(const e:Exception):string; overload;
  // Raise exception with "Not implemented" message
  procedure NotImplemented(msg:string=''); inline;
  procedure NotSupported(msg:string=''); inline;

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
    class function Get(data:cardinal; index:integer):boolean; overload; static; inline;
    class function Get(data:uint64; index:integer):boolean; overload; static; inline;
    class procedure SetBit(var data:byte; index:integer; value:boolean=true); overload; static; inline;
    class procedure SetBit(var data:word; index:integer; value:boolean=true); overload; static; inline;
    class procedure SetBit(var data:cardinal; index:integer; value:boolean=true); overload; static; inline;
    class procedure SetBit(var data:uint64; index:integer; value:boolean=true); overload; static; inline;
    // Bit fields (multi-bit): index - 0-based field position, size - field size in bits (<32)
    class function GetBits(data:cardinal; index,size:integer):cardinal; overload; static;
    class function GetBits(data:uint64; index,size:integer):uint64; overload; static;
    class procedure SetBits(var data:byte; index,size,value:integer); overload; static;
    class procedure SetBits(var data:word; index,size,value:integer); overload; static;
    class procedure SetBits(var data:cardinal; index,size,value:integer); overload; static;
    class procedure SetBits(var data:uint64; index,size,value:integer); overload; static;
  end;

// =============================================================================
// Time scope - high-precision time functions
// =============================================================================
type
  Time=record
    class function Now:TDateTime; static;  // local time (high-precision)
    class function UTC:TDateTime; static;  // UTC time (high-precision)
    class function Stamp:string8; static;   // HH:MM:SS.mmm for logs
    // Get milliseconds since system start (monotonic, no overflow). Better replacement for GetTickCount/GetTickCount64
    class function Ticks:int64; static; inline;
    // Sleep for specified milliseconds
    class procedure Sleep(ms:integer); static; inline;
  end;
  CoreTime = Time; // Alias to avoid name clash with SysUtils.Time etc.

// =============================================================================
// Atomic scope - atomic operations for lock-free synchronization
// =============================================================================
type
  Atomic=record
    // Increment/Decrement - map directly to RTL AtomicIncrement/Decrement
    class function Inc(var target:longint):longint; overload; static; inline;
    class function Dec(var target:longint):longint; overload; static; inline;
    // Add/Sub with custom value - use CmpExchange loop for arbitrary values
    class function Add(var target:longint; value:longint):longint; static; inline;
    class function Sub(var target:longint; value:longint):longint; static; inline;
    // Exchange and CompareExchange - map directly to RTL
    class function Exchange(var target:longint; value:longint):longint; static; inline;
    class function CmpExchange(var target:longint; newValue,comparand:longint):longint; static; inline;
  end;

implementation

uses
  Apus.Conv, DateUtils, Variants,
{$IFDEF MSWINDOWS}
  Windows
{$ENDIF}
{$IFDEF UNIX}
  BaseUnix,
  {$IFDEF LINUX}Linux{$ENDIF}
{$ENDIF};

{$IFDEF MSWINDOWS}
function RtlCaptureStackBackTrace(
  FramesToSkip: Cardinal;
  FramesToCapture: Cardinal;
  BackTrace: Pointer;
  BackTraceHash: PCardinal
): Word; stdcall; external 'kernel32.dll' name 'RtlCaptureStackBackTrace';
{$ENDIF}


// =============================================================================
// Stack scope - stack trace utilities
// =============================================================================

class function Stack.Caller:pointer;
{$IFDEF MSWINDOWS}
begin
  // skip 2 frames: Caller itself + immediate caller
  if RtlCaptureStackBackTrace(2,1,@result,nil)=0 then
    result:=nil;
end;
{$ELSE}
begin
  // skip 2 frames: Caller itself + immediate caller
  result:=get_caller_addr(get_caller_frame(get_frame));
end;
{$ENDIF}

class function Stack.Trace(var frames:TCallStack; skip:integer):integer;
{$IFDEF MSWINDOWS}
begin
  result:=RtlCaptureStackBackTrace(skip,Length(frames),@frames[0],nil);
end;
{$ELSE}
var
  frame:pointer;
  i:integer;
begin
  result:=0;
  frame:=get_frame;
  // skip requested frames
  for i:=0 to skip do
    if frame<>nil then frame:=get_caller_frame(frame);
  // capture stack
  for i:=0 to High(frames) do begin
    if frame=nil then break;
    frames[i]:=get_caller_addr(frame);
    inc(result);
    frame:=get_caller_frame(frame);
  end;
end;
{$ENDIF}

procedure SpinLock(var lock:integer);
begin
  while Atomic.CmpExchange(lock,1,0)<>0 do Time.Sleep(0);
end;

procedure SpinLock; inline;
begin
  while Atomic.CmpExchange(globalSpinLock,1,0)<>0 do Time.Sleep(0);
end;

procedure SpinUnlock(var lock:integer); inline;
begin
  Atomic.Exchange(lock,0);
end;

procedure SpinUnlock; inline;
begin
  Atomic.Exchange(globalSpinLock,0);
end;

// =============================================================================
// Cross-platform primitives implementation
// =============================================================================

function GetCurrentThreadID:{$IFDEF MSWINDOWS}cardinal{$ELSE}TThreadID{$ENDIF}; inline;
begin
{$IFDEF MSWINDOWS}
  result:=windows.GetCurrentThreadId;
{$ELSE}
  result:=system.GetCurrentThreadID;
{$ENDIF}
end;

{ Atomic }

class function Atomic.Inc(var target:longint):longint;
begin
 {$IF Declared(AtomicIncrement)}
 result:=AtomicIncrement(target);
 {$ELSE}
 result:=InterlockedIncrement(target);
 {$ENDIF}
end;

class function Atomic.Dec(var target:longint):longint;
begin
 {$IF Declared(AtomicDecrement)}
 result:=AtomicDecrement(target);
 {$ELSE}
 result:=InterlockedDecrement(target);
 {$ENDIF}
end;

class function Atomic.Add(var target:longint; value:longint):longint;
var
 old:longint;
begin
 repeat
  old:=target;
 until CmpExchange(target,old+value,old)=old;
 result:=old+value;
end;

class function Atomic.Sub(var target:longint; value:longint):longint;
var
 old:longint;
begin
 repeat
  old:=target;
 until CmpExchange(target,old-value,old)=old;
 result:=old-value;
end;

class function Atomic.Exchange(var target:longint; value:longint):longint;
begin
 {$IF Declared(AtomicExchange)}
 result:=AtomicExchange(target,value);
 {$ELSE}
 result:=InterlockedExchange(target,value);
 {$ENDIF}
end;

class function Atomic.CmpExchange(var target:longint; newValue,comparand:longint):longint;
begin
 {$IF Declared(AtomicCmpExchange)}
 result:=AtomicCmpExchange(target,newValue,comparand);
 {$ELSE}
 result:=InterlockedCompareExchange(target,newValue,comparand);
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
var
  dummy:longint;
begin
  {$IF DEFINED(CPUX86) OR DEFINED(CPUX64)}
  asm mfence end;
  {$ELSE}
  // Fallback full barrier via atomic read-modify-write operation.
  dummy:=0;
  Atomic.CmpExchange(dummy,0,0);
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

// =============================================================================
// Standalone functions implementation
// =============================================================================

function Min(a,b:integer):integer;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:cardinal):cardinal;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:int64):int64;
begin
  if a<b then result:=a else result:=b;
end;

function Min(a,b:uint64):uint64;
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

function Min(a,b,c:single):single;
begin
  result:=a;
  if b<result then result:=b;
  if c<result then result:=c;
end;

function Max(a,b:integer):integer;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:cardinal):cardinal;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:int64):int64;
begin
  if a>b then result:=a else result:=b;
end;

function Max(a,b:uint64):uint64;
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

function Max(a,b,c:single):single;
begin
  result:=a;
  if b>result then result:=b;
  if c>result then result:=c;
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

function Wrap(value,max:single):single;
begin
  if (value>=0) and (value<max) then exit(value); // fast path: already in range
  result:=frac(value/max)*max;
  if result<0 then result:=result+max;
end;

function Wrap(value,max:double):double;
begin
  if (value>=0) and (value<max) then exit(value); // fast path: already in range
  result:=frac(value/max)*max;
  if result<0 then result:=result+max;
end;

function FRound(v:double):integer;
const
  EPSILON=0.00001;
begin
  result:=round(v+EPSILON);
end;

function PRound(v:double):integer;
begin
  if v>0 then result:=trunc(v+0.5)
   else result:=trunc(v-0.5);
end;

function SRound(v:single):integer;
{$IFDEF CPUX86ASM}
const
  const_0_5:single=0.5;
asm
  {$IFDEF CPUx64}
  addss xmm0,[const_0_5+rip]
  roundss xmm0,xmm0,1
  cvtss2si rax,xmm0
  {$ELSE}
  movss xmm0,v
  addss xmm0,const_0_5
  roundss xmm0,xmm0,1
  cvtss2si eax,xmm0
  {$ENDIF}
end;
{$ELSE}
begin
  result:=trunc(v+0.5);
end;
{$ENDIF}

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

function NextPow2(v:uint64):uint64;
begin
  if v<=1 then begin
    result:=1;
    exit;
  end;
  // Round up to next power of two (64-bit). Overflow returns 0.
  dec(v);
  v:=v or (v shr 1);
  v:=v or (v shr 2);
  v:=v or (v shr 4);
  v:=v or (v shr 8);
  v:=v or (v shr 16);
  v:=v or (v shr 32);
  result:=v+1;
end;

function Pow2(e:integer):int64;
begin
  result:=0;
  // int64 signed range: 2^63 is not representable as positive value
  if (e>=0) and (e<63) then
    result:=int64(1) shl e;
end;

function Log2i(v:int64):integer;
var
  u:uint64;
begin
  if v<=1 then Exit(0);
  u:=uint64(v-1);
  result:=0;
  while u>0 do begin
    inc(result);
    u:=u shr 1;
  end;
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

function HasValue(const v:variant):boolean;
begin
  result:=not (VarIsEmpty(v) or VarIsNull(v));
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
  result:=(val+UIntPtr(align)-1) and (not UIntPtr(align-1));
end;

function AlignUp(val:pointer;align:cardinal):pointer;
begin
  result:=pointer((UIntPtr(val)+align-1) and not (align-1));
end;

function AlignDown(val:UIntPtr;align:cardinal):UIntPtr;
begin
  result:=val and (not UIntPtr(align-1));
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
// SSE-optimized FillD implementation. data MUST be aligned by 4 byte
procedure FillD_SSE(var data; count: UIntPtr; value: cardinal); forward;

{$IFDEF CPUX64}
procedure FillD_SSE(var data; count: UIntPtr; value: cardinal); assembler;  {$IFDEF FPC} nostackframe; {$ENDIF}
// Windows x64 calling convention: RCX=data, RDX=count, R8=value
// Unix x64 calling convention: RDI=data, RSI=count, RDX=value
asm
  {$IFDEF MSWINDOWS}
  // Windows x64: RCX=data, RDX=count, R8=value
  // RDI is non-volatile, must preserve
  push rdi
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

  // Align to 16-byte boundary (address already aligned on 4, max 3 dwords to write)
@unaligned:
  test rdi, 15
  jz @aligned
  mov [rdi], eax
  add rdi, 4
  dec rcx
  jz @done            // exit if count exhausted
  jmp @unaligned

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
  {$IFDEF MSWINDOWS}
  pop rdi
  {$ENDIF}
  ret
end;
{$ELSE}
// x86 SSE implementation
procedure FillD_SSE(var data; count: UIntPtr; value: cardinal); assembler;  {$IFDEF FPC} nostackframe; {$ENDIF}
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

  // Align to 16-byte boundary (address already aligned on 4, max 3 dwords to write)
@unaligned:
  test edi, 15
  jz @aligned
  mov [edi], ebx
  add edi, 4
  dec ecx
  jz @done            // exit if count exhausted
  jmp @unaligned

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
  // Use SSE optimization only if:
  // - SSE available and count is large enough (>= 16)
  // - Address is aligned on dword boundary (unaligned SSE is complex and rare)
  if cpuFeatures.SSE and (count>=16) and (UIntPtr(@data) and 3=0) then
    FillD_SSE(data,count,value)
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

class function Bits.Get(data:uint64;index:integer):boolean;
begin
  result:=data and (uint64(1) shl index)<>0;
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

const
  BITS_FIELD_MASK:array[0..32] of cardinal=(0,1,3,7,15,31,63,127,255,
    $1FF,$3FF,$7FF,$FFF,$1FFF,$3FFF,$7FFF,$FFFF,
    $1FFFF,$3FFFF,$7FFFF,$FFFFF,$1FFFFF,$3FFFFF,$7FFFFF,$FFFFFF,
    $1FFFFFF,$3FFFFFF,$7FFFFFF,$FFFFFFF,$1FFFFFFF,$3FFFFFFF,$7FFFFFFF,$FFFFFFFF);

class function Bits.GetBits(data:cardinal;index,size:integer):cardinal;
begin
  ASSERT((size>=0) and (size<=32));
  ASSERT((index>=0) and (index+size<=32));
  result:=(data shr index) and BITS_FIELD_MASK[size];
end;

class function Bits.GetBits(data:uint64; index,size:integer):uint64;
begin
  ASSERT((size>=0) and (size<=32));
  ASSERT((index>=0) and (index+size<=64));
  result:=(data shr index) and BITS_FIELD_MASK[size];
end;

class procedure Bits.SetBits(var data:byte;index,size,value:integer);
var
  fieldMask:byte;
begin
  ASSERT((size>=0) and (size<=8));
  ASSERT((index>=0) and (index+size<=8));
  fieldMask:=byte(BITS_FIELD_MASK[size] shl index);
  data:=(data and not fieldMask) or byte((cardinal(value) and BITS_FIELD_MASK[size]) shl index);
end;

class procedure Bits.SetBits(var data:word;index,size,value:integer);
var
  fieldMask:word;
begin
  ASSERT((size>=0) and (size<=16));
  ASSERT((index>=0) and (index+size<=16));
  fieldMask:=word(BITS_FIELD_MASK[size] shl index);
  data:=(data and not fieldMask) or word((cardinal(value) and BITS_FIELD_MASK[size]) shl index);
end;

class procedure Bits.SetBits(var data:cardinal;index,size,value:integer);
var
  fieldMask:cardinal;
begin
  ASSERT((size>=0) and (size<=32));
  ASSERT((index>=0) and (index+size<=32));
  fieldMask:=BITS_FIELD_MASK[size] shl index;
  data:=(data and not fieldMask) or ((cardinal(value) and BITS_FIELD_MASK[size]) shl index);
end;

class procedure Bits.SetBits(var data:uint64;index,size,value:integer);
var
  fieldMask:uint64;
begin
  ASSERT((size>=0) and (size<=32));
  ASSERT((index>=0) and (index+size<=64));
  fieldMask:=uint64(BITS_FIELD_MASK[size]) shl index;
  data:=(data and not fieldMask) or ((uint64(value) and uint64(BITS_FIELD_MASK[size])) shl index);
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

// =============================================================================
// EBaseException
// =============================================================================
constructor EBaseException.Create(const msg:string);
var
  frames:TCallStack;
  count,i:integer;
  stackStr:string;
begin
  // capture call stack (skip=1 to skip constructor itself)
  count:=Stack.Trace(frames,1);
  if count>0 then begin
    FAddress:=NativeUInt(frames[0]);
    stackStr:='[';
    for i:=0 to count-1 do begin
      stackStr:=stackStr+Conv.ToStr(frames[i]);
      if i<count-1 then stackStr:=stackStr+'->';
    end;
    stackStr:=stackStr+'] ';
  end else begin
    FAddress:=0;
    stackStr:='';
  end;
  inherited Create(stackStr+msg);
end;

constructor EBaseException.Create(const msg:string; fields:array of const);
begin
  Create(Format(msg,fields));
end;

function ExceptionMsg(const e:Exception):string;
begin
  if e is EBaseException then
    result:=e.Message  // already contains stack trace
  else
    result:='['+Conv.ToStr(ExceptAddr)+'] '+e.Message;
end;

procedure NotImplemented(msg:string='');
begin
  raise EError.Create('Not implemented: '+msg);
end;

procedure NotSupported(msg:string='');
begin
  raise EError.Create('Not supported: '+msg);
end;

// =============================================================================
// Time scope implementation
// =============================================================================
{$IFDEF MSWINDOWS}
var
  preciseTimeSupport:integer=0; // 0=unknown, 1=supported, -1=not supported
  GetSystemTimePreciseAsFileTime:procedure(out time:TFileTime); stdcall;

function GetPreciseUTCFileTime(out ft:TFileTime):boolean;
var
  p:pointer;
begin
  if preciseTimeSupport=0 then begin
    p:=GetProcAddress(GetModuleHandle('kernel32.dll'),'GetSystemTimePreciseAsFileTime');
    if p<>nil then begin
      preciseTimeSupport:=1; // supported
      GetSystemTimePreciseAsFileTime:=p;
    end else
      preciseTimeSupport:=-1; // not supported
  end;

  if preciseTimeSupport>0 then begin
    GetSystemTimePreciseAsFileTime(ft);
    result:=true;
  end else begin
    GetSystemTimeAsFileTime(ft);
    result:=false;
  end;
end;
{$ENDIF}

class function Time.UTC:TDateTime;
{$IFDEF MSWINDOWS}
var
  ft:TFileTime;
  st:TSystemTime;
begin
  GetPreciseUTCFileTime(ft);
  FileTimeToSystemTime(ft,st);
  result:=SystemTimeToDateTime(st);
end;
{$ELSE}
{$IFDEF UNIX}
begin
  result:=LocalTimeToUniversal(SysUtils.Now);
end;
{$ELSE}
{$IFDEF IOS}
begin
  result:=SysUtils.Now+(NSTimeZone.localTimeZone.secondsFromGMT)/86400;
end;
{$ELSE}
var
  st:TSystemTime;
begin
  GetSystemTime(st);
  result:=SystemTimeToDateTime(st);
end;
{$ENDIF}
{$ENDIF}
{$ENDIF}

class function Time.Now:TDateTime;
{$IFDEF MSWINDOWS}
var
  ft,localFt:TFileTime;
  st:TSystemTime;
begin
  GetPreciseUTCFileTime(ft);
  FileTimeToLocalFileTime(ft,localFt);
  FileTimeToSystemTime(localFt,st);
  result:=SystemTimeToDateTime(st);
end;
{$ELSE}
begin
  result:=SysUtils.Now;
end;
{$ENDIF}

class function Time.Stamp:string8;
{$IFDEF MSWINDOWS}
var
  st:TSystemTime;
  ft:TFileTime;
begin
  GetPreciseUTCFileTime(ft);
  FileTimeToSystemTime(ft,st);
  // format: HH:MM:SS.mmm
  result:=chr(48+st.wHour div 10)+chr(48+st.wHour mod 10)+':'+
          chr(48+st.wMinute div 10)+chr(48+st.wMinute mod 10)+':'+
          chr(48+st.wSecond div 10)+chr(48+st.wSecond mod 10)+'.'+
          chr(48+st.wMilliseconds div 100)+chr(48+(st.wMilliseconds div 10) mod 10)+chr(48+st.wMilliseconds mod 10);
end;
{$ELSE}
var
  hour,minute,second,msec:word;
begin
  DecodeTime(Time.UTC,hour,minute,second,msec);
  // format: HH:MM:SS.mmm
  result:=chr(48+hour div 10)+chr(48+hour mod 10)+':'+
          chr(48+minute div 10)+chr(48+minute mod 10)+':'+
          chr(48+second div 10)+chr(48+second mod 10)+'.'+
          chr(48+msec div 100)+chr(48+(msec div 10) mod 10)+chr(48+msec mod 10);
end;
{$ENDIF}

class function Time.Ticks:int64;
{$IFDEF UNIX}
var ts:TTimeSpec;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  result:=Windows.GetTickCount64;
  {$ELSE}
  clock_gettime(CLOCK_MONOTONIC,@ts);
  result:=int64(ts.tv_sec)*1000+ts.tv_nsec div 1000000;
  {$ENDIF}
end;

class procedure Time.Sleep(ms:integer);
begin
  {$IFDEF MSWINDOWS}
  Windows.Sleep(ms);
  {$ELSE}
  SysUtils.Sleep(ms);
  {$ENDIF}
end;


initialization
  CheckCPU;
  InitTimer;
end.


-- Apus.Types:

// This unit contains some useful types (except simple types and classes) and helpers
// The structures defined here are not thread-safe

// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.Types;
interface
uses Types,
  Apus.Core
  {$IFDEF MSWINDOWS},Windows{$ENDIF};

type
  TPoint = Types.TPoint;
  TRect = Types.TRect;

  // Spline function: f(x0)=y0, f(x1)=y1, f(x)=?
  TSplineFunc=function(x,x0,x1,y0,y1:single):single;

  TIntRange=record
    min,max:integer;
    procedure Init(min,max:integer);
    function Width:integer; // max-min
    function Rand:integer;
  end;

  TFloatRange=record
    min,max:single;
    procedure Init(min,max:single);
    function Width:single; // max-min
    function Rand:single;
  end;

  // Helper type for custom arrays
  TArray<T>=record
    items:array of T;
    procedure Add(element:T);
    procedure Insert(element:T;index:integer);
    procedure Remove(element:T;keepOrder:boolean=true);
    function Find(element:T):integer;
    function Contains(element:T):boolean;
    function Last:T;
    function IsEmpty:boolean;
    function Count:integer;
    function Pop:T; // return the last element and remove it
  end;

  // "name = value" string pair
  TNameValue=record
    name,value:string8;
    procedure Init(name,value:string8);
    procedure InitFrom(st:string8;splitter:string8='='); // split and trim
    function Named(st:string8):boolean;
    function GetInt:int64;
    function GetFloat:double;
    function GetDate:TDateTime;
    function GetBool:boolean; // true if value is "y", "yes", "true", "on", "1"; false if "n", "no", "false", "off", "0"
    function Join(separator:string8='='):string8; // convert back to "name=value"
  end;

  // List of "name=value" pairs
  // If you have many items, consider using hash instead
  TNameValueList=record
    items:array of TNameValue;
    // Init from a string 'name1=value1;..;nameN=valueN'
    constructor Init(st:string8;itemSeparator:string8=';';valueSeparator:string8='='); overload;
    // Init from array of strings 'name=value'
    constructor Init(list:Strings8;valueSeparator:string8='='); overload;
    function Save(itemSeparator:string8=';';valueSeparator:string8='='):string8;
    function Count:integer;
    function HasName(name:string8):boolean; // check if there is an item with given name
    function Find(name:string8):integer;
    procedure Add(item:TNameValue); overload;
    procedure Add(list:TNameValueList); overload;
  private
    function GetItem(name:String8):string8;
    procedure SetItem(name:string8;value:string8);
  public
    property Item[name:string8]:string8 read GetItem write SetItem;
  end;

  // Helper object represents in-memory binary buffer, doesn't own data
  // Useful to pass arbitrary data instead of pointer:size pair
  TBuffer=record
    data:PByte;   // pointer to the whole buffer data
    readPos:PByte; // current reading position
    size:integer; // total data size
    constructor Create(sour:pointer;sizeInBytes:integer);
    constructor CreateFrom(sour:pointer;sizeInBytes:integer); overload;
    constructor CreateFrom(var sour;sizeInBytes:integer); overload;
    constructor CreateFrom(bytes:ByteArray); overload;
    constructor CreateFrom(st:String8); overload;
    function Slice(length:integer;advance:boolean=false):TBuffer; overload;
    function Slice(from,length:integer):TBuffer; overload;
    function ReadByte:byte;
    function ReadBool:boolean;
    function ReadWord:word;
    function ReadInt:integer;
    function ReadUInt:cardinal;
    function ReadFloat:single;
    function ReadDouble:double;
    function ReadString:String8;
    function ReadFlex:cardinal; // read flexible (multibyte) unsigned integer
    procedure Skip(numBytes:integer); // advance read pos by
    procedure Seek(pos:integer);
    procedure Read(var dest;numBytes:integer);
    function BytesLeft:integer; inline;
    function CurrentPos:integer; inline;
  end;

{  // In-memory binary buffer used to read bit fields
  TBitBuffer=record
    data:PByte;
    size:integer;
    constructor Create(sour:pointer;sizeInBytes:integer);
    constructor CreateFrom(buffer:TBuffer);
    function Read(numBits:integer):cardinal;
  private
    buf:cardinal;
  end;}

  TWriteBuffer=record
    position:integer;
    constructor Init(expectedSize:integer);
    procedure Reset(newSize:integer);
    procedure Write(var item;numBytes:integer); overload;
    procedure Write(var buf:TBuffer); overload;
    procedure WriteByte(b:byte); inline;
    procedure WriteBool(b:boolean); inline;
    procedure WriteWord(w:word); inline;
    procedure WriteInt(i:integer); inline;
    procedure WriteUInt(c:cardinal); inline;
    procedure WriteFloat(f:single); inline;
    procedure WriteDouble(d:double); inline;
    procedure WriteFlex(c:cardinal);
    procedure WriteStr(s:String8);
    procedure Seek(pos:integer);
    procedure Skip(bytes:integer);
    function AsBuffer:TBuffer;
  private
    data:ByteArray;
  end;
