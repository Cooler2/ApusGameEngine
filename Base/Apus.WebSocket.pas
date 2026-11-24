// WebSocket protocol (RFC 6455) without sockets: opening handshake, frame encoding,
// incremental frame parsing and the connection state (TWsSession). Transport-agnostic:
// feed received bytes in, send the produced bytes over any byte stream (Apus.TCP, TLS, ...).
// Copyright (C) 2026 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (https://github.com/Cooler2/ApusGameEngine)
{$I defines.inc}
unit Apus.WebSocket;
interface
uses Apus.Core, Apus.Types;

const
  // Close status codes (RFC 6455 7.4.1)
  WS_CLOSE_NORMAL         = 1000;
  WS_CLOSE_GOING_AWAY     = 1001;
  WS_CLOSE_PROTOCOL_ERROR = 1002;
  WS_CLOSE_UNSUPPORTED    = 1003; // data type the endpoint can't accept
  WS_CLOSE_NO_STATUS      = 1005; // reserved: close frame without a code, never sent
  WS_CLOSE_ABNORMAL       = 1006; // reserved: dropped without a close frame, never sent
  WS_CLOSE_INVALID_DATA   = 1007; // e.g. a text message is not valid UTF-8
  WS_CLOSE_POLICY         = 1008;
  WS_CLOSE_TOO_BIG        = 1009;
  WS_CLOSE_INTERNAL_ERROR = 1011;

  WS_MAX_CONTROL_PAYLOAD = 125;

