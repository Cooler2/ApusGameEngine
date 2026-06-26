// Minimal self-hosted HTTP/1.1 server over Apus.TCP.

// Copyright (C) 2026 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.HttpServer;
interface
uses Apus.Core, Apus.Types, Apus.TCP, Apus.HashMaps;

type
 THttpReqHandle = type cardinal;            // opaque: connection slot + generation
 THttpCompress  = (csNone,csAuto,csForce);  // deflate; default csNone (admin-tier, see Respond)

 // Internal (exposed only because they are fields of THttpServer):
 TConnSlot=record       // stable connection registry slot (survives TCP array compaction)
  conn:TObject;         // THttpConn occupying this slot (nil if free)
  generation:word;      // bumped on release; part of the handle for stale detection
  active:boolean;
 end;
 TIPRec=record          // per-IP penalty with lazy time decay
  penalty:integer;
  tick:int64;           // CoreTime.Ticks of last update
 end;

 THttpServer = class; // forward

 // One HTTP transaction: the parsed request plus the means to respond.
 // Valid ONLY inside the onRequest handler. To respond later (long-poll), call
 // Defer and keep the Handle; the object itself must not be retained.
 THttpContext = class
  method:String8;       // 'GET' / 'POST'
  uri:String8;          // path, no leading '/', no query (e.g. '123-4-ab12cd')
  query:String8;        // raw query (after '?')
  contentType:String8;  // body Content-Type (lowercased)
  body:String8;         // raw request body (POST); custom framing parsed by caller
  remoteIP:cardinal;
  country:String8;      // 2-letter code if GeoIP enabled, else ''
  function Param(name:String8):String8;   // GET query OR POST urlencoded/multipart, case-insensitive
  function HasParam(name:String8):boolean;
  function Cookie(name:String8):String8;
  function Header(name:String8):String8;
  function Handle:THttpReqHandle;
  // respond — choose EXACTLY one:
  procedure Respond(const body:String8;mime:String8='text/plain';
     cacheControl:String8='';compress:THttpCompress=csNone);
  procedure RespondError(status:String8);  // e.g. '404 Not Found'
  procedure Defer(timeoutMS:integer=0);    // park; respond later via server.Respond(Handle,...). 0=default
 private
  fServer:THttpServer;
  fHandle:THttpReqHandle;
  parsed:boolean;
  parNames,parValues:Strings8;
  hdrNames,hdrValues:Strings8;
  cookieLine:String8;
  procedure Reset;
  procedure ParseParameters;
 end;

 THttpRequestEvent = procedure(ctx:THttpContext) of object;       // must call one of Respond/RespondError/Defer
 THttpDeferExpiredEvent = function(handle:THttpReqHandle):String8 of object; // body on timeout ('' => empty 200)

 THttpServer = class
 private
  fTCP:TTCPServer;
  fSlots:array of TConnSlot;
  fActiveCount:integer;
  fGeoIP:boolean;
  fPenalties:THashMapNum<TIPRec>;
  fOnRequest:THttpRequestEvent;
  fOnDeferExpired:THttpDeferExpiredEvent;
  fDefaultDeferTimeout,fKeepAliveTimeout,fMaxRequestSize,fMaxConnections:integer;
  fBanThreshold,fRequestPenalty,fPenaltyDecayPerSec:integer;
  procedure AcquireSlot(conn:TObject);
  procedure ReleaseSlot(slot:integer);
  function  ConnFromHandle(handle:THttpReqHandle):TObject;
  procedure IPPenaltyRec(ip:cardinal;out rec:TIPRec); // decayed penalty for ip
 public
  constructor Create(port:word;bindAll:boolean=false);
  destructor Destroy; override;
  procedure Poll;                          // accept/read/dispatch/flush/expire deferred — call regularly
  procedure Respond(handle:THttpReqHandle;const body:String8;mime:String8='text/plain';
     cacheControl:String8='';compress:THttpCompress=csNone);  // complete a deferred request
  procedure RespondError(handle:THttpReqHandle;status:String8);
  function  IsAlive(handle:THttpReqHandle):boolean;
  procedure Close(handle:THttpReqHandle);
  function  ConnectionCount:integer;
  // --- IP penalty / DoS / brute-force protection ---
  procedure PenalizeIP(ip:cardinal;weight:integer); // raise an IP's penalty (auth failure, abuse)
  function  IPPenalty(ip:cardinal):integer;
  // --- optional GeoIP country (off by default) ---
  procedure EnableGeoIP(dbPath:String8='');  // resolve ctx.country at accept via Apus.GeoIP
  property onRequest:THttpRequestEvent read fOnRequest write fOnRequest;
  property onDeferExpired:THttpDeferExpiredEvent read fOnDeferExpired write fOnDeferExpired;
  property defaultDeferTimeout:integer read fDefaultDeferTimeout write fDefaultDeferTimeout;  // ms
  property keepAliveTimeout:integer read fKeepAliveTimeout write fKeepAliveTimeout;           // ms
  property maxRequestSize:integer read fMaxRequestSize write fMaxRequestSize;
  property maxConnections:integer read fMaxConnections write fMaxConnections;                 // DoS cap
  property banThreshold:integer read fBanThreshold write fBanThreshold;     // reject new conns at/above this
  property requestPenalty:integer read fRequestPenalty write fRequestPenalty; // auto-added per request
  property penaltyDecayPerSec:integer read fPenaltyDecayPerSec write fPenaltyDecayPerSec;
 end;

