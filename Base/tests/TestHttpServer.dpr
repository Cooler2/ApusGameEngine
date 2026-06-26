{$APPTYPE CONSOLE}
program TestHttpServer;
uses
  SysUtils,
  Apus.Core,
  Apus.Types,
  Apus.Strings,
  Apus.Conv,
  Apus.TCP,
  Apus.HttpServer;

{$INCLUDE Test.inc}

const
  SERVER_PORT=38080;

var
  gHandlerRan:boolean;
  gLastHandle:THttpReqHandle;

type
  // onRequest/onDeferExpired are "of object" — route through a small object.
  TRouter=class
    procedure OnRequest(ctx:THttpContext);
    function  OnDeferExpired(handle:THttpReqHandle):String8;
  end;

  // Collects every byte the server sends back.
  TCollectClient=class(TTCPClient)
    response:String8;
    procedure onDataReceived(var buf:TBuffer); override;
  end;

procedure TRouter.OnRequest(ctx:THttpContext);
begin
  gHandlerRan:=true;
  if ctx.uri='echo' then
    ctx.Respond(ctx.method+' a='+ctx.Param('a')+' b='+ctx.Param('b'))
  else if ctx.uri='form' then
    ctx.Respond('name='+ctx.Param('name'))
  else if ctx.uri='raw' then
    ctx.Respond(ctx.body)
  else if ctx.uri='defer' then begin
    gLastHandle:=ctx.Handle;
    ctx.Defer(10000); // long; the test completes it explicitly
  end
  else if ctx.uri='expire' then
    ctx.Defer(200)    // short; let it time out via OnDeferExpired
  else
    ctx.RespondError('404 Not Found');
end;

function TRouter.OnDeferExpired(handle:THttpReqHandle):String8;
begin
  result:='EXPIRED-BODY';
end;

procedure TCollectClient.onDataReceived(var buf:TBuffer);
var old:integer;
begin
  if buf.size<=0 then exit;
  old:=length(response);
  SetLength(response,old+buf.size);
  move(buf.data^,response[old+1],buf.size);
  buf.Skip(buf.size);
end;

// Parse a (possibly partial) HTTP response. Returns true when a full message
// (headers + Content-Length body) is present; fills statusLine and body.
function ResponseComplete(const r:String8;out statusLine,body:String8):boolean;
var
  p,clp,cl,lineEnd:integer;
  head,lenLine:String8;