type
  {$SCOPEDENUMS ON}
  TWsOpcode=(Continuation=0,Text=1,Binary=2,Close=8,Ping=9,Pong=10);
  // Client masks outgoing frames and rejects masked incoming ones; server - the opposite
  TWsRole=(Server,Client);
  TWsParseResult=(NeedMore,Message,Error);
  TWsHandshakeResult=(NeedMore,Accepted,Rejected);
  {$SCOPEDENUMS OFF}

  // One complete data message or one control frame
  TWsMessage=record
    opcode:TWsOpcode;  // Text, Binary, Close, Ping or Pong (never Continuation)
    data:ByteArray;    // unmasked payload; for Close - the reason (without the code)
    closeCode:word;    // Close only: status code, WS_CLOSE_NO_STATUS if the frame has none
    function Text:String8; // data as a string (Text message, Close reason); copies
  end;

  // Incremental frame parser for one connection: unmasks, reassembles fragmented messages
  // and validates the stream (RSV bits, opcodes, masking, control frame rules, UTF-8 of
  // text messages and close reasons, close codes, size limits).
  // No extensions are negotiated, so any RSV bit is a protocol error.
  TWsParser=record
    role:TWsRole;
    maxMessageSize:integer; // limit for an assembled data message, bytes
    errorCode:word;         // after Error: close code to send (1002, 1007 or 1009)
    errorText:String8;      // after Error: description for the log
    procedure Init(role:TWsRole;maxMessageSize:integer=1 shl 20);
    // Parse the next message from buf, starting at its current position. Complete frames are
    // consumed (the position advances), a partial frame stays unread for the next call.
    // Call repeatedly until NeedMore or Error. Control frames are returned as soon as they
    // arrive, also between fragments of a data message. A frame whose declared length exceeds
    // the limit fails at once, without waiting for its payload. After Error the parser stays
    // failed: the connection must be closed.
    function Next(var buf:TBuffer;out msg:TWsMessage):TWsParseResult;
  private
    fragActive:boolean;   // a fragmented data message is being assembled
    fragOpcode:TWsOpcode; // its opcode (Text or Binary)
    fragData:ByteArray;   // its payload so far (capacity may exceed fragSize)
    fragSize:integer;
    failed:boolean;
    function Fail(code:word;const text:String8):TWsParseResult;
  end;

  {$SCOPEDENUMS ON}
  TWsState=(Open,Closing,Closed);
  {$SCOPEDENUMS OFF}

  // Protocol state of one WebSocket connection after the handshake, without I/O: the transport
  // feeds received bytes in and writes out the bytes the session produced. Control frames are
  // handled here: Ping is answered with Pong, the close handshake is completed, a protocol
  // error closes the connection with the proper code. Optional keepalive pings a silent peer.
  // When state becomes Closed the transport flushes the output and closes the connection.
  // Not thread-safe: use from the thread that polls the transport.
  TWsSession=class
  private
    fState:TWsState;
    fCloseCode:word;
    fCloseReason:String8;
    fPingInterval,fPongTimeout,fCloseTimeout:integer;
    parser:TWsParser;
    masked:boolean;          // role=Client
    inbox:array of TWsMessage;
    inboxHead,inboxCount:integer;
    output:ByteArray;
    outputSize:integer;
    dataSeen:boolean;        // something arrived since the last Tick
    lastReceived,pingSent,closeSent:int64; // CoreTime.Ticks, 0 - not yet
    procedure Enqueue(const msg:TWsMessage);
    procedure AddOutput(const frame:ByteArray);
    procedure SetClosed(code:word;const reason:String8);
  public
    constructor Create(role:TWsRole;maxMessageSize:integer=1 shl 20);
    // --- input ---
    // Process received bytes: complete frames are consumed, a partial frame stays in buf.
    // Any call with unread bytes counts as activity for keepalive (a long frame in progress
    // keeps the session alive), so call it only when new data has arrived.
    procedure Feed(var buf:TBuffer);
    // Next received data message (Text or Binary); false if none is queued
    function Receive(out msg:TWsMessage):boolean;
    // The transport lost the connection without a close handshake: state=Closed, code 1006
    procedure ConnectionLost;
    // --- output (ignored unless state=Open) ---
    procedure Send(data:pointer;size:integer); overload; // binary message
    procedure Send(const data:ByteArray); overload;      // binary message
    procedure SendText(const text:String8);
    procedure Ping;
    // Start the close handshake: state=Closing until the peer answers or closeTimeout passes
    procedure Close(code:word=WS_CLOSE_NORMAL;const reason:String8='');
    // Bytes to write to the transport; false if nothing is pending
    function TakeOutput(out data:ByteArray):boolean;
    // --- time ---
    // Call regularly with CoreTime.Ticks: keepalive pings and close/pong timeouts
    procedure Tick(nowMS:int64);
    property state:TWsState read fState;
    // Valid when Closed: the code from the peer's Close frame if one arrived, otherwise ours
    // (Close argument, parser error code, WS_CLOSE_ABNORMAL for a timeout or a lost connection)
    property closeCode:word read fCloseCode;
    property closeReason:String8 read fCloseReason;
    property pingInterval:integer read fPingInterval write fPingInterval; // ms of silence before Ping, 0 - off
    property pongTimeout:integer read fPongTimeout write fPongTimeout;    // ms to wait for any data after Ping
    property closeTimeout:integer read fCloseTimeout write fCloseTimeout; // ms to wait for the peer's Close
  end;

// --- Frames ---

// Encode a single frame: header + payload, ready to send. masked=true for the client role
// (a random masking key is generated). fin=false with opcode Text/Binary starts a fragmented
// message, continue it with Continuation.
function WsEncodeFrame(opcode:TWsOpcode;data:pointer;size:integer;masked:boolean;fin:boolean=true):ByteArray; overload;
function WsEncodeFrame(opcode:TWsOpcode;const data:ByteArray;masked:boolean;fin:boolean=true):ByteArray; overload;
function WsEncodeFrame(opcode:TWsOpcode;const text:String8;masked:boolean;fin:boolean=true):ByteArray; overload;
// Close frame with a status code and a reason (cut on a UTF-8 boundary to fit 125 bytes).
// code=WS_CLOSE_NO_STATUS gives an empty close frame.
function WsEncodeClose(code:word;const reason:String8;masked:boolean):ByteArray;

// --- Opening handshake ---