implementation
uses SysUtils, Apus.Strings, Apus.Conv, Apus.GeoIP, Apus.Log;

const
 CRLF=#13#10;
 HDR_END=#13#10#13#10;

type
 // TCP-level endpoint for one HTTP connection: accumulates bytes, parses requests,
 // owns a reusable THttpContext, tracks an optional parked (deferred) response.
 THttpConn=class(TTCPServerUser)
  owner:THttpServer;
  slot:integer;          // index into owner.fSlots, -1 if not registered
  generation:word;
  ctx:THttpContext;
  awaiting:boolean;      // a request was dispatched, response not yet sent
  deferred:boolean;      // parked long-poll
  deferDeadline:int64;
  wantClose:boolean;     // close after the current response is flushed
  keepAlive:boolean;
  lastActivity:int64;
  constructor Create; override;
  destructor Destroy; override;
  procedure onConnected; override;
  procedure onDataReceived(var buf:TBuffer); override;
  function  HandleValue:THttpReqHandle;
  procedure WriteRaw(const httpText:String8);
  procedure SendResponse(const body,mime,cacheControl:String8);
  procedure SendError(const status:String8);
  function  ProcessOne(const data:String8;out consumed:integer):boolean; // one request; false=incomplete
 end;

var
 // Set around fTCP.Poll so the parameterless TTCPServerUser.Create can find its owner.
 gActiveServer:THttpServer=nil;

// ============================================================================
//  Helpers
// ============================================================================
function EncodeHandle(slot:integer;generation:word):THttpReqHandle;
begin
 result:=THttpReqHandle((cardinal(generation) shl 16) or (cardinal(slot) and $FFFF));
end;

procedure DecodeHandle(handle:THttpReqHandle;out slot:integer;out generation:word);
begin
 slot:=integer(cardinal(handle) and $FFFF);
 generation:=word((cardinal(handle) shr 16) and $FFFF);
end;

function StatusCode(const status:String8):String8;
begin // first token of e.g. '404 Not Found' / '200 OK'
 result:=status;
 if result.IndexOf(' ')>0 then result:=copy(result,1,result.IndexOf(' ')-1);
end;

