{$APPTYPE CONSOLE}
program chat;
 uses SysUtils,EventMan,network,networking2,windows,myservis,classes;
 var
  i,v:integer;
  buf:array[1..100000] of byte;
  lPort,rPort:word;
  adr:string;
  ip:cardinal;
  port:word;
  c:TConnection;

 function Evt(event:EventStr;tag:integer):boolean;
  var
   i,s:integer;
   ptr:PByte;
   fl:boolean;
  begin
   result:=false;
   if UpperCase(event)='NET\CONN\USERMSG' then begin
    write('Message ',tag,' received. ');
    s:=GetMsg(tag,pointer(ptr));
    if s<0 then writeln('Data unaccessible.') else begin
     write('Size: ',s,' - ');
     fl:=true;
     for i:=1 to s do begin
      if ptr^<>i and 255 then fl:=false;
      inc(ptr);
     end;
     if fl then writeln('Valid') else writeln('INVALID');
     if ip=0 then GetMsgOrigin(tag,ip,port);
    end;
   end;

   if UpperCase(event)='NET\ONDATA' then begin
    write('Message ',tag,' received. ');
    s:=GetMsg(tag,pointer(ptr));
    if s<0 then writeln('Data unaccessible.') else begin
     write('Size: ',s,' - ');
     fl:=true;
     for i:=1 to s do begin
      if ptr^<>i and 255 then fl:=false;
      inc(ptr);
     end;
     if fl then writeln('Valid') else writeln('INVALID');
     if ip=0 then GetMsgOrigin(tag,ip,port);
    end;
   end else
    writeln(event,tag:10);
  end;

begin
 SetEventHandler('Net',Evt);
 UseLogFile('chat.log');
 SetLogMode(lmVerbose,'6');

 writeln('1 - LAN');
 writeln('2 - Internet server');
 writeln('3 - Internet client');
 write('Choose: ');
 readln(v);
 case v of
  1:begin
     NetInit(2000);
     c:=TConnection.Create;
     c.Connect(0,2000);
     for i:=1 to 10 do begin
      sleep(20*i);
      if c.connected then break;
     end;
     if not c.connected then begin
      writeln('Server not found, waiting for clients...');
      c.Accept;
     end;

{     port:=2000;
     NetInit(0);
     ip:=GetLanServerAddress(2000,true);
     if ip<>0 then begin
      writeln('Server found!');
     end else begin
      NetDone;
      NetInit(port);
      LanServerMode:=true;
      writeln('Waiting for clients');
     end;}
    end;
  2:begin
     NetInit(2000);
     c:=TConnection.Create(true);
{     ip:=0;
     NetInit(2000);
     writeln('Server mode. Can only accept messages.');}
    end;
  3:begin
     write('Enter local port: '); readln(lPort);
     NetInit(lPort);
     write('Enter server address: '); readln(adr);
     write('Resolving... ');
     ResolveAddress(adr,ip,port);
     if port=0 then port:=2000;
     if ip<>0 then begin
      writeln('done.');
     end else writeln('failed');

     c:=TConnection.Create;
     c.Connect(ip,port);
    end;
 end;

 for i:=1 to 100000 do buf[i]:=i;
 repeat
  try
  write('Enter data length to send, -1 to exit, -2 to reconnect: ');
  readln(v);
  if v<0 then begin
   if (v=-2) and not c.connected then c.Connect(ip,port);
   if c.connected then c.Disconnect;
   sleep(300);
   if v=-1 then break;
   continue;
  end;
  if c.connected then
   c.SendData(@buf,v)
  else writeln('Connection not established');
{  if ip<>0 then
   Send(ip,port,@buf,v)
  else writeln('Receive-only mode.');}
  except
   on e:Exception do writeln('Exception ',e.ClassName,' - ',e.Message);
  end;
 until false;
 NetDone;
 writeln('Done, press Enter to exit');
 readln;
end.