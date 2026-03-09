
//since the array of const in delphi is not C compatible:
{$IFDEF FPC}

{**
 *  \brief The maximum size of a log message
 *
 *  Messages longer than the maximum size will be truncated
 *}
const
  SDL_MAX_LOG_MESSAGE = 4096;

{**
 *  \brief The predefined log categories
 *
 *  By default the application category is enabled at the INFO level,
 *  the assert category is enabled at the WARN level, test is enabled
 *  at the VERBOSE level and all other categories are enabled at the
 *  CRITICAL level.
 *}
type
  PPSDL_LogCategory = ^PSDL_LogCategory;
  PSDL_LogCategory = ^TSDL_LogCategory;
  TSDL_LogCategory = type cint;

const
  SDL_LOG_CATEGORY_APPLICATION           = TSDL_LogCategory(0);
  SDL_LOG_CATEGORY_ERROR                 = TSDL_LogCategory(1);
  SDL_LOG_CATEGORY_ASSERT                = TSDL_LogCategory(2);
  SDL_LOG_CATEGORY_SYSTEM                = TSDL_LogCategory(3);
  SDL_LOG_CATEGORY_AUDIO                 = TSDL_LogCategory(4);
  SDL_LOG_CATEGORY_VIDEO                 = TSDL_LogCategory(5);
  SDL_LOG_CATEGORY_RENDER                = TSDL_LogCategory(6);
  SDL_LOG_CATEGORY_INPUT                 = TSDL_LogCategory(7);
  SDL_LOG_CATEGORY_TEST                  = TSDL_LogCategory(8);

  {* Reserved for future SDL library use *}
  SDL_LOG_CATEGORY_RESERVED1             = TSDL_LogCategory(9);
  SDL_LOG_CATEGORY_RESERVED2             = TSDL_LogCategory(10);
  SDL_LOG_CATEGORY_RESERVED3             = TSDL_LogCategory(11);
  SDL_LOG_CATEGORY_RESERVED4             = TSDL_LogCategory(12);
  SDL_LOG_CATEGORY_RESERVED5             = TSDL_LogCategory(13);
  SDL_LOG_CATEGORY_RESERVED6             = TSDL_LogCategory(14);
  SDL_LOG_CATEGORY_RESERVED7             = TSDL_LogCategory(15);
  SDL_LOG_CATEGORY_RESERVED8             = TSDL_LogCategory(16);
  SDL_LOG_CATEGORY_RESERVED9             = TSDL_LogCategory(17);
  SDL_LOG_CATEGORY_RESERVED10            = TSDL_LogCategory(18);

  {* Beyond this point is reserved for application use *}
  SDL_LOG_CATEGORY_CUSTOM                = TSDL_LogCategory(19);

{**
 *  \brief The predefined log priorities
 *}
type
  PPSDL_LogPriority = ^PSDL_LogPriority;
  PSDL_LogPriority = ^TSDL_LogPriority;
  TSDL_LogPriority = type cint32;
const
  SDL_LOG_PRIORITY_VERBOSE = TSDL_LogPriority(1);
  SDL_LOG_PRIORITY_DEBUG = TSDL_LogPriority(2);
  SDL_LOG_PRIORITY_INFO = TSDL_LogPriority(3);
  SDL_LOG_PRIORITY_WARN = TSDL_LogPriority(4);
  SDL_LOG_PRIORITY_ERROR = TSDL_LogPriority(5);
  SDL_LOG_PRIORITY_CRITICAL = TSDL_LogPriority(6);
  SDL_NUM_LOG_PRIORITIES = TSDL_LogPriority(7);

{**
 *  \brief Set the priority of all log categories
 *}
procedure SDL_LogSetAllPriority(priority: TSDL_LogPriority); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogSetAllPriority' {$ENDIF} {$ENDIF};

{**
 *  \brief Set the priority of a particular log category
 *}
procedure SDL_LogSetPriority(category: TSDL_LogCategory; priority: TSDL_LogPriority); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogSetPriority' {$ENDIF} {$ENDIF};

{**
 *  \brief Get the priority of a particular log category
 *}
function SDL_LogGetPriority(category: TSDL_LogCategory): TSDL_LogPriority; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogGetPriority' {$ENDIF} {$ENDIF};

{**
 *  \brief Reset all priorities to default.
 *
 *  \note This is called in SDL_Quit().
 *}
procedure SDL_LogResetPriorities(); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogResetPriorities' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with SDL_LOG_CATEGORY_APPLICATION and SDL_LOG_PRIORITY_INFO
 *}
procedure SDL_Log(const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_Log' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with SDL_LOG_PRIORITY_VERBOSE
 *}
procedure SDL_LogVerbose(category: TSDL_LogCategory; const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogVerbose' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with SDL_LOG_PRIORITY_DEBUG
 *}
procedure SDL_LogDebug(category: TSDL_LogCategory; const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogDebug' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with SDL_LOG_PRIORITY_INFO
 *}
procedure SDL_LogInfo(category: TSDL_LogCategory; const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogInfo' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with SDL_LOG_PRIORITY_WARN
 *}
procedure SDL_LogWarn(category: TSDL_LogCategory; const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogWarn' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with SDL_LOG_PRIORITY_ERROR
 *}
procedure SDL_LogError(category: TSDL_LogCategory; const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogError' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with SDL_LOG_PRIORITY_CRITICAL
 *}
procedure SDL_LogCritical(category: TSDL_LogCategory; const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogCritical' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with the specified category and priority.
 *}
