// Network engine layer, ver 3 (messaging protocol over HTTP, client-side part)
//
// Copyright (C) 2014 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R+}
unit Apus.Engine.Networking3;
interface
uses MyServis;
type
 TNetMessage=record
  values:StringArr;
  index:integer;
  function NextInt:integer;
  function NextStr:string;
  function Empty:boolean;
  function Int(idx:integer):integer;
 end;

var
 NW3ErrorMessage:string; // текст последней ошибки (если был сигнал Net\Conn3\Error)
 mainLoopDelay:integer=10; // периодичность главного цикла в мс (вносит задержку в отправку/приём
                           // сообщений, но помогает объединять их в один запрос

 failedRequests:integer; // каждый сбойный запрос увеличивает счётчик, успешный - обнуляет
 lastPollSent:TDateTime; // время отправки последнего POLL-запроса

 // Перечень всех возможных сигналов:
 //  NET\Conn3\AccountCreated - аккаунт успешно создан (CreateAccount)
 //  NET\Conn3\AccountFailed - запрос создания аккаунта принят (CreateAccount), но отклонён -
 //                            что-то не так, см. errorMessage и код ошибки в тэге
 //  NET\Conn3\ConnectionFailed - не удалось подключиться к серверу (нет интернета, неправильный адрес, сервер лежит)
 //  NET\Conn3\ConnectionRejected - сервер отказал в подключении (бан)
 //  NET\Conn3\ConnectionClosed - сервер закрыл соединение
 //  NET\Conn3\ConnectionBroken - установленное соединение разорвано по техническим причинам
 //  NET\Conn3\Connected - соединение установлено, но не авторизовано
 //  NET\Conn3\Logged - авторизация успешно пройдена - можно работать
 //  NET\Conn3\AccessDenied - авторизация не прошла, соединение закрыто, причина - в тексте ошибки
 //  NET\Conn3\Error - произошла какая-то иная ошибка
 //  NET\Conn3\DataReceived - получено сообщение (хэндл в тэге)

 // Создание нового аккаунта. (extras - набор дополнительных полей, разделённых #9 (\t)
 procedure CreateAccount(server,login,password,name,extras:string);

 // Устанавливает соединение с сервером по указанному адресу/порту.
 // Подключение происходит асинхронно, уведомление о результате придёт сигналом
 // возможно подключение с авторизацией или без неё
 procedure Connect(server,login,password,clientinfo:string);

 // Отправка массива данных
 procedure SendData(data:array of const);

 // true - если возможна отправка данных через SendData
 function Connected:boolean;

 // Получить содержимое поступившего сообщения (хэндл передается в тэге сигнала Net\Conn3\UserMsg)
 procedure GetNetMessage(handle:integer;var msg:TNetMessage);

 // Форматирует строку сообщения из массива значений
// function FormatMessage(data:array of const):string;

 // Закрывает соединение, в нормальных условиях сервер максимально быстро об этом узнаёт
 procedure Disconnect(extraInfo:string='');

 // Проверка незанятости имени (не требует установки соединения)
// procedure CheckName(name:string);

 // Парсит и ресолвит (если необходимо) адрес, заданный в виде строки
 // Внимание!!! Может занять много времени!
 procedure GetInternetAddress(address:AnsiString;var ip:cardinal;var port:word);

 // Is internet connection available? positive - yes, negative - no
 function CheckInternetConnection:integer;


implementation
 uses {$IFDEF MSWINDOWS}windows,winsock,{$ELSE}CrossPlatform,Sockets,BaseUnix,{$ENDIF}
      {$IFDEF IOS}CFBase,{$ENDIF}sysutils,classes,eventman,DCPmd5a,httpRequests;

 type
  TMainThread=class(TThread)
   server,login,password,clientInfo:string;
   logoutInfo:string;
   procedure Execute; override;
  end;

  TConnectionState=(csNone,           // до инициализации
                    csConnecting,     // подключение (получение временного ID)
                    csConnected,      // подключено, но не авторизовано
                    csLogging,        // идёт авторизация
                    csLogged,         // авторизация прошла - можно работать
                    csDisconnecting,
                    csDisconnected);  // соединение завершено (нормально или же по ошибке)

 var
  mainThread:TMainThread;
  critSect:TMyCriticalSection;
  state:TConnectionState; // current state
  userID:integer; // current UserID
  MD5pwd:string; // short hash for signature
  serial:cardinal; // request serial number
  activePollRequest:integer; // current poll request ID (0 - no active poll request)
  activePostRequest:integer; // current post request ID (0 - no active post request)
  lastPostSent:TDateTime; // время первой отправки POST-запроса с ID=activePostRequest (для таймаута)
  lastPollURL:string;
  lastPostURL,lastPostData:string;
  lastPostType:TContentType;
  connectionTimeout:int64;

  // outbox messages
  outQueue:array[0..255] of string;
  outStart,outFree:integer;

  // inbox messages
  // сообщения хранятся в кольцевом буфере постоянно, старые перезаписываются новыми
  inQueue:array[0..63] of string;
  inQueueTag:array[0..63] of integer;
  inPos:integer; // сюда нужно писать очередное сообщение
  lastTag:integer;