// ============================================================================
//  THttpContext
// ============================================================================
procedure THttpContext.Reset;
begin
 method:=''; uri:=''; query:=''; contentType:=''; body:=''; country:='';
 remoteIP:=0;
 parsed:=false;
 SetLength(parNames,0); SetLength(parValues,0);
 SetLength(hdrNames,0); SetLength(hdrValues,0);
 cookieLine:='';
end;

function THttpContext.Handle:THttpReqHandle;
begin
 result:=fHandle;
end;

procedure THttpContext.ParseParameters;
var
 ct,boundary,partHdr,partData,st:String8;
 pairs,parts:Strings8;
 i,c,p:integer;
begin
 if parsed then exit;
 parsed:=true;
 SetLength(parNames,0); SetLength(parValues,0);
 // POST body parameters
 if method.Same('POST') then begin
  ct:=contentType;
  if ct.Contains('application/x-www-form-urlencoded') then begin
   // fall through: treat body like a query string below
   pairs:=body.Split('&');
   SetLength(parNames,length(pairs)); SetLength(parValues,length(pairs));
   for i:=0 to high(pairs) do begin
    p:=pairs[i].IndexOf('=');
    if p>0 then begin
     parNames[i]:=copy(pairs[i],1,p-1).UrlDecode;
     parValues[i]:=copy(pairs[i],p+1,length(pairs[i])).UrlDecode;
    end else begin
     parNames[i]:=pairs[i].UrlDecode;
     parValues[i]:='TRUE';
    end;
   end;
   exit;
  end;
  if ct.Contains('multipart/form-data') then begin
   p:=ct.IndexOf('boundary=');
   if p>0 then begin
    boundary:=copy(ct,p+9,length(ct));
    parts:=body.Split(boundary); // simple split; good enough for form values
    c:=0;
    SetLength(parNames,length(parts)); SetLength(parValues,length(parts));
    for i:=0 to high(parts) do begin
     p:=parts[i].IndexOf(HDR_END);
     if p=0 then continue;
     partHdr:=copy(parts[i],1,p-1);
     partData:=copy(parts[i],p+4,length(parts[i])-(p+4)-1); // drop trailing CRLF
     st:=partHdr.ToLower;
     p:=st.IndexOf('name="');
     if p=0 then continue;
     st:=copy(partHdr,p+6,250);
     p:=st.IndexOf('"');
     if p=0 then continue;
     SetLength(st,p-1);
     parNames[c]:=st;
     parValues[c]:=partData;
     inc(c);
    end;
    SetLength(parNames,c); SetLength(parValues,c);
   end;
   exit;
  end;
 end;
 // GET query (also used when POST had no recognised form encoding)
 if query<>'' then begin
  pairs:=query.Split('&');
  SetLength(parNames,length(pairs)); SetLength(parValues,length(pairs));
  for i:=0 to high(pairs) do begin
   p:=pairs[i].IndexOf('=');
   if p>0 then begin
    parNames[i]:=copy(pairs[i],1,p-1).UrlDecode;
    parValues[i]:=copy(pairs[i],p+1,length(pairs[i])).UrlDecode;
   end else begin
    parNames[i]:=pairs[i].UrlDecode;
    parValues[i]:='TRUE';
   end;
  end;
 end;
end;

function THttpContext.Param(name:String8):String8;
var i:integer;
begin
 result:='';
 ParseParameters;
 for i:=0 to high(parNames) do
  if parNames[i].Same(name) then begin
   result:=parValues[i];
   exit;
  end;
end;

function THttpContext.HasParam(name:String8):boolean;
var i:integer;
begin
 result:=false;
 ParseParameters;
 for i:=0 to high(parNames) do
  if parNames[i].Same(name) then begin
   result:=true;
   exit;
  end;
end;

function THttpContext.Header(name:String8):String8;
var i:integer;
begin
 result:='';
 for i:=0 to high(hdrNames) do
  if hdrNames[i].Same(name) then begin
   result:=hdrValues[i];
   exit;
  end;
