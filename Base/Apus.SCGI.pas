// SimpleCGI framework
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.SCGI;
interface
 uses Apus.Types, Apus.Database, Apus.Structs, SysUtils;
 const
  MAX_REQUESTS = 1000;
  MAX_RQUEUE = 1023; // 2^n-1
  MAX_HANDLERS = 200;
  CRLF = #13#10;
  MAX_COMET_DURATION = 15000; // don't handle any request longer than 15 sec
  COMET_INTERVAL = 250; // retry to process pending request after 0.25 sec

  // Time constants
  MINUTE = 1/1440;
  SECOND = 1/86400;
 var
  // Global options
  PORT:integer=9000;
  WORKER_THREADS:integer=3;
  local_IP:cardinal=$7F000001; // localhost

  rootDir:string; // root dir for site "/" path (ends with '\')
  URIprefix:String8; // this prefix is removed from URI before request is processed

 threadvar
  db:TDataBase; // worker's database connection
  templates:THash; // Global site templates (content). Each thread has own copy of template collection
  temp:THash; // Tempopary values/templates. Cleared/initialized for each request
  workerID:integer;
  // Per-request values
  requestIdx:integer;
  headers:String8;    // заголовки из SCGI-запроса (as-is, разделены #0)
  requestBody:String8;
  uri,query:String8; // Запрос (до знака ? и после него)
  clientIP:String8;  // remote IP address
  clientCountry:String8;
  httpMethod:String8;   // 'GET', 'POST'
  setCookies:String8; // Сюда заносятся куки, которые нужно установить юзеру (используется в FormatHeaders)
  userID:integer; // обнуляется при каждом запросе, служит для определения авторизации юзеров (ID профиля)
  uploadedFileName:String8; // при вызове Param() для поля с файлом - сюда заносится исходное имя загруженного файла

  // Язык клиента (xx) - определяется по куке, либо по заголовкам
  clientLang:String8;

 type
  // Page builder function type
  TRequestHandler=function:String8; stdcall;

  // Exceptions for standard HTTP response codes
  E200=class(Exception) end; // Normal response returned via exception mechanism
  E403=class(Exception) end; // Forbidden
  E404=class(Exception) end; // Not found
  E405=class(Exception) end; // Method not allowed
  E429=class(Exception) end; // Too many requests
  E500=class(Exception) end; // Internal server error

 var
  timerProc:TRequestHandler; // this handler is called with 1 second interval from any worker
  initProc:TRequestHandler; // this handler is called before handling any other requests

 // Add page handler (with or without '/', i.e. pass index.cgi for '/index.cgi') (case insensitive)
 // Use xxx* to match first part of URI
 // Use '*' to set default handler
 procedure AddHandler(uri:String8;handler:TRequestHandler);

 // Load configuration
 procedure Initialize;

 // Run main loop
 procedure RunServer;

 // Use global critsection to access global variables
 procedure GlobalLock;
 procedure GlobalUnLock;

 // Aux functions for use from request handlers
 // Extract value of parameter [name] from [headers] (name is case insensitive)
 function Param(name:String8):String8;
 function IntParam(name:String8;default:integer=-1):integer;
 // Extract value of cookie [name] from [headers] (name is case insensitive)
 function Cookie(name:String8):String8;
 // Установить куку (будет отправлено при формировании заголовков через FormatHeaders)
 procedure SetCookie(name,value:String8;permanent:boolean;httpOnly:boolean=true);
 procedure DeleteCookie(name:String8);
 // Extract value of SCGI request header [name] from [headers] (name is case-insensitive)
 function GetHeader(headers,name:String8):String8;

 // Build page text based on global and local templates
 // template can be name (#NAME) or plain text to be translated
 function BuildTemplate(template:String8):String8;

 // Combine values into response header
 function FormatHeaders(contentType:String8;status:String8='';other:String8=''):String8;

 // Build headers for Error response
 function FormatError(code:integer;msgToLog:String8):String8;

 // Build headers for redirection
 function FormatRedirect(url:String8;extra:String8=''):String8;

 // Ensure that string is number
 function MakeNumber(st:String8):String8;

 // yyyymmddhhnnss
 function CurrentTimeStamp:String8;
 function ParseTimeStamp(timestamp:String8):TDateTime;

 // Add task (request, async job) to process (st=url, like received)
 procedure AddTask(task:String8;data:String8='');

 // Execute DB query in a queued task
 procedure PostQuery(query:String8;params:array of const);

 // Test request that output HTTP headers
 function ListHeaders:String8; stdcall;

