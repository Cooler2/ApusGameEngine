// Network engine layer, ver 2
//
// Copyright (C) 2007 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R-}
unit Apus.Engine.Networking2;
interface
 const
  MAX_PACKET = 1200; // 512;//1400; // сокращённый размер пакета
  MaxSendTick:integer=8192; // макс. 8K исходящего трафика за итерацию
  HistoryMsgSize:integer=512; // размер данных в хистори
 type
  TConnection=class;
  TDataPacket=class
   next:TDataPacket;
   num:word;
   created:cardinal; // значение maintimer на момент создания (затем может изменяться)
   counter:integer; // универсальный счетчик
   src:TConnection;
   data:array of byte;
   ticks:cardinal;  // значение getTickCount на момент создания
   constructor Create;
  end;
  // обработка получения пакета
  TUserMsgProc=procedure(con:TConnection;buf:pointer;size:integer;ip:cardinal;port:word);

  TConnection=class
   connected:boolean;
   remIP:cardinal;
   remPort:word;
   ping,avgping:single; // Время доставки последнего пакета (сек.)
   sessID,remID:cardinal; // используется также в качестве хэша для поиска соединений в массиве
   history:array of byte; // журнал сообщений (очередь)
   hPos,hSize:integer; // указатели очереди

   constructor Create(accept:boolean=false);
   destructor Destroy; override;
   // Подключиться к указанной системе
   // (если target=0 - искать систему в LAN и если найдем - подключиться)
   procedure Connect(target:cardinal;port:word);
   // Отключиться (с уведомлением)
   procedure Disconnect(freeObject:boolean=false);
   // Послать блок данных
   procedure SendData(buf:pointer;size:integer;maxlatency:integer=20);
   procedure Accept(wait:boolean=true); // переводит соединение в режим ожидания подключения
   function DumpHistory(hexMode:boolean=true):string;
  protected
   accepting,deleting:boolean;
   status:integer;
   // очередь отправки данных
   firstSend,lastSend:TDataPacket;
   // очередь получения данных
   firstRecv,lastRecv:TDataPacket;
   lastSentTime:cardinal; // момент последней отправки пакета
   lastRecvID:word; // ID последнего пакета данных (чтобы не обрабатывать снова)
   fetchPos:integer; // выборка очередного сообщения начиная с этой позиции в первом пакете
   procedure FreeAll;
   procedure PutToHistory(data:pointer;size:integer;msgtype:byte);
  end;

 var
  // если установлен этот обработчик, то он будет вызываться из сетевого потока
  // вместо сигнала, после обработки сообщение будет удалено из хранилища
  onUserMsg:TUserMsgProc;
  conCnt:integer; // кол-во соединений

  avgTime1,avgTime2,avgTime3,avgTime4:double; // измерение производительности

 procedure NetInit(port:word);
 procedure NetDone;
 // ind: 1-sent, 2-received, 3-sentBytes, 4-receivedBytes
 function GetNetStat(ind:integer):int64;

 // получить указатель на полученный блок данных (и его размер)
 // handle передается в параметре события Net\onData
 function GetMsg(handle:cardinal;var data:pointer):integer;
 procedure GetMsgOrigin(handle:integer;var ip:cardinal;var port:word);

 // парсит и ресолвит (если необходимо) адрес, заданный в виде строки
 // Внимание!!! Может занять много времени! Возвращает 0 или код ошибки
 procedure GetInternetAddress(adr:string;var ip:cardinal;var port:word);

 // Is internet connection available? positive - yes, negative - no
 function CheckInternetConnection:integer;

