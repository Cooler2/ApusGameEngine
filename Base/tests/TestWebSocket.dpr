{$APPTYPE CONSOLE}
// Tests for Apus.WebSocket (RFC 6455 codec and session) and SHA-1 from Apus.Crypto.
// No network: frames are fed through in-memory buffers.
program TestWebSocket;
uses
  SysUtils,
  Apus.Core,
  Apus.Types,
  Apus.Strings,
  Apus.Conv,
  Apus.Crypto,
  Apus.WebSocket;

{$INCLUDE Test.inc}

// --- helpers ---

function Bytes(const a:array of byte):ByteArray;
var
  i:integer;
begin
  SetLength(result,length(a));
  for i:=0 to high(a) do result[i]:=a[i];
end;

function BytesOf(const s:String8):ByteArray;
begin
  SetLength(result,length(s));
  if s<>'' then move(s[1],result[0],length(s));
end;

function JoinBytes(const a,b:ByteArray):ByteArray;
begin
  SetLength(result,length(a)+length(b));
  if length(a)>0 then move(a[0],result[0],length(a));
  if length(b)>0 then move(b[0],result[length(a)],length(b));
end;

function SameBytes(const a:ByteArray;const b:array of byte):boolean;
var
  i:integer;
begin
  result:=length(a)=length(b);
  if result then
    for i:=0 to high(b) do
      if a[i]<>b[i] then exit(false);
end;

function DigestHex(const d:TSHA1Digest):string;
var
  i:integer;
begin
  result:='';
  for i:=0 to high(d) do result:=result+LowerCase(IntToHex(d[i],2));
end;

type
  // Feeds a byte stream to a parser in chunks of a given size, as a socket would
  TParseRun=record
    msgs:array of TWsMessage;
    lastResult:TWsParseResult;
    procedure Run(var parser:TWsParser;const stream:ByteArray;chunk:integer);
  end;

procedure TParseRun.Run(var parser:TWsParser;const stream:ByteArray;chunk:integer);
var
  pending:ByteArray;
  pos,n,consumed:integer;
  buf:TBuffer;
  msg:TWsMessage;
begin
  msgs:=nil;
  pending:=nil;
  pos:=0;
  lastResult:=TWsParseResult.NeedMore;
  while pos<length(stream) do begin
    n:=Min(chunk,length(stream)-pos);
    pending:=JoinBytes(pending,copy(stream,pos,n));
    inc(pos,n);
    buf.Create(@pending[0],length(pending));
    repeat
      lastResult:=parser.Next(buf,msg);
      if lastResult=TWsParseResult.Message then begin
        SetLength(msgs,length(msgs)+1);
        msgs[high(msgs)]:=msg;
      end;
    until lastResult<>TWsParseResult.Message;
    if lastResult=TWsParseResult.Error then exit;
    consumed:=buf.CurrentPos;
    pending:=copy(pending,consumed,length(pending)-consumed);
  end;
end;

function ParseAll(role:TWsRole;const stream:ByteArray;chunk:integer;out run:TParseRun;
  maxSize:integer=1 shl 20):TWsParser;
begin
  result.Init(role,maxSize);
  run.Run(result,stream,chunk);
end;

// --- SHA-1 ---

procedure TestSHA1;
var
  s:RawByteString;
begin
  StartTest('SHA-1 vectors');
  Check(DigestHex(SHA1(''))='da39a3ee5e6b4b0d3255bfef95601890afd80709','empty');
  Check(DigestHex(SHA1('abc'))='a9993e364706816aba3e25717850c26c9cd0d89d','abc');
  Check(DigestHex(SHA1('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'))=
    '84983e441c3bd26ebaae4aa1f95129e5e54670f1','56 bytes (two padding blocks)');
  s:=StringOfChar(AnsiChar('a'),1000000);
  Check(DigestHex(SHA1(s))='34aa973cd4c4daa4f61eeb2bdbad27316534016f','million a');
  EndTest;
end;

// --- UTF-8 validation (pointer overload) ---

procedure TestUTF8Pointer;
var
  b:ByteArray;
