// Unified logging interface - simple yet powerful logging with severity levels and categories
//
// SCOPE: Application logging and diagnostics. Provides clean API for outputting messages
// with timestamps, severity filtering, file/console output, and custom handlers.
// Used by all applications that need structured logging.
//
// ADD HERE: Log output formats, severity levels, output backends (file, network, console).
// DON'T ADD: Application-specific logging logic, profiling/metrics (→ Apus.Profiling),
// crash dumps (→ Apus.StackTrace).
//
// Contains: Log scope (Msg/Debug/Info/Force/Warn/Error/Fatal methods), Logger configuration
// (UseLogFile, SetVerbosity, LogCacheMode, Flush, GetTail), custom handlers, threaded background writing.
//
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.Log;
interface
uses Apus.Core;

type
  {$SCOPEDENUMS ON}

  // Message severity
  TSeverity = (
    Debug     = 0, // auxiliary debug information
    Info      = 1, // minor event
    Normal    = 2, // regular event, meaningful but not indicating a problem
    Forced    = 3, // important message, buffer will be flushed
    Warn      = 4, // something unusual, abnormal but not dangerous
    Error     = 5, // failure, error with ability to continue without crash
    Fatal     = 6  // fatal failure - emergency situation causing termination
  );

  // Main log API
  Log = record
    class procedure Msg(const msg:String8; category:byte=0; level:TSeverity=TSeverity.Normal); overload; static;
    class procedure Msg(const msg:String8; const params:array of const; category:byte=0; level:TSeverity=TSeverity.Normal); overload; static;
    class procedure Debug(const msg:String8; category:byte=0); overload; static;
    class procedure Debug(const msg:String8; const params:array of const; category:byte=0); overload; static;
    class procedure Info(const msg:String8; category:byte=0); overload; static;
    class procedure Info(const msg:String8; const params:array of const; category:byte=0); overload; static;
    class procedure Force(const msg:String8; category:byte=0); overload; static;
    class procedure Force(const msg:String8; const params:array of const; category:byte=0); overload; static;
    class procedure Warn(const msg:String8; category:byte=0); overload; static;
    class procedure Warn(const msg:String8; const params:array of const; category:byte=0); overload; static;
    class procedure Error(const msg:String8; category:byte=0); overload; static;
    class procedure Error(const msg:String8; const params:array of const; category:byte=0); overload; static;
    class procedure Fatal(const msg:String8; category:byte=0); overload; static;
    class procedure Fatal(const msg:String8; const params:array of const; category:byte=0); overload; static;
  end;

  // Log interception handler. msg doesn't contain date/time!
  TLogProc = procedure(const msg:String8; category:byte=0; level:TSeverity=TSeverity.Normal);

  // Basic logger API
  Logger = record
    class procedure UseLogFile(const name:String8; useThread:boolean=false; keepOpened:boolean=false); static;
    class procedure SetVerbosity(minSeverity:TSeverity=TSeverity.Info); static;
    class procedure SetDebugMirror(minSeverity:TSeverity=TSeverity.Error; enable:boolean=true); static;
    class procedure LogCacheMode(enableCache:boolean; bypassSeverity:TSeverity = TSeverity.Forced); static;
    class procedure Flush; static;
    class procedure SetCustomHandler(handler:TLogProc; disableDefaultHandler:boolean = false); static;
    class procedure StopLogThread; static; // optional, auto-called in finalization
    class function GetErrorCount:integer; static; // number of Error and Fatal messages
    // Last maxSize bytes of the active log file, cached messages included ('' if there is
    // no log file). Raw bytes: the text may start in the middle of a line or a UTF-8 sequence
    class function GetTail(maxSize:integer):String8; static;
  end;

implementation
uses SysUtils, Apus.Threads, Apus.Conv, Apus.Strings;

{$IFDEF ANDROID}
{$linklib log}
function AndroidLogWrite(priority:longint; tag,text:PAnsiChar):longint; cdecl;
  external 'liblog.so' name '__android_log_write';