implementation
 uses {$IFDEF MSWINDOWS}Windows, WinSock2,{$ELSE}Sockets, {$ENDIF}
    Apus.MyServis, Classes, Apus.ControlFiles, Apus.Logging, Apus.GeoIP;
 type
  // Worker thread
  TWorker=class(TThread)
   workerID:integer;
   reloadTemplates:boolean;
   currentRequest:integer;
   constructor Create(id:integer);
   procedure Execute; override;
  end;

  TRequestStatus=(
   rsFree=0,        // free slot
   rsReading=1,     // receiving request
   rsReceived=2,    // request received, but not yet processed. Worker should process it
   rsProcessing=3,  // request is being processed by a worker
   rsPending=4,     // request defered: can't be completed now, must be processed again later
   rsCompleted=5    // request processed and response is ready to be sent to the client
  );

  TRequest=record
   status:TRequestStatus;
   timestamp:int64; // when status changed last time? (MyTickCount used)
   executionTime:integer;  // total time spent (including pending/waiting) to complete request
   socket:TSocket;
   request,response:String8;
   contentLength,totalLength,bytesSent:integer;
   headers,body:String8;
   timeToProcess:int64; // don't handle before this time (MyTickCOunt)
  end;

  THandler=record
   uri:String8;    // always uppercase
   wildcard:integer;  // URI starts or ends with '*' (1 - prefix, 2 - suffix)
   handler:TRequestHandler;
  end;

 var
  ctl:TControlFile;
  critSect:TMyCriticalSection;

  mainSock:TSocket;
  requests:array[1..MAX_REQUESTS] of TRequest; // all requests
  rHash:TSimpleHash; // socket->request num

  workers:array[1..20] of TWorker;
  liveWorkers:integer;

  // Read/Send buffer is here, not on stack
  buffer:array[0..100000] of byte; // Actual request can be larger
  reserve:array[0..10000] of byte;

  // Active request queue
  queue:array[0..MAX_RQUEUE] of integer;
  qStart,qEnd:integer;

  // Page handlers
  handlers:array[0..MAX_HANDLERS] of THandler;
  hCount:integer;

  loopCounter:cardinal;
  needExit:boolean=false;

  mostRecentTemplate:TDateTime;
  lastTimerTime:int64; // when timer proc called last time

  startTime:TDateTime;
  requestsProcessed:int64;

 procedure GlobalLock;
  begin
   critSect.Enter;
  end;

 procedure GlobalUnLock;
  begin
   critSect.Leave;
  end;


