// Robot API: file-based protocol for external automation
// See robot_api_protocol.md for specification
//
// Copyright (C) 2026 Apus Software (www.apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$R-}
unit Apus.Engine.RobotAPI;
interface
uses Apus.Core, Apus.Types;

type
  TRobotRequest=record
    id:String8;
    cmd:String8;
    params:TNameValueList;
    function Param(const key:String8):String8;
  end;

  // handler returns true=OK (body=response), false=ERROR (body=error message)
  TRobotCommandHandler=function(const req:TRobotRequest; out body:String8):boolean;

  procedure InitRobotAPI;
  procedure PollRobotAPI;
  procedure DoneRobotAPI;
  procedure RegisterRobotCommand(const name:String8; handler:TRobotCommandHandler);

var
  robotAPIEnabled:boolean = {$IFDEF DEBUG}true{$ELSE}false{$ENDIF};

implementation
uses Apus.Conv, Apus.Strings, Apus.Log, Apus.Files, Apus.EventMan;

const
  INPUT_FILE  = 'robot_in.txt';
  OUTPUT_FILE = 'robot_out.txt';
  PENDING_TOKEN='@PENDING@';
  UTF8_BOM=#$EF#$BB#$BF;
  SLOW_INTERVAL = 500; // ms between checks in slow mode
  FAST_INTERVAL = 100; // ms between checks in fast mode
  FAST_TIMEOUT  = 5000; // ms of inactivity before returning to slow mode
  CRLF = #13#10;

type
  TCommandEntry=record
    name:String8;
    handler:TRobotCommandHandler;
  end;
  TRequestArray=array of TRobotRequest;

var
  commands:array of TCommandEntry;
  commandCount:integer;
  pendingRequests:TRequestArray;
  lastCheckTime:int64;
  lastActivityTime:int64;
  fastMode:boolean;
  initialized:boolean;

function TRobotRequest.Param(const key:String8):String8;
begin
  result:=params.Item[key];
end;

procedure RegisterRobotCommand(const name:String8; handler:TRobotCommandHandler);
begin
  if commandCount>=length(commands) then
    SetLength(commands,commandCount+16);
  commands[commandCount].name:=name.ToLower;
  commands[commandCount].handler:=handler;
  inc(commandCount);
end;

function GetCheckInterval:integer;
begin
  if fastMode then result:=FAST_INTERVAL
  else result:=SLOW_INTERVAL;
end;

function NormalizeHeaderKey(st:String8):String8;
begin
  result:=st.Trim;
  if UTF8.HasBOM(result) then
    Delete(result,1,3);
  // Be tolerant to editors/encodings that inject leading control/BOM-like bytes.
  while (length(result)>0) and not (result[1] in ['A'..'Z','a'..'z']) do
    Delete(result,1,1);
  result:=result.ToLower;
end;

// Parse input file into array of requests
function ParseRequests(const content:String8):TRequestArray;
var
  lines:Strings8;
  i,reqCount:integer;
  line:String8;
  nv:TNameValue;
  key:String8;
  cur:TRobotRequest;
begin
  SetLength(result,0);
  reqCount:=0;
  lines:=content.SplitLines;
  cur.id:='';
  cur.cmd:='';
  SetLength(cur.params.items,0);

  for i:=0 to high(lines) do begin
    line:=lines[i].Trim;
    if (i=0) and line.StartsWith(UTF8_BOM) then
      line:=line.Substr(4,length(line)-3).Trim;
    if (line='---') or (line='===') then begin
      if cur.cmd<>'' then begin
        if reqCount>=length(result) then
          SetLength(result,reqCount+8);
        result[reqCount]:=cur;
        inc(reqCount);
      end;
      cur.id:='';
      cur.cmd:='';
      SetLength(cur.params.items,0);
      continue;
    end;
    if line.IndexOf(':')<1 then continue;
    nv.InitFrom(line,':');
    key:=NormalizeHeaderKey(nv.name);
    if key='id' then
      cur.id:=nv.value
    else if key='cmd' then
      cur.cmd:=nv.value.ToLower
    else
      cur.params.Add(nv);
  end;
  SetLength(result,reqCount);
end;

function HandleRequest(const req:TRobotRequest; out pending:boolean):String8;
var
  i:integer;
  body:String8;
  ok:boolean;
