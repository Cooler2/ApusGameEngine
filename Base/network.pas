// --------------------------------------------------------------
// This unit contains classes for dealing with any network API's
// Author: Ivan Polyacov, Copyright (C) 2002, Apus Software
// Contact: ivan@games4win.com or cooler@tut.by
// --------------------------------------------------------------
{$H+,I-,R-}
//{$IFDEF IOS}{$modeswitch objectivec1}{$ENDIF}
unit network;

interface
 uses classes,MyServis {$IFDEF USE_DP}, DirectPlay{$ENDIF};

const
{$IFDEF USE_DP}
 BroadcastID=DPID_ALLPLAYERS;
{$ENDIF}
 BroadcastAddr:cardinal=0;

type
 // Connection modes: autocreate means that if joining fails, new session will be created
 TConnectionMode=(cmCreate,cmJoin,cmAutoCreate);

 TMessage=record
  sender,receiver:cardinal; // UID of sender and receiver
  size:integer;  // Size of message
  data:pointer;  // message itself
 end;

 {$IFDEF MSWINDOWS}
 THTTPStatus=(stReady,   // Ready for action
              stBusy,    // Performing action now
              stSuccess, // Last action successfully completed, new action can be launched
              stFailed); // Last action failed, new action can be launched

 // Request ower HTTP protocol (Winsocket is used)
 HTTPRequest=class
  status:THTTPStatus;
  recvData:pointer; // Received data
  recvSize:integer; // Size of received data
  constructor Create;
  procedure Get(url:string);
  procedure Post(url:string;postdata:string);
  procedure CancelAction;
 protected
  thread:TThread;
  postmethod:boolean;
  address,data:string;
 end;
 {$ENDIF}

 // UDP service
 // ------------
 UDPSocket=class
  constructor Create(port:word);
  destructor Destroy; override;
  // Send data to this address
  procedure Send(adr:cardinal;port:word;var buf;size:integer);
  // Receive data, wait until they will be received,
  function Receive(var adr:cardinal;var port:word;var buf;size:integer):integer;
 private
  initialized:boolean;
  sock:cardinal;
 end;

 // улучшенный вариант: использует non-blocking socket, поддерживает broadcast
 UDPSocket2=class
  sent,received,sentBytes,receivedBytes:cardinal;
  constructor Create(port:word;broadcast:boolean=true;ip:cardinal=0);
  destructor Destroy; override;
  // Send data to this address
  procedure Send(adr:cardinal;port:word;var buf;size:integer);
  // Send data to this address, returns false if no confirmation is received
  function SendGuar(adr:cardinal;port:word;var buf;size:integer):boolean;
  // Receive data, returns false if no data available
  function Receive(var adr:cardinal;var port:word;var buf;var size:integer):boolean;
 public
  lastError:integer;
 private
  initialized:boolean;
  sockPort:word;
  sockIP:cardinal;
  AllowBroadcast:boolean;
  sock:integer;
  lastSent,lastReceived:byte;
  procedure InitSocket;
 end;

 function MacToStr(var mac):string;
 function IpToStr(ip:cardinal):string;
 function StrToIp(ip:string):cardinal;

 procedure ResolveAddress(resolveAdr:string;var resolvedIP:cardinal;var resolvedPort:word);

implementation
 uses {$IFDEF MSWINDOWS}windows,activex,WinSock,{$ENDIF}
   {$IFDEF UNIX}Sockets,BaseUnix,{$ENDIF}
   SysUtils;

 {$IFDEF MSWINDOWS}
 type
  HTTPThread = class(TThread)
  private
    request:HTTPRequest;
    stage:integer;
  protected
    procedure Execute; override;
  end;
 {$ENDIF}

 const
  AppGUID:TGUID='{00000000-2389-1924-2910-246563839018}';
  magic:cardinal=$17391628;

