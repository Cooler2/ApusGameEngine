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
// (UseLogFile, SetVerbosity, LogCacheMode, Flush), custom handlers, threaded background writing.
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
    class procedure Msg(msg:String8; category:byte=0; level:TSeverity=TSeverity.Normal); overload; static;
    class procedure Msg(msg:String8; params:array of const; category:byte=0; level:TSeverity=TSeverity.Normal); overload; static;
    class procedure Debug(msg:String8; category:byte=0); overload; static;
    class procedure Debug(msg:String8; params:array of const; category:byte=0); overload; static;
    class procedure Info(msg:String8; category:byte=0); overload; static;
    class procedure Info(msg:String8; params:array of const; category:byte=0); overload; static;
    class procedure Force(msg:String8; category:byte=0); overload; static;
    class procedure Force(msg:String8; params:array of const; category:byte=0); overload; static;
    class procedure Warn(msg:String8; category:byte=0); overload; static;
    class procedure Warn(msg:String8; params:array of const; category:byte=0); overload; static;
    class procedure Error(msg:String8; category:byte=0); overload; static;
    class procedure Error(msg:String8; params:array of const; category:byte=0); overload; static;
    class procedure Fatal(msg:String8; category:byte=0); overload; static;
    class procedure Fatal(msg:String8; params:array of const; category:byte=0); overload; static;
  end;

  // Log interception handler. msg doesn't contain date/time!
  TLogProc = procedure(msg:String8; category:byte=0; level:TSeverity=TSeverity.Normal);

  // Basic logger API
  Logger = record
    class procedure UseLogFile(name:string; useThread:boolean=false; keepOpened:boolean=false); static;
    class procedure SetVerbosity(minSeverity:TSeverity=TSeverity.Info); static;
    class procedure SetDebugMirror(minSeverity:TSeverity=TSeverity.Error; enable:boolean=true); static;
    class procedure LogCacheMode(enableCache:boolean; bypassSeverity:TSeverity = TSeverity.Forced); static;
    class procedure Flush; static;
    class procedure SetCustomHandler(handler:TLogProc; disableDefaultHandler:boolean = false); static;
    class procedure StopLogThread; static; // optional, auto-called in finalization
    class function GetErrorCount:integer; static; // number of Error and Fatal messages
  end;

implementation
uses SysUtils, Apus.Threads;


var
  logFileName:string = '';
  minLogLevel:TSeverity = TSeverity.Info;
  logAlwaysOpened:boolean;
  logFile:file;
  cacheBuf:RawByteString;
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

// 12-character time: HH:MM:SS.mmm
function FormatLogText(const text:string):string;
begin
  result:=string(Apus.Core.Time.Stamp)+'  '+text;
end;

function BuildText(const msg:String8; category:byte):string;
begin
  if category > 0 then
    result:='['+IntToStr(category)+'] '+string(msg)
  else
    result:=string(msg);
end;