begin
  StartTest('UTF8.IsValid(pointer,size)');
  b:=BytesOf('Привет, мир');
  Check(UTF8.IsValid(@b[0],length(b)),'valid Cyrillic');
  Check(UTF8.IsValid(nil,0),'empty');
  b:=Bytes([$C0,$AF]);
  Check(not UTF8.IsValid(@b[0],length(b)),'overlong');
  b:=Bytes([$ED,$A0,$80]);
  Check(not UTF8.IsValid(@b[0],length(b)),'surrogate');
  b:=Bytes([$F4,$90,$80,$80]);
  Check(not UTF8.IsValid(@b[0],length(b)),'above U+10FFFF');
  b:=Bytes([$61,$62,$D0]);
  Check(not UTF8.IsValid(@b[0],length(b)),'truncated sequence');
  Check(UTF8.IsValid(@b[0],2),'size limits the check');
  EndTest;
end;

// --- RFC 6455 section 5.7 examples ---

procedure TestRfcExamples;
var
  run:TParseRun;
  p:TWsParser;
  data,stream:ByteArray;
  i:integer;
begin
  StartTest('RFC 6455 5.7 examples');
  // single-frame unmasked text (server to client)
  p:=ParseAll(TWsRole.Client,Bytes([$81,$05,$48,$65,$6c,$6c,$6f]),100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Text) and
    (run.msgs[0].Text='Hello'),'unmasked text');
  // single-frame masked text (client to server)
  p:=ParseAll(TWsRole.Server,Bytes([$81,$85,$37,$fa,$21,$3d,$7f,$9f,$4d,$51,$58]),100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].Text='Hello'),'masked text');
  // fragmented unmasked text
  p:=ParseAll(TWsRole.Client,Bytes([$01,$03,$48,$65,$6c,$80,$02,$6c,$6f]),100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Text) and
    (run.msgs[0].Text='Hello'),'fragmented text');
  // unmasked ping, masked pong
  p:=ParseAll(TWsRole.Client,Bytes([$89,$05,$48,$65,$6c,$6c,$6f]),100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Ping) and
    (run.msgs[0].Text='Hello'),'ping');
  p:=ParseAll(TWsRole.Server,Bytes([$8a,$85,$37,$fa,$21,$3d,$7f,$9f,$4d,$51,$58]),100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Pong) and
    (run.msgs[0].Text='Hello'),'pong');
  // 256 bytes binary: 16-bit length
  SetLength(data,256);
  for i:=0 to high(data) do data[i]:=i;
  stream:=JoinBytes(Bytes([$82,$7E,$01,$00]),data);
  p:=ParseAll(TWsRole.Client,stream,100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Binary) and
    (length(run.msgs[0].data)=256) and (run.msgs[0].data[255]=255),'256 bytes binary');
  // 64 KiB binary: 64-bit length
  SetLength(data,65536);
  for i:=0 to high(data) do data[i]:=i and $FF;
  stream:=JoinBytes(Bytes([$82,$7F,0,0,0,0,0,1,0,0]),data);
  p:=ParseAll(TWsRole.Client,stream,4096,run);
  Check((length(run.msgs)=1) and (length(run.msgs[0].data)=65536) and
    (run.msgs[0].data[65535]=$FF),'64 KiB binary');
  // the encoder produces exactly the RFC bytes when unmasked
  Check(SameBytes(WsEncodeFrame(TWsOpcode.Text,String8('Hello'),false),
    [$81,$05,$48,$65,$6c,$6c,$6f]),'encode unmasked text');
  Check(SameBytes(WsEncodeFrame(TWsOpcode.Text,String8('Hel'),false,false),[$01,$03,$48,$65,$6c]) and
    SameBytes(WsEncodeFrame(TWsOpcode.Continuation,String8('lo'),false),[$80,$02,$6c,$6f]),
    'encode fragments');
  EndTest;
end;

// --- encoder/parser round trip over all length forms, byte-by-byte arrival ---

procedure TestRoundTrip;
const
  SIZES:array[0..6] of integer=(0,1,125,126,65535,65536,70000);
