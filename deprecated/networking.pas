// Network engine layer
//
// Copyright (C) 2005 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)

unit networking;
interface
 var
  // Глобальные настройки
  // если true - будет отзываться на бродкасты, иначе - игнорировать
  LanServerMode:boolean;
  ForceWANmode:boolean=false; // работать в режиме Internet даже в локалке
  ConnectionsOnly:boolean=false; // если true - шлет разрыв соединения в ответ на любое сообщение, не относящееся к соединению

 type
  // Соединение
  // Можно использовать несколько соединений, однако если этот класс используется,
  // то неаккуратное обращение с глобальными процедурами может нарушить его работу
  TConnection=class
   connected:boolean;
   remIP:cardinal;
   remPort:word;
   ping:single; // Время доставки последнего пакета (сек.)
   // Если локальный порт указан - после создания соединение будет в режиме ожидания
   // (т.е. ждать когда оно будет установлено по инициативе другой стороны)
   // Если сетевая подсистема уже была инициализирована (втч другим соединением),
   // то значение localPort игнорируется
   constructor Create(localPort:word);
   destructor Destroy; override;
   // Подключиться к указанной системе
   // (если target=0 - искать систему в LAN и если найдем - подключиться)
   procedure Connect(target:cardinal;port:word);
   // Отключиться (с уведомлением)
   procedure Disconnect;
   // Послать блок данных
   procedure SendData(buf:pointer;size:integer);
  protected
   status:integer; // 0 - ожидаем подключения, 1 - подключаемся, 2 - подключено
  end;

 procedure NetInit(port:word);
 procedure NetDone;

 // Искать в локальной сети адрес сервера (если не ждать, то вернет его сигналом)
 // Если адрес не найден - вернет 0
 function GetLanServerAddress(port:word;wait:boolean):cardinal;

 // парсит и ресолвит (если необходимо) адрес, заданный в виде строки
 // Внимание!!! Может занять много времени! Возвращает 0 или код ошибки
 function GetInternetAddress(adr:string;wait:boolean;var ip:cardinal;var port:word):integer;

 // Послать блок данных по указанному адресу с гарантией доставки
 function Send(adr:cardinal;port:word;data:pointer;size:integer):integer;

 // получить указатель на полученный блок данных (и его размер)
 // handle передается в параметре события Net\onData
 function GetMsg(handle:integer;var data:pointer):integer;

 procedure GetMsgOrigin(handle:integer;var ip:cardinal;var port:word);

 // Создать дамп структур в файл (детализация: 0..2)
 procedure Dump(detailLevel:byte=1;reason:string='');