// Sec-WebSocket-Accept value for a client key: base64(SHA-1(key+GUID))
function WsAcceptKey(const clientKey:String8):String8;
// Client: random 16-byte key, base64
function WsNewClientKey:String8;
// Client: opening HTTP request. path - with leading '/' and query; protocols - comma-separated
// subprotocols or ''; extraHeaders - complete lines with CRLF each (e.g. Origin, Cookie) or ''
function WsClientRequest(const host,path,key:String8;const protocols:String8='';
  const extraHeaders:String8=''):String8;
// Server: check the upgrade request headers (values as received; token lists such as
// "keep-alive, Upgrade" are accepted). On failure returns false and the HTTP status to answer
// with in error: '405 Method Not Allowed', '400 Bad Request', or '426 Upgrade Required' for
// a wrong version (the response must then carry "Sec-WebSocket-Version: 13")
function WsCheckRequest(const method,upgrade,connection,version,key:String8;out error:String8):boolean;
// Server: 101 Switching Protocols response; protocol - the selected subprotocol or ''
function WsServerResponse(const clientKey:String8;const protocol:String8=''):String8;
// Client: check the server response at the current position of buf. protocols - the list
// offered in WsClientRequest ('' if none): a subprotocol outside it (exact match) is rejected.
// Accepted - the header is consumed (frames may follow in the same buffer) and protocol gets
// the selected subprotocol or ''; NeedMore - the header is incomplete, nothing consumed;
// Rejected - error tells why
function WsCheckResponse(var buf:TBuffer;const clientKey,protocols:String8;
  out protocol,error:String8):TWsHandshakeResult;

implementation
uses Apus.Strings, Apus.Conv, Apus.Crypto;

const
  WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
  CRLF = #13#10;
  MAX_RESPONSE_HEADER = 16384; // client: a longer handshake response is rejected

threadvar
  rng:TRandom;
  rngReady:boolean;

// Masking keys and client keys. RFC 6455 5.3 asks for a strong entropy source: masking protects
// proxies from script-crafted payloads. Only our own native client masks (browsers mask by
// themselves), so PCG32 mixed with the microsecond clock is a deliberate simplification;
// an OS CSPRNG may replace it later.
function RandomDWord:cardinal;
begin
  if not rngReady then begin
    rng.InitUnique;
    rngReady:=true;
  end;
  result:=rng.Next xor cardinal(CoreTime.TicksUs);
end;

// Does a comma-separated header value contain the token (case-insensitive)?
function HasToken(const list,token:String8):boolean;
var
  parts:Strings8;
  i:integer;
begin
  parts:=list.Split(',');
  for i:=0 to high(parts) do
    if parts[i].Trim.Same(token) then exit(true);
  result:=false;
end;

// Same, but case-sensitive: subprotocol names
function HasExactToken(const list,token:String8):boolean;
var
  parts:Strings8;
  i:integer;
begin
  parts:=list.Split(',');
  for i:=0 to high(parts) do
    if parts[i].Trim=token then exit(true);
  result:=false;
end;

// Client key: base64 of 16 bytes = 22 base64 chars + '=='
function IsValidClientKey(const key:String8):boolean;
var
  i:integer;
begin
  result:=false;
  if (length(key)<>24) or (key[23]<>'=') or (key[24]<>'=') then exit;
  for i:=1 to 22 do
    if not (key[i] in ['A'..'Z','a'..'z','0'..'9','+','/']) then exit;
  result:=true;
end;

// Codes an endpoint may send in a Close frame (1004-1006 and 1015 are reserved)
function IsValidCloseCode(code:word):boolean;
begin
  result:=((code>=1000) and (code<=1003)) or ((code>=1007) and (code<=1014)) or
          ((code>=3000) and (code<=4999));
end;

procedure Unmask(p:PByte;size:integer;const key:array of byte);
var
  i:integer;
begin
  for i:=0 to size-1 do
    p[i]:=p[i] xor key[i and 3];
end;

{ TWsMessage }

function TWsMessage.Text:String8;
begin
  SetLength(result,length(data));
  if length(data)>0 then move(data[0],result[1],length(data));