var
  run:TParseRun;
  p:TWsParser;
  data,frame:ByteArray;
  i,j,hdr:integer;
  ok:boolean;
begin
  StartTest('Round trip of length forms');
  for i:=0 to high(SIZES) do begin
    SetLength(data,SIZES[i]);
    for j:=0 to high(data) do data[j]:=(j*7) and $FF;
    frame:=WsEncodeFrame(TWsOpcode.Binary,data,true);
    if SIZES[i]>65535 then hdr:=14 else if SIZES[i]>=126 then hdr:=8 else hdr:=6;
    Check(length(frame)=hdr+SIZES[i],'header size for '+IntToStr(SIZES[i]));
    p:=ParseAll(TWsRole.Server,frame,1000,run);
    ok:=(length(run.msgs)=1) and (length(run.msgs[0].data)=SIZES[i]);
    if ok then
      for j:=0 to high(data) do
        if run.msgs[0].data[j]<>data[j] then begin ok:=false; break; end;
    Check(ok,'masked round trip of '+IntToStr(SIZES[i])+' bytes');
  end;
  // masking really changes the bytes on the wire
  frame:=WsEncodeFrame(TWsOpcode.Text,String8('AAAAAAAA'),true);
  Check((frame[1] and $80)<>0,'mask bit set');
  EndTest;

  StartTest('Byte-by-byte arrival, ping between fragments');
  frame:=JoinBytes(WsEncodeFrame(TWsOpcode.Text,String8('Hel'),true,false),
         JoinBytes(WsEncodeFrame(TWsOpcode.Ping,String8('p'),true),
         JoinBytes(WsEncodeFrame(TWsOpcode.Continuation,String8('lo, '),true,false),
         JoinBytes(WsEncodeFrame(TWsOpcode.Continuation,String8('мир'),true),
                WsEncodeFrame(TWsOpcode.Binary,Bytes([1,2,3]),true)))));
  p:=ParseAll(TWsRole.Server,frame,1,run);
  Check(run.lastResult=TWsParseResult.NeedMore,'no error');
  Check(length(run.msgs)=3,'three messages');
  if length(run.msgs)=3 then begin
    Check((run.msgs[0].opcode=TWsOpcode.Ping) and (run.msgs[0].Text='p'),'ping first');
    Check((run.msgs[1].opcode=TWsOpcode.Text) and (run.msgs[1].Text='Hello, мир'),'reassembled text');
    Check((run.msgs[2].opcode=TWsOpcode.Binary) and SameBytes(run.msgs[2].data,[1,2,3]),'binary after it');
  end;
  EndTest;
end;

// --- protocol errors ---

// textPart - a fragment of errorText, to tell apart errors with the same code
procedure ExpectError(role:TWsRole;const stream:ByteArray;code:word;const name:string;
  maxSize:integer=1 shl 20;const textPart:String8='');
var
  run:TParseRun;
  p:TWsParser;
  buf:TBuffer;
  msg:TWsMessage;
begin
  p:=ParseAll(role,stream,1000,run,maxSize);
  Check((run.lastResult=TWsParseResult.Error) and (p.errorCode=code) and
    ((textPart='') or p.errorText.Contains(textPart)),
    name+': expected '+IntToStr(code)+', got '+IntToStr(p.errorCode)+' '+string(p.errorText));
  // the parser stays failed
  buf.Create(@stream[0],length(stream));
  Check(p.Next(buf,msg)=TWsParseResult.Error,name+': stays failed');
end;

procedure TestErrors;
var
  big:ByteArray;
  run:TParseRun;
  p:TWsParser;
