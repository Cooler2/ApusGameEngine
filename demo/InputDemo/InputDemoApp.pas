// Input diagnostics demo for Apus Engine
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit InputDemoApp;
interface
uses Apus.Engine.GameApp,Apus.Engine.API;

type
  TMainApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure SetupGameSettings(var settings:TGameSettings); override;
    procedure CreateScenes; override;
  end;

var
  application:TMainApp;

implementation
uses
  SysUtils,
  Types,
  Apus.Core,
  Apus.Conv,
  Apus.Strings,
  Apus.EventMan,
  Apus.Engine.Keys,
  Apus.Engine.Types,
  Apus.Engine.Scene;

type
  TInputLogEntry=record
    t:double;
    kind:string;
    info:string;
  end;

  TMouseSample=record
    t:double;
    x,y:integer;
    buttons:byte;
  end;

  TMainScene=class(TGameScene)
    titleFont,menuFont,hintFont,bodyFont:TFontHandle;
    currentScreen:integer;
    textTopOpt,textBlockOpt:cardinal;

    uiScale:single; // game.screenScale the metrics are built for
    menuWidth,menuTop,menuItemHeight,contentPadding,screenTopOffset:integer;

    logHead,logCount:integer;
    logs:array[0..255] of TInputLogEntry;

    rawHead,rawCount:integer;
    rawSamples:array[0..11999] of TMouseSample;

    frameHead,frameCount:integer;
    frameSamples:array[0..2047] of TMouseSample;

    moveEventsTotal:integer;
    btnDownEvents,btnUpEvents:integer;
    wheelEventsTotal:integer;
    wheelDeltaTotal:integer;
    lastWheelDelta:integer;
    keyDownEvents,keyUpEvents:integer;
    charEvents:integer;

    secWindowStart:double;
    secMoveEvents,secKeyEvents,secCharEvents,secWheelEvents:integer;
    rateMove,rateKey,rateChar,rateWheel:single;

    lastFrameRawHead:integer;
    rawPerFrame:integer;
    maxRawPerFrame:integer;

    pollingKeyPressCnt:array[0..7] of integer;
    eventKeyDownCnt:array[0..7] of integer;
    traceMode:integer;

    procedure Load; override;
    function Process:boolean; override;
    procedure ProcessInputBuffers;
    procedure Render; override;
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    function onKeyUp(key:TKey;scancode:integer;shift:byte):boolean; override;

    function S(v:integer):integer;
    procedure UpdateMetrics;
    procedure RebuildFonts;
    procedure HandleInput;
    procedure UpdateStats;

    procedure PushLog(const kind,info:string);
    procedure PushRawSample(x,y:integer;buttons:byte;t:double);
    procedure PushFrameSample(x,y:integer;buttons:byte;t:double);

    procedure DrawMenu(const menuRect:TRect);
    procedure DrawScreenTitle(const contentRect:TRect; const title,subtitle:string);
    procedure DrawTag(x,y:integer;const st:string;color:cardinal=$FFE6EEF8);

    procedure DrawOverview(const contentRect:TRect);
    procedure DrawKeyboardDeep(const contentRect:TRect);
    procedure DrawMouseDeep(const contentRect:TRect);
    procedure DrawHighRateTrace(const contentRect:TRect);
    procedure DrawPollingVsEvents(const contentRect:TRect);
    procedure DrawStress(const contentRect:TRect);
    function GetArea:TRect; override;
  end;

const
  SCREEN_COUNT=6;
  MENU_WIDTH=360;
  MENU_TOP=76;
  MENU_ITEM_HEIGHT=58;
  CONTENT_PADDING=18;

  TRACKED_SCANS:array[0..7] of integer=(17,30,31,32,57,42,29,15); // W,A,S,D,Space,LShift,LCtrl,Tab
  TRACKED_NAMES:array[0..7] of string=('W','A','S','D','Space','LShift','LCtrl','Tab');

  SCREEN_TITLES:array[0..SCREEN_COUNT-1] of string=(
    'Overview',
    'Keyboard Deep',
    'Mouse Deep',
    'High-Rate Trace',
    'Polling vs Events',
    'Stress'
  );

  SCREEN_HINTS:array[0..SCREEN_COUNT-1] of string=(
    'Main state summary (keyboard + mouse + rates)',
    'Buffered key stream from scene.ReadKey()',
    'Mouse buttons/wheel/hover zones',
    'Raw mouse samples vs frame-latched path',
    'Compare polling edges with event counts',
    'Rapid input diagnostics counters'
  );

var
  sceneMain:TMainScene;

function LMBClicked:boolean;
begin
  result:=Mouse.WasPressed;
end;

procedure InputEventHandler(event:TEventStr;tag:TTag);
var
  x,y:integer;
  sub:TEventStr;
  t:double;
