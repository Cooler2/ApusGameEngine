//types from SDL_stdinc.h

{ SDL-For-Pascal: A lot of the functions are missing. Some functions are useless
                  if working with Pascal (e. g. memory management functions),
                  others could be useful (e. g. math functions).

  TODO: Investigate header file and translate potentially useful functions. }

type
  PPSDL_Bool = ^PSDL_Bool;
  PSDL_Bool = ^TSDL_Bool;
  TSDL_Bool = cbool;

const
  SDL_FALSE = TSDL_Bool(0);
  SDL_TRUE  = TSDL_Bool(1);

  SDL_MAX_SINT8 = High(cint8);
  SDL_MIN_SINT8 = Low(cint8);

  SDL_MAX_UINT8 = High(cuint8);
  SDL_MIN_UINT8 = Low(cuint8);

  SDL_MAX_SINT16 = High(cint16);
  SDL_MIN_SINT16 = Low(cint16);

  SDL_MAX_UINT16 = High(cuint16);
  SDL_MIN_UINT16 = Low(cuint16);

  SDL_MAX_SINT32 = High(cint32);
  SDL_MIN_SINT32 = Low(cint32);

  SDL_MAX_UINT32 = High(cuint32);
  SDL_MIN_UINT32 = Low(cuint32);

  {$IFDEF Has_Int64}
    SDL_MAX_SINT64 = High(cint64);
    SDL_MIN_SINT64 = Low(cint64);

    SDL_MAX_UINT64 = High(cuint64);
    SDL_MIN_UINT64 = Low(cuint64);
  {$ELSE}
    SDL_MAX_SINT64: cuint64 = (hi: SDL_MAX_SINT32; lo: SDL_MAX_UINT32);
    SDL_MIN_SINT64: cuint64 = (hi: SDL_MIN_SINT32; lo: 0);

    SDL_MAX_UINT64: cuint64 = (hi: SDL_MAX_UINT32; lo: SDL_MAX_UINT32);
    SDL_MIN_UINT64: cuint64 = (hi: 0;              lo: 0);
  {$ENDIF}

  SDL_FLT_EPSILON = cfloat(1.1920928955078125e-07);

type
  PPSDL_malloc_func = ^PSDL_malloc_func;
  PSDL_malloc_func = ^TSDL_malloc_func;
  TSDL_malloc_func = function(size: csize_t): Pointer; cdecl;

  PPSDL_calloc_func = ^PSDL_calloc_func;
  PSDL_calloc_func = ^TSDL_calloc_func;
  TSDL_calloc_func = function(nmemb, size: csize_t): Pointer; cdecl;

  PPSDL_realloc_func = ^PSDL_realloc_func;
  PSDL_realloc_func = ^TSDL_realloc_func;
  TSDL_realloc_func = function(mem: Pointer; size: csize_t): Pointer; cdecl;

  PPSDL_free_func = ^PSDL_free_func;
  PSDL_free_func = ^TSDL_free_func;
  TSDL_free_func = procedure(mem: Pointer); cdecl;

{**
 * Get the original set of SDL memory functions
 *
 * \since This function is available since SDL 2.24.0.
 *}
procedure SDL_GetOriginalMemoryFunctions(
  malloc_func: PSDL_malloc_func;
  calloc_func: PSDL_calloc_func;
  realloc_func: PSDL_realloc_func;
  free_func: PSDL_free_func
); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetOriginalMemoryFunctions' {$ENDIF} {$ENDIF};

(**
 * Get the current set of SDL memory functions
 *
 * \since This function is available since SDL 2.0.7.
 *)
procedure SDL_GetMemoryFunctions(
  malloc_func: PSDL_malloc_func;
  calloc_func: PSDL_calloc_func;
  realloc_func: PSDL_realloc_func;
  free_func: PSDL_free_func
); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetMemoryFunctions' {$ENDIF} {$ENDIF};

(**
 * Replace SDL's memory allocation functions with a custom set
 *
 * \since This function is available since SDL 2.0.7.
 *)
