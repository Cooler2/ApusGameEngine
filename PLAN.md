# Refactoring Plan

## Goal
Refactor Base library into clean dependency layers, starting with Layer 0.

## Layer 0: Apus.Core

Single module with no Apus dependencies, minimal RTL dependencies.

### Contents

**Types:**
- `Char8, String8, Char16, String16, String32` - character/string type aliases
- `UIntPtr, PtrUInt` - pointer-sized unsigned integers
- `DWORD, QWORD` - integer type aliases
- `ByteArray, WordArray, IntArray, UIntArray, SingleArray, FloatArray, PointerArray` - array types
- `StringArray8, StringArray16, StringArray` - string arrays
- `ShortStr` - short string[31]
- `TProcedure, TObjProcedure` - procedure types
- `TSplineFunc` - spline function type
- `m128` - 128-bit vector record
- `half` - 16-bit float with implicit conversion

**CPU detection:**
- `TCPUType` enum (X86, ARM)
- `CPU_TYPE`, `CPU_BIT` constants
- `cpuFeatures:TCPUFeatures` - global record with feature flags (MMX, SSE, SSE2, SSE3, AVX, AVX2, AES, etc.)

**Math functions:**
- Min/Max (integer, single, double; 2 and 3 args)
- Clamp, Sat, Lerp, LerpC
- Swap, Toggle
- Pow2, GetPow2, Log2i
- IsNaN (single, double)
- FRound, PRound, SRound, FastFloor (to add)
- Ratio, FastInvSqrt, Wrap (to add)
- LinearMix (to add)
- PseudoRand (to add)

**Memory operations:** `Mem` scope
- Clear, Fill, FillW, FillD, FillQ, FillF
- Copy, Shift, IsZero

**Bit manipulation:** `Bits` scope
- HasAll, HasAny, SetFlag, Clear, Modify
- Get, SetBit (byte, word, cardinal, uint64)

**Alignment:**
- AlignUp, AlignDown, IsAligned (UIntPtr and pointer versions)

**Pointers:**
- PtrInside

## Layer 0: Apus.System (future)

Threading and synchronization primitives.

- `TMyCriticalSection` + Init/Delete/Enter/Leave
- `TSRWLock`
- `SpinLock`
- Thread registration

**Note:** Depends on platform APIs. May need simplified version without GetCaller dependency.

## Stays in Apus.Types (Layer 1+)

These types have methods with dependencies or are not simple:
- `TIntRange, TFloatRange` - use Random()
- `TNameValue, TNameValueList` - use string parsing from Common
- `TBuffer, TWriteBuffer` - binary buffer helpers
- `TMyCriticalSection, TSRWLock` - threading primitives
- `TArray<T>` - generic container

## Progress

- [x] Create Apus.Core with basic math, memory, bits
- [x] Add alignment functions
- [x] Add tests (TestCore.dpr)
- [x] Merge Apus.CPU into Apus.Core
- [x] Add basic types from Apus.Types (simple ones only)
- [x] Add CPU_TYPE/CPU_BIT constants
- [ ] Add more math functions (FRound, etc.)
- [ ] Update modules to use Apus.Core instead of Apus.Common for basic functions