begin
  if sceneMain=nil then exit;
  t:=CoreTime.Ticks*0.001;

  if EventOfClass(event,'MOUSE',sub) then begin
    if sub='MOVE' then begin
      x:=SmallInt(Bits.GetWord(cardinal(tag),0));
      y:=SmallInt(Bits.GetWord(cardinal(tag),1));
      sceneMain.PushRawSample(x,y,window.mouseButtons,t);
      inc(sceneMain.moveEventsTotal);
      inc(sceneMain.secMoveEvents);
      exit;
    end;
    if sub.IndexOf('BTNDOWN')=1 then begin
      inc(sceneMain.btnDownEvents);
      sceneMain.PushLog('MB_DOWN','btn='+Conv.ToStr(tag));
      exit;
    end;
    if sub.IndexOf('BTNUP')=1 then begin
      inc(sceneMain.btnUpEvents);
      sceneMain.PushLog('MB_UP','btn='+Conv.ToStr(tag));
      exit;
    end;
    if sub='SCROLL' then begin
      sceneMain.lastWheelDelta:=integer(tag);
      sceneMain.wheelDeltaTotal:=sceneMain.wheelDeltaTotal+integer(tag);
      inc(sceneMain.wheelEventsTotal);
      inc(sceneMain.secWheelEvents);
      sceneMain.PushLog('WHEEL',Format('delta=%d',[integer(tag)]));
      exit;
    end;
  end;

end;

// Key events now arrive through the synchronous callback pipeline (R-23) instead of
// the removed SCENE\Main\KeyDown/KeyUp signal — see onKeyDown/onKeyUp below.
function TMainScene.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
var
  i,keyCode:integer;
begin
  keyCode:=ord(key);
  inc(keyDownEvents);
  inc(secKeyEvents);
  PushLog('KD',Format('key=%d scan=%d',[keyCode,scancode]));
  if (window.shiftState=0) and (keyCode>=ord(TKey.F1)) and (keyCode<=ord(TKey.F6)) then
    currentScreen:=keyCode-ord(TKey.F1);
  for i:=0 to high(TRACKED_SCANS) do
    if scancode=TRACKED_SCANS[i] then inc(eventKeyDownCnt[i]);
  result:=false; // diagnostic scene: observe but don't consume
end;

function TMainScene.onKeyUp(key:TKey;scancode:integer;shift:byte):boolean;
begin
  inc(keyUpEvents);
  PushLog('KU',Format('key=%d scan=%d',[ord(key),scancode]));
  result:=false;
end;

procedure TMainApp.SetupApplication;
begin
  inherited;
  appSetup.title:='Apus Engine: InputDemo';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(1520,860);
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode:=dmFixedWindow;
end;

procedure TMainApp.CreateScenes;
begin
  inherited;
  sceneMain:=TMainScene.Create('Main',true,window);
  game.SwitchToScene('Main');
end;

