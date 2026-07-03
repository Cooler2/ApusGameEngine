// Advanced in-memory logging with daily file rotation
// Integrates with Apus.Log as a custom handler (in-memory store + daily rotation).
//
// SCOPE: Supplemental logging for long-running servers — in-memory ring buffer,
// date-range queries, daily log rotation, flood protection, crash recovery via dump.
// Works on top of Apus.Log: all messages come via the registered custom handler.
//
// ADD HERE: In-memory log queries, daily rotation, alarm dumps, persistence across restarts.
// DON'T ADD: Basic file logging (→ Apus.Log), profiling (→ Apus.Profiling).
//
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.Logging;
interface
 uses Apus.Core, Apus.Log;

 var
  maxLogMsgSize:integer=2000; // larger messages will be truncated
  avgMsgPerSecondLimit:integer=500; // message rate limit (avg per second)
  minLogFileLevel:TSeverity=TSeverity.Info; // min level to write to daily log file
  minLogMemLevel:TSeverity=TSeverity.Info;  // min level to store in memory
  logMsgCounter:int64; // total messages added (not just currently stored)
  numFailures:integer; // count of Error and Fatal messages

 // Initialize: allocate memsize MB for in-memory log, set path for daily log files
 // Daily files are named YYMMDD.log and written to path\
 // fileFilter: min severity to write to daily log files
 procedure InitLogging(memsize:integer; path:string; fileFilter:TSeverity=TSeverity.Normal);

 // Flush daily log file cache to disk
 procedure FlushLogs;

 // Returns messages from in-memory log filtered by date range and level
 function FetchLog(fromDate,toDate:TDateTime; minLevel:TSeverity; limit:integer=10000):Strings8;

 // Emergency dump of in-memory log to file (amount = max kilobytes to write)
 procedure AlarmLog(filename:string; amount:integer=1024);

 // Returns in-memory usage: msgCount (total), msgCount1 (Info+), result = bytes
 function LogMemUsage(out msgCount,msgCount1:integer):integer;

 // Save log messages to disk for recovery after restart
 procedure SaveLogMessages;

