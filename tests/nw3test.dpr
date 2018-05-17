program nw3test;
{$APPTYPE CONSOLE}
uses
  SysUtils,MyServis,EventMan,httpRequests,Networking3;

 const
  server='127.0.0.1:8888';
  login='Cooler@tut.by';
  password='AHpsubsb';
  clientInfo='CLIENTINFO';

 var
  logged:boolean; 

function EventHandler(event:eventStr;tag:integer):boolean;
 var
  msg:TNetMessage;
  st:string;
 begin
  if event='Net\Conn3\Recv' then begin
   GetRequestResult(tag,st);
   writeln(FormatDateTime('hh:nn:ss.zzz',Now),' Received: '+st);
   exit;
  end;
  writeln('Event: ',event,' ',tag);
  event:=UpperCase(event);
  result:=true;
  if event='NET\CONN3\DATARECEIVED' then begin
   GetNetMessage(tag,msg);
   writeln(' Data received: '+ join(msg.values,'|'));
   LogMessage('Data received: '+ join(msg.values,'|'));
  end;
  if event='NET\CONN3\LOGGED' then begin
   logged:=true;
  end;
 end;

procedure TestRequests;
 begin
  repeat
   writeln(FormatDateTime('hh:nn:ss.zzz',Now),' sending... ');
   HTTPrequest('astralheroes.com'{:2992/checkvalue?email=cooler@tut.by'},'','Net\Conn3\Recv');
   sleep(2000);
  until false;
 end;

begin
 randomize;
 UseLogFile('game.log');
 SetLogMode(lmVerbose);
 SetEventHandler('Net\Conn3',EventHandler,async);

 TestRequests;

 Connect('127.0.0.1:8888','cooler@tut.by','AHpsubsb','CLIENT');
 sleep(5000);
 exit;

 UseLogFile('nw3test.log');
 SetlogMode(lmVerbose);
 writeln('Client-server connection test.');
{ CreateAccount(server,'Test@spectromancer.com','12345','Test1',2);
 readln;
 exit;}
 Connect(server,login,password,clientinfo);
 repeat
  sleep(200);
  write('#');
 until logged;
 writeln;
 writeln('Connected!');
 writeln('Set autosearch=off');
 SendData([32,2]);
 readln;
 writeln('Disconneting');
 Disconnect;
 sleep(500);
 LogMessage('Exit!');
end.