implementation
 uses windows,eventMan,classes,winsock,SysUtils,network,MyServis;
 type
  TNetThread=class(TThread)
   procedure Execute; override;
  end;

  // Исходящее сообщение (запрос на доставку)
  TDeliveryRequest=class
   id:integer;
   dest_adr:cardinal;
   dest_port:word;
   data:array of byte;
   last_sent,          // последняя часть, которая хотя бы раз посылалась
   can_send,           // можно ли посылать новые части
   confirmed_parts,    // сколько частей было подтверждено (непрерывный блок)
   conf_bits,          // маска подтвержденных частей следом
   resend_time,        // момент, когда нужно повторить отправку неподтвержденных частей
   resend_count,       // кол-во перепосылок
   timeout:integer;    // момент, когда нужно прервать доставку
   created:integer;    // момент создания запроса
  end;

  // Входящее сообщение
  TQueuedMessage=class
   id:integer;
   ip:cardinal;
   port:word;
   data:array of byte;
   parts:cardinal;     // Маска полученных частей
   part_first,part_total:integer; // номер части, с которой начинается маска, общее кол-во частей
   counter:integer;    // Таймер, по которому можно определить, что доставка была прервана
   session:byte; // ID сессии
  end;

  // Источник получения пакета
  TSource=record
   ip:cardinal;
   port:word;
   res:word;
   lastID:integer;
   timeout:integer;
   sess:byte; // ID текущей сессии с этого источника (чтобы не рассматривать устаревшие сообщения)
  end;

 var
  udp:UDPSocket2;
  thread:TNetThread;
  initialized:integer;
  critSect:TMyCriticalSection;
  MainTimer:integer;
  requests:array[1..3000] of TDeliveryRequest;
  count{,lastID}:integer;
  size:integer;
  recvBuf:array[0..2047] of byte;

  queue:array[0..16383] of TQueuedMessage;
  qFirst,qFree:integer;

  sources:array[1..300] of TSource;
  scount:integer;

  targets:array[1..300] of TSource;
  tcount:integer;

  // Поиск ЛАН-сервера
  InstID:integer;
  LookingForServer:integer; // таймер для поиска сервера
  LookingCounter:integer;
  ServerPort:word;
  ServerAddress:cardinal;   // если адрес сервера найден - здесь будет результат

  // Определение адреса
  resolveAdr:string;
  resolvedIP:cardinal;
  resolvedPort:word;

  // Соединения
  connections:array[1..300] of TConnection;
  conCnt:integer;

  initPort:word;
  lastDump:integer;

  debug_counter:integer;

 procedure ResolveAddress; forward;

 // Определяет, является ли адрес - адресом в локальной сети
 // (адрес в "подготовленном" виде, в том, как работает winsock)
 function IsLocalAdr(adr:cardinal):boolean;
  begin
   result:=false;
   if ForceWanMode then exit;
   if (adr and $FF=$10) or
      (adr and $F0FF=$10AC) or
      (adr and $FFFF=$A8C0) or
      (adr=$FFFFFFFF) or
      (adr=$100007F) then result:=true;
  end;

 function PutMsgToQueue(adr:cardinal;port:word): integer;
  var
   id:integer;
  begin
   result:=qFree;
   qFree:=(qFree+1) and 16383;
   if qFree=qFirst then begin
    ForceLogMessage('Queue overflow!!! Message deleted');
    FreeAndNil(queue[qFirst]);
    qFirst:=(qFirst+1) and 16383;
   end;
   queue[result]:=TQueuedMessage.Create;
   queue[result].parts:=0;
   queue[result].part_first:=0;
   queue[result].part_total:=-1;
   queue[result].ip:=adr;
   queue[result].port:=port;
  end;


 function GetLanServerAddress(port:word;wait:boolean):cardinal;
  begin
   EnterCriticalSection(critsect);
   try
    LookingForServer:=MainTimer+150;
    LookingCounter:=0;
    ServerPort:=port;
   finally
    LeaveCriticalSection(critSect);
   end;
   if wait then begin
    repeat
     sleep(50);
    until (LookingForServer=0) or (ServerAddress<>0);
    result:=ServerAddress;
   end;
  end;

 function GetInternetAddress(adr:string;wait:boolean;var ip:cardinal;var port:word):integer;
  begin
   EnterCriticalSection(critsect);
   try
    resolveAdr:=adr;
    if not wait then begin
     ResolveAddress;
     ip:=ResolvedIP;
     port:=ResolvedPort;
    end;
   finally
    LeaveCriticalSection(critSect);
   end;
   if wait then begin
    repeat
     sleep(50);
    until ResolveAdr='';
    ip:=ResolvedIP;
    port:=ResolvedPort;
    result:=0;
    if ip=0 then result:=-1;
   end;
  end;

 procedure NetInit(port:word);
  begin
   if initialized>0 then begin
    inc(initialized); exit;
   end;
   initport:=port;
   thread:=TNetThread.Create(true);
   thread.FreeOnTerminate:=true;
   thread.Resume;
   initialized:=1;
  end;

 procedure NetDone;
  var
   i:integer;
  begin
   dec(initialized);
   if initialized>0 then exit;
   EnterCriticalSection(critSect);
   try
    LogMessage(TimeStamp+' NET: finalizing');
    if thread<>nil then thread.Terminate;
   finally
    LeaveCriticalSection(critSect);
   end;
{   if (thread<>nil) and (GetCurrentThreadID<>thread.ThreadID) then begin
    i:=0;
    while thread<>nil do begin
     sleep(20); inc(i);
     LogMessage('waiting for NET terminate');
     if i>20 then begin
      ForceLogMessage('NET thread failed to terminate!');
      TerminateThread(thread.Handle,0);
      FreeAndNil(thread);
     end;
    end;
   end;}
  end;

 function min2(a,b:integer):integer;
  begin
   if a>b then result:=b else result:=a;
  end;

 function Send(adr:cardinal;port:word;data:pointer;size:integer):integer;
  var
   r:TDeliveryRequest;
   i,ID,min:integer;
  begin