function MacToStr(var mac):string;
 type
  TMac=array[0..5] of byte;
 var
  a:^TMac;
 begin
  a:=@mac;
  result:=IntToHex(a[0],2)+'-'+
          IntToHex(a[1],2)+'-'+
          IntToHex(a[2],2)+'-'+
          IntToHex(a[3],2)+'-'+
          IntToHex(a[4],2)+'-'+
          IntToHex(a[5],2);
 end;

function IpToStr(ip:cardinal):string;
 type
  TA=array[0..3] of byte;
 var
  a:TA absolute ip;
 begin
  result:=inttostr(a[0])+'.'+
          inttostr(a[1])+'.'+
          inttostr(a[2])+'.'+
          inttostr(a[3]);
 end;

function StrToIp(ip:string):cardinal;
 var
  i,v:integer;
 begin
  result:=0;
  v:=0;
  for i:=1 to length(ip) do begin
   if ip[i] in ['0'..'9'] then v:=v*10+byte(ip[i])-byte('0');
   if ip[i]=':' then break;
   if ip[i]='.' then begin
    result:=result shr 8+v shl 24;
    v:=0;
   end;
  end;
  result:=result shr 8+v shl 24;
 end;

procedure ResolveAddress(resolveAdr:string;var resolvedIP:cardinal;var resolvedPort:word);
 {$IFDEF MSWINDOWS}
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
  if (i>0) {or (pos('.',address)=0)} then  begin
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
    end else
     move(h^.h_addr^[0],ip,4);
   end;
  end else
   ip:=$FFFFFFFF;

  ResolveAdr:='';
  ResolvedIP:=ip;
  ResolvedPort:=port;
 end;
 {$ENDIF}
 {$IFDEF UNIX}
 begin
 end;
 {$ENDIF}

{$IFDEF MSWINDOWS}
{ HTTPRequest }
procedure HTTPRequest.CancelAction;
begin
 if status<>stBusy then
  exit;
 thread.Terminate;
end;

constructor HTTPRequest.Create;
begin
 status:=stReady;
end;

procedure HTTPRequest.Get(url: string);
begin
 if status=stBusy then
  raise EWarning.Create('Request cannot be started: object is busy');

 status:=stBusy;
 postmethod:=false;
 address:=url;
 data:='';
 thread:=HTTPThread.Create(false);
 (thread as HTTPThread).request:=self;
 thread.FreeOnTerminate:=true;
end;

procedure HTTPRequest.Post(url: string; postdata:string);
begin
 if status=stBusy then
  raise EWarning.Create('Request cannot be started: object is busy');

 status:=stBusy;
 postmethod:=true;
 address:=url;
 data:=postdata;
 thread:=HTTPThread.Create(false);
 (thread as HTTPThread).request:=self;
 thread.FreeOnTerminate:=true;
end;

{ HTTPThread }
procedure HTTPThread.Execute;
var
 sock:integer;
 WSAdata:TWSAData;
 adr,adr2:sockaddr_in;
 i,j,size,datapos,datasize:integer;
 host:PHostent;
 st,st2,hostname,document:string;
 ip:array[0..3] of byte;
 buf:array[0..16383] of char;
 pb:PByte;
 time:cardinal;
 chunked:boolean;