implementation
 uses {$IFDEF MSWINDOWS}windows,winsock,{$ELSE}Apus.CrossPlatform,Sockets,BaseUnix,{$ENDIF}
      {$IFDEF IOS}CFBase,{$ENDIF}Apus.Common,SysUtils,Apus.Network,Classes,Apus.EventMan;
 const
  // Статусы соединений
  csIdle = 1; // не подключено, ничего делать не нужно
  csRejected = 2; // не подключено, попытка подключения была отклонена
  csDisconnected = 3; // не подключено, соединение закрыто локальной стороной
  csClosed = 4; // не подключено, соединение разорвано удаленной стороной
  csBroken = 5; // не подключено, соединение разорвано по техническим причинам
  csDestroying = 7; // необходимо удалить объект соединения
  csConnecting = 20; // был вызван коннект
  csConnWait = 21; // ждём ответа на запрос подключения
  csConnected = 30; // соединение успешно установлено
  csDisconnecting = 40; // был вызван дисконнект

 type
  TNetThread=class(TThread)
   procedure Execute; override;
  end;
  THistoryHdr=packed record
   msgtype,reserved:byte;
   storedsize:word;
   size:integer;
   time:cardinal; // время (мс)
  end;

 var
  udp:UDPSocket2;
  initialized:integer;
  initport:word;
  thread:TNetThread;
  critSect,threadSect:TMyCriticalSection;
  MainTimer:cardinal=10000; // смещение чтобы обеспечить некоторый запас "в прошлое"

  lastPacketID:cardinal;

  // Определение адреса
  resolveAdr:string;
  resolvedIP:cardinal;
  resolvedPort:word;


  connections:array[0..4095] of TConnection;
  processingFlag:boolean; // флаг того, что какое-то соединение находится в состоянии, требующем обработки

  storageFirst,storageLast:TDataPacket; // хранилище принятых сообщений (очередь)

 {$IFDEF IOS}
 type
  SCNetworkReachabilityRef = pointer;

 function SCNetworkReachabilityCreateWithAddress(allocator:pointer;
                   var address:TSockAddr):SCNetworkReachabilityRef; cdecl; external;

 function SCNetworkReachabilityGetFlags(nrr:SCNetworkReachabilityRef;out flags:cardinal):boolean; cdecl; external;

 const
  kSCNetworkReachabilityFlagsReachable = 1 shl 1;
  kSCNetworkReachabilityFlagsIsWWAN = 1 shl 18;

 function CheckInternetConnection:integer;
  var
    nrr:SCNetworkReachabilityRef;
    addr:TSockAddr;
    flags:cardinal;
  begin
   fillchar(addr,sizeof(addr),0);
   addr.sin_family:=AF_INET;
   addr.sa_len:=sizeof(addr);
   //addr.sin_port:=htons(sockport);
   //adr.sin_addr.S_addr:=INADDR_ANY;
   nrr:=SCNetworkReachabilityCreateWithAddress(nil,addr);
   result:=-1;
   if nrr=nil then exit;
   result:=-2;
   if SCNetworkReachabilityGetFlags(nrr,flags) then begin
    if flags and kSCNetworkReachabilityFlagsReachable>0 then result:=1;
    if flags and kSCNetworkReachabilityFlagsIsWWAN>0 then result:=result+2;
   end else
    result:=-3;
   CFAllocatorDeallocate(CFAllocatorGetDefault,nrr);
  end;
 {$ELSE}
 function CheckInternetConnection:integer;
  begin
   result:=1;
  end;
 {$ENDIF}


 procedure NetInit(port:word);
  begin
   if initialized>0 then begin
    inc(initialized); exit;
   end;
   EnterCriticalSection(threadSect);
   try
    initport:=port;
    thread:=TNetThread.Create(true);
    thread.FreeOnTerminate:=true;
    thread.Resume;
    initialized:=1;
   finally
    LeaveCriticalSection(threadSect);
   end;
  end;

 procedure NetDone;
  begin
   dec(initialized);
   if initialized>0 then exit;
   EnterCriticalSection(critSect);
   try
    if thread<>nil then thread.Terminate;
   finally
    LeaveCriticalSection(critSect);
   end;
   EnterCriticalSection(threadSect);
   LeaveCriticalSection(threadSect);
  end;

function GetNetStat(ind:integer):int64;
 begin
  result:=0;
  if udp=nil then exit;
  case ind of
   1:result:=udp.sent;
   2:result:=udp.received;
   3:result:=udp.sentBytes;
   4:result:=udp.receivedBytes;
  end;
 end;

{$IFDEF UNIX}
const
  { Net type }
  socklib = 'c';
  { Error constants. Returned by LastError method of THost, TNet}

  NETDB_INTERNAL= -1;       { see errno }
  NETDB_SUCCESS = 0;        { no problem }
  HOST_NOT_FOUND= 1;        { Authoritative Answer Host not found }
  TRY_AGAIN     = 2;        { Non-Authoritive Host not found, or SERVERFAIL }
  NO_RECOVERY   = 3;        { Non recoverable errors, FORMERR, REFUSED, NOTIMP }
  NO_DATA       = 4;        { Valid name, no data record of requested type }
  NO_ADDRESS    = NO_DATA;  { no address, look for MX record }


Type
  { THostEnt Object }
  THostEnt = record
    H_Name     : pchar;   { Official name }
    H_Aliases  : ppchar;  { Null-terminated list of aliases}
    H_Addrtype : longint;   { Host address type }
    H_length  : longint;   { Length of address }
    H_Addr : ppchar;    { null-terminated list of adresses }
  end;
  PHostEnt = ^THostEnt;

{ C style calls, linked in from Libc }
function gethostbyname ( Name : Pchar) : PHostEnt; cdecl; external socklib;
function inet_addr(addr:PChar):cardinal; cdecl; external socklib;
{$ENDIF}

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
  try
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
     LogMessage('Resolving host address: '+address);
     // ожидание инициализации сокета
     for i:=1 to 50 do if udp=nil then sleep(5);
     sleep(10);
     h:=GetHostByName(@address[1]);
     if h=nil then begin
      ip:=0;
     end else
      move(h^.h_addr^[0],ip,4);
     LogMessage('Resolved IP: '+iptostr(ip));
    end;
   end else
    ip:=$FFFFFFFF;
  except
  end;
  ResolveAdr:='';
  ResolvedIP:=ip;
  ResolvedPort:=port;
 end;

 procedure GetInternetAddress(adr:string;var ip:cardinal;var port:word);
  begin
   resolveAdr:=adr;
   ResolveAddress;
   ip:=ResolvedIP;
   port:=ResolvedPort;
  end;

  { TConnection }

