
{*
 * This is a guess for the cacheline size used for padding.
 * Most x86 processors have a 64 byte cache line.
 * The 64-bit PowerPC processors have a 128 byte cache line.
 * We'll use the larger value to be generally safe.
 *}
const
	SDL_CACHELINE_SIZE = 128;

{**
 * This function returns the number of CPU cores available.
 *}
function SDL_GetCPUCount(): cint; cdecl;
	 external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetCPUCount' {$ENDIF} {$ENDIF};

{**
 * This function returns the L1 cache line size of the CPU.
 *
 * This is useful for determining multi-threaded structure padding
 * or SIMD prefetch sizes.
 *}
function SDL_GetCPUCacheLineSize(): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetCPUCacheLineSize' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has the RDTSC instruction.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasRDTSC(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasRDTSC' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has AltiVec features.
 * 
 * This always returns false on CPUs that aren't using PowerPC
 * instruction sets.
 *}
function SDL_HasAltiVec(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasAltiVec' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has MMX features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasMMX(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasMMX' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has 3DNow! features.
 *
 * This always returns false on CPUs that aren't using AMD instruction sets.
 *}
function SDL_Has3DNow(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_Has3DNow' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has SSE features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasSSE(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasSSE' {$ENDIF} {$ENDIF};

{**
 *  This function returns true if the CPU has SSE2 features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasSSE2(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasSSE2' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has SSE3 features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasSSE3(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasSSE3' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has SSE4.1 features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasSSE41(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasSSE41' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has SSE4.2 features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasSSE42(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasSSE42' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has AVX features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasAVX(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasAVX' {$ENDIF} {$ENDIF};

{**
 * This function returns true if the CPU has AVX2 features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasAVX2(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasAVX2' {$ENDIF} {$ENDIF};

{**
 * Determine whether the CPU has AVX-512F (foundation) features.
 *
 * This always returns false on CPUs that aren't using Intel instruction sets.
 *}
function SDL_HasAVX512F(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasAVX512F' {$ENDIF} {$ENDIF};

{**
 * Determine whether the CPU has ARM SIMD (ARMv6) features.
 * This is different from ARM NEON, which is a different instruction set.
 *
 * This always returns false on CPUs that aren't using ARM instruction sets.
 *}
function SDL_HasARMSIMD(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasARMSIMD' {$ENDIF} {$ENDIF};

{**
 * Determine whether the CPU has NEON (ARM SIMD) features.
 *
 * This always returns false on CPUs that aren't using ARM instruction sets.
 *}
function SDL_HasNEON(): TSDL_Bool; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasNEON' {$ENDIF} {$ENDIF};

{**
 * This function returns the amount of RAM configured in the system, in MB.
 *}
function SDL_GetSystemRAM(): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetSystemRAM' {$ENDIF} {$ENDIF};

{**
 * Report the alignment this system needs for SIMD allocations.
 *
 * This will return the minimum number of bytes to which a pointer must be
 * aligned to be compatible with SIMD instructions on the current machine. For
 * example, if the machine supports SSE only, it will return 16, but if it
 * supports AVX-512F, it'll return 64 (etc). This only reports values for
 * instruction sets SDL knows about, so if your SDL build doesn't have
 * SDL_HasAVX512F(), then it might return 16 for the SSE support it sees and
 * not 64 for the AVX-512 instructions that exist but SDL doesn't know about.
 * Plan accordingly.
 *}
function SDL_SIMDGetAlignment(): csize_t; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SIMDGetAlignment' {$ENDIF} {$ENDIF};

{*
 * Allocate memory in a SIMD-friendly way.
 *
 * This will allocate a block of memory that is suitable for use with SIMD
 * instructions. Specifically, it will be properly aligned and padded for the
 * system's supported vector instructions.
 *
 * The memory returned will be padded such that it is safe to read or write an
 * incomplete vector at the end of the memory block. This can be useful so you
 * don't have to drop back to a scalar fallback at the end of your SIMD
 * processing loop to deal with the final elements without overflowing the
 * allocated buffer.
 *
 * You must free this memory with SDL_FreeSIMD(), not free() or SDL_free().
 *
 * Note that SDL will only deal with SIMD instruction sets it is aware of; for
 * example, SDL 2.0.8 knows that SSE wants 16-byte vectors (SDL_HasSSE()), and
 * AVX2 wants 32 bytes (SDL_HasAVX2()), but doesn't know that AVX-512 wants
 * 64. To be clear: if you can't decide to use an instruction set with an
 * SDL_Has*() function, don't use that instruction set with memory allocated
 * through here.
 *
 * SDL_AllocSIMD(0) will return a non-NULL pointer, assuming the system isn't
 * out of memory, but you are not allowed to dereference it (because you only
 * own zero bytes of that buffer).
 *}
function SDL_SIMDAlloc(const len: csize_t): Pointer; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SIMDAlloc' {$ENDIF} {$ENDIF};

{**
 * Reallocate memory obtained from SDL_SIMDAlloc.
 *
 * It is not valid to use this function on a pointer from anything but
 * SDL_SIMDAlloc(). It can't be used on pointers from SDL_malloc, GetMem, etc.
 *}
function SDL_SIMDRealloc(mem: Pointer; const len: csize_t): Pointer; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SIMDRealloc' {$ENDIF} {$ENDIF};

{**
 * Deallocate memory obtained from SDL_SIMDAlloc.
 *
 * It is not valid to use this function on a pointer from anything but
 * SDL_SIMDAlloc() or SDL_SIMDRealloc(). It can't be used on pointers from
 * SDL_malloc, GetMem, etc.
 *
 * However, SDL_SIMDFree(NIL) is a legal no-op.
 *
 * The memory pointed to by `mem` is no longer valid for access upon return,
 * and may be returned to the system or reused by a future allocation. The
 * pointer passed to this function is no longer safe to dereference once this
 * function returns, and should be discarded.
 *}
procedure SDL_SIMDFree(mem: Pointer); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SIMDFree' {$ENDIF} {$ENDIF};