end;

{ TWsParser }

procedure TWsParser.Init(role:TWsRole;maxMessageSize:integer);
begin
  self.role:=role;
  self.maxMessageSize:=maxMessageSize;
  errorCode:=0;
  errorText:='';
  fragActive:=false;
  fragData:=nil;
  fragSize:=0;
  failed:=false;
end;

function TWsParser.Fail(code:word;const text:String8):TWsParseResult;
begin
  failed:=true;
  errorCode:=code;
  errorText:=text;
  fragData:=nil;
  result:=TWsParseResult.Error;
end;

function TWsParser.Next(var buf:TBuffer;out msg:TWsMessage):TWsParseResult;
var
  p,payload:PByte;
  avail,hdrSize,i,size,newCap:integer;
  len:uint64;
  op:byte;
  fin,isMasked:boolean;
  key:array[0..3] of byte;
  data:ByteArray;
begin
  msg.opcode:=TWsOpcode.Binary;
  msg.data:=nil;
  msg.closeCode:=0;
  if failed then exit(TWsParseResult.Error);
  while true do begin
    avail:=buf.BytesLeft;
    if avail<2 then exit(TWsParseResult.NeedMore);
    p:=buf.readPos;
    fin:=(p[0] and $80)<>0;
    op:=p[0] and $0F;
    isMasked:=(p[1] and $80)<>0;
    // header checks that don't need the rest of the frame
    if (p[0] and $70)<>0 then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'RSV bits set without an extension'));
    if not (op in [0,1,2,8,9,10]) then
      exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Unknown opcode '+Conv.ToStr(op)));
    if isMasked<>(role=TWsRole.Server) then begin
      if isMasked then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Masked frame from the server'))
        else exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Unmasked frame from the client'));
    end;
    if op>=8 then begin
      if not fin then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Fragmented control frame'));
      if (p[1] and $7F)>WS_MAX_CONTROL_PAYLOAD then
        exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Control frame payload over 125 bytes'));
    end else
    if op=0 then begin
      if not fragActive then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Continuation without a message'));
    end else
      if fragActive then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'New message inside a fragmented one'));
    // payload length
    len:=p[1] and $7F;
    hdrSize:=2;
    if len=126 then begin
      if avail<4 then exit(TWsParseResult.NeedMore);
      len:=(cardinal(p[2]) shl 8) or p[3];
      if len<126 then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Non-minimal 16-bit payload length'));
      hdrSize:=4;
    end else
    if len=127 then begin
      if avail<10 then exit(TWsParseResult.NeedMore);
      len:=0;
      for i:=2 to 9 do len:=(len shl 8) or p[i];
      if (len shr 63)<>0 then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Invalid payload length'));
      if len<=65535 then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Non-minimal 64-bit payload length'));
      hdrSize:=10;
    end;
    if (op<8) and (uint64(fragSize)+len>uint64(maxMessageSize)) then
      exit(Fail(WS_CLOSE_TOO_BIG,'Message exceeds '+Conv.ToStr(maxMessageSize)+' bytes'));
    if isMasked then begin
      if avail<hdrSize+4 then exit(TWsParseResult.NeedMore);
      move(p[hdrSize],key,4);
      inc(hdrSize,4);
    end;
    size:=integer(len); // fits: limited by maxMessageSize or 125
    if avail-hdrSize<size then exit(TWsParseResult.NeedMore);
    // the whole frame is here: consume it
    payload:=p+hdrSize;
    buf.Skip(hdrSize+size);

    if op>=8 then begin
      // control frame
      SetLength(data,size);
      if size>0 then begin
        move(payload^,data[0],size);
        if isMasked then Unmask(@data[0],size,key);
      end;
      msg.opcode:=TWsOpcode(op);
      if op=8 then begin
        if size=1 then exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Close frame with a 1-byte payload'));
        if size=0 then msg.closeCode:=WS_CLOSE_NO_STATUS
        else begin
          msg.closeCode:=(word(data[0]) shl 8) or data[1];
          if not IsValidCloseCode(msg.closeCode) then
            exit(Fail(WS_CLOSE_PROTOCOL_ERROR,'Invalid close code '+Conv.ToStr(msg.closeCode)));
          if (size>2) and not UTF8.IsValid(@data[2],size-2) then
            exit(Fail(WS_CLOSE_INVALID_DATA,'Close reason is not valid UTF-8'));
          data:=copy(data,2,size-2);
        end;
      end;
      msg.data:=data;
      exit(TWsParseResult.Message);
    end;

    // data frame
    if (op<>0) and fin then begin
      // the common case: a whole message in one frame, no reassembly
      SetLength(data,size);
      if size>0 then begin
        move(payload^,data[0],size);
        if isMasked then Unmask(@data[0],size,key);
      end;
      if (op=1) and not UTF8.IsValid(pointer(data),size) then
        exit(Fail(WS_CLOSE_INVALID_DATA,'Text message is not valid UTF-8'));
      msg.opcode:=TWsOpcode(op);
      msg.data:=data;
      exit(TWsParseResult.Message);
    end;
    if op<>0 then begin
      fragActive:=true;
      fragOpcode:=TWsOpcode(op);
      fragSize:=0;
    end;
    if fragSize+size>length(fragData) then begin
      newCap:=Max(fragSize+size,length(fragData)*2);
      if newCap>maxMessageSize then newCap:=maxMessageSize;
      SetLength(fragData,newCap);
    end;
    if size>0 then begin
      move(payload^,fragData[fragSize],size);
      if isMasked then Unmask(@fragData[fragSize],size,key);
      inc(fragSize,size);
    end;
    if fin then begin
      SetLength(fragData,fragSize);
      if (fragOpcode=TWsOpcode.Text) and not UTF8.IsValid(pointer(fragData),fragSize) then
        exit(Fail(WS_CLOSE_INVALID_DATA,'Text message is not valid UTF-8'));
      msg.opcode:=fragOpcode;
      msg.data:=fragData;
      fragData:=nil;
      fragSize:=0;
      fragActive:=false;
      exit(TWsParseResult.Message);
    end;
    // a middle fragment: go on with the next frame
  end;