end;

function THttpContext.Cookie(name:String8):String8;
var
 list:Strings8;
 i,p:integer;
begin
 result:='';
 list:=cookieLine.Split(';');
 for i:=0 to high(list) do begin
  p:=list[i].IndexOf('=');
  if p>0 then
   if copy(list[i],1,p-1).Trim.Same(name) then begin
    result:=copy(list[i],p+1,length(list[i])).Trim;
    exit;
   end;
 end;
end;

procedure THttpContext.Respond(const body:String8;mime:String8;cacheControl:String8;compress:THttpCompress);
begin
 fServer.Respond(fHandle,body,mime,cacheControl,compress);
end;

procedure THttpContext.RespondError(status:String8);
begin
 fServer.RespondError(fHandle,status);
end;

procedure THttpContext.Defer(timeoutMS:integer);
var
 slot:integer;
 gen:word;
 c:THttpConn;
begin
 DecodeHandle(fHandle,slot,gen);
 if (slot<0) or (slot>high(fServer.fSlots)) then exit;
 if (not fServer.fSlots[slot].active) or (fServer.fSlots[slot].generation<>gen) then exit;
 c:=THttpConn(fServer.fSlots[slot].conn);
 if c=nil then exit;
 if timeoutMS<=0 then timeoutMS:=fServer.fDefaultDeferTimeout;
 c.deferred:=true;
 c.deferDeadline:=CoreTime.Ticks+timeoutMS;
end;

// ============================================================================
//  THttpConn
// ============================================================================
constructor THttpConn.Create;
begin
 inherited Create;
 slot:=-1;
 keepAlive:=true;
 ctx:=THttpContext.Create;
end;

destructor THttpConn.Destroy;
begin
 if (owner<>nil) and (slot>=0) then
  owner.ReleaseSlot(slot);
 FreeAndNil(ctx);
 inherited;
end;

procedure THttpConn.onConnected;
begin
 owner:=gActiveServer;
 if owner=nil then begin Disconnect; exit; end; // not pumped by a server? refuse
 lastActivity:=CoreTime.Ticks;
 if (owner.fMaxConnections>0) and (owner.ConnectionCount>=owner.fMaxConnections) then begin
  Disconnect; exit; // load cap
 end;
 if owner.IPPenalty(remoteIP)>=owner.fBanThreshold then begin
  Disconnect; exit; // banned IP
 end;
 owner.AcquireSlot(self);
 ctx.fServer:=owner;
end;

function THttpConn.HandleValue:THttpReqHandle;
begin
 result:=EncodeHandle(slot,generation);
end;

procedure THttpConn.WriteRaw(const httpText:String8);
var buf:TBuffer;
begin
 if httpText='' then exit;
 buf.CreateFrom(httpText);
 SendData(buf);
 lastActivity:=CoreTime.Ticks;
end;

procedure THttpConn.SendResponse(const body,mime,cacheControl:String8);
var
 m,cc,conn,resp:String8;
begin
 m:=mime; if m='' then m:='text/plain';
 cc:=cacheControl; if cc='' then cc:='no-cache';
 if keepAlive then conn:='Keep-Alive' else conn:='Close';
 resp:='HTTP/1.1 200 OK'+CRLF+
       'Content-Type: '+m+'; charset=utf-8'+CRLF+
       'Access-Control-Allow-Origin: *'+CRLF+
       'Cache-Control: '+cc+CRLF+
       'Connection: '+conn+CRLF+
       'Content-Length: '+Conv.ToStr(length(body))+CRLF+CRLF+
       body;
 WriteRaw(resp);
 awaiting:=false;
 deferred:=false;
 if not keepAlive then wantClose:=true;
end;