{$IFDEF DARWIN}{$DEFINE NETLIB_C}{$ENDIF}
{$IFDEF ANDROID}{$DEFINE NETLIB_C}{$ENDIF}
{$IFDEF NETLIB_C}
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


var
 WSAInit:boolean;

procedure GetInternetAddress(address:AnsiString;var ip:cardinal;var port:word);
 var
  i:integer;
  h:PHostEnt;
  fl:boolean;
  {$IFDEF MSWINDOWS}
  WSAData:TWSAData;
  {$ENDIF}
 begin
  {$IFDEF MSWINDOWS}
  if not WSAInit then begin
   WSAStartup($0202, WSAData);
   WSAInit:=true;
  end;
  {$ENDIF}

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
     ip:=inet_addr(PAnsiChar(address));
    end else begin
     LogMessage('Resolving host address: '+address);
     sleep(10);
     h:=GetHostByName(PAnsiChar(address));
     if h=nil then begin
      {$IFDEF MSWINDOWS}
      port:=WSAGetLastError;
      {$ENDIF}
      ip:=0;
     end else
      move(h^.h_addr^[0],ip,4);
     LogMessage('Resolved IP: '+iptostr(ip));
    end;
   end else
    ip:=$FFFFFFFF;
  except
  end;
 end;

function ShortMD5(st:string):string;
 begin
  result:=copy(MD5(st),1,10);
 end;

