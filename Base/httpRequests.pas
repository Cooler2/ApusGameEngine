// Cross-platform support for HTTP GET and POST async requests
//
// Copyright (C) 2013 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com, cooler@tut.by)
{$IFDEF IOS}{$S-} {$modeswitch objectivec1}{$ENDIF}
unit httpRequests;
interface
 uses MyServis;

 const
  httpStatusFree = 0; // element not used
  httpStatusPending = 1; // Initiated, but not sent yet
  httpStatusSent = 2; // waiting for response
  httpStatusFailed = 10;  // request completed with error
  httpStatusCompleted = 11; // request completed successfully

 type 
  TContentType=(ctMultipart,ctUrlencoded,ctBinary,ctText,ctAuto);

 var
  httpUseCookies:boolean=false; // send/store cookies
  // Statistics
  avgResponseTime,maxResponseTime:integer; // среднее и максимальное врем€ (успешного, если указан таймаут) выполнени€ запросов в ms
  requestsFailed,requestsSucceed,requestsTime,requestsTimeCount:integer;

 // Start HTTP request to URL, if postdata='' then request is GET, otherwise - POST
 // Upon completion (or in case of failure), "event" will be signaled with tag=requestID
 // Return value: request ID
 function HTTPRequest(url,postdata,event:string;timeout:integer=0;contentType:TContentType=ctText):integer;

 procedure CancelRequest(reqID:integer);

 // Return request status (HTTP code or error constant) and response text
 // If request is completed - this destroys request object, so it's ID and data can't be used anymore
 function GetRequestResult(ID:integer;out response:AnsiString;httpStatus:PInteger=nil):integer;
 // ≈сли статут запроса - Sent или Completed - возвращает кол-во скачанных байт
 function GetRequestState(ID:integer):integer;
 // ¬озвращает код ошибки запроса, который завершилс€ неудачей
 function GetRequestError(ID:integer):integer;

 // Format POST body with specified parameters using specified content type
 function FormatPostBody(paramNames,paramValues:StringArr;contentType:TContentType=ctAuto):AnsiString;

 // Both procedures are not required to call!
 procedure InitHTTPrequests;
 procedure DoneHTTPrequests;

implementation
 uses CrossPlatform,SysUtils,classes,eventman
   {$IFDEF DELPHI},wininet,ZLibEx{$ENDIF}
   {$IFDEF IOS},iPhoneAll{$ENDIF}
   {$IFDEF FPC},fphttpclient{$ENDIF};
 type
  TRequest=record
   ID:integer;
   status,receivedBytes:integer;
   timeSent:int64;
   url,postdata,event,response:AnsiString;
   errorCode:integer;
   timeout:integer;
   contentType:TContentType;
   thread:TThread;
   httpStatus:integer; // ¬ случае получени€ ответа - здесь HTTP-код
   {$IFDEF IOS}
   con:id;
   {$ENDIF}
   {$IFDEF DELPHI}
   handle:HInternet;
   {$ENDIF}
  end;
  {$IFDEF DELPHI}
  THTTPConnection=record
   HCon:HInternet;
   server:AnsiString;
   port:word;
   free:boolean; // используетс€ ли в данный момент дл€ запроса?
  end;
  {$ENDIF}
  THTTPThread=class(TThread)
   req:^TRequest;
   procedure Execute; override;
   procedure ExecuteGetRequest;
   procedure ExecutePostRequest;
  end;

 var
  requests:array[1..20] of TRequest;
  lastID:integer=0;
  critSect:TMyCriticalSection;
  lastLogTime:int64;