procedure TConnection.Accept(wait:boolean=true);
begin
 EnterCriticalSection(critSect);
 try
  if connected and not wait then exit;
  if status<>csDisconnecting then Disconnect;
  accepting:=true;
  LogMessage('Connection accepting '+inttostr(sessID and $FFF));
 finally
  LeaveCriticalSection(critsect);
 end;
end;

procedure TConnection.Connect(target: cardinal; port: word);
begin
 if connected then exit;
 EnterCriticalSection(critSect);
 try
  remIP:=target;
  remPort:=port;
  status:=csConnecting;
  processingFlag:=true;
  accepting:=false;
 finally
  LeaveCriticalSection(critsect);
 end;
end;

constructor TConnection.Create(accept:boolean=false);
begin
 if concnt>4000 then exit;
 EnterCriticalSection(critSect);
 try
  status:=csIdle;
  accepting:=accept;
  lastRecvID:=0;
  repeat
   sessID:=random(65536) shl 16+random(65536);
  until connections[sessID and $FFF]=nil;
  connections[sessID and $FFF]:=self;
  inc(conCnt);
  ping:=0.15; avgping:=0.15; // дефолтный пинг
  LogMessage('Connection created: '+inttostr(sessID and $FFF)+
    ' count='+inttostr(concnt)+' accept: '+booltostr(accepting));
  firstSend:=nil; lastSend:=nil;
  hSize:=0; hPos:=0;
 finally
  LeaveCriticalSection(critsect);
 end;
end;

destructor TConnection.Destroy;
begin
 EnterCriticalSection(critSect);
 try
  connections[sessID and $FFF]:=nil;
  dec(conCnt);
  LogMessage('Connection destroyed: '+inttostr(sessID and $FFF)+' count='+inttostr(concnt));
  FreeAll;
 finally
  LeaveCriticalSection(critsect);
 end;
end;

procedure TConnection.Disconnect(freeObject:boolean=false);
begin
 LogMessage('Disconnect called for '+inttostr(sessID and $FFF));
 if not connected then begin
  if Freeobject then Destroy;
  exit;
 end;
 EnterCriticalSection(critSect);
 try
  status:=csDisconnecting;
  processingFlag:=true;
  deleting:=freeObject;
 finally
  LeaveCriticalSection(critsect);
 end;
end;

function TConnection.DumpHistory(hexmode:boolean=true): string;
var
 i,s,j:integer;
 hdr:THistoryHdr;
 data:array[0..1023] of byte;
 pb:PByte;
 st:string;
begin
 result:='';
 if length(history)=0 then begin
  result:='Empty'#13#10;
  exit;
 end;
 i:=hPos; // позиция чтения
 s:=hSize; // размер данных для чтения
 if s>length(history) then s:=length(history);
 while s>sizeof(hdr) do begin
  dec(i,sizeof(hdr));
  if i<0 then inc(i,length(history));
  pb:=@hdr;
  for j:=1 to sizeof(hdr) do begin
   pb^:=history[i];
   inc(pb);
   inc(i);
   if i>=length(history) then i:=0;
  end;
  dec(s,sizeof(hdr));
  if s<hdr.storedsize then break;
  dec(i,sizeof(hdr)+hdr.storedsize);
  if i<0 then inc(i,length(history));
  pb:=@data[0];
  for j:=1 to hdr.storedsize do begin
   pb^:=history[i];
   inc(pb);
   inc(i);
   if i>=length(history) then i:=0;
  end;
  dec(s,hdr.storedsize);
  dec(i,hdr.storedsize);
  if i<0 then inc(i,length(history));
  st:=#13#10+inttostr((hdr.time div 1000) mod 10000)+'.'+inttostr(hdr.time mod 1000)+' ';
  if hdr.msgtype=1 then st:=st+'send '
   else st:=st+'recv ';
  if hexmode then
   st:=st+inttostr(hdr.size)+#13#10+HexDump(@data[0],hdr.storedsize)+#13#10
  else
   st:=st+inttostr(hdr.size)+#13#10+DecDump(@data[0],hdr.storedsize)+#13#10;
  result:=st+result;
 end;
 result:='History for connection '+inttostr(sessID and $FFF)+'/'+inttostr(remID and $FFF)+#13#10+result;
end;

procedure TConnection.PutToHistory(data: pointer; size: integer;msgtype:byte);
var
 hdr:THistoryHdr;
 pb:PByte;
 i:integer;
begin
 if length(history)<1024 then exit;
 hdr.size:=size;
 if historyMsgSize>1024 then historyMsgSize:=1024;
 if size>HistoryMsgSize then size:=HistoryMsgSize;
 hdr.msgtype:=msgtype;
 hdr.storedsize:=size;
 hdr.time:=getTickCount;
 pb:=data;
 for i:=1 to size do begin
  history[hPos]:=pb^;
  inc(pb);
  inc(hSize);
  inc(hPos);
  if hPos>=length(history) then hPos:=0;
 end;
 pb:=@hdr;
 for i:=1 to sizeof(hdr) do begin
  history[hPos]:=pb^;
  inc(pb);
  inc(hSize);
  inc(hPos);
  if hPos>=length(history) then hPos:=0;
 end;
