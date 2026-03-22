// Input diagnostics demo for Apus Engine
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit SceneInputDemo;
interface
uses Apus.Engine.GameApp,Apus.Engine.API;

type
  TMainApp=class(TGameApplication)
    constructor Create;
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

    layoutScale:single;
    menuWidth,menuTop,menuItemHeight,contentPadding,screenTopOffset:integer;
    lastDPI:integer;

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
    procedure ProcessInputBuffers;
    procedure Render; override;

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
  result:=Bits.HasAll(window.mouseButtons,mbLeft) and not Bits.HasAll(window.oldMouseButtons,mbLeft);
end;

function SafeScan(tag:TTag):integer;
begin
  result:=Bits.GetByte(cardinal(tag),3);
end;

procedure InputEventHandler(event:TEventStr;tag:TTag);
var
  x,y,scan,keyCode:integer;
  sub:TEventStr;
  t:double;
  info:string;
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

  if EventOfClass(event,'SCENE\MAIN',sub) then begin
    if sub='KEYDOWN' then begin
      keyCode:=Bits.GetWord(cardinal(tag),0);
      scan:=SafeScan(tag);
      inc(sceneMain.keyDownEvents);
      inc(sceneMain.secKeyEvents);
      info:=Format('key=%d scan=%d',[keyCode,scan]);
      sceneMain.PushLog('KD',info);
      if (window.shiftState=0) and (keyCode>=ord(TKey.F1)) and (keyCode<=ord(TKey.F6)) then
        sceneMain.currentScreen:=keyCode-ord(TKey.F1);
      if scan=TRACKED_SCANS[0] then inc(sceneMain.eventKeyDownCnt[0]);
      if scan=TRACKED_SCANS[1] then inc(sceneMain.eventKeyDownCnt[1]);
      if scan=TRACKED_SCANS[2] then inc(sceneMain.eventKeyDownCnt[2]);
      if scan=TRACKED_SCANS[3] then inc(sceneMain.eventKeyDownCnt[3]);
      if scan=TRACKED_SCANS[4] then inc(sceneMain.eventKeyDownCnt[4]);
      if scan=TRACKED_SCANS[5] then inc(sceneMain.eventKeyDownCnt[5]);
      if scan=TRACKED_SCANS[6] then inc(sceneMain.eventKeyDownCnt[6]);
      if scan=TRACKED_SCANS[7] then inc(sceneMain.eventKeyDownCnt[7]);
      exit;
    end;
    if sub='KEYUP' then begin
      scan:=SafeScan(tag);
      inc(sceneMain.keyUpEvents);
      info:=Format('key=%d scan=%d',[Bits.GetWord(cardinal(tag),0),scan]);
      sceneMain.PushLog('KU',info);
      exit;
    end;
  end;
end;