function SDL_SetMemoryFunctions(
  malloc_func: TSDL_malloc_func;
  calloc_func: TSDL_calloc_func;
  realloc_func: TSDL_realloc_func;
  free_func: TSDL_free_func
): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetMemoryFunctions' {$ENDIF} {$ENDIF};

(**
 * Get the number of outstanding (unfreed) allocations
 *
 * \since This function is available since SDL 2.0.7.
 *)
function SDL_GetNumAllocations(): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetNumAllocations' {$ENDIF} {$ENDIF};

(**
 * Allocate a block of memory. The memory is *not* initialized.
 *)
function SDL_malloc(size: csize_t): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_malloc' {$ENDIF} {$ENDIF};

(**
 * Allocate a block of memory that can fit an array of nmemb elements, each of given size.
 * The memory is initialized by setting every byte to 0.
 *)
function SDL_calloc(nmemb, size: csize_t): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_calloc' {$ENDIF} {$ENDIF};

(**
 * Resize a block of memory allocated previously with SDL_malloc() or SDL_calloc().
 *
 * The returned pointer may or may not be the same as the original pointer.
 * If the new size is larger than the old size, any new memory will *not* be initialized.
 *)
function SDL_realloc(mem: Pointer; size: csize_t): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_realloc' {$ENDIF} {$ENDIF};

(**
 * Free memory returned by functions like SDL_GetBasePath(), SDL_GetPrefPath(), etc.
 *
 * Calling SDL_free() on the same pointer twice is undefined behaviour and may cause
 * your program to crash or behave in unexpected ways.
 *)
procedure SDL_free(mem: Pointer); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_free' {$ENDIF} {$ENDIF};



{*** --- Character functions --- ***

SDL2-for-Pascal: All comments are added by us and not found in the include file.}


