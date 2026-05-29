// TCP client/server library: single-threaded, nonblocking.

// Copyright (C) 2023 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.TCP;
interface
uses {$IFDEF MSWINDOWS}Windows, WinSock2,{$ELSE}Sockets, Apus.SocketCompat, {$ENDIF}
  Apus.Core, Apus.Types;

type
 // This object is created on server side for each connected client.
 // It represents server-side endpoint of a client-server connection and should
 // store any client-related data.
 TTCPServerUser=class
  remoteIP:cardinal;
  remotePort:word;
  created:TDateTime; // when this object was created
  lastData:TDateTime; // when last data was received
  constructor Create;
  destructor Destroy; override;
  procedure SendData(const buf:TBuffer); // use this to send response
  procedure Disconnect;
  // Override this to react on incoming data. Data read from buf may be unavailable next time,
  // so use Seek() to keep the current data if you to process later, when more data is available.
  procedure onDataReceived(var buf:TBuffer); virtual;
  procedure onConnected; virtual;
  procedure onDisconnected; virtual;
  function GetUserName:string; virtual; // return something to identify user
 private
  sock:TSocket;
  readPos,writePos:integer;
  data:ByteArray;
  sendBuf:ByteArray;
  sendReadPos,sendWritePos:integer;
  procedure FlushSendData;
  procedure ReadData; virtual; // Read data from socket
 end;

 TTCPServerUserClass=class of TTCPServerUser;

 // TCP Server instance
 TTCPServer=class
  users:array of TTCPServerUser;
  constructor Create(listenPort:word;userClass:TTCPServerUserClass);
  destructor Destroy; override;
  procedure Poll; // Call this periodically to keep the server running
 protected
  listenPort:word;
  sock:TSocket;
  userClass:TTCPServerUserClass;
  function AcceptNewConnection:boolean;
  procedure ReadData;
 end;

 // TCP Client instance
 TTCPClient=class
  connected:boolean; // connection established?
  connecting:boolean; // trying to connect?
  disconnected:boolean; // true after an established connection was broken
  constructor Create;
  destructor Destroy; override;
  // If waitMS>=0 - Connect() will wait for connection and reset to disconnected state if failed
  // if waitMS<0 - Connect() may return immediately with connecting=true state
  procedure Connect(serverAddress:string;waitMS:integer=-1);
  procedure Disconnect;
  procedure Poll;
  procedure SendData(const buf:TBuffer);
  // Methods to override
  procedure onConnect; virtual;
  procedure onDisconnect; virtual;
  procedure onDataReceived(var buf:TBuffer); virtual;
 protected
  sock:TSocket;
  data:ByteArray;
  readPos,writePos:integer;
  sendBuf:ByteArray;
  sendReadPos,sendWritePos:integer;
  procedure FlushSendData;
 end;

implementation
uses SysUtils, Apus.Log,
  {$IFNDEF MSWINDOWS}CNetDB,{$ENDIF}
  Apus.Conv;
{$IFNDEF FPC}
{$IFNDEF DELPHI}
  Define "DELPHI" symbol if you're using Delphi
{$ENDIF}
{$ENDIF}

const
 local_IP:cardinal=$7F000001; // localhost
 PAGE_SIZE = 30000;


 {$IFDEF MSWINDOWS}
  // many routines have different declaration in different WinSock2 import units
  {$IFDEF DELPHI}
  function bind(s: TSocket; name: PSockAddr; namelen: Integer): Integer; stdcall; external 'ws2_32.dll';
  {$ENDIF}
  {$IFDEF FPC}
  function WSAAccept(s:TSocket; addr:PSockAddr; addrlen:PLongint; lpfnCondition:LPCONDITIONPROC; dwCallbackData:DWORD ):TSocket; stdcall; external 'ws2_32.dll' name 'WSAAccept';
  {$ENDIF}
 {$ENDIF}

