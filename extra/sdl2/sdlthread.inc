// based on "sdl_thread.h"

{**
 *  \file SDL_thread.h
 *
 *  Header for the SDL thread management routines.
 *}

{* The SDL thread structure, defined in SDL_thread.c *}
type
  PSDL_Thread = type Pointer;

  {* The SDL thread ID *}
  PPSDL_threadID = ^PSDL_threadID;
  PSDL_threadID = ^TSDL_threadID;
  TSDL_threadID = culong;

  {* Thread local storage ID, 0 is the invalid ID *}
  PPSDL_TLSID = ^PSDL_TLSID;
  PSDL_TLSID = ^TSDL_TLSID;
  TSDL_TLSID = cuint;

 {**
 *  The SDL thread priority.
 *
 *  SDL will make system changes as necessary in order to apply the thread priority.
 *  Code which attempts to control thread state related to priority should be aware
 *  that calling SDL_SetThreadPriority may alter such state.
 *  SDL_HINT_THREAD_PRIORITY_POLICY can be used to control aspects of this behavior.
 *
 *  \note On many systems you require special privileges to set high or time critical priority.
 *}
type
  PPSDL_ThreadPriority = ^PSDL_ThreadPriority;
  PSDL_ThreadPriority = ^TSDL_ThreadPriority;
  TSDL_ThreadPriority = cint;

const
  SDL_THREAD_PRIORITY_LOW = TSDL_ThreadPriority(0);
  SDL_THREAD_PRIORITY_NORMAL = TSDL_ThreadPriority(1);
  SDL_THREAD_PRIORITY_HIGH = TSDL_ThreadPriority(2);
  SDL_THREAD_PRIORITY_TIME_CRITICAL = TSDL_ThreadPriority(3);

  {**
 * The function passed to SDL_CreateThread().
 *
 * \param data what was passed as `data` to SDL_CreateThread()
 * \returns a value that can be reported through SDL_WaitThread().
 *}
type
  PPSDL_ThreadFunction = ^PSDL_ThreadFunction;
  PSDL_ThreadFunction = ^TSDL_ThreadFunction;
  TSDL_ThreadFunction = function(data: Pointer): cint; cdecl;

{$IFDEF WINDOWS}
  {**
   *  SDL_thread.h
   *
   *  We compile SDL into a DLL. This means, that it's the DLL which
   *  creates a new thread for the calling process with the SDL_CreateThread()
   *  API. There is a problem with this, that only the RTL of the SDL.DLL will
   *  be initialized for those threads, and not the RTL of the calling
   *  application!
   *
   *  To solve this, we make a little hack here.
   *
   *  We'll always use the caller's _beginthread() and _endthread() APIs to
   *  start a new thread. This way, if it's the SDL.DLL which uses this API,
   *  then the RTL of SDL.DLL will be used to create the new thread, and if it's
   *  the application, then the RTL of the application will be used.
   *
   *  So, in short:
   *  Always use the _beginthread() and _endthread() of the calling runtime
   *  library!
   *}
{$DEFINE SDL_PASSED_BEGINTHREAD_ENDTHREAD}