implementation
 uses SysUtils, Apus.Files, Apus.Threads
   {$IFDEF MSWINDOWS},Windows{$ENDIF};

 type
  TLogMessage=record
   date:TDateTime;
   level:TSeverity;
   kind:byte;
   msg:String8;
  end;

  TLogBuffer=class
   messages:array[1..1000] of TLogMessage;
   count,count1:integer;
   minDate,maxDate:TDateTime;
   next:TLogBuffer;
   constructor Create;
   destructor Destroy; override;
   function GetDump(minLevel:TSeverity):ByteArray;
  end;

 var
  logCache:String8;
  logSect:TLock;
  logDir:string;
  lastTime:TSystemTime; // time of last message (for daily rotation)

  firstBuffer,lastBuffer:TLogBuffer;
  bufferCount,maxBuffers:integer;
  inited:boolean=false;

  avgMsgCounter:integer; // flood counter, decremented by avgMsgPerSecondLimit per second
  msgBlocked:boolean=false;

 // Must be called with logSect held
 procedure AddLogMsg(date:TDateTime; level:TSeverity; kind:byte; const msg:String8);
  var
   buf:TLogBuffer;
  begin
   // must be called with logSect held
   if (lastBuffer<>nil) and (lastBuffer.count<1000) then buf:=lastBuffer
    else buf:=TLogBuffer.Create;
   inc(logMsgCounter);
   inc(buf.count);
   if level>TSeverity.Debug then inc(buf.count1);
   buf.messages[buf.count].date:=date;
   buf.messages[buf.count].level:=level;
   buf.messages[buf.count].kind:=kind;
   buf.messages[buf.count].msg:=msg;
   if date<buf.minDate then buf.minDate:=date;
   if date>buf.maxDate then buf.maxDate:=date;
   while bufferCount>maxBuffers do firstBuffer.Free;
  end;

 // 12-character time: HH:MM:SS.mmm
 procedure FormatTimeStr(p:PByte; time:TSystemTime);
  begin
   {$IFDEF FPC}
   p^:=48+time.Hour div 10; inc(p);
   p^:=48+time.Hour mod 10; inc(p);
   p^:=ord(':'); inc(p);
   p^:=48+time.Minute div 10; inc(p);
   p^:=48+time.Minute mod 10; inc(p);
   p^:=ord(':'); inc(p);
   p^:=48+time.Second div 10; inc(p);
   p^:=48+time.Second mod 10; inc(p);
   p^:=ord('.'); inc(p);
   p^:=48+time.Millisecond div 100; inc(p);
   p^:=48+(time.Millisecond div 10) mod 10; inc(p);
   p^:=48+time.Millisecond mod 10;
   {$ELSE}
   p^:=48+time.wHour div 10; inc(p);
   p^:=48+time.wHour mod 10; inc(p);
   p^:=ord(':'); inc(p);
   p^:=48+time.wMinute div 10; inc(p);
   p^:=48+time.wMinute mod 10; inc(p);
   p^:=ord(':'); inc(p);
   p^:=48+time.wSecond div 10; inc(p);
   p^:=48+time.wSecond mod 10; inc(p);
   p^:=ord('.'); inc(p);
   p^:=48+time.wMilliseconds div 100; inc(p);
   p^:=48+(time.wMilliseconds div 10) mod 10; inc(p);
   p^:=48+time.wMilliseconds mod 10;
   {$ENDIF}
  end;

 // Custom handler called by Apus.Log for every Log.Msg call
 procedure AdvancedLogHandler(msg:String8; category:byte; level:TSeverity);
  var
   time:TSystemTime;
   date:string[14];
   st:String8;
  begin
   if level>=TSeverity.Error then inc(numFailures);
   if length(msg)>maxLogMsgSize then SetLength(msg,maxLogMsgSize);
   if not inited then exit;

   logSect.Enter;
   try
    {$IFDEF MSWINDOWS}GetSystemTime(time);{$ELSE}DateTimeToSystemTime(Now,time);{$ENDIF}
    // Day changed — flush to previous day's file
    {$IFDEF FPC}
    if (time.Day<>lastTime.Day) and (logCache<>'') then FlushLogs;
    // Flood protection
    if time.Second<>lastTime.Second then begin
    {$ELSE}
    if (time.wDay<>lastTime.wDay) and (logCache<>'') then FlushLogs;
    if time.wSecond<>lastTime.wSecond then begin
    {$ENDIF}
     dec(avgMsgCounter,avgMsgPerSecondLimit);
     if avgMsgCounter<0 then avgMsgCounter:=0;
    end;
    lastTime:=time;
    if (avgMsgCounter>500) and (level<TSeverity.Normal) then begin
     if not msgblocked then begin
      st:='Log flood protection';
      AddLogMsg(SystemTimeToDateTime(time),TSeverity.Forced,0,st);
      logCache:=logCache+st+LineBreak;
     end;
     msgblocked:=true;
     exit;
    end;
    msgblocked:=false;
    inc(avgMsgCounter);

    // Store in memory
    if level>=minLogMemLevel then
     AddLogMsg(SystemTimeToDateTime(time),level,category,msg);

    // Write to daily log file
    if level>=minLogFileLevel then begin
     setLength(date,14);
     FormatTimeStr(@date[1],time);
     date[13]:=' ';
     date[14]:=' ';
     if category>0 then
      logCache:=logCache+date+'['+IntToStr(category)+'] '+msg+LineBreak
     else
      logCache:=logCache+date+msg+LineBreak;
     if level>=TSeverity.Warn then FlushLogs;
    end;
   finally
    logSect.Leave;
   end;
  end;

 function LogMemUsage(out msgCount,msgCount1:integer):integer;
  var
   buf:TLogBuffer;
   i:integer;
  begin
   msgCount:=0; msgCount1:=0; result:=0;
   logSect.Enter;
   try
    buf:=firstBuffer;
    while buf<>nil do begin
     inc(msgCount,buf.count);
     inc(msgCount1,buf.count1);
     inc(result,sizeof(buf.messages));
     for i:=1 to buf.count do
      inc(result,8+length(buf.messages[i].msg));
     buf:=buf.next;
    end;
   finally
    logSect.Leave;
   end;
  end;

 procedure SaveLogMessages;
  var
   f:file;
   n,cnt:integer;
   buf:TLogBuffer;
   dump:ByteArray;
  begin
   logSect.Enter;
   try
    Assign(f,logDir+'logDump.log');
    Rewrite(f,1);
    n:=bufferCount;
    buf:=firstBuffer;
    cnt:=n;
    while buf<>nil do begin
     dump:=buf.GetDump(TSeverity.Debug);
     if cnt>50 then dump:=buf.GetDump(TSeverity.Info);
     if cnt>150 then dump:=buf.GetDump(TSeverity.Normal);
     if cnt>500 then dump:=buf.GetDump(TSeverity.Warn);
     BlockWrite(f,dump[0],length(dump));
     buf:=buf.next;
     dec(cnt);
    end;
    Close(f);
   finally
    logSect.Leave;
   end;
  end;

 procedure LoadOldMessages;
  var
   dump:ByteArray;
   p:integer;
   date:TDateTime;
   level,kind:byte;
   sz:word;
   fname,msg:string;
  begin
   try
    fname:=logDir+'logDump.log';
    dump:=Files.LoadAsBytes(fname);
    logSect.Enter;
    try
     p:=0;
     while p+12<=length(dump) do begin
      move(dump[p],date,8); inc(p,8);
      kind:=dump[p]; inc(p);
      level:=dump[p]; inc(p);
      sz:=dump[p]+dump[p+1]*256; inc(p,2);
      if p+sz>length(dump) then break;
      SetLength(msg,sz);
      if sz>0 then begin
       move(dump[p],msg[1],sz);
       inc(p,sz);
      end;
      AddLogMsg(date,TSeverity(level),kind,String8(msg));
     end;
    finally
     logSect.Leave;
    end;
   except
    on e:Exception do Log.Force('Error in LoadOldMessages ('+fname+'): '+e.message);
   end;
  end;

 procedure FlushLogs;
  var
   dateStr:string;
   f:text;
   fname:string;
  begin
   logSect.Enter;
   try
    if logCache='' then exit;
    setLength(dateStr,6);
    {$IFDEF FPC}
    dateStr[1]:=chr(48+(lasttime.Year div 10) mod 10);
    dateStr[2]:=chr(48+lasttime.Year mod 10);
    dateStr[3]:=chr(48+lasttime.Month div 10);
    dateStr[4]:=chr(48+lasttime.Month mod 10);
    dateStr[5]:=chr(48+lasttime.Day div 10);
    dateStr[6]:=chr(48+lasttime.Day mod 10);
    {$ELSE}
    dateStr[1]:=chr(48+(lasttime.wYear div 10) mod 10);
    dateStr[2]:=chr(48+lasttime.wYear mod 10);
    dateStr[3]:=chr(48+lasttime.wMonth div 10);
    dateStr[4]:=chr(48+lasttime.wMonth mod 10);
    dateStr[5]:=chr(48+lasttime.wDay div 10);
    dateStr[6]:=chr(48+lasttime.wDay mod 10);
    {$ENDIF}
    fname:=logDir+dateStr+'.log';
    assign(f,fname);
    try
     SetTextCodePage(f,CP_UTF8);
     if FileExists(fname) then append(f)
      else rewrite(f);
     write(f,logCache);
     logCache:='';
     close(f);
    except
     on e:exception do Log.Force('ERROR: Can''t flush log to '+fname+': '+e.message);
    end;
   finally
    logSect.Leave;
   end;
  end;

 function FetchLog(fromDate,toDate:TDateTime; minLevel:TSeverity; limit:integer):Strings8;
  var
   cnt:integer;
   i:integer;
   buf:TLogBuffer;
   sTime:TSystemTime;
   timeStr:string[12];
  begin
   logSect.Enter;
   try
    try
     SetLength(result,limit);
     cnt:=0;
     buf:=firstBuffer;
     SetLength(timeStr,12);
     while buf<>nil do begin
      if (buf.minDate<toDate) and (buf.maxDate>fromDate) then
       for i:=1 to buf.count do begin
        if cnt>=limit then break;
        with buf.messages[i] do begin
         if (level<minLevel) or (date<fromDate) or (date>toDate) then continue;
         DateTimeToSystemTime(date,sTime);
         FormatTimeStr(@timestr[1],sTime);
         result[cnt]:=timestr+' '+IntToStr(ord(level))+IntToStr(kind)+' '+msg;
        end;
        inc(cnt);
       end;
      buf:=buf.next;
     end;
     SetLength(result,cnt);
    except
     on e:Exception do begin
      SetLength(result,0);
      raise EError.Create('FetchLog error: '+e.message);
     end;
    end;
   finally
    logSect.Leave;
   end;
  end;

 procedure AlarmLog(filename:string; amount:integer=1024);
  var
   lines:Strings8;
   f:text;
   i:integer;
  begin
   try
    lines:=FetchLog(1,99999,TSeverity.Debug,amount*50); // rough limit by count
    Assign(f,filename);
    rewrite(f);
    for i:=0 to length(lines)-1 do
     writeln(f,lines[i]);
    close(f);
   except
    on e:exception do Log.Force('Failed to create alarm log: '+e.message);
   end;
  end;

 procedure InitLogging(memsize:integer; path:string; fileFilter:TSeverity=TSeverity.Normal);
  begin
   if (memsize<1) or (memsize>1024) then raise EError.Create('Illegal log area size');
   try
   logSect.Enter;
   try
    if path<>'' then logDir:=path;
    if logDir<>'' then begin
     if (logDir<>'') and (logDir[length(logDir)]<>PathSeparator) then logDir:=logDir+PathSeparator;
     ForceDirectories(logDir);
    end;
    minLogFileLevel:=fileFilter;
    minLogMemLevel:=TSeverity.Debug;
    maxBuffers:=memSize*16;
    if not inited then begin
     firstBuffer:=nil;
     lastBuffer:=nil;
     bufferCount:=0;
     if FileExists(logDir+'logDump.log') then LoadOldMessages;
     inited:=true;
    end;
    // Register as custom handler — we add to Apus.Log pipeline
    Logger.SetCustomHandler(@AdvancedLogHandler,false);
   finally
    logSect.Leave;
   end;
   except
    on e:exception do Log.Force('InitLogging error ('+logDir+'): '+e.message);
   end;
  end;