begin
  pending:=false;
  if req.id='' then begin
    result:='ID: '+req.id+CRLF+'STATUS: ERROR'+CRLF+'MSG: ID parameter required'+CRLF+'==='+CRLF;
    exit;
  end;
  for i:=0 to commandCount-1 do
    if commands[i].name=req.cmd then begin
      Log.Info('RoboReq: '+commands[i].name);
      ok:=commands[i].handler(req,body);
      if ok then begin
        if body.Trim.StartsWith(PENDING_TOKEN) then begin
          pending:=true;
          result:='';
          exit;
        end;
        result:='ID: '+req.id+CRLF+'STATUS: OK'+CRLF+body+'==='+CRLF
      end else begin
        result:='ID: '+req.id+CRLF+'STATUS: ERROR'+CRLF+'MSG: '+body+CRLF+'==='+CRLF;
        Log.Warn('RoboReq FAIL: '+body);
      end;
      exit;
    end;
  result:='ID: '+req.id+CRLF+'STATUS: ERROR'+CRLF+'MSG: unknown command: '+req.cmd+CRLF+'==='+CRLF;
end;

procedure ProcessInputFile;
var
  content,response:String8;
  requests,newPending,allRequests:TRequestArray;
  i,requestCount,newCount,pendingCount:integer;
  isPending:boolean;
begin
  SetLength(requests,0);
  if Files.Exists(INPUT_FILE) then begin
    content:=Files.LoadAsString(INPUT_FILE);
    if content.IndexOf('===')>0 then begin
      Log.Msg('RobotAPI: processing input file');
      lastActivityTime:=CoreTime.Ticks;
      fastMode:=true;
      requests:=ParseRequests(content);
      Files.Delete(INPUT_FILE);
    end;
  end;

  newCount:=length(requests);
  pendingCount:=length(pendingRequests);
  requestCount:=newCount+pendingCount;
  if requestCount=0 then exit;

  SetLength(allRequests,requestCount);
  for i:=0 to pendingCount-1 do
    allRequests[i]:=pendingRequests[i];
  for i:=0 to newCount-1 do
    allRequests[pendingCount+i]:=requests[i];

  SetLength(newPending,0);
  response:='';
  for i:=0 to high(allRequests) do begin
    response:=response+HandleRequest(allRequests[i],isPending);
    if isPending then begin
      SetLength(newPending,length(newPending)+1);
      newPending[high(newPending)]:=allRequests[i];
    end;
  end;
  pendingRequests:=newPending;

  if response<>'' then
    Files.Save(OUTPUT_FILE,response);
  if length(pendingRequests)>0 then begin
    fastMode:=true;
    lastActivityTime:=CoreTime.Ticks;
  end;
  Log.Msg('RobotAPI: processed %d request(s), pending=%d',[requestCount,length(pendingRequests)]);
end;

// --- Built-in commands ---

function CmdSignal(const req:TRobotRequest; out body:String8):boolean;
var
  event:String8;
  tag:NativeInt;
begin
  event:=req.Param('EVENT');
  if event='' then begin
    body:='EVENT parameter required';
    exit(false);
  end;
  tag:=Conv.ToInt(req.Param('TAG'));
  Signal(event,tag);
  body:='';
  result:=true;
end;

procedure InitRobotAPI;
begin
  if not robotAPIEnabled then exit;
  RegisterRobotCommand('signal',@CmdSignal);
  fastMode:=false;
  lastCheckTime:=0;
  lastActivityTime:=0;
  SetLength(pendingRequests,0);
  initialized:=true;
  Log.Msg('RobotAPI: initialized (%d commands registered)',[commandCount]);
end;

procedure PollRobotAPI;
var
  now:int64;
begin
  if not initialized then exit;
  now:=CoreTime.Ticks;
  if now-lastCheckTime<GetCheckInterval then exit;
  lastCheckTime:=now;
  if fastMode and (lastActivityTime>0) and (now-lastActivityTime>FAST_TIMEOUT) then begin
    fastMode:=false;
    Log.Msg('RobotAPI: switching to slow polling');
  end;
  try
    ProcessInputFile;
  except
    on e:Exception do
      Log.Warn('RobotAPI: error processing input: '+String8(e.Message));
  end;
end;

procedure DoneRobotAPI;
begin
  if not initialized then exit;
  initialized:=false;
  SetLength(pendingRequests,0);
  Log.Msg('RobotAPI: shutdown');
end;

end.