begin
  StartTest('Protocol errors');
  ExpectError(TWsRole.Client,Bytes([$C1,$00]),WS_CLOSE_PROTOCOL_ERROR,'RSV1 set');
  ExpectError(TWsRole.Client,Bytes([$83,$00]),WS_CLOSE_PROTOCOL_ERROR,'opcode 3');
  ExpectError(TWsRole.Client,Bytes([$8B,$00]),WS_CLOSE_PROTOCOL_ERROR,'opcode 11');
  ExpectError(TWsRole.Server,Bytes([$81,$01,$41]),WS_CLOSE_PROTOCOL_ERROR,'unmasked to server');
  ExpectError(TWsRole.Client,Bytes([$81,$81,0,0,0,0,$41]),WS_CLOSE_PROTOCOL_ERROR,'masked to client');
  ExpectError(TWsRole.Client,Bytes([$89,$7E,$00,$7E]),WS_CLOSE_PROTOCOL_ERROR,'ping over 125');
  ExpectError(TWsRole.Client,Bytes([$09,$00]),WS_CLOSE_PROTOCOL_ERROR,'fragmented ping');
  ExpectError(TWsRole.Client,Bytes([$80,$01,$41]),WS_CLOSE_PROTOCOL_ERROR,'continuation first');
  ExpectError(TWsRole.Client,Bytes([$01,$01,$41,$81,$01,$42]),WS_CLOSE_PROTOCOL_ERROR,
    'text inside fragmented text');
  ExpectError(TWsRole.Client,Bytes([$82,$7F,$80,0,0,0,0,0,0,1]),WS_CLOSE_PROTOCOL_ERROR,
    '64-bit length with MSB');
  ExpectError(TWsRole.Client,Bytes([$81,$02,$C0,$AF]),WS_CLOSE_INVALID_DATA,'overlong UTF-8');
  ExpectError(TWsRole.Client,Bytes([$01,$01,$E2,$80,$02,$82,$41]),WS_CLOSE_INVALID_DATA,
    'invalid UTF-8 across fragments');
  ExpectError(TWsRole.Client,Bytes([$88,$01,$03]),WS_CLOSE_PROTOCOL_ERROR,'close with 1 byte');
  ExpectError(TWsRole.Client,Bytes([$88,$02,$03,$ED]),WS_CLOSE_PROTOCOL_ERROR,'close code 1005');
  ExpectError(TWsRole.Client,Bytes([$88,$02,$03,$E7]),WS_CLOSE_PROTOCOL_ERROR,'close code 999');
  ExpectError(TWsRole.Client,Bytes([$88,$04,$03,$E8,$C0,$AF]),WS_CLOSE_INVALID_DATA,
    'close reason not UTF-8');
  // size limit: fails on the header, before the payload arrives
  ExpectError(TWsRole.Client,Bytes([$82,$7F,0,0,0,0,0,$20,0,0]),WS_CLOSE_TOO_BIG,
    'declared 2 MB, header only');
  big:=JoinBytes(WsEncodeFrame(TWsOpcode.Binary,StringOfChar(AnsiChar('x'),600),false,false),
              WsEncodeFrame(TWsOpcode.Continuation,StringOfChar(AnsiChar('x'),600),false));
  ExpectError(TWsRole.Client,big,WS_CLOSE_TOO_BIG,'fragments over the limit',1000);
  // the length must take the shortest form: fails on the header; the smallest valid values pass
  ExpectError(TWsRole.Client,Bytes([$82,$7E,$00,$7D]),WS_CLOSE_PROTOCOL_ERROR,
    '16-bit length 125',1 shl 20,'Non-minimal');
  ExpectError(TWsRole.Client,Bytes([$82,$7F,0,0,0,0,0,0,$FF,$FF]),WS_CLOSE_PROTOCOL_ERROR,
    '64-bit length 65535',1 shl 20,'Non-minimal');
  SetLength(big,126);
  p:=ParseAll(TWsRole.Client,JoinBytes(Bytes([$82,$7E,$00,$7E]),big),1000,run);
  Check((length(run.msgs)=1) and (length(run.msgs[0].data)=126),'16-bit length 126');
  SetLength(big,65536);
  p:=ParseAll(TWsRole.Client,JoinBytes(Bytes([$82,$7F,0,0,0,0,0,1,0,0]),big),100000,run);
  Check((length(run.msgs)=1) and (length(run.msgs[0].data)=65536),'64-bit length 65536');
  EndTest;
end;

// --- close frames ---

procedure TestCloseFrames;
var
  run:TParseRun;
  p:TWsParser;
  reason:String8;
  frame:ByteArray;
  i:integer;