(**
 * Check if the provided ASCII character is an alphabetic character (a letter).
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_isalpha(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isalpha' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is an alphanumeric character.
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_isalnum(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isalnum' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a blank character (a space or a tab).
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_isblank(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isblank' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a control character.
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_iscntrl(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_iscntrl' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a decimal digit.
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_isdigit(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isdigit' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a hexadecimal digit.
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_isxdigit(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isxdigit' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is any printable character
 * which is not a space or an alphanumeric character.
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_ispunct(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ispunct' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a whitespace character.
 * This set includes the following characters: space,
 * form feed (FF), newline/line feed (LF), carriage return (CR),
 * horizontal tab (HT), vertical tab (VT).
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_isspace(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isspace' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is an uppercase letter.
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.12.
 *)
function SDL_isupper(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isupper' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a lowercase letter.
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.12.
 *)
function SDL_islower(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_islower' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a printable character (including space).
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_isprint(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isprint' {$ENDIF} {$ENDIF};

(**
 * Check if the provided ASCII character is a printable character (excluding space).
 *
 * \returns 1 if the check passes, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_isgraph(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_isgraph' {$ENDIF} {$ENDIF};

(**
 * If the given ASCII character is a lowercase letter, converts it to uppercase.
 * Otherwise returns the original value.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_toupper(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_toupper' {$ENDIF} {$ENDIF};

(**
 * If the given ASCII character is an uppercase letter, converts it to lowercase.
 * Otherwise returns the original value.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_tolower(x: cint):cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_tolower' {$ENDIF} {$ENDIF};



(*** --- Math functions --- ***)


(**
 * Calculate the arc cosine of x;
 * that is, the value (in radians) whose cosine equals x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_acos(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_acos' {$ENDIF} {$ENDIF};

(**
 * Calculate the arc cosine of x;
 * that is, the value (in radians) whose cosine equals x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_acosf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_acosf' {$ENDIF} {$ENDIF};

(**
 * Calculate the arc sine of x;
 * that is, the value (in radians) whose sine equals x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_asin(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_asin' {$ENDIF} {$ENDIF};

(**
 * Calculate the arc sine of x;
 * that is, the value (in radians) whose sine equals x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_asinf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_asinf' {$ENDIF} {$ENDIF};

(**
 * Calculate the arc tangent of x;
 * that is, the value (in radians) whose tangent equals x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_atan(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_atan' {$ENDIF} {$ENDIF};

(**
 * Calculate the arc tangent of x;
 * that is, the value (in radians) whose tangent equals x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_atanf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_atanf' {$ENDIF} {$ENDIF};

(**
 * Calculate the arc tangent of y/x, using the signs of the two arguments
 * to determine the quadrant of the result.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_atan2(y, x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_atan2' {$ENDIF} {$ENDIF};

(**
 * Calculate the arc tangent of y/x, using the signs of the two arguments
 * to determine the quadrant of the result.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_atan2f(y, x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_atan2f' {$ENDIF} {$ENDIF};

(**
 * Calculate the smallest integral value that is not less than x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_ceil(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ceil' {$ENDIF} {$ENDIF};

(**
 * Calculate the smallest integral value that is not less than x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_ceilf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ceilf' {$ENDIF} {$ENDIF};

(**
 * Return a number whose absolute value matches that of x,
 * but the sign matches that of y.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_copysign(x, y: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_copysign' {$ENDIF} {$ENDIF};

(**
 * Return a number whose absolute value matches that of x,
 * but the sign matches that of y.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_copysignf(x, y: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_copysignf' {$ENDIF} {$ENDIF};

(**
 * Calculate the cosine of x, where x is given in radians.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_cos(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_cos' {$ENDIF} {$ENDIF};

(**
 * Calculate the cosine of x, where x is given in radians.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_cosf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_cosf' {$ENDIF} {$ENDIF};

(**
 * Calculate the value of e (the base of natural logarithms)
 * raised to the power of x.
 *
 * \since This function is available since SDL 2.0.9.
 *)
function SDL_exp(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_exp' {$ENDIF} {$ENDIF};

(**
 * Calculate the value of e (the base of natural logarithms)
 * raised to the power of x.
 *
 * \since This function is available since SDL 2.0.9.
 *)
function SDL_expf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_expf' {$ENDIF} {$ENDIF};

(**
 * Calculate the absolute value of x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_fabs(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_fabs' {$ENDIF} {$ENDIF};

(**
 * Calculate the absolute value of x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_fabsf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_fabsf' {$ENDIF} {$ENDIF};

(**
 * Calculate the largest integral value that is not greater than x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_floor(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_floor' {$ENDIF} {$ENDIF};

(**
 * Calculate the largest integral value that is not greater than x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_floorf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_floorf' {$ENDIF} {$ENDIF};

(**
 * Calculate the floating-point remainder of dividing x by y.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_fmod(x, y: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_fmod' {$ENDIF} {$ENDIF};

(**
 * Calculate the floating-point remainder of dividing x by y.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_fmodf(x, y: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_fmodf' {$ENDIF} {$ENDIF};

(**
 * Calculate the natural logarithm of x.
 *
 * \since This function is available since SDL 2.0.4.
 
 SDL2-for-Pascal: ATTENTION: The original C name of this function is SDL_log, 
 but since Pascal names are case-insensitive, it is in conflict with SDL_Log (logging function). 
 Hence we decided to rename it.
 *)
function SDL_nlog(x: cdouble): cdouble; cdecl;
  external SDL_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_SDL_log' {$ELSE} 'SDL_log' {$ENDIF};

(**
 * Calculate the natural logarithm of x.
 *
 * \since This function is available since SDL 2.0.8.
 
 SDL2-for-Pascal: ATTENTION: The original C name of this function is SDL_logf, 
 but to be consistent with the renamed SDL_log function (see comment of SDL_nlog
 for details), we decided to rename it.
 *)
function SDL_nlogf(x: cfloat): cfloat; cdecl;
  external SDL_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_SDL_logf' {$ELSE} 'SDL_logf' {$ENDIF};

(**
 * Calculate the base 10 logarithm of x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_log10(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_log10' {$ENDIF} {$ENDIF};

(**
 * Calculate the base 10 logarithm of x.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_log10f(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_log10f' {$ENDIF} {$ENDIF};

(**
 * Round to nearest integer, away from zero.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_lround(x: cdouble): clong; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_lround' {$ENDIF} {$ENDIF};

(**
 * Round to nearest integer, away from zero.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_lroundf(x: cfloat): clong; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_lroundf' {$ENDIF} {$ENDIF};

(**
 * Calculate the value of x raised to the power of y.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_pow(x, y: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_pow' {$ENDIF} {$ENDIF};

(**
 * Calculate the value of x raised to the power of y.
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_powf(x, y: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_powf' {$ENDIF} {$ENDIF};

(**
 * Round to nearest integral value, away from zero.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_round(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_round' {$ENDIF} {$ENDIF};

(**
 * Round to nearest integral value, away from zero.
 *
 * \since This function is available since SDL 2.0.16.
 *)
function SDL_roundf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_roundf' {$ENDIF} {$ENDIF};

(**
 * Calculate x multiplied by the floating-point radix to the power of n.
 * On most systems, the radix is 2, making this equivalent to x*(2**n).
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_scalbn(x: cdouble; n: cint): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_scalbn' {$ENDIF} {$ENDIF};

(**
 * Calculate x multiplied by the floating-point radix to the power of n.
 * On most systems, the radix is 2, making this equivalent to x*(2**n).
 *
 * \since This function is available since SDL 2.0.8.
 *)
function SDL_scalbnf(x: cfloat; n: cint): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_scalbnf' {$ENDIF} {$ENDIF};

(**
 * Calculate the sine of x, where x is given in radians.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_sin(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_sin' {$ENDIF} {$ENDIF};

(**
 * Calculate the sine of x, where x is given in radians.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_sinf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_sinf' {$ENDIF} {$ENDIF};

(**
 * Calculate the non-negative square root of x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_sqrt(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_sqrt' {$ENDIF} {$ENDIF};

(**
 * Calculate the non-negative square root of x.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_sqrtf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_sqrtf' {$ENDIF} {$ENDIF};

(**
 * Calculate the tangent of x, where x is given in radians.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_tan(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_tan' {$ENDIF} {$ENDIF};

(**
 * Calculate the tangent of x, where x is given in radians.
 *
 * \since This function is available since SDL 2.0.4.
 *)
function SDL_tanf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_tanf' {$ENDIF} {$ENDIF};

(**
 * Round to nearest integral value, towards zero.
 *
 * \since This function is available since SDL 2.0.14.
 *)
function SDL_trunc(x: cdouble): cdouble; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_trunc' {$ENDIF} {$ENDIF};

(**
 * Round to nearest integral value, towards zero.
 *
 * \since This function is available since SDL 2.0.14.
 *)
function SDL_truncf(x: cfloat): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_truncf' {$ENDIF} {$ENDIF};



(*** --- iconv functions --- ***)


(**
 * This function converts a string between encodings in one pass, returning a
 * string that must be freed with SDL_free(), or NIL on error.
 *
 * \since This function is available since SDL 2.0.0.
 *)
function SDL_iconv_string(Const tocode, fromcode, inbuf: PAnsiChar; inbytesleft: csize_t): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_iconv_string' {$ENDIF} {$ENDIF};

// These are macros in the original C headers, we will reimplement them as simple Pascal functions.
function SDL_iconv_utf8_locale(Const str: PAnsiChar): PAnsiChar; cdecl;
function SDL_iconv_utf8_ucs2(Const str: PAnsiChar): pcUint16; cdecl;
function SDL_iconv_utf8_ucs4(Const str: PAnsiChar): pcUint32; cdecl;

(* The SDL implementation of iconv() returns these error codes *)
const
  SDL_ICONV_ERROR  = csize_t(-1);
  SDL_ICONV_E2BIG  = csize_t(-2);
  SDL_ICONV_EILSEQ = csize_t(-3);
  SDL_ICONV_EINVAL = csize_t(-4);

type
  PSDL_iconv = type Pointer;

function SDL_iconv_open(Const tocode, fromcode: PAnsiChar): PSDL_iconv; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_iconv_open' {$ENDIF} {$ENDIF};

function SDL_iconv_close(cd: PSDL_iconv): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_iconv_close' {$ENDIF} {$ENDIF};

function SDL_iconv(cd: PSDL_iconv; Const inbuf: PPAnsiChar; inbytesleft: pcsize_t; outbuf: PPAnsiChar; outbytesleft: pcsize_t): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_iconv' {$ENDIF} {$ENDIF};