end;

{ Frames }

function WsEncodeFrame(opcode:TWsOpcode;data:pointer;size:integer;masked:boolean;fin:boolean):ByteArray;
var
  hdrSize,i:integer;
  b0:byte;
  mask:cardinal;
  key:array[0..3] of byte;
  p:PByte;
begin
  ASSERT(size>=0);
  ASSERT((ord(opcode)<8) or (fin and (size<=WS_MAX_CONTROL_PAYLOAD)),'Invalid control frame');
  hdrSize:=2;
  if size>65535 then inc(hdrSize,8)
  else if size>=126 then inc(hdrSize,2);
  if masked then inc(hdrSize,4);
  SetLength(result,hdrSize+size);
  b0:=ord(opcode);
  if fin then b0:=b0 or $80;
  result[0]:=b0;
  if size>65535 then begin
    result[1]:=127;
    for i:=0 to 7 do result[9-i]:=byte(uint64(size) shr (i*8));
  end else
  if size>=126 then begin
    result[1]:=126;
    result[2]:=byte(size shr 8);
    result[3]:=byte(size);
  end else
    result[1]:=size;
  p:=PByte(result)+hdrSize; // not @result[hdrSize]: past the end for an empty payload
  if size>0 then move(data^,p^,size);
  if masked then begin
    result[1]:=result[1] or $80;
    mask:=RandomDWord;
    move(mask,key,4);
    move(key,result[hdrSize-4],4);
    if size>0 then Unmask(p,size,key);
  end;
end;

function WsEncodeFrame(opcode:TWsOpcode;const data:ByteArray;masked:boolean;fin:boolean):ByteArray;
begin
  result:=WsEncodeFrame(opcode,pointer(data),length(data),masked,fin);
end;