begin
  StartTest('Close frames');
  p:=ParseAll(TWsRole.Server,WsEncodeClose(WS_CLOSE_GOING_AWAY,'bye',true),100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Close) and
    (run.msgs[0].closeCode=WS_CLOSE_GOING_AWAY) and (run.msgs[0].Text='bye'),'code and reason');
  p:=ParseAll(TWsRole.Client,WsEncodeClose(WS_CLOSE_NO_STATUS,'ignored',false),100,run);
  Check((length(run.msgs)=1) and (run.msgs[0].closeCode=WS_CLOSE_NO_STATUS) and
    (length(run.msgs[0].data)=0),'empty close');
  // a long reason is cut on a character boundary: 70 two-byte characters = 140 bytes
  // 'я' = D1 8F, set byte by byte: Delphi converts a char literal through the ANSI code page
  SetLength(reason,140);
  for i:=0 to 69 do begin
    reason[i*2+1]:=AnsiChar($D1);
    reason[i*2+2]:=AnsiChar($8F);
  end;
  frame:=WsEncodeClose(WS_CLOSE_NORMAL,reason,false);
  Check(length(frame)=2+2+122,'payload cut to 124 bytes');
  p:=ParseAll(TWsRole.Client,frame,100,run);
  Check((length(run.msgs)=1) and (length(run.msgs[0].data)=122),'reason is still valid UTF-8');
  EndTest;
end;

// --- handshake ---

// WsCheckResponse on a complete response
function CheckResponse(const response,key,protocols:String8;out protocol:String8):TWsHandshakeResult;
var
  stream:ByteArray;
  buf:TBuffer;
  error:String8;
begin
  stream:=BytesOf(response);
  buf.Create(@stream[0],length(stream));
  result:=WsCheckResponse(buf,key,protocols,protocol,error);
end;

procedure TestHandshake;
var
  key,request,response,protocol,error:String8;
  stream,frame:ByteArray;
  buf:TBuffer;
  run:TParseRun;
  p:TWsParser;
  n:integer;
  res:TWsHandshakeResult;