procedure MirrorToAndroidLog(const msg:String8; category:byte; level:TSeverity);
const
  ANDROID_LOG_INFO=4;
  ANDROID_LOG_WARN=5;
  ANDROID_LOG_ERROR=6;
  ANDROID_LOG_FATAL=7;
var
  priority:longint;
  text:UTF8String;
begin
  if level<TSeverity.Forced then exit;
  case level of
    TSeverity.Forced:priority:=ANDROID_LOG_INFO;
    TSeverity.Warn:priority:=ANDROID_LOG_WARN;
    TSeverity.Error:priority:=ANDROID_LOG_ERROR;
  else
    priority:=ANDROID_LOG_FATAL;
  end;
  if category>0 then
    text:='['+Conv.ToStr(integer(category))+'] '+msg
  else
    text:=msg;
  AndroidLogWrite(priority,'ApusEngine',PAnsiChar(text));
end;
{$ENDIF}


var
  logFileName:String8 = ''; // full path; String8 - a string would lose non-ANSI characters under FPC
  minLogLevel:TSeverity = TSeverity.Info;
  logAlwaysOpened:boolean;
  logFile:file;
  cacheBuf:array of byte; // pending log text, cacheLen bytes are used
  cacheLen:integer;
  cacheEnabled:boolean;
  bypassCacheSeverity:TSeverity = TSeverity.Forced;
  debugMirrorEnabled:boolean=true;
  debugMirrorMinSeverity:TSeverity = TSeverity.Error;
  logLock:TLock;
  logErrorCount:integer;
  customHandler:TLogProc;
  disableDefault:boolean;

  // Flush thread
  flushThread:IThread;
  flushThreadActive:boolean;
  terminateFlushThread:boolean;

const
  CACHE_LIMIT=65000; // cached text is written out when it would exceed this size

// Log line without the line break: "HH:MM:SS.mmm  [category] msg"
function BuildLine(const msg:String8; category:byte):String8;
begin
  if category>0 then
    result:=CoreTime.Stamp+'  ['+Conv.ToStr(integer(category))+'] '+msg
  else
    result:=CoreTime.Stamp+'  '+msg;
end;

