// WinSock-style socket compatibility helpers for FPC/Unix.

// Copyright (C) 2026 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.SocketCompat;

interface

uses
  BaseUnix, Sockets;

const
  INVALID_SOCKET = -1;
  SOCKET_ERROR = -1;
  WSAEWOULDBLOCK = ESockEWOULDBLOCK;
  WSAECONNREFUSED = ESysECONNREFUSED;
  FIONBIO = 0;

type
  TSocket = Sockets.TSocket;
  PSockAddr = Sockets.PSockAddr;
  TSockAddr = Sockets.TSockAddr;
  SOCKADDR_IN = Sockets.sockaddr_in;
  TTimeVal = BaseUnix.TTimeVal;
  PTimeVal = BaseUnix.PTimeVal;

  TFDSet = record
    fd_count: LongInt;
    fd_array: array[0..63] of TSocket;
  end;
  PFDSet = ^TFDSet;

function socket(domain, xtype, protocol: LongInt): TSocket;
function bind(s: TSocket; name: PSockAddr; namelen: LongInt): LongInt;
function listen(s: TSocket; backlog: LongInt): LongInt;
function accept(s: TSocket; addr: PSockAddr; addrlen: PLongInt): TSocket;
function recv(s: TSocket; var buf; len: SizeUInt; flags: LongInt): LongInt;
function send(s: TSocket; const buf; len: SizeUInt; flags: LongInt): LongInt;
function ioctlsocket(s: TSocket; cmd: LongInt; var arg: Cardinal): LongInt;
function select(nfds: LongInt; readfds, writefds, exceptfds: PFDSet; timeout: PTimeVal): LongInt;
function WSAGetLastError: LongInt;
function WSAAccept(s: TSocket; addr: PSockAddr; addrlen: PLongInt; lpfnCondition: Pointer; dwCallbackData: PtrUInt): TSocket;
function SocketConnect(s: TSocket; const addr: TSockAddr; namelen: LongInt): LongInt;

implementation

function socket(domain, xtype, protocol: LongInt): TSocket;
begin
  result := fpSocket(domain, xtype, protocol);
end;

function bind(s: TSocket; name: PSockAddr; namelen: LongInt): LongInt;
begin
  result := fpBind(s, name, namelen);
end;

function listen(s: TSocket; backlog: LongInt): LongInt;
begin
  result := fpListen(s, backlog);
end;

function accept(s: TSocket; addr: PSockAddr; addrlen: PLongInt): TSocket;
var
  len: TSockLen;
begin
  len := addrlen^;
  result := fpAccept(s, addr, @len);
  addrlen^ := len;
end;

function recv(s: TSocket; var buf; len: SizeUInt; flags: LongInt): LongInt;
begin
  result := fpRecv(s, @buf, len, flags);
end;

function send(s: TSocket; const buf; len: SizeUInt; flags: LongInt): LongInt;
begin
  result := fpSend(s, @buf, len, flags);
end;

function ioctlsocket(s: TSocket; cmd: LongInt; var arg: Cardinal): LongInt;
var
  flags: LongInt;
begin
  flags := fpFcntl(s, F_GETFL, 0);
  if flags < 0 then exit(SOCKET_ERROR);
  if arg <> 0 then
    flags := flags or O_NONBLOCK
  else
    flags := flags and not O_NONBLOCK;
  result := fpFcntl(s, F_SETFL, flags);
end;

procedure BuildFdSet(src: PFDSet; var dst: BaseUnix.TFDSet; var maxfd: LongInt);
var
  i: Integer;
begin
  fpFD_ZERO(dst);
  if src = nil then exit;
  for i := 0 to src^.fd_count - 1 do begin
    fpFD_SET(src^.fd_array[i], dst);
    if src^.fd_array[i] > maxfd then maxfd := src^.fd_array[i];
  end;
end;

procedure FilterFdSet(var dst: TFDSet; const src: BaseUnix.TFDSet);
var
  i, n: Integer;
begin
  n := 0;
  for i := 0 to dst.fd_count - 1 do
    if fpFD_ISSET(dst.fd_array[i], src) <> 0 then begin
      dst.fd_array[n] := dst.fd_array[i];
      inc(n);
    end;
  dst.fd_count := n;
end;

function select(nfds: LongInt; readfds, writefds, exceptfds: PFDSet; timeout: PTimeVal): LongInt;
var
  readSet, writeSet, exceptSet: BaseUnix.TFDSet;
  readPtr, writePtr, exceptPtr: BaseUnix.PFDSet;
  maxfd: LongInt;
begin
  maxfd := -1;
  readPtr := nil;
  writePtr := nil;
  exceptPtr := nil;
  if readfds <> nil then begin
    BuildFdSet(readfds, readSet, maxfd);
    readPtr := @readSet;
  end;
  if writefds <> nil then begin
    BuildFdSet(writefds, writeSet, maxfd);
    writePtr := @writeSet;
  end;
  if exceptfds <> nil then begin
    BuildFdSet(exceptfds, exceptSet, maxfd);
    exceptPtr := @exceptSet;
  end;
  if nfds <= 0 then nfds := maxfd + 1;
  result := fpSelect(nfds, readPtr, writePtr, exceptPtr, timeout);
  if result > 0 then begin
    if readfds <> nil then FilterFdSet(readfds^, readSet);
    if writefds <> nil then FilterFdSet(writefds^, writeSet);
    if exceptfds <> nil then FilterFdSet(exceptfds^, exceptSet);
  end else begin
    if readfds <> nil then readfds^.fd_count := 0;
    if writefds <> nil then writefds^.fd_count := 0;
    if exceptfds <> nil then exceptfds^.fd_count := 0;
  end;
end;

function WSAGetLastError: LongInt;
begin
  result := SocketError;
end;

function WSAAccept(s: TSocket; addr: PSockAddr; addrlen: PLongInt; lpfnCondition: Pointer; dwCallbackData: PtrUInt): TSocket;
begin
  result := accept(s, addr, addrlen);
end;

function SocketConnect(s: TSocket; const addr: TSockAddr; namelen: LongInt): LongInt;
begin
  result := fpConnect(s, @addr, namelen);
end;

end.