procedure ResolveAddress(resolveAdr:AnsiString;var resolvedIP:cardinal;var resolvedPort:word);
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
   port:=Conv.ToInt(copy(address,i+1,length(address)-i));
   SetLength(address,i-1);
  end;
  if address<>'' then begin
   fl:=true;
   for i:=1 to length(address) do
    if not (address[i] in ['0'..'9','.']) then fl:=false;
   if fl then begin
    {$IFDEF MSWINDOWS}
    address:=address+#0;
    ip:=inet_addr(@address[1]);
    {$ELSE}
    ip:=StrToNetAddr(address).s_addr;
    {$ENDIF}
   end else begin
    address:=address+#0;
    h:=GetHostByName(@address[1]);
    if h=nil then begin
     ip:=0;
    end else begin
     {$IFDEF MSWINDOWS}
     move(h^.h_addr^[0],ip,4);
     {$ELSE}
     if h^.h_addr_list<>nil then
      move(h^.h_addr_list^^,ip,4)
     else
      ip:=0;
     {$ENDIF}
    end;
   end;
  end else
   ip:=$FFFFFFFF;

  ResolveAdr:='';
  ResolvedIP:=ip;
  ResolvedPort:=port;
end;

{ TTCPServer }
constructor TTCPServer.Create(listenPort:word; userClass:TTCPServerUserClass);
var
  addr:SOCKADDR_IN;
  res:integer;
  arg:cardinal;
begin
  self.listenPort:=listenPort;
  self.userClass:=userClass;
  // create main socket
  sock:=socket(PF_INET,SOCK_STREAM,IPPROTO_IP);
  if sock=INVALID_SOCKET then
    raise EError.Create('Invalid socket: '+Conv.ToStr(WSAGetLastError));
  // bind
  addr.sin_family:=PF_INET;
  addr.sin_port:=htons(listenPort);
  addr.sin_addr.S_addr:=htonl(local_IP);

  res:=bind(sock,PSockAddr(@addr),sizeof(addr));
  if res<>0 then raise EError.Create('Bind failed: '+Conv.ToStr(WSAGetLastError));

  arg:=1;
  if ioctlsocket(sock,longint(FIONBIO),arg)<>0 then
    raise EError.Create('Cannot make non-blocking socket');

  res:=listen(sock,SOMAXCONN);
  if res<>0 then raise EError.Create('Listen returned error '+Conv.ToStr(WSAGetLastError));
  Log.Msg('Server: Listening on port %d',[listenPort]);
end;

destructor TTCPServer.Destroy;
begin
  if sock<>0 then
    CloseSocket(sock);
  Log.Force('Server destroyed');
  inherited;
end;

procedure TTCPServer.Poll;
var
  i:integer;
begin
  while AcceptNewConnection do;
  ReadData;
  i:=0;
  while i<=high(users) do begin
   users[i].FlushSendData;
   if users[i].sock=0 then begin
     // User disconnected
     Log.Msg('Client %s disconnected',[users[i].GetUserName]);
     users[i].Free;
     users[i]:=users[high(users)];
     SetLength(users,length(users)-1);
     continue;
   end;
   inc(i);
  end;
end;

function TTCPServer.AcceptNewConnection:boolean;
var
  s:TSocket;
  i,res,n:integer;
  addr:SockAddr_IN;
  addrLen:integer;
  user:TTCPServerUser;
begin
    result:=false;
    addrlen:=sizeof(addr);
    s:=WSAAccept(sock,@addr,@addrlen,nil,0);
    if s=INVALID_SOCKET then begin
       res:=WSAGetLastError;
       if (res<>WSAEWOULDBLOCK) and (res<>WSAECONNREFUSED) then
         Log.Warn('ACCEPT failed with '+Conv.ToStr(res));
    end else begin
      // Success! Create new user
      user:=userClass.Create;
      user.sock:=s;
      user.remoteIP:=addr.sin_addr.S_addr;
      user.remotePort:=ntohs(addr.sin_port);
      n:=length(users);
      SetLength(users,n+1);
      users[n]:=user;
      Log.Msg('Client connected: %s:%d ',[Conv.FormatIp(user.remoteIP),user.remotePort]);
      result:=true;
      try
        user.onConnected;
      except
        on e:Exception do Log.Warn('onConnected error: '+ExceptionMsg(e));
      end;
    end;
end;

procedure TTCPServer.ReadData;
var
  readSet:TFDSet;
  timeout:TTimeVal;
  i,j,u,uStart,res:integer;
