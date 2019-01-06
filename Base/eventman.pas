// Event manager
//
// Copyright (C) 2004 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
//
// Основные категории иерархии:
//  debug\ - отладочные события
//  kbd\ - события связанные с клавой (KeyDown, KeyUp)
//  mouse\ - события, связанные с мышью (Move, Delta, BtnDown, BtnUp)
//  net\ - события, связанные с приемом/передачей данных в сети
//  error\ - ошибки
//  engine\ - события в движке
//  UI\ - события интерфейса пользователя
unit EventMan;
interface
type
 // Режим обработки (режим привязывается обработчиком событий)
 TEventMode=(emQueued,   // события помещаются в очередь потока
             emInstant,  // обработчик вызывается немедленно в контексте того потока, где произошло событие
             emMixed); // если событие произошло в том же потоке - обрабатывается немедленно, иначе - в очередь

 // Строка, определяющая событие
 // Имеет формат: category\subcategory\..\sub..subcategory\name
// EventStr=string[127];
 EventStr=string;

 // Функция обработки события. Для блокировки обработки на более общих уровнях, должна вернуть false
 // In fact, return value is ignored
 TEventHandler=function(event:EventStr;tag:integer):boolean;

 // Установить обработчик для категории событий
 // При возникновении события, сперва вызываются более конкретные обработчики, а затем более общие
 procedure SetEventHandler(event:EventStr;handler:TEventHandler;mode:TEventMode=emInstant);
 // Убрать обработчик
 procedure RemoveEventHandler(handler:TEventHandler;event:EventStr='');

 // Сигнал о возникновении события (обрабатывается немедленно - в контексте текущего потока)
 procedure Signal(event:EventStr;tag:integer=0);
 procedure DelayedSignal(event:EventStr;delay:integer;tag:integer=0);

 // Обработать сигналы синхронно (если поток регистрирует синхронные обработчики, то он обязан регулярно вызывать эту функцию)
 procedure HandleSignals;

 // Связать событие с другим событием (тэг при этом может быть новым, но если это -1, то сохраняется старый)
 // Если redirect=true - при наличии линка отменет обработку сигнала на более общих уровнях
 procedure Link(event,newEvent:EventStr;tag:integer=-1;redirect:boolean=false);
 // Удалить связь между событиями
 procedure Unlink(event,linkedEvent:EventStr);
 // Удалить все связанные события (втч для всех подсобытий)
 procedure UnlinkAll(event:EventStr='');

implementation
 uses CrossPlatform, SysUtils, MyServis;
const
 queueMask = 1023;
type
 PHandler=^THandler;
 THandler=record
  event:EventStr;
  handler:TEventHandler;
  threadNum:integer; // индекс в массиве нитей (-1 - асинхронная обработка)
  mode:TEventMode;
  next:PHandler;
 end;

 PLink=^TLink;
 TLink=record
  event:EventStr;
  LinkedEvent:EventStr;
  tag:integer;
  next:PLink;
  redirect,keepOriginalTag:boolean;
 end;

 // Элемент очереди событий
 TQueuedEvent=record
  event:EventStr; // событие
  handler:TEventHandler; // кто должен его обработать
  tag:integer;
  callerThread:TThreadID; // поток, из которого было
  callerIP:cardinal; // точка вызова Signal
  time:int64; // когда событие должно быть обработано (только для отложенных сигналов)
 end;

 // Очередь событий для каждого потока, в котором есть какие-либо обработчики сигналов
 TThreadQueue=record
  thread:TThreadId;
  queue:array[0..queueMask] of TQueuedEvent;
  delayed:array[0..31] of TQueuedEvent;
  first,last,delcnt:integer;
  procedure LogQueueDump; // пишет в лог состояние всей очереди
 end;

var
 // Обработчики событий
 handlers:array[0..255] of PHandler;

 threads:array of TThreadQueue;
 threadCnt:integer=0;

 // Стек событий (макс. глубина - 8 событий)
 StackSize:integer=0;
// EventStack:array[1..8] of EventStr;
 eventnum:integer=0;
