// Socket wrapper and cross-platform compatibility layer for Delphi and FPC

// Copyright (C) 2023 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.Socket;
interface
uses
{$IFDEF MSWINDOWS}
  Windows, WinSock2,
{$ELSE}
  {$IFDEF UNIX}
  BaseUnix, Sockets, CNetDB,
  {$ENDIF}
{$ENDIF}
  Apus.Types;

const
 LOCAL_IP = $7F000001; // localhost = 127.0.0.1
 INVALID_SOCKET = {$IFDEF MSWINDOWS}WinSock2.INVALID_SOCKET{$ELSE}-1{$ENDIF};
 SOCKET_ERROR = {$IFDEF MSWINDOWS}WinSock2.SOCKET_ERROR{$ELSE}-1{$ENDIF};
 WSAEWOULDBLOCK = {$IFDEF MSWINDOWS}WinSock2.WSAEWOULDBLOCK{$ELSE}ESockEWOULDBLOCK{$ENDIF};
 // a non-blocking connect() reports "in progress" differently per platform
 WSAEINPROGRESS = {$IFDEF MSWINDOWS}WinSock2.WSAEWOULDBLOCK{$ELSE}ESysEINPROGRESS{$ENDIF};
 WSAECONNREFUSED = {$IFDEF MSWINDOWS}WinSock2.WSAECONNREFUSED{$ELSE}ESysECONNREFUSED{$ENDIF};
 PF_INET = {$IFDEF MSWINDOWS}WinSock2.PF_INET{$ELSE}Sockets.PF_INET{$ENDIF};
 SOCK_STREAM = {$IFDEF MSWINDOWS}WinSock2.SOCK_STREAM{$ELSE}Sockets.SOCK_STREAM{$ENDIF};
 SOCK_DGRAM = {$IFDEF MSWINDOWS}WinSock2.SOCK_DGRAM{$ELSE}Sockets.SOCK_DGRAM{$ENDIF};
 IPPROTO_IP = {$IFDEF MSWINDOWS}WinSock2.IPPROTO_IP{$ELSE}Sockets.IPPROTO_IP{$ENDIF};
 SOMAXCONN = {$IFDEF MSWINDOWS}WinSock2.SOMAXCONN{$ELSE}Sockets.SOMAXCONN{$ENDIF};
 FIONBIO = {$IFDEF MSWINDOWS}WinSock2.FIONBIO{$ELSE}0{$ENDIF};

type
 TNativeSocket = {$IFDEF MSWINDOWS}
   WinSock2.TSocket;
 {$ELSE}
   Sockets.TSocket;
 {$ENDIF}
 PSockAddr = {$IFDEF MSWINDOWS}WinSock2.PSockAddr{$ELSE}Sockets.PSockAddr{$ENDIF};
 TSockAddr = {$IFDEF MSWINDOWS}WinSock2.TSockAddr{$ELSE}Sockets.TSockAddr{$ENDIF};
 SOCKADDR_IN = {$IFDEF MSWINDOWS}WinSock2.SOCKADDR_IN{$ELSE}Sockets.sockaddr_in{$ENDIF};
 TTimeVal = {$IFDEF MSWINDOWS}WinSock2.TTimeVal{$ELSE}BaseUnix.TTimeVal{$ENDIF};
 PTimeVal = {$IFDEF MSWINDOWS}WinSock2.PTimeVal{$ELSE}BaseUnix.PTimeVal{$ENDIF};

 {$IFDEF MSWINDOWS}
 TFDSet = WinSock2.TFDSet;
 PFDSet = WinSock2.PFDSet;
 {$ELSE}
 TFDSet = record
   fd_count: LongInt;
   fd_array: array[0..63] of TNativeSocket;
 end;
 PFDSet = ^TFDSet;
 {$ENDIF}

 {$SCOPEDENUMS ON}
 TSocketProto = (TCP, UDP);

 // BSD socket API wrapper
 TSocket=record
   sock:TNativeSocket;
   lastError:integer;
   constructor Create(protocol:TSocketProto);
   function Bind(port:word;ip:cardinal=LOCAL_IP):boolean;
   function Listen:integer;
   function Accept(out newSocket:TSocket):boolean;
   procedure Close;
 end;