begin
  readset.fd_count:=0;
  // Select sockets to read
  readset.fd_count:=0;
  uStart:=0;
  for i:=0 to High(users) do begin
    if users[i].sock=0 then continue;
    readset.fd_array[readset.fd_count]:=users[i].sock;
    inc(readset.fd_count);
    if (i=high(users)) or (readset.fd_count>=high(readset.fd_array)) then begin
      fillchar(timeout,sizeof(timeout),0);
      res:=select(0,@readset,nil,nil,@timeout);
      if res=SOCKET_ERROR then
        Log.Warn('Select error: '+Conv.ToStr(WSAGetLastError));

      if res>0 then // some sockets are ready
        for j:=0 to readset.fd_count-1 do
          for u:=uStart to i do
            if users[u].sock=readset.fd_array[j] then
              users[u].ReadData;

      readset.fd_count:=0; // continue
      uStart:=i+1;
    end;
  end;
end;

procedure CutBuffer(var data:ByteArray;var readPos:integer;var writePos:integer);
begin
  data:=copy(data,PAGE_SIZE,length(data)-PAGE_SIZE);
  dec(readPos,PAGE_SIZE);
  dec(writePos,PAGE_SIZE);
end;

procedure QueueData(var queue:ByteArray;var writePos:integer;src:pointer;size:integer);
var
  newSize:integer;
begin
  if size<=0 then exit;
  if length(queue)<writePos+size then begin
    newSize:=length(queue)*2;
    if newSize<65536 then
      newSize:=65536;
    if newSize<writePos+size then
      newSize:=writePos+size;
    SetLength(queue,newSize);
  end;
  move(src^,queue[writePos],size);
  inc(writePos,size);
end;

{ TTCPServerUser }

constructor TTCPServerUser.Create;
begin
  created:=Now;
end;

destructor TTCPServerUser.Destroy;
begin
  onDisconnected;
  inherited;
end;

procedure TTCPServerUser.Disconnect;
begin
  CloseSocket(sock);
  sock:=0;
  sendReadPos:=0;
  sendWritePos:=0;
end;

function TTCPServerUser.GetUserName:string;
begin
  result:=Conv.FormatIp(remoteIP)+':'+Conv.ToStr(remotePort);
end;

procedure TTCPServerUser.onConnected;
begin
end;

procedure TTCPServerUser.onDataReceived(var buf:TBuffer);
begin
end;

procedure TTCPServerUser.onDisconnected;
begin
end;

procedure TTCPServerUser.ReadData;
var
  res:integer;
  buf:TBuffer;
begin
  if length(data)<writePos+65536 then
    SetLength(data,length(data)+65536);
  res:=recv(sock,data[writePos],length(data)-writePos,0);
  if res>0 then begin
    Log.Info('User %s sent %d bytes',[GetUserName,res]);
    lastData:=Now;
    inc(writePos,res);
    buf.CreateFrom(data[readPos],writePos-readPos);
    try
      onDataReceived(buf);
      inc(readPos,buf.CurrentPos);
    except
      on e:Exception do begin
        Log.Warn('User %s onReceive error: '+ExceptionMsg(e),[GetUserName]);
        CloseSocket(sock);
        sock:=0;
        Log.Warn('User %s disconnected',[GetUserName]);
      end;
    end;
    if readPos>PAGE_SIZE then
      CutBuffer(data,readPos,writePos);
  end else
  if res=0 then begin
    Log.Msg('Client %s closed connection',[GetUserName]);
    CloseSocket(sock);
    sock:=0;
  end else begin
    Log.Force('RECV error: '+Conv.ToStr(WSAGetLastError));
    CloseSocket(sock);
    sock:=0;
  end;
end;

procedure TTCPServerUser.FlushSendData;
var
  res:integer;
begin
  while (sock<>0) and (sendReadPos<sendWritePos) do begin
    res:=Send(sock,sendBuf[sendReadPos],sendWritePos-sendReadPos,0);
    if res=SOCKET_ERROR then begin
      res:=WSAGetLastError;
      if res=WSAEWOULDBLOCK then exit;
      Log.Warn('Send error: '+Conv.ToStr(res));
      CloseSocket(sock);
      sock:=0;
      Log.Msg('User %s socket closed',[GetUserName]);
      exit;
    end;
    if res<=0 then begin
      Log.Warn('Socket closed while sending to user %s',[GetUserName]);
      CloseSocket(sock);
      sock:=0;
      exit;
    end;
    inc(sendReadPos,res);
    if sendReadPos>PAGE_SIZE then
      CutBuffer(sendBuf,sendReadPos,sendWritePos);
  end;
  if sendReadPos=sendWritePos then begin
    sendReadPos:=0;
    sendWritePos:=0;
  end;