constructor TMainApp.Create;
begin
  inherited;
  gameTitle:='Apus Engine: InputDemo';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  useRealDPI:=false;
  windowWidth:=1520;
  windowHeight:=860;
  windowSizeable:=false;
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmFixedWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
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
  lastDPI:=0;
  currentScreen:=0;
  traceMode:=3;
  textTopOpt:=toAddBaseline;
  textBlockOpt:=toDontTranslate or toWithShadow;
  UpdateMetrics;
  RebuildFonts;
  SetEventHandler('MOUSE\',InputEventHandler,emInstant);
  SetEventHandler('SCENE\MAIN\KEYDOWN,SCENE\MAIN\KEYUP',InputEventHandler,emInstant);
  loaded:=true;
end;

procedure TMainScene.UpdateMetrics;
begin
  layoutScale:=window.screenDPI/96;
  if layoutScale<1 then layoutScale:=1;
  menuWidth:=MENU_WIDTH+round((layoutScale-1)*110);
  menuWidth:=Clamp(menuWidth,340,window.renderWidth div 2);
  menuTop:=round(MENU_TOP*layoutScale);
  menuItemHeight:=round(MENU_ITEM_HEIGHT*layoutScale);
  contentPadding:=round(CONTENT_PADDING*layoutScale);
  screenTopOffset:=round(84*layoutScale);
end;

procedure TMainScene.RebuildFonts;
var
  fs:single;
  function F(baseSize:integer):integer;
  begin
    result:=round(baseSize*fs);
    if result<6 then result:=6;
  end;
begin
  fs:=window.screenDPI/96;
  if fs<1 then fs:=1;
  titleFont:=txt.GetFont('Default',F(12));
  menuFont:=txt.GetFont('Default',F(10));
  hintFont:=txt.GetFont('Default',F(8));
  bodyFont:=txt.GetFont('Default',F(8));
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

procedure TMainScene.HandleInput;
var
  item:integer;
begin
  if IsKeyPressed(60) or IsKeyPressed(59) or IsKeyPressed(58) then currentScreen:=0 else
  if IsKeyPressed(61) or IsKeyPressed(60) or IsKeyPressed(59) then currentScreen:=1 else
  if IsKeyPressed(62) or IsKeyPressed(61) or IsKeyPressed(60) then currentScreen:=2 else
  if IsKeyPressed(63) or IsKeyPressed(62) or IsKeyPressed(61) then currentScreen:=3 else
  if IsKeyPressed(64) or IsKeyPressed(63) or IsKeyPressed(62) then currentScreen:=4 else
  if IsKeyPressed(65) or IsKeyPressed(64) or IsKeyPressed(63) then currentScreen:=5;

  if IsKeyPressed(2) or IsKeyPressed(30) then traceMode:=1;
  if IsKeyPressed(3) or IsKeyPressed(31) then traceMode:=2;
  if IsKeyPressed(4) or IsKeyPressed(32) then traceMode:=3;

  if LMBClicked and (window.mouseX>=0) and (window.mouseX<menuWidth) and
     (window.mouseY>=menuTop) then begin
    item:=(window.mouseY-menuTop) div menuItemHeight;
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
  result:=Rect(0,0,window.renderWidth,window.renderHeight);
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

  txt.Write(titleFont,20,25,$FFE8F0FA,'InputDemo Screens',taLeft,toAddBaseline);
  txt.Write(hintFont,20,52,$FFA4B7CE,'Mouse click or keys [F1..F6]',taLeft,toAddBaseline);

  for i:=0 to SCREEN_COUNT-1 do begin
    top:=menuTop+i*menuItemHeight;
    bottom:=top+menuItemHeight-6;
    r:=Rect(menuRect.Left+12,top,menuRect.Right-12,bottom);
    isActive:=i=currentScreen;
    isHovered:=PtInRect(r,Point(window.mouseX,window.mouseY));

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

    draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,bg,8);
    draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,8,border);
    txt.Write(menuFont,r.Left+12,r.Top+18,txtCol,Conv.ToStr(i+1)+'. '+SCREEN_TITLES[i],taLeft,integer(textTopOpt));
  end;
end;

procedure TMainScene.DrawScreenTitle(const contentRect:TRect; const title,subtitle:string);
begin
  draw.FillRect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF1F2A3A);
  draw.Rect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF3D5067);
  txt.Write(titleFont,contentRect.Left+14,contentRect.Top+16,$FFEAF2FC,title,taLeft,toAddBaseline);
  txt.Write(hintFont,contentRect.Left+14,contentRect.Top+44,$FFA8BDD5,subtitle,taLeft,toAddBaseline);
end;

procedure TMainScene.DrawTag(x,y:integer;const st:string;color:cardinal=$FFE6EEF8);
var
  h:integer;
begin
  h:=txt.Height(bodyFont);
  draw.FillRect(x-4,y-3,x+txt.Width(bodyFont,st)+4,y+h+3,$50202A38);
  txt.Write(bodyFont,x,y,color,st,taLeft,toAddBaseline);
end;

procedure TMainScene.DrawOverview(const contentRect:TRect);
var
  a,b,c:TRect;
  st:string;
  i,y,maxLines:integer;
  pClient,pScreen:TPoint;