function socket(domain, xtype, protocol: LongInt): TNativeSocket;
function bind(s: TNativeSocket; name: PSockAddr; namelen: LongInt): LongInt;
function listen(s: TNativeSocket; backlog: LongInt): LongInt;
function accept(s: TNativeSocket; addr: PSockAddr; addrlen: PLongInt): TNativeSocket;
function recv(s: TNativeSocket; var buf; len: SizeUInt; flags: LongInt): LongInt;
function send(s: TNativeSocket; const buf; len: SizeUInt; flags: LongInt): LongInt;
function ioctlsocket(s: TNativeSocket; cmd: LongInt; var arg: Cardinal): LongInt;
function select(nfds: LongInt; readfds, writefds, exceptfds: PFDSet; timeout: PTimeVal): LongInt;
function WSAGetLastError: LongInt;
function WSAAccept(s: TNativeSocket; addr: PSockAddr; addrlen: PLongInt; lpfnCondition: Pointer; dwCallbackData: PtrUInt): TNativeSocket;
function SocketConnect(s: TNativeSocket; const addr: TSockAddr; namelen: LongInt): LongInt;
function CloseSocket(s: TNativeSocket): LongInt;
function htons(value: Word): Word;
function ntohs(value: Word): Word;
function htonl(value: Cardinal): Cardinal;
function ResolveIPv4Address(address: AnsiString): Cardinal;

implementation
uses Apus.Core, Apus.Conv;

{$IFDEF MSWINDOWS}
// many routines have different declaration in different WinSock2 import units
function _bind(s:TNativeSocket; name:PSockAddr; namelen:Integer): Integer; stdcall; external 'ws2_32.dll' name 'bind';
function _connect(s:TNativeSocket; name:PSockAddr; namelen:Integer): Integer; stdcall; external 'ws2_32.dll' name 'connect';
function _WSAAccept(s:TNativeSocket; addr:PSockAddr; addrlen:PLongint; lpfnCondition:Pointer; dwCallbackData:PtrUInt):TNativeSocket; stdcall; external 'ws2_32.dll' name 'WSAAccept';
{$ENDIF}

function socket(domain, xtype, protocol: LongInt): TNativeSocket;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.socket(domain,xtype,protocol);
  {$ELSE}
  result:=fpSocket(domain,xtype,protocol);
  {$ENDIF}
end;

function bind(s: TNativeSocket; name: PSockAddr; namelen: LongInt): LongInt;
begin
  {$IFDEF MSWINDOWS}
  result:=_bind(s,name,namelen);
  {$ELSE}
  result:=fpBind(s,name,namelen);
  {$ENDIF}
end;

function listen(s: TNativeSocket; backlog: LongInt): LongInt;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.listen(s,backlog);
  {$ELSE}
  result:=fpListen(s,backlog);
  {$ENDIF}
end;

function accept(s: TNativeSocket; addr: PSockAddr; addrlen: PLongInt): TNativeSocket;
{$IFNDEF MSWINDOWS}
var
  len: TSockLen;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.accept(s,addr,addrlen);
  {$ELSE}
  len:=addrlen^;
  result:=fpAccept(s,addr,@len);
  addrlen^:=len;
  {$ENDIF}
end;

function recv(s: TNativeSocket; var buf; len: SizeUInt; flags: LongInt): LongInt;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.recv(s,buf,len,flags);
  {$ELSE}
  result:=fpRecv(s,@buf,len,flags);
  {$ENDIF}
end;

function send(s: TNativeSocket; const buf; len: SizeUInt; flags: LongInt): LongInt;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.send(s,buf,len,flags);
  {$ELSE}
  result:=fpSend(s,@buf,len,flags);
  {$ENDIF}
end;

