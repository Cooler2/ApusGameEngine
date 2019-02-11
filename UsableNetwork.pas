unit UsableNetwork;

interface
uses SysUtils,EventMan,networking2,MyServis,Classes,EngineAPI,UIScene,BasicGame;
type
 tNetData=array[0..39999] of byte;
 pNetData=^TNetData;

var connected:boolean=false;
    c:TConnection=nil;
    Config,Server:string;
    databuf:tNetData;
    ServerPort:word=2991;


procedure InitUsableNetwork(gamept:TObject;rootDir:string='');
procedure DoneUsableNetwork;
procedure SearchLanConnection(port:integer);
procedure Login(adr:string;port:integer);
procedure BreakConnection;
procedure SendData(DataSize:integer;DataPointer:Pointer);
function GetNetMsg(handle:integer;var data:pointer):integer;

implementation
uses network;
type
 TLanLoginThread = class(TThread)
  running:boolean;
  procedure Execute; override;
 end;

 tOnlineLoginThread = class(TThread)
  running:boolean;
  procedure Execute; override;
 end;

var wasinit:boolean=false;
    ip:cardinal;
    workingport:word;
    LanLogging,onlinelogging,needonline:boolean;
    LastLoggingTime:integer;
    LanThr:TLanLoginThread;
    OnlineThr:TOnlineLoginThread;
    GamePointer:TBasicGame;

procedure SignalToVisibleScenes(event:string;tag:integer);
var i,n:integer;
    s:array[1..50] of string[64];
begin
 n:=0;
 with GamePointer do
 begin
  for i:=low(scenes) to high(scenes) do
   if (scenes[i]<>nil) and (scenes[i].Activated) then
  with scenes[i] as TUIScene do
  begin
   begin
    inc(n);
    s[n]:='UI\'+name+'\'+event;
   end;
  end;
 end;
 for i:=1 to n do
 begin
  ForceLogMessage(s[i]);
  Signal(s[i],tag);
 end;
end;

function KillConnection(param:integer):integer;
begin
 ForceLogMessage('Trying to kill connection');
 if c<>nil then
 begin
  FreeAndNil(c);
  {$IFNDEF MSWINDOWS}
  NetDone;
  {$ENDIF}
 end else
  ForceLogMessage('c=nil');
 result:=1;
 ForceLogMessage('KillConn done');
end;

function EventHandler(event:EventStr;tag:integer):boolean;
var q,n,l:integer;
    pdata:pNetData;
    s:string;
begin
 event:=uppercase(event);
 if copy(event,1,3)='NET' then
  ForceLogMessage(event);
 if (event='ENGINE\AFTERMAINLOOP')and(lanlogging) then
  LanThr.Terminate;
 if (event='ENGINE\AFTERMAINLOOP')and(onlinelogging) then
  OnlineThr.Terminate;

 if event='NET\CONN\CONNECTED' then
 begin
  if ((config<>'AUTO')and(LanLogging=false)and(needonline=false))or((needonline)and(onlinelogging=false)) then
  begin
   c.Disconnect;
  end else
  begin
   connected:=true;
   LanLogging:=false;
   OnlineLogging:=false;
   SignalToVisibleScenes('ConnectionEstablished',0);
  end;
 end;

 if (event='NET\CONN\CONNECTIONBROKEN')or(event='NET\CONN\CONNECTIONCLOSED') then
 begin
  if connected then
  begin
   connected:=false;
   SignalToVisibleScenes('ConnectionBroken',0);
   BreakConnection;
  end;
 end;

 if event='NET\CONN\USERMSG' then
 begin
  n:=GetNetMsg(tag,pointer(pdata));
  ForceLogMessage('Data received, size '+inttostr(n));
  s:='';
  l:=n; if l>2000 then l:=2000;
  for q:=1 to l do s:=s+' '+inttostr(pdata[q-1]);
  ForceLogMessage(s);
  SignalToVisibleScenes('NetData',tag);
 end;
 if event='NET\KILLCONNECTION' then
 begin
  gamepointer.RunAsync(@KillConnection,0);
 end;
end;

procedure InitUsableNetwork;
var q:integer;
    f:text;
    fname:string;
begin
 if wasinit then exit;
