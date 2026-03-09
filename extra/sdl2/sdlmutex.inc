// based on "sdl_mutex.h"

const
  {**
   *  Synchronization functions which can time out return this value
   *  if they time out.
   *}
  SDL_MUTEX_TIMEDOUT = 1;

  {**
   *  This is the timeout value which corresponds to never time out.
   *}
  SDL_MUTEX_MAXWAIT = Not cuint32(0);

  { -- Mutex functions -- }
type
  { The SDL mutex structure, defined in SDL_sysmutex.c }
  PPSDL_Mutex = ^PSDL_Mutex;
  PSDL_Mutex = Type Pointer;

{**
 * Create a new mutex.
 *
 * All newly-created mutexes begin in the _unlocked_ state.
 *
 * Calls to SDL_LockMutex() will not return while the mutex is locked by
 * another thread. See SDL_TryLockMutex() to attempt to lock without blocking.
 *
 * SDL mutexes are reentrant.
 *
 * \returns the initialized and unlocked mutex or NIL on failure;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_CreateMutex: PSDL_Mutex; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateMutex' {$ENDIF} {$ENDIF};

{**
 * Lock the mutex.
 *
 * This will block until the mutex is available, which is to say it is in the
 * unlocked state and the OS has chosen the caller as the next thread to lock
 * it. Of all threads waiting to lock the mutex, only one may do so at a time.
 *
 * It is legal for the owning thread to lock an already-locked mutex. It must
 * unlock it the same number of times before it is actually made available for
 * other threads in the system (this is known as a "recursive mutex").
 *
 * \param mutex the mutex to lock
 * \return 0, or -1 on error.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_LockMutex(mutex: PSDL_Mutex): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LockMutex' {$ENDIF} {$ENDIF};

{ SDL2-for-Pascal: SDL_mutexP macro ignored; no benefit for the Pascal units }
//C: #define SDL_mutexP(m)   SDL_UnlockMutex(m)

{**
 * Try to lock a mutex without blocking.
 *
 * This works just like SDL_LockMutex(), but if the mutex is not available,
 * this function returns SDL_MUTEX_TIMEDOUT immediately.
 *
 * This technique is useful if you need exclusive access to a resource but
 * don't want to wait for it, and will return to it to try again later.
 *
 * \param mutex the mutex to try to lock
 * \returns 0, SDL_MUTEX_TIMEDOUT, or -1 on error; call SDL_GetError() for
 *          more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_TryLockMutex(mutex: PSDL_Mutex): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_TryLockMutex' {$ENDIF} {$ENDIF};

{**
 * Unlock the mutex.
 *
 * It is legal for the owning thread to lock an already-locked mutex. It must
 * unlock it the same number of times before it is actually made available for
 * other threads in the system (this is known as a "recursive mutex").
 *
 * It is an error to unlock a mutex that has not been locked by the current
 * thread, and doing so results in undefined behavior.
 *
 * It is also an error to unlock a mutex that isn't locked at all.
 *
 * \param mutex the mutex to unlock.
 * \returns 0, or -1 on error.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_UnlockMutex(mutex: PSDL_Mutex): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_UnlockMutex' {$ENDIF} {$ENDIF};

{ SDL2-for-Pascal: SDL_mutexV macro ignored; no benefit for the Pascal units }
//C: #define SDL_mutexV(m)   SDL_UnlockMutex(m)

{**
 * Destroy a mutex created with SDL_CreateMutex().
 *
 * This function must be called on any mutex that is no longer needed. Failure
 * to destroy a mutex will result in a system memory or resource leak. While
 * it is safe to destroy a mutex that is _unlocked_, it is not safe to attempt
 * to destroy a locked mutex, and may result in undefined behavior depending
 * on the platform.
 *
 * \param mutex the mutex to destroy
 *
 * \since This function is available since SDL 2.0.0.
 *}
procedure SDL_DestroyMutex(mutex: PSDL_Mutex); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_DestroyMutex' {$ENDIF} {$ENDIF};

  { -- Semaphore functions -- }
type
  { The SDL semaphore structure, defined in SDL_sem.c }
  PPSDL_Sem = ^PSDL_Sem;
  PSDL_Sem = Type Pointer;

{**
 * Create a semaphore.
 *
 * This function creates a new semaphore and initializes it with the provided
 * initial value. Each wait operation on the semaphore will atomically
 * decrement the semaphore value and potentially block if the semaphore value
 * is 0. Each post operation will atomically increment the semaphore value and
 * wake waiting threads and allow them to retry the wait operation.
 *
 * \param initial_value the starting value of the semaphore
 * \returns a new semaphore or NIL on failure; call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_CreateSemaphore(initial_value: cuint32): PSDL_sem; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateSemaphore' {$ENDIF} {$ENDIF};

{**
 * Destroy a semaphore.
 *
 * It is not safe to destroy a semaphore if there are threads currently
 * waiting on it.
 *
 * \param sem the semaphore to destroy
 *
 * \since This function is available since SDL 2.0.0.
 *}
procedure SDL_DestroySemaphore(sem: PSDL_Sem); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_DestroySemaphore' {$ENDIF} {$ENDIF};

{**
 * Wait until a semaphore has a positive value and then decrements it.
 *
 * This function suspends the calling thread until either the semaphore
 * pointed to by `sem` has a positive value or the call is interrupted by a
 * signal or error. If the call is successful it will atomically decrement the
 * semaphore value.
 *
 * This function is the equivalent of calling SDL_SemWaitTimeout() with a time
 * length of SDL_MUTEX_MAXWAIT.
 *
 * \param sem the semaphore wait on
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_SemWait(sem: PSDL_Sem): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SemWait' {$ENDIF} {$ENDIF};

{**
 * See if a semaphore has a positive value and decrement it if it does.
 *
 * This function checks to see if the semaphore pointed to by `sem` has a
 * positive value and atomically decrements the semaphore value if it does. If
 * the semaphore doesn't have a positive value, the function immediately
 * returns SDL_MUTEX_TIMEDOUT.
 *
 * \param sem the semaphore to wait on
 * \returns 0 if the wait succeeds, SDL_MUTEX_TIMEDOUT if the wait would
 *          block, or a negative error code on failure; call SDL_GetError()
 *          for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_SemTryWait(sem: PSDL_Sem): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SemTryWait' {$ENDIF} {$ENDIF};

{**
 * Wait until a semaphore has a positive value and then decrements it.
 *
 * This function suspends the calling thread until either the semaphore
 * pointed to by `sem` has a positive value, the call is interrupted by a
 * signal or error, or the specified time has elapsed. If the call is
 * successful it will atomically decrement the semaphore value.
 *
 * \param sem the semaphore to wait on
 * \param ms the length of the timeout, in milliseconds
 * \returns 0 if the wait succeeds, SDL_MUTEX_TIMEDOUT if the wait does not
 *          succeed in the allotted time, or a negative error code on failure;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_SemWaitTimeout(sem: PSDL_Sem; ms: cuint32): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SemWaitTimeout' {$ENDIF} {$ENDIF};

{**
 * Atomically increment a semaphore's value and wake waiting threads.
 *
 * \param sem the semaphore to increment
 * \returns 0 on success or a negative error code on failure;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_SemPost(sem: PSDL_Sem): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SemPost' {$ENDIF} {$ENDIF};

{**
 * Get the current value of a semaphore.
 *
 * \param sem the semaphore to query
 * \returns the current value of the semaphore.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_SemValue(sem: PSDL_Sem): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SemValue' {$ENDIF} {$ENDIF};

  { -- Condition variable functions -- }
type
  { The SDL condition variable structure, defined in SDL_cond.c }
  PPSDL_Cond = ^PSDL_Cond;

  {**
   *  The condition variable type.
   *
   *  Typical use of condition variables:
   *
   *  Thread A:
   *    SDL_LockMutex(lock);
   *    while ( not condition )
   *    begin
   *      SDL_CondWait(cond, lock);
   *    end;
   *    SDL_UnlockMutex(lock);
   *
   *  Thread B:
   *    SDL_LockMutex(lock);
   *    ...
   *    condition := true;
   *    ...
   *    SDL_CondSignal(cond);
   *    SDL_UnlockMutex(lock);
   *
   *  There is some discussion whether to signal the condition variable
   *  with the mutex locked or not.  There is some potential performance
   *  benefit to unlocking first on some platforms, but there are some
   *  potential race conditions depending on how your code is structured.
   *
   *  In general it's safer to signal the condition variable while the
   *  mutex is locked.
   *}
  PSDL_Cond = Type Pointer;

{**
 * Create a condition variable.
 *
 * \returns a new condition variable or NIL on failure; call SDL_GetError()
 *          for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_CreateCond: PSDL_Cond; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateCond' {$ENDIF} {$ENDIF};

{**
 * Destroy a condition variable.
 *
 * \param cond the condition variable to destroy
 *
 * \since This function is available since SDL 2.0.0.
 *}
procedure SDL_DestroyCond(cond: PSDL_Cond); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_DestroyCond' {$ENDIF} {$ENDIF};

{**
 * Restart one of the threads that are waiting on the condition variable.
 *
 * \param cond the condition variable to signal
 * \returns 0 on success or a negative error code on failure;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_CondSignal(cond: PSDL_Cond): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CondSignal' {$ENDIF} {$ENDIF};

{**
 * Restart all threads that are waiting on the condition variable.
 *
 * \param cond the condition variable to signal
 * \returns 0 on success or a negative error code on failure;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_CondBroadcast(cond: PSDL_Cond): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CondBroadcast' {$ENDIF} {$ENDIF};

{**
 * Wait until a condition variable is signaled.
 *
 * This function unlocks the specified `mutex` and waits for another thread to
 * call SDL_CondSignal() or SDL_CondBroadcast() on the condition variable
 * `cond`. Once the condition variable is signaled, the mutex is re-locked and
 * the function returns.
 *
 * The mutex must be locked before calling this function.
 *
 * This function is the equivalent of calling SDL_CondWaitTimeout() with a
 * time length of SDL_MUTEX_MAXWAIT.
 *
 * \param cond the condition variable to wait on
 * \param mutex the mutex used to coordinate thread access
 * \returns 0 when it is signaled or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_CondWait(cond: PSDL_Cond; mutex: PSDL_Mutex): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CondWait' {$ENDIF} {$ENDIF};

{**
 * Wait until a condition variable is signaled or a certain time has passed.
 *
 * This function unlocks the specified `mutex` and waits for another thread to
 * call SDL_CondSignal() or SDL_CondBroadcast() on the condition variable
 * `cond`, or for the specified time to elapse. Once the condition variable is
 * signaled or the time elapsed, the mutex is re-locked and the function
 * returns.
 *
 * The mutex must be locked before calling this function.
 *
 * \param cond the condition variable to wait on
 * \param mutex the mutex used to coordinate thread access
 * \param ms the maximum time to wait, in milliseconds, or SDL_MUTEX_MAXWAIT
 *           to wait indefinitely
 * \returns 0 if the condition variable is signaled, SDL_MUTEX_TIMEDOUT if
 *          the condition is not signaled in the allotted time, or a negative
 *          error code on failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_CondWaitTimeout(cond: PSDL_Cond; mutex: PSDL_Mutex; ms: cuint32): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CondWaitTimeout' {$ENDIF} {$ENDIF};