procedure TMainScene.Load;
begin
  secWindowStart:=0;
  currentScreen:=0;
  traceMode:=3;
  textTopOpt:=toAddBaseline;
  textBlockOpt:=toDontTranslate or toWithShadow;
  UpdateMetrics;
  RebuildFonts;
  SetEventHandler('MOUSE\',InputEventHandler,emInstant);
  loaded:=true;
end;

// Layout sizes are given for 96 DPI: scaled by the UI scale, as the text is
function TMainScene.S(v:integer):integer;
begin
  result:=round(v*uiScale);
end;

procedure TMainScene.UpdateMetrics;
begin
  uiScale:=game.screenScale;
  menuWidth:=S(MENU_WIDTH);
  if menuWidth>window.canvasWidth div 2 then menuWidth:=window.canvasWidth div 2;
  menuTop:=S(MENU_TOP);
  menuItemHeight:=S(MENU_ITEM_HEIGHT);
  contentPadding:=S(CONTENT_PADDING);
  screenTopOffset:=S(84);
end;

// GetFont applies the UI scale itself (TGameApplication.SetupHighDPI)
procedure TMainScene.RebuildFonts;
begin
  titleFont:=txt.GetFont('Default',12);
  menuFont:=txt.GetFont('Default',10);
  hintFont:=txt.GetFont('Default',8);
  bodyFont:=txt.GetFont('Default',8);
end;

procedure TMainScene.PushLog(const kind,info:string);
var
  idx:integer;
begin
  idx:=logHead;
  logs[idx].t:=CoreTime.Ticks*0.001;
  logs[idx].kind:=kind;
  logs[idx].info:=info;
  logHead:=(logHead+1) mod Length(logs);
  if logCount<Length(logs) then inc(logCount);
end;

procedure TMainScene.PushRawSample(x,y:integer;buttons:byte;t:double);
var
  idx:integer;
begin
  idx:=rawHead;
  rawSamples[idx].t:=t;
  rawSamples[idx].x:=x;
  rawSamples[idx].y:=y;
  rawSamples[idx].buttons:=buttons;
  rawHead:=(rawHead+1) mod Length(rawSamples);
  if rawCount<Length(rawSamples) then inc(rawCount);
end;

procedure TMainScene.PushFrameSample(x,y:integer;buttons:byte;t:double);
var
  idx:integer;
begin
  idx:=frameHead;
  frameSamples[idx].t:=t;
  frameSamples[idx].x:=x;
  frameSamples[idx].y:=y;
  frameSamples[idx].buttons:=buttons;
  frameHead:=(frameHead+1) mod Length(frameSamples);
  if frameCount<Length(frameSamples) then inc(frameCount);
end;

function TMainScene.Process:boolean;
begin
  result:=inherited;
  if not loaded then exit; // the menu metrics come from Load
  // input reactions belong here: Render may be skipped, Process runs every frame
  HandleInput;
  ProcessInputBuffers;
end;

procedure TMainScene.HandleInput;
var
  item:integer;
begin
  if IsKeyPressed(2) or IsKeyPressed(30) then traceMode:=1;
  if IsKeyPressed(3) or IsKeyPressed(31) then traceMode:=2;
  if IsKeyPressed(4) or IsKeyPressed(32) then traceMode:=3;

  if LMBClicked and (window.mousePos.x>=0) and (window.mousePos.x<menuWidth) and
     (window.mousePos.y>=menuTop) then begin
    item:=(window.mousePos.y-menuTop) div menuItemHeight;
    if (item>=0) and (item<SCREEN_COUNT) then
      currentScreen:=item;
  end;
end;

procedure TMainScene.UpdateStats;
var
  nowT:double;
begin
  rawPerFrame:=rawHead-lastFrameRawHead;
  if rawPerFrame<0 then rawPerFrame:=rawPerFrame+Length(rawSamples);
  lastFrameRawHead:=rawHead;
  if rawPerFrame>maxRawPerFrame then maxRawPerFrame:=rawPerFrame;

  nowT:=CoreTime.Ticks*0.001;
  if nowT-secWindowStart>=1.0 then begin
    rateMove:=secMoveEvents/(nowT-secWindowStart);
    rateKey:=secKeyEvents/(nowT-secWindowStart);
    rateChar:=secCharEvents/(nowT-secWindowStart);
    rateWheel:=secWheelEvents/(nowT-secWindowStart);
    secWindowStart:=nowT;
    secMoveEvents:=0;
    secKeyEvents:=0;
    secCharEvents:=0;
    secWheelEvents:=0;
  end;
end;

procedure TMainScene.ProcessInputBuffers;
var
  key:cardinal;
  scan,ansi,uCode:integer;
  i:integer;
begin
  repeat
    key:=ReadKey;
    if key=0 then break;
    ansi:=Bits.GetByte(key,0);
    scan:=Bits.GetByte(key,1);
    uCode:=Bits.GetWord(key,1);
    inc(charEvents);
    inc(secCharEvents);
    PushLog('CHAR',Format('ansi=%d scan=%d uni=%d',[ansi,scan,uCode]));
  until false;

  for i:=0 to high(TRACKED_SCANS) do
    if IsKeyPressed(TRACKED_SCANS[i]) then
      inc(pollingKeyPressCnt[i]);
end;

function TMainScene.GetArea:TRect;
begin
  result:=Rect(0,0,window.canvasWidth,window.canvasHeight);
end;

procedure TMainScene.DrawMenu(const menuRect:TRect);
var
  i,top,bottom:integer;
  r:TRect;
  isActive,isHovered:boolean;
  bg,border,txtCol:cardinal;
begin
  draw.FillRect(menuRect.Left,menuRect.Top,menuRect.Right,menuRect.Bottom,$FF1A2230);
  draw.Rect(menuRect.Left,menuRect.Top,menuRect.Right,menuRect.Bottom,$FF3B4B60);

  txt.Write(titleFont,S(20),S(25),$FFE8F0FA,'InputDemo Screens',taLeft,toAddBaseline);
  txt.Write(hintFont,S(20),S(52),$FFA4B7CE,'Mouse click or keys [F1..F6]',taLeft,toAddBaseline);

  for i:=0 to SCREEN_COUNT-1 do begin
    top:=menuTop+i*menuItemHeight;
    bottom:=top+menuItemHeight-S(6);
    r:=Rect(menuRect.Left+S(12),top,menuRect.Right-S(12),bottom);
    isActive:=i=currentScreen;
    isHovered:=PtInRect(r,Point(window.mousePos.x,window.mousePos.y));

    if isActive then begin
      bg:=$FF34506D;
      border:=$FF8CB8E8;
      txtCol:=$FFFFFFFF;
    end else
    if isHovered then begin
      bg:=$FF27384D;
      border:=$FF5F7FA5;
      txtCol:=$FFE8EEF8;
    end else begin
      bg:=$FF202C3B;
      border:=$FF3F5168;
      txtCol:=$FFC9D7E8;
    end;

    draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,bg,S(8));
    draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,S(8),border);
    txt.Write(menuFont,r.Left+S(12),r.Top+S(18),txtCol,Conv.ToStr(i+1)+'. '+SCREEN_TITLES[i],taLeft,integer(textTopOpt));
  end;
