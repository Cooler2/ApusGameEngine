{$IFDEF FPC}
  {$MODE DELPHI}
  {$ASMMODE intel}
{$ELSE}
  {$DEFINE DELPHI}
{$ENDIF}
{$IFDEF CPUX64}
  {$DEFINE CPU64}
{$ENDIF}

// Global RW-lock backend switch:
// - default on Windows: prefer native SRWLock backend;
// - define APUS_FORCE_RWLOCK_FALLBACK to force software fallback (for testing).
{$IFDEF MSWINDOWS}
  {$IFNDEF APUS_FORCE_RWLOCK_FALLBACK}
    {$DEFINE APUS_RWLOCK_USE_SRWLOCK}
  {$ENDIF}
{$ENDIF}