procedure THttpConn.SendError(const status:String8);
var html,resp:String8;
begin
 html:='<h2>'+status+'</h2>';
 resp:='HTTP/1.1 '+status+CRLF+
       'Access-Control-Allow-Origin: *'+CRLF+
       'Content-Type: text/html'+CRLF+
       'Connection: Close'+CRLF+
       'Content-Length: '+Conv.ToStr(length(html))+CRLF+CRLF+
       html;
 WriteRaw(resp);
 awaiting:=false;
 deferred:=false;
 wantClose:=true; // errors close the connection
end;

// Parse exactly one request from the front of data. Returns false if more bytes
// are needed (consumed=0). On success, fills ctx, dispatches onRequest and sets
// consumed to the number of bytes used by this request.
function THttpConn.ProcessOne(const data:String8;out consumed:integer):boolean;
var
 headEnd,bodyStart,contentLen,sp1,sp2,i,p:integer;
 head,reqLine,line,hname,hval,rawUri:String8;
 lines:Strings8;
begin
 result:=false; consumed:=0;
 headEnd:=data.IndexOf(HDR_END);
 if headEnd=0 then begin
  if length(data)>owner.fMaxRequestSize then SendError('413 Payload Too Large');
  exit; // headers not complete yet
 end;
 head:=copy(data,1,headEnd-1);
 bodyStart:=headEnd+4; // first body byte (1-based)

 lines:=head.Split(#10); // tolerate bare LF; CR is stripped below
 if length(lines)=0 then begin SendError('400 Bad Request'); consumed:=bodyStart-1; result:=true; exit; end;

 ctx.Reset;
 ctx.remoteIP:=remoteIP;
 // request line: METHOD SP URI SP HTTP/x.y
 reqLine:=lines[0]; if reqLine.EndsWith(#13) then SetLength(reqLine,length(reqLine)-1);
 sp1:=reqLine.IndexOf(' ');
 sp2:=reqLine.IndexOf(' ',sp1+1);
 if (sp1=0) or (sp2=0) then begin SendError('400 Bad Request'); consumed:=bodyStart-1; result:=true; exit; end;
 ctx.method:=copy(reqLine,1,sp1-1).ToUpper;
 rawUri:=copy(reqLine,sp1+1,sp2-sp1-1);
 // split off query
 p:=rawUri.IndexOf('?');
 if p>0 then begin
  ctx.query:=copy(rawUri,p+1,length(rawUri));
  SetLength(rawUri,p-1);
 end;
 if rawUri.StartsWith('/') then rawUri:=copy(rawUri,2,length(rawUri));
 ctx.uri:=rawUri.UrlDecode;

 // headers
 keepAlive:=true; // HTTP/1.1 default
 contentLen:=0;
 SetLength(ctx.hdrNames,length(lines)); SetLength(ctx.hdrValues,length(lines));
 i:=0;
 for p:=1 to high(lines) do begin
  line:=lines[p]; if line.EndsWith(#13) then SetLength(line,length(line)-1);
  if line='' then continue;
  sp1:=line.IndexOf(':');
  if sp1=0 then continue;
  hname:=copy(line,1,sp1-1).Trim;
  hval:=copy(line,sp1+1,length(line)).Trim;
  ctx.hdrNames[i]:=hname; ctx.hdrValues[i]:=hval; inc(i);
  if hname.Same('Content-Length') then contentLen:=hval.ToInteger
  else if hname.Same('Content-Type') then ctx.contentType:=hval.ToLower
  else if hname.Same('Cookie') then ctx.cookieLine:=hval
  else if hname.Same('Connection') then
   if hval.Contains('close',true) then keepAlive:=false;
 end;
 SetLength(ctx.hdrNames,i); SetLength(ctx.hdrValues,i);

 if contentLen<0 then contentLen:=0;
 if (contentLen>owner.fMaxRequestSize) or (bodyStart-1+contentLen>owner.fMaxRequestSize) then begin
  SendError('413 Payload Too Large'); consumed:=bodyStart-1; result:=true; exit;
 end;
 // need the whole body present
 if length(data)<bodyStart-1+contentLen then exit; // incomplete body

 if contentLen>0 then ctx.body:=copy(data,bodyStart,contentLen);
 consumed:=bodyStart-1+contentLen;
 result:=true;

 // resolve country lazily here (cheap, only when GeoIP enabled)
 if owner.fGeoIP then ctx.country:=GetCountryByIP(remoteIP);

 // dispatch
 ctx.fHandle:=HandleValue;
 awaiting:=true;
 deferred:=false;
 owner.PenalizeIP(remoteIP,owner.fRequestPenalty); // rate limiting
 if Assigned(owner.fOnRequest) then begin
  try
   owner.fOnRequest(ctx);
  except
   on e:Exception do begin
    Log.Warn('HttpServer onRequest error: '+ExceptionMsg(e));
    if awaiting then SendError('500 Internal Server Error');
   end;
  end;
 end;
 // handler that neither responded nor deferred: send empty 200 to keep protocol sane
 if awaiting and not deferred then SendResponse('','text/plain','');
end;

procedure THttpConn.onDataReceived(var buf:TBuffer);
var
 whole,chunk:String8;
 offset,consumed:integer;
begin
 lastActivity:=CoreTime.Ticks;
 if buf.size<=0 then exit;
 SetLength(whole,buf.size);
 move(buf.data^,whole[1],buf.size);
 offset:=0;
 while offset<length(whole) do begin
  chunk:=copy(whole,offset+1,length(whole)-offset);
  if not ProcessOne(chunk,consumed) then break; // incomplete: keep bytes for next read
  inc(offset,consumed);
  if wantClose or deferred then break; // stop pipelining on close/long-poll
 end;
 if offset>0 then buf.Skip(offset); // consume processed bytes; remainder stays buffered
end;

// ============================================================================
//  THttpServer
// ============================================================================
constructor THttpServer.Create(port:word;bindAll:boolean=false);
begin
 fDefaultDeferTimeout:=20000;
 fKeepAliveTimeout:=30000;
 fMaxRequestSize:=1 shl 20; // 1 MB
 fMaxConnections:=4096;
 fBanThreshold:=100;
 fRequestPenalty:=1;
 fPenaltyDecayPerSec:=10;
 fActiveCount:=0;
 fGeoIP:=false;
 fPenalties.Init(64);
 fTCP:=TTCPServer.Create(port,THttpConn,bindAll);
end;

destructor THttpServer.Destroy;
begin
 FreeAndNil(fTCP); // frees all connections (their Destroy releases slots)
 inherited;
end;

procedure THttpServer.AcquireSlot(conn:TObject);
var i,n:integer;
begin
 n:=-1;
 for i:=0 to high(fSlots) do
  if not fSlots[i].active then begin n:=i; break; end;
 if n<0 then begin
  n:=length(fSlots);
  SetLength(fSlots,n+1);
  fSlots[n].generation:=1; // start at 1 so handle 0 stays an "invalid" sentinel
 end;
 fSlots[n].conn:=conn;
 fSlots[n].active:=true;
 THttpConn(conn).slot:=n;
 THttpConn(conn).generation:=fSlots[n].generation;
 inc(fActiveCount);
end;

procedure THttpServer.ReleaseSlot(slot:integer);
begin
 if (slot<0) or (slot>high(fSlots)) then exit;
 if not fSlots[slot].active then exit;
 fSlots[slot].active:=false;
 fSlots[slot].conn:=nil;
 inc(fSlots[slot].generation); // invalidate outstanding handles
 dec(fActiveCount);
end;

function THttpServer.ConnFromHandle(handle:THttpReqHandle):TObject;
var slot:integer; gen:word;
begin
 result:=nil;
 DecodeHandle(handle,slot,gen);
 if (slot<0) or (slot>high(fSlots)) then exit;
 if (not fSlots[slot].active) or (fSlots[slot].generation<>gen) then exit;
 result:=fSlots[slot].conn;
end;

function THttpServer.IsAlive(handle:THttpReqHandle):boolean;
begin
 result:=ConnFromHandle(handle)<>nil;
end;

function THttpServer.ConnectionCount:integer;
begin
 result:=fActiveCount;
end;

procedure THttpServer.Respond(handle:THttpReqHandle;const body:String8;mime:String8;
   cacheControl:String8;compress:THttpCompress);
var c:THttpConn;
begin
 c:=THttpConn(ConnFromHandle(handle));
 if (c=nil) or (not c.awaiting) then exit;
 c.SendResponse(body,mime,cacheControl);
end;

procedure THttpServer.RespondError(handle:THttpReqHandle;status:String8);
var c:THttpConn;
begin
 c:=THttpConn(ConnFromHandle(handle));
 if (c=nil) or (not c.awaiting) then exit;
 c.SendError(status);
end;

procedure THttpServer.Close(handle:THttpReqHandle);
var c:THttpConn;
begin
 c:=THttpConn(ConnFromHandle(handle));
 if c<>nil then c.Disconnect;
end;

procedure THttpServer.PenalizeIP(ip:cardinal;weight:integer);
var rec:TIPRec;
begin
 IPPenaltyRec(ip,rec); // decays in place
 rec.penalty:=rec.penalty+weight;
 rec.tick:=CoreTime.Ticks;
 if rec.penalty<=0 then fPenalties.Remove(ip)
 else fPenalties.Put(ip,rec);
end;

// decayed penalty for ip; rec is the (decayed) record, valid to re-Put
procedure THttpServer.IPPenaltyRec(ip:cardinal;out rec:TIPRec);
var nowT,elapsed,d:int64;
begin
 rec.penalty:=0; rec.tick:=CoreTime.Ticks;
 if not fPenalties.Get(ip,rec) then exit;
 nowT:=CoreTime.Ticks;
 elapsed:=nowT-rec.tick;
 if (elapsed>0) and (fPenaltyDecayPerSec>0) then begin
  d:=(elapsed*fPenaltyDecayPerSec) div 1000;
  rec.penalty:=rec.penalty-integer(d);
  if rec.penalty<0 then rec.penalty:=0;
  rec.tick:=nowT;
 end;
end;

function THttpServer.IPPenalty(ip:cardinal):integer;
var rec:TIPRec;
begin
 IPPenaltyRec(ip,rec);
 result:=rec.penalty;
end;

procedure THttpServer.EnableGeoIP(dbPath:String8);
begin
 InitGeoIP(dbPath);
 fGeoIP:=true;
end;

procedure THttpServer.Poll;
var
 i:integer;
 c:THttpConn;
 nowT:int64;
 body:String8;
begin
 gActiveServer:=self;
 try
  fTCP.Poll; // accept + read (→dispatch) + flush + reap dead connections
 finally
  gActiveServer:=nil;
 end;
 // maintenance: expire deferred long-polls, reap idle keep-alive connections,
 // close connections that asked to close once their data is flushed.
 nowT:=CoreTime.Ticks;
 for i:=0 to high(fSlots) do begin
  if not fSlots[i].active then continue;
  c:=THttpConn(fSlots[i].conn);
  if c=nil then continue;
  if c.deferred and (nowT>=c.deferDeadline) then begin
   body:='';
   if Assigned(fOnDeferExpired) then body:=fOnDeferExpired(c.HandleValue);
   c.SendResponse(body,'text/plain','');  // empty 200 => client re-polls
   continue;
  end;
  if c.wantClose and not c.awaiting then begin
   c.Disconnect;
   continue;
  end;
  if (not c.deferred) and (not c.awaiting) and (fKeepAliveTimeout>0) and
     (nowT-c.lastActivity>fKeepAliveTimeout) then
   c.Disconnect; // idle keep-alive reaping
 end;
end;

end.