function QuoteCmdArg(const st:string):string;
begin
  if (st='') or (Pos(' ',st)>0) or (Pos(#9,st)>0) or (Pos('"',st)>0) then
    result:='"'+StringReplace(st,'"','""',[rfReplaceAll])+'"'
  else
    result:=st;
end;

function BuildCmdParams:string;
var
  i:integer;
begin
  result:='';
  for i:=1 to ParamCount do begin
    if result<>'' then result:=result+' ';
    result:=result+QuoteCmdArg(ParamStr(i));
  end;
end;

procedure AppendLogFile(var data; size:integer);
var
  f:file;
begin
  if logAlwaysOpened then begin
    BlockWrite(logFile, data, size);
  end else begin
    AssignFile(f, logFileName);
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
    AppendLogFile(cacheBuf[1], length(cacheBuf));
    cacheBuf := '';
  except
  end;
end;

procedure InternalLogWrite(const msg:String8; category:byte; level:TSeverity);
var
  st:String8;
  text:string;
begin
  if logFileName='' then exit;
  if level<minLogLevel then exit;

  // Format message
  text:=BuildText(msg,category);

  st:=String8(FormatLogText(text));
  logLock.Enter;
  try
    if level>=bypassCacheSeverity then begin
      // Bypass cache - write directly
      if cacheBuf<>'' then IntFlushLog;
      try
        st:=st+String8(LineBreak);
        AppendLogFile(st[1], length(st));
      except
        on e:Exception do begin
          // Can't log error in log, avoid recursion
        end;
      end;
    end else begin
      // Use cache
      if cacheEnabled and (length(cacheBuf) + length(st) < 65000) then begin
        // Cache available and has space
        cacheBuf:=cacheBuf+st+LineBreak;
      end else begin
        // Cache disabled or full
        if cacheBuf<>'' then IntFlushLog;
        try
          st:=st+String8(LineBreak);
          AppendLogFile(st[1],length(st));
        except
          on e:Exception do begin
            // Can't log error in log
          end;
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
    if (length(cacheBuf)>20000) or (tick mod 50=0) then
      Logger.Flush;
  until terminateFlushThread;
end;

{ Log }

class procedure Log.Msg(msg:String8; category:byte; level:TSeverity);
var
  text:string;
begin
  // Call custom handler if set
  if Assigned(customHandler) then
    customHandler(msg, category, level);

  // Call default handler unless disabled
  if not disableDefault then
    InternalLogWrite(msg, category, level);

  // Optional mirroring to debug console.
  if debugMirrorEnabled and (level>=debugMirrorMinSeverity) then begin
    text:=BuildText(msg,category);
    DebugMsg(FormatLogText(text));
  end;

  // Track errors
  if level>=TSeverity.Error then
    Atomic.Inc(logErrorCount);
end;

class procedure Log.Msg(msg:String8; params:array of const; category:byte; level:TSeverity);
begin
  Log.Msg(Format(string(msg), params), category, level);
end;

class procedure Log.Debug(msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Debug);
end;

class procedure Log.Debug(msg:String8; params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Debug);
end;

class procedure Log.Info(msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Info);
end;

class procedure Log.Info(msg:String8; params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Info);
end;

class procedure Log.Force(msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Forced);
end;

class procedure Log.Force(msg:String8; params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Forced);
end;

class procedure Log.Warn(msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Warn);
end;

class procedure Log.Warn(msg:String8; params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Warn);
end;

class procedure Log.Error(msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Error);
end;

class procedure Log.Error(msg:String8; params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Error);
end;

class procedure Log.Fatal(msg:String8; category:byte);
begin
  Log.Msg(msg, category, TSeverity.Fatal);
end;

class procedure Log.Fatal(msg:String8; params:array of const; category:byte);
begin
  Log.Msg(msg, params, category, TSeverity.Fatal);
end;

{ Logger }

class procedure Logger.UseLogFile(name:string; useThread:boolean; keepOpened:boolean);
var
  f:TextFile;
  dt:TDateTime;
  age:integer;
  exePath,cmdParams:string;
begin
  Logger.Flush;
  logLock.Enter;
  try
    logFileName:=ExpandFileName(name);
    exePath:=ExpandFileName(ParamStr(0));
    cmdParams:=BuildCmdParams;
    {$WARN SYMBOL_DEPRECATED OFF}
    age:=FileAge(ParamStr(0));
    {$WARN SYMBOL_DEPRECATED ON}
    dt:=FileDateToDateTime(age);
    try
      assign(f,name);
      rewrite(f);
      writeln(f,FormatDateTime('ddddd t',dt));
      writeln(f,'exe: '+exePath);
      writeln(f,'params: '+cmdParams);
      close(f);
      if keepOpened then begin
        AssignFile(logFile,name);
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
  if not enableCache and (cacheBuf<>'') then
    Logger.Flush;
end;

class procedure Logger.Flush;
begin
  if logFileName = '' then exit;
  logLock.Enter;
  try
    if cacheBuf = '' then exit;
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

initialization
  logLock.Init('Log');

finalization
  Logger.StopLogThread;
  Logger.Flush;
  if logAlwaysOpened then
    Close(logFile);
  logLock.Cleanup;
end.