end;

procedure TTCPServerUser.SendData(const buf:TBuffer);
var
  res:integer;
begin
  if sock=0 then begin
    Log.Msg('Trying to send to unconnected user %s',[GetUserName]);
    exit;
  end;
  Log.Info('Sending %d bytes to user %s',[buf.size,GetUserName]);
  Log.Debug(Conv.HexDump(buf.data,Min(16,buf.size)));
  if (sendReadPos=sendWritePos) and (buf.size>0) then begin
    res:=Send(sock,buf.data^,buf.size,0);
    if res=buf.size then exit;
    if res=SOCKET_ERROR then begin
      res:=WSAGetLastError;
      if res<>WSAEWOULDBLOCK then begin
        Log.Warn('Send error: '+Conv.ToStr(res));
        CloseSocket(sock);
        sock:=0;
        Log.Msg('User %s socket closed',[GetUserName]);
      end;
      res:=0;
    end;
    if res<0 then res:=0;
    if res>buf.size then res:=buf.size;
    QueueData(sendBuf,sendWritePos,@buf.data[res],buf.size-res);
    FlushSendData;
    exit;
  end;
  QueueData(sendBuf,sendWritePos,buf.data,buf.size);
  FlushSendData;
end;

{ TTCPClient }

constructor TTCPClient.Create;
begin
  connected:=false;
end;

destructor TTCPClient.Destroy;
begin
  if sock<>0 then Disconnect;
  inherited;
end;

procedure TTCPClient.Connect(serverAddress:string;waitMS:integer=-1);
var
  addr:SOCKADDR_IN;
  res:integer;
  arg:cardinal;
  ip:cardinal;
  port:word;
  time:int64;
begin
  ASSERT(connected=false,'Client already connected');
  Log.Msg('Connecting to '+serverAddress);
  // create main socket
  sock:=socket(PF_INET,SOCK_STREAM,IPPROTO_IP);
  if sock=INVALID_SOCKET then
    raise EError.Create('Invalid socket: '+Conv.ToStr(WSAGetLastError));

  arg:=1;
  if ioctlsocket(sock,longint(FIONBIO),arg)<>0 then
    raise EError.Create('Cannot make non-blocking socket');

  ResolveAddress(serverAddress,ip,port);
  Log.Msg('Address resolved: %s:%d',[Conv.FormatIp(ip),port]);
  addr.sin_family:=PF_INET;
  addr.sin_port:=htons(port);
  addr.sin_addr.S_addr:=ip; // Address already correct

  connecting:=true;
  disconnected:=false;
  {$IFDEF MSWINDOWS}
  res:=WinSock2.Connect(sock,TSockAddr(addr),sizeof(addr));
  {$ELSE}
  res:=SocketConnect(sock,TSockAddr(addr),sizeof(addr));
  {$ENDIF}
  if (res<>0) then begin
   res:=WSAGetLastError;
   if res<>WSAEWOULDBLOCK then begin
    connecting:=false;
    CloseSocket(sock);
    sock:=0;
    raise EError.Create('Connect error '+Conv.ToStr(res));
   end;
  end else begin
   connected:=true;
   connecting:=false;
   onConnect;
  end;
  if waitMS<0 then exit;
  time:=CoreTime.Ticks+waitMS;
  repeat
   Sleep(1);
   Poll;
   if connected or not connecting then exit;
  until CoreTime.Ticks>=time;
  // Failed to connect
  Log.Warn('Connection failed');
  connecting:=false;
  if sock<>0 then begin
   CloseSocket(sock);
   sock:=0;
  end;
end;

procedure TTCPClient.Disconnect;
begin
  if sock=0 then exit;
  CloseSocket(sock);
  sock:=0;
  Log.Force('Disconnected');
  onDisconnect;
  disconnected:=true;
end;

procedure TTCPClient.Poll;
var
  res:integer;
  buf:TBuffer;
  writeSet,errorSet:TFdSet;
  timeout:TTimeVal;