end;

procedure TConnection.FreeAll; // вызывать только внутри критсекции!
var
 d:TDataPacket;
begin
 try
 while firstSend<>nil do begin
  d:=firstSend;
  firstSend:=d.next;
  d.Free;
 end;
 lastSend:=nil;
 while firstRecv<>nil do begin
  d:=firstRecv;
  firstRecv:=d.next;
  d.Free;
 end;
 lastRecv:=nil;
 except
  on e:Exception do ForceLogMessage('FATAL error in net2:FreeAll: '+ExceptionMsg(e));
 end;
// LogMessage('FreeAll: '+inttostr(was)+'->'+inttostr());
end;

procedure TConnection.SendData(buf: pointer; size: integer;maxlatency:integer=20);
var
 i,j:integer;
 d:TDataPacket;
 pb:PByte;
begin
 if self=nil then
  raise EError.Create('Net: connection is nil!');
 if not connected then
  raise EWarning.Create('Can''t send data: not connected '+inttostr(sessID)+' status='+inttostr(ord(status)));
 EnterCriticalSection(critSect);
 try
  try
  LogMessage('NET: outgoing message, conn '+inttostr(sessID and $FFF)+' size '+inttostr(size)+
   #13#10+HexDump(buf,min2(size,32)),6);
  // поместим сообщение в исходящий буфер соединения
  if firstSend=nil then begin // если в очереди нет вообще пакетов - создадим один
   d:=TDataPacket.Create;
   inc(d.created,maxlatency div 10);
   firstSend:=d;
   lastSend:=d;
   LogMessage('NET: new packet created '+inttostr(d.num)+', time: '+inttostr(d.created),6);
  end;
  if length(history)>0 then PutToHistory(buf,size,1);
  except
   on e:exception do ForceLogMessage('SendData E1');
  end;
  // можно ли поместить какие-либо данные в последний из пакетов, или начинать новый
  // Важно! Нельзя дописывать в пакет, который уже хотя бы раз отсылался!
  // Также не дописываем в пакет, который уже хотя бы наполовину заполнен
  try
  if (length(lastSend.data)<MAX_PACKET div 2) and (lastSend.counter=0) then begin
   j:=length(lastSend.data); // Позиция, начиная с которой можно писать данные
   i:=j+4+size; // в i будет новый размер пакета
   if i>MAX_PACKET then i:=MAX_PACKET;
   setLength(lastSend.data,i);
   LogMessage('NET: appending to packet '+inttostr(lastsend.num),6);
  end else begin
   d:=TDataPacket.Create; // Создаем новый пакет и прицепляем его к очереди
   inc(d.created,maxlatency div 10);
   if size+4>MAX_PACKET then i:=MAX_PACKET else i:=size+4;
   SetLength(d.data,i);
   lastSend.next:=d;
   lastSend:=d;
   j:=0; // позиция записи в новый пакет
   LogMessage('NET: new packet created(2) '+inttostr(d.num)+', time '+inttostr(d.created),6);
  end;
  except
   on e:exception do ForceLogMessage('SendData E2');
  end;

  try
  move(size,lastSend.data[j],4);
  inc(j,4);
  pb:=buf;
  while size>0 do begin
   // сколько еще данных можно поместить в последний пакет?
   i:=length(lastsend.data)-j;
   move(pb^,lastsend.data[j],i);
   dec(size,i);
   inc(pb,i);
   if size>0 then begin
    // нужен еще пакет
    d:=TDataPacket.Create;
    LogMessage('NET: creating additional packet for data: '+inttostr(d.num),6);
    if size>MAX_PACKET then i:=MAX_PACKET else i:=size;
    setLength(d.data,i);
    lastSend.next:=d;
    lastSend:=d;
    j:=0;
   end;
  end;
  except
   on e:exception do ForceLogMessage('SendData E1');
  end;

 finally
  LeaveCriticalSection(critsect);
 end;
end;

{ TNetThread }

var
 size:integer;
 recvBuf,sendbuf:array[0..16500] of byte;

procedure TNetThread.Execute;
var
 i,j,k,l:integer;
 rem_adr:cardinal;
 rem_port:word;
 SID,c:cardinal;
 pnum:word;
 cmd:byte;
 list,info:array[1..1000] of cardinal;
 count,sentCount:integer;
 con:TConnection;
 fl:boolean;
 d,dd:TDataPacket;
 t:cardinal;
begin
 EnterCriticalSection(threadSect); // секция захвачена всегда, когда выполняется поток
 try
 EnterCriticalSection(critSect);
 try
  // инициализация
  RegisterThread('Netwrk2');
  LogMessage(TimeStamp+' NET: Initializing, threadID='+inttostr(cardinal(GetCurrentThreadID)));
  randomize;
  try
   udp:=UDPSocket2.Create(initport,true);
  except
   udp:=UDPSocket2.Create(initport+100,true);
  end;
  Priority:=tpHigher; // повышенный приоритет потока
 finally
  LeaveCriticalSection(critSect);
 end;

 // Главный цикл, частота не более 100 Гц
 // ------------------------------------------------------
 repeat
  inc(MainTimer);
  if MainTimer and $F=0 then PingThread;

  // Этап 1: обработка входящих пакетов
  EnterCriticalSection(critSect);
  try
   t:=getTickCount;
   // Обработка входящих пакетов
   size:=16500;
   count:=0;
   try
    while true do begin
     size:=16500;
     if not udp.Receive(rem_adr,rem_port,recvbuf,size) then break;
     if size<8 then continue;
     move(recvbuf[0],SID,4);
     move(recvbuf[4],pnum,2);
     cmd:=recvbuf[6];
     if not (cmd in [1..6]) then begin size:=16500; continue; end;
     con:=nil;
     if cmd in [2..6] then
      con:=connections[SID and $FFF];
     if (con<>nil) and (con.sessID<>SID) then con:=nil;
     if (cmd in [2,3,5,6]) and (con=nil) then begin
      LogMessage('NET: no connection '+inttostr(SID and $FFF)+' for packet '+
       inttostr(pnum)+' size '+inttostr(size)+' from '+IpToStr(rem_adr)+':'+inttostr(rem_port)
       +#13#10+HexDump(@recvbuf,min2(size,32)));
      size:=16500;
      continue;
     end else
      if (cmd>1) and (con<>nil) and (con.connected) and
         ((con.remIP<>rem_adr) or (con.remPort<>rem_port)) then begin
       LogMessage('NET: remote address changed, conn: '+inttostr(con.sessID and $FFF)+
         ' ip: '+iptostr(rem_adr)+' port: '+inttostr(rem_port));
       con.remIP:=rem_adr;
       con.remPort:=rem_port;
      end;
     case cmd of
      1:begin
       // Запрос на установку соединения.
       // сперва проверим не свой ли это запрос
       // и не установлено ли уже такое соединение
       fl:=false;
       for i:=0 to 4095 do
        if (connections[i]<>nil) then
         with connections[i] do
          if ((status=csConnWait) and (sessID=SID)) or
             ((status=csConnected) and (remID=SID)) then begin
          fl:=true; break;
        end;
       if fl then begin
        if connections[i].status=csConnected then begin
         LogMessage('NET: Already connected, repeat confirmation '+inttostr(SID and $FFF));
         move(connections[j].sessID,recvbuf[8],4);
         recvbuf[6]:=2; // accepted
         try
          udp.Send(rem_adr,rem_port,recvbuf,12);
         except
          on e:exception do begin
           ForceLogMessage('NET: send error #2: '+e.message);
           sleep(10);
          end;
         end;
        end else
         LogMessage('NET: Wrong connection attempt ignored '+inttostr(SID and $FFF));
        size:=16500;
        continue;
       end;
       //Найти ожидающее соединение и соединить его
       fl:=false;
       for i:=0 to 4095 do
        if (connections[i]<>nil) {and (connections[i].status=csIdle)} and
           connections[i].accepting then begin
         connections[i].connected:=true;
         connections[i].status:=csConnected;
         connections[i].remIP:=rem_adr;
         connections[i].remPort:=rem_port;
         connections[i].remID:=SID;
         connections[i].hPos:=0;
         connections[i].hSize:=0;
         connections[i].accepting:=false;
         LogMessage('NET: connection '+inttostr(i)+'/'+inttostr(SID and $FFF)+' established with '+iptostr(rem_adr)+':'+inttostr(rem_port));
         inc(count);
         list[count]:=cardinal(connections[i]);
         info[count]:=1;
         j:=i;
         fl:=true;
         break;
        end;
       if fl then begin
        move(connections[j].sessID,recvbuf[8],4);
        recvbuf[6]:=2; // accepted
        try
         udp.Send(rem_adr,rem_port,recvbuf,12);
         LogMessage('NET: acceptance to '+IpToStr(rem_adr)+':'+inttostr(rem_port)+' conn '+inttostr(j)+' sessID='+inttostr(connections[j].sessID));
        except
         on e:exception do begin
          ForceLogMessage('NET: send error #2: '+e.message);
          sleep(10);
         end;
        end;
       end else begin
        recvbuf[6]:=3; // rejected
        recvbuf[0]:=1;
        recvbuf[1]:=0;
        recvbuf[2]:=0;
        recvbuf[3]:=0;
        try
         udp.Send(rem_adr,rem_port,recvbuf,8);
         LogMessage('NET: rejection to '+iptostr(rem_adr)+':'+inttostr(rem_port));
        except
         on e:exception do begin
          ForceLogMessage('NET: send error #3: '+e.message);
          sleep(10);
         end;
        end;
       end;
      end; // cmd=1

      2:begin
       LogMessage('Acceptance');
       if (size<>12) or (con.connected) then begin
        if con.connected then
         LogMessage('NET: already connected (duplicated acceptance?)')
        else
         LogMessage('NET: Incorrect acceptance');
        size:=16500;
        continue;
       end;
       // соединение успешно установлено
       con.remIP:=rem_adr;
       con.remPort:=rem_port;
       con.connected:=true;
       con.status:=csConnected;
       con.hPos:=0;
       con.hSize:=0;
       move(recvbuf[8],con.remID,4);
       LogMessage('NET: accepted, sessID='+inttostr(con.sessID)+', remID='+inttostr(con.remID));
       inc(count);
       list[count]:=cardinal(con);
       info[count]:=1;
      end;

      3:begin
       // отказано в соединении
       con.status:=csIdle;
       con.connected:=false;
       con.FreeAll;
       LogMessage('NET: connection rejected');
       inc(count);
       list[count]:=i;
       info[count]:=2;
      end;

      4:begin
       // разрыв соединения, тут всё непросто...
       if con=nil then // поискать соединение
        for i:=0 to 4095 do
         if (connections[i]<>nil) and (connections[i].remID=SID) then begin
          con:=connections[i]; break;
         end;
       if (con<>nil) and (con.connected) then begin
        // запрос на разрыв указанного соединения
        LogMessage('NET: connection '+inttostr(con.sessID and $FFF)+' ('+
         ipToStr(con.remIP)+':'+inttostr(con.remPort)+') closed by remote side');
        con.connected:=false;
        con.status:=csClosed;
        con.FreeAll;
        inc(count);
        list[count]:=cardinal(con);
        info[count]:=4;
       end;
      end;

      5:begin
       // пакет с данными, вышлем подтверждение
       try
        move(con.remID,recvbuf[0],4);
        recvbuf[6]:=6;
        udp.Send(rem_adr,rem_port,recvBuf,8);
        LogMessage('NET: packet '+inttostr(pnum)+' received from conn: '+
         inttostr(con.sessID and $FFF)+' size '+inttostr(size-8)+#13#10+
         hexDump(@recvbuf[8],min2(size-8,64)),6);
       except
        on e:exception do ForceLogMessage('NET: error in packet confirmation - '+e.message);
       end;
       // Ахтунг!
       j:=pnum-con.lastRecvID;
       if j<-50000 then j:=j+65536;
       if (size<=8) or (j<=0) then begin
        LogMessage('NET: packet ignored: '+inttostr(pnum)+' last: '+inttostr(con.lastRecvID)+
        ', j='+inttostr(j)+' size: '+inttostr(size),6);
        size:=16500;
        continue;
       end;
       con.lastRecvID:=pnum;
       // добавим пакет в очередь
       d:=TDataPacket.Create;
       d.num:=pnum;
       SetLength(d.data,size-8);
       move(recvbuf[8],d.data[0],size-8);
       if con.lastRecv<>nil then begin
        con.lastRecv.next:=d;
        con.lastRecv:=d;
       end else begin
        con.firstRecv:=d;
        con.lastRecv:=d;
        con.fetchPos:=0;
       end;
       // проверим не пора ли принимать сообщение
       repeat
        fl:=false;
        k:=con.fetchPos;
        // проверим наличие сообщения целиком
        move(con.firstRecv.data[k],j,4);
        inc(k,4);
        d:=con.firstRecv;
        i:=j;
        while (d<>nil) and (length(d.data)-k<=i) do begin
         dec(i,length(d.data)-k);
         k:=0;
         d:=d.next;
        end;
        if i=0 then fl:=true;
        if (i>0) and (d<>nil) and (length(d.data)-k>=i) then fl:=true;

        if fl then begin
         // если сообщение присутствует полностью - перенести его в хранилище,
         // а ненужные пакеты - удалить
         d:=TDataPacket.Create;
         d.src:=con;
         SetLength(d.data,j);
         i:=0; // позиция в приёмнике
         inc(con.fetchPos,4); // позиция в источнике
         k:=con.fetchPos;
         while (con.firstRecv<>nil) and (length(con.firstRecv.data)-k<=j) do begin // содержимое пакета копировать целиком
          l:=length(con.firstRecv.data)-k;
          move(con.firstRecv.data[k],d.data[i],l);
          dec(j,l);
          inc(i,l);
          k:=0;
          con.fetchPos:=0;
          dd:=con.firstRecv;
          con.firstRecv:=con.firstRecv.next;
          dd.Free;
         end;
         if con.firstRecv=nil then con.lastRecv:=nil;

         if j>0 then begin // Осталось еще забрать часть из пакета
          move(con.firstRecv.data[con.fetchPos],d.data[i],j);
          inc(con.fetchPos,j);
         end;

         if logGroups[6] then LogMessage('NET: message received from conn '+inttostr(con.sessID and $FFF)+', '+
           IpToStr(con.remIP)+':'+inttostr(con.remPort)+' size '+inttostr(length(d.data))+#13#10+
           hexDump(@d.data[0],min2(length(d.data),32)),6);
         if length(con.history)>0 then con.PutToHistory(d.data,length(d.data),2);

         // добавим в хранилище
         if storageLast<>nil then begin
          storageLast.next:=d;
          storageLast:=d;
         end else begin
          storageFirst:=d;
          storageLast:=d;
         end;
         inc(count);
         list[count]:=cardinal(d);
         info[count]:=3;
        end;
       until (fl=false) or (con.firstRecv=nil);
      end;

      6:begin
       // подтверждение получения данных
       if (con.firstSend<>nil) and (con.firstSend.num=pnum) then begin
        c:=GetTickCount;
        if (c>con.firstSend.ticks) then
         con.ping:=(c-con.firstSend.ticks)/1000;
        con.avgping:=con.avgping*0.8+con.ping*0.2;
        d:=con.firstSend;
        con.firstSend:=con.firstSend.next;
        d.Free; // освобождение памяти
       end;
       if con.firstSend=nil then con.lastSend:=nil;
       LogMessage('NET: conn: '+inttostr(con.sessID and $FFF)+', packet '+
        inttostr(pnum)+' confirmed, avg ping: '+inttostr(round(con.avgping*1000)),6);
      end;

     end; //  case
    end; //  while
   except
    on e:Exception do Signal('Net\Error\'+e.Message,0);
   end;
  finally
   LeaveCriticalSection(critSect);
   t:=GetTickCount-t;
   avgTime1:=avgTime1*0.99+t*0.01;
  end;

  t:=getTickCount;
  // уведомления
  for i:=1 to count do begin
   if info[i]=1 then
    Signal('NET\Conn\Connected',list[i]);
   if info[i]=2 then
    Signal('NET\Conn\ConnectionRejected',cardinal(connections[list[i]]));
   if info[i]=3 then
    if @onUserMsg<>nil then begin
     d:=TDataPacket(pointer(list[i]));
     onUserMsg(d.src,@d.data[0],length(d.data),d.src.remIP,d.src.remPort);
     d.created:=0; // отметка как старое - для удаления
    end else
     Signal('NET\Conn\UserMsg',list[i]);
   if info[i]=4 then
    Signal('Net\Conn\ConnectionClosed',list[i]);
  end;
  t:=GetTickCount-t;
  avgTime2:=avgTime2*0.99+t*0.01;

  // Этап 2: формирование и отправка исходящих пакетов
  EnterCriticalSection(critSect);
  try
  t:=getTickCount;
  count:=0;
  sentCount:=0; // Ограничение трафика за итерацию
  c:=GetTickCount;
  for i:=0 to 4095 do
   if (connections[i]<>nil) and (connections[i].connected) and
      (connections[i].firstSend<>nil) then with connections[i] do begin

    if firstSend.created<=MainTimer then begin
     inc(firstSend.counter);
     // если состоялось 8 неудачных попыток доставки
     // или прошло более 30 секунд
     if (firstSend.counter=11) or (c>firstsend.ticks+30000) then begin
      LogMessage('NET: cannot deliver pkt '+inttostr(firstsend.num)+' to '+
        IpToStr(remIP)+':'+inttostr(remPort)+' ('+inttostr(firstSend.counter)+
        '), connection broken: '+inttostr(sessID and $FFF));
      FreeAll;
      connected:=false;
      status:=csBroken;
      if count<1000 then begin
       inc(count);
       list[count]:=i;
      end;
     end else begin
      move(remID,sendbuf[0],4);
      move(firstSend.num,sendBuf[4],2);
      sendBuf[6]:=5;
      j:=length(firstSend.data);
      move(firstSend.data[0],sendBuf[8],j);
      try
       udp.Send(remIP,remPort,sendBuf,8+j);
      except
       on e:exception do begin
        ForceLogMessage('Send error: '+e.message);
        sleep(10);
        break;
       end;
      end;
      inc(sentCount,60+j);
      // задержка до перепосылки зависит от размера пакета и качества связи
      inc(firstSend.created,sqr(1+firstSend.counter)*5+
        round(avgping*75)+
        (60+j) div 40);
      lastSentTime:=MainTimer;
      LogMessage('NET: Sending with conn: '+inttostr(i)+' ('+IpToStr(remIP)+':'+
        inttostr(remPort)+') size: '+inttostr(j)+', pkt: '+inttostr(firstsend.num)+
        ' timer: '+inttostr(MainTimer)+#13#10+
        hexDump(@sendbuf[8],min2(j,32)),6);
      if sentCount>MaxSendTick then break; // не более указанного объема за итерацию
     end;
    end;
   end;
  finally
   LeaveCriticalSection(critSect);
  end;
  // Уведомление о разорванных соединениях
  for i:=1 to count do
   Signal('NET\Conn\ConnectionBroken',cardinal(connections[list[i]]));
  t:=GetTickCount-t;
  avgTime3:=avgTime3*0.99+t*0.01;

  // Этап 3: обработка соединений, таймаутов, структур данных, состояний соединений
  EnterCriticalSection(critSect);
  try
   t:=getTickCount;
   j:=MainTimer-1500; // удаление сообщений, хранившихся не менее 15 секунд
   while (storageFirst<>nil) and (storageFirst.created<j) do begin
    d:=storageFirst;
    StorageFirst:=d.next;
    d.Free;
   end;
   if storageFirst=nil then storageLast:=nil;

   // обработка пинга
   c:=GetTickCount;
   j:=(maintimer and 3)*1024;
   for i:=j to j+1023 do
    if (connections[i]<>nil) and (connections[i].firstSend<>nil) then begin
     if c-connections[i].firstSend.ticks>connections[i].ping*1000 then
      connections[i].ping:=(c-connections[i].firstSend.ticks)/1000;
    end;
   // периодическая отсылка пинговых пакетов (раз в 2.5 секунд,
   // но только в те соединения, где нет pending packets)
   if concnt>2000 then begin
    j:=maintimer mod 512;
    k:=8;
   end else begin
    j:=maintimer mod 256;
    k:=16;
   end;
   for i:=j*k to j*k+k-1 do
    if (connections[i]<>nil) and (connections[i].status=csConnected) and
     (connections[i].lastSentTime<MainTimer-100) and (connections[i].firstSend=nil) then begin
     d:=TDataPacket.Create;
     connections[i].firstSend:=d;
     connections[i].lastSend:=d;
     LogMessage('NET: ping packet '+inttostr(d.num)+' created for conn '+inttostr(i),6);
    end;

   if processingFlag then begin
    processingFlag:=false;
    for i:=0 to 4095 do
     if (connections[i]<>nil) then begin
      if connections[i].status=csConnecting then with connections[i] do begin
       // послать запрос на установку соединения
       move(sessID,sendbuf[0],4);
       sendbuf[4]:=random(256);
       sendbuf[5]:=random(256);
       sendbuf[6]:=1;
       if remIP=0 then remIP:=$FFFFFFFF;
       try
        udp.Send(remIP,remPort,sendbuf,8);
        LogMessage('NET: sending conn '+inttostr(i)+' request to '+ipToStr(remIP)+':'+inttostr(remPort));
        status:=csConnWait;
       except
        on e:exception do begin
         ForceLogMessage('NET: send error #1: '+e.message);
         sleep(10);
        end;
       end;
      end;
      if connections[i].status=csDisconnecting then with connections[i] do begin
       // послать запрос на разрыв соединения
       try
        move(remID,sendbuf[0],4);
        sendbuf[4]:=0;
        sendbuf[5]:=0;
        sendbuf[6]:=4;
        udp.Send(remIP,remPort,sendbuf,8);
        LogMessage('NET: sending conn '+inttostr(i)+' disconnect to '+ipToStr(remIP)+':'+inttostr(remPort));
       except
        on E:Exception do ForceLogMessage('Error in disconnection: '+e.message);
       end;
       status:=csDisconnected;
       connected:=false;
       FreeAll;
       if accepting then begin
        status:=csIdle;
        LogMessage('Disconnected, ready to accept');
       end;
       if deleting then Destroy;
      end;
     end;
   end;

  finally
   LeaveCriticalSection(critSect);
   t:=GetTickCount-t;
   avgTime4:=avgTime4*0.99+t*0.01;
  end;

  sleep(10);
 until terminated;
 // Конец главного цикла
 // ------------------------------------------------------

 EnterCriticalSection(critSect);
 try
  // финализация
  LogMessage('NET: thread stopping '+inttostr(GetTickCount));
  FreeAndNil(udp);

  // Нужно подчистить все структуры
  LogMessage('NET: thread done '+inttostr(GetTickCount));
 finally
  LeaveCriticalSection(critSect);
 end;

 except
  on e:Exception do begin
   ForceLogMessage('NET: error in NET thread - '+e.Message);
  end;
 end;
 LeaveCriticalSection(threadSect);
 UnregisterThread;
end;

{ TDataPacket }

constructor TDataPacket.Create;
begin
 created:=MainTimer;
 inc(LastPacketID);
 num:=LastPacketID;
 ticks:=GetTickCount;
end;

function GetMsg(handle:cardinal;var data:pointer):integer;
var
 d:TDataPacket;
begin
 EnterCriticalSection(critSect);
 try
  d:=pointer(handle);
  result:=length(d.data);
  data:=@d.data[0];
 finally
  LeaveCriticalSection(critSect);
 end;
end;

procedure GetMsgOrigin(handle:integer;var ip:cardinal;var port:word);
var
 d:TDataPacket;
begin
 EnterCriticalSection(critSect);
 try
  d:=pointer(handle);
  ip:=d.src.remIP;
  port:=d.src.remPort;
 finally
  LeaveCriticalSection(critSect);
 end;
end;

initialization
 InitCritSect(critSect,'Netwrk2',50);
 InitCritSect(threadSect,'Netwrk2Thr',10);
 randomize;
 LastPacketID:=getTickCount;
finalization
 DeleteCritSect(critSect);
 DeleteCritSect(threadSect);
end.
