// Robot API: file-based protocol for external automation
// See robot_api_protocol.md for specification
//
// Copyright (C) 2026 Apus Software (www.apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$R-}
unit Apus.Engine.RobotAPI;
interface
uses Apus.Core;

  procedure InitRobotAPI;
  procedure PollRobotAPI;
  procedure DoneRobotAPI;

var
  robotAPIEnabled:boolean = {$IFDEF DEBUG}true{$ELSE}false{$ENDIF};

implementation
uses Apus.Conv, Apus.Strings, Apus.Log, Apus.Files,
  Apus.Engine.API, Apus.Engine.Game, Apus.Engine.Scene;

type
  TRequest=record
    id:String8;
    cmd:String8;
    params:array of record
      key,value:String8;
    end;
  end;

const
  INPUT_FILE  = 'robot_in.txt';
  OUTPUT_FILE = 'robot_out.txt';
  SLOW_INTERVAL = 500; // ms between checks in slow mode
  FAST_INTERVAL = 100; // ms between checks in fast mode
  FAST_TIMEOUT  = 5000; // ms of inactivity before returning to slow mode

var
  lastCheckTime:int64;
  lastActivityTime:int64;
  fastMode:boolean;
  initialized:boolean;

function GetCheckInterval:integer;
begin
  if fastMode then result:=FAST_INTERVAL
  else result:=SLOW_INTERVAL;
end;

function GetParam(const req:TRequest; const key:String8):String8;
var
  i:integer;
begin
  result:='';
  for i:=0 to high(req.params) do
    if req.params[i].key.Same(key) then
      exit(req.params[i].value);
end;

// Parse input file into array of requests
function ParseRequests(const content:String8):TArray<TRequest>;
var
  lines:Strings8;
  i,reqCount:integer;
  line,key,value:String8;
  p:integer;
  cur:TRequest;
begin
  result:=nil;
  reqCount:=0;
  lines:=content.SplitLines;
  cur.id:='';
  cur.cmd:='';
  SetLength(cur.params,0);

  for i:=0 to high(lines) do begin
    line:=lines[i].Trim;
    if (line='---') or (line='===') then begin
      // finalize current request
      if cur.cmd<>'' then begin
        if reqCount>=length(result) then
          SetLength(result,reqCount+8);
        result[reqCount]:=cur;
        inc(reqCount);
      end;
      cur.id:='';
      cur.cmd:='';
      SetLength(cur.params,0);
      continue;
    end;
    p:=line.IndexOf(':');
    if p<1 then continue;
    key:=String8(Copy(line,1,p-1)).Trim;
    value:=String8(Copy(line,p+1,length(line))).Trim;
    if key.Same('ID') then
      cur.id:=value
    else if key.Same('CMD') then
      cur.cmd:=value.ToLower
    else begin
      SetLength(cur.params,length(cur.params)+1);
      cur.params[high(cur.params)].key:=key;
      cur.params[high(cur.params)].value:=value;
    end;
  end;
  SetLength(result,reqCount);
end;

// Format a single response block
function FormatResponse(const id:String8; const status:String8; const body:String8=''; const msg:String8=''):String8;
begin
  result:='ID: '+id+#13#10+'STATUS: '+status+#13#10;
  if msg<>'' then
    result:=result+'MSG: '+msg+#13#10;
  if body<>'' then
    result:=result+body;
  result:=result+'==='+#13#10;
end;

const
  CRLF = #13#10;
  statusNames:array[TSceneStatus] of String8 = ('frozen','background','active');

function CmdWindows(const req:TRequest):String8;
var
  body:String8;
