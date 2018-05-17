{ Модуль службы связи.

  Служба связи реализует сетевой протокол на базе UDP:
  1. Транспортный двухточечный протокол с установкой соединения.
     Game Connection Protocol (GCP)
     Это некий аналог PPP и модемной связи.
     Функциональность на этом уровне такая:
     а) установить соединение одним из способов (указав адрес сервера либо
        делая поиск в локальной сети через бродкасты)
     б) послать/получить блок данных (адрес указывать не нужно, т.к. протокол connection-type)
   Свойства:
     - гарантированная доставка, порядок доставки сохраняется, если сообщение
       не удается доставить в течение заданного времени - получаем сообщение о потере связи
     - регулярная проверка состояния соединения, если оно перестало работать -
       получаем сообщение о потере связи
     - размер блоков данных не ограничен, клиент имеет возможность наблюдать за
       ходом отправки/получения больших блоков
}
unit Connection;
interface
const
 // локальный порт для UDP-сокета
 LocalPort:word=6993;
type
 // Класс для работы с соединением транспортного протокола
 // Использует сигналы для оповещения о различных событиях:
 //   net\GCP\name\Connected - соединение установлено
 //   net\GCP\name\ConnectFailed - не удалось установить соединение
 //   net\GCP\name\Disconnected - соединение прервано удаленной стороной
 //   net\GCP\name\Broken - соединение нарушено
 //   net\GCP\name\onData - уведомление о том, что получен пакет данных
 TGameConnection=class
  // Создание объекта соединения с указанным именем.
  constructor Create(name:string);
  // Удаление объекта
  destructor Destroy; override;
  // Начать подключаться (с использованием указанного адреса, адрес - либо
  // стандартная запись адреса хоста, либо пустая строка)
  procedure Connect(address:string;GCPport:integer;LAN:boolean);
  // Начать отключение
  procedure Disconnect;
  // Возвращает состояние соединения (установлено или нет)
  function IsConnected:boolean;
  // Послать данные
  procedure Send(buffer:pointer;size:integer);
  // Принять данные (если буфер позволяет), возвращает необходимый размер буфера
  function Receive(buffer:pointer;size:integer):integer;
  // Возвращает размер ожидающего пакета, либо 0 если полученных пакетов нету
  function GetRecv:integer;
  // продвинутый вариант: возвращает кол-во пакетов, которые можно забрать,
  //  размер первого из них, размер пакета, который в данный момент принимается и
  //  кол-во байт, которые уже приняты (полезно для показа прогресса больших пакетов)
  procedure GetRecvEx(var pCount,pSize,recvTotal,recvCurrent:integer);
  // показывает состояние отправки: кол-во пакетов в очереди на отправку,
  //  размер пакеты, который сейчас отправляется и какая часть его уже отправлена
  procedure GetSendEx(var pCount,sendTotal,sendCurrent:integer);
  // Возвращает строку с описанием ошибки (узнать о возникновении ошибки можно
  //  по сигналам оповещения)
  function GetLastError:string;

  // Дать указатель на заданное сообщение (возвращает размер сообщения), -1/nil - если его уже/еще нет
  function GetMsg(handle:integer;var data:pointer):integer;
 protected
  outbox,packets,incoming:TObject; // очереди входящих сообщений, исходящих сообщений и исходящих пакетов
  cname:string;
  error:string;
  status:integer; // состояние соединения
  ip:cardinal;
  port,ipport:integer;
  LocalCon,RemoteCon:word;
  timeout:double;
  lastRecv,lastSent:integer;
  procedure Process(size:integer); // обработка входящего udp-пакета
  procedure CheckForMsg(n:integer); // проверить не получено ли сообщение
  procedure Poll;
  // Добавляет объект в очередь, возвращает его индекс
  function PutMsgToQueue:integer;
 end;