type
  { SDL2-for-Pascal: #todo : Needed? }
  {$IFNDEF FPC}
    {$IFNDEF DELPHI16UP}
      TThreadID = Cardinal;
    {$ENDIF}
  {$ENDIF}

  { SDL2-for-Pascal #todo : Explanation needed }
  TpfnSDL_CurrentBeginThread = function(
    SecurityAttributes: Pointer; StackSize: cuint; ThreadFunc: TThreadFunc;
    Parameter: Pointer {arg}; CreationFlags: cuint; var ThreadId: TThreadID {threadID}): cuintptr_t; cdecl;

  TpfnSDL_CurrentEndThread = procedure(code: cuint); cdecl;


function SDL_CreateThread(fn: TSDL_ThreadFunction; name: PAnsiChar;
  data: Pointer;
  pfnBeginThread: TpfnSDL_CurrentBeginThread;
  pfnEndThread: TpfnSDL_CurrentEndThread): PSDL_Thread; cdecl; overload;
  external SDL_LibName;

function SDL_CreateThreadWithStackSize(fn: TSDL_ThreadFunction;
  name: PAnsiChar; const stacksize: csize_t; data: Pointer;
  pfnBeginThread: TpfnSDL_CurrentBeginThread;
  pfnEndThread: TpfnSDL_CurrentEndThread): PSDL_Thread; cdecl; overload;
  external SDL_LibName;

{ SDL2-For-Pascal:  #note : In the C header are two versions
    of these macro functions. One for SDL's dynamic API and one without.
    We can go with this for the moment. Improvement surely possible. }
function SDL_CreateThread(fn: TSDL_ThreadFunction; name: PAnsiChar;
  data: Pointer): PSDL_Thread; overload;

function SDL_CreateThreadWithStackSize(fn: TSDL_ThreadFunction; name: PAnsiChar;
  const stacksize: csize_t; data: Pointer): PSDL_Thread; overload;


{ SDL2-For-Pascal: #todo :
          The OS2 part of SDL_thread.h is not translated, yet.
          The ELSE block is covering this right now. Not sure if the
          OS2 platform switch is implemented in Delphi. }
//{$ELSEIF OS2}
//{*
// * just like the windows case above:  We compile SDL2
// * into a dll with Watcom's runtime statically linked.
// *}

{ ... }

{$ELSE}

  {**
   *  Create a thread.
   *
   *   Thread naming is a little complicated: Most systems have very small
   *    limits for the string length (BeOS has 32 bytes, Linux currently has 16,
   *    Visual C++ 6.0 has nine!), and possibly other arbitrary rules. You'll
   *    have to see what happens with your system's debugger. The name should be
   *    UTF-8 (but using the naming limits of C identifiers is a better bet).
   *   There are no requirements for thread naming conventions, so long as the
   *    string is null-terminated UTF-8, but these guidelines are helpful in
   *    choosing a name:
   *
   *    http://stackoverflow.com/questions/149932/naming-conventions-for-threads
   *
   *   If a system imposes requirements, SDL will try to munge the string for
   *    it (truncate, etc), but the original string contents will be available
   *    from SDL_GetThreadName().
   *}
function SDL_CreateThread(fn: TSDL_ThreadFunction; name: PAnsiChar;
  data: Pointer): PSDL_Thread; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateThread' {$ENDIF} {$ENDIF};

{**
 * Create a new thread with a specific stack size.
 *
 * SDL makes an attempt to report `name` to the system, so that debuggers can
 * display it. Not all platforms support this.
 *
 * Thread naming is a little complicated: Most systems have very small limits
 * for the string length (Haiku has 32 bytes, Linux currently has 16, Visual
 * C++ 6.0 has _nine_!), and possibly other arbitrary rules. You'll have to
 * see what happens with your system's debugger. The name should be UTF-8 (but
 * using the naming limits of C identifiers is a better bet). There are no
 * requirements for thread naming conventions, so long as the string is
 * null-terminated UTF-8, but these guidelines are helpful in choosing a name:
 *
 * https://stackoverflow.com/questions/149932/naming-conventions-for-threads
 *
 * If a system imposes requirements, SDL will try to munge the string for it
 * (truncate, etc), but the original string contents will be available from
 * SDL_GetThreadName().
 *
 * The size (in bytes) of the new stack can be specified. Zero means "use the
 * system default" which might be wildly different between platforms. x86
 * Linux generally defaults to eight megabytes, an embedded device might be a
 * few kilobytes instead. You generally need to specify a stack that is a
 * multiple of the system's page size (in many cases, this is 4 kilobytes, but
 * check your system documentation).
 *
 * In SDL 2.1, stack size will be folded into the original SDL_CreateThread
 * function, but for backwards compatibility, this is currently a separate
 * function.
 *
 * \param fn the SDL_ThreadFunction function to call in the new thread
 * \param name the name of the thread
 * \param stacksize the size, in bytes, to allocate for the new thread stack.
 * \param data a pointer that is passed to `fn`
 * \returns an opaque pointer to the new thread object on success, NULL if the
 *          new thread could not be created; call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.9.
 *
 * \sa SDL_WaitThread
 *}
function SDL_CreateThreadWithStackSize(fn: TSDL_ThreadFunction; name: PAnsiChar;
  stacksize: csize_t; data: Pointer): PSDL_Thread; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateThreadWithStackSize' {$ENDIF} {$ENDIF};


{$ENDIF}

  {**
 * Get the thread name as it was specified in SDL_CreateThread().
 *
 * This is internal memory, not to be freed by the caller, and remains valid
 * until the specified thread is cleaned up by SDL_WaitThread().
 *
 * \param thread the thread to query
 * \returns a pointer to a UTF-8 string that names the specified thread, or
 *          NULL if it doesn't have a name.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateThread
 *}
function SDL_GetThreadName(thread: PSDL_Thread): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetThreadName' {$ENDIF}{$ENDIF};

  {**
 * Get the thread identifier for the current thread.
 *
 * This thread identifier is as reported by the underlying operating system.
 * If SDL is running on a platform that does not support threads the return
 * value will always be zero.
 *
 * This function also returns a valid thread ID when called from the main
 * thread.
 *
 * \returns the ID of the current thread.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetThreadID
 *}
function SDL_ThreadID: TSDL_ThreadID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ThreadID' {$ENDIF}{$ENDIF};

  {**
 * Get the thread identifier for the specified thread.
 *
 * This thread identifier is as reported by the underlying operating system.
 * If SDL is running on a platform that does not support threads the return
 * value will always be zero.
 *
 * \param thread the thread to query
 * \returns the ID of the specified thread, or the ID of the current thread if
 *          `thread` is NULL.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_ThreadID
 *}
