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

// Parse input file into array of requests
function ParseRequests(const content:String8):TRequestArray;
var
  lines:Strings8;
  i,reqCount:integer;
  line:String8;
  nv:TNameValue;
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
    if nv.Named('ID') then
      cur.id:=nv.value
    else if nv.Named('CMD') then
      cur.cmd:=nv.value.ToLower
    else
      cur.params.Add(nv);
  end;
  SetLength(result,reqCount);
end;

function HandleRequest(const req:TRobotRequest):String8;
var
  i:integer;
  body:String8;
  ok:boolean;
begin
  for i:=0 to commandCount-1 do
    if commands[i].name=req.cmd then begin
      ok:=commands[i].handler(req,body);
      if ok then
        result:='ID: '+req.id+CRLF+'STATUS: OK'+CRLF+body+'==='+CRLF
      else
        result:='ID: '+req.id+CRLF+'STATUS: ERROR'+CRLF+'MSG: '+body+CRLF+'==='+CRLF;
      exit;
    end;
  result:='ID: '+req.id+CRLF+'STATUS: ERROR'+CRLF+'MSG: unknown command: '+req.cmd+CRLF+'==='+CRLF;
end;

procedure ProcessInputFile;
var
  content,response:String8;
  requests:TRequestArray;
  i:integer;
begin
  if not Files.Exists(INPUT_FILE) then exit;
  content:=Files.LoadAsString(INPUT_FILE);
  if content.IndexOf('===')<1 then exit; // wait for end marker

  Log.Msg('RobotAPI: processing input file');
  lastActivityTime:=CoreTime.Ticks;
  fastMode:=true;

  requests:=ParseRequests(content);
  response:='';
  for i:=0 to high(requests) do
    response:=response+HandleRequest(requests[i]);

  Files.Save(OUTPUT_FILE,response);
  Files.Delete(INPUT_FILE);
  Log.Msg('RobotAPI: processed %d request(s)',[length(requests)]);
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
  Log.Msg('RobotAPI: shutdown');
end;

end.