begin
  StartTest('Handshake');
  Check(WsAcceptKey('dGhlIHNhbXBsZSBub25jZQ==')='s3pPLMBiTxaQ9kYGzzhZRbK+xOo=','RFC 1.3 accept key');
  key:=WsNewClientKey;
  Check((length(key)=24) and key.EndsWith('=='),'client key is base64 of 16 bytes');
  Check(key<>WsNewClientKey,'client keys differ');
  request:=WsClientRequest('example.com:8080','/chat?room=1',key,'game.v1','Origin: http://example.com'#13#10);
  Check(request.StartsWith('GET /chat?room=1 HTTP/1.1'#13#10),'request line');
  Check(request.Contains(#13#10'Sec-WebSocket-Key: '+key+#13#10) and
    request.Contains(#13#10'Sec-WebSocket-Protocol: game.v1'#13#10) and
    request.Contains(#13#10'Origin: http://example.com'#13#10) and
    request.EndsWith(#13#10#13#10),'request headers');
  // server-side checks
  Check(WsCheckRequest('GET','websocket','Upgrade','13',key,error) and (error=''),'valid request');
  Check(WsCheckRequest('GET','WebSocket','keep-alive, Upgrade','13',key,error),'token lists, case');
  Check(not WsCheckRequest('POST','websocket','Upgrade','13',key,error) and
    (error='405 Method Not Allowed'),'POST');
  Check(not WsCheckRequest('GET','h2c','Upgrade','13',key,error) and (error='400 Bad Request'),'wrong upgrade');
  Check(not WsCheckRequest('GET','websocket','keep-alive','13',key,error),'no Connection: Upgrade');
  Check(not WsCheckRequest('GET','websocket','Upgrade','8',key,error) and
    (error='426 Upgrade Required'),'old version');
  Check(not WsCheckRequest('GET','websocket','Upgrade','13','short',error),'bad key');
  // client-side check of the server response, with a frame right behind it
  response:=WsServerResponse(key,'game.v1');
  frame:=WsEncodeFrame(TWsOpcode.Text,String8('hi'),false);
  stream:=JoinBytes(BytesOf(response),frame);
  buf.Create(@stream[0],length(response)-3);
  Check(WsCheckResponse(buf,key,'game.v1',protocol,error)=TWsHandshakeResult.NeedMore,'partial response');
  Check(buf.CurrentPos=0,'nothing consumed while partial');
  buf.Create(@stream[0],length(stream));
  Check(WsCheckResponse(buf,key,'game.v1',protocol,error)=TWsHandshakeResult.Accepted,'accepted: '+error);
  Check(protocol='game.v1','selected protocol');
  Check(buf.CurrentPos=length(response),'only the header consumed');
  p.Init(TWsRole.Client);
  run.Run(p,copy(stream,length(response),length(frame)),100);
  Check((length(run.msgs)=1) and (run.msgs[0].Text='hi'),'frame after the header');
  // rejections
  stream:=BytesOf(WsServerResponse(WsNewClientKey));
  buf.Create(@stream[0],length(stream));
  Check(WsCheckResponse(buf,key,'',protocol,error)=TWsHandshakeResult.Rejected,'wrong accept key');
  stream:=BytesOf('HTTP/1.1 403 Forbidden'#13#10'Content-Length: 0'#13#10#13#10);
  buf.Create(@stream[0],length(stream));
  Check((WsCheckResponse(buf,key,'',protocol,error)=TWsHandshakeResult.Rejected) and
    error.Contains('403'),'refused upgrade');
  EndTest;

  StartTest('Handshake: subprotocol');
  Check((CheckResponse(WsServerResponse(key,'game.v2'),key,'game.v1, game.v2',protocol)=
    TWsHandshakeResult.Accepted) and (protocol='game.v2'),'one of the offered');
  Check((CheckResponse(WsServerResponse(key),key,'game.v1',protocol)=TWsHandshakeResult.Accepted) and
    (protocol=''),'none selected');
  Check(CheckResponse(WsServerResponse(key,'chat'),key,'game.v1',protocol)=TWsHandshakeResult.Rejected,
    'not offered');
  Check(CheckResponse(WsServerResponse(key,'game.v1'),key,'',protocol)=TWsHandshakeResult.Rejected,
    'none offered');
  Check(CheckResponse(WsServerResponse(key,'Game.V1'),key,'game.v1',protocol)=TWsHandshakeResult.Rejected,
    'case differs');
  Check(CheckResponse(WsServerResponse(key,'game.v1, game.v2'),key,'game.v1, game.v2',protocol)=
    TWsHandshakeResult.Rejected,'a list instead of one');
  response:=WsServerResponse(key,'game.v1');
  response:=copy(response,1,length(response)-2)+'Sec-WebSocket-Protocol: game.v1'#13#10#13#10;
  Check(CheckResponse(response,key,'game.v1',protocol)=TWsHandshakeResult.Rejected,'two headers');
  EndTest;

  StartTest('Handshake: header size limit');
  response:=WsServerResponse(key);
  response:=copy(response,1,length(response)-2)+'X-Pad: '+String8(StringOfChar(AnsiChar('a'),15000))+
    #13#10#13#10;
  Check(CheckResponse(response,key,'',protocol)=TWsHandshakeResult.Accepted,'under the limit');
  response:=WsServerResponse(key);
  response:=copy(response,1,length(response)-2)+'X-Pad: '+String8(StringOfChar(AnsiChar('a'),17000))+
    #13#10#13#10;
  Check(CheckResponse(response,key,'',protocol)=TWsHandshakeResult.Rejected,'over the limit, whole');
  // the same response arriving in parts: the same verdict
  stream:=BytesOf(response);
  n:=0;
  repeat
    n:=Min(n+1000,length(stream));
    buf.Create(@stream[0],n);
    res:=WsCheckResponse(buf,key,'',protocol,error);
  until (res<>TWsHandshakeResult.NeedMore) or (n=length(stream));
  Check(res=TWsHandshakeResult.Rejected,'over the limit, in parts');
  EndTest;
end;

// --- session ---

// Move all pending output of one session into the other
procedure Pump(src,dst:TWsSession);
var
  data:ByteArray;
  buf:TBuffer;
begin
  if not src.TakeOutput(data) then exit;
  buf.Create(@data[0],length(data));
  dst.Feed(buf);
  Check(buf.BytesLeft=0,'all bytes consumed');
end;

procedure TestSession;
var
  client,server:TWsSession;
  msg:TWsMessage;
  data,big,frame:ByteArray;
  buf:TBuffer;
  run:TParseRun;
  p:TWsParser;
  i:integer;
  ok:boolean;
begin
  StartTest('Session: messages both ways');
  client:=TWsSession.Create(TWsRole.Client);
  server:=TWsSession.Create(TWsRole.Server);
  try
    client.SendText('hello');
    client.Send(Bytes([1,2,3]));
    Pump(client,server);
    Check(server.Receive(msg) and (msg.opcode=TWsOpcode.Text) and (msg.Text='hello'),'text to server');
    Check(server.Receive(msg) and (msg.opcode=TWsOpcode.Binary) and SameBytes(msg.data,[1,2,3]),'binary to server');
    Check(not server.Receive(msg),'queue empty');
    server.SendText('welcome');
    Pump(server,client);
    Check(client.Receive(msg) and (msg.Text='welcome'),'text to client');
    // the queue survives interleaved receive/grow (compaction keeps the order)
    for i:=1 to 3 do server.SendText(IntToStr(i));
    Pump(server,client);
    client.Receive(msg);
    client.Receive(msg);
    for i:=4 to 10 do server.SendText(IntToStr(i));
    Pump(server,client);
    ok:=true;
    for i:=3 to 10 do
      if not client.Receive(msg) or (msg.Text<>IntToStr(i)) then ok:=false;
    Check(ok and not client.Receive(msg),'order kept');
  finally
    client.Free;
    server.Free;
  end;
  EndTest;

  StartTest('Session: ping is answered');
  server:=TWsSession.Create(TWsRole.Server);
  try
    data:=WsEncodeFrame(TWsOpcode.Ping,String8('42'),true);
    buf.Create(@data[0],length(data));
    server.Feed(buf);
    Check(not server.Receive(msg),'ping is not queued');
    Check(server.TakeOutput(data),'pong produced');
    p:=ParseAll(TWsRole.Client,data,100,run);
    Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Pong) and (run.msgs[0].Text='42'),
      'pong echoes the payload');
  finally
    server.Free;
  end;
  EndTest;

  StartTest('Session: close handshake');
  client:=TWsSession.Create(TWsRole.Client);
  server:=TWsSession.Create(TWsRole.Server);
  try
    client.Close(WS_CLOSE_NORMAL,'bye');
    Check(client.state=TWsState.Closing,'client closing');
    client.SendText('late');
    Pump(client,server);
    Check(server.state=TWsState.Closed,'server closed');
    Check((server.closeCode=WS_CLOSE_NORMAL) and (server.closeReason='bye'),'server sees code and reason');
    Check(not server.Receive(msg),'nothing sent after Close');
    Pump(server,client);
    Check((client.state=TWsState.Closed) and (client.closeCode=WS_CLOSE_NORMAL),'client closed by the echo');
  finally
    client.Free;
    server.Free;
  end;
  EndTest;

  StartTest('Session: ping while closing');
  client:=TWsSession.Create(TWsRole.Client);
  server:=TWsSession.Create(TWsRole.Server);
  try
    server.Close;
    server.TakeOutput(data); // the Close frame, not delivered: the client keeps talking
    client.Ping;
    Pump(client,server);
    Check(server.state=TWsState.Closing,'still closing');
    Check(server.TakeOutput(data),'pong while closing');
    p:=ParseAll(TWsRole.Client,data,100,run);
    Check((length(run.msgs)=1) and (run.msgs[0].opcode=TWsOpcode.Pong),'pong frame');
    client.Close(WS_CLOSE_GOING_AWAY);
    Pump(client,server);
    Check((server.state=TWsState.Closed) and (server.closeCode=WS_CLOSE_GOING_AWAY),'closed by the peer''s Close');
    Check(not server.TakeOutput(data),'no second Close');
  finally
    client.Free;
    server.Free;
  end;
  EndTest;

  StartTest('Session: protocol error closes');
  server:=TWsSession.Create(TWsRole.Server);
  try
    data:=WsEncodeFrame(TWsOpcode.Text,String8('x'),false); // unmasked from a client
    buf.Create(@data[0],length(data));
    server.Feed(buf);
    Check((server.state=TWsState.Closed) and (server.closeCode=WS_CLOSE_PROTOCOL_ERROR),'closed with 1002');
    Check(server.TakeOutput(data),'close frame produced');
    p:=ParseAll(TWsRole.Client,data,100,run);
    Check((length(run.msgs)=1) and (run.msgs[0].closeCode=WS_CLOSE_PROTOCOL_ERROR),'close frame carries 1002');
    server.SendText('ignored');
    Check(not server.TakeOutput(data),'no output after Closed');
  finally
    server.Free;
  end;
  EndTest;

  StartTest('Session: keepalive and timeouts');
  server:=TWsSession.Create(TWsRole.Server);
  try
    server.pingInterval:=1000;
    server.pongTimeout:=500;
    server.Tick(10000);
    server.Tick(10900);
    Check(not server.TakeOutput(data),'no ping before the interval');
    server.Tick(11000);
    Check(server.TakeOutput(data) and (data[0]=$89),'ping after the interval');
    // the peer answers: the timer restarts
    data:=WsEncodeFrame(TWsOpcode.Pong,nil,0,true);
    buf.Create(@data[0],length(data));
    server.Feed(buf);
    server.Tick(11400);
    server.Tick(12300);
    Check(server.state=TWsState.Open,'alive after pong');
    Check(not server.TakeOutput(data),'next ping not yet due');
    server.Tick(12400);
    Check(server.TakeOutput(data),'second ping');
    server.Tick(12899);
    Check(server.state=TWsState.Open,'waiting for pong');
    server.Tick(12900);
    Check((server.state=TWsState.Closed) and (server.closeCode=WS_CLOSE_ABNORMAL),'pong timeout');
  finally
    server.Free;
  end;
  server:=TWsSession.Create(TWsRole.Server);
  try
    server.closeTimeout:=300;
    server.Close;
    server.Tick(5000);
    server.Tick(5299);
    Check(server.state=TWsState.Closing,'waiting for the peer''s Close');
    server.Tick(5300);
    Check((server.state=TWsState.Closed) and (server.closeCode=WS_CLOSE_ABNORMAL),'close timeout');
  finally
    server.Free;
  end;
  // a long frame arriving in parts keeps the session alive, though no message completes
  server:=TWsSession.Create(TWsRole.Server);
  try
    server.pingInterval:=1000;
    server.pongTimeout:=500;
    SetLength(big,10000);
    frame:=WsEncodeFrame(TWsOpcode.Binary,big,true);
    server.Tick(10000);
    server.Tick(11000);
    Check(server.TakeOutput(data),'ping sent');
    buf.Create(@frame[0],length(frame) div 2);
    server.Feed(buf);
    server.Tick(11600);
    Check(server.state=TWsState.Open,'partial frame counts as activity');
    buf.Create(@frame[0],length(frame));
    server.Feed(buf);
    Check(server.Receive(msg) and (length(msg.data)=10000),'frame completed');
  finally
    server.Free;
  end;
  client:=TWsSession.Create(TWsRole.Client);
  try
    client.ConnectionLost;
    Check((client.state=TWsState.Closed) and (client.closeCode=WS_CLOSE_ABNORMAL),'connection lost');
  finally
    client.Free;
  end;
  EndTest;
end;

begin
  try
    TestSHA1;
    TestUTF8Pointer;
    TestRfcExamples;
    TestRoundTrip;
    TestErrors;
    TestCloseFrames;
    TestHandshake;
    TestSession;
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
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
