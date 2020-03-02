// Generic support for advanced in-memory logging and log files
// Copyright (C) 2012-2016 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Logging;
interface
 uses windows,MyServis;

 const
  // Степени аварийности сообщений
  logDebug     = 0; // вспомогательные отладочные сведения
  logInfo      = 1; // малозначительное событие
  logNormal    = 2; // регулярное событие, имеющее значение, но не указывающее на проблему
  logImportant = 3; // важное, ключевое событие
  logWarn      = 3; // что-то необычное, ненормальное но не представляющее опасности
  logError     = 4; // сбой, ошибка с возможностью продолжения работы без аварийного завершения
  logCritical  = 5; // фатальный сбой - аварийная ситуация, вызывающая завершение работы

  // Категории (группы) сообщений
  lgHTTP     = 1;
  lgDatabase = 2;
  lgChat     = 3;
  lgAI       = 4;
  lgTurnData = 5; // данные, которыми обмениваются между собой игроки

 var
  maxLogMsgSize:integer=2000; // larger messages will be truncated
  avgMsgPerSecondLimit:integer = 500; // лимит на скорость поступления сообщений (в среднем в секунду)
  minLogFileLevel:integer = logInfo; // min level of message to be stored in log file
  minLogMemLevel:integer = logInfo; // min level of message to be stored in memory
  logMsgCounter:int64; // global msg counter (сколько вообще сообщений было добавлено, а не сколько хранится)
  numFailures:integer; // счётчик сообщений с уровнем logError и выше

  levelToCopyToMainLog:integer = logNormal; // дублировать сообщения с таким уровнем в основной лог

 // Initialize logging system:
 // Allocate "memsize" megabytes for in-memory logging (0 - keep current size, max 1024)
 // Set "path" for log files (daily rotation enabled)
 // Write messages with level>="fileFilter" to log files
 procedure InitLogging(memsize:integer;path:string;fileFilter:integer=logNormal);

 // level: 0 - debug, 1 - info, 2 - normal, 3 - warning, 4 - error, 5 - critical
 procedure LogMsg(st:AnsiString;level:byte=logNormal;msgtype:byte=0); overload;
 procedure LogMsg(st:AnsiString;params:array of const;level:byte=logNormal;msgtype:byte=0); overload;

 // Cброс накопленных сообщений в файл
 procedure FlushLogs;

 // Returns (partial) content of the in-memory log (CAUTION! May consume significant time and memory!)
 function FetchLog(fromDate,toDate:TDateTime;minLevel:byte;limit:integer=10000):StringArr;

 // Аварийный сброс лога в файл (amount килобайт)
 procedure AlarmLog(filename:string;amount:integer=1024);

 // msgCount - всего сообщений
 // msgCount1 - сообщений уровня info и выше
 function LogMemUsage(out msgCount,msgCount1:integer):integer;

 // Save some log messages for further use after restart
 procedure SaveLogMessages;