procedure EventHandler(event:TEventStr;tag:TTag);
 var
  i,code,t,e1,e2,httpStatus:integer;
  response:AnsiString;
  sa:AStringArr;
 begin
  if (event='HTTP_Event\ResendPost') and (activePostRequest>0) then begin
    LogMessage('NW3: resending POST request');
    activePostRequest:=HTTPRequest(lastPostURL,lastPostData,'HTTP_Event',4000,lastPostType);
    exit;
  end;
  code:=GetRequestResult(tag,response,@httpStatus);
  if code<>httpStatusCompleted then begin
   // Request failed
   inc(failedRequests);
   ForceLogMessage(Format('NW3 HTTP request %d failure (state=%d): %s',
     [tag,ord(state),response]));
   Sleep(50);
   if state=csConnecting then Signal('NET\Conn3\ConnectionFailed')
    else begin
     e1:=pos('404 Not Found',response);
     e2:=pos('503 Internal Server Error',response);
     if (e1 in [1..100]) or (e2 in [1..100]) or
        (MyTickCount>connectionTimeout) then begin
      Signal('NET\Conn3\ConnectionBroken',1);
      state:=csDisconnected;
     end else begin
      sleep(1000);
      LogMessage('NW3: Resending request');
      // Resend request
      if tag=activePollRequest then
       activePollRequest:=HTTPRequest(lastPollURL,'','HTTP_Event');
      if tag=activePostRequest then
       activePostRequest:=HTTPRequest(lastPostURL,lastPostData,'HTTP_Event',4000,lastPostType);
     end;
    end;
  end else begin
   failedRequests:=0;
   connectionTimeout:=MyTickCount+120000; // +100 seconds
   // Success
   case state of
    csConnecting:begin // simple login
      userID:=StrToIntDef(response,-1);
      LogMessage('NW3: UserID='+inttostr(userID));
      if userID=-1 then begin
       LogMessage('NW3 Rejected: '+response);
       Signal('NET\Conn3\ConnectionRejected');
       if mainThread<>nil then mainThread.Terminate;
      end else begin
       state:=csConnected; // UserID received
       Signal('NET\Conn3\Connected');
      end;
     end;

    csLogging:begin // advanced login
      userID:=StrToIntDef(response,-1);
      if userID=-1 then begin
       LogMessage('NW3 Access Denied: '+response);
       NW3ErrorMessage:=response;
       Signal('Net\Conn3\AccessDenied');
       state:=csDisconnected;
       if mainThread<>nil then mainThread.Terminate;
      end else begin
       LogMessage('NW3 Authenticated under UserID='+inttostr(userID));
       Signal('NET\Conn3\Logged',userID);
       state:=csLogged; // Authorized
      end;
     end;

    csLogged:begin
      if tag=activePollRequest then begin
       if length(response)>0 then begin
        if copy(response,1,5)='WTF!?' then begin
         LogMessage('NW3: Error! Bad serial in request #'+inttostr(tag));
         state:=csDisconnected;
         Signal('NET\Conn3\ConnectionBroken',2);
         exit;
        end;
        // messages received
        sa:=SplitA(#13#10,response);
        LogMessage('NW3: '+IntToStr(length(sa))+' messages received from request #'+inttostr(tag));
        for i:=0 to length(sa)-1 do begin
         // Здесь был баг, декодировать нужно правильно
         sa[i]:=UnEscape(sa[i]);
{         sa[i]:=StringReplace(sa[i],'\n',#13#10,[rfReplaceAll]);
         sa[i]:=StringReplace(sa[i],'\\','\',[rfReplaceAll]);}
         inQueue[inPos]:=sa[i];
         t:=inPos+lastTag*1000;
         inQueueTag[inPos]:=t;
         Signal('Net\Conn3\DataReceived',t);
         inPos:=(inPos+1) and 63;
         lastTag:=(lastTag+1) and $FFFF;
        end;
       end else
        LogMessage('NW3: empty poll #'+inttostr(tag));
       Sleep(20);
       activePollRequest:=0;
      end;
      if tag=activePostRequest then begin
       // Нужно либо обнулить activePostRequest (чтобы разрешить последующую отправку данных)
       // либо перевыслать запрос
       if (response<>'OK') and (response<>'IGNORED') then begin
        LogMessage('NW3: bad response to request '+inttostr(tag)+': '+response);
        if (Now>lastPostSent+120/86400) or    // соединение считать разорванным если не удалось доставить пакет за 120 секунд
           (httpStatus>400) then begin // доставка невозможна
         LogMessage('NW3: delivery timeout');
         activePostRequest:=0;
         state:=csDisconnected;
         Signal('NET\Conn3\ConnectionBroken',3);
         exit;
        end;
        DelayedSignal('HTTP_Event\ResendPost',3000); // перевыслать через 3 секунды
       end else
        activePostRequest:=0;
      end;
    end;
   end; // Case
  end; // Success
 end;

function StrToHex(st:string):string;
 const
  hex:array[0..15] of char=('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
 var
  i:integer;
  b:byte;
 begin
  SetLength(result,length(st)*2);
  for i:=1 to length(st) do begin
   b:=byte(st[i]);
   result[i*2-1]:=hex[b shr 4];
   result[i*2]:=hex[b and 15];
  end;
 end;

// Формирует тело запроса из очереди исходящих сообщений и отправляет запрос
procedure SendMessages(server:string);
 var
  i,size,count:integer;
  msgs:array[1..10] of integer;
  query,boundary,sign:string;
  names,values:StringArr;
  cType:TContentType;
 begin
  // Тут нужно определиться каким способом отправлять сообщения
  size:=0; count:=0;
  while (outStart<>outFree) and (count<10) do begin // больше 10 сообщений за раз не отправляем
   inc(count);
   inc(size,length(outQueue[outStart]));
   msgs[count]:=outStart;
   outStart:=(outStart+1) and 255;
  end;
  // Старый код! В новом - только POST
{  if size<300 then begin // отправим методом GET
   query:=server+'/'+inttostr(userID)+'?';
   data:='';
   for i:=1 to count do begin
    query:=query+chr(64+i)+'='+UrlEncode(outQueue[msgs[i]])+'&';
    data:=data+outQueue[msgs[i]];
   end;
   query:=query+'Z='+ShortMD5(data+MD5pwd);
   HTTPRequest(query,'','HTTP_Event');
  end else begin // отправим методом POST
   SetLength(names,count+1);
   SetLength(values,count+1);
   data:='';
   for i:=1 to count do begin
    names[i]:=chr(64+i);
    values[i]:=outQueue[msgs[i]];
    data:=data+values[i];
   end;
   names[0]:='Z';
   values[0]:=ShortMD5(data+MD5pwd);
   query:=FormatPostBody(names,values,ctAuto);
   HTTPRequest(server+'/'+inttostr(userID),query,'HTTP_Event');
  end;}
  if count>0 then begin
   SetLength(names,count+1);
   SetLength(values,count+1);
   query:='';
   for i:=1 to count do begin
    names[i]:=''; values[i]:=outQueue[msgs[i]];
    query:=query+values[i];
   end;
   values[0]:=ShortMD5(query+MD5pwd);
  end;
  lastPostData:='';
  if size>4000 then cType:=ctBinary
   else cType:=ctText;
  inc(serial);
  sign:=ShortMD5(IntToStr(userID)+IntToStr(serial)+MD5pwd);
  lastPostData:=FormatPostBody(names,values,cType);
  lastPostType:=cType;
  lastPostURL:=server+Format('/%d-%d-%s',[userID,serial,sign]);
  activePostRequest:=HTTPRequest(lastPostURL,lastPostData,'HTTP_Event',4000,cType);
  lastPostSent:=Now;
 end;

procedure PollRequest(server:string);
 begin
  inc(serial);
  lastPollURL:=inttostr(userID)+'-'+inttostr(serial);
  if userID<10000 then lastPollURL:=lastPollURL+'-'+ShortMD5(inttostr(userID)+inttostr(serial)+MD5pwd);
  lastPollURL:=server+'/'+lastPollURL;
  lastPollSent:=Now;
  activePollRequest:=HTTPRequest(lastPollURL,'','HTTP_Event');
 end;

{ TMainThread }
procedure TMainThread.Execute;
 begin
  RegisterThread('NW3');
  userID:=0;
  activePollRequest:=0;
  activePostRequest:=0;
  serial:=0;
  MD5pwd:=ShortMD5(password);
  LogMessage('NW3: HTTP thread started');
  SetEventHandler('HTTP_Event',EventHandler,emQueued);
  try
   state:=csNone;
   // Главный цикл
   repeat
    // simple login
    if state=csNone then begin
     state:=csConnecting; // waiting for UserID
     HTTPrequest(server+'/login?'+IntToStr(random(100000)),'','HTTP_Event');
    end;

    // Advanced login
    if (state=csConnected) and (password<>'') and (userID>0) then begin
     state:=csLogging; // waiting for auth userID
     HTTPRequest(server+'/login?A='+inttostr(userID)+'&B='+UrlEncode(login)+
        '&C='+UrlEncode(clientInfo)+
        '&D='+ShortMD5(inttostr(userID)+login+clientInfo+MD5pwd),'','HTTP_Event');
    end;

    if state=csLogged then begin
     MyServis.EnterCriticalSection(critSect);
     try
      // Send messages (if any)
      if (activePostRequest=0) and (outStart<>outFree) then SendMessages(server);
      // poll request
      if activePollRequest=0 then PollRequest(server);
     finally
      MyServis.LeaveCriticalSection(critSect);
     end;
    end;

    sleep(mainLoopDelay);
    HandleSignals;
   until terminated;
   LogMessage('NW3: Session terminated '+inttostr(activePollRequest)+':'+inttostr(activePostRequest));
   if activePollRequest<>0 then CancelRequest(activePollRequest);
   if activePostRequest<>0 then CancelRequest(activePostRequest);

   // Отключение
   if (UserID>0) and (userID<10000) and (state=csLogged) then begin
    if logoutInfo<>'' then logoutInfo:='&C='+EncodeHex(logoutInfo);
    HTTPRequest(server+'/logout?A='+IntToStr(userID)+'&B='+ShortMD5(inttostr(userID)+MD5pwd)+logoutInfo,'','HTTP_Event');
    sleep(200); // wait some time so the notification request at least sent
   end;

   state:=csDisconnected;
   DoneHTTPrequests; // может не надо? - сессий может быть много!
  except
   on e:exception do begin
    state:=csDisconnected;
    ForceLogMessage('NET3 Error: '+ExceptionMsg(e));
    NW3ErrorMessage:=ExceptionMsg(e);
    Signal('NET\Conn3\Error');
   end;
  end;
  mainThread:=nil; // no need to free, just to inform
  LogMessage('NW3: net thread done');
  UnregisterThread;
 end;

procedure TerminateIfNeeded;
 var
  c:integer;
 begin
  if mainThread<>nil then begin
   ForceLogMessage('Enforced disconnect');
   Disconnect;
   c:=1000;
   repeat
    sleep(1);
    dec(c);
   until (mainThread=nil) or (c=0);
   if c=0 then ForceLogMessage('NW3: Fatal - mainThread<>nil!');
   sleep(1);
  end;
  RemoveEventHandler(EventHandler);
 end;

procedure Connect(server,login,password,clientinfo:string);
 begin
  TerminateIfNeeded;
  outStart:=0; outFree:=0;
  inPos:=0; lastTag:=1;
  failedRequests:=0;
  mainThread:=TMainThread.Create(true);
  mainThread.server:=server;
  mainThread.login:=login;
  mainThread.password:=password;
  mainThread.clientInfo:=clientInfo;
  mainThread.FreeOnTerminate:=true;
  mainThread.Resume;
 end;

// Создание аккаунта
procedure EventHandler2(event:TEventStr;tag:TTag);
 var
  code:integer;
  response:AnsiString;
 begin
  code:=GetRequestResult(tag,response);
  if code<>httpStatusCompleted then begin
   ForceLogMessage('NW3 HTTP failure: '+response);
   Signal('NET\Conn3\ConnectionFailed');
  end else begin
   // Success
   if pos('OK',response)=1 then begin
    LogMessage('NW3: account created!');
    Signal('NET\Conn3\AccountCreated');
   end else
   if pos('ERROR:',response)=1 then begin
    LogMessage('NW3: account failed - '+response);
    NW3ErrorMessage:=copy(response,8,length(response));
    Signal('NET\Conn3\AccountFailed');
   end else
    LogMessage('NW3: unrecognized response - '+response);
  end; // Success
 end;


procedure CreateAccount(server,login,password,name,extras:string);
 var
  query,data:string;
  b:byte;
  i:integer;
 begin
  RemoveEventHandler(EventHandler2);
  SetEventHandler('HTTP_Event2',EventHandler2,emInstant);
  query:=name+#9+login+#9+ShortMD5(password)+#9+extras;
  b:=47;
  for i:=1 to length(query) do begin
   query[i]:=char(byte(query[i]) xor b);
   inc(b,39);
  end;
  data:='A='+StrToHex(query);
  HTTPRequest(server+'/newacc',data,'HTTP_Event2',0,ctUrlencoded);
 end;

procedure Disconnect(extraInfo:string='');
 begin
  MyServis.EnterCriticalSection(critSect);
  try
  ForceLogMessage('NW3: Disconnect');
  if mainThread<>nil then begin
//    state:=csDisconnecting;
    mainThread.logoutInfo:=extraInfo;
    mainThread.Terminate;
  end;
  finally
    MyServis.LeaveCriticalSection(critSect);
  end;
 end;

function Connected:boolean;
 begin
  result:=state in [csConnected,csLogged];
 end;

procedure SendData(data:array of const);
 var
  i:integer;
  sa:StringArr;
 begin
//  if not connected then raise EWarning.Create('NW3: not connected');
  if not (state in [csConnected,csLogged]) then exit;
  MyServis.EnterCriticalSection(critSect);
  try
   if (outFree+1) and 255=outStart then
    raise EWarning.Create('NW3 outbox queue overflow!');
   SetLength(sa,length(data));
   for i:=0 to length(data)-1 do
    sa[i]:=VarToStr(data[i]);
   LogMessage('Send: '+copy(join(sa,'|'),1,200));
   outQueue[outFree]:=combine(sa,'~','_');
   outFree:=(outFree+1) and 255;
  finally
   MyServis.LeaveCriticalSection(critSect);
  end;
 end;

procedure GetNetMessage(handle:integer;var msg:TNetMessage);
 var
  i,idx:integer;
 begin
  idx:=handle mod 1000;
  if (idx>=length(inQueue)) or (inQueueTag[idx]<>handle) then
   raise EWarning.Create('Invaid handle: '+inttostr(handle));
  StringArr(msg.values):=Split('~',inQueue[idx],'_');
  msg.index:=0;
 end;

{ TMessage }

function TNetMessage.Int(idx: integer): integer;
 begin
  if (idx>=0) and (idx<length(values)) then
   result:=StrToIntDef(values[idx],0)
  else
   result:=0;
 end;

function TNetMessage.Empty:boolean;
begin
 result:=index>=length(values);
end;

function TNetMessage.NextInt: integer;
 begin
  if index<length(values) then result:=StrToIntDef(values[index],-1)
   else result:=-1;
  inc(index);
 end;

function TNetMessage.NextStr: string;
 begin
  if index<length(values) then result:=values[index]
   else result:='';
  inc(index);
 end;

initialization
 InitCritSect(critSect,'Netw3',40);
finalization
 TerminateIfNeeded;
 DeleteCritSect(critSect);
end.
