// --------------------------------------------------------------
// This unit contains classes for dealing with any network API's
// Author: Ivan Polyacov, Copyright (C) 2002, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
// --------------------------------------------------------------
// Currently only UDP left here. For HTTP use httpRequests. DirectPlay removed as obsolete.
{$H+,I-,R-}
//{$IFDEF IOS}{$modeswitch objectivec1}{$ENDIF}
unit Apus.Network;

interface
 uses Classes,Apus.Common;

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

 // Returns IP in the network byte order
 procedure ResolveAddress(resolveAdr:AnsiString;var resolvedIP:cardinal;var resolvedPort:word);

 // Text form of WSAGetLasteError() codes
 function GetWSAerror(c:integer):string;

implementation
 uses {$IFDEF MSWINDOWS}Windows,WinSock,{$ENDIF}
   {$IFDEF UNIX}Sockets,BaseUnix,{$ENDIF}
   SysUtils;

 const
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

procedure ResolveAddress(resolveAdr:AnsiString;var resolvedIP:cardinal;var resolvedPort:word);
 {$IFDEF MSWINDOWS}
 var
  i:integer;
  address:AnsiString;
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

function GetWSAerror(c:integer):string;
{$IFDEF MSWINDOWS}
begin
 if c=SOCKET_ERROR then c:=WSAGetLastError;
 case c of
  WSANOTINITIALISED:result:='WSA not initialized';
  WSAENETDOWN:result:='NET DOWN';
  WSAEFAULT:result:='FAULT';
  WSAENOBUFS:result:='no buffer space';
  WSAESHUTDOWN:result:='SHUTDOWN';
  WSAEWOULDBLOCK:result:='WOULD BLOCK';
  WSAEMSGSIZE:result:='MSGSIZE';
  WSAEHOSTUNREACH:result:='host unreacheable';
  WSAECONNRESET:result:='connection reset';
  WSAETIMEDOUT:result:='timeout';
  WSAECONNREFUSED:result:='connection refused';
  WSAENOTSOCK:result:='not a socket';
  else result:='unknown, code '+inttostr(c);
 end;
end;
{$ENDIF}
{$IFDEF UNIX}
 begin

 end;
{$ENDIF}

{ UDPSocket2 }
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
 BroadcastAddr:=cardinal(INADDR_BROADCAST);
 {$ENDIF}
end.