function ioctlsocket(s: TNativeSocket; cmd: LongInt; var arg: Cardinal): LongInt;
{$IFNDEF MSWINDOWS}
var
  flags: LongInt;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.ioctlsocket(s,cmd,arg);
  {$ELSE}
  flags:=fpFcntl(s,F_GETFL,0);
  if flags<0 then exit(SOCKET_ERROR);
  if arg<>0 then
    flags:=flags or O_NONBLOCK
  else
    flags:=flags and not O_NONBLOCK;
  result:=fpFcntl(s,F_SETFL,flags);
  {$ENDIF}
end;

{$IFNDEF MSWINDOWS}
procedure BuildFdSet(src: PFDSet; var dst: BaseUnix.TFDSet; var maxfd: LongInt);
var
  i: Integer;
begin
  fpFD_ZERO(dst);
  if src=nil then exit;
  for i:=0 to src^.fd_count-1 do begin
    fpFD_SET(src^.fd_array[i],dst);
    if src^.fd_array[i]>maxfd then maxfd:=src^.fd_array[i];
  end;
end;

procedure FilterFdSet(var dst: TFDSet; const src: BaseUnix.TFDSet);
var
  i,n: Integer;
begin
  n:=0;
  for i:=0 to dst.fd_count-1 do
    if fpFD_ISSET(dst.fd_array[i],src)<>0 then begin
      dst.fd_array[n]:=dst.fd_array[i];
      inc(n);
    end;
  dst.fd_count:=n;
end;
{$ENDIF}

function select(nfds: LongInt; readfds, writefds, exceptfds: PFDSet; timeout: PTimeVal): LongInt;
{$IFNDEF MSWINDOWS}
var
  readSet,writeSet,exceptSet: BaseUnix.TFDSet;
  readPtr,writePtr,exceptPtr: BaseUnix.PFDSet;
  maxfd: LongInt;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.select(nfds,readfds,writefds,exceptfds,timeout);
  {$ELSE}
  maxfd:=-1;
  readPtr:=nil;
  writePtr:=nil;
  exceptPtr:=nil;
  if readfds<>nil then begin
    BuildFdSet(readfds,readSet,maxfd);
    readPtr:=@readSet;
  end;
  if writefds<>nil then begin
    BuildFdSet(writefds,writeSet,maxfd);
    writePtr:=@writeSet;
  end;
  if exceptfds<>nil then begin
    BuildFdSet(exceptfds,exceptSet,maxfd);
    exceptPtr:=@exceptSet;
  end;
  if nfds<=0 then nfds:=maxfd+1;
  result:=fpSelect(nfds,readPtr,writePtr,exceptPtr,timeout);
  if result>0 then begin
    if readfds<>nil then FilterFdSet(readfds^,readSet);
    if writefds<>nil then FilterFdSet(writefds^,writeSet);
    if exceptfds<>nil then FilterFdSet(exceptfds^,exceptSet);
  end else begin
    if readfds<>nil then readfds^.fd_count:=0;
    if writefds<>nil then writefds^.fd_count:=0;
    if exceptfds<>nil then exceptfds^.fd_count:=0;
  end;
  {$ENDIF}
end;

function WSAGetLastError: LongInt;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.WSAGetLastError;
  {$ELSE}
  result:=SocketError;
  {$ENDIF}
end;

function WSAAccept(s: TNativeSocket; addr: PSockAddr; addrlen: PLongInt; lpfnCondition: Pointer; dwCallbackData: PtrUInt): TNativeSocket;
begin
  {$IFDEF MSWINDOWS}
  result:=_WSAAccept(s,addr,addrlen,lpfnCondition,dwCallbackData);
  {$ELSE}
  result:=accept(s,addr,addrlen);
  {$ENDIF}
end;

function SocketConnect(s: TNativeSocket; const addr: TSockAddr; namelen: LongInt): LongInt;
begin
  {$IFDEF MSWINDOWS}
  result:=_connect(s,PSockAddr(@addr),namelen);
  {$ELSE}
  result:=fpConnect(s,@addr,namelen);
  {$ENDIF}
end;