function SDL_GetThreadID(thread: PSDL_Thread): TSDL_ThreadID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetThreadID' {$ENDIF}{$ENDIF};

  {**
 * Set the priority for the current thread.
 *
 * Note that some platforms will not let you alter the priority (or at least,
 * promote the thread to a higher priority) at all, and some require you to be
 * an administrator account. Be prepared for this to fail.
 *
 * \param priority the SDL_ThreadPriority to set
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_SetThreadPriority(priority: TSDL_ThreadPriority): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetThreadPriority' {$ENDIF}{$ENDIF};

  {**
 * Wait for a thread to finish.
 *
 * Threads that haven't been detached will remain (as a "zombie") until this
 * function cleans them up. Not doing so is a resource leak.
 *
 * Once a thread has been cleaned up through this function, the SDL_Thread
 * that references it becomes invalid and should not be referenced again. As
 * such, only one thread may call SDL_WaitThread() on another.
 *
 * The return code for the thread function is placed in the area pointed to by
 * `status`, if `status` is not NULL.
 *
 * You may not wait on a thread that has been used in a call to
 * SDL_DetachThread(). Use either that function or this one, but not both, or
 * behavior is undefined.
 *
 * It is safe to pass a NULL thread to this function; it is a no-op.
 *
 * Note that the thread pointer is freed by this function and is not valid
 * afterward.
 *
 * \param thread the SDL_Thread pointer that was returned from the
 *               SDL_CreateThread() call that started this thread
 * \param status pointer to an integer that will receive the value returned
 *               from the thread function by its 'return', or NULL to not
 *               receive such value back.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateThread
 * \sa SDL_DetachThread
 *}
procedure SDL_WaitThread(thread: PSDL_Thread; status: pcint); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WaitThread' {$ENDIF}{$ENDIF};

  {**
 * Let a thread clean up on exit without intervention.
 *
 * A thread may be "detached" to signify that it should not remain until
 * another thread has called SDL_WaitThread() on it. Detaching a thread is
 * useful for long-running threads that nothing needs to synchronize with or
 * further manage. When a detached thread is done, it simply goes away.
 *
 * There is no way to recover the return code of a detached thread. If you
 * need this, don't detach the thread and instead use SDL_WaitThread().
 *
 * Once a thread is detached, you should usually assume the SDL_Thread isn't
 * safe to reference again, as it will become invalid immediately upon the
 * detached thread's exit, instead of remaining until someone has called
 * SDL_WaitThread() to finally clean it up. As such, don't detach the same
 * thread more than once.
 *
 * If a thread has already exited when passed to SDL_DetachThread(), it will
 * stop waiting for a call to SDL_WaitThread() and clean up immediately. It is
 * not safe to detach a thread that might be used with SDL_WaitThread().
 *
 * You may not call SDL_WaitThread() on a thread that has been detached. Use
 * either that function or this one, but not both, or behavior is undefined.
 *
 * It is safe to pass NULL to this function; it is a no-op.
 *
 * \param thread the SDL_Thread pointer that was returned from the
 *               SDL_CreateThread() call that started this thread
 *
 * \since This function is available since SDL 2.0.2.
 *
 * \sa SDL_CreateThread
 * \sa SDL_WaitThread
 *}
procedure SDL_DetachThread(thread:PSDL_Thread); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_DetachThread' {$ENDIF}{$ENDIF};

  {**
 * Create a piece of thread-local storage.
 *
 * This creates an identifier that is globally visible to all threads but
 * refers to data that is thread-specific.
 *
 * \returns the newly created thread local storage identifier or 0 on error.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_TLSGet
 * \sa SDL_TLSSet
 *}
function SDL_TLSCreate: TSDL_TLSID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_TLSCreate' {$ENDIF} {$ENDIF};

  {**
 * Get the current thread's value associated with a thread local storage ID.
 *
 * \param id the thread local storage ID
 * \returns the value associated with the ID for the current thread or NULL if
 *          no value has been set; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_TLSCreate
 * \sa SDL_TLSSet
 *}
function SDL_TLSGet(id: TSDL_TLSID): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_TLSGet' {$ENDIF} {$ENDIF};

type
  { SDL2-For-Pascal: This function pointer is introduced to specifiy the
                     destructor pointer in the SDL_TLSSet function
                     according to C headers.

                     The TTLSDestructor type itself is not defined
                     by the original SDL2 headers. }
  TTLSDestructor = procedure(value: Pointer); cdecl;

  {**
 * Set the current thread's value associated with a thread local storage ID.
 *
 * The function prototype for `destructor` is:
 *
 * ```c
 * void destructor(void *value)
 * ```
 *
 * where its parameter `value` is what was passed as `value` to SDL_TLSSet().
 *
 * \param id the thread local storage ID
 * \param value the value to associate with the ID for the current thread
 * \param destructor a function called when the thread exits, to free the
 *                   value
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_TLSCreate
 * \sa SDL_TLSGet
 *}
function SDL_TLSSet(id: TSDL_TLSID; const value: Pointer; destructor_: TTLSDestructor): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_TLSSet' {$ENDIF} {$ENDIF};

{**
 * Cleanup all TLS data for this thread.
 *
 * \since This function is available since SDL 2.0.16.
 *}
procedure SDL_TLSCleanup; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_TLSCleanup' {$ENDIF} {$ENDIF};