implementation
 uses SysUtils,MMSystem;

 type
  TMsgHeader=packed record
   size:word;
   level,kind:byte;
   date:TDateTime;
  end;
  // Single log message
  TLogMessage=record
   date:TDateTime;
   level,kind:byte;
   msg:AnsiString;
  end;
  //
  TLogBuffer=class
   messages:array[1..1000] of TLogMessage;
   count,count1:integer;
   minDate,maxDate:TDateTime;
   next:TLogBuffer;
   constructor Create;
   destructor Destroy; override;
   function GetDump(minLevel:integer):ByteArray;
  end;
 var
  logCache:string;
  logSect:TMyCriticalSection;
  logDir:string;
  lastTime:TSystemTime; // time of the last message for log file
  buffer:array of byte; // main buffer
  firstUsedByte,firstFreeByte:integer; // если совпадают - буфер пуст
  freeSpace:integer;

  firstBuffer,lastBuffer:TLogBuffer;
  bufferCount,maxBuffers:integer;
  initialized:boolean=false;

  avgMsgCounter:integer; // Счётчик сообщений, раз в секунду уменьшается на avgMsgPerSecondLimit, но не ниже 0
  msgBlocked:boolean=false;

 // Кол-во строк в логе (всего и с важностью выше Debug)
 function LogMemUsage(out msgCount,msgCount1:integer):integer;
  var
   buf:TLogBuffer;
   i:integer;
  begin
   msgCount:=0; msgCount1:=0; result:=0;
   EnterCriticalSection(logSect);
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
    LeaveCriticalSection(logSect);
   end;
  end;

 // MUST BE CALLED FROM LOGSECT!
 procedure AddLogMsg(date:TDateTime;level,kind:byte;msg:string);
  var
   buf:TLogBuffer;
  begin
   ASSERT(logSect.lockCount>0,'LogSect!!!');

   // 1. Need new buffer?
   if (lastBuffer<>nil) and (lastBuffer.count<1000) then buf:=lastBuffer
    else begin
     buf:=TLogBuffer.Create;
    end;
   // 2. Add message
   inc(logMsgCounter);
   inc(buf.count);
   if level>logDebug then inc(buf.count1);
   buf.messages[buf.count].date:=date;
   buf.messages[buf.count].level:=level;
   buf.messages[buf.count].kind:=kind;
   buf.messages[buf.count].msg:=msg;
   if date<buf.minDate then buf.minDate:=date;
   if date>buf.maxDate then buf.maxDate:=date;
   while bufferCount>maxBuffers do firstBuffer.Free;
  end;

 procedure SaveLogMessages;
  var
   f:file;
   i,n,level:integer;
   buf:TLogBuffer;
   dump:ByteArray;
  begin
   EnterCriticalSection(logSect);
   try
   Assign(f,logDir+'logDump.log');
   Rewrite(f,1);
   n:=0;
   buf:=firstBuffer;
   while buf<>nil do begin
    inc(n); buf:=buf.next;
   end;
   i:=bufferCount;
   buf:=firstBuffer;
   LogMsg(Format('Flushing log: %d = %d buffers',[bufferCount,n]),logImportant);
   i:=n;
   while buf<>nil do begin
    level:=logDebug;
    if i>50 then level:=logInfo;
    if i>150 then level:=logNormal;
    if i>500 then level:=logWarn;
    dump:=buf.GetDump(level);
    BlockWrite(f,dump[0],length(dump));
    buf:=buf.next;
    dec(i);
   end;
   Close(f);
   finally
    LeaveCriticalSection(logSect);
   end;
  end;

 procedure LoadOldMessages;
  var
   f:file;
   dump:ByteArray;
   p:integer;
   date:TDateTime;
   level,kind:byte;
   size:word;
   fname,msg:string;
  begin
   try
    fname:=logDir+'logDump.log';
    dump:=LoadFileAsBytes(fname);
    EnterCriticalSection(logSect);
    try
    p:=0;
    while p<high(dump) do begin
     move(dump[p],date,8); inc(p,8);
     kind:=dump[p]; inc(p);
     level:=dump[p]; inc(p);
     size:=dump[p]+dump[p+1]*256; inc(p,2);
     SetLength(msg,size);
     if size>0 then begin
      move(dump[p],msg[1],size);
      inc(p,size);
     end;
     AddLogMsg(date,level,kind,msg);
    end;
    finally
     LeaveCriticalSection(logSect);
    end;
   except
    on e:Exception do ForceLogMessage('Error in LoadOldMessages ('+fname+'): '+e.message);
   end;
  end;

 // 12-character time: HH:MM:SS.zzz
 procedure FormatTimeStr(p:PByte;time:TSystemTime);
  begin
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
  end;

 // Read "size" bytes from the cyclic log buffer starting from "posit"
 function ReadData(posit,size:integer;buf:PByte):integer;
  var
   bufSize,d:integer;
  begin
   bufSize:=length(buffer);
   if posit+size>bufSize then begin // partial?
    d:=bufSize-posit;
    move(buffer[posit],buf^,d);
    posit:=0; inc(buf,d);
    dec(size,d);
   end;
   move(buffer[posit],buf^,size);
   inc(posit,size);
   if posit>=bufSize then dec(posit,bufSize);
   result:=posit;
  end;

 function FetchLog(fromDate,toDate:TDateTime;minLevel:byte;limit:integer):StringArr;
  var
   cnt,max:integer;
   i,pos,l:integer;
   hdr:TMsgHeader;
   st:string;
   sTime:TSystemTime;
   buf:TLogBuffer;
   timeStr:string[20];
  begin
   EnterCriticalSection(logSect);
   try
    try
     max:=limit; // initial array size
     cnt:=0;
     SetLength(result,max);
     // New code
     buf:=firstBuffer;
     SetLength(timeStr,12);
     while buf<>nil do begin
      if (buf.minDate<toDate) or (buf.maxDate>fromDate) then
       for i:=1 to buf.count do begin
        if cnt>=limit then break;
        with buf.messages[i] do begin
         if (level<minLevel) or
            (date<fromDate) or
            (date>ToDate) then continue;
         DateTimeToSystemTime(date,sTime);
         FormatTimeStr(@timestr[1],sTime);
         result[cnt]:=Format('%s %d%d %s',[timestr,kind,level,msg]);
        end;
        inc(cnt);
       end;
      buf:=buf.next;
     end;
     SetLength(result,cnt);
    except
     on e:Exception do begin
      SetLength(result,0);
      raise EError.Create('Fetch Log error: '+e.message);
     end;
    end;
   finally
    LeaveCriticalSection(logSect);
   end;
  end;

 procedure FlushLogs;
  var
   date:string;
   f:text;
   fname:string;
  begin
   EnterCriticalSection(logSect);
   try
    if logCache='' then exit;
    setLength(date,6);
    date[1]:=chr(48+(lasttime.wYear div 10) mod 10);
    date[2]:=chr(48+lasttime.wYear mod 10);
    date[3]:=chr(48+lasttime.wMonth div 10);
    date[4]:=chr(48+lasttime.wMonth mod 10);
    date[5]:=chr(48+lasttime.wDay div 10);
    date[6]:=chr(48+lasttime.wDay mod 10);

    fname:=logDir+date+'.log';
    assign(f,fname);
    try
     if FileExists(fname) then append(f)
      else rewrite(f);
     write(f,logCache);
     logCache:='';
     close(f);
    except
     on e:exception do ForceLogMessage('ERROR: Can''t flush log to '+fname+': '+e.message);
    end;
   finally
    LeaveCriticalSection(logSect);
   end;
  end;

 procedure LogMsg(st:AnsiString;level:byte=logNormal;msgtype:byte=0);
  var
   date:string[19];
   time:TSystemTime;
   hdr:TMsgHeader;
   size:word;
  begin
   if level>=logError then inc(numFailures);
   if level<minLogMemlevel then exit;
   if length(st)>maxLogMsgSize then SetLength(st,maxLogMsgSize);
   if level=levelToCopyToMainLog then LogMessage(st);
   if level>levelToCopyToMainLog then ForceLogMessage(st);
   if not initialized then exit;
   EnterCriticalSection(logSect);
   try
    time:=GetUTCTime;
    if (time.wDay<>lastTime.wDay) and (logCache<>'') then FlushLogs; // day changed
    if time.wSecond<>lastTime.wSecond then begin
     dec(avgMsgCounter,avgMsgPerSecondLimit);
     if avgMsgCounter<0 then avgMsgCounter:=0;
    end;
    lastTime:=time;
    if (avgMsgCounter>500) and (level<logNormal) then begin
     if not msgblocked then begin
      st:='Log flood protection';
      AddLogMsg(SystemTimeToDateTime(time),logImportant,0,st);
      logCache:=logCache+st+#13#10;
     end;
     msgblocked:=true;
     exit; // too many messages
    end;
    msgblocked:=false;
    inc(avgMsgCounter);
    hdr.date:=SystemTimeToDateTime(time);
    hdr.size:=sizeof(hdr)+length(st);
    hdr.level:=level;
    hdr.kind:=msgtype;

    AddLogMsg(hdr.date,level,msgtype,st);

    if level>=minLogFileLevel then begin
     // Write to file
     setLength(date,14);
     FormatTimeStr(@date[1],time);
     date[13]:=' ';
     date[14]:=' ';

     st:=date+st;
     logCache:=logCache+st+#13#10;
     if level>=logWarn then FlushLogs;
    end;
   finally
    LeaveCriticalSection(logSect);
   end;
  end;

 procedure LogMsg(st:AnsiString;params:array of const;level:byte=logNormal;msgtype:byte=0);
  begin
   LogMsg(Format(st,params),level,msgtype);
  end;

 // Аварийный сброс лога в файл (amount килобайт)
 procedure AlarmLog(filename:string;amount:integer=1024);
  var
   saveFirst,space:integer;
   size:word;
   log:StringArr;
   f:text;
   i:integer;
  begin
   try
   amount:=amount*1024;
   if (amount<=0) or (amount>length(buffer)) then exit;
   EnterCriticalSection(logSect);
   try
    saveFirst:=firstUsedByte;
    space:=length(buffer)-freeSpace;
    while space>amount do begin
     ReadData(firstUsedByte,2,@size);
     inc(firstUsedByte,size);
     if firstUsedByte>=length(buffer) then dec(firstUsedByte,length(buffer));
     dec(space,size);
    end;
    log:=FetchLog(1,99999,0);
   finally
    firstUsedByte:=saveFirst;
    LeaveCriticalSection(logSect);
   end;
   Assign(F,filename);
   rewrite(f);
   for i:=0 to length(log)-1 do
    writeln(f,log[i]);
   close(f);
   except
    on e:exception do ForceLogMessage('Failed to create alarm log: '+e.message);
   end;
  end;

 procedure InitLogging(memsize:integer;path:string;fileFilter:integer=logNormal);
  begin
   if (memsize<1) or (memsize>1024) then raise EError.Create('Illegal log area size');
   try
   EnterCriticalSection(logSect);
   try
    if memsize>0 then begin
     freeSpace:=memsize*1024*1024;
     SetLength(buffer,freeSpace);
     firstFreeByte:=0;
     firstUsedByte:=0;
    end;
    if path<>'' then logDir:=path;
    if LastChar(logDir)<>PathSeparator then logDir:=logDir+PathSeparator;
    minLogFileLevel:=fileFilter;
    minLogMemLevel:=0;

    // New logging
    maxBuffers:=memSize*16;
    if not initialized then begin
     firstBuffer:=nil;
     lastBuffer:=nil;
     bufferCount:=0;
     If FileExists(logDir+'logDump.log') then LoadOldMessages;
     initialized:=true;
    end;
   finally
    LeaveCriticalSection(logSect);
   end;
   except
    on e:exception do ForceLogMessage('InitLogging error ('+logDir+'): '+e.message);
   end;
  end;