begin
  a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+620,contentRect.Bottom-20);
  b:=Rect(contentRect.Left+640,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Top+350);
  c:=Rect(contentRect.Left+640,contentRect.Top+370,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,10);
  draw.FillRRect(c.Left,c.Top,c.Right,c.Bottom,$FF202D3D,10);

  DrawTag(a.Left+20,a.Top+24,'Keyboard State');
  y:=a.Top+52;
  for i:=0 to high(TRACKED_SCANS) do begin
    st:=Format('%-6s down=%d pressed=%d released=%d  pollCnt=%d evtCnt=%d',
      [TRACKED_NAMES[i],byte(IsKeyDown(TRACKED_SCANS[i])),byte(IsKeyPressed(TRACKED_SCANS[i])),
       byte(IsKeyReleased(TRACKED_SCANS[i])),pollingKeyPressCnt[i],eventKeyDownCnt[i]]);
    txt.Write(bodyFont,a.Left+20,y,$FFE5EDF7,st,taLeft,toAddBaseline);
    inc(y,20);
  end;

  st:=Format('ShiftState=%d  LMB=%d RMB=%d MMB=%d',[window.shiftState,
    byte(Bits.HasAll(window.mouseButtons,mbLeft)),byte(Bits.HasAll(window.mouseButtons,mbRight)),
    byte(Bits.HasAll(window.mouseButtons,mbMiddle))]);
  txt.Write(bodyFont,a.Left+20,y+8,$FFF3D39C,st,taLeft,toAddBaseline);
  st:=Format('Mods: LS=%d RS=%d LC=%d RC=%d LA=%d RA=%d LW=%d RW=%d',
    [byte(Bits.HasAll(window.shiftState,sscShift) and not Bits.HasAll(window.shiftState,sscRShift)),
     byte(Bits.HasAll(window.shiftState,sscRShift)),
     byte(Bits.HasAll(window.shiftState,sscCtrl) and not Bits.HasAll(window.shiftState,sscRCtrl)),
     byte(Bits.HasAll(window.shiftState,sscRCtrl)),
     byte(Bits.HasAll(window.shiftState,sscAlt) and not Bits.HasAll(window.shiftState,sscRAlt)),
     byte(Bits.HasAll(window.shiftState,sscRAlt)),
     byte(Bits.HasAll(window.shiftState,sscWin) and not Bits.HasAll(window.shiftState,sscRWin)),
     byte(Bits.HasAll(window.shiftState,sscRWin))]);
  txt.Write(bodyFont,a.Left+20,y+28,$FFF3D39C,st,taLeft,toAddBaseline);

  DrawTag(b.Left+20,b.Top+24,'Input Summary');
  pClient:=Point(window.mouseX,window.mouseY);
  game.GameToClient(pClient);
  pScreen:=pClient;
  window.ClientToScreen(pScreen);
  txt.Write(bodyFont,b.Left+20,b.Top+52,$FFE5EDF7,
    Format('Mouse game: (%d,%d) old=(%d,%d)',[window.mouseX,window.mouseY,window.oldMouseX,window.oldMouseY]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+20,b.Top+72,$FFE5EDF7,
    Format('Mouse window(client): (%d,%d)',[pClient.X,pClient.Y]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+20,b.Top+92,$FFE5EDF7,
    Format('Mouse screen: (%d,%d)',[pScreen.X,pScreen.Y]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+20,b.Top+122,$FFE5EDF7,
    Format('Window: %dx%d render=%dx%d',[window.windowWidth,window.windowHeight,window.renderWidth,window.renderHeight]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+20,b.Top+152,$FFE5EDF7,
    Format('Events total: move=%d wheel=%d keyDown=%d keyUp=%d char=%d',
      [moveEventsTotal,wheelEventsTotal,keyDownEvents,keyUpEvents,charEvents]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+20,b.Top+172,$FFE5EDF7,
    Format('Rates (/sec): move=%.1f wheel=%.1f key=%.1f char=%.1f',
      [rateMove,rateWheel,rateKey,rateChar]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+20,b.Top+192,$FFE5EDF7,
    Format('Samples/frame: now=%d max=%d',[rawPerFrame,maxRawPerFrame]),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+20,b.Top+222,$FFF3D39C,
    Format('FPS: %.1f  SmoothFPS: %.1f',[window.FPS,window.smoothFPS]),taLeft,toAddBaseline);

  draw.FillRect(c.Left+20,c.Top+44,c.Right-20,c.Bottom-20,$30233A53);
  DrawTag(c.Left+24,c.Top+20,'Last Events');
  y:=c.Top+54;
  maxLines:=(c.Bottom-26-y) div 20;
  if maxLines<0 then maxLines:=0;
  for i:=0 to maxLines-1 do begin
    if i>=logCount then break;
    st:=logs[(logHead-1-i+Length(logs)) mod Length(logs)].kind+'  '+
      Format('%.3f',[logs[(logHead-1-i+Length(logs)) mod Length(logs)].t])+'  '+
      logs[(logHead-1-i+Length(logs)) mod Length(logs)].info;
    txt.Write(bodyFont,c.Left+24,y,$FFD8E7F8,st,taLeft,toAddBaseline);
    inc(y,20);
  end;
end;

procedure TMainScene.DrawKeyboardDeep(const contentRect:TRect);
var
  r:TRect;
  i,y,idx,maxLines:integer;
  st:string;
begin
  r:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF202D3D,10);
  DrawTag(r.Left+20,r.Top+24,'Buffered Key Stream (scene.ReadKey + SCENE\\Main\\KeyDown/KeyUp)');

  txt.Write(bodyFont,r.Left+20,r.Top+52,$FFE5EDF7,
    Format('Totals: keyDown=%d keyUp=%d char=%d',[keyDownEvents,keyUpEvents,charEvents]),taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+20,r.Top+72,$FFE5EDF7,
    'Fields: [kind] [time] [payload]',taLeft,toAddBaseline);

  y:=r.Top+102;
  maxLines:=(r.Bottom-24-y) div 20;
  if maxLines<0 then maxLines:=0;
  for i:=0 to maxLines-1 do begin
    if i>=logCount then break;
    idx:=(logHead-1-i+Length(logs)) mod Length(logs);
    st:=Format('%-6s %8.3f  %s',[logs[idx].kind,logs[idx].t,logs[idx].info]);
    txt.Write(bodyFont,r.Left+20,y,$FFD8E7F8,st,taLeft,toAddBaseline);
    inc(y,20);
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
  a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+720,contentRect.Bottom-20);
  b:=Rect(contentRect.Left+740,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,10);

  DrawTag(a.Left+20,a.Top+24,'Mouse Zones / Buttons');
  txt.Write(bodyFont,a.Left+20,a.Top+48,$FFE5EDF7,'Move cursor through zones, click buttons 1..5, use wheel.',taLeft,toAddBaseline);
  zone1:=Rect(a.Left+50,a.Top+120,a.Left+330,a.Top+330);
  zone2:=Rect(a.Left+380,a.Top+120,a.Right-50,a.Top+330);
  c1:=$404890C0;
  c2:=$4060A060;
  if PtInRect(zone1,Point(window.mouseX,window.mouseY)) then c1:=$70A0D8FF;
  if PtInRect(zone2,Point(window.mouseX,window.mouseY)) then c2:=$70A8F0A8;
  draw.FillRRect(zone1.Left,zone1.Top,zone1.Right,zone1.Bottom,c1,12);
  draw.FillRRect(zone2.Left,zone2.Top,zone2.Right,zone2.Bottom,c2,12);
  draw.RRect(zone1.Left,zone1.Top,zone1.Right,zone1.Bottom,2,12,$FFE8F4FF);
  draw.RRect(zone2.Left,zone2.Top,zone2.Right,zone2.Bottom,2,12,$FFE8F4FF);
  DrawTag(zone1.Left+16,zone1.Top+18,'Hover Zone A (enter/leave test)');
  DrawTag(zone2.Left+16,zone2.Top+18,'Hover Zone B (independent area)');

  st:=Format('Btn events: down=%d up=%d',[btnDownEvents,btnUpEvents]);
  txt.Write(bodyFont,a.Left+20,a.Top+360,$FFE5EDF7,st,taLeft,toAddBaseline);
  txt.Write(bodyFont,a.Left+20,a.Top+380,$FFE5EDF7,
    Format('Wheel: lastDelta=%d events=%d totalDelta=%d rate=%.1f/s',
      [lastWheelDelta,wheelEventsTotal,wheelDeltaTotal,rateWheel]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,a.Left+20,a.Top+400,$FFE5EDF7,
    Format('Mouse buttons mask: %d old=%d',[window.mouseButtons,window.oldMouseButtons]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,a.Left+20,a.Top+420,$FFE5EDF7,
    Format('L=%d R=%d M=%d X1=%d X2=%d',
      [byte(Bits.HasAll(window.mouseButtons,1)),byte(Bits.HasAll(window.mouseButtons,2)),
       byte(Bits.HasAll(window.mouseButtons,4)),byte(Bits.HasAll(window.mouseButtons,8)),
       byte(Bits.HasAll(window.mouseButtons,16))]),taLeft,integer(textTopOpt));
  pClient:=Point(window.mouseX,window.mouseY);
  game.GameToClient(pClient);
  pScreen:=pClient;
  window.ClientToScreen(pScreen);
  txt.Write(bodyFont,a.Left+20,a.Top+448,$FFF3D39C,
    Format('Pos game=(%d,%d) client=(%d,%d) screen=(%d,%d)',
      [window.mouseX,window.mouseY,pClient.X,pClient.Y,pScreen.X,pScreen.Y]),taLeft,integer(textTopOpt));

  DrawTag(b.Left+20,b.Top+24,'Recent Raw Mouse Samples');
  txt.Write(bodyFont,b.Left+20,b.Top+52,$FFE5EDF7,
    Format('Raw samples: %d  move events total: %d',[rawCount,moveEventsTotal]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,b.Left+20,b.Top+72,$FFE5EDF7,
    'Fields: [time] [x,y] [buttons]',taLeft,integer(textTopOpt));

  st:='';
  if rawCount>0 then begin
    st:=Format('Last sample: t=%.3f x=%d y=%d b=%d',[
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].t,
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].x,
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].y,
      rawSamples[(rawHead-1+Length(rawSamples)) mod Length(rawSamples)].buttons]);
  end;
  txt.Write(bodyFont,b.Left+20,b.Top+92,$FFF3D39C,st,taLeft,integer(textTopOpt));

  st:=Format('rates: move=%.1f/s, samples/frame=%d (max=%d)',[rateMove,rawPerFrame,maxRawPerFrame]);
  txt.Write(bodyFont,b.Left+20,b.Top+112,$FFD8E7F8,st,taLeft,integer(textTopOpt));
  txt.Write(bodyFont,b.Left+20,b.Top+140,$FF9BB0C8,
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
  s:TMouseSample;
  prevX,prevY:single;
  modeName:string;
begin
  area:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(area.Left,area.Top,area.Right,area.Bottom,$FF202D3D,10);

  plotRect:=Rect(area.Left+20,area.Top+96,area.Right-20,area.Bottom-24);
  draw.FillRect(plotRect.Left,plotRect.Top,plotRect.Right,plotRect.Bottom,$FF1B2636);
  draw.RRect(plotRect.Left,plotRect.Top,plotRect.Right,plotRect.Bottom,1,8,$FF516883);
  DrawTag(area.Left+24,area.Top+14,'High-Rate Mouse Trace');
  case traceMode of
    1:modeName:='raw only (1)';
    2:modeName:='frame only (2)';
  else
    modeName:='raw + frame (3)';
  end;
  txt.Write(bodyFont,area.Left+24,area.Top+46,$FFE5EDF7,'Mode '+modeName+'; press [1..3] to switch.');
  txt.Write(bodyFont,area.Left+24,area.Top+68,$FFE5EDF7,'Traces are drawn in absolute game coords; clipped by plot area.');

  nowT:=CoreTime.Ticks*0.001;
  traceWindow:=2.5;
  fromT:=nowT-traceWindow;
  prevX:=0;
  prevY:=0;

  hasPrev:=false;
  sampleCnt:=0;
  for i:=0 to rawCount-1 do begin
    idx:=(rawHead-rawCount+i+Length(rawSamples)) mod Length(rawSamples);
    s:=rawSamples[idx];
    if s.t<fromT then continue;
    sx:=s.x;
    sy:=s.y;
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
    s:=frameSamples[idx];
    if s.t<fromT then continue;
    sx:=s.x;
    sy:=s.y;
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

  x1:=area.Left+24; y1:=area.Bottom-10;
  x2:=x1+70; y2:=y1;
  draw.Line(x1,y1,x2,y2,$FF60E4FF);
  txt.Write(bodyFont,round(x2+8),round(y1+4),$FFDCEEFE,'raw event samples');
  draw.Line(x1+230,y1,x1+280,y1,$FFFFD070);
  txt.Write(bodyFont,round(x1+288),round(y1+4),$FFEFE4C0,'frame-latched path');

  st:=Format('window=%.1fs rawSamples=%d frameSamples=%d rawRate=%.1f/s maxRawPerFrame=%d mode=%s',
    [traceWindow,sampleCnt,frameCnt,rateMove,maxRawPerFrame,modeName]);
  txt.Write(bodyFont,area.Left+24,area.Top+86,$FFE5EDF7,st);
end;

procedure TMainScene.DrawPollingVsEvents(const contentRect:TRect);
var
  r:TRect;
  i,y:integer;
  st:string;
  col:cardinal;
begin
  r:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF202D3D,10);
  DrawTag(r.Left+20,r.Top+24,'Polling(IsKeyPressed) vs Event(SCENE\\Main\\KeyDown)');

  y:=r.Top+56;
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
    txt.Write(bodyFont,r.Left+20,y,col,st,taLeft,integer(textTopOpt));
    inc(y,20);
  end;

  txt.Write(bodyFont,r.Left+20,r.Bottom-26,$FF9BB0C8,
    'green=close, yellow=moderate mismatch, red=large mismatch',taLeft,integer(textTopOpt));
end;

procedure TMainScene.DrawStress(const contentRect:TRect);
var
  r:TRect;
  st:string;
begin
  r:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF202D3D,10);
  DrawTag(r.Left+20,r.Top+24,'Stress Snapshot');

  st:=Format('moveEvents=%d keyDown=%d keyUp=%d char=%d rawSamples=%d logs=%d',
    [moveEventsTotal,keyDownEvents,keyUpEvents,charEvents,rawCount,logCount]);
  txt.Write(bodyFont,r.Left+20,r.Top+56,$FFE5EDF7,st,taLeft,integer(textTopOpt));
  txt.Write(bodyFont,r.Left+20,r.Top+76,$FFE5EDF7,
    Format('wheelEvents=%d lastWheel=%d wheelTotal=%d rateWheel=%.1f/s',
      [wheelEventsTotal,lastWheelDelta,wheelDeltaTotal,rateWheel]),taLeft,integer(textTopOpt));
  txt.Write(bodyFont,r.Left+20,r.Top+96,$FFE5EDF7,
    Format('rateMove=%.1f rateKey=%.1f rateChar=%.1f raw/frame now=%d max=%d',
      [rateMove,rateKey,rateChar,rawPerFrame,maxRawPerFrame]),taLeft,integer(textTopOpt));

  draw.FillRect(r.Left+20,r.Top+132,r.Right-20,r.Bottom-24,$30233A53);
  DrawTag(r.Left+24,r.Top+148,'Usage');
  txt.Write(bodyFont,r.Left+24,r.Top+174,$FFD8E7F8,'1) Move mouse in circles: check High-Rate Trace raw continuity',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+24,r.Top+194,$FFD8E7F8,'2) Scroll wheel up/down: verify WHEEL events and deltas',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+24,r.Top+214,$FFD8E7F8,'3) Hold/release keys rapidly: compare Polling vs Events',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+24,r.Top+234,$FFD8E7F8,'4) Click/drag in Mouse Deep zones: verify button transitions',taLeft,toAddBaseline);
  txt.Write(bodyFont,r.Left+24,r.Top+254,$FFD8E7F8,'5) Keyboard Deep logs buffered ReadKey stream',taLeft,toAddBaseline);
end;

procedure TMainScene.Render;
var
  menuRect,contentRect:TRect;
  dpiNow:integer;
  t:double;
begin
  UpdateMetrics;
  dpiNow:=window.screenDPI;
  if dpiNow<>lastDPI then begin
    lastDPI:=dpiNow;
    RebuildFonts;
  end;

  HandleInput;
  ProcessInputBuffers;
  UpdateStats;

  t:=CoreTime.Ticks*0.001;
  PushFrameSample(window.mouseX,window.mouseY,window.mouseButtons,t);

  gfx.target.Clear($FF151C27);

  menuRect:=Rect(0,0,menuWidth-1,window.renderHeight-1);
  contentRect:=Rect(menuWidth+contentPadding,contentPadding,
    window.renderWidth-contentPadding-1,window.renderHeight-contentPadding-1);

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

    txt.Write(hintFont,contentRect.Left+12,contentRect.Bottom-10,$FF9BB0C8,
      'Tip: switch screens with mouse or [F1..F6], trace mode [1..3] on High-Rate screen',taLeft,toAddBaseline);
  finally
    txt.EndBlock;
  end;
  inherited;
end;

end.