function WsEncodeFrame(opcode:TWsOpcode;const text:String8;masked:boolean;fin:boolean):ByteArray;
begin
  result:=WsEncodeFrame(opcode,pointer(text),length(text),masked,fin);
end;

function WsEncodeClose(code:word;const reason:String8;masked:boolean):ByteArray;
var
  payload:array[0..WS_MAX_CONTROL_PAYLOAD-1] of byte;
  n:integer;
begin
  if code=WS_CLOSE_NO_STATUS then
    exit(WsEncodeFrame(TWsOpcode.Close,nil,0,masked));
  ASSERT(IsValidCloseCode(code),'Reserved or invalid close code');
  payload[0]:=code shr 8;
  payload[1]:=code and $FF;
  n:=length(reason);
  if n>WS_MAX_CONTROL_PAYLOAD-2 then begin
    n:=WS_MAX_CONTROL_PAYLOAD-2;
    // don't cut a multibyte character: back off while the next byte is a continuation byte
    while (n>0) and ((byte(reason[n+1]) and $C0)=$80) do dec(n);
  end;
  if n>0 then move(reason[1],payload[2],n);
  result:=WsEncodeFrame(TWsOpcode.Close,@payload,n+2,masked);
end;

{ Handshake }

function WsAcceptKey(const clientKey:String8):String8;
var
  digest:TSHA1Digest;
begin
  digest:=SHA1(clientKey+WS_GUID);
  result:=Conv.ToBase64(@digest,sizeof(digest));
end;

function WsNewClientKey:String8;
var
  key:array[0..3] of cardinal;
  i:integer;
begin
  for i:=0 to 3 do key[i]:=RandomDWord;
  result:=Conv.ToBase64(@key,sizeof(key));
end;

function WsClientRequest(const host,path,key:String8;const protocols,extraHeaders:String8):String8;
var
  uri:String8;
begin
  uri:=path;
  if uri='' then uri:='/';
  result:='GET '+uri+' HTTP/1.1'+CRLF+
    'Host: '+host+CRLF+
    'Upgrade: websocket'+CRLF+
    'Connection: Upgrade'+CRLF+
    'Sec-WebSocket-Key: '+key+CRLF+
    'Sec-WebSocket-Version: 13'+CRLF;
  if protocols<>'' then result:=result+'Sec-WebSocket-Protocol: '+protocols+CRLF;
  result:=result+extraHeaders+CRLF;
end;

function WsCheckRequest(const method,upgrade,connection,version,key:String8;out error:String8):boolean;
begin
  result:=false;
  if method<>'GET' then begin
    error:='405 Method Not Allowed';
    exit;
  end;
  error:='400 Bad Request';
  if not HasToken(upgrade,'websocket') then exit;
  if not HasToken(connection,'upgrade') then exit;
  if not IsValidClientKey(key.Trim) then exit;
  if version.Trim<>'13' then begin
    error:='426 Upgrade Required';
    exit;
  end;
  error:='';
  result:=true;
end;

function WsServerResponse(const clientKey:String8;const protocol:String8):String8;
begin
  result:='HTTP/1.1 101 Switching Protocols'+CRLF+
    'Upgrade: websocket'+CRLF+
    'Connection: Upgrade'+CRLF+
    'Sec-WebSocket-Accept: '+WsAcceptKey(clientKey.Trim)+CRLF;
  if protocol<>'' then result:=result+'Sec-WebSocket-Protocol: '+protocol+CRLF;
  result:=result+CRLF;
end;

function WsCheckResponse(var buf:TBuffer;const clientKey,protocols:String8;
  out protocol,error:String8):TWsHandshakeResult;
var
  p:PByte;
  avail,hdrSize,i,colon:integer;
  header,name,value:String8;
  lines,parts:Strings8;
  gotUpgrade,gotConnection,gotAccept,gotProtocol:boolean;