{ TLogBuffer }

constructor TLogBuffer.Create;
begin
 EnterCriticalSection(logSect);
 try
  count:=0; count1:=0;
  minDate:=MaxDateTime;
  maxDate:=MinDateTime;
  next:=nil;
  inc(bufferCount);
  if lastBuffer<>nil then begin
   lastBuffer.next:=self;
  end;
  if firstBuffer=nil then firstBuffer:=self;
  lastBuffer:=self;
 finally
  LeaveCriticalSection(logSect);
 end;
end;

destructor TLogBuffer.Destroy;
begin
 EnterCriticalSection(logSect);
 try
  if firstBuffer=self then firstBuffer:=self.next;
  if lastBuffer=self then lastBuffer:=nil;
  dec(bufferCount);
  inherited;
 finally
  LeaveCriticalSection(logSect);
 end;
end;

function TLogBuffer.GetDump(minLevel: integer): ByteArray;
var
 i,p,l:integer;
begin
 SetLength(result,200000);
 p:=0;
 EnterCriticalSection(logSect);
 try
 for i:=1 to count do begin
  if messages[i].level<minLevel then continue;
  move(messages[i].date,result[p],8); inc(p,8);
  result[p]:=messages[i].kind; inc(p);
  result[p]:=messages[i].level; inc(p);
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
  LeaveCriticalSection(logSect);
 end;
 SetLength(result,p);
end;

initialization
 InitCritSect(logSect,'Logging',190);
finalization
 DeleteCritSect(logSect);
end.