// ForceWANmode:=true;
// ConnectionsOnly:=true;
 GamePointer:=GamePt as TBasicGame;
 SetEventHandler('Net',EventHandler,emQueued);
 SetEventHandler('Engine\',EventHandler,emQueued);
 wasinit:=true;
 lanlogging:=false;
 onlinelogging:=false;
 needonline:=false;
 fname:=FileName(rootDir+'Network.cfg');
 if FileExists(fname) then
 begin
  assign(f,fname);
  reset(f);
  readln(f,Config);
  Config:=uppercase(Config);
  close(f);
 end else Config:='AUTO';
 fname:=FileName(rootDir+'server.cfg');
 if FileExists(fname) then
 begin
  assign(f,fname);
  reset(f);
  readln(f,server);
  q:=pos(':',server);
  if q>0 then begin
   serverPort:=StrToInt(copy(server,q+1,100));
   SetLength(server,q-1);
  end;
//  Config:=uppercase(Config);
  close(f);
 end else server:='127.0.0.1';
// NetInit(0);
end;

procedure DoneUsableNetwork;
begin
 if (c<>nil) and (c.connected) then begin
  c.Disconnect;
  sleep(100);
 end;
 NetDone;
 sleep(50);
end;

procedure TLanLoginThread.Execute;
begin
 LanLogging:=true;
 repeat
  if (GetCurTime-LastLoggingTime)>600 then
   c.Accept;
  if abs(GetCurTime-LastLoggingTime)>4000 then
  begin
   LastLoggingTime:=GetCurtime;
   if not c.connected then c.Connect(ip,workingport);
  end;
  sleep(500);
 until LanLogging=false;
end;

procedure TOnlineLoginThread.Execute;
var t:integer;
begin
 needonline:=true;
 sleep(500);
 OnlineLogging:=true;
 t:=getcurtime;
 c.Connect(ip,workingport);
 repeat
  sleep(10);
 until (getcurtime-t>1500)or(onlinelogging=false);
 if onlineLogging then begin
  c.Connect(ip,workingport);
  repeat
   sleep(10);
  until (getcurtime-t>3000)or(onlinelogging=false);
 end;
 if onlineLogging then begin
  c.Connect(ip,workingport);
  repeat
   sleep(10);
  until (getcurtime-t>5000)or(onlinelogging=false);
 end;
 if onlinelogging then SignalToVisibleScenes('NoReply',0);
 needonline:=false;
end;

procedure SearchLanConnection(port:integer);
begin
 if WasInit=false then exit;
 NetDone;
 sleep(100);
 netInit(port);
 sleep(100);
{ if Config='AUTO' then
 begin
  if c=nil then
   c:=TConnection.Create;
  c.Connect(0,port);
  workingport:=port;
 end else
 begin}
 if config='AUTO' then ip:=0 else
  GetInternetAddress(Config,ip,workingport);
 workingport:=port;
 if c=nil then
  c:=TConnection.Create;
//  if ip<>0 then
 LanThr:=TLanLoginThread.Create(false);
// end;
end;

procedure Login(adr:string;port:integer);
//var
// localport:word;
// UDP:UDPSocket2;
begin
 if (c=nil) {$IFDEF IOS}or true{$ENDIF} then begin
   // выбор локального порта
{   localport:=2899+random(1000);
   repeat
    inc(localPort); inc(i);
    try
     UDP:=UDPSocket2.Create(localPort,false);
    except
     on e:exception do continue;
    end;
    break;
   until i=10;
   if localport=3991 then raise EError.Create('No port available');
   UDP.Destroy;
   ForceLogMessage('Local port: '+inttostr(localport));}
   NetDone;
   NetInit(0);
   c:=TConnection.Create;
 end;
 GetInternetAddress(adr,ip,workingport);
 workingport:=port;
 if ip<>0 then begin
{  if onlineThr<>nil then
   ForceLogMessage('Thread is working now')
  else}
  OnlineThr:=TOnlineLoginThread.Create(false);
 end else
  SignalToVisibleScenes('CANNTCONNECT',0);
end;

procedure BreakConnection;
begin
 if c=nil then exit;
 if (connected)or(c.connected) then
  c.Disconnect;
 if LanLogging then
 begin
  LanLogging:=false;
  LanThr.Terminate;
 end;
 if onlineLogging then
 begin
  OnlineLogging:=false;
  OnlineThr.Terminate;
 end;
 connected:=false;
 if c<>nil then DelayedSignal('Net\KillConnection',200);
end;

procedure SendData(DataSize:integer;DataPointer:Pointer);
var s:string;
    q:integer;
    d:pnetdata;
begin
 if connected then
 begin
  ForceLogMessage('Data sending, size '+inttostr(datasize));
  s:='';
  d:=datapointer;
  for q:=1 to datasize do s:=s+' '+inttostr(d[q-1]);
  ForceLogMessage(s);
  c.SendData(datapointer,datasize);
 end;
end;

function GetNetMsg(handle:integer;var data:pointer):integer;
begin
 result:=GetMsg(handle,data);
end;

end.