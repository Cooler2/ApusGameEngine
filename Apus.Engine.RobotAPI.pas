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
uses Apus.Types, Apus.Conv, Apus.Strings, Apus.Log, Apus.Files,
  Apus.Engine.API, Apus.Engine.Game, Apus.Engine.Scene,
  Apus.Engine.UITypes, Apus.Engine.UI, Apus.Engine.UIScene;

type
  TRequest=record
    id:String8;
    cmd:String8;
    params:TNameValueList;
  end;
  TRequestArray = array of TRequest;

const
  INPUT_FILE  = 'robot_in.txt';
  OUTPUT_FILE = 'robot_out.txt';
  SLOW_INTERVAL = 500; // ms between checks in slow mode
  FAST_INTERVAL = 100; // ms between checks in fast mode
  FAST_TIMEOUT  = 5000; // ms of inactivity before returning to slow mode
  CRLF = #13#10;
  statusNames:array[TSceneStatus] of String8 = ('frozen','background','active');

var
  lastCheckTime:int64;
  lastActivityTime:int64;
  fastMode:boolean;
  initialized:boolean;

type
  TGameHelper = class(TGame)
    function FormatScenes(activeOnly:boolean):String8;
    function FindUISceneRoot(const sceneName:String8):TUIElement;
  end;

function TGameHelper.FormatScenes(activeOnly:boolean):String8;
var
  i:integer;
  s:TGameScene;
begin
  result:='';
  EnterCritSect;
  try
    for i:=0 to high(scenes) do begin
      s:=scenes[i];
      if activeOnly and (s.status<>ssActive) then continue;
      result:=result+'SCENE: '+s.name+CRLF+
        '  status: '+statusNames[s.status]+CRLF+
        '  zOrder: '+Conv.ToStr(s.zOrder)+CRLF+
        '  frequency: '+Conv.ToStr(s.frequency)+CRLF+
        '  fullscreen: '+Conv.ToStr(s.fullscreen)+CRLF+
        '  class: '+String8(s.ClassName)+CRLF;
    end;
  finally
    LeaveCritSect;
  end;
end;

function TGameHelper.FindUISceneRoot(const sceneName:String8):TUIElement;
var
  s:TObject;
begin
  result:=nil;
  s:=TGameScene.FindByName(sceneName);
  if (s<>nil) and (s is TUIScene) then
    result:=TUIScene(s).UI;
end;

function GetCheckInterval:integer;
begin
  if fastMode then result:=FAST_INTERVAL
  else result:=SLOW_INTERVAL;
end;

function GetParam(const req:TRequest; const key:String8):String8;
begin
  result:=req.params.Item[key];
end;

// Parse input file into array of requests
function ParseRequests(const content:String8):TRequestArray;
var
  lines:Strings8;
  i,reqCount:integer;
  line:String8;
  nv:TNameValue;
  cur:TRequest;
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
  activeOnly:boolean;
begin
  activeOnly:=GetParam(req,'ACTIVE_ONLY')<>'';
  body:=TGameHelper(game).FormatScenes(activeOnly);
  if body='' then exit(FormatResponse(req.id,'ERROR','','no scenes available'));
  result:=FormatResponse(req.id,'OK',body);
end;

function ElementFlags(e:TUIElement):String8;
begin
  if e.visible then result:='visible' else result:='hidden';
  if e.enabled then result:=result+' enabled' else result:=result+' disabled';
end;

function ElementSummary(e:TUIElement; indent:integer):String8;
var
  pad:String8;
  r:TRect;
begin
  pad:='';
  while length(pad)<indent do pad:=pad+'  ';
  r:=e.GetPosOnScreen;
  result:=pad+'UI: '+e.name+' ['+String8(e.ClassName)+'] '+
    Conv.ToStr(r.Left)+','+Conv.ToStr(r.Top)+' '+
    Conv.ToStr(r.Width)+'x'+Conv.ToStr(r.Height)+' '+
    ElementFlags(e);
  if e.caption<>'' then
    result:=result+' caption="'+e.caption+'"';
  result:=result+CRLF;
end;

procedure DumpTree(e:TUIElement; depth,maxDepth:integer; var body:String8);
var
  i:integer;
begin
  body:=body+ElementSummary(e,depth);
  if (maxDepth>0) and (depth>=maxDepth) then exit;
  for i:=0 to high(e.children) do
    DumpTree(e.children[i],depth+1,maxDepth,body);
end;

function CmdUITree(const req:TRequest):String8;
var
  body:String8;
  sceneName:String8;
  maxDepth,i:integer;
  root:TUIElement;