implementation
 uses windows,eventMan,classes,winsock,SysUtils,network,MyServis;
 const
  MAXBOXMSG=100;
  MAXCON=500;
 type
  TNetThread=class(TThread)
   procedure Execute; override;
  end;

  TBoxMessage=class
   data:array of byte;
   datasize:integer;
   msg:integer;
   parts,cnt:word;
   constructor Create(iniSize:integer);
   procedure Append(source:pointer;size:integer);
   procedure Write(source:pointer;size,pos:integer);
  end;

  // очередь пакетов
  TBox=class
   count:integer;
   messages:array[1..MAXBOXMSG] of TBoxMessage;
   complFlag:boolean;
   constructor Create;
   destructor Destroy; override;
   // Поместить пакет в очередь (size - размер данных!)
   procedure Put(cmd:byte;size:word;data:pointer);
   // Записать блок данных
   procedure PutData(msg:integer;part:word;final:boolean;data:pointer;size:integer);
  end;

 var
  thread:TNetThread;
  connections:array[1..MAXCON] of TGameConnection;
  count:integer=0;
  MainTimer:integer=0;
  critSect:TMyCriticalSection;

 const
  // Состояния соединения
  csIdle          = 0; // соединение отсутствует и ничего не происходит
  csJoining       = 1; // пытаемся подкючиться к удаленному компьютеру
  csAccepting     = 2; // не пытаемся, но ждем подключения со стороны
  csRunning       = 3; // соединение установлено и работает
  csBroken        = 4; // соединение было нарушено
  csDisconnecting = 5; // соединение закрывается

  // Типы пакетов
  ptData          = 0;
  ptDataLast      = 1;
  ptConfirm       = 4;
  ptResend        = 5;
  ptTest          = 6;
  ptClose         = 7;
  ptConnect       = 8;
  ptAccept        = 9;
  ptReject        = 10;

 type
  TPacketHeader=word;

  TQueuedMessage=class
   id:integer;
   msg:pointer;
   size:integer;
   counter:integer;
  end;
 var
  // общий буфер для приема пакетов UDP
  recvBuf:array[0..2047] of byte;
  rem_adr:cardinal;
  rem_port:word;

  udp:UDPSocket2;

  // Очередь принятых сообщений
  queue:array[0..1023] of TQueuedMessage;
  qFirst,qFree:integer;

{ TGameConnection }
procedure TGameConnection.CheckForMsg(n: integer);
var
 i,m:integer;