//   LogMessage('Send called, count='+inttostr(critSect.LockCount)+','+inttostr(critSect.RecursionCount),6);
   EnterCriticalSection(critSect);
   try
   if count=2900 then ForceLogMessage('90% of requst storage used!');
   if count=3000 then begin
    Dump(1,'Out of request storage');
    raise EError.Create('Out of request storage');
   end;
   inc(count);
   // найти ID
   ID:=-1;
   for i:=1 to tcount do
    if (targets[i].ip=adr) and (targets[i].port=port) then begin
     inc(targets[i].lastID);
     ID:=targets[i].lastID;
     break;
    end;
   LogMessage('Send: ID='+inttostr(id),6);
   if ID=-1 then begin
    if tcount<300 then begin
     inc(tcount);
     min:=tcount;
    end else begin
     min:=1;
     for i:=2 to tcount do
      if targets[i].timeout<targets[min].timeout then min:=i;
    end;
    targets[min].ip:=adr;
    targets[min].port:=port;
    targets[min].lastID:=1;
    targets[min].timeout:=MainTimer;
    ID:=1;
   end;
   LogMessage(TimeStamp+' SENDING: '+inttostr(ID)+', '+inttostr(size)+' to: '+iptostr(adr)+':'+inttostr(port)+
    #13#10+HexDump(data,min2(size,16)),6);
   r:=TDeliveryRequest.Create;
   r.id:=ID;
   r.dest_adr:=adr;
   r.dest_port:=port;
   r.confirmed_parts:=0;
   r.conf_bits:=0;
   r.resend_time:=0;
   r.resend_count:=0;
   if IsLocalAdr(adr) then r.timeout:=MainTimer+100
    else r.timeout:=MainTimer+1500; // 30 сек
   r.created:=MainTimer; 
   r.last_sent:=-1;
   r.can_send:=8;
   SetLength(r.data,size);
   move(data^,r.data[0],size);
   requests[count]:=r;
   result:=r.id;
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 function GetMsg(handle:integer;var data:pointer):integer;
  begin
   EnterCriticalSection(critSect);
   try
   result:=-1;
   data:=nil;
   if queue[handle]=nil then exit;
   data:=@queue[handle].data[0];
   result:=length(queue[handle].data);
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 procedure GetMsgOrigin(handle:integer;var ip:cardinal;var port:word);
  begin
   EnterCriticalSection(critSect);
   try
   if queue[handle]=nil then begin
    ip:=0; port:=0;
    exit;
   end;
   ip:=queue[handle].ip;
   port:=queue[handle].port;
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

procedure ResolveAddress;
 var
  i:integer;
  address:string;
  port:word;
  ip:cardinal;
  h:PHostEnt;
  fl:boolean;
 begin
  address:=ResolveAdr;
  port:=0;
  i:=pos(':',address);
  if (i>0) or (pos('.',address)=0) then  begin
   port:=StrToInt(copy(address,i+1,length(address)-i));
   SetLength(address,i-1);
  end;
  if address<>'' then begin
   fl:=true;
   for i:=1 to length(address) do
    if not (address[i] in ['0'..'9','.']) then fl:=false;
   if fl then begin
    address:=address+#0;
    ip:=inet_addr(@address[1]);
   end else begin
    address:=address+#0;
    h:=GetHostByName(@address[1]);
    if h=nil then begin
     ip:=0;
    end;
    move(h^.h_addr^[0],ip,4);
   end;
  end else
   ip:=$FFFFFFFF;

  ResolveAdr:='';
  ResolvedIP:=ip;
  ResolvedPort:=port;
 end;

{ TNetThread }
procedure TNetThread.Execute;
var
 i,j,o,id:integer;
 rem_adr:cardinal;
 rem_port:word;
 buf:array[0..1200] of byte;
 m,s:integer;
 fl:boolean;
 onData:array[1..100] of integer;
 onDataCnt:integer;
begin
 try
 RegisterThread('Netwrk(E2)');
 LogMessage(TimeStamp+' NET: Initializing, threadID='+inttostr(GetCurrentThreadID));
 randomize;
 InstID:=random(65536)+random(32768) shl 16;
 udp:=UDPSocket2.Create(initport,true);

 repeat
  inc(MainTimer);
  if MainTimer mod 500=1 then
   LogMessage('NET: loop '+inttostr(MainTimer),6);
  PingThread;
  EnterCriticalSection(critSect);
  try
   // Обработка входящих пакетов
   size:=2048;
   try
   onDataCnt:=0;
   while udp.Receive(rem_adr,rem_port,recvbuf,size) do begin
    // симуляция сбоев доставки
{    if random(10)>5 then begin
     size:=2048; continue;
    end;}
    if (size>6) and (recvbuf[0] in [1,2]) then begin
     // получен пакет данных
     o:=recvbuf[1]+recvbuf[2]*256;
     m:=qFirst;
     id:=recvbuf[3]+recvbuf[4] shl 8+recvbuf[5] shl 16;
     // найдем в очереди сообщение, к которому относится пакет
     while m<>qFree do
      if (networking.queue[m].id=id) and (networking.queue[m].ip=rem_adr) and (networking.queue[m].port=rem_port) then break
       else m:=(m+1) and 16383;
     if m=qFree then begin // ни к какому не относится - создадим новое
      m:=PutMsgToQueue(rem_adr,rem_port);
      networking.queue[m].id:=id;
     end;
     // отныне m - позиция в очереди, где хранится сообщение
     s:=size-6;
     if (s>1024) then begin
      ForceLogMessage('Too large packet!');
      size:=2048;
      continue;
     end;
     // пакет слишком маленький - поврежден?
     if (recvbuf[0]=1) and (s<>1024) then begin size:=2048; continue; end;
     // если пакет финальный - он определяет размер буфера
     i:=length(networking.queue[m].data);
     if recvbuf[0]=2 then begin
      networking.queue[m].part_total:=o+1;
      SetLength(networking.queue[m].data,o*1024+s);
     end;
     // если пакет промежуточный но не влазит в буфер - увеличить буфер
     if (recvbuf[0]=1) and (i<o*1024+s) then
      SetLength(networking.queue[m].data,1024+s+i+i div 4);

     // перенесем данные и увеличим таймер
     networking.queue[m].counter:=MainTimer+500;
     move(recvbuf[6],networking.queue[m].data[o*1024],s);

     // выслать подтверждение получения пакета
     recvbuf[0]:=3;
     udp.Send(rem_adr,rem_port,recvbuf,6);
     o:=o-networking.queue[m].part_first;
     if (o>=0) and (o<24) and (networking.queue[m].parts and (1 shl o)=0) then
      with networking.queue[m] do begin
       // получена часть, которую еще не получали ранее
       parts:=parts or (1 shl o);
       while parts and 1>0 do begin
        parts:=parts shr 1;
        inc(part_first);
       end;
       if part_first=part_total then begin
        // Сообщение принято полностью, можно забирать
        LogMessage(TimeStamp+' RECEIVED: '+inttostr(networking.queue[m].id)+', '+
           inttostr(length(networking.queue[m].data))+' from: '+iptostr(rem_adr)+':'+inttostr(rem_port)+
           #13#10+HexDump(@networking.queue[m].data[0],min2(length(networking.queue[m].data),16)),6);
        // Пройдемся по источникам и рассмотрим их
        fl:=false;
        for i:=1 to scount do with sources[i] do
         if (ip=rem_adr) and (port=rem_port) then begin
          fl:=true; break;
         end;
        if fl then begin
         // Источник найден, проверим очередность
         networking.queue[m].session:=sources[i].sess;
         sources[i].timeout:=MainTimer+2000; // 40 секунд
         if (networking.queue[m].id<>sources[i].lastID+1) and (length(networking.queue[m].data)=4) and
           (networking.queue[m].data[0] in [$78,$79]) and (networking.queue[m].data[1]=$56) and
           (networking.queue[m].data[2]=$34) and (networking.queue[m].data[3]=$12) then begin
          LogMessage('Trying to restart connection from '+IpToStr(sources[i].ip)+':'+inttostr(sources[i].port));
          sources[i].lastID:=0;
          inc(sources[i].sess); // новая сессия
         end;
         if networking.queue[m].id=sources[i].lastID+1 then begin
          inc(sources[i].lastID);
          // получен следующий по порядку пакет - обработать его и если есть последующие - тоже
          networking.queue[m].counter:=MainTimer+150*20; // 150 секунд на обработку сообщения
          inc(onDataCnt);
          onData[onDataCnt]:=m;
//          Signal('Net\onData',m);
          s:=i;
          repeat
           // ищем в очереди следующий пакет
           fl:=false;
           i:=qFirst;
           while i<>qFree do begin
            if (networking.queue[i].ip=rem_adr) and (networking.queue[i].port=rem_port) and
               (networking.queue[i].id=sources[s].lastID+1) and (networking.queue[i].session=sources[s].sess) then begin
             inc(sources[s].lastID);
             LogMessage(TimeStamp+' Additional packet: '+inttostr(networking.queue[i].id),6);
             networking.queue[i].counter:=MainTimer+150*20; // 150 секунд на обработку сообщения
             inc(onDataCnt);
             onData[onDataCnt]:=i;
//             Signal('Net\onData',i);
             fl:=true;
            end;
            i:=(i+1) and 16383;
           end;
          until not fl;
         end else
          LogMessage(' expected: '+inttostr(sources[i].lastID+1)+
            ' instead of '+inttostr(networking.queue[m].id)+' from: '+ipToStr(sources[i].ip)); // иначе получен внеочередной пакет, который обработаем в будущем

        end else begin
         // Новый источник, пакет можно принимать
//         if networking.queue[m].id=1 then begin
          if scount<300 then inc(scount);
          sources[scount].ip:=rem_adr;
          sources[scount].port:=rem_port;
          sources[scount].lastID:=networking.queue[m].id;
          sources[scount].timeout:=MainTimer+40*50;
          sources[scount].sess:=random(256);
          LogMessage(TimeStamp+' NewSource: '+ipToStr(rem_adr),6);
          inc(onDataCnt);
          onData[onDataCnt]:=m;
//         end else LogMessage('WARN! First packet ID<>1, ignored!');
//         Signal('Net\onData',m);
        end;
       end;
      end;
    end else // Важно!
    if (recvbuf[0]=3) and (size=6) then begin
     // получено подтверждение доставки
     o:=recvbuf[1]+recvbuf[2]*256;
     id:=recvbuf[3]+recvbuf[4] shl 8+recvbuf[5] shl 16;
     LogMessage(TimeStamp+' CONFIRMED: '+inttostr(id)+'.'+inttostr(o)+' FROM '+iptostr(rem_adr),6);
     
     // продлить таймаут для source
     for i:=1 to scount do with sources[i] do
      if (ip=rem_adr) and (port=rem_port) then begin
       timeout:=mainTimer+2000; break;
      end;

     fl:=false;
     for i:=1 to count do
      if (requests[i].id=id) and (requests[i].dest_adr=rem_adr) and
         (requests[i].dest_port=rem_port) then with requests[i] do
       if (o>=confirmed_parts) and (o<confirmed_parts+24) then begin
         conf_bits:=conf_bits or (1 shl (o-confirmed_parts));
         while conf_bits and 1>0 do begin
          conf_bits:=conf_bits shr 1;
          inc(confirmed_parts);
          if confirmed_parts>(length(data)-1) div 1024 then fl:=true;
         end;
         if IsLocalAdr(dest_adr) then timeout:=MainTimer+100
          else timeout:=MainTimer+1500;
         inc(can_send);
         break;
       end;
     if fl then begin // доставлены все части сообщения
      i:=1;
      while i<=count do with requests[i] do
       if confirmed_parts>(length(data)-1) div 1024 then begin
        // Проверить наличие соединения и обновить его пинг, если пакет был маленький
        if length(data)<=1024 then 
         for j:=1 to conCnt do
          if (connections[j].remIP=dest_adr) and
             (connections[j].remPort=dest_port) then begin
           connections[j].ping:=(MainTimer-created)*0.02;
          end;
        // удалить запрос
        FreeAndNil(requests[i]);
        requests[i]:=requests[count];
        requests[count]:=nil;
        dec(count);
       end else inc(i);
      // нужно продлить таймер для target'а
      for i:=1 to tcount do
       if (targets[i].ip=rem_adr) and (targets[i].port=rem_port) then
        targets[i].timeout:=MainTimer;
     end;
    end else
    if (recvbuf[0]=4) and (size=5) and LanServerMode then begin
     // отозваться (но только не себе)
     move(recvbuf[1],m,4);
     if m<>InstID then begin
      recvbuf[0]:=5;
      udp.Send(rem_adr,rem_port,recvbuf,1);
     end;
    end else
    if (recvbuf[0]=5) and (size=1) then begin
     // получен отзыв
     if (LookingForServer>0) and (rem_port=ServerPort) then begin
      ServerAddress:=rem_adr;
      LookingForServer:=0;
      Signal('Net\LANserverFound',ServerAddress);
     end;
    end else begin // какой-то непонятный пакет...
     Signal('Net\'); // to be continued...
    end;
    size:=2048;
   end; // while

   except
    on e:Exception do Signal('Net\Error\'+e.Message,0);
   end;
  finally
   LeaveCriticalSection(critSect);
  end;

//  if onDataCnt>1 then ForceLogMessage('NET: '+inttostr(onDataCnt)+' messages to process');
  Debug_counter:=onDataCnt;
  for i:=1 to onDataCnt do
   Signal('Net\OnData',onData[i]);

{  if debug_counter<>0 then begin
   ForceLogMessage('BUG ABOVE! Debug counter: '+inttostr(debug_counter));
   ErrorMessage('OMG! See log!');
  end;}

  EnterCriticalSection(critSect);
  try
   // Отправка пакетов
   // есть два случая:
   // 1) наступил момент resend_time - выслать части, которые не были подтверждены
   // 2) can_send > 0 - выслать еще не посланные части и очистить флаг
   for i:=1 to count do with requests[i] do
    if (MainTimer>resend_time) or (can_send>0) then begin
     try
      // просмотреть на N частей вперед и послать те из них, которые не были подтверждены
      for o:=confirmed_parts to confirmed_parts+7 do begin
       // если часть была подтверждена - безусловно не посылать
       if (conf_bits and (1 shl (o-confirmed_parts)))>0 then continue;
       // если часть уже высылалась и не наступил момент перепосылки
       if (o<last_sent) and not (MainTimer>resend_time) then continue;

       size:=length(data)-o*1024;
       if size<=0 then break;
       if size>1024 then size:=1024;
       buf[0]:=1;
       if o*1024+size=length(data) then begin inc(buf[0]); can_send:=0; end;
       move(o,buf[1],2);
       move(requests[i].id,buf[3],3);
       move(data[o*1024],buf[6],size);
       udp.Send(dest_adr,dest_port,buf,size+6);
       LogMessage(TimeStamp+' SENDPART: '+inttostr(requests[i].id)+'.'+inttostr(o),6);
       inc(resend_count);
       if IsLocalAdr(dest_adr) then resend_time:=MainTimer+10*resend_count
        else resend_time:=MainTimer+20*resend_count;

       if can_send>0 then dec(can_send);
       if o>last_sent then last_sent:=o;
      end;
     except
      on e:Exception do begin
       ForceLogMessage('NET: Exception in sending - '+e.message);
       break; // отмена цикла отправки если что-то случилось
      end;
     end;
    end;

   try
   // Поиск ЛАН-сервера
   if LookingForServer>0 then begin
    if LookingCounter<=0 then begin
     buf[0]:=4;
     move(InstID,buf[1],4);
     udp.Send($FFFFFFFF,serverPort,buf,5);
     LookingCounter:=50;
    end;
    dec(LookingCounter);
    if MainTimer>LookingForServer then begin
     LookingForServer:=0;
     ServerAddress:=0;
    end;
   end;

   // Обработка адреса (вызывает задержку)
   if ResolveAdr<>'' then
    ResolveAddress;

   // Обработка таймаутов
   i:=1;
   while i<=count do
    if MainTimer>requests[i].timeout then begin
     // Сообщение не было доставлено
     LogMessage(TimeStamp+' NET: CANTSEND: '+inttostr(requests[i].id)+' to '+iptostr(requests[i].dest_adr)+
       ' size:'+inttostr(length(requests[i].data))+
       ' confirmed: '+inttostr(requests[i].confirmed_parts)+'#'+inttostr(requests[i].conf_bits)+
       ' resent: '+inttostr(requests[i].resend_count));
     Signal('net\onCantSend\'+inttostr(requests[i].dest_port),requests[i].dest_adr);
     // Удалить все прочие исходящие сообщения на этот адрес
{     o:=i+1;
     while o<=count do
      if (requests[o].dest_adr=requests[i].dest_adr) and
         (requests[o].dest_port=requests[i].dest_port) then begin
       FreeAndNil(requests[o]);
       requests[o]:=requests[count];
      end
     else inc(o);}
     // Удалить само сообщение
     FreeAndNil(requests[i]);
     requests[i]:=requests[count];
     requests[count]:=nil;
     dec(count);
    end
   else inc(i);

   // Удаление старых входящих сообщений
   // удалить можно только первое в очереди
   while (qFirst<>qFree) and (MainTimer>networking.queue[qFirst].counter) do begin // если настало время - удалить
    // проверим, является ли сообщение внеочередным
    for i:=1 to scount do
     if (sources[i].ip=networking.queue[qFirst].ip) and (sources[i].port=networking.queue[qFirst].port) and
        (networking.queue[qFirst].id>sources[i].lastID) then begin
      if MainTimer<networking.queue[qFirst].counter+50*20 then begin
       // если с таймаута прошло менее 50 секунд - кидаем сообщение в конец очереди:
       // возможно за это время еще будет получено недостающее сообщение
       networking.queue[qFree]:=networking.queue[qFirst];
       qFree:=(qFree+1) and 16383;
       qFirst:=(qFirst+1) and 16383;           
       continue;
      end else begin
       // недостающее сообщение так и не было получено - значит порядок доставки
       // соблюсти невозможно, нужно разорвать соединение
       for o:=1 to conCnt do
        if (connections[o].connected) and (connections[o].remIP=sources[i].ip) and
           (connections[o].remPort=sources[i].port) then begin
         // разрыв соединения

         connections[o].connected:=false;
         connections[o].status:=-1;
         ForceLogMessage('Unordered message deleted, connection broken: '+inttostr(networking.queue[qfirst].id)+':'+inttostr(sources[i].lastID));
         Signal('Net\Conn\ConnectionBroken',cardinal(connections[o]));
        end;
       sources[i]:=sources[scount]; dec(scount); // удаляем источник
      end;
    end;
    FreeAndNil(networking.queue[qFirst]);
    qFirst:=(qFirst+1) and 16383;
   end;

{   i:=qFirst;
   while i<>qFree do begin
    if networking.queue[i]=nil then begin
     ForceLogMessage('QUEUE DAMAGED!');
     LogMessage('qFirst='+inttostr(qFirst));
     LogMessage('qFree='+inttostr(qFree));
     i:=qFirst;
     while i<>qFree do begin
      LogMessage('queue['+inttostr(i)+']='+inttohex(integer(queue[i]),8));
      i:=(i+1) and 1023;
     end;
    end;
    if MainTimer>queue[i].counter then begin // если настало время - удалить
     FreeAndNil(queue[i]);
     queue[i]:=queue[qFirst];
     qFirst:=(qFirst+1) and 1023;
    end;
    i:=(i+1) and 1023;
   end;}

   // удалим устаревшие источники
   i:=1;
   while i<=sCount do
    if MainTimer>sources[i].timeout then begin
     // если было соединение с источником - разорвать его
     for o:=1 to conCnt do
      if connections[o].connected and (connections[o].remIP=sources[i].ip) and
      (connections[o].remPort=sources[i].port) then begin
        connections[o].connected:=false;
        connections[o].status:=-1;
        LogMessage(timestamp+' Timeout for source '+iptostr(sources[i].ip)+
          ', connection broken');
        Signal('Net\Conn\ConnectionBroken',cardinal(connections[o]));
      end;
     sources[i]:=sources[sCount];
     dec(sCount);
    end else inc(i);

   // Обработка соединений
   i:=MainTimer mod 300+1;
   if (i<=conCnt) and (connections[i].connected) then begin
    m:=$1234567A;
    connections[i].SendData(@m,4);
   end;
   for i:=1 to conCnt do
    if (i mod 8=mainTimer mod 8) and (connections[i].connected) then
     for j:=1 to count do
      if (requests[j].dest_adr=connections[i].remIP) and
         (requests[j].dest_port=connections[i].remPort) and
         (length(requests[j].data)<=1024) and
         ((MainTimer-requests[j].created)*0.02>connections[i].ping) then begin
          connections[i].ping:=(MainTimer-requests[j].created)*0.02;
         end;

   except
    on e:Exception do ForceLogMessage('NET: loop exception - '+e.Message);
   end;

  finally
   LeaveCriticalSection(critSect);
  end;
  sleep(20);
 until terminated;
 EnterCriticalSection(critSect);
 try
  LogMessage('NET: thread stopping '+inttostr(GetTickCount));
  FreeAndNil(udp);

  // Нужно подчистить все структуры
  LogMessage('Count='+inttostr(count));
  sCount:=0;
  count:=0;
  for i:=1 to length(requests) do begin
   FreeAndNil(requests[i]);
  end;

  LogMessage('Q: '+inttostr(qFirst)+' '+inttostr(qFree));
  for i:=0 to 16383 do begin
   FreeAndNil(networking.queue[i]);
  end;
  qfirst:=0; qFree:=0;
  thread:=nil;
  LogMessage('NET: thread done '+inttostr(GetTickCount));
 finally
  LeaveCriticalSection(critSect);
 end;
 except
  on e:Exception do begin
   Dump(1,'Error in NET loop');
   ForceLogMessage('NET: error in NET loop - '+e.Message);
  end;
 end;
 UnregisterThread;
end;

{ TConnection }

function ConEvtHandler(event:EventStr;tag:integer):boolean;
var
 v,i:integer;
 ip:cardinal;
 port:word;
 size:integer;
 buf:^integer;
 fl,handled:boolean;
begin
 result:=false;
// ForceLogMessage('NetConn: '+event+' ; '+inttostr(tag));
 event:=UpperCase(event);
 if pos('NET\LANSERVERFOUND',event)=1 then
  // передан адрес сервера для подключения
  for i:=1 to conCnt do
   if (connections[i].status=0) then begin
    // Послать запрос на установку соединения
    connections[i].remIP:=tag;
    connections[i].status:=1;
    v:=$12345678;
    Send(tag,connections[i].remPort,@v,4);
   end;

 if pos('NET\ONCANTSEND',event)=1 then begin
  // Сообщение не было доставлено (подтверждено)
  delete(event,1,15);
  port:=StrToInt(event);
  for i:=1 to conCnt do
   if (connections[i].status>0) and
      (connections[i].remIP=cardinal(tag)) and (connections[i].remPort=port) then begin
    connections[i].status:=-1;
    if connections[i].connected then begin
     connections[i].connected:=false;
     ForceLogMessage('Connection to '+IpToStr(connections[i].remIP)+' broken: message was not delivered');
     Signal('Net\Conn\ConnectionBroken',cardinal(connections[i]));
    end;
   end;
 end;

 if pos('NET\ONDATA',event)=1 then begin
  dec(debug_counter);
  if tag<0 then exit;
  GetMsgOrigin(tag,ip,port);
  handled:=false;

  // Варианты:
  // 1) сообщение относится к какому-либо установленному соединению
  //  а) это служебное сообщение - обработать
  //  б) это сообщение с данными
  // 2) соответствует соединению в ожидании - обработать
  //  2a) сообщение юзера, но соединения уже нет - послать разрыв (если установлен режим разрыва)

  for i:=1 to conCnt do begin
   if (connections[i].connected) and (connections[i].remIP=ip) and (connections[i].remPort=port) then begin
    size:=GetMsg(tag,pointer(buf));
    fl:=true; // сообщение юзера
    if (size=4) and (buf^=$12345678) then
     buf^:=$12345679; // разорвать

    if (size=4) and (buf^=$12345679) then begin
     // Получен запрос на разрыв соединения
     fl:=false;
     if connections[i].connected then begin
      connections[i].connected:=false;
      connections[i].status:=-1;
      Signal('Net\Conn\ConnectionClosed',cardinal(connections[i]));
      handled:=true;
      exit;
      // Удалить все недоставленные исходящие на это соединение
//      v:=1;
{      while v<=count do
       if (requests[v].dest_adr=connections[i].remIP) and
          (requests[v].dest_port=connections[i].remPort) then begin
         LogMessage('2delete: '+IpToStr(requests[v].dest_adr)+#1310+
          HexDump(requests[v].data,length(requests[v].data)),6);
        FreeAndNil(requests[v]);
        requests[v]:=requests[count];
        dec(count);
       end else inc(v);}
     end;
    end;
    if (size=4) and (buf^=$1234567A) then begin
     // Получен запрос на автоответ (игнорируем)
     fl:=false;
     handled:=true; exit;
    end;
    if fl and connections[i].connected then begin
//     LogMessage('NET: User message');
     Signal('Net\Conn\UserMsg',tag);
     handled:=true; exit;
    end;
   end;
  end;

  // сообщение для ожидающего соединения?
  for i:=1 to conCnt do begin
   if connections[i].status in [0,1] then begin
    size:=GetMsg(tag,pointer(buf));
    if (size=4) and (buf^=$12345678) then
     if (connections[i].status=0) or (connections[i].remIP=ip) then begin
      // Получен запрос на установку соединения
      v:=$1234567C;
      connections[i].remIP:=ip;
      connections[i].remPort:=port;
      connections[i].SendData(@v,4);
      connections[i].connected:=true;
      connections[i].status:=2;
      handled:=true;
      Signal('Net\Conn\Connected');
      continue;
     end;
    if (size=4) and (buf^=$1234567B) then begin
     if connections[i].status=1 then begin
      fl:=false;
      connections[i].status:=0;
      handled:=true;
      Signal('Net\Conn\ConnectionRejected');
     end;
    end;
    if (size=4) and (buf^=$1234567C) then begin
     if connections[i].status=1 then begin
      fl:=false;
      connections[i].status:=2;
      connections[i].connected:=true;
      handled:=true;
      Signal('Net\Conn\Connected');
     end;
    end;
   end;
  end;

  if not handled and ConnectionsOnly then begin
   v:=$12345679;
   Send(ip,port,@v,4);
   LogMessage('Not connection-related message from '+iptostr(ip)+':'+inttostr(port));
  end;

 end;
end;

constructor TConnection.Create(localPort:word);
begin
 EnterCriticalSection(CritSect);
 try
 connected:=false;
 status:=0;
 if concnt=0 then begin
  SetEventHandler('Net',ConEvtHandler);
  if initialized=0 then
   NetInit(localPort);
  if LocalPort<>0 then LanServerMode:=true;
 end;
 inc(conCnt);
 connections[conCnt]:=self;
 LogMessage(TimeStamp+' NetConn: created',6);
 finally
  LeaveCriticalSection(critSect);
 end;
end;

destructor TConnection.Destroy;
var
 i:integer;
begin
 EnterCriticalSection(CritSect);
 try
 for i:=1 to conCnt do
  if connections[i]=self then begin
   LogMessage(TimeStamp+' NetConn: deleted, '+iptostr(connections[i].remIP),6);
   connections[i]:=connections[conCnt];
   dec(conCnt);
   break;
  end;
 finally
  LeaveCriticalSection(critSect);
 end;
 if concnt=0 then begin
  NetDone;
  RemoveEventHandler(ConEvtHandler);
 end;
end;

procedure TConnection.Connect(target: cardinal; port: word);
begin
 if connected then exit;
 EnterCriticalSection(CritSect);
 try
 remIP:=target;
 remPort:=port;
 status:=0; // попытка подключения
 if target=0 then begin
  GetLanServerAddress(port,false);
//  status:=0; // сперва попробуем найти сервер в LAN
  exit;
 end;
 Signal('Net\LanServerFound',target);
 finally
  LeaveCriticalSection(critSect);
 end;
end;

procedure TConnection.Disconnect;
var
 v:integer;
begin
 status:=0;
 if not connected then exit;
 v:=$12345679;
 Send(remIP,remPort,@v,4);
 connected:=false;
 sleep(50);
end;

procedure TConnection.SendData(buf: pointer; size: integer);
begin
 LogMessage('Connection.Send',6);
 Send(remIP,remPort,buf,size);
end;

procedure Dump(detailLevel:byte=1;reason:string='');
var
 f:text;
 i,j:integer;
 function Min(a,b:integer):integer;
  begin
   result:=a;
   if b<a then result:=b;
  end;
begin
 EnterCriticalSection(critSect);
 try
  inc(lastDump);
  assign(f,ExtractFilePath(ParamStr(0))+'netwrk_dump'+inttostr(lastDump)+'.txt');
  rewrite(f);
  writeln(f,'REASON: ',reason);
  writeln(f);
  writeln(f,'OVERVIEW ');
  writeln(f,'  MainTimer: ',mainTimer);
  writeln(f,'   Requests: ',count);
  writeln(f,'      Queue: ',qFirst,' - ',qFree);
  writeln(f,'    Sources: ',scount);
  writeln(f,'    Targets: ',tcount);

  writeln(f,'CONNECTIONS');
  for i:=1 to conCnt do
   writeln(f,i:3,') Adr: ',IpToStr(connections[i].remIP),':',connections[i].remPort);


  if DetailLevel>0 then begin
   writeln(f); writeln(f,'REQUESTS');
   for i:=1 to count do
    writeln(f,i:4,') id: ',requests[i].id,
      ', to: ',IpToStr(requests[i].dest_adr),':',requests[i].dest_port,
      ', timeout: ',requests[i].timeout,
      ', confirmed: ',requests[i].confirmed_parts,'(',requests[i].conf_bits,
      '), last sent: ',requests[i].last_sent,
      ', | ',HexDump(@requests[i].data[0],min(length(requests[i].data),15)));

   writeln(f); writeln(f,'QUEUE');
   i:=qFirst;
   while i<>qFree do begin
    writeln(f,i:4,') id: ',networking.queue[i].id,', from: ',IpToStr(networking.queue[i].ip),':',+networking.queue[i].port,
      ', counter: ',networking.queue[i].counter,
      ', parts: ',networking.queue[i].part_first,'#',networking.queue[i].parts,
      ', | ',HexDump(@networking.queue[i].data[0],min(length(networking.queue[i].data),15)));
    i:=(i+1) and 16383;
   end;

   writeln(f); writeln(f,'SOURCES');
   for i:=1 to scount do
    writeln(f,i:4,'  Address: ',IpToStr(sources[i].ip),':',sources[i].port,
      ', lastID: ',sources[i].lastID,', timeout: ',sources[i].timeout);

   writeln(f); writeln(f,'TARGETS');
   for i:=1 to tcount do
    writeln(f,i:4,'  Address: ',IpToStr(targets[i].ip),':',targets[i].port,
      ', lastID: ',targets[i].lastID,', timeout: ',targets[i].timeout);

  end;
  close(f);
 finally
  LeaveCriticalSection(critSect);
 end;
end;


initialization
 InitCritSect(critSect,'Netwrk');
// InitializeCriticalSection(critSect);
finalization
 DeleteCriticalSection(critSect.crs);
end.