// -------------------------------------------------------
// AUX CGI functions
// -------------------------------------------------------

 function Param(name:String8):String8;
  var
   p,e:integer;
   params,cType:String8;
   function ExtractMultipartValue:String8;
    var
     boundary,fHeaders:String8;
     i,p,q:integer;
    begin
     result:='';
     i:=pos('boundary=',cType);
     if i>0 then boundary:='--'+copy(cType,i+9,length(cType));
     p:=PosFrom(boundary,requestBody);
     if p=0 then exit;
     repeat
      i:=p+length(boundary)+2; // первый байт заголовка параметра
      q:=PosFrom(#13#10#13#10,requestBody,i);
      if q=0 then break;
      p:=PosFrom(boundary,requestBody,q); // конец данных
      if p=0 then break;
      fHeaders:=copy(requestBody,i,q-i);
      q:=q+4;
      if (p-q-2>=0) and (PosFrom('name="'+name+'"',fHeaders,1,true)>0) then begin
       result:=copy(requestBody,q,p-q-2);
       i:=Pos('filename="',fheaders);
       if i>0 then begin
        q:=PosFrom('"',fheaders,i+10);
        if q>=i+10 then uploadedFileName:=copy(fHeaders,i+10,q-i-10)
         else uploadedFileName:='';
       end;
       exit;
      end;
     until p=0;
    end;
  begin
   result:='';
   params:='';
   if httpMethod='GET' then params:=query;
   if (httpMethod='POST') then begin
    cType:=GetHeader(headers,'CONTENT_TYPE');
    if PosFrom('application/x-www-form-urlencoded',cType,1,true)>0 then params:=requestBody;
    if PosFrom('multipart/form-data',cType,1,true)>0 then begin
     result:=ExtractMultipartValue;
     exit;
    end;
   end;
   p:=pos(lowercase(name)+'=',lowercase(params));
   if p>0 then begin
    p:=p+length(name)+1;
    e:=p;
    while (e<=length(params)) and (params[e]<>'&') do inc(e);
    result:=copy(params,p,e-p);
    result:=UrlDecode(result);
   end;
  end;

 function IntParam(name:String8;default:integer=-1):integer;
  begin
   result:=StrToIntDef(Param(name),default);
  end;

 function Cookie(name:String8):String8;
  var
   p,e,i:integer;
   cookies,items:StringArr;
   st:String8;
  begin
   result:='';
   name:=UpperCase(name);
   cookies:=split(';',GetHeader(headers,'HTTP_COOKIE'));
   for st in cookies do begin
    items:=split('=',st);
    if UpperCase(chop(items[0]))=name then begin
     result:=chop(items[1]);
     exit;
    end;
   end;
  end;

 procedure SetCookie(name,value:String8;permanent:boolean;httpOnly:boolean=true);
  begin
   setCookies:=setCookies+'Set-Cookie: '+name+'='+value+'; Path=/';
   if permanent then setCookies:=setCookies+'; Expires=30-Dec-2098 00:00:00 GMT';
   if httpOnly then setCookies:=setCookies+'; httponly';
   setCookies:=setCookies+#13#10;
  end;

 procedure DeleteCookie(name:String8);
  begin
   setCookies:=setCookies+'Set-Cookie: '+name+'=; Expires=31-Dec-2000 00:00:00 GMT'#13#10;
  end;

 function GetHeader(headers,name:String8):String8;
  var
   p,e:integer;
  begin
   result:='';
   p:=pos(UpperCase(name)+#0,headers);
   if p>0 then begin
    p:=p+length(name)+1;
    e:=p;
    while (e<=length(headers)) and (headers[e]<>#0) do inc(e);
    result:=copy(headers,p,e-p);
   end;
  end;

 function MakeNumber(st:String8):String8;
  var
   i:integer;
  begin
   for i:=1 to length(st) do
    if not (st[i] in ['0'..'9','-','.']) then st[i]:=' ';
   result:=StringReplace(st,' ','',[rfReplaceAll]);
  end;

 function CurrentTimeStamp:String8;
  begin
   result:=FormatDateTime('yyyymmddhhnnss',NowGMT);
  end;

 function ParseTimeStamp(timestamp:String8):TDateTime;
  var
   year,month,day,hour,min,sec:integer;
  begin
   try
    year:=StrToInt(copy(timestamp,1,4));
    month:=StrToInt(copy(timestamp,5,2));
    day:=StrToInt(copy(timestamp,7,2));
    hour:=StrToInt(copy(timestamp,9,2));
    min:=StrToInt(copy(timestamp,11,2));
    sec:=StrToInt(copy(timestamp,13,2));
    result:=EncodeDate(year,month,day)+EncodeTime(hour,min,sec,0);
   except
    result:=0;
   end;
  end;

 // -------------------------------------------------------
 // Templates-related functions
 // -------------------------------------------------------

 function FormatHeaders(contentType:String8;status:String8='';other:String8=''):String8;
  begin
   result:='';
   if contentType<>'' then result:=result+'Content-type: '+contentType+#13#10;
   if status<>'' then result:=result+'Status: '+status+#13#10;
   if setCookies<>'' then result:=result+setCookies;
   if other<>'' then result:=result+other+#13#10;
   result:=result+#13#10;
  end;

 function FormatRedirect(url:String8;extra:String8=''):String8;
  begin
   url:='Location: '+url;
   if extra<>'' then url:=url+#13#10+extra;
   result:=FormatHeaders('','303 See Other',url);
  end;

 function FormatError(code:integer;msgToLog:String8):String8;
  begin
   LogMsg('ErrorCode '+IntToStr(code)+': '+msgToLog,logNormal);
   result:=FormatHeaders('text/html',IntToStr(code));
   case code of
    403:result:=result+'<h3>403 Forbidden</h3>';
    404:result:=result+'<h3>404 Not Found</h3>';
    405:result:=result+'<h3>405 Method not allowed</h3>';
    429:result:=result+'<h3>429 Too many requests</h3>You''ve sent too many requests. Please wait and try again.';
    500:result:=result+'<h3>500 Internal Server Error</h3>';
   end;
  end;

 // Apply templates to a String8
 function TranslateString(st:String8):String8;
  var
   i,j,k,p,q,r,start,after,action:integer;
   key,subst,tmp,pName,pValue:String8;
   keep,bad:boolean;
   sa:StringArr;
  begin
   st:=st+' '; // Terminator
   // Pass 1 - translate using locals
   if temp.count>0 then begin
    p:=1; start:=0; // указатель на начало слова (первый символ после $)
    while p<=length(st) do begin
     if (start>1) and not (st[p] in ['A'..'Z','0'..'9','_']) and (p>start) then begin
      key:=copy(st,start,p-start);
      subst:=temp.Get(key);
      if subst<>'' then begin
       subst:=TranslateString(subst);
       after:=length(st)-p+1;
       tmp:=copy(st,1,start-2)+subst+copy(st,p,after);
       st:=tmp;
       p:=start-2+length(subst);
      end;
      start:=0;
     end;
     if (p<length(st)) and (st[p]='$') and (st[p+1] in ['A'..'Z']) then start:=p+1;
     inc(p);
    end;
   end;
   // Pass 2 - translate using global templates
   p:=1; start:=0;
   while p<=length(st) do begin
    if (start>1) and not (st[p] in ['A'..'Z','0'..'9','_']) and (p>start) then begin
     key:=copy(st,start,p-start);
     // Any parameters?
     if st[p]='{' then begin
      // если после имени идёт скобка, то ищем в скобках строки вида A=XXX;B=YYY, и устанавливаем temp{A}=XXX и т.д.
      q:=p; bad:=true;
      while (q<=length(st)) and (st[q]<>'}') do begin
       if st[q]='=' then bad:=false;
       if st[q]=';' then bad:=true;
       inc(q);
      end;
      if q=length(st) then bad:=true;
      if not bad then begin
       sa:=split(';',copy(st,p+1,q-p-1));
       for k:=0 to high(sa) do begin
        r:=pos('=',sa[k]);
        pName:=copy(sa[k],1,r-1);
        pValue:=copy(sa[k],r+1,length(sa[k]));
        temp.Put(pName,pValue,true);
       end;
       p:=q+1;
      end;
     end;
     // First try localized item
     subst:=templates.Get(key+'_'+clientLang);
     if subst='' then // otherwise try generic
       subst:=templates.Get(key);
     if subst<>'' then subst:=TranslateString(subst);
     after:=length(st)-p+1;
     tmp:=copy(st,1,start-2)+subst+copy(st,p,after);
     st:=tmp;
     p:=start-2+length(subst);
     start:=0;
    end;
    if (p<length(st)) and (p>0) and (st[p]='$') and (st[p+1] in ['A'..'Z']) then start:=p+1;
    inc(p);
   end;
   // Pass 3: conditional blocks
   p:=1; start:=0;
   while p<=length(st) do begin
    if (start>=1) and (st[p]='>') and (p>start+5) then begin
     key:=copy(st,start+1,p-start-1);
     action:=0;
     tmp:=key;
     if pos('IF_',key)=1 then action:=1;
     if pos('IFNOT_',key)=1 then action:=-1;
     if action=1 then delete(key,1,3);
     if action=-1 then delete(key,1,6);
     j:=pos('</'+tmp+'>',st);
     if (action<>0) and (j>start) then begin
      subst:=temp.Get(key);
      keep:=((subst='') or (subst='False')) xor (action>0);
      if keep then begin
       delete(st,j,length(tmp)+3);
       delete(st,start,p-start+1);
      end else
       delete(st,start,j-start+length(tmp)+3);
      p:=start;
      start:=0;
     end;
    end;
    if (p<length(st)-6) and (st[p]='<') and (st[p+1]='I') and (st[p+2]='F') then start:=p;
    inc(p);
   end;
   SetLength(st,length(st)-1); // remove terminator
   result:=st;
  end;

 function BuildTemplate(template:String8):String8;
  begin
   EnterCriticalSection(critSect);
   try
   if (length(template)>1) and (template[1]='#') then begin
    delete(template,1,1);
    if temp.count>0 then result:=temp.Get(template)
     else result:='';
    if result='' then result:=templates.Get(template);
   end else
    result:=template;
   result:=TranslateString(result);
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 // Возможны 2 варианта:
 // 1) файл целиком - один шаблон, имя шаблона = имя файла (uppercase)
 // 2) Файл содержит несколько шаблонов, т.е. содержит строки вида #NAME:
 procedure LoadTemplatesFromFile(fname:String8);
  var
   f:text;
   st,name,value:String8;
   i,j,p:integer;
   fl,firstName:boolean;
  begin
   assign(f,fname);
   SetTextCodePage(f,CP_UTF8);
   reset(f);
   name:=UpperCase(ExtractFileName(fname));
   value:='';
   firstName:=true;
   while not eof(f) do begin
    readln(f,st);
    // Comments?
    if (length(st)>2) and
       (st[1]='/') and (st[2]='/') then continue;
    p:=pos(':',st);
    if (length(st)>2) and (st[1]='#') and (p>2) then begin
     if (name<>'') and (value<>'') {and not firstName} then begin
      templates.Put(name,value);
      name:='';
      firstName:=false;
     end;
     name:=UpperCase(copy(st,2,p-2));
     value:='';
     if length(st)>p then value:=copy(st,p+1,length(st));
     fl:=false;
     for i:=1 to length(value) do
      if value[i]>' ' then begin
       fl:=true; // единственная строка, игнорировать всё, что дальше
       break;
      end;
     if not fl then value:=''; // no characters in value String8
    end else
     // not new template
     if not fl then
      value:=value+st+#13#10;
   end;
   if name<>'' then
    templates.Put(name,value);
   close(f);
  end;

 procedure LoadTemplates;
  var
   sr:TSearchRec;
   r,p:integer;
   date,fileDate:TDateTime;
  begin
   EnterCriticalSection(critSect); // в принципе это больше не нужно!
   try
   r:=FindFirst('templates\*.*',faArchive,sr);
   while r=0 do begin
    // Load templates from file and update max filedate
    mostRecentTemplate:=max2d(double(mostRecentTemplate),FileDateToDateTime(sr.Time));
    LoadTemplatesFromFile('templates\'+sr.name);
    r:=FindNext(sr);
   end;
   SysUtils.FindClose(sr);
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 procedure CheckForTemplatesUpdate;
  var
   sr:TSearchRec;
   r,i:integer;
  begin
   r:=FindFirst('templates\*.*',faArchive,sr);
   while r=0 do begin
    if FileDateToDateTime(sr.Time)>mostRecentTemplate then begin
     LogMsg('Templates changed, reloading...',logImportant);
     for i:=1 to WORKER_THREADS do
      if workers[i]<>nil then workers[i].reloadTemplates:=true;
     break;
    end;
    r:=FindNext(sr);
   end;
   SysUtils.FindClose(sr);
  end;

// ---------------------------------------------------------------
// Internal AUX functions
// ---------------------------------------------------------------

 procedure qPut(r:integer);
  begin
   EnterCriticalSection(critSect);
   try
    queue[qEnd]:=r;
    qEnd:=(qEnd+1) and MAX_RQUEUE;
    if qStart=qEnd then raise EError.Create('Queue overflow!');
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 function qGet:integer;
  begin
   EnterCriticalSection(critSect);
   try
   if qStart<>qEnd then begin
    result:=queue[qStart];
    qStart:=(qStart+1) and MAX_RQUEUE;
   end else
    result:=-1;
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 {$IFDEF MSWINDOWS}
  // many routines have different declaration in different WinSock2 import units
  {$IFDEF DELPHI}
  function bind(s: TSocket; name: PSockAddr; namelen: Integer): Integer; stdcall; external 'ws2_32.dll';
  {$ENDIF}
  {$IFDEF FPC}
  function WSAAccept(s:TSocket; addr:PSockAddr; addrlen:PLongint; lpfnCondition:LPCONDITIONPROC; dwCallbackData:DWORD ):TSocket; stdcall; external 'ws2_32.dll' name 'WSAAccept';
  {$ENDIF}
 {$ENDIF}


// ---------------------------------------------------------------
// Main thread internal functions
// ---------------------------------------------------------------

 procedure InitMainSocket;
  var
   addr:SOCKADDR_IN;
   res:integer;
   arg:cardinal;
  begin
   // create main socket
   mainSock:=socket(PF_INET,SOCK_STREAM,IPPROTO_IP);
   if MainSock=INVALID_SOCKET then
    raise EError.Create('Invalid socket: '+inttostr(WSAGetLastError));
   // bind
   addr.sin_family:=PF_INET;
   addr.sin_port:=htons(PORT);
   addr.sin_addr.S_addr:=htonl(local_IP);

   res:=bind(MainSock,PSockAddr(@addr),sizeof(addr));
   if res<>0 then raise EError.Create('Bind failed: '+inttostr(WSAGetLastError));

   arg:=1;
   if ioctlsocket(MainSock,longint(FIONBIO),arg)<>0 then
    raise EError.Create('Cannot make non-blocking socket');

   res:=listen(MainSock,SOMAXCONN);
   if res<>0 then raise EError.Create('Listen returned error '+inttostr(WSAGetLastError));
  end;

 procedure TryToExtractContentLength(var r:TRequest);
  var
   p,start,size:integer;
  begin
   with r do begin
    // Check if headers are received
    if length(request)>6 then begin
      p:=pos(':',request);
      if (p>0) and (p<=6) then
        size:=StrToIntDef(copy(request,1,p-1),-1);
      if (size>=0) and (length(request)>=size+p) then begin
        // Headers received
        start:=p;
        headers:=copy(request,p+1,size);
        p:=pos('CONTENT_LENGTH',request);
        if p>0 then begin
          inc(p,15);
          contentLength:=0;
          while request[p] in ['0'..'9'] do begin
            contentLength:=contentLength*10+(ord(request[p])-ord('0'));
            inc(p);
          end;
          totalLength:=start+size{+1}+contentLength;
        end else begin
          LogMsg('Invalid request: '+request,logWarn);
          status:=rsFree;
          closesocket(socket);
        end;
      end;
    end;
   end;
  end;

 // Read data from socket to request buffer and check if a complete response is received
 // (always called inside critsect)
 procedure ReadData(s:TSocket);
  var
   i,res,size,p,start:integer;
   t:int64;
  begin
   t:=MyTickCount;
   EnterCriticalSection(critSect);
   try
   res:=recv(s,buffer,sizeof(buffer),0);
   if res>=0 then begin
    for i:=1 to high(requests) do
     with requests[i] do
      if socket=s then begin
       if res>0 then begin
         LogMsg('Request %d: received %d bytes',[i,res],logInfo);
         // copy received data
         size:=length(request);
         SetLength(request,size+res);
         move(buffer,request[size+1],res);
         // Check if request is completely received
         // Content-length not yet determined?
         if contentLength<0 then TryToExtractContentLength(requests[i]);
         if contentLength>=0 then begin
           // Content-length is already known
           if length(request)>=totalLength then begin
             LogMsg('Request %d ready: %d >= %d',[i,length(request),totalLength],logDebug);
             body:=copy(request,length(request)-contentLength+1,contentLength);
             request:=''; // already parsed, so not needed anymore
             status:=rsReceived;
             timestamp:=MyTickCount;
             timeToProcess:=0;
             qPut(i);
           end;
         end
       end else begin // connection closed (aborted)
         status:=rsFree;
       end;
       break; // don't look to other requests
      end;
   end else begin
     LogMsg('RECV error: '+inttostr(WSAGetLastError),logWarn);
     for i:=1 to high(requests) do
      with requests[i] do
       if socket=s then status:=rsFree;
     CloseSocket(s);
   end;
   finally
    LeaveCriticalSection(critSect);
   end;
   if MyTickCount>t+10 then LogMsg('WARN: long socket reading',logWarn);
  end;

 // Записывает данные в сокет
 procedure WriteData(s:TSocket);
  var
   i,res,size:integer;
   t:int64;
  begin
   t:=MyTickCount;
   EnterCriticalSection(critSect);
   try
   for i:=1 to High(requests) do
    if requests[i].socket=s then
     with requests[i] do begin
      size:=length(response)-bytesSent;
      if size>100000 then size:=100000;
      move(response[bytesSent+1],buffer,size);
      LogMsg('Sending %d bytes to #%d',[size,i],logInfo);
      res:=send(s,buffer,size,0);
      if res=SOCKET_ERROR then begin
       LogMsg('Send error: '+inttostr(WSAGetLastError),logWarn);
       CloseSocket(s);
       status:=rsFree;
       LogMsg('Socket closed',logInfo);
      end else begin
       inc(bytesSent,res);
       if bytesSent=length(response) then begin
        // Complete
        CloseSocket(s);
        status:=rsFree;
        LogMsg('Socket closed',logInfo);
       end;
      end;
      break;
     end;
   finally
    LeaveCriticalSection(critSect);
   end;
   if MyTickCount>t+10 then LogMsg('WARN: long socket writing',logWarn);
  end;

 var
  lastAcceptTime:int64=0; // last time when AcceptNewConnection was called

 function AcceptNewConnection:boolean;
  var
   s:TSocket;
   i,res:integer;
   addr:TSockAddr;
   addrLen:integer;
   t:int64;
  begin
    if (lastAcceptTime>0) and (MyTickCount>lastAcceptTime+40) then
      LogMsg('WARN! Long delay for Accept! '+inttostr(MyTickCount-lastAcceptTime));
    lastAcceptTime:=MyTickCount;
    t:=MyTickCount;
    result:=false;
    addrlen:=sizeof(addr);
    s:=WSAAccept(mainSock,@addr,@addrlen,nil,0);
    if s=INVALID_SOCKET then begin
       res:=WSAGetLastError;
       if (res<>WSAEWOULDBLOCK) and (res<>WSAECONNREFUSED) then
         Logmsg('ACCEPT failed with '+inttostr(res),logWarn);
    end else begin
      // Connection established
      EnterCriticalSection(critSect);
      try
      for i:=1 to High(requests) do
      with requests[i] do
       if status=rsFree then begin
         LogMsg('New connection: '+IntToStr(i),logInfo);
         if MyTickCount>t+20 then
          LogMsg('Long waiting for accepted connection! ',logWarn);
         socket:=s;
         status:=rsReading;
         request:=''; response:='';
         body:=''; headers:='';
         timestamp:=MyTickCount;
         executionTime:=0;
         contentLength:=-1; // not defined
         bytesSent:=0;
         result:=true;
         rHash.Put(s,i);
         exit;
       end;
       LogMsg('ERROR! New connection not assigned!',logWarn);
      finally
       LeaveCriticalSection(critSect);
      end;
    end;
   if MyTickCount>t+20 then LogMsg('WARN: long AcceptNew '+inttostr(MyTickCount-t),logWarn);
  end;

 // Проверяет сокеты, ожидающие поступления запросов, на наличие поступивших данных
 procedure ReadIncomingData;
  var
   readSet:TFDSet;
   timeout:TTimeVal;
   i,res:integer;
  begin
    readset.fd_count:=0;
    // Choose up to 60 sockets
    for i:=1 to High(requests) do
     with requests[i] do
      if status=rsReading then begin
        readset.fd_array[readset.fd_count]:=socket;
        inc(readset.fd_count);
        if readset.fd_count>=60 then break;
      end;

    fillchar(timeout,sizeof(timeout),0);
    if readset.fd_count>0 then begin
      // Select sockets which can be read
      res:=select(0,@readset,nil,nil,@timeout);
      if res=SOCKET_ERROR then
        raise EWarning.Create('Select 1 error: '+inttostr(WSAGetLastError));

      if res>0 then
        for i:=0 to readset.fd_count-1 do
          ReadData(readset.fd_array[i]);
    end;
  end;

 procedure WriteOutgoingData;
  var
   i,res:integer;
   writeSet:TFDSet;
   timeout:TTimeVal;
  begin
    writeset.fd_count:=0;
    // Choose up to 60 sockets to send data
    for i:=1 to High(requests) do
     with requests[i] do
      if (status=rsCompleted) and (bytesSent<length(response)) and (socket<>0) then begin
        writeset.fd_array[writeset.fd_count]:=socket;
        inc(writeset.fd_count);
        if writeset.fd_count>=60 then break;
      end;

    fillchar(timeout,sizeof(timeout),0);
    if writeset.fd_count>0 then begin
      // Select sockets which can be used to send data
      res:=select(0,nil,@writeset,nil,@timeout);
      if res=SOCKET_ERROR then
        raise EWarning.Create('Select 2 error: '+inttostr(WSAGetLastError));
      if res>0 then
        for i:=0 to writeset.fd_count-1 do
          WriteData(writeset.fd_array[i]);
    end;
  end;

 procedure WriteStatusFile;
  var
   f:text;
   i:integer;
   uptime:int64;
  begin
   EnterCriticalSection(critSect);
   try
     assign(f,'status');
     rewrite(f);
     writeln(f,'Launched at ',FormatDateTime('d.mm.yyyy hh:nn:ss',startTime));
     uptime:=round((now-startTime)*86400000);
     writeln(f,'Uptime: '+FormatTime(uptime));
     writeln(f,'Requests: ',requestsProcessed);
     writeln(f,'RPS: ',requestsProcessed/(uptime/1000):5:2);
     writeln(f);

     for i:=1 to WORKER_THREADS do
      if workers[i]<>nil then
       writeln(f,Format('Thread %d is handling request %d',[i,workers[i].currentRequest]));

     writeln(f);
     for i:=1 to high(requests) do
      with requests[i] do
       if status<>rsFree then
        writeln(f,Format('',[]));

     writeln(f);
     write(f,'Queue: ');
     i:=qStart;
     while i<>qEnd do begin
       write(f,queue[i],' ');
       i:=(i+1) and MAX_RQUEUE;
     end;
     close(f);
   finally
     LeaveCriticalSection(critSect);
   end;
  end;

 procedure ExternalControl;
  begin
   try
    // should terminate?
    if FileExists('exit') then begin
      LogMsg('Exit requested!',logImportant);
      DeleteFile('exit');
      needExit:=true;
    end;

    // Fill status file
    if not FileExists('status') then WriteStatusFile;

   except
    on e:exception do LogMsg('Error in External Control: '+ExceptionMsg(e),logError);
   end;
  end;

 procedure AddFakeRequest(rType,data:String8);
  var
   i:integer;
  begin
    for i:=1 to high(requests) do
     if requests[i].status=rsFree then begin
      requests[i].status:=rsReceived;
      requests[i].timestamp:=MyTickCount;
      requests[i].request:=rType;
      requests[i].socket:=0;
      requests[i].body:=data;
      requests[i].timeToProcess:=0;
      qPut(i);
      exit;
     end;
  end;

 procedure CheckForTimer;
  begin
   if (@timerProc<>nil) and (MyTickCount>lastTimerTime+1000) then begin
    AddFakeRequest('TIMER','');
    lastTimerTime:=MyTickCount;
   end;
  end;

// ---------------------------------------------------------------
// Main interface functions
// ---------------------------------------------------------------

 procedure AddHandler(uri:String8;handler:TRequestHandler);
  begin
   EnterCriticalSection(critSect);
   try
    if uri='*' then begin
     handlers[0].uri:='*';
     handlers[0].handler:=handler; exit;
    end;
    handlers[hCount+1].wildcard:=0;
    if (uri[1]='*') or (uri[length(uri)]='*') then begin
     if uri[1]='*' then inc(handlers[hCount+1].wildcard,1);
     if uri[length(uri)]='*' then inc(handlers[hCount+1].wildcard,2);
     uri:=StringReplace(uri,'*','',[rfReplaceAll]);
    end else begin
     if uri[1]<>'/' then uri:='/'+uri;
    end;
    handlers[hCount+1].uri:=UpperCase(uri);
    handlers[hCount+1].handler:=handler;
    inc(hCount);
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 procedure Initialize;
  var
   WSAdata:TWSAData;
  begin
   // Logging
   if FileExists('scgi.log') then RenameFile('scgi.log','scgi.old');
   UseLogFile('scgi.log');
   LogCacheMode(true,false,false);
   InitLogging(10,'logs',logInfo);

   // Initialization
   InitCritSect(critSect,'SCGI');
   WSAStartup($0202, WSAData);
   // Load configuration
   ctl:=TControlFile.Create('config.ctl','');
   port:=ctl.GetInt('PORT',port);
   worker_threads:=ctl.GetInt('WorkerThreads',worker_threads);
   rootDir:=ctl.GetStr('rootDir',GetCurrentDir);
   URIprefix:=lowercase(ctl.GetStr('URIprefix',''));
   if LastChar(rootDir)<>'\' then rootDir:=rootDir+'\';
   DB_HOST:=ctl.GetStr('MySQL\Host',DB_HOST);
   DB_LOGIN:=ctl.GetStr('MySQL\Login',DB_LOGIN);
   DB_PASSWORD:=ctl.GetStr('MySQL\Password',DB_PASSWORD);
   DB_DATABASE:=ctl.GetStr('MySQL\Database',DB_DATABASE);
   LogMsg('SCGI Initialized',logImportant);
   qStart:=0; qEnd:=0;
   requestsProcessed:=0;
  end;

 procedure RunServer;
  var
   i,n,idx,res,addrLen:integer;
   arg:cardinal;
  begin
   startTime:=now;
   lastTimerTime:=MyTickCount;

   {$IF Declared(SetPriorityClass)}
   if not SetPriorityClass(GetCurrentProcess,NORMAL_PRIORITY_CLASS) then
    LogMsg('Failed to set process priority',logWarn);
   {$ENDIF}

   {$IF Declared(SetThreadPriority)}
   if not SetThreadPriority(GetCurrentThread,THREAD_PRIORITY_ABOVE_NORMAL) then
    LogMsg('Failed to set main thread priority',logWarn);
   {$ENDIF}

   InitGeoIP;
   InitMainSocket;

   // Init request storage
   for i:=1 to High(requests) do
    requests[i].status:=rsFree;
   rHash.Init(MAX_REQUESTS);

   // Start workers
   for i:=1 to WORKER_THREADS do begin
    workers[i]:=TWorker.Create(i);
    workers[i].FreeOnTerminate:=true;
    sleep(10);
   end;

   AddFakeRequest('INITIALIZE','');

   // Main loop
   repeat
    inc(loopCounter);
    try
      EnterCriticalSection(critSect);
      try
        while AcceptNewConnection do;
        ReadIncomingData;
        CheckForTimer;
      finally
       LeaveCriticalSection(critSect);
      end;

      if loopCounter and $FF=0 then begin
       ExternalControl;
      end;
      if loopCounter and $1FF=0 then begin
       FlushLog;
       FlushLogs;
       CheckForTemplatesUpdate;
      end;
      sleep(1);

      // Send responses if ready
      EnterCriticalSection(critSect);
      try
        WriteOutgoingData;
      finally
       LeaveCriticalSection(critSect);
      end;
    except
     on e:exception do begin
       LogMsg('Error in main thread: '+ExceptionMsg(e),logWarn);
       Sleep(1000);
     end;
    end;
   until needExit;

   LogMsg('Terminating...',logImportant);
   for i:=1 to worker_threads do
    workers[i].terminate;

   for i:=1 to 100 do begin
    sleep(50);
    if liveWorkers=0 then break;
   end;
   if liveWorkers>0 then LogMsg('Not all workers terminated!',logWarn);
   CloseSocket(MainSock);
   WSACleanup;
   ctl.Free;
   DeleteCritSect(critSect);
   LogMsg('Terminated',logImportant);
  end;

// -------------------------------------------------------
// Worker threads
// -------------------------------------------------------

// Returns: true - request completed, false - pending (process it later again)
function HandleRequest(pending:boolean;out resp:String8):boolean;
 var
  i,p:integer;
  found:integer;
  st,uriUp:String8;
  t:int64;
 begin
  try
  try
   t:=MyTickCount;
   result:=false;
   resp:='';
   if uri='' then begin // parse script and query
    uri:=GetHeader(headers,'REQUEST_URI');
    p:=pos('?',uri);
    if p>0 then setLength(uri,p-1);
    query:=GetHeader(headers,'QUERY_STRING');
   end;
   if (URIPrefix<>'') and HasPrefix(uri,URIprefix,true) then Delete(uri,1,length(UriPrefix));
   uriUp:=UpperCase(uri);
   clientIP:=GetHeader(headers,'REMOTE_ADDR');
   clientCountry:=GetCountryByIP(StrToIp(clientIP));
   httpMethod:=UpperCase(GetHeader(headers,'REQUEST_METHOD'));
   if not pending then
    LogMsg('[%d] Handling request %d: %s %s %s VID:%s (%s;%s)',
      [workerID,requestIdx,httpMethod,uri,query,Cookie('VID'),clientIP,ClientCountry],logNormal);
   // Exact match
   found:=-1;
   for i:=1 to hCount do
    if (handlers[i].wildcard=0) and
      (handlers[i].uri=uriUp) then begin
     found:=i; break;
    end;
   // Try wildcard
   if found=-1 then
    for i:=1 to hCount do begin
     if handlers[i].wildcard>0 then begin
      p:=pos(handlers[i].uri,uriUp);
      if (p=1) or (p>1) and (handlers[i].wildcard and 1=1) then begin
       found:=i; break;
      end;
     end;
    end;
   // default page handler
   if (found<0) and (handlers[0].uri='*') then begin
    found:=0;
    LogMsg('No handler for request '+uri+', using default');
   end;
   if found>=0 then begin
    temp.Init; // Clear temporary templates
    resp:=handlers[found].handler;
    result:=resp<>'';
    exit;
   end;
   resp:=FormatHeaders('text/html','404')+'<h1>404 Not Found!<h1>';
   result:=true;
  except
   on e:E200 do resp:=FormatHeaders('text/html')+e.Message;
   on e:E403 do resp:=FormatError(403,e.Message);
   on e:E404 do resp:=FormatError(404,e.Message);
   on e:E405 do resp:=FormatError(405,e.Message);
   on e:E429 do resp:=FormatError(429,e.Message);
   on e:E500 do resp:=FormatError(500,e.Message);
   on e:exception do begin
    LogMsg('Error 500: '+ExceptionMsg(e),logWarn);
    resp:=FormatHeaders('text/html','500')+'<h1>500 Internal Server Error!<h1>';
   end;
  end;
  finally
   if resp<>'' then result:=true;
   st:=copy(resp,1,180);
   st:=StringReplace(st,#13,'\r',[rfReplaceAll]);
   st:=StringReplace(st,#10,'\n',[rfReplaceAll]);
   if result then LogMsg('[%d] Request %d handled (t=%d): %s',[workerID,requestIdx,integer(MyTickCount-t),st],logNormal);
  end;
 end;

// special fake requests
procedure HandleSpecialRequest(r:integer);
 begin
  try
   if (requests[r].request='DB') then db.Query(requests[r].body)
   else
   if (requests[r].request='TIMER') and (@timerProc<>nil) then timerProc
   else
   if (requests[r].request='INITIALIZE') and (@initProc<>nil) then initProc;
  except
   on e:Exception do LogMsg('Error in special request "%s": '+ExceptionMsg(e),[requests[r].request],logWarn);
  end;
 end;

{ TWorker }
constructor TWorker.Create(id: integer);
 begin
  inherited Create(false);
  workerID:=id;
 end;

procedure TWorker.Execute;
 var
  r,count,duration:integer;
  req:TRequest;
  state,isPending,isSpecial:boolean;
  t:int64;
 begin
  currentRequest:=0;
  Apus.SCGI.workerID:=self.workerID;
  LogMsg('Hello from worker '+inttostr(workerID));
  try
   priority:=tpHigher;
   InterlockedIncrement(liveWorkers);
   if DB_HOST<>'' then begin
    db:=TMySQLDatabaseWithLogging.Create(logmsg,logInfo,logInfo,logNormal,2);
    db.Connect;
   end else
    db:=nil;
   templates.Init;
   LoadTemplates;
  except
   on e:exception do begin
    LogMsg('Failed to start worker '+inttostr(workerID)+' thread: '+ExceptionMsg(e),logError);
    InterlockedDecrement(liveWorkers);
    exit;
   end;
  end;
  r:=-1; count:=0;
  repeat
   try
    // process request
    if r>0 then begin
     if isSpecial then begin
      HandleSpecialRequest(r);
      state:=true;
     end else
      state:=HandleRequest(isPending,requests[r].response);
    end;
    if count>10 then begin
     Sleep(5); // try 10 times, then wait...
     count:=0;
    end;

    if reloadTemplates then begin
     LoadTemplates;
     reloadTemplates:=false;
    end;

    EnterCriticalSection(critSect);
    try
     // Store request state
     if r>0 then with requests[r] do begin
      if state then begin
        status:=rsCompleted;
        t:=MyTickCount;
        executionTime:=t-timestamp;
        timestamp:=t;
        if socket=0 then status:=rsFree;
      end else begin
        duration:=MyTickCount-timestamp;
        if duration>MAX_COMET_DURATION then begin
         // too long waiting - abort
         requests[r].response:=FormatHeaders('text/html','204 No Content');
         status:=rsCompleted;
         LogMsg('[%d] Request %d timeout: ret 204 status',[workerId,r]);
        end else begin
         if not isPending then LogMsg('[%d] Request %d postponed',[workerId,r]);
         status:=rsPending;
         timeToProcess:=MyTickCount+COMET_INTERVAL; // wait some time to process again
         qPut(r); // Put back to the queue to process later
        end;
      end;
     end;
    finally
     LeaveCriticalSection(critSect);
    end;
    sleep(1);
    // get next request to process
    repeat
     r:=qGet;
     if r<0 then break;
     t:=MyTickCount;
     if (r>0) and (requests[r].timeToProcess>t) then begin
      sleep(5);
      qPut(r); // postpone request
      continue;
     end;
     break;
    until false;
    currentRequest:=r;
    inc(count);
    if r>0 then begin
      isPending:=requests[r].status=rsPending;
      requests[r].status:=rsProcessing;
      if not isPending then
       requests[r].timestamp:=MyTickCount;

      isSpecial:=(requests[r].socket=0) and
         ((requests[r].request='TIMER') or
          (requests[r].request='INITIALIZE') or
          (requests[r].request='DB'));
      if not isSpecial then begin
       // real request
       requestIdx:=r;
       headers:=requests[r].headers;
       requestBody:=requests[r].body;
       uri:=''; query:=''; setCookies:='';
       clientIP:=''; httpMethod:='';
       userID:=0;
       if requests[r].request<>'' then begin
        uri:=requests[r].request;
       end;
     end;
    end;
   except
    on e:exception do begin
     LogMsg('ERROR IN WORKER '+inttostr(workerID)+': '+ExceptionMsg(e),logWarn);
     sleep(500);
    end;
   end;
  until terminated;
  FreeAndNil(db);
  InterlockedDecrement(liveWorkers);
 end;

 procedure AddTask(task:String8;data:String8='');
  begin
   AddFakeRequest(task,data);
  end;

 procedure PostQuery(query:String8;params:array of const);
  begin
   query:=FormatQuery(query,params);
   AddTask('DB',query);
  end;

 // Test request
 function ListHeaders:String8; stdcall;
  var
   i:integer;
   sa:stringArr;
   st:String8;
  begin
   sa:=split(#0,headers);
   st:='<html><body><table cellpadding=3 style="background-color:#e6d8ce">';
   for i:=0 to length(sa)-2 do begin
    if i and 3=2 then st:=st+'<tr>';
    if i and 3=0 then st:=st+'<tr style="background-color:#D8F0F0">';
    st:=st+'<td>'+sa[i];
   end;
   st:=st+'</table></body></html>';
   result:=FormatHeaders('text/html','','')+st;
  end;


var
 st:String8;
begin
 // Default handler
 handlers[0].uri:='';
 handlers[0].handler:=nil;

end.