begin
  if connecting and not connected then begin
    // Check for connection
    writeSet.fd_count:=1;
    writeSet.fd_array[0]:=sock;
    errorSet.fd_count:=1;
    errorSet.fd_array[0]:=sock;
    fillchar(timeout,sizeof(timeout),0);
    res:=select(0,nil,@writeSet,@errorSet,@timeout);
    if res=SOCKET_ERROR then
      raise EWarning.Create('Select 1 error: '+Conv.ToStr(WSAGetLastError));
    if errorSet.fd_count>0 then begin
      Log.Warn('Connection failed because of error!');
      connecting:=false;
      CloseSocket(sock);
      sock:=0;
      exit;
    end;
    if writeSet.fd_count>0 then begin
      connected:=true;
      connecting:=false;
      onConnect;
    end;
  end;
  if not connected then exit;
  if sendReadPos<sendWritePos then
    FlushSendData;
  if length(data)<writePos+65536 then
    SetLength(data,length(data)+65536);
  res:=recv(sock,data[writePos],length(data)-writePos,0);
  if res=SOCKET_ERROR then begin
    res:=WSAGetLastError;
    if res<>WSAEWOULDBLOCK then begin
      Log.Warn('Socket read error: %d',[res]);
      connected:=false;
      CloseSocket(sock);
      sock:=0;
      Log.Force('Disconnected');
      onDisconnect;
      disconnected:=true;
    end;
    exit;
  end;
  if res>0 then begin
    // Some data received
    Log.Info('Received %d bytes: '+Conv.HexDump(@data[readpos],Min(res,16)),[res]);
    inc(writePos,res);
    buf.CreateFrom(data[readPos],writePos-readPos);
    try
      onDataReceived(buf);
      inc(readPos,buf.CurrentPos);
    except
      on e:Exception do Log.Warn('onReceive error: '+ExceptionMsg(e));
    end;
    if readPos>PAGE_SIZE then
      CutBuffer(data,readPos,writePos);
  end else
  if res=0 then begin
    Log.Msg('Server closed connection');
    connected:=false;
    CloseSocket(sock);
    sock:=0;
    Log.Force('Disconnected');
    onDisconnect;
    disconnected:=true;
  end;
end;

procedure TTCPClient.FlushSendData;
var
  res:integer;
begin
  while (sock<>0) and (sendReadPos<sendWritePos) do begin
    res:=Send(sock,sendBuf[sendReadPos],sendWritePos-sendReadPos,0);
    if res=SOCKET_ERROR then begin
      res:=WSAGetLastError;
      if res=WSAEWOULDBLOCK then exit;
      Log.Warn('Send error: '+Conv.ToStr(res));
      Disconnect;
      exit;
    end;
    if res<=0 then begin
      Disconnect;
      exit;
    end;
    inc(sendReadPos,res);
    if sendReadPos>PAGE_SIZE then
      CutBuffer(sendBuf,sendReadPos,sendWritePos);
  end;
  if sendReadPos=sendWritePos then begin
    sendReadPos:=0;
    sendWritePos:=0;
  end;
end;

procedure TTCPClient.SendData(const buf:TBuffer);
var
  res:integer;
begin
  ASSERT(connected);
  if (sendReadPos=sendWritePos) and (buf.size>0) then begin
    res:=Send(sock,buf.data^,buf.size,0);
    if res=buf.size then exit;
    if res=SOCKET_ERROR then begin
      res:=WSAGetLastError;
      if res<>WSAEWOULDBLOCK then begin
        Log.Warn('Send error: '+Conv.ToStr(res));
        Disconnect;
        exit;
      end;
      res:=0;
    end;
    if res<0 then res:=0;
    if res>buf.size then res:=buf.size;
    QueueData(sendBuf,sendWritePos,@buf.data[res],buf.size-res);
    FlushSendData;
    exit;
  end;
  QueueData(sendBuf,sendWritePos,buf.data,buf.size);
  FlushSendData;
end;

procedure TTCPClient.onDataReceived(var buf: TBuffer);
begin
end;

procedure TTCPClient.onConnect;
begin
end;

procedure TTCPClient.onDisconnect;
begin
end;

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