// stacklog:string;

 links:array[0..255] of PLink;

 CritSect:TMyCriticalSection;

 {$R-}

 procedure TThreadQueue.LogQueueDump;
  var
   i:integer;
   st:string;
   curtime:int64;
  begin
   st:='';
   i:=first;
   while i<>last do begin
    with queue[i] do
     st:=st+Format(#13#10'  %d) (thr:%d) %.8x -> %s:%d ',[i,callerThread,callerIP,event,tag]);
    i:=(i+1) and queueMask;
   end;
   ForceLogMessage('Thread '+GetThreadName(thread)+' event queue: '+st);
   st:=''; i:=0; curTime:=MyTickCount;
   while i<delCnt do begin
    with delayed[i] do
     st:=st+Format(#13#10'  %d) (thr:%d) %.8x -> %s:%d at %d',[i,callerThread,callerIP,event,tag,time-curtime]);
    inc(i);
   end;
   if st='' then st:='<empty>';
   ForceLogMessage('Thread '+GetThreadName(thread)+' delayed event queue: '+st);
  end;

 function Hash(st:EventStr):byte;
  var
   i:integer;
  begin
   result:=length(st);
   for i:=1 to Min2(length(st),30) do
    inc(result,byte(st[i]));
  end;

 procedure SetEventHandler(event:EventStr;handler:TEventHandler;mode:TEventMode=emInstant);
  var
   ThreadID:TThreadID;
   i,n:integer;
   ph:PHandler;
  begin
   // Если обработчик уже есть - повторно установлен не будет
   try
    EnterCriticalSection(CritSect);
    if event[length(event)]='\' then setlength(event,length(event)-1);

    if mode<>emInstant then begin
     ThreadID:=GetCurrentThreadID;
     n:=-1;
     for i:=1 to threadCnt do
      if threads[i-1].Thread=threadID then n:=i-1;
     if n=-1 then begin
      n:=ThreadCnt; inc(ThreadCnt);
      SetLength(threads,ThreadCnt);
      threads[n].Thread:=ThreadID;
      threads[n].first:=0;
      threads[n].last:=0;
      threads[n].delcnt:=0;
     end;
    end else
     n:=-1;

    event:=UpperCase(event);
    i:=hash(event);
    // поиск имеющегося обработчика
    ph:=handlers[i];
    while ph<>nil do begin
     if (@ph.handler=@handler) and (ph.event=event) then exit;
     ph:=ph.next;
    end;
    new(ph);
    ph.event:=event;
    ph.handler:=handler;
    ph.threadNum:=n;
    ph.mode:=mode;
    ph.next:=handlers[i];
    handlers[i]:=ph;

   finally
    LeaveCriticalSection(CritSect);
   end;
  end;

 procedure RemoveEventHandler(handler:TEventHandler;event:EventStr='');
  var
   i:integer;
   ph,prev,next:PHandler;
  begin
   EnterCriticalSection(CritSect);
   try
    if stacksize>0 then LogMessage('EventMan: Warning - removing event handler during signal processing, not a good style...',4);
    for i:=0 to 255 do
     if handlers[i]<>nil then begin
      ph:=handlers[i]; prev:=nil;            
      repeat
       if (@ph.handler=@handler) and
          ((event='') or (event=ph.event)) then begin
        next:=ph.next;
        if prev=nil then handlers[i]:=next else prev.next:=next;
        dispose(ph);
        ph:=next;
       end else begin
        prev:=ph;
        ph:=ph.next;
       end;
      until ph=nil;
     end;
   finally
    LeaveCriticalSection(CritSect);
   end;
  end;

 // Для внутреннего использования
 procedure HandleEvent(event:EventStr;tag:integer;time:int64;caller:cardinal=0);
  var
   i,h:integer;
   fl:boolean;
   hnd:PHandler;
   link:PLink;
   ev:EventStr;
   trID:TThreadID;
   cnt:integer;
   hndlist:array[1..150] of TEventHandler;
   allowBubble:boolean;
  begin
   ev:=event;
   event:=UpperCase(event);
   trID:=GetCurrentThreadID;
   try

   repeat
    allowBubble:=true;
    cnt:=0;
    // Поиск обработчиков
    h:=Hash(event);
    hnd:=handlers[h];
    while hnd<>nil do begin
     if hnd.event=event then
      if (hnd.mode=emQueued) or ((hnd.mode=emMixed) and (threads[hnd.threadNum].Thread<>trID)) then
          with threads[hnd.threadNum] do begin
        if time>0 then begin
         if delcnt>=31 then begin
          ForceLogMessage('EventMan: thread delayed queue overflow, event: '+ev+', handler: '+inttohex(cardinal(@hnd.handler),8));
          LogQueueDump;
          Sleep(1000);
          HandleEvent('Error\EventMan\QueueOverflow',cardinal(Thread),0,caller);
         end;
         delayed[delcnt].event:=ev;
         delayed[delcnt].handler:=hnd.handler;
         delayed[delcnt].tag:=tag;
         delayed[delcnt].time:=time;
         delayed[delCnt].callerThread:=trID;
         delayed[delCnt].callerIP:=caller;
         inc(delcnt);
        end else begin
         queue[last].event:=ev;
         queue[last].handler:=hnd.handler;
         queue[last].tag:=tag;
         queue[last].callerThread:=trID;
         queue[last].callerIP:=caller;
         i:=0;
         while (last+1 and queueMask)=first do begin
          // Сигнал в текущий поток
          if threads[hnd.threadNum].Thread=trID then begin
           CritSect.Leave;
           try
            HandleSignals;
           finally
            CritSect.Enter;
           end;
           break;
          end;
          if i=0 then ForceLogMessage('EventMan: queue overflow, waiting... Thread='+IntToStr(trID));
          inc(i);
          // Сперва подождать...
          if i<50 then begin
           CritSect.Leave;
           sleep(1);
           CritSect.Enter;
          end else begin
           first:=(first+1) and queueMask;
           ForceLogMessage('EventMan: wait finished, event: '+ev+', handler: '+inttohex(cardinal(@hnd.handler),8));
           LogQueueDump;
           Sleep(500);
           //HandleEvent('Error\EventMan\QueueOverflow',cardinal(Thread),0,caller);
          end;
         end;
         if i>0 then ForceLogMessage('EventMan: waited '+inttostr(i)+' times');
         last:=(last+1) and queueMask;
        end;
      end else begin
       if cnt<150 then inc(cnt);
       hndlist[cnt]:=hnd.handler;
      end;
     hnd:=hnd.next;
    end;
    LeaveCriticalSection(CritSect);
    try
     // Вызовы обработчиков вынесены в безопасный код для достижения реентабельности
     for i:=1 to cnt do
      try
       hndList[i](ev,tag);
      except
        on e:exception do ForceLogMessage('Error in event handler: '+ev+' - '+ExceptionMsg(e));
      end;
    finally
     EnterCriticalSection(CritSect);
    end;

    // Обработка связей
    link:=links[h];
    fl:=false;
    while link<>nil do begin
     if link.event=event then begin
      if link.keepOriginalTag then
       HandleEvent(link.LinkedEvent,tag,time,caller)
      else
       HandleEvent(link.LinkedEvent,link.tag,time,caller);
      if link.redirect then fl:=true;
     end;
     link:=link.next;
    end;
    if fl then break;

    // Переход к более общему событию
    fl:=true;
    for i:=length(event) downto 1 do
     if event[i]='\' then begin
      SetLength(event,i-1);
      fl:=false;
      break;
     end;
   until fl;

   finally
{    dec(StackSize);
    if stacksize=0 then stacklog:='';}
   end;
  end;


 procedure Signal(event:EventStr;tag:integer=0);
  var
   callerIP:cardinal; // адрес, откуда вызвана процедура
  begin
   if event='' then exit;
   {$IFDEF CPU386}
   asm
    mov eax,[ebp+4]
    mov callerIP,eax
   end;
   {$ELSE}
   callerIP:=0;
   {$ENDIF}
//   LogMessage('Signal: '+event+'='+inttostr(tag)+' thread='+inttostr(GetCurrentThreadID),4);
   EnterCriticalSection(CritSect);
   try
    HandleEvent(event,tag,0,callerIP);
   finally
    LeaveCriticalSection(CritSect);
   end;
  end;

 procedure DelayedSignal(event:EventStr;delay:integer;tag:integer=0);
  var
   callerIP:cardinal; // адрес, откуда вызвана процедура
  begin
   {$IFDEF CPU386}
   asm
    mov eax,[ebp+4]
    mov callerIP,eax
   end;
   {$ELSE}
   callerIP:=0;
   {$ENDIF}
   EnterCriticalSection(CritSect);
   try
    HandleEvent(event,tag,MyTickCount+delay,callerIP);
   finally
    LeaveCriticalSection(CritSect);
   end;
  end;

 procedure HandleSignals;
  type
   TCall=record
    proc:TEventHandler;
    event:Eventstr;
    tag:integer;
   end;
   { TThreadQueue }
  var
   ID:TThreadID;
   t:int64;
   i,j:integer;
   calls:array[1..100] of TCall;
   count:integer;
  begin
   EnterCriticalSection(CritSect);
   try
    ID:=GetCurrentThreadID;
    count:=0;
    for i:=1 to threadCnt do // Выбор очереди текущего потока
     if threads[i-1].Thread=ID then with threads[i-1] do begin
      while first<>last do begin
       if count=100 then break;
       inc(count);
       calls[count].proc:=queue[first].handler;
       calls[count].event:=queue[first].event;
       calls[count].tag:=queue[first].tag;
       first:=(first+1) and queueMask;
      end;
      if delcnt>0 then begin
       t:=MyTickCount; j:=0;
       while j<delcnt do begin
        if delayed[j].time<t then begin
         if count=100 then break;
         inc(count);
         calls[count].proc:=delayed[j].handler;
         calls[count].event:=delayed[j].event;
         calls[count].tag:=delayed[j].tag;
         dec(delcnt);
         delayed[j]:=delayed[delcnt];
        end else inc(j);
       end;
      end;
      break;
     end;
   finally
    LeaveCriticalSection(CritSect);
   end;
   for i:=1 to count do try
    calls[i].proc(calls[i].event,calls[i].tag);
    except
      on e:exception do ForceLogMessage(Format('Error in handling event: %s:%d Thread: %s - %s ',
        [calls[i].event,calls[i].tag,GetThreadName,ExceptionMsg(e)]));
    end;
  end;

 procedure Link(event,newEvent:EventStr;tag:integer=-1;redirect:boolean=false);
  var
   n:byte;
   link:PLink;
  begin
   EnterCriticalSection(CritSect);
   try
    event:=UpperCase(event);
    n:=Hash(event);
    new(link);
    link.next:=links[n];
    links[n]:=link;

    link.event:=event;
    link.LinkedEvent:=UpperCase(newEvent);
    link.tag:=tag;
    link.redirect:=redirect;
    link.keepOriginalTag:=tag=-1;
   finally
    LeaveCriticalSection(CritSect);
   end;
  end;

 // Для внутреннего использования
 procedure DeleteLink(hash:byte;var prev,link:PLink);
  var
   s:PLink;
  begin
   s:=link.next;
   if prev<>nil then begin
    prev.next:=link.next;
   end else links[hash]:=link.next;
   Dispose(link);
   link:=s;
  end;

 procedure Unlink(event,linkedEvent:EventStr);
  var
   n:byte;
   prev,link:PLink;
  begin
   EnterCriticalSection(CritSect);
   try
    n:=Hash(event);
    prev:=nil; link:=links[n];
    if link=nil then exit;
    event:=UpperCase(event);
    linkedEvent:=UpperCase(linkedEvent);
    repeat
     if (link.event=event) and
        (UpperCase(link.LinkedEvent)=linkedEvent) then
      DeleteLink(n,prev,link)
     else begin
      prev:=link;
      link:=link.next;
     end;
    until link=nil;
   finally
    LeaveCriticalSection(CritSect);
   end;
  end;

 procedure UnlinkAll(event:EventStr='');
  var
   i:integer;
   prev,link:PLink;
  begin
   EnterCriticalSection(CritSect);
   try
    for i:=0 to 255 do
     if links[i]<>nil then begin
      prev:=nil; link:=links[i];
      repeat
       if link.event=event then DeleteLink(i,prev,link)
       else begin
        prev:=link;
        link:=link.next;
       end;
      until link=nil;
     end;
   finally
    LeaveCriticalSection(CritSect);
   end;
  end;

initialization
 InitCritSect(critSect,'EventMan',300);
// InitializeCriticalSection(critSect);

finalization
 DeleteCritSect(critSect);
end.