begin
 if incoming=nil then exit;
 with incoming as TBox do begin
  for i:=1 to count do
   if (messages[i].msg=n) and (messages[i].cnt=messages[i].parts) then begin
    m:=PutMsgToQueue;
    queue[m].size:=messages[i].datasize;
    GetMem(queue[m].msg,queue[m].size);
    move(messages[i].data[0],queue[m].msg^,queue[m].size);
    LastRecv:=n;
    Signal('net\GCP\'+cname+'\onData',queue[m].id);
   end;
 end;
end;

procedure TGameConnection.Connect(address: string; GCPport: integer;
  LAN: boolean);
var
 h:PHostEnt;
 i:integer;
 fl:boolean;
begin
 if status<>csIdle then begin
  Signal('Debug\GCP\Connect skipped due to connection status');
  exit;
 end;
 EnterCriticalSection(critSect);
 try
  error:='';
  ipport:=LocalPort;
  port:=GCPport;
  i:=pos(':',address);
  if (i>0) or (pos('.',address)=0) then  begin
   ipport:=StrToInt(copy(address,i+1,length(address)-i));
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
     error:='Can''t resolve host address: '+address;
     exit;
    end;
    move(h^.h_addr^[0],ip,4);
   end;
  end else
   ip:=$FFFFFFFF;

  if udp=nil then
   udp:=UDPSocket2.Create(LocalPort,lan);

  outbox:=TBox.Create;
  packets:=TBox.Create;
  incoming:=TBox.Create;
  timeout:=Now+0.0001;
  lastRecv:=0; lastSent:=0;

 finally
  LeaveCriticalSection(critSect);
 end;
end;

constructor TGameConnection.Create(name: string);
var
 i:integer;
begin
 EnterCriticalSection(critSect);
 try
  inc(count);
  if count=1 then thread:=TNetThread.Create(true);
  thread.FreeOnTerminate:=true;
  status:=csIdle;
  for i:=1 to MAXCON do
   if connections[i]=nil then begin
    LocalCon:=i;
    connections[i]:=self;
   end;
 finally
  LeaveCriticalSection(critSect);
 end;
end;

destructor TGameConnection.Destroy;
var
 i:integer;
begin
 EnterCriticalSection(critSect);
 try
  connections[localCon]:=nil;
  dec(count);
  if count=0 then FreeAndNil(udp);
  FreeAndNil(outbox);
  FreeAndNil(packets);
  FreeAndNil(incoming);
 finally
  LeaveCriticalSection(critSect);
 end;
end;

procedure TGameConnection.Disconnect;
begin
 if status<>csRunning then exit;
 EnterCriticalSection(critSect);
 try
  status:=csDisconnecting;
 finally
  LeaveCriticalSection(critSect);
 end;
end;

function TGameConnection.GetLastError: string;
begin
 result:=error;
end;

function TGameConnection.GetMsg(handle: integer; var data: pointer): integer;
var
 n:integer;
begin
 EnterCriticalSection(critSect);
 try
  n:=handle and 1023;
  if (queue[n]=nil) or (queue[n].id<>handle) then begin
   result:=0; data:=nil; exit;
  end;
  data:=queue[n].msg;
  result:=queue[n].size;
 finally
  LeaveCriticalSection(critSect);
 end;
end;

function TGameConnection.GetRecv: integer;
begin
 EnterCriticalSection(critSect);
 try

 finally
  LeaveCriticalSection(critSect);
 end;
end;

procedure TGameConnection.GetRecvEx(var pCount, pSize, recvTotal,
  recvCurrent: integer);
begin
 EnterCriticalSection(critSect);
 try

 finally
  LeaveCriticalSection(critSect);
 end;
end;

procedure TGameConnection.GetSendEx(var pCount, sendTotal,
  sendCurrent: integer);
begin
 EnterCriticalSection(critSect);
 try

 finally
  LeaveCriticalSection(critSect);
 end;
end;

function TGameConnection.IsConnected: boolean;
begin
 result:=status=csRunning;
end;

procedure TGameConnection.Poll;
begin

end;

procedure TGameConnection.Process(size:integer);
var
 psize,pos,cmd,i:integer;
 hdr:^TPacketHeader;
 fl:boolean;
 buf:array[0..1023] of byte;
 st:string;
 v,c:integer;
begin
 pos:=2;
 timeout:=Now+0.0002;
 while pos<size do begin
  hdr:=@recvBuf[pos];
  psize:=hdr^ and $FFF;
  cmd:=hdr^ shr 12;
  if (pos+psize>size) or (psize<2) then break;
  case cmd of
    // Запрос на соединение
    ptConnect:if psize=8 then begin
     fl:=true;
     if status<>csAccepting then begin fl:=false; st:='Don''t accept'; end;
     move(recvbuf[pos+2],v,4);
     if (port<>0) and (v<>port) then begin fl:=false; st:='Port disabled'; end;
     c:=recvbuf[pos+6];
     if fl then begin
      // Запрос удовлетворен
      RemoteCon:=c;
      move(RemoteCon,buf[0],2);
      move(LocalCon,buf[2],2);
      (packets as TBox).Put(ptAccept,4,@buf);
      status:=csRunning;
     end else begin
      // Запрос отклонен
      move(c,buf[0],2);
      move(st[1],buf[2],length(st));
      (packets as TBox).Put(ptAccept,2+length(st),@buf);
     end;
    end;
    // Подтверждение подключения
    ptAccept:if (psize=6) and (status=csJoining) then begin
     if recvbuf[pos+2]=LocalCon then begin
      RemoteCon:=0;
      move(recvBuf[pos+3],RemoteCon,2);
      status:=csRunning;
     end;
    end;
    // Отказано в подключении
    ptReject:if (psize>=4) and (status=csJoining) then begin
     if recvbuf[pos+2]=LocalCon then begin
      status:=csIdle;
      LocalCon:=0;
      if psize>4 then begin
       SetLength(st,psize-4);
       move(recvbuf[pos+4],st[1],psize-3);
      end else st:='';
      Signal('net\GCP\'+cname+'\ConnectFailed\'+st,0);
     end;
    end;
    // получен пакет данных
    ptData:if psize=1030 then begin
     move(recvbuf[pos+2],v,4);
     c:=v shr 12;
     v:=v and $FFF;
     (incoming as TBox).PutData(c,v,false,@recvbuf[pos+6],psize-6);
     (packets as TBox).Put(ptConfirm,4,@recvbuf[pos+2]);
     if c=LastRecv+1 then CheckForMsg(c);
    end;
    // получен финальный пакет данных
    ptDataLast:if psize>6 then begin
     move(recvbuf[pos+2],v,4);
     c:=v shr 12;
     v:=v and $FFF;
     (incoming as TBox).PutData(c,v,true,@recvbuf[pos+6],psize-6);
     (packets as TBox).Put(ptConfirm,4,@recvbuf[pos+2]);
     if c=LastRecv+1 then CheckForMsg(c);
    end;
    // Получено уведомление о закрытии соединения
    ptClose:if status=csRunning then begin
     Signal('Net\GCP\'+cname+'\Disconnected',0);
     LocalCon:=0; RemoteCon:=0;
     status:=csIdle;
     FreeAndNil(packets);
     FreeAndNil(outbox);
    end;
    // Подтверждение доставки блока
    ptConfirm:begin

    end;

   else break;
  end;
  inc(pos,size);
 end;
end;

function TGameConnection.PutMsgToQueue: integer;
var
 id:integer;
begin
 id:=qFree;
 result:=qFree and 1023;
 inc(qFree);
 if qFree and 1023=qFirst then begin
  FreeAndNil(queue[qFirst]);
  qFirst:=(qFirst+1) and 1023;
 end;
 queue[result]:=TQueuedMessage.Create;
 queue[result].counter:=MainTimer+150;
 queue[result].size:=0;
 queue[result].id:=id;
end;

function TGameConnection.Receive(buffer: pointer; size: integer): integer;
begin
 EnterCriticalSection(critSect);
 try

 finally
  LeaveCriticalSection(critSect);
 end;
end;

procedure TGameConnection.Send(buffer: pointer; size: integer);
begin
 if status<>csRunning then raise EWarning.Create('Not yet connected');
 EnterCriticalSection(critSect);
 try
//  (outbox as TBox).
 finally
  LeaveCriticalSection(critSect);
 end;
end;

{ TNetThread }
procedure TNetThread.Execute;
var
 i,size:integer;
 cn:word absolute recvbuf;
 box:TBox;
begin
 repeat
  inc(MainTimer);
  EnterCriticalSection(critSect);
  try
   HandleSignals;
   // Обработка входящих пакетов
   size:=2048;
   while udp.Receive(rem_adr,rem_port,recvbuf,size) do begin
    for i:=1 to count do
     if (connections[i].RemoteCon=cn) and (connections[i].status<>csIdle) then
      connections[i].Process(size);
    size:=2048;
   end;
   // Отправка исходящих пакетов
   for i:=1 to MAXCON do
    if (connections[i]<>nil) and (connections[i].status<>csIdle) then
     if (connections[i].packets as TBox).count>0 then begin
      box:=connections[i].packets as TBox;
//      udp.Send(rem_adr,rem_port,box.messages[1].data[0]);
     end;

   // Удаление устаревших сообщений из общей очереди
   while (qFirst<(qFree and 1023)) and (MainTimer>queue[qFree].counter) do begin
    FreeAndNil(queue[qFirst]);
    qFirst:=(qFirst+1) and 1023;
   end;
  finally
   LeaveCriticalSection(critSect);
  end;
  sleep(20);
 until count=0;
end;

{ TBoxMessage }

procedure TBoxMessage.Append(source: pointer; size: integer);
begin
 if datasize+size>length(data) then
  SetLength(data,datasize+size+length(data) div 2);
 move(source^,data[datasize],size);
 inc(datasize,size);
end;

constructor TBoxMessage.Create(iniSize: integer);
begin
 setlength(data,iniSize);
 datasize:=0;
 msg:=0;
 parts:=65535; cnt:=0;
end;

procedure TBoxMessage.Write(source: pointer; size, pos: integer);
begin
 if pos+size>length(data) then
  SetLength(data,pos+size+length(data) div 2);
 move(source^,data[pos],size);
 if pos+size>datasize then datasize:=pos+size;
end;

{ TBox }

constructor TBox.Create;
begin
 count:=0;
 complFlag:=false;
 fillchar(messages,sizeof(messages),0);
end;

destructor TBox.Destroy;
var
 i:integer;
begin
 for i:=1 to count do
  FreeAndNil(messages[i]);
end;

procedure TBox.Put(cmd: byte; size: word; data: pointer);
var
 hdr:TPacketHeader;
begin
 // проверим есть ли доступный буфер
 if (count=0) or (messages[count].datasize+size+4>=1400) then begin
  if count=MAXBOXMSG then raise EError.Create('GCP: out of send buffers');
  inc(count);
  messages[count]:=TBoxMessage.Create(1400);
 end;
 hdr:=size+sizeof(hdr)+cmd shl 12;
 messages[count].Append(@hdr,sizeof(hdr));
 messages[count].Append(data,size);
end;

procedure TBox.PutData(msg: integer; part: word; final: boolean; data:pointer;size:integer);
var
 i,n:integer;
begin
 n:=0;
 for i:=1 to count do
  if messages[i].msg=msg then begin n:=i; break; end;
 if n=0 then begin
  if count=MAXBOXMSG then raise EError.Create('GCP: out of message buffers');
  inc(count);   n:=count;
  messages[n]:=TBoxMessage.Create((part+1)*1024);
  messages[n].msg:=msg;
 end;
 inc(messages[n].cnt);
 if final then messages[n].parts:=part+1;
 messages[n].Write(data,size,part*1024);
 if messages[n].cnt=messages[n].parts then complFlag:=true;
end;

initialization
 InitializeCriticalSection(critSect);
finalization
 DeleteCriticalSection(critSect);
end.