end;

procedure TMainScene.DrawScreenTitle(const contentRect:TRect; const title,subtitle:string);
begin
  draw.FillRect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-S(10),$FF1F2A3A);
  draw.Rect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-S(10),$FF3D5067);
  txt.Write(titleFont,contentRect.Left+S(14),contentRect.Top+S(16),$FFEAF2FC,title,taLeft,toAddBaseline);
  txt.Write(hintFont,contentRect.Left+S(14),contentRect.Top+S(44),$FFA8BDD5,subtitle,taLeft,toAddBaseline);
end;

procedure TMainScene.DrawTag(x,y:integer;const st:string;color:cardinal=$FFE6EEF8);
var
  h:integer;
begin
  h:=txt.Height(bodyFont);
  draw.FillRect(x-S(4),y-S(3),x+txt.Width(bodyFont,st)+S(4),y+h+S(3),$50202A38);
  txt.Write(bodyFont,x,y,color,st,taLeft,toAddBaseline);
end;

procedure TMainScene.DrawOverview(const contentRect:TRect);
var
  a,b,c:TRect;
  st:string;
  i,y,maxLines:integer;
  pClient,pScreen:TPoint;
begin
  a:=Rect(contentRect.Left+S(10),contentRect.Top+screenTopOffset,contentRect.Left+S(620),contentRect.Bottom-S(20));
  b:=Rect(contentRect.Left+S(640),contentRect.Top+screenTopOffset,contentRect.Right-S(10),contentRect.Top+S(350));
  c:=Rect(contentRect.Left+S(640),contentRect.Top+S(370),contentRect.Right-S(10),contentRect.Bottom-S(20));
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,S(10));
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,S(10));
  draw.FillRRect(c.Left,c.Top,c.Right,c.Bottom,$FF202D3D,S(10));

  DrawTag(a.Left+S(20),a.Top+S(24),'Keyboard State');
  y:=a.Top+S(52);
  for i:=0 to high(TRACKED_SCANS) do begin
    st:=Format('%-6s down=%d pressed=%d released=%d  pollCnt=%d evtCnt=%d',
      [TRACKED_NAMES[i],byte(IsKeyDown(TRACKED_SCANS[i])),byte(IsKeyPressed(TRACKED_SCANS[i])),
       byte(IsKeyReleased(TRACKED_SCANS[i])),pollingKeyPressCnt[i],eventKeyDownCnt[i]]);
    txt.Write(bodyFont,a.Left+S(20),y,$FFE5EDF7,st,taLeft,toAddBaseline);
    inc(y,S(20));
  end;

  st:=Format('ShiftState=%d  LMB=%d RMB=%d MMB=%d',[window.shiftState,
    byte(Bits.HasAll(window.mouseButtons,mbLeft)),byte(Bits.HasAll(window.mouseButtons,mbRight)),
    byte(Bits.HasAll(window.mouseButtons,mbMiddle))]);
  txt.Write(bodyFont,a.Left+S(20),y+S(8),$FFF3D39C,st,taLeft,toAddBaseline);
  st:=Format('Mods: LS=%d RS=%d LC=%d RC=%d LA=%d RA=%d LW=%d RW=%d',
    [byte(Bits.HasAll(window.shiftState,sscShift) and not Bits.HasAll(window.shiftState,sscRShift)),
     byte(Bits.HasAll(window.shiftState,sscRShift)),
     byte(Bits.HasAll(window.shiftState,sscCtrl) and not Bits.HasAll(window.shiftState,sscRCtrl)),
     byte(Bits.HasAll(window.shiftState,sscRCtrl)),
     byte(Bits.HasAll(window.shiftState,sscAlt) and not Bits.HasAll(window.shiftState,sscRAlt)),
     byte(Bits.HasAll(window.shiftState,sscRAlt)),
     byte(Bits.HasAll(window.shiftState,sscWin) and not Bits.HasAll(window.shiftState,sscRWin)),
     byte(Bits.HasAll(window.shiftState,sscRWin))]);
  txt.Write(bodyFont,a.Left+S(20),y+S(28),$FFF3D39C,st,taLeft,toAddBaseline);

  DrawTag(b.Left+S(20),b.Top+S(24),'Input Summary');
  pClient:=Point(window.mousePos.x,window.mousePos.y);
  pClient:=window.CanvasToClient(pClient);
  pScreen:=pClient;
  window.ClientToScreen(pScreen);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(52),$FFE5EDF7,
    Format('Mouse game: (%d,%d) old=(%d,%d)',[window.mousePos.x,window.mousePos.y,window.oldMousePos.x,window.oldMousePos.y]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(72),$FFE5EDF7,
    Format('Mouse window(client): (%d,%d)',[pClient.X,pClient.Y]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(92),$FFE5EDF7,
    Format('Mouse screen: (%d,%d)',[pScreen.X,pScreen.Y]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(122),$FFE5EDF7,
    Format('Window: %dx%d render=%dx%d',[window.clientWidth,window.clientHeight,window.canvasWidth,window.canvasHeight]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(152),$FFE5EDF7,
    Format('Events total: move=%d wheel=%d keyDown=%d keyUp=%d char=%d',
      [moveEventsTotal,wheelEventsTotal,keyDownEvents,keyUpEvents,charEvents]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(172),$FFE5EDF7,
    Format('Rates (/sec): move=%.1f wheel=%.1f key=%.1f char=%.1f',
      [rateMove,rateWheel,rateKey,rateChar]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(192),$FFE5EDF7,
    Format('Samples/frame: now=%d max=%d',[rawPerFrame,maxRawPerFrame]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(222),$FFF3D39C,
    Format('FPS: %.1f  SmoothFPS: %.1f',[window.timings.fps,window.timings.smoothFps]),taLeft,toAddBaseline);

  draw.FillRect(c.Left+S(20),c.Top+S(44),c.Right-S(20),c.Bottom-S(20),$30233A53);
  DrawTag(c.Left+S(24),c.Top+S(20),'Last Events');
  y:=c.Top+S(54);
  maxLines:=(c.Bottom-S(26)-y) div S(20);
  if maxLines<0 then maxLines:=0;
  for i:=0 to maxLines-1 do begin
    if i>=logCount then break;
    st:=logs[(logHead-1-i+Length(logs)) mod Length(logs)].kind+'  '+
      Format('%.3f',[logs[(logHead-1-i+Length(logs)) mod Length(logs)].t])+'  '+
      logs[(logHead-1-i+Length(logs)) mod Length(logs)].info;
    txt.Write(bodyFont,c.Left+S(24),y,$FFD8E7F8,st,taLeft,toAddBaseline);
    inc(y,S(20));
  end;
end;

procedure TMainScene.DrawKeyboardDeep(const contentRect:TRect);
var
  r:TRect;
  i,y,idx,maxLines:integer;
  st:string;
begin
  r:=Rect(contentRect.Left+S(10),contentRect.Top+screenTopOffset,contentRect.Right-S(10),contentRect.Bottom-S(20));
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF202D3D,S(10));
  DrawTag(r.Left+S(20),r.Top+S(24),'Buffered Char Stream (scene.ReadKey) + onKeyDown/onKeyUp callbacks');

  txt.Write(bodyFont,r.Left+S(20),r.Top+S(52),$FFE5EDF7,
    Format('Totals: keyDown=%d keyUp=%d char=%d',[keyDownEvents,keyUpEvents,charEvents]),taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+S(20),r.Top+S(72),$FFE5EDF7,
    'Fields: [kind] [time] [payload]',taLeft,toAddBaseline);

  y:=r.Top+S(102);
  maxLines:=(r.Bottom-S(24)-y) div S(20);
  if maxLines<0 then maxLines:=0;
  for i:=0 to maxLines-1 do begin
    if i>=logCount then break;
    idx:=(logHead-1-i+Length(logs)) mod Length(logs);
    st:=Format('%-6s %8.3f  %s',[logs[idx].kind,logs[idx].t,logs[idx].info]);
    txt.Write(bodyFont,r.Left+S(20),y,$FFD8E7F8,st,taLeft,toAddBaseline);
    inc(y,S(20));
  end;
end;

procedure TMainScene.DrawMouseDeep(const contentRect:TRect);
var
  a,b:TRect;
  zone1,zone2:TRect;
  c1,c2:cardinal;
  st:string;
  pClient,pScreen:TPoint;
begin
  a:=Rect(contentRect.Left+S(10),contentRect.Top+screenTopOffset,contentRect.Left+S(720),contentRect.Bottom-S(20));
  b:=Rect(contentRect.Left+S(740),contentRect.Top+screenTopOffset,contentRect.Right-S(10),contentRect.Bottom-S(20));
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,S(10));
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,S(10));

  DrawTag(a.Left+S(20),a.Top+S(24),'Mouse Zones / Buttons');
  txt.Write(bodyFont,a.Left+S(20),a.Top+S(48),$FFE5EDF7,'Move cursor through zones, click buttons 1..5, use wheel.',taLeft,toAddBaseline);
  zone1:=Rect(a.Left+S(50),a.Top+S(120),a.Left+S(330),a.Top+S(330));
  zone2:=Rect(a.Left+S(380),a.Top+S(120),a.Right-S(50),a.Top+S(330));
  c1:=$404890C0;
  c2:=$4060A060;
  if PtInRect(zone1,Point(window.mousePos.x,window.mousePos.y)) then c1:=$70A0D8FF;
  if PtInRect(zone2,Point(window.mousePos.x,window.mousePos.y)) then c2:=$70A8F0A8;
  draw.FillRRect(zone1.Left,zone1.Top,zone1.Right,zone1.Bottom,c1,S(12));
  draw.FillRRect(zone2.Left,zone2.Top,zone2.Right,zone2.Bottom,c2,S(12));
  draw.RRect(zone1.Left,zone1.Top,zone1.Right,zone1.Bottom,S(2),S(12),$FFE8F4FF);
  draw.RRect(zone2.Left,zone2.Top,zone2.Right,zone2.Bottom,S(2),S(12),$FFE8F4FF);
  DrawTag(zone1.Left+S(16),zone1.Top+S(18),'Hover Zone A (enter/leave test)');
  DrawTag(zone2.Left+S(16),zone2.Top+S(18),'Hover Zone B (independent area)');

  st:=Format('Btn events: down=%d up=%d',[btnDownEvents,btnUpEvents]);
  txt.Write(bodyFont,a.Left+S(20),a.Top+S(360),$FFE5EDF7,st,taLeft,toAddBaseline);
  txt.Write(bodyFont,a.Left+S(20),a.Top+S(380),$FFE5EDF7,
    Format('Wheel: lastDelta=%d events=%d totalDelta=%d rate=%.1f/s',
      [lastWheelDelta,wheelEventsTotal,wheelDeltaTotal,rateWheel]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,a.Left+S(20),a.Top+S(400),$FFE5EDF7,
    Format('Mouse buttons mask: %d',[window.mouseButtons]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,a.Left+S(20),a.Top+S(420),$FFE5EDF7,
    Format('L=%d R=%d M=%d X1=%d X2=%d',
      [byte(Bits.HasAll(window.mouseButtons,1)),byte(Bits.HasAll(window.mouseButtons,2)),
       byte(Bits.HasAll(window.mouseButtons,4)),byte(Bits.HasAll(window.mouseButtons,8)),
       byte(Bits.HasAll(window.mouseButtons,16))]),taLeft,integer(textTopOpt));
  pClient:=Point(window.mousePos.x,window.mousePos.y);
  pClient:=window.CanvasToClient(pClient);
  pScreen:=pClient;
  window.ClientToScreen(pScreen);
  txt.Write(bodyFont,a.Left+S(20),a.Top+S(448),$FFF3D39C,
    Format('Pos game=(%d,%d) client=(%d,%d) screen=(%d,%d)',
      [window.mousePos.x,window.mousePos.y,pClient.X,pClient.Y,pScreen.X,pScreen.Y]),taLeft,integer(textTopOpt));

  DrawTag(b.Left+S(20),b.Top+S(24),'Recent Raw Mouse Samples');
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(52),$FFE5EDF7,
    Format('Raw samples: %d  move events total: %d',[rawCount,moveEventsTotal]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(72),$FFE5EDF7,
    'Fields: [time] [x,y] [buttons]',taLeft,integer(textTopOpt));

  st:='';
  if rawCount>0 then begin
    st:=Format('Last sample: t=%.3f x=%d y=%d b=%d',[
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].t,
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].x,
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].y,
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].buttons]);
  end;
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(92),$FFF3D39C,st,taLeft,integer(textTopOpt));

  st:=Format('rates: move=%.1f/s, samples/frame=%d (max=%d)',[rateMove,rawPerFrame,maxRawPerFrame]);
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(112),$FFD8E7F8,st,taLeft,integer(textTopOpt));
  txt.Write(bodyFont,b.Left+S(20),b.Top+S(140),$FF9BB0C8,
    'Note: X1/X2 require platform support for'#13#10' WM_XBUTTON* (Windows) or SDL buttons 4/5.',taLeft,integer(textTopOpt));
end;

procedure TMainScene.DrawHighRateTrace(const contentRect:TRect);
var
  area,plotRect:TRect;
  nowT,fromT,traceWindow:double;
  i,idx:integer;
  x1,y1,x2,y2:single;
  hasPrev:boolean;
  sx,sy:single;
  sampleCnt,frameCnt:integer;
  st:string;
  smp:TMouseSample;
  prevX,prevY:single;
  modeName:string;
begin
  area:=Rect(contentRect.Left+S(10),contentRect.Top+screenTopOffset,contentRect.Right-S(10),contentRect.Bottom-S(20));
  draw.FillRRect(area.Left,area.Top,area.Right,area.Bottom,$FF202D3D,S(10));

  plotRect:=Rect(area.Left+S(20),area.Top+S(96),area.Right-S(20),area.Bottom-S(24));
  draw.FillRect(plotRect.Left,plotRect.Top,plotRect.Right,plotRect.Bottom,$FF1B2636);
  draw.RRect(plotRect.Left,plotRect.Top,plotRect.Right,plotRect.Bottom,1,S(8),$FF516883);
  DrawTag(area.Left+S(24),area.Top+S(14),'High-Rate Mouse Trace');
  case traceMode of
    1:modeName:='raw only (1)';
    2:modeName:='frame only (2)';
  else
    modeName:='raw + frame (3)';
  end;
  txt.Write(bodyFont,area.Left+S(24),area.Top+S(46),$FFE5EDF7,'Mode '+modeName+'; press [1..3] to switch.');
  txt.Write(bodyFont,area.Left+S(24),area.Top+S(68),$FFE5EDF7,'Traces are drawn in absolute game coords; clipped by plot area.');

  nowT:=CoreTime.Ticks*0.001;
  traceWindow:=2.5;
  fromT:=nowT-traceWindow;
  prevX:=0;
  prevY:=0;

  hasPrev:=false;
  sampleCnt:=0;
  for i:=0 to rawCount-1 do begin
    idx:=(rawHead-rawCount+i+Length(rawSamples)) mod Length(rawSamples);
    smp:=rawSamples[idx];
    if smp.t<fromT then continue;
    sx:=smp.x;
    sy:=smp.y;
    if (sx<plotRect.Left) or (sx>plotRect.Right) or (sy<plotRect.Top) or (sy>plotRect.Bottom) then begin
      hasPrev:=false;
      continue;
    end;
    if hasPrev and (traceMode<>2) then
      draw.Line(prevX,prevY,sx,sy,$FF60E4FF);
    prevX:=sx;
    prevY:=sy;
    hasPrev:=true;
    inc(sampleCnt);
  end;

  hasPrev:=false;
  frameCnt:=0;
  for i:=0 to frameCount-1 do begin
    idx:=(frameHead-frameCount+i+Length(frameSamples)) mod Length(frameSamples);
    smp:=frameSamples[idx];
    if smp.t<fromT then continue;
    sx:=smp.x;
    sy:=smp.y;
    if (sx<plotRect.Left) or (sx>plotRect.Right) or (sy<plotRect.Top) or (sy>plotRect.Bottom) then begin
      hasPrev:=false;
      continue;
    end;
    if hasPrev and (traceMode<>1) then
      draw.Line(prevX,prevY,sx,sy,$FFFFD070);
    prevX:=sx;
    prevY:=sy;
    hasPrev:=true;
    inc(frameCnt);
  end;

  x1:=area.Left+S(24); y1:=area.Bottom-S(10);
  x2:=x1+S(70); y2:=y1;
  draw.Line(x1,y1,x2,y2,$FF60E4FF);
  txt.Write(bodyFont,round(x2+S(8)),round(y1+S(4)),$FFDCEEFE,'raw event samples');
  draw.Line(x1+S(230),y1,x1+S(280),y1,$FFFFD070);
  txt.Write(bodyFont,round(x1+S(288)),round(y1+S(4)),$FFEFE4C0,'frame-latched path');

  st:=Format('window=%.1fs rawSamples=%d frameSamples=%d rawRate=%.1f/s maxRawPerFrame=%d mode=%s',
    [traceWindow,sampleCnt,frameCnt,rateMove,maxRawPerFrame,modeName]);
  txt.Write(bodyFont,area.Left+S(24),area.Top+S(86),$FFE5EDF7,st);
end;

procedure TMainScene.DrawPollingVsEvents(const contentRect:TRect);
var
  r:TRect;
  i,y:integer;
  st:string;
  col:cardinal;
begin
  r:=Rect(contentRect.Left+S(10),contentRect.Top+screenTopOffset,contentRect.Right-S(10),contentRect.Bottom-S(20));
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF202D3D,S(10));
  DrawTag(r.Left+S(20),r.Top+S(24),'Polling(IsKeyPressed) vs Callback(onKeyDown)');

  y:=r.Top+S(56);
  for i:=0 to high(TRACKED_SCANS) do begin
    if Abs(pollingKeyPressCnt[i]-eventKeyDownCnt[i])<=1 then
      col:=$FFB4E5B4
    else
    if Abs(pollingKeyPressCnt[i]-eventKeyDownCnt[i])<=4 then
      col:=$FFF3D39C
    else
      col:=$FFFFB0A0;

    st:=Format('%-6s poll=%d  event=%d  delta=%d',
      [TRACKED_NAMES[i],pollingKeyPressCnt[i],eventKeyDownCnt[i],pollingKeyPressCnt[i]-eventKeyDownCnt[i]]);
    txt.Write(bodyFont,r.Left+S(20),y,col,st,taLeft,integer(textTopOpt));
    inc(y,S(20));
  end;

  txt.Write(bodyFont,r.Left+S(20),r.Bottom-S(26),$FF9BB0C8,
    'green=close, yellow=moderate mismatch, red=large mismatch',taLeft,integer(textTopOpt));