begin
  protocol:='';
  error:='';
  p:=buf.readPos;
  avail:=buf.BytesLeft;
  // find the end of the header within the limit, so the verdict doesn't depend on how it arrived
  hdrSize:=0;
  for i:=0 to Min(avail,MAX_RESPONSE_HEADER)-4 do
    if (p[i]=13) and (p[i+1]=10) and (p[i+2]=13) and (p[i+3]=10) then begin
      hdrSize:=i+4;
      break;
    end;
  if hdrSize=0 then begin
    if avail>=MAX_RESPONSE_HEADER then begin
      error:='Handshake response header is too long';
      exit(TWsHandshakeResult.Rejected);
    end;
    exit(TWsHandshakeResult.NeedMore);
  end;
  SetLength(header,hdrSize);
  move(p^,header[1],hdrSize);
  lines:=header.Split(#10);
  // status line: HTTP/1.1 101 Switching Protocols
  parts:=lines[0].Trim.Split(' ');
  if (length(parts)<2) or not parts[0].StartsWith('HTTP/1.') or (parts[1]<>'101') then begin
    error:='Server refused the upgrade: '+lines[0].Trim;
    exit(TWsHandshakeResult.Rejected);
  end;
  gotUpgrade:=false; gotConnection:=false; gotAccept:=false; gotProtocol:=false;
  for i:=1 to high(lines) do begin
    colon:=lines[i].IndexOf(':');
    if colon=0 then continue;
    name:=lines[i].Left(colon-1).Trim;
    value:=lines[i].Substr(colon+1).Trim;
    if name.Same('Upgrade') then gotUpgrade:=HasToken(value,'websocket')
    else if name.Same('Connection') then gotConnection:=HasToken(value,'upgrade')
    else if name.Same('Sec-WebSocket-Accept') then gotAccept:=value=WsAcceptKey(clientKey)
    else if name.Same('Sec-WebSocket-Protocol') then begin
      if gotProtocol then begin
        error:='Several Sec-WebSocket-Protocol headers in the response';
        exit(TWsHandshakeResult.Rejected);
      end;
      gotProtocol:=true;
      protocol:=value;
    end else if name.Same('Sec-WebSocket-Extensions') and (value<>'') then begin
      error:='Server selected an extension that was not requested: '+value;
      exit(TWsHandshakeResult.Rejected);
    end;
  end;
  if not gotUpgrade then error:='No "Upgrade: websocket" in the response'
  else if not gotConnection then error:='No "Connection: Upgrade" in the response'
  else if not gotAccept then error:='Wrong or missing Sec-WebSocket-Accept'
  else if gotProtocol and not HasExactToken(protocols,protocol) then
    error:='Server selected a subprotocol that was not offered: '+protocol;
  if error<>'' then exit(TWsHandshakeResult.Rejected);
  buf.Skip(hdrSize);
  result:=TWsHandshakeResult.Accepted;
end;

{ TWsSession }

constructor TWsSession.Create(role:TWsRole;maxMessageSize:integer);
begin
  parser.Init(role,maxMessageSize);
  masked:=role=TWsRole.Client;
  fState:=TWsState.Open;
  fPingInterval:=0;
  fPongTimeout:=15000;
  fCloseTimeout:=5000;
end;

procedure TWsSession.AddOutput(const frame:ByteArray);
var
  n:integer;
begin
  n:=length(frame);
  if outputSize+n>length(output) then
    SetLength(output,Max(outputSize+n,length(output)*2));
  move(frame[0],output[outputSize],n);
  inc(outputSize,n);
end;

procedure TWsSession.Enqueue(const msg:TWsMessage);
var
  i:integer;
begin
  if inboxHead+inboxCount>=length(inbox) then begin
    if inboxHead>0 then begin
      // compact: records hold managed data, so assign instead of move
      for i:=0 to inboxCount-1 do inbox[i]:=inbox[inboxHead+i];
      for i:=inboxCount to inboxHead+inboxCount-1 do inbox[i].data:=nil;
      inboxHead:=0;
    end;
    if inboxCount>=length(inbox) then SetLength(inbox,Max(4,length(inbox)*2));
  end;
  inbox[inboxHead+inboxCount]:=msg;
  inc(inboxCount);
end;

procedure TWsSession.SetClosed(code:word;const reason:String8);
begin
  fState:=TWsState.Closed;
  fCloseCode:=code;
  fCloseReason:=reason;
end;

procedure TWsSession.Feed(var buf:TBuffer);
var
  msg:TWsMessage;
begin
  if buf.BytesLeft>0 then dataSeen:=true;
  while fState<>TWsState.Closed do
    case parser.Next(buf,msg) of
      TWsParseResult.NeedMore:exit;
      TWsParseResult.Error:begin
        if fState=TWsState.Open then AddOutput(WsEncodeClose(parser.errorCode,parser.errorText,masked));
        SetClosed(parser.errorCode,parser.errorText);
      end;
      TWsParseResult.Message:
        case msg.opcode of
          TWsOpcode.Text,TWsOpcode.Binary:Enqueue(msg);
          TWsOpcode.Ping: // answered also while Closing: the peer's Close hasn't come yet
            AddOutput(WsEncodeFrame(TWsOpcode.Pong,msg.data,masked));
          TWsOpcode.Close:begin
            // peer-initiated: echo its code; our own Close was already sent otherwise
            if fState=TWsState.Open then AddOutput(WsEncodeClose(msg.closeCode,'',masked));
            SetClosed(msg.closeCode,msg.Text);
          end;
        end;
    end;
end;

function TWsSession.Receive(out msg:TWsMessage):boolean;
begin
  result:=inboxCount>0;
  if not result then exit;
  msg:=inbox[inboxHead];
  inbox[inboxHead].data:=nil;
  inc(inboxHead);
  dec(inboxCount);
  if inboxCount=0 then inboxHead:=0;
end;

procedure TWsSession.ConnectionLost;
begin
  if fState<>TWsState.Closed then SetClosed(WS_CLOSE_ABNORMAL,'Connection lost');
end;

procedure TWsSession.Send(data:pointer;size:integer);
begin
  if fState=TWsState.Open then AddOutput(WsEncodeFrame(TWsOpcode.Binary,data,size,masked));
end;

procedure TWsSession.Send(const data:ByteArray);
begin
  Send(pointer(data),length(data));
end;

procedure TWsSession.SendText(const text:String8);
begin
  if fState=TWsState.Open then AddOutput(WsEncodeFrame(TWsOpcode.Text,text,masked));
end;

procedure TWsSession.Ping;
begin
  if fState=TWsState.Open then AddOutput(WsEncodeFrame(TWsOpcode.Ping,nil,0,masked));
end;

procedure TWsSession.Close(code:word;const reason:String8);
begin
  if fState<>TWsState.Open then exit;
  AddOutput(WsEncodeClose(code,reason,masked));
  fState:=TWsState.Closing;
  fCloseCode:=code;
  fCloseReason:=reason;
  closeSent:=0; // the timeout starts at the next Tick
end;

function TWsSession.TakeOutput(out data:ByteArray):boolean;
begin
  result:=outputSize>0;
  if not result then begin
    data:=nil;
    exit;
  end;
  SetLength(output,outputSize);
  data:=output;
  output:=nil;
  outputSize:=0;
end;

procedure TWsSession.Tick(nowMS:int64);
begin
  if fState=TWsState.Closed then exit;
  if (lastReceived=0) or dataSeen then begin
    lastReceived:=nowMS;
    pingSent:=0;
    dataSeen:=false;
  end;
  if fState=TWsState.Closing then begin
    if closeSent=0 then closeSent:=nowMS
    else if nowMS-closeSent>=fCloseTimeout then
      SetClosed(WS_CLOSE_ABNORMAL,'No answer to Close');
    exit;
  end;
  if fPingInterval<=0 then exit;
  if pingSent=0 then begin
    if nowMS-lastReceived>=fPingInterval then begin
      Ping;
      pingSent:=nowMS;
    end;
  end else
  if nowMS-pingSent>=fPongTimeout then
    SetClosed(WS_CLOSE_ABNORMAL,'No answer to Ping');
end;

end.