begin
  result:=false; statusLine:=''; body:='';
  p:=r.IndexOf(#13#10#13#10);
  if p=0 then exit;
  head:=copy(r,1,p-1);
  lineEnd:=head.IndexOf(#13#10);
  if lineEnd>0 then statusLine:=copy(head,1,lineEnd-1)
  else statusLine:=head;
  cl:=0;
  clp:=head.ToLower.IndexOf('content-length:');
  if clp>0 then begin
    lenLine:=copy(head,clp+15,length(head));
    lineEnd:=lenLine.IndexOf(#13#10);
    if lineEnd>0 then SetLength(lenLine,lineEnd-1);
    cl:=lenLine.Trim.ToInteger;
  end;
  if length(r)-(p+3)>=cl then begin
    body:=copy(r,p+4,cl);
    result:=true;
  end;
end;

// Send one raw HTTP request on a fresh connection and wait for a full response.
// onParkedRespond>=0: once the handler has parked the request, complete it from
// the server side with this handle's response (tests deferred long-poll).
function DoRequest(server:THttpServer;const rawRequest:String8;
  out statusLine,body:String8;timeoutMs:integer;completeDeferred:boolean):boolean;
var
  client:TCollectClient;
  wb:TBuffer;
  deadline:int64;
  responded:boolean;
begin
  result:=false; statusLine:=''; body:='';
  gHandlerRan:=false; gLastHandle:=0;
  responded:=false;
  client:=TCollectClient.Create;
  try
    client.Connect('127.0.0.1:'+IntToStr(SERVER_PORT),-1); // non-blocking; pumped below
    deadline:=CoreTime.Ticks+timeoutMs;
    // 1) wait until the connection is established (server must Poll to accept)
    while (not client.connected) and (not client.disconnected) and (CoreTime.Ticks<deadline) do begin
      server.Poll;
      client.Poll;
      Sleep(1);
    end;
    if not client.connected then exit;
    // 2) send the request, then pump until a full response arrives
    wb.CreateFrom(rawRequest);
    client.SendData(wb);
    while CoreTime.Ticks<deadline do begin
      server.Poll;
      client.Poll;
      if completeDeferred and (not responded) and gHandlerRan and (gLastHandle<>0) then begin
        server.Respond(gLastHandle,'LATE-DATA');
        responded:=true;
      end;
      if ResponseComplete(client.response,statusLine,body) then begin
        result:=true;
        exit;
      end;
      Sleep(1);
    end;
  finally
    client.Disconnect;
    client.Free;
  end;
end;

procedure TestGetQuery(server:THttpServer);
var st,body:String8;
begin
  StartTest('GET with query params');
  if DoRequest(server,'GET /echo?a=1&b=two HTTP/1.1'#13#10'Host: x'#13#10#13#10,
       st,body,3000,false) then begin
    Check(st.Contains('200'),'status not 200: '+st);
    Check(body='GET a=1 b=two','wrong echo body: ['+body+']');
  end else
    Check(false,'no response to GET');
  EndTest;
end;

procedure TestPostUrlEncoded(server:THttpServer);
var st,body,req,payload:String8;
begin
  StartTest('POST urlencoded form');
  payload:='name=Alice';
  req:='POST /form HTTP/1.1'#13#10+
       'Host: x'#13#10+
       'Content-Type: application/x-www-form-urlencoded'#13#10+
       'Content-Length: '+IntToStr(length(payload))+#13#10#13#10+payload;
  if DoRequest(server,req,st,body,3000,false) then begin
    Check(st.Contains('200'),'status not 200: '+st);
    Check(body='name=Alice','wrong form echo: ['+body+']');
  end else
    Check(false,'no response to POST form');
  EndTest;
end;

procedure TestPostRawBody(server:THttpServer);
var st,body,req,payload:String8;
begin
  StartTest('POST raw body echo');
  payload:='line1'#13#10'line2~payload';
  req:='POST /raw HTTP/1.1'#13#10+
       'Host: x'#13#10+
       'Content-Type: text/plain'#13#10+
       'Content-Length: '+IntToStr(length(payload))+#13#10#13#10+payload;
  if DoRequest(server,req,st,body,3000,false) then begin
    Check(st.Contains('200'),'status not 200: '+st);
    Check(body=payload,'raw body not echoed verbatim: ['+body+']');
  end else
    Check(false,'no response to raw POST');
  EndTest;
end;

procedure TestDeferredLongPoll(server:THttpServer);
var st,body:String8;
begin
  StartTest('deferred long-poll (server push)');
  if DoRequest(server,'GET /defer HTTP/1.1'#13#10'Host: x'#13#10#13#10,
       st,body,3000,true) then begin
    Check(st.Contains('200'),'status not 200: '+st);
    Check(body='LATE-DATA','deferred body wrong: ['+body+']');
  end else
    Check(false,'no response to deferred poll');
  EndTest;
end;

procedure TestDeferExpiry(server:THttpServer);
var st,body:String8;
begin
  StartTest('deferred timeout -> onDeferExpired');
  if DoRequest(server,'GET /expire HTTP/1.1'#13#10'Host: x'#13#10#13#10,
       st,body,3000,false) then begin
    Check(st.Contains('200'),'status not 200: '+st);
    Check(body='EXPIRED-BODY','expiry body wrong: ['+body+']');
  end else
    Check(false,'no response on defer expiry');
  EndTest;
end;

procedure TestNotFound(server:THttpServer);
var st,body:String8;
begin
  StartTest('unknown route -> 404');
  if DoRequest(server,'GET /nope HTTP/1.1'#13#10'Host: x'#13#10#13#10,
       st,body,3000,false) then
    Check(st.Contains('404'),'expected 404, got: '+st)
  else
    Check(false,'no response to unknown route');
  EndTest;
end;

var
  router:TRouter;
  server:THttpServer;

begin
  writeln('=== HTTP Server Tests ===');
  writeln;
  router:=TRouter.Create;
  server:=nil;
  try
    server:=THttpServer.Create(SERVER_PORT);  // loopback only
    server.onRequest:=router.OnRequest;
    server.onDeferExpired:=router.OnDeferExpired;

    TestGetQuery(server);
    TestPostUrlEncoded(server);
    TestPostRawBody(server);
    TestDeferredLongPoll(server);
    TestDeferExpiry(server);
    TestNotFound(server);

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',e.Message);
      ExitCode:=255;
    end;
  end;
  server.Free;
  router.Free;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
