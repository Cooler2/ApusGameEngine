// Unix socket wrapper for cross-platform compatibility for Delphi and FPC

// Copyright (C) 2023 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)
unit Apus.Socket;
interface
uses
{$IFDEF MSWINDOWS}
  Windows, WinSock2,
{$ELSE}
  Sockets,
{$ENDIF}
  Apus.Types;

const
 LOCAL_IP = $7F000001; // localhost = 127.0.0.1

type
 TNativeSocket = {$IFDEF MSWINDOWS}
   WinSock2.TSocket;
 {$ELSE}
   Sockets.TSocket;
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

implementation
uses SysUtils, Apus.Common;

 {$IFDEF MSWINDOWS}
  // many routines have different declaration in different WinSock2 import units
  function _bind(s:TNativeSocket; name:PSockAddr; namelen:Integer): Integer; stdcall; external 'ws2_32.dll' name 'bind';
  {$IFDEF FPC}
  function WSAAccept(s:TNativeSocket; addr:PSockAddr; addrlen:PLongint; lpfnCondition:LPCONDITIONPROC; dwCallbackData:DWORD ):TNativeSocket; stdcall; external 'ws2_32.dll' name 'WSAAccept';
  {$ENDIF}
 {$ENDIF}

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
   raise EError.Create('Invalid socket: '+inttostr(LastError));

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
 res:=_bind(sock,PSockAddr(@addr),sizeof(addr));
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
  if (res<>WSAEWOULDBLOCK) and (res<>WSAECONNREFUSED) then
   exit(false);
 end;
end;

procedure TSocket.Close;
begin
 CloseSocket(sock);
 sock:=0;
end;

function TSocket.Listen: integer;
begin

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