begin
{ sleep(0);
 stage:=0;
 request.recvData:=nil;
 request.recvSize:=0;
 // Initialization
 WSAStartup($0101, WSAData);
 try
  stage:=1; // Create socket
  Sock:=socket(PF_INET,SOCK_STREAM,IPPROTO_IP);
  if Sock=INVALID_SOCKET then begin
   exit;
  end;

  stage:=2;
  st:=request.address;
  if pos('//',st)>0 then
   delete(st,1,pos('//',st)+1);
  document:='/';
  if pos('/',st)>0 then begin
   document:=copy(st,pos('/',st),length(st)-pos('/',st)+1);
   SetLength(st,pos('/',st)-1);
  end;
  hostname:=st;

  stage:=4; //
  host:=GetHostByName(@hostname[1]);
  if host=nil then exit;

  stage:=5;
  fillchar(adr2,sizeof(adr2),0);
  adr2.sin_family:=PF_INET;
  adr2.sin_port:=htons(80);
  move(host^.h_addr^[0],adr2.sin_addr.S_addr,4);
  if connect(Sock,adr2,sizeof(adr2))<>0 then
   exit;

  stage:=6;
  if request.postmethod then begin
    // Create POST request
    st:='POST '+document+' HTTP/1.1'#13#10'Host: '+hostname+
       #13#10'Content-Type: application/x-www-form-urlencoded'+
       #13#10'Content-Length: '+inttostr(length(request.data))+
       #13#10'User-Agent: HTTPRequest class'#13#10#13#10+request.data;
  end else begin
    // Create GET request
    st:='GET '+document+' HTTP/1.1'#13#10'Host: '+hostname+#13#10'User-Agent: HTTPRequest class'#13#10#13#10;
  end;
  if send(Sock,st[1],length(st),0)<>length(st) then
   exit;

  stage:=7;
  size:=recv(Sock,buf[0],sizeof(buf),0);
  if size=SOCKET_ERROR then begin
   stage:=WSAGetLastError;
   exit;
  end;

  // Get header and handle it
  SetLength(st,size);
  move(buf,st[1],size);
  i:=pos(#13#10#13#10,st);
  datapos:=i+3;
  if i>0 then SetLength(st,i);
  i:=pos(#13#10,st);
  j:=pos('200',st);
  if (j=0) or (j>=i) then
   exit;
  st:=UpperCase(st);
  datasize:=-1;
  i:=pos('CHUNKED',st);
  chunked:=false;
  if i>0 then
   chunked:=true
  else begin
   chunked:=false;
   i:=pos('CONTENT-LENGTH:',st);
   if i>0 then begin
    i:=i+15;
    st2:=copy(st,i,7);
    for j:=1 to 7 do
     if not (st2[j] in ['0'..'9',' ',#9]) then begin
      SetLength(st2,j-1);
      break;
     end;
    datasize:=strtoint(st2);
   end else datasize:=size-datapos;
  end;

  repeat
   if chunked then begin // Read size of first chunk
    i:=datapos;
    st2:='';
    while (i<size) and (buf[i] in ['0'..'9','A'..'F','a'..'f']) do begin
     st2:=st2+buf[i];
     inc(i);
    end;
    if i>datapos then begin // size found
     datasize:=HexToInt(st2);
     datapos:=i+3;
    end;
   end;

  until false;

  if datasize=-1 then begin // No Content-length, try to find length in body
   end else
  end;
  Getmem(request.recvdata,datasize);
  request.recvSize:=0;

  // Start data receiving
  i:=0; // current position
  j:=size-datapos; // block size
  if j>datasize then j:=datasize;
  pb:=request.recvData;
  Move(buf[datapos],pb^,j);
  inc(i,j);
  inc(pb,j);
  request.recvSize:=i;

  while i<datasize do begin
   // Receive other data
   size:=recv(Sock,buf[0],sizeof(buf),0);
   if size=SOCKET_ERROR then begin
    stage:=WSAGetLastError;
    exit;
   end;
   Move(buf[0],pb^,size);
   inc(i,size);
   inc(pb,size);
   request.recvSize:=i;
  end;

  stage:=100;
 finally
  if stage<100 then request.status:=stFailed
   else request.status:=stSuccess;
  WSACleanup;
 end;}
end;
{$ENDIF}

{ UDPSocket }
constructor UDPSocket.Create(port: word);
{$IFDEF MSWINDOWS}
var
 WSAdata:TWSAData;
 adr:sockaddr_in;
begin
 initialized:=false;
 // Init network
 WSAStartup($0101, WSAData);
 Sock:=socket(PF_INET,SOCK_DGRAM,IPPROTO_IP);
 if Sock=INVALID_SOCKET then
  raise EError.Create('UDP: Cannot create socket');

 fillchar(adr,sizeof(adr),0);
 adr.sin_family:=PF_INET;
 adr.sin_port:=htons(port);
 adr.sin_addr.S_addr:=INADDR_ANY;
 if bind(Sock,adr,sizeof(adr))=SOCKET_ERROR then
  raise EError.Create('UDP: Bind failed');

 initialized:=true;
end;
{$ENDIF}
{$IFDEF UNIX}
 begin

 end;
{$ENDIF}

destructor UDPSocket.Destroy;
{$IFDEF MSWINDOWS}
begin
 if initialized then WSACleanup;
end;
{$ENDIF}
{$IFDEF UNIX}
 begin

 end;
{$ENDIF}

function UDPSocket.Receive(var adr: cardinal; var port: word; var buf;
  size: integer):integer;
{$IFDEF MSWINDOWS}
var
 a:sockaddr_in;
 asize:integer;
begin
 if not initialized then
  raise EError.Create('UDP: not initialized!');
 asize:=sizeof(a);
 result:=RecvFrom(sock,Buf,size,0,A,asize);
 if result=SOCKET_ERROR then
  raise EError.Create('UDP: error on receive');
 port:=ntohs(a.sin_port);
 adr:=a.sin_addr.S_addr;
end;
{$ENDIF}
{$IFDEF UNIX}
 begin

 end;
{$ENDIF}


procedure UDPSocket.Send(adr: cardinal; port: word; var buf;
  size: integer);
{$IFDEF MSWINDOWS}
var
 a:sockaddr_in;
begin
 if not initialized then
  raise EError.Create('UDP: not initialized!');
 fillchar(a,sizeof(a),0);
 a.sin_family:=PF_INET;
 a.sin_port:=htons(Port);
 a.sin_addr.S_addr:=adr;
 if SendTo(sock,buf,size,0,a,sizeof(a))<>size then
  raise EWarning.Create('UDP: data was not sent');
end;
{$ENDIF}
{$IFDEF UNIX}
 begin

 end;
{$ENDIF}


{ UDPSocket2 }
function GetWSAerror(c:integer):string;
{$IFDEF MSWINDOWS}
begin
 case c of
  WSANOTINITIALISED:result:='WSA not initialized';
  WSAENETDOWN:result:='network down';
  WSAEFAULT:result:='program fault';
  WSAENOBUFS:result:='no buffer space';
  WSAESHUTDOWN:result:='shutdown';
  WSAEWOULDBLOCK:result:='need to block';
  WSAEMSGSIZE:result:='wrong message size';
  WSAEHOSTUNREACH:result:='host unreacheable';
  WSAECONNRESET:result:='connection reset';
  WSAETIMEDOUT:result:='timeout';
  else result:='unknown, code '+inttostr(c);
 end;
end;
{$ENDIF}
{$IFDEF UNIX}
 begin

 end;
{$ENDIF}

constructor UDPSocket2.Create(port: word; broadcast: boolean; ip:cardinal);
{$IFDEF MSWINDOWS}
var
 WSAdata:TWSAData;
begin
 initialized:=false;
 // Init network
 WSAStartup($0101, WSAData);
 initialized:=true;
 sockPort:=port;
 sockIP:=ip;
 allowBroadcast:=broadcast;
 InitSocket;
end;
{$ENDIF}
{$IFDEF UNIX}
 begin
   initialized:=true;
   initialized:=true;
   sockPort:=port;
   sockIP:=ip;
   allowBroadcast:=broadcast;
   InitSocket;
 end;
{$ENDIF}

destructor UDPSocket2.Destroy;
begin
 if initialized then begin
  closeSocket(sock);
  {$IFDEF MSWINDOWS}
  WSACleanup;
  {$ENDIF}
 end;
end;

procedure UDPSocket2.InitSocket;
{$IFDEF MSWINDOWS}
var
 c:integer;
 adr:sockaddr_in;
begin
 Sock:=socket(PF_INET,SOCK_DGRAM,IPPROTO_IP);
 if Sock=INVALID_SOCKET then
  raise EError.Create('UDP2: Cannot create socket');

 c:=1;
 if ioctlsocket(sock,FIONBIO,c)<>0 then
  raise EError.Create('UDP2: Cannot make non-blocking socket');

 if AllowBroadcast then
  if setsockopt(sock,SOL_SOCKET,SO_BROADCAST,@c,4)<>0 then
   raise EError.Create('UDP2: Cannot allow broadcast');

 fillchar(adr,sizeof(adr),0);
 adr.sin_family:=PF_INET;
 adr.sin_port:=htons(sockport);
 if sockip=0 then
  adr.sin_addr.S_addr:=INADDR_ANY
 else
  adr.sin_addr.S_addr:=sockIP;

 if bind(Sock,adr,sizeof(adr))=SOCKET_ERROR then
  raise EError.Create('UDP: Bind failed');
 LogMessage('UDP2: Socket initialized, port: '+inttostr(sockport));
end;
{$ENDIF}
{$IFDEF UNIX}
 var
  adr:TInetSockAddr;
  val:cardinal;
 begin
  sock:=fpsocket(PF_INET,SOCK_DGRAM,IPPROTO_UDP);
  if sock=-1 then
   raise EError.Create('UDP2: Socket creation error: '+inttostr(SocketError));

  FpFcntl(sock, F_GETFL, val);
  val:=val or O_NONBLOCK;
  if FpFcntl(sock, F_SETFL, val)<>0 then
   raise EError.Create('UDP2: can''t make non-blocking socket');

  fillchar(adr,sizeof(adr),0);
  adr.sin_family:=PF_INET;
  adr.sin_port:=htons(sockport);
  if sockip=0 then
   adr.sin_addr.s_addr:=INADDR_ANY
  else
   adr.sin_addr.s_addr:=sockIP;

  if fpbind(sock,@adr,sizeof(adr))<>0 then
   raise EError.Create('UDP: bind failed');
  LogMessage('UDP2: Socket initialized, port: '+inttostr(sockport));
 end;
{$ENDIF}

function UDPSocket2.Receive(var adr: cardinal; var port: word; var buf;
  var size: integer): boolean;
{$IFDEF MSWINDOWS}
var
 a:sockaddr_in;
 asize,r,err,bufsize:integer;
 m:^cardinal;
 pb:^byte;
 b:byte;
 confbuf:array[0..1] of cardinal;
begin
 if not initialized then
  raise EError.Create('UDP2: not initialized!');
 asize:=sizeof(a);
 bufsize:=size;
 size:=RecvFrom(sock,Buf,size,0,A,asize);
 r:=size; err:=0;
 result:=(size>0);
 if size=SOCKET_ERROR then begin
  size:=WSAGetLastError;
  err:=size;
  if size=WSAEMSGSIZE then begin
   LogMessage('Packet too large, buffer size was '+inttostr(bufsize));
   exit;
  end;
  if size=WSAECONNRESET then begin
   LogMessage('UDP2: ECONNRESET');
   closeSocket(sock);
   InitSocket;
   result:=false;
   size:=0;
   exit;
  end;
  if size<>WSAEWOULDBLOCK then
   raise EError.Create('UDP2: error on receive - '+getWSAerror(size))
  else begin
   result:=false;
   exit;
  end;
 end;
 port:=ntohs(a.sin_port);
 adr:=a.sin_addr.S_addr;
 inc(received);
 inc(receivedBytes,size);
end;
{$ENDIF}
{$IFDEF UNIX}
 var
  a:TSockAddr;
  r,err,bufsize:integer;
  asize:TSockLen;
 begin
  if not initialized then
   raise EError.Create('UDP2: not initialized!');
  asize:=sizeof(a);
  bufsize:=size;
  size:=fpRecvFrom(sock,@Buf,size,0,@A,@asize);
  r:=size; err:=0;
  result:=(size>0);
  if size=-1 then begin
   err:=SocketError;
   if err=ESysENOTCONN then begin
    LogMessage('UDP2: ESysENOTCONN');
    result:=false;
    size:=0;
    closeSocket(sock);
    InitSocket;
    exit;
   end;
   if err<>ESysEAGAIN then
    raise EError.Create('UDP2: Error on receive: '+inttostr(SocketError));
  end;
  port:=ntohs(a.sin_port);
  adr:=a.sin_addr.S_addr;
  inc(received);
  inc(receivedBytes,size);
 end;
{$ENDIF}

procedure UDPSocket2.Send(adr: cardinal; port: word; var buf;
  size: integer);
{$IFDEF MSWINDOWS}
var
 a:sockaddr_in;
 r,s:integer;
begin
 if not initialized then
  raise EError.Create('UDP2: not initialized!');
{ s:=4; r:=0;
 getSockOpt(sock,SOL_SOCKET,SO_MAXDG,PChar(@r),s);
 LogMessage(inttostr(r));}
 fillchar(a,sizeof(a),0);
 a.sin_family:=PF_INET;
 a.sin_port:=htons(Port);
 a.sin_addr.S_addr:=adr;
 r:=SendTo(sock,buf,size,0,a,sizeof(a));
 if r=SOCKET_ERROR then begin
  if r=WSAECONNRESET then begin
   CloseSocket(sock);
   InitSocket;
  end;
  lastError:=WSAGetLastError;
  raise EWarning.Create('UDP2: sending error - '+GetWSAerror(lastError));
 end;
 if r<>size then
  raise EWarning.Create('UDP2: data was not sent')
 else begin
  inc(sent);
  inc(sentBytes,size);
 end;
end;
{$ENDIF}
{$IFDEF UNIX}
 var
  a:TSockAddr;
  r:integer;
 begin
  if not initialized then
   raise EError.Create('UDP2: not initialized!');
  fillchar(a,sizeof(a),0);
  a.sin_family:=PF_INET;
  a.sin_port:=htons(Port);
  a.sin_addr.S_addr:=adr;
  r:=fpSendTo(sock,@buf,size,0,@a,sizeof(a));
  if r<0 then
   raise EError.Create('UDP2: send error: '+inttostr(SocketError));
  if r<>size then
   raise EWarning.Create('UDP2: data was not sent')
  else begin
   inc(sent);
   inc(sentBytes,size);
  end;
 end;
{$ENDIF}

function UDPSocket2.SendGuar(adr: cardinal; port: word; var buf;
  size: integer): boolean;
{$IFDEF MSWINDOWS}
var
 ownbuf:array of byte;
 time:integer;
 function CheckConf:boolean;
  var
   confbuf:array[0..1] of cardinal;
   size:integer;
  begin
   result:=false;
   size:=8;
   if not Receive(adr,port,confbuf,size) then exit;
   if size<>8 then exit;
   if (confbuf[0]=magic+1) and (confbuf[1]=LastSent) then
    result:=true;
  end;
begin
 SetLength(ownbuf,size+8);
 move(buf,ownbuf[8],size);
 move(magic,ownbuf[0],4);
 ownbuf[4]:=random(256);
 ownbuf[5]:=256-ownbuf[4];
 inc(LastSent);
 ownbuf[7]:=LastSent;
 Send(adr,port,ownbuf,size+8);
 time:=50;
 repeat
  sleep(time div 2);
  if CheckConf then break;
  sleep(time div 2);
  if CheckConf then break;
  Send(adr,port,ownbuf,size+8);
  time:=time*2;
 until time>1500;
 result:=time<=1500;
end;
{$ENDIF}
{$IFDEF UNIX}
 begin

 end;
{$ENDIF}

initialization
 {$IFDEF MSWINDOWS}
 CoInitialize(nil);
 BroadcastAddr:=cardinal(INADDR_BROADCAST);
 {$ENDIF}
finalization
 {$IFDEF MSWINDOWS}
 CoUninitialize;
 {$ENDIF}
end.