end;

procedure TMainScene.DrawStress(const contentRect:TRect);
var
  r:TRect;
  st:string;
begin
  r:=Rect(contentRect.Left+S(10),contentRect.Top+screenTopOffset,contentRect.Right-S(10),contentRect.Bottom-S(20));
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF202D3D,S(10));
  DrawTag(r.Left+S(20),r.Top+S(24),'Stress Snapshot');

  st:=Format('moveEvents=%d keyDown=%d keyUp=%d char=%d rawSamples=%d logs=%d',
    [moveEventsTotal,keyDownEvents,keyUpEvents,charEvents,rawCount,logCount]);
  txt.Write(bodyFont,r.Left+S(20),r.Top+S(56),$FFE5EDF7,st,taLeft,integer(textTopOpt));
  txt.Write(bodyFont,r.Left+S(20),r.Top+S(76),$FFE5EDF7,
    Format('wheelEvents=%d lastWheel=%d wheelTotal=%d rateWheel=%.1f/s',
      [wheelEventsTotal,lastWheelDelta,wheelDeltaTotal,rateWheel]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,r.Left+S(20),r.Top+S(96),$FFE5EDF7,
    Format('rateMove=%.1f rateKey=%.1f rateChar=%.1f raw/frame now=%d max=%d',
      [rateMove,rateKey,rateChar,rawPerFrame,maxRawPerFrame]),taLeft,integer(textTopOpt));

  draw.FillRect(r.Left+S(20),r.Top+S(132),r.Right-S(20),r.Bottom-S(24),$30233A53);
  DrawTag(r.Left+S(24),r.Top+S(148),'Usage');
  txt.Write(bodyFont,r.Left+S(24),r.Top+S(174),$FFD8E7F8,'1) Move mouse in circles: check High-Rate Trace raw continuity',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+S(24),r.Top+S(194),$FFD8E7F8,'2) Scroll wheel up/down: verify WHEEL events and deltas',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+S(24),r.Top+S(214),$FFD8E7F8,'3) Hold/release keys rapidly: compare Polling vs Events',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+S(24),r.Top+S(234),$FFD8E7F8,'4) Click/drag in Mouse Deep zones: verify button transitions',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+S(24),r.Top+S(254),$FFD8E7F8,'5) Keyboard Deep logs buffered ReadKey stream',taLeft,toAddBaseline);
end;

procedure TMainScene.Render;
var
  menuRect,contentRect:TRect;
  t:double;
begin
  if game.screenScale<>uiScale then RebuildFonts; // the DPI changed
  UpdateMetrics;

  UpdateStats;

  t:=CoreTime.Ticks*0.001;
  PushFrameSample(window.mousePos.x,window.mousePos.y,window.mouseButtons,t);

  gfx.target.Clear($FF151C27);

  menuRect:=Rect(0,0,menuWidth-1,window.canvasHeight-1);
  contentRect:=Rect(menuWidth+contentPadding,contentPadding,
    window.canvasWidth-contentPadding-1,window.canvasHeight-contentPadding-1);

  txt.BeginBlock(textBlockOpt);
  try
    DrawMenu(menuRect);
    DrawScreenTitle(contentRect,SCREEN_TITLES[currentScreen],SCREEN_HINTS[currentScreen]);

    case currentScreen of
      0:DrawOverview(contentRect);
      1:DrawKeyboardDeep(contentRect);
      2:DrawMouseDeep(contentRect);
      3:DrawHighRateTrace(contentRect);
      4:DrawPollingVsEvents(contentRect);
      5:DrawStress(contentRect);
    end;

    txt.Write(hintFont,contentRect.Left+S(12),contentRect.Bottom-S(10),$FF9BB0C8,
      'Tip: switch screens with mouse or [F1..F6], trace mode [1..3] on High-Rate screen',taLeft,toAddBaseline);
  finally
    txt.EndBlock;
  end;
  inherited;
end;

end.