{ TLogBuffer }

constructor TLogBuffer.Create;
begin
 logSect.Enter;
 try
  count:=0; count1:=0;
  minDate:=1e15; // larger than any valid TDateTime
  maxDate:=0;
  next:=nil;
  inc(bufferCount);
  if lastBuffer<>nil then lastBuffer.next:=self;
  if firstBuffer=nil then firstBuffer:=self;
  lastBuffer:=self;
 finally
  logSect.Leave;
 end;
end;

destructor TLogBuffer.Destroy;
begin
 logSect.Enter;
 try
  if firstBuffer=self then firstBuffer:=self.next;
  if lastBuffer=self then lastBuffer:=nil;
  dec(bufferCount);
  inherited;
 finally
  logSect.Leave;
 end;
end;

function TLogBuffer.GetDump(minLevel:TSeverity):ByteArray;
var
 i,p,l:integer;
begin
 SetLength(result,200000);
 p:=0;
 logSect.Enter;
 try
  for i:=1 to count do begin
   if messages[i].level<minLevel then continue;
   move(messages[i].date,result[p],8); inc(p,8);
   result[p]:=messages[i].kind; inc(p);
   result[p]:=ord(messages[i].level); inc(p);
   l:=length(messages[i].msg);
   if l>4096 then l:=4096;
   result[p]:=l and 255; inc(p);
   result[p]:=l shr 8; inc(p);
   if l>0 then begin
    move(messages[i].msg[1],result[p],l);
    inc(p,l);
   end;
  end;
 finally
  logSect.Leave;
 end;
 SetLength(result,p);
end;

initialization
 logSect.Init('Logging',190);
end.