begin
  sceneName:=GetParam(req,'SCENE');
  maxDepth:=Conv.ToInt(GetParam(req,'DEPTH'));
  body:='';
  UICritSect.Enter;
  try
    if sceneName<>'' then begin
      root:=TGameHelper(game).FindUISceneRoot(sceneName);
      if root=nil then
        exit(FormatResponse(req.id,'ERROR','','scene not found: '+sceneName));
      DumpTree(root,0,maxDepth,body);
    end else begin
      for i:=0 to high(rootElements) do
        DumpTree(rootElements[i],0,maxDepth,body);
    end;
  finally
    UICritSect.Leave;
  end;
  result:=FormatResponse(req.id,'OK',body);
end;

function CmdUIElement(const req:TRequest):String8;
var
  body:String8;
  eName:String8;
  e:TUIElement;
  r:TRect;
begin
  eName:=GetParam(req,'NAME');
  if eName='' then exit(FormatResponse(req.id,'ERROR','','NAME parameter required'));
  UICritSect.Enter;
  try
    e:=FindElement(eName,false);
    if e=nil then exit(FormatResponse(req.id,'ERROR','','element not found: '+eName));
    r:=e.GetPosOnScreen;
    body:='name: '+e.name+CRLF+
      'class: '+String8(e.ClassName)+CRLF+
      'position: '+Conv.ToStr(e.position.x,1)+','+Conv.ToStr(e.position.y,1)+CRLF+
      'size: '+Conv.ToStr(e.size.x,1)+','+Conv.ToStr(e.size.y,1)+CRLF+
      'pivot: '+Conv.ToStr(e.pivot.x,1)+','+Conv.ToStr(e.pivot.y,1)+CRLF+
      'scale: '+Conv.ToStr(e.scale,2)+CRLF+
      'globalRect: '+Conv.ToStr(r.Left)+','+Conv.ToStr(r.Top)+','+Conv.ToStr(r.Right)+','+Conv.ToStr(r.Bottom)+CRLF+
      'visible: '+Conv.ToStr(e.visible)+CRLF+
      'enabled: '+Conv.ToStr(e.enabled)+CRLF+
      'parentClip: '+Conv.ToStr(e.parentClip)+CRLF+
      'clipChildren: '+Conv.ToStr(e.clipChildren)+CRLF+
      'order: '+Conv.ToStr(e.order)+CRLF+
      'caption: '+e.caption+CRLF+
      'hint: '+e.hint+CRLF+
      'styleInfo: '+e.styleInfo+CRLF+
      'color: '+Conv.ToHex(e.color)+CRLF+
      'font: '+Conv.ToStr(integer(e.font))+CRLF;
    if e.parent<>nil then
      body:=body+'parent: '+e.parent.name+CRLF
    else
      body:=body+'parent: (none)'+CRLF;
    body:=body+'childCount: '+Conv.ToStr(length(e.children))+CRLF+
      'focused: '+Conv.ToStr(FocusedElement=e)+CRLF+
      'underMouse: '+Conv.ToStr(underMouse=e)+CRLF;
  finally
    UICritSect.Leave;
  end;
  result:=FormatResponse(req.id,'OK',body);
end;

function CmdUIHitTest(const req:TRequest):String8;
var
  body:String8;
  x,y:integer;
  c,p:TUIElement;
  chain:String8;
  enabled:boolean;
begin
  x:=Conv.ToInt(GetParam(req,'X'));
  y:=Conv.ToInt(GetParam(req,'Y'));
  // FindAnyElementAt locks UICritSect internally
  enabled:=FindAnyElementAt(x,y,c);
  if c=nil then begin
    body:='hit: (none)'+CRLF;
  end else begin
    // build chain from root to hit element
    chain:=c.name;
    p:=c.parent;
    while p<>nil do begin
      chain:=p.name+' > '+chain;
      p:=p.parent;
    end;
    body:='hit: '+c.name+CRLF+
      'hitClass: '+String8(c.ClassName)+CRLF+
      'chain: '+chain+CRLF+
      'enabled: '+Conv.ToStr(enabled)+CRLF;
  end;
  if modalElement<>nil then
    body:=body+'modal: '+modalElement.name+CRLF
  else
    body:=body+'modal: (none)'+CRLF;
  result:=FormatResponse(req.id,'OK',body);
end;

function HandleRequest(const req:TRequest):String8;
begin
  if req.cmd='windows' then
    result:=CmdWindows(req)
  else if req.cmd='fps' then
    result:=CmdFps(req)
  else if req.cmd='scenes' then
    result:=CmdScenes(req)
  else if req.cmd='ui.tree' then
    result:=CmdUITree(req)
  else if req.cmd='ui.element' then
    result:=CmdUIElement(req)
  else if req.cmd='ui.hittest' then
    result:=CmdUIHitTest(req)
  else
    result:=FormatResponse(req.id,'ERROR','','unknown command: '+req.cmd);
end;

procedure ProcessInputFile;
var
  content,response:String8;
  requests:TRequestArray;
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
  Log.Msg('RobotAPI: processed %d request(s)',[length(requests)]);
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