//  initialized:boolean;

 procedure LogStats;
  begin
   lastLogTime:=MyTickCount;
   LogMessage(Format('HTTP stats: succeed: %d, failed: %d, avg time: %d, max time: %d',
     [requestsSucceed,requestsFailed,avgResponseTime,maxResponseTime]));
  end;

 {$IFDEF DELPHI}
 var
  HMain:HInternet;
  connections:array[1..5] of THTTPConnection;   // used for simultaneous access to different servers
 {$ENDIF}

  procedure SendRequest(var r:TRequest);
   var
    thread:THTTPThread;
   begin
    thread:=THTTPThread.Create(true);
    thread.FreeOnTerminate:=true;
    thread.req:=@r;
    thread.Resume;
   end;

  {$IFDEF IOS}
   type
    TConnectionDelegate=objcclass(NSObject,NSURLConnectionDelegateProtocol)
     procedure connection_didReceiveResponse(connection: NSURLConnection; response: NSURLResponse); message 'connection:didReceiveResponse:';
     procedure connection_didFailWithError(connection: NSURLConnection; error: NSError); message 'connection:didFailWithError:';
     procedure connection_didReceiveData(connection: NSURLConnection; data: NSData); message 'connection:didReceiveData:';
     procedure connectionDidFinishLoading(connection: NSURLConnection); message 'connectionDidFinishLoading:';
    end;
   var
    delegate:TConnectionDelegate;

   function GetConnectionURL(con:NSUrlConnection):string;
    begin
     result:='unknown';
    end;

   function FindRequest(con:NSURLConnection):integer;
    var
     i:integer;
    begin
     result:=0;
     for i:=1 to high(requests) do
      if requests[i].con=con then begin
       result:=i; exit;
      end;
     raise EWarning.Create('HTTP request not found for '+GetConnectionURL(con));
    end;

   procedure TConnectionDelegate.connection_didReceiveResponse(connection: NSURLConnection; response: NSURLResponse);
    begin
    end;

   procedure TConnectionDelegate.connection_didReceiveData(connection: NSURLConnection; data: NSData);
    var
     r:integer;
     st:string;
    begin
     r:=FindRequest(connection);
     SetLength(st,data.length);
     data.getBytes_length(@st[1],data.length);
     requests[r].response:=requests[r].response+st;
    end;

   procedure tConnectionDelegate.connectionDidFinishLoading(connection: NSURLConnection);
    var
      r:integer;
    begin
     r:=FindRequest(connection);
     if requests[r].status<10 then begin
      requests[r].status:=httpStatusCompleted;
      LogMessage('HTTP request '+inttostr(requests[r].id)+' completed: '+requests[r].url);
      Signal(requests[r].event,requests[r].id);
     end;
    end;

   procedure TConnectionDelegate.connection_didFailWithError(connection: NSURLConnection; error: NSError);
    var
     req:integer;
     url:string;
    begin
     req:=FindRequest(connection);
     requests[req].status:=httpStatusFailed;
     ForceLogMessage('HTTP request '+inttostr(requests[req].id)+' failed: '+requests[req].url+' ERROR: '+error.localizedDescription.UTF8String);
     Signal(requests[req].event,requests[req].id);
    end;

   procedure InternalInit;
    begin
     if delegate=nil then delegate:=TConnectionDelegate.alloc.init;
    end;

   procedure InternalCleanup;
    begin
     if delegate<>nil then delegate.release;
    end;

   procedure SendRequest(var r:TRequest);
    var
     st:string;
     url:NSURL;
     request:NSMutableURLRequest;
     connection:NSURLConnection;
    begin
     InternalInit;
     st:=r.url;
     url:=NSURL.UrlWithString(NSSTR(PChar(st)));
     request:=NSURLRequest.requestWithURL_cachePolicy_timeoutInterval(url,
       NSURLRequestReloadIgnoringLocalAndRemoteCacheData,3);
     if r.postdata<>'' then begin
      request.setHTTPMethod(NSSTR('POST'));
      request.setHTTPBody(NSData.DataWithBytes_length(@r.postdata[1],length(r.postdata)));
      LogMessage(inttostr(r.id)+' POST '+st+' size: '+inttostr(length(r.postdata)));
     end else
      LogMessage(inttostr(r.id)+' GET '+st);
     connection:=NSURLConnection.connectionWithRequest_delegate(request,delegate);
     r.status:=httpStatusSent;
     r.timeSent:=MyTickCount;
     r.con:=connection;
     connection.retain;
    end;
 {$ENDIF}  // IOS

 {$IFDEF FPC}
 type
  THTTPClient=record
   client:TFPHTTPClient;
   busy:boolean;
  end;
 var
  getClient:THTTPClient;
  postClients:array of THTTPClient;

 { THTTPThread }

 procedure SaveRequestResult(var req:TRequest;client:TFPHTTPClient);
  begin
   if client.ResponseStatusCode div 100=2 then begin
    req.status:=httpStatusCompleted;
    LogMessage(Format('HTTP request %d done, %d bytes received: %s',
     [req.id,length(req.response),copy(req.response,1,80)]));
   end else begin
    req.status:=httpStatusFailed;
    LogMessage(Format('HTTP request %d failed, code %d: %s',
     [req.id,client.ResponseStatusCode,copy(req.response,1,100)]));
   end;
  end;

 procedure THTTPThread.ExecuteGetRequest;
  var
   client:TFPHTTPClient;
   ss:TStringStream;
  begin
   LogMessage('GET '+IntToStr(req.ID)+': '+req.url);
   critSect.Enter;
   try
    client:=nil;
    if getClient.client=nil then begin
     LogMessage('Creating a GET HTTP client');
     client:=TFPHTTPClient.Create(nil);
     client.KeepConnection:=true;
     client.AllowRedirect:=true;
     getClient.busy:=true;
     getClient.Client:=client;
    end else
    if not getClient.busy then begin
     getClient.busy:=true;
     client:=getClient.Client;
    end;
   finally
    critSect.Leave;
   end;
   if client=nil then begin
    client:=TFPHTTPClient.Create(nil);
    client.AllowRedirect:=true;
   end;
   req.status:=httpStatusSent;
   client.AddHeader('X-Dont-Compress','1');
   try
   SS:=TStringStream.Create('');
   try
     client.HTTPMethod('GET',req.url,ss,[200,400,403,404,500,503]);
     req.response:=SS.Datastring;
   finally
     SS.Free;
   end;
   SaveRequestResult(req^,client);
   except
    on e:exception do begin
      LogMessage('HTTP request '+inttostr(req.id)+' failure: '+ExceptionMsg(e));
      req.response:=ExceptionMsg(e);
      req.status:=httpStatusFailed;
    end;
   end;

   if client=getClient.client then
    getClient.busy:=false
   else
    client.Free;
  end;

 procedure THTTPThread.ExecutePostRequest;
  var
    i,port,n:integer;
    request,serverName:string;
    client:TFPHTTPClient;
    multipart:boolean;
    lines:StringArr;
    boundary:string;
    ss:TStringStream;
  begin
   LogMessage('POST '+IntToStr(req.ID)+': '+req.url+' :: '+StringReplace(copy(req.postdata,1,70),#13#10,'\n',[rfReplaceAll]));
   // Parse URL
   i:=pos('//',req.url);
   request:=Copy(req.url,i+2,length(req.url));
   i:=pos('/',request);
   if i>0 then begin
    serverName:=copy(request,1,i-1);
    delete(request,1,i-1);
   end else begin
    // empty request
    serverName:=request;
    request:='/';
   end;
   port:=80;
   i:=pos(':',serverName);
   if i>0 then begin
    port:=StrToIntDef(copy(serverName,i+1,10),port);
    SetLength(serverName,i-1);
   end;

   critSect.Enter;
   try
    client:=nil;
    for i:=0 to high(postClients) do
     if not postClients[i].busy then begin
      postClients[i].busy:=true;
      client:=postClients[i].client;
     end;
    if client=nil then begin
     n:=length(postClients);
     SetLength(postClients,n+1);
     with postClients[n] do begin
      LogMessage('Creating a HTTP client');
      client:=TFPHTTPClient.Create(nil);
      client.KeepConnection:=true;
      client.AllowRedirect:=true;
      busy:=true;
     end;
    end;
   finally
    critSect.Leave;
   end;

   DebugMessage('1');
   client.AddHeader('Accept','*.*');
   DebugMessage('2');
   client.AddHeader('Content-Length',inttostr(length(req.postdata)));
   DebugMessage('3');
   client.AddHeader('X-Dont-Compress','1');
   case req.contentType of
    ctUrlencoded:client.AddHeader('Content-Type','application/x-www-form-urlencoded');
    ctBinary:client.AddHeader('Content-Type','application/octet-stream');
    ctText:client.AddHeader('Content-Type','text/plain');
    ctMultipart:begin // complex case
      multipart:=false;
      lines:=Split(#13#10,req.postData);
      for i:=1 to length(lines)-1 do begin
       if length(lines[i])<120 then begin
        if pos('CONTENT-DISPOSITION:',UpperCase(lines[i]))=1 then begin
         boundary:=lines[i-1];
         if (length(boundary)>2) and (length(boundary)<100) and
            (boundary[1]='-') and (boundary[2]='-') then begin
           delete(boundary,1,2);
           multipart:=true;
           break;
         end;
        end;
       end;
      end;
      if multipart then begin
       DebugMessage('4');
       client.AddHeader('Content-Transfer-Encoding','binary');
       DebugMessage('5');
       client.AddHeader('Content-Type','multipart/form-data; boundary='+boundary);
      end;
    end;
   end;
   try
   SS:=TStringStream.Create('');
   try
    client.RequestBody:=TStringStream.Create(req.postdata);
    client.HTTPMethod('POST',req.url,ss,[200,400,403,404,500,503]);
    req.response:=SS.Datastring;
    client.RequestBody.Free;
   finally
    SS.Free;
   end;
   SaveRequestResult(req^,client);
   except
    on e:exception do begin
      LogMessage('HTTP request '+inttostr(req.id)+' failure: '+ExceptionMsg(e));
      req.response:=ExceptionMsg(e);
      req.status:=httpStatusFailed;
    end;
   end;

   critSect.Enter;
   try
    postClients[n].busy:=false;
   finally
    critSect.Leave;
   end;
  end;
 {$ENDIF}


 function HTTPrequest(url,postdata,event:string;timeout:integer=0;contentType:TContentType=ctText):integer;
  var
   i:integer;
  begin
   result:=0;
   EnterCriticalSection(critSect);
   try
    InitHTTPrequests;
    for i:=1 to high(requests) do
     if requests[i].status=0 then begin
      inc(lastID);
      requests[i].status:=httpStatusPending;
      requests[i].httpStatus:=0;      
      requests[i].ID:=lastID;
      result:=lastID;
      requests[i].event:=event;
      if pos('http',url)<>1 then url:='http://'+url;
      requests[i].url:=url;
      requests[i].contentType:=contentType;
      requests[i].postdata:=postdata;
      requests[i].timeout:=timeout;
      requests[i].thread:=nil;
      requests[i].errorCode:=0;
      SendRequest(requests[i]); // инициирует асинхронную отправку запроса
      exit;
     end;
    raise EWarning.Create('HTTP: too many HTTP requests');
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 procedure CancelRequest(reqID:integer);
  var
   i:integer;
  begin
   LogMessage('Cancel request '+inttostr(reqID));
   EnterCriticalSection(critSect);
   try
    for i:=1 to high(requests) do
     with requests[i] do
      if (ID=reqID) and (status=httpStatusSent) then begin
       LogMessage('Aborting request '+inttostr(reqID));
       status:=httpStatusFailed;
       {$IFDEF DELPHI}
       InternetCloseHandle(handle);
       {$ENDIF}
       exit;
      end;
   finally
    LeaveCriticalSection(critSect);
   end;
   LogMessage('Request not found'+inttostr(reqID));
  end;

 function GetRequestResult(ID:integer;out response:AnsiString;httpStatus:PInteger=nil):integer;
  var
   i:integer;
  begin
   result:=0;
   EnterCriticalSection(critSect);
   try
    for i:=1 to High(requests) do
     if (requests[i].status>0) and (requests[i].ID=ID) then begin
      result:=requests[i].status;
      response:='';
      if result>=10 then begin
       // request completed
       response:=requests[i].response;
       requests[i].response:='';
       requests[i].postdata:='';
       requests[i].url:='';
       requests[i].status:=httpStatusFree; // free
       if httpStatus<>nil then httpStatus^:=requests[i].httpStatus;
       {$IFDEF IOS}
       requests[i].con.release;
       requests[i].con:=nil;
       {$ENDIF}
      end;
      exit;
     end;
    raise EWarning.Create('HTTP: request not found, ID='+inttostr(id));
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 function GetRequestState(ID:integer):integer;
  var
   i:integer;
  begin
   result:=-1;
   EnterCriticalSection(critSect);
   try
    for i:=1 to High(requests) do
     if (requests[i].status in [httpStatusSent,httpStatusCompleted]) and
        (requests[i].ID=ID) then begin
      result:=requests[i].receivedBytes;
      exit;
     end;
   finally
    LeaveCriticalSection(critSect);
   end;
  end;

 function GetRequestError(ID:integer):integer;
  var
   i:integer;
  begin
   result:=0;
   EnterCriticalSection(critSect);
   try
    for i:=1 to High(requests) do
     if (requests[i].ID=ID) then begin
      result:=requests[i].errorCode;
      exit;
     end;
   finally
    LeaveCriticalSection(critSect);
   end;
  end;


{$IFDEF DELPHI}
{ THTTPThread }
procedure THTTPThread.ExecuteGetRequest;
 var
  handle:HInternet;
  error:integer;
  code,size,downloaded,extra:cardinal;
  buf:string[255];
  data:array of byte;
  encoding:string[31];
  deflate:boolean;
 begin
  // 1. Send request
  LogMessage('GET '+IntToStr(req.ID)+': '+req.url);
  handle:=InternetOpenUrlA(HMain,PAnsiChar(req.url),nil,0,
    INTERNET_FLAG_RELOAD+
    INTERNET_FLAG_KEEP_CONNECTION+
    INTERNET_FLAG_PRAGMA_NOCACHE+
    INTERNET_FLAG_NO_CACHE_WRITE+
    INTERNET_FLAG_EXISTING_CONNECT+
    INTERNET_FLAG_NO_COOKIES*byte(not httpUseCookies),0);
    
  EnterCriticalSection(critSect);
  try
  req.handle:=handle;
  req.status:=httpStatusSent;
  req.timeSent:=MyTickCount;
  req.receivedBytes:=0;
//  LogMessage('request open '+inttostr(req.ID));
  if handle=nil then begin // failed
   req.status:=httpStatusFailed;
   error:=GetLastError; size:=254;
   if not InternetGetLastResponseInfoA(code,@buf[1],size) then buf:='(too long)'#0;
   ForceLogMessage(Format('HTTP request %d failed: %s eCode: %d code: %d',[req.ID,req.url,error,code]));
   req.errorCode:=error;
   exit;
  end else // success
   size:=4; code:=0; extra:=0;
   if not HTTPQueryInfo(handle,HTTP_QUERY_STATUS_CODE+HTTP_QUERY_FLAG_NUMBER,@code,size,extra) then
     req.status:=httpStatusFailed;
//   req.status:=httpStatusSent;
   if (code<200) or (code>=400) then begin
    req.status:=httpStatusFailed;
    ForceLogMessage(Format('HTTP request %d failed: %s Status: %d',[req.ID,req.url,code]));
   end;
   req.httpStatus:=code;
  finally
   LeaveCriticalSection(critSect);
  end;
  // 2. Download response
  downloaded:=0;
  while true do begin
   size:=16384;
   SetLength(data,downloaded+size);
   if InternetReadFile(handle,@data[downloaded],size,size) then begin
    if size>0 then begin
     inc(downloaded,size);
     req.receivedBytes:=downloaded;
    end else
     break; // download complete
   end else begin
    // download failed
    req.errorCode:=GetLastError;
    ForceLogMessage('HTTP request error: '+IntToStr(req.errorCode));
    req.status:=httpStatusFailed;
    break;
   end;
   sleep(1);
  end;

  // Decompression needed?
  deflate:=false;
  size:=31; extra:=0;
  if HttpQueryInfoA(handle,HTTP_QUERY_CONTENT_ENCODING,@encoding[1],size,extra) then begin
   SetLength(encoding,size);
   if pos('deflate',lowercase(encoding))>0 then deflate:=true;
  end;

//  LogMessage('Received: '+inttostr(downloaded));

  // 3. Ready
  EnterCriticalSection(critSect);
  InternetCloseHandle(handle);
  req.handle:=nil;
  try
   SetLength(req.response,downloaded);
   move(data[0],req.response[1],downloaded);
   if deflate then ZDecompressHTTP(req.response);
   if req.status<>httpStatusFailed then
    req.status:=httpStatusCompleted;
   req.receivedBytes:=length(req.response);
  finally
   LeaveCriticalSection(critSect);
  end;
 end;

procedure DeleteConnection(handle:HInternet);
 var
  i:integer;
 begin
  critSect.Enter;
  try
   for i:=1 to high(connections) do
    if connections[i].HCon=handle then begin
     LogMessage('Deleting connection ['+inttostr(i)+'] = '+PtrToStr(handle));
     connections[i].free:=true;
     connections[i].HCon:=0;
     connections[i].server:='';
     connections[i].port:=0;     
     InternetCloseHandle(handle);
    end;
  finally
   CritSect.Leave;
  end;
 end;

procedure THTTPThread.ExecutePostRequest;
 var
  i,error,port,conIdx:integer;
  code,httpCode,size,downloaded:cardinal;
  buf:string[255];
  handle:HInternet;
  data:array of byte;
  lines:AStringArr;
  headers,boundary,serverName,request:AnsiString;
  multipart,binary:boolean;
  HConnect:HInternet;
 begin
  LogMessage('POST '+IntToStr(req.ID)+': '+req.url+' :: '+StringReplace(copy(req.postdata,1,70),#13#10,'\n',[rfReplaceAll]));
  // Parse URL
  i:=pos('//',req.url);
  request:=Copy(req.url,i+2,length(req.url));
  i:=pos('/',request);
  if i>0 then begin
   serverName:=copy(request,1,i-1);
   delete(request,1,i-1);
  end else begin
   // empty request
   serverName:=request;
   request:='/';
  end;
  port:=80;
  i:=pos(':',serverName);
  if i>0 then begin
   port:=StrToIntDef(copy(serverName,i+1,10),port);
   SetLength(serverName,i-1);
  end;

  EnterCriticalSection(critSect);
  try
   // Find/alloc proper HCon
   HConnect:=nil; conIdx:=0;
   for i:=1 to High(connections) do
    if (connections[i].HCon<>nil) and
//       (connections[i].free) and
       (connections[i].server=serverName) and
       (connections[i].port=port) then begin
      conIdx:=i; 
      HConnect:=connections[i].HCon;
      connections[conIdx].free:=false;
      LogMessage(Format('HTTP: using connection [%d]=%s ',[i,PtrToStr(HConnect)]));
      break;
     end;

   // Alloc new
   if HConnect=nil then begin
    HConnect:=InternetConnectA(HMain,PAnsiChar(serverName),port,nil,nil,INTERNET_SERVICE_HTTP,0,0);
    if HConnect=nil then begin
     req.status:=httpStatusFailed;
     error:=GetLastError; size:=254;
     req.errorCode:=error;
     if not InternetGetLastResponseInfoA(code,@buf[1],size) then buf:='(too long)'#0;
     ForceLogMessage('HTTP request connect failed: '+req.url+' eCode: '+IntToStr(error)+
       ' code: '+IntToStr(code)+' error: '+PChar(@buf[1]));
     exit;
    end;
    // Store
    conIdx:=0;
    for i:=1 to High(connections) do
     if connections[i].HCon=nil then begin
      conIdx:=i; break;
     end;
    if conIdx=0 then
     for i:=1 to High(connections) do
      if connections[i].free then begin
       InternetCloseHandle(connections[i].HCon);
       conIdx:=i;
       break;
      end;
    if conIdx>0 then begin
     connections[conIdx].HCon:=HConnect;
     connections[conIdx].server:=serverName;
     connections[conIdx].port:=port;
     connections[conIdx].free:=false;
     LogMessage(Format('HTTP: new connection created [%d]=%s ',[conIdx,PtrToStr(HConnect)]));
    end else begin
     req.status:=httpStatusFailed;
     ForceLogMessage('Error: out of connection handles!');
     exit;
    end;
   end;

   // Open request
   handle:=HttpOpenRequestA(HConnect,'POST',PAnsiChar(request),nil,nil,nil,
     INTERNET_FLAG_KEEP_CONNECTION+
     INTERNET_FLAG_RELOAD+
     INTERNET_FLAG_NO_CACHE_WRITE+
     INTERNET_FLAG_NO_COOKIES*byte(not httpuseCookies),0);
   if handle=nil then begin
    req.status:=httpStatusFailed;
    error:=GetLastError;
    req.errorCode:=error;
    ForceLogMessage('HTTP request open failed: '+req.url+' eCode: '+IntToStr(error));
    DeleteConnection(HConnect);
    exit;
   end;
   if req.timeout>0 then begin
    InternetSetOptionA(handle,INTERNET_OPTION_RECEIVE_TIMEOUT,@req.timeout,4);
    InternetSetOptionA(handle,INTERNET_OPTION_SEND_TIMEOUT,@req.timeout,4);
   end;
  finally
   LeaveCriticalSection(critSect);
  end;

  headers:='Accept: */*'#13#10+'Content-Length: '+inttostr(length(req.postdata));
  case req.contentType of
   ctUrlencoded:headers:=headers+#13#10+'Content-Type: application/x-www-form-urlencoded';
   ctBinary:headers:=headers+#13#10+'Content-Type: application/octet-stream';
   ctText:headers:=headers+#13#10+'Content-Type: text/plain';
   ctMultipart:begin // complex case
     multipart:=false;
     lines:=SplitA(#13#10,req.postData);
     for i:=1 to length(lines)-1 do begin
      if length(lines[i])<120 then begin
       if pos('CONTENT-DISPOSITION:',UpperCase(lines[i]))=1 then begin
        boundary:=lines[i-1];
        if (length(boundary)>2) and (length(boundary)<100) and
           (boundary[1]='-') and (boundary[2]='-') then begin
          delete(boundary,1,2);
          multipart:=true;
          break;
        end;
       end;
      end;
     end;
     if multipart then
      headers:=headers+#13#10+'Content-Transfer-Encoding: binary'+#13#10+
        'Content-Type: multipart/form-data; boundary='+boundary
   end;
  end;

  // Send request 
  if not HttpSendRequestA(handle,PAnsiChar(headers),length(headers),
          @req.postdata[1],length(req.postdata)) then begin
   req.status:=httpStatusFailed;
   error:=GetLastError;
   req.errorCode:=error;
   ForceLogMessage('HTTP request '+IntToStr(req.ID)+' send failed: '+req.url+' eCode: '+IntToStr(error));
   DeleteConnection(connections[conIdx].HCon);
   exit;
  end else
   req.status:=httpStatusSent;

  size:=4; i:=0;
  if HTTPQueryInfoA(handle,HTTP_QUERY_STATUS_CODE,@httpCode,size,cardinal(i)) then begin
   req.httpStatus:=httpCode;
  end;

  // 2. Download response
  downloaded:=0;
  while true do begin
   size:=16384;
   SetLength(data,downloaded+size);
   if InternetReadFile(handle,@data[downloaded],size,size) then begin
    if size>0 then begin
     inc(downloaded,size);
    end else
     break; // download complete
   end else begin
    req.errorCode:=GetLastError;
    ForceLogMessage('HTTP request read error: '+IntToStr(req.errorCode));
    req.status:=httpStatusFailed;
   end;
   sleep(1);
  end;
  InternetCloseHandle(handle);

  // 3. Ready
  EnterCriticalSection(critSect);
  try
   SetLength(req.response,downloaded);
   move(data[0],req.response[1],downloaded);
   if req.status<>httpStatusFailed then
    req.status:=httpStatusCompleted;
   connections[conIdx].free:=true;
  finally
   LeaveCriticalSection(critSect);
  end;
 end;
{$ENDIF}

procedure THTTPThread.Execute;
 var
  time:int64;
 begin
  RegisterThread('HTTP-'+inttostr(req.ID));
  req.thread:=self;
  time:=MyTickCOunt;
  if req.postdata='' then ExecuteGetRequest
   else ExecutePostRequest;
  time:=MyTickCount-time;
  if req.status=httpStatusCompleted then begin
   inc(requestsSucceed);
   if (req.timeout>0) and (time>maxResponseTime) then maxResponseTime:=time;
   LogMessage(Format('Request %d status %d, %.3f s, %d bytes: %s',
     [req.ID,req.httpStatus,time/1000,req.receivedBytes,copy(req.response,1,60)]));
   if (req.timeout>0) then begin
    inc(requestsTime,time);
    inc(requestsTimeCount);
    avgResponseTime:=round(requestsTime/requestsTimeCount);
   end;
  end else
   inc(requestsFailed);

  Signal(req.event,req.ID);
  if MyTickCount>lastLogTime+60000 then LogStats; // –аз в минуту писать статистику по запросам в лог 
  req.thread:=nil;
  UnregisterThread;
 end;

 // not required to call
 procedure InitHTTPrequests;
  var
   c:cardinal;
   res:boolean;
   b:longbool;
  begin
   {$IFDEF DELPHI}
     if HMain=nil then begin
      HMain:=InternetOpen('ENGINE3_CLIENT',INTERNET_OPEN_TYPE_PRECONFIG,nil,nil,0);
//      HMain:=InternetOpen('ENGINE3_CLIENT',INTERNET_OPEN_TYPE_DIRECT,nil,nil,0);
      LogMessage('HTTP Init: '+IntToHex(cardinal(HMain),8));
      sleep(10);
      c:=4000; // 4 sec
      InternetSetOptionA(HMain,INTERNET_OPTION_CONNECT_TIMEOUT,@c,4);
      c:=30000; // 30 seconds default
      InternetSetOptionA(HMain,INTERNET_OPTION_RECEIVE_TIMEOUT,@c,4);
      InternetSetOptionA(HMain,INTERNET_OPTION_SEND_TIMEOUT,@c,4);
      res:=InternetSetOptionA(HMain,77{INTERNET_OPTION_IGNORE_OFFLINE},nil,0);
      LogMessage('INTERNET_OPTION_IGNORE_OFFLINE - '+BoolToStr(res,true));
      b:=false;
      res:=InternetSetOptionA(HMain,65{INTERNET_OPTION_HTTP_DECODING},@b,4);
      LogMessage('INTERNET_OPTION_HTTP_DECODING - '+BoolToStr(res,true));
     end;
     if HMain=nil then begin
      ForceLogMessage('HTTP: Internal Error 1 - '+IntToStr(GetLastError));
      exit;
     end;
   {$ENDIF}
  end;

 procedure DoneHTTPrequests;
  var
   i:integer;
  begin
   {$IFDEF DELPHI}
   if hMain=nil then exit;
   ForceLogMessage('HTTP terminating');
   LogStats;
   EnterCriticalSection(critSect);
   try
    for i:=1 to High(connections) do
     if connections[i].HCon<>nil then begin
      InternetCloseHandle(connections[i].HCon);
      connections[i].HCon:=nil;
      sleep(10);
     end;
    if HMain<>nil then InternetCloseHandle(HMain);
    HMain:=nil;
    ForceLogMessage('HTTP Done');
   finally
    LeaveCriticalSection(critSect);
   end;
   {$ENDIF}
  end;

 function FormatPostBody(paramNames,paramValues:StringArr;contentType:TContentType):AnsiString;
  var
   i,j,c,s:integer;
   boundary:string;
   b:byte;
   binHdr:string[4];
  begin
   if length(paramNames)<>length(paramValues) then raise EError.Create('FPB error');
   if contentType=ctAuto then begin
    c:=0; s:=0;
    for i:=0 to length(paramValues)-1 do begin
     inc(s,length(paramNames[i]));
     inc(c,length(paramNames[i]));
     inc(s,length(paramValues[i]));
     for j:=1 to length(paramValues[i]) do begin
      b:=byte(paramValues[i][j]);
      if (b<48) or (b>127) then inc(c,3)
       else inc(c);
     end;
    end;
    if c<s+50*length(paramValues) then contentType:=ctUrlencoded
     else contentType:=ctMultipart;
   end;
   result:='';
   case contentType of
    ctMultipart:begin
      // multipart/formdata
      boundary:='--'+IntToHex(getTickCount+random(10000000),8);
      result:=boundary;
      for i:=0 to length(paramNames)-1 do begin
       result:=result+#13#10'Content-Disposition: form-data; name="'+paramNames[i]+'"'+#13#10+
          'Content-type: application/octet-stream'#13#10#13#10+
          paramValues[i]+#13#10+boundary;
      end;
      result:=result+'--'#13#10;
    end;
    ctUrlencoded:begin
      // x-www-urlencode
      for i:=0 to high(paramNames) do begin
       if i>0 then result:=result+'&';
       if (paramNames[i]='') or (paramValues[i]='') then
        result:=result+UrlEncode(paramNames[i]+paramValues[i])
       else
        result:=result+UrlEncode(paramNames[i])+'='+UrlEncode(paramValues[i]);
      end;
    end;
    ctText:begin
     // text/plain - paramValues only
     for i:=0 to high(paramValues) do begin
      if i>0 then result:=result+#13#10;
      paramValues[i]:=StringReplace(paramValues[i],'\','\\',[rfReplaceAll]);
      paramValues[i]:=StringReplace(paramValues[i],#13#10,'\n',[rfReplaceAll]);
      result:=result+paramValues[i];
     end;
    end;
    ctBinary:begin
     // application/octet-stream - paramValues only!
     for i:=0 to high(paramValues) do begin
      s:=length(paramValues[i]);
      if s>=255 then begin
        SetLength(binHdr,4);
        binHdr[1]:=#255;
        move(s,binHdr[2],3); // 3 bytes for length, i.e. 16 Mb max
        result:=result+binHdr;
        LogMessage(Format('Long binary part %d/%d: %d bytes',[i,high(paramValues),s]));
      end else
        result:=result+char(s);
      result:=result+paramValues[i];
     end;
    end;
   end;
  end;

initialization
 InitCritSect(critSect,'HTTPrequest',60);
 {$IFDEF DELPHI}
 fillchar(connections,sizeof(connections),0);
 {$ENDIF}
finalization
 DoneHTTPrequests;
 DeleteCritSect(critSect);
end.