procedure SDL_LogMessage(category: TSDL_LogCategory; priority: TSDL_LogPriority; const fmt: PAnsiChar; pars: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogMessage' {$ENDIF} {$ENDIF};

{**
 *  \brief Log a message with the specified category and priority.
 *}
procedure SDL_LogMessageV(category: TSDL_LogCategory; priority: TSDL_LogPriority; const fmt: PAnsiChar; ap: array of const); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogMessageV' {$ENDIF} {$ENDIF};

{**
 *  \brief The prototype for the log output function
 *}
type
  PPSDL_LogOutputFunction = ^PSDL_LogOutputFunction;
  PSDL_LogOutputFunction = ^TSDL_LogOutputFunction;
  TSDL_LogOutputFunction = procedure(
    userdata: Pointer;
    category: TSDL_LogCategory;
    priority: TSDL_LogPriority;
    const msg: PAnsiChar); cdecl;

{**
 *  \brief Get the current log output function.
 *}
procedure SDL_LogGetOutputFunction(callback: PSDL_LogOutputFunction; userdata: PPointer); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogGetOutputFunction' {$ENDIF} {$ENDIF};

{**
 *  \brief This function allows you to replace the default log output
 *         function with one of your own.
 *}
procedure SDL_LogSetOutputFunction(callback: TSDL_LogOutputFunction; userdata: Pointer); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogSetOutputFunction' {$ENDIF} {$ENDIF};

{$ELSE}

// Delphi compatibility subset (non-varargs API only).
const
  SDL_MAX_LOG_MESSAGE = 4096;

type
  PPSDL_LogCategory = ^PSDL_LogCategory;
  PSDL_LogCategory = ^TSDL_LogCategory;
  TSDL_LogCategory = type cint;

const
  SDL_LOG_CATEGORY_APPLICATION           = TSDL_LogCategory(0);
  SDL_LOG_CATEGORY_ERROR                 = TSDL_LogCategory(1);
  SDL_LOG_CATEGORY_ASSERT                = TSDL_LogCategory(2);
  SDL_LOG_CATEGORY_SYSTEM                = TSDL_LogCategory(3);
  SDL_LOG_CATEGORY_AUDIO                 = TSDL_LogCategory(4);
  SDL_LOG_CATEGORY_VIDEO                 = TSDL_LogCategory(5);
  SDL_LOG_CATEGORY_RENDER                = TSDL_LogCategory(6);
  SDL_LOG_CATEGORY_INPUT                 = TSDL_LogCategory(7);
  SDL_LOG_CATEGORY_TEST                  = TSDL_LogCategory(8);
  SDL_LOG_CATEGORY_RESERVED1             = TSDL_LogCategory(9);
  SDL_LOG_CATEGORY_RESERVED2             = TSDL_LogCategory(10);
  SDL_LOG_CATEGORY_RESERVED3             = TSDL_LogCategory(11);
  SDL_LOG_CATEGORY_RESERVED4             = TSDL_LogCategory(12);
  SDL_LOG_CATEGORY_RESERVED5             = TSDL_LogCategory(13);
  SDL_LOG_CATEGORY_RESERVED6             = TSDL_LogCategory(14);
  SDL_LOG_CATEGORY_RESERVED7             = TSDL_LogCategory(15);
  SDL_LOG_CATEGORY_RESERVED8             = TSDL_LogCategory(16);
  SDL_LOG_CATEGORY_RESERVED9             = TSDL_LogCategory(17);
  SDL_LOG_CATEGORY_RESERVED10            = TSDL_LogCategory(18);
  SDL_LOG_CATEGORY_CUSTOM                = TSDL_LogCategory(19);

type
  PPSDL_LogPriority = ^PSDL_LogPriority;
  PSDL_LogPriority = ^TSDL_LogPriority;
  TSDL_LogPriority = type cint32;

const
  SDL_LOG_PRIORITY_VERBOSE = TSDL_LogPriority(1);
  SDL_LOG_PRIORITY_DEBUG = TSDL_LogPriority(2);
  SDL_LOG_PRIORITY_INFO = TSDL_LogPriority(3);
  SDL_LOG_PRIORITY_WARN = TSDL_LogPriority(4);
  SDL_LOG_PRIORITY_ERROR = TSDL_LogPriority(5);
  SDL_LOG_PRIORITY_CRITICAL = TSDL_LogPriority(6);
  SDL_NUM_LOG_PRIORITIES = TSDL_LogPriority(7);

procedure SDL_LogSetAllPriority(priority: TSDL_LogPriority); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogSetAllPriority' {$ENDIF} {$ENDIF};
procedure SDL_LogSetPriority(category: TSDL_LogCategory; priority: TSDL_LogPriority); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogSetPriority' {$ENDIF} {$ENDIF};
function SDL_LogGetPriority(category: TSDL_LogCategory): TSDL_LogPriority; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogGetPriority' {$ENDIF} {$ENDIF};
procedure SDL_LogResetPriorities(); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogResetPriorities' {$ENDIF} {$ENDIF};

type
  PPSDL_LogOutputFunction = ^PSDL_LogOutputFunction;
  PSDL_LogOutputFunction = ^TSDL_LogOutputFunction;
  TSDL_LogOutputFunction = procedure(
    userdata: Pointer;
    category: TSDL_LogCategory;
    priority: TSDL_LogPriority;
    const msg: PAnsiChar); cdecl;

procedure SDL_LogGetOutputFunction(callback: PSDL_LogOutputFunction; userdata: PPointer); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogGetOutputFunction' {$ENDIF} {$ENDIF};
procedure SDL_LogSetOutputFunction(callback: TSDL_LogOutputFunction; userdata: Pointer); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LogSetOutputFunction' {$ENDIF} {$ENDIF};

{$ENDIF}