function QuoteCmdArg(const st:String8):String8;
begin
  if (st='') or (st.IndexOf(' ')>0) or (st.IndexOf(#9)>0) or (st.IndexOf('"')>0) then
    result:='"'+st.ReplaceAll('"','""')+'"'
  else
    result:=st;
end;

function BuildCmdParams:String8;
var
  i:integer;
begin
  result:='';
  for i:=1 to Env.ParamCount do begin
    if result<>'' then result:=result+' ';
    result:=result+QuoteCmdArg(Env.ParamStr(i));
  end;
end;

// Full path of a file name, without a trip through the ANSI code page under FPC on Windows
function ExpandName(const name:String8):String8;
begin
  {$IF defined(FPC) and defined(MSWINDOWS)}
  result:=UTF8Encode(ExpandFileName(UnicodeString(name)));
  {$ELSE}
  result:=String8(ExpandFileName(string(name)));
  {$IFEND}
end;

procedure AppendLogFile(var data; size:integer);
var
  f:file;
begin
  if logAlwaysOpened then begin
    BlockWrite(logFile, data, size);
  end else begin
    AssignFile(f,{$IFDEF FPC}logFileName{$ELSE}string(logFileName){$ENDIF});
    Reset(f, 1);
    Seek(f, FileSize(f));
    try
      BlockWrite(f, data, size);
    finally
      Close(f);
    end;
  end;
end;

procedure IntFlushLog;
begin
  if logFileName = '' then exit;
  try
    AppendLogFile(cacheBuf[0], cacheLen);
    cacheLen := 0;
  except
  end;
end;

// Append line+LineBreak to the cache; the caller checked that it fits CACHE_LIMIT
procedure CacheAppend(const line:String8);
const
  LB:String8=LineBreak; // a single char on Unix, so index a string copy
var
  n:integer;
begin
  if length(cacheBuf)<CACHE_LIMIT then SetLength(cacheBuf,CACHE_LIMIT);
  n:=length(line);
  if n>0 then Move(line[1],cacheBuf[cacheLen],n);
  inc(cacheLen,n);
  Move(LB[1],cacheBuf[cacheLen],length(LB));
  inc(cacheLen,length(LB));
end;

procedure InternalLogWrite(const line:String8; level:TSeverity);
var
  st:String8;
begin
  logLock.Enter;
  try
    if (level<bypassCacheSeverity) and cacheEnabled and
       (cacheLen+length(line)+length(LineBreak)<CACHE_LIMIT) then
      CacheAppend(line)
    else begin
      // bypass severity, cache disabled or full - write directly
      if cacheLen>0 then IntFlushLog;
      try
        st:=line+LineBreak;
        AppendLogFile(st[1],length(st));
      except
        on e:Exception do begin
          // Can't log error in log, avoid recursion
        end;
      end;
    end;
  finally
    logLock.Leave;
  end;
end;

procedure FlushThreadProc;
var
  tick:cardinal;
begin
  tick:=0;
  repeat
    inc(tick);
    sleep(10);
    if (cacheLen>20000) or (tick mod 50=0) then
      Logger.Flush;
  until terminateFlushThread;
end;

{ Log }

class procedure Log.Msg(const msg:String8; category:byte; level:TSeverity);
var
  line:String8;
  toFile,toMirror:boolean;
begin
  // Call custom handler if set
  if Assigned(customHandler) then
    customHandler(msg, category, level);

  {$IFDEF ANDROID}
  MirrorToAndroidLog(msg,category,level);
  {$ENDIF}

  // Default handler (unless disabled) and optional mirroring to debug console share the line
  toFile:=not disableDefault and (logFileName<>'') and (level>=minLogLevel);
  toMirror:=debugMirrorEnabled and (level>=debugMirrorMinSeverity);
  if toFile or toMirror then begin
    line:=BuildLine(msg,category);
    if toFile then InternalLogWrite(line,level);
    if toMirror then DebugMsg(line);
  end;

  // Track errors
  if level>=TSeverity.Error then
    Atomic.Inc(logErrorCount);
end;

class procedure Log.Msg(const msg:String8; const params:array of const; category:byte; level:TSeverity);
begin
  Log.Msg(UTF8.Format(msg, params), category, level);
end;

class procedure Log.Debug(const msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Debug);
end;

class procedure Log.Debug(const msg:String8; const params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Debug);
end;

class procedure Log.Info(const msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Info);
end;

class procedure Log.Info(const msg:String8; const params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Info);
end;

class procedure Log.Force(const msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Forced);
end;

class procedure Log.Force(const msg:String8; const params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Forced);
end;

class procedure Log.Warn(const msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Warn);
end;

class procedure Log.Warn(const msg:String8; const params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Warn);
end;

class procedure Log.Error(const msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Error);
end;

class procedure Log.Error(const msg:String8; const params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Error);
end;

class procedure Log.Fatal(const msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Fatal);
end;

class procedure Log.Fatal(const msg:String8; const params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Fatal);
end;

{ Logger }

class procedure Logger.UseLogFile(const name:String8; useThread:boolean; keepOpened:boolean);
var
  f:file;
  dt:TDateTime;
  header,dateStr:String8;
begin
  Logger.Flush;
  logLock.Enter;
  try
    if logAlwaysOpened then begin
      logAlwaysOpened:=false;
      try
        CloseFile(logFile);
      except
      end;
    end;
    logFileName:=ExpandName(name);
    // the date of the executable; unknown if it can't be read (no exception: the logger
    // starts before anything could report it)
    if FileAge({$IFDEF FPC}Env.ExeName{$ELSE}string(Env.ExeName){$ENDIF},dt) then
      dateStr:=String8(FormatDateTime('ddddd t',dt))
    else
      dateStr:='exe date unknown';
    header:=dateStr+LineBreak+'exe: '+Env.ExeName+LineBreak+'params: '+BuildCmdParams+LineBreak;
    try
      // untyped file: the header is UTF-8 bytes, a text file would convert them under FPC
      AssignFile(f,{$IFDEF FPC}logFileName{$ELSE}string(logFileName){$ENDIF});
      Rewrite(f,1);
      BlockWrite(f,header[1],length(header));
      CloseFile(f);
      if keepOpened then begin
        AssignFile(logFile,{$IFDEF FPC}logFileName{$ELSE}string(logFileName){$ENDIF});
        Reset(logFile,1);
        Seek(logFile,FileSize(logFile));
        logAlwaysOpened:=true;
      end;
    except
      logFileName:='';
    end;

    // start flush thread if requested
    if useThread and not flushThreadActive then begin
      terminateFlushThread:=false;
      flushThread:=Thread.Start('LogFlush',@FlushThreadProc,nil);
      flushThreadActive:=true;
    end;
  finally
    logLock.Leave;
  end;
end;

class procedure Logger.SetVerbosity(minSeverity:TSeverity);
begin
  minLogLevel:=minSeverity;
end;

class procedure Logger.SetDebugMirror(minSeverity:TSeverity; enable:boolean);
begin
  debugMirrorMinSeverity:=minSeverity;
  debugMirrorEnabled:=enable;
end;

class procedure Logger.LogCacheMode(enableCache:boolean; bypassSeverity:TSeverity);
begin
  cacheEnabled:=enableCache;
  bypassCacheSeverity:=bypassSeverity;
  if not enableCache and (cacheLen>0) then
    Logger.Flush;
end;

class procedure Logger.Flush;
begin
  if logFileName = '' then exit;
  logLock.Enter;
  try
    if cacheLen = 0 then exit;
    try
      IntFlushLog;
    except
      on e:Exception do begin
        // Can't log error in flush
      end;
    end;
  finally
    logLock.Leave;
  end;
end;

class procedure Logger.SetCustomHandler(handler:TLogProc; disableDefaultHandler:boolean);
begin
  customHandler := handler;
  disableDefault := disableDefaultHandler;
end;

class procedure Logger.StopLogThread;
begin
  if not flushThreadActive then exit;
  terminateFlushThread:=true;
  // wait for thread to finish (max 1 second)
  if flushThread<>nil then begin
   flushThread.Wait(1000);
   flushThread:=nil; // release interface
  end;
  flushThreadActive:=false;
end;

class function Logger.GetErrorCount:integer;
begin
  result := logErrorCount;
end;

// Last maxSize bytes of an opened file; the position is left at the end
function ReadTail(var f:file; maxSize:integer):String8;
var
  size,start:int64;
begin
  size:=FileSize(f);
  start:=size-maxSize;
  if start<0 then start:=0;
  try
    SetLength(result,size-start);
    Seek(f,start);
    if result<>'' then BlockRead(f,result[1],length(result));
  finally
    Seek(f,size);
  end;
end;

class function Logger.GetTail(maxSize:integer):String8;
var
  f:file;
begin
  result:='';
  if maxSize<=0 then exit;
  logLock.Enter;
  try
    if logFileName='' then exit;
    try
      if cacheLen>0 then IntFlushLog;
      if logAlwaysOpened then
        result:=ReadTail(logFile,maxSize)
      else begin
        AssignFile(f,{$IFDEF FPC}logFileName{$ELSE}string(logFileName){$ENDIF});
        Reset(f,1);
        try
          result:=ReadTail(f,maxSize);
        finally
          CloseFile(f);
        end;
      end;
    except
      result:='';
    end;
  finally
    logLock.Leave;
  end;
end;

initialization
  logLock.Init('Log',1000); // innermost: anything may log under any other lock

finalization
  Logger.StopLogThread;
  Logger.Flush;
  if logAlwaysOpened then
    Close(logFile);
  logLock.Cleanup;
end.