begin
  if game=nil then exit(FormatResponse(req.id,'ERROR','','game not initialized'));
  // TODO: lock if window properties become mutable from other threads
  body:='WINDOW: 0'+CRLF+
    '  windowWidth: '+Conv.ToStr(game.windowWidth)+CRLF+
    '  windowHeight: '+Conv.ToStr(game.windowHeight)+CRLF+
    '  renderWidth: '+Conv.ToStr(game.renderWidth)+CRLF+
    '  renderHeight: '+Conv.ToStr(game.renderHeight)+CRLF+
    '  screenDPI: '+Conv.ToStr(game.screenDPI)+CRLF+
    '  displayRect: '+Conv.ToStr(game.displayRect.Left)+','+Conv.ToStr(game.displayRect.Top)+','+
      Conv.ToStr(game.displayRect.Right)+','+Conv.ToStr(game.displayRect.Bottom)+CRLF;
  result:=FormatResponse(req.id,'OK',body);
end;

function CmdFps(const req:TRequest):String8;
var
  body:String8;
begin
  if game=nil then exit(FormatResponse(req.id,'ERROR','','game not initialized'));
  // no lock needed: FPS fields are written/read on main thread only
  body:='fps: '+Conv.ToStr(game.FPS,2)+CRLF+
    'smoothFPS: '+Conv.ToStr(game.smoothFPS,2)+CRLF+
    'frameNum: '+Conv.ToStr(game.frameNum)+CRLF+
    'frameTime: '+Conv.ToStr(integer(game.frameTimeDelta))+CRLF;
  result:=FormatResponse(req.id,'OK',body);
end;

function CmdScenes(const req:TRequest):String8;
var
  body:String8;
  scenes:TArray<TGameScene>;
  i:integer;
  s:TGameScene;
begin
  scenes:=GetAllScenes; // locked internally via game.EnterCritSect
  if scenes=nil then exit(FormatResponse(req.id,'ERROR','','no scenes available'));
  body:='';
  for i:=0 to high(scenes) do begin
    s:=scenes[i];
    body:=body+'SCENE: '+s.name+CRLF+
      '  status: '+statusNames[s.status]+CRLF+
      '  zOrder: '+Conv.ToStr(s.zOrder)+CRLF+
      '  frequency: '+Conv.ToStr(s.frequency)+CRLF+
      '  fullscreen: '+Conv.ToStr(s.fullscreen)+CRLF+
      '  class: '+String8(s.ClassName)+CRLF;
  end;
  result:=FormatResponse(req.id,'OK',body);
end;

// NOTE: UI commands (Stage 3+) must use UICritSect for rootElements/children access
function HandleRequest(const req:TRequest):String8;
begin
  if req.cmd='windows' then
    result:=CmdWindows(req)
  else if req.cmd='fps' then
    result:=CmdFps(req)
  else if req.cmd='scenes' then
    result:=CmdScenes(req)
  else
    result:=FormatResponse(req.id,'ERROR','','unknown command: '+req.cmd);
end;

procedure ProcessInputFile;
var
  content:String8;
  requests:TArray<TRequest>;
  response:String8;
  i:integer;
begin
  if not Files.Exists(INPUT_FILE) then exit;
  content:=Files.LoadAsString(INPUT_FILE);
  // check for end marker
  if content.IndexOf('===')<1 then exit;

  Log.Msg('RobotAPI: processing input file');
  lastActivityTime:=CoreTime.Ticks;
  fastMode:=true;

  requests:=ParseRequests(content);
  response:='';
  for i:=0 to high(requests) do
    response:=response+HandleRequest(requests[i]);

  Files.Save(OUTPUT_FILE,response);
  Files.Delete(INPUT_FILE);
  Log.Msg('RobotAPI: processed '+Conv.ToStr(length(requests))+' request(s)');
end;

procedure InitRobotAPI;
begin
  if not robotAPIEnabled then exit;
  fastMode:=false;
  lastCheckTime:=0;
  lastActivityTime:=0;
  initialized:=true;
  Log.Msg('RobotAPI: initialized');
end;

procedure PollRobotAPI;
var
  now:int64;
begin
  if not initialized then exit;
  now:=CoreTime.Ticks;
  // throttle file checks
  if now-lastCheckTime<GetCheckInterval then exit;
  lastCheckTime:=now;
  // return to slow mode after inactivity
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