function CloseSocket(s: TNativeSocket): LongInt;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.CloseSocket(s);
  {$ELSE}
  result:=fpClose(s);
  {$ENDIF}
end;

function htons(value: Word): Word;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.htons(value);
  {$ELSE}
  result:=Sockets.htons(value);
  {$ENDIF}
end;

function ntohs(value: Word): Word;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.ntohs(value);
  {$ELSE}
  result:=Sockets.ntohs(value);
  {$ENDIF}
end;

function htonl(value: Cardinal): Cardinal;
begin
  {$IFDEF MSWINDOWS}
  result:=WinSock2.htonl(value);
  {$ELSE}
  result:=Sockets.htonl(value);
  {$ENDIF}
end;

function ResolveIPv4Address(address: AnsiString): Cardinal;
var
  h: PHostEnt;
begin
  address:=address+#0;
  {$IFDEF MSWINDOWS}
  result:=WinSock2.inet_addr(@address[1]);
  if result<>Cardinal(INADDR_NONE) then exit;
  h:=WinSock2.GetHostByName(@address[1]);
  if h<>nil then
    move(h^.h_addr^[0],result,4)
  else
    result:=0;
  {$ELSE}
  result:=StrToNetAddr(address).s_addr;
  if result<>0 then exit;
  h:=CNetDB.GetHostByName(@address[1]);
  if (h<>nil) and (h^.h_addr_list<>nil) then
    move(h^.h_addr_list^^,result,4)
  else
    result:=0;
  {$ENDIF}
end;

constructor TSocket.Create(protocol:TSocketProto);
var
 proto:integer;
 arg:cardinal;
begin
 case protocol of
  TSocketProto.TCP:proto:=SOCK_STREAM;
  TSocketProto.UDP:proto:=SOCK_DGRAM;
 end;
 sock:=socket(PF_INET,proto,IPPROTO_IP);
 if sock=INVALID_SOCKET then
   raise EError.Create('Invalid socket: '+Conv.ToStr(LastError));

 arg:=1;
 if ioctlsocket(sock,longint(FIONBIO),arg)<>0 then
   raise EError.Create('Cannot make non-blocking socket');
end;

function TSocket.Bind(port:word;ip:cardinal=LOCAL_IP):boolean;
var
 addr:SOCKADDR_IN;
 res:integer;
begin
 result:=true;
 addr.sin_family:=PF_INET;
 addr.sin_port:=htons(port);
 addr.sin_addr.S_addr:=htonl(ip);
 res:=Apus.Socket.bind(sock,PSockAddr(@addr),sizeof(addr));
 if res<>0 then begin
   lastError:=WSAGetLastError;
   result:=false;
 end;
end;

function TSocket.Accept(out newSocket:TSocket):boolean;
var
 s:TNativeSocket;
 addr:SockAddr_IN;
 addrLen:integer;
 res:integer;
begin
 result:=true;
 addrlen:=sizeof(addr);
 s:=WSAAccept(sock,@addr,@addrlen,nil,0);
 if s=INVALID_SOCKET then begin
  lastError:=WSAGetLastError;
  res:=lastError;
  if (res<>WSAEWOULDBLOCK) and (res<>WSAECONNREFUSED) then
   exit(false);
 end else
  newSocket.sock:=s;
end;

procedure TSocket.Close;
begin
 CloseSocket(sock);
 sock:=0;
end;

function TSocket.Listen: integer;
begin
 result:=Apus.Socket.listen(sock,SOMAXCONN);
end;

(*
function TSocket.LastError:integer;
begin
 {$IFDEF MSWINDOWS}
 result:=WSAGetLastError;
 {$ELSE}
 {$ENDIF}
end; *)

{$IFDEF MSWINDOWS}
var
   WSAdata:TWSAData;
{$ENDIF}

initialization
 {$IFDEF MSWINDOWS}
 WSAStartup($0202, WSAData);
 {$ENDIF}
finalization
 {$IFDEF MSWINDOWS}
 WSACleanup;
 {$ENDIF}
end.

