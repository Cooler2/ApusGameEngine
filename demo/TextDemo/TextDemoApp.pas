// Text rendering showcase/demo for Apus Engine
//
// Screen scaling (HiDPI) shown here: REAL PIXELS + UI SCALE.
// The canvas is in screen pixels. Every layout number goes through S(), which multiplies
// it by game.screenScale (1, 1.2, 1.5, 2...); fonts from txt.GetFont follow that scale
// by themselves.
// Good for: pixel-precise text: alignment, raster fonts at their own sizes,
//   text next to 1px lines and frames.
// Costs: every number has to be wrapped, and a forgotten one stays small on a HiDPI
// display.
// Other demos show other ways: check which one fits your case before copying.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit TextDemoApp;
interface
uses
  Apus.Engine.GameApp,
  Apus.Engine.API;

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
  Math,
  Apus.Core,
  Apus.Conv,
  Apus.Strings,
  Apus.Engine.Keys,
  Apus.Engine.Types,
  Apus.Engine.Scene,
  Apus.Engine.TextDraw,
  Apus.Engine.TextEffects;

type
  TMainScene=class(TGameScene)
    titleFont,menuFont,hintFont,bodyFont,monoFont:TFontHandle;
    vectorFont,rasterFont:TFontHandle;
    currentScreen:integer;
    uiScale:single; // game.screenScale the metrics are built for
    menuWidth,menuTop,menuItemHeight,contentPadding,screenTopOffset:integer;
    baseOpt:cardinal;
    vectorFontName,rasterFontName:string;
    vectorFontLoaded,rasterFontLoaded:boolean;
    lastLink:integer;
    deltaHist:array[0..9] of integer;
    deltaHistPos,deltaHistCount:integer;
    procedure UpdateDeltaStats;
    function MaxRecentDeltaMs:integer;
    procedure DrawOverlayStats;
    procedure Load; override;
    function Process:boolean; override;
    procedure Render; override;
    function GetArea:TRect; override;
    function S(v:integer):integer;
    procedure UpdateMetrics;
    procedure RebuildFonts;
    procedure TryLoadDemoFonts;
    procedure HandleInput;
    procedure DrawMenu(const menuRect:TRect);
    procedure DrawScreenTitle(const contentRect:TRect;const title,subtitle:string);
    procedure DrawTag(x,y:integer;const st:string;color:cardinal=$FFE6EEF8);
    procedure DrawBlock(const r:TRect;const title:string;out innerR:TRect);
    function GridCell(const area:TRect;col,row,cols,rows,gap:integer):TRect;
    procedure DrawOverview(const contentRect:TRect);
    procedure DrawWriteFamily(const contentRect:TRect);
    procedure DrawAlignment(const contentRect:TRect);
    procedure DrawStyles(const contentRect:TRect);
    procedure DrawMeasureLinks(const contentRect:TRect);
    procedure DrawBlockAndCache(const contentRect:TRect);
    procedure DrawUnicodeComplex(const contentRect:TRect);
    procedure DrawMetrics(const contentRect:TRect);
    procedure DrawEffects(const contentRect:TRect);
  end;

const
  SCREEN_COUNT=9;
  MENU_WIDTH=380;
  MENU_TOP=78;
  MENU_ITEM_HEIGHT=54;
  CONTENT_PADDING=18;
  BLOCK_TITLE_H=26;
  BLOCK_RADIUS=8;
  BLOCK_GAP=10;

  SCREEN_TITLES:array[0..SCREEN_COUNT-1] of string=(
    'Overview',
    'Write Family',
    'Alignment',
    'Styles && Hinting',
    'Measure && Links',
    'Block && Cache',
    'Unicode && Complex',
    'Metrics && Scale',
    'Text Effects'
  );

  SCREEN_HINTS:array[0..SCREEN_COUNT-1] of string=(
    'Coverage map + controls + runtime info',
    'txt.Write / WriteW / WriteR / WriteC',
    'left/center/right/justify and top-vs-baseline',
    'bold/italic/underline/shadow/hinting/spacing',
    'toMeasure, hyperlinks, query point and SML align modes',
    'BeginBlock/EndBlock, toDontCache and MAGIC_TEXTCACHE preview',
    'multiline Unicode + complex markup + align',
    'Width/WidthW/Height, ScaleFont, font options',
    'DrawTextFX: glow, outline, shadow layers (R-33)'
  );

var
  sceneMain:TMainScene;

function LMBClicked:boolean;
begin
  result:=Mouse.WasPressed;
end;

function ClampI(v,minV,maxV:integer):integer;
begin
  if v<minV then exit(minV);
  if v>maxV then exit(maxV);
  result:=v;
end;

function SampleWide:WideString;
begin
  result:=WideString('Unicode: ')+WideString(#$041F#$0440#$0438#$0432#$0435#$0442)+
    WideString('  ')+WideString(#$03B1#$00B2)+WideString('  ')+WideString(#$2116)+WideString('42');
end;

procedure TMainApp.SetupApplication;
begin
  inherited;
  appSetup.title:='Apus Engine: TextDemo';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(1620,920);
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
var
  i:integer;
begin
  currentScreen:=0;
  for i:=1 to ParamCount do // -screen=N opens screen N (1-based) at start
    if SameText(copy(ParamStr(i),1,8),'-screen=') then
      currentScreen:=EnsureRange(StrToIntDef(copy(ParamStr(i),9,3),1)-1,0,SCREEN_COUNT-1);
  baseOpt:=toDontTranslate;
  vectorFontLoaded:=false;
  rasterFontLoaded:=false;
  vectorFontName:='Default';
  rasterFontName:='Default';
  deltaHistPos:=0;
  deltaHistCount:=0;
  FillChar(deltaHist,SizeOf(deltaHist),0);
  UpdateMetrics;
  TryLoadDemoFonts;
  RebuildFonts;
  loaded:=true;
end;

procedure TMainScene.UpdateDeltaStats;
begin
  deltaHist[deltaHistPos]:=window.frameDeltaMs;
  deltaHistPos:=(deltaHistPos+1) mod Length(deltaHist);
  if deltaHistCount<Length(deltaHist) then inc(deltaHistCount);
end;

function TMainScene.MaxRecentDeltaMs:integer;
var
  i:integer;
begin
  result:=0;
  for i:=0 to deltaHistCount-1 do
    if deltaHist[i]>result then
      result:=deltaHist[i];
end;

procedure TMainScene.DrawOverlayStats;
var
  st:string;
  y:integer;
begin
  y:=window.canvasHeight-S(6);
  st:=Format('frameDelta: %d/%d ms',[window.frameDeltaMs,MaxRecentDeltaMs]);
  txt.Write(hintFont,S(12),y,$FFE6F0FA,st,taLeft,toWithShadow or toDontTranslate);
end;

procedure TMainScene.TryLoadDemoFonts;
const
  TTF_PATHS:array[0..4] of string=(
    'res\arial.ttf',
    '..\legacy\EngineTest\res\arial.ttf',
    'demo\legacy\EngineTest\res\arial.ttf',
    '..\..\demo\legacy\EngineTest\res\arial.ttf',
    '..\..\..\demo\legacy\EngineTest\res\arial.ttf'
  );
var
  i:integer;
begin
  vectorFontLoaded:=false;
  rasterFontLoaded:=true;
  vectorFontName:='DefaultVector';
  rasterFontName:='Default';

  for i:=0 to high(TTF_PATHS) do begin
    if not FileExists(TTF_PATHS[i]) then continue;
    try
      vectorFontName:=txt.LoadFont(TTF_PATHS[i],'DemoArial');
      vectorFontLoaded:=true;
      break;
    except
      // no freetype or broken file, fallback to raster/default
    end;
  end;
end;

// Layout sizes are given for 96 DPI: scaled by the UI scale, as the text is
function TMainScene.S(v:integer):integer;
begin
  result:=round(v*uiScale);
end;

procedure TMainScene.UpdateMetrics;
begin
  uiScale:=game.screenScale;
  menuWidth:=ClampI(S(MENU_WIDTH),0,window.canvasWidth div 2);
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
  rasterFont:=txt.GetFont(rasterFontName,8,fsStrictMatch);
  if rasterFont=0 then rasterFont:=txt.GetFont('Default',8);
  vectorFont:=0;
  if vectorFontLoaded then
    vectorFont:=txt.GetFont(vectorFontName,8,fsStrictMatch);
  if vectorFont=0 then vectorFont:=rasterFont;
  bodyFont:=rasterFont;
  monoFont:=txt.GetFont('Default',7);
  txt.SetFontOption(rasterFont,foDownscaleFactor,1.0);
  txt.SetFontOption(rasterFont,foUpscaleFactor,1.0);
  if vectorFontLoaded then
    txt.SetFontOption(vectorFont,foGlobalScale,1.0);
end;

function TMainScene.Process:boolean;
begin
  result:=inherited;
  // input reactions belong here: Render may be skipped, Process runs every frame
  if loaded then HandleInput; // the menu metrics come from Load
end;

procedure TMainScene.HandleInput;
const
  F_SCANS:array[0..8] of integer=(59,60,61,62,63,64,65,66,67); // F1..F9
  D_SCANS:array[0..8] of integer=(2,3,4,5,6,7,8,9,10); // 1..9
var
  i,item:integer;
begin
  for i:=0 to SCREEN_COUNT-1 do begin
    if (window.shiftState=0) and (IsKeyPressed(F_SCANS[i]) or IsKeyPressed(D_SCANS[i])) then
      currentScreen:=i;
  end;

  if LMBClicked and (window.mousePos.x>=0) and (window.mousePos.x<menuWidth) and
     (window.mousePos.y>=menuTop) then begin
    item:=(window.mousePos.y-menuTop) div menuItemHeight;
    if InRange(item,0,SCREEN_COUNT-1) then
      currentScreen:=item;
  end;
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

  txt.Write(titleFont,S(20),S(28),$FFE8F0FA,'TextDemo Screens',taLeft,toAddBaseline or toWithShadow);
  txt.Write(hintFont,S(20),S(52),$FFA4B7CE,'Mouse click or keys [F1..F9] / [1..9]',taLeft,toAddBaseline);

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
    txt.Write(menuFont,r.Left+S(12),r.Top+S(17),txtCol,Conv.ToStr(i+1)+'. '+SCREEN_TITLES[i],taLeft,toAddBaseline);
  end;
end;

procedure TMainScene.DrawScreenTitle(const contentRect:TRect;const title,subtitle:string);
begin
  draw.FillRect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-S(10),$FF1F2A3A);
  draw.Rect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-S(10),$FF3D5067);
  txt.Write(titleFont,contentRect.Left+S(14),contentRect.Top+S(16),$FFEAF2FC,title,taLeft,toAddBaseline or toWithShadow);
  txt.Write(hintFont,contentRect.Left+S(14),contentRect.Top+S(44),$FFA8BDD5,subtitle,taLeft,toAddBaseline);
end;

procedure TMainScene.DrawTag(x,y:integer;const st:string;color:cardinal=$FFE6EEF8);
var
  h:integer;
begin
  h:=txt.Height(bodyFont);
  draw.FillRect(x-S(4),y-S(3),x+txt.Width(bodyFont,st)+S(4),y+h+S(3),$50202A38);
  txt.Write(bodyFont,x,y,color,st,taLeft,toAddBaseline or toWithShadow);
end;

procedure TMainScene.DrawBlock(const r:TRect;const title:string;out innerR:TRect);
begin
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF1C2836,S(BLOCK_RADIUS));
  draw.FillRect(r.Left+1,r.Top+1,r.Right-1,r.Top+S(BLOCK_TITLE_H),$28AACCFF);
  draw.Rect(r.Left,r.Top,r.Right,r.Bottom,$FF3D5270);
  draw.Line(r.Left+1,r.Top+S(BLOCK_TITLE_H),r.Right-1,r.Top+S(BLOCK_TITLE_H),$FF3D5270);
  txt.Write(bodyFont,r.Left+S(10),r.Top+S(6),$FFDDEEFF,title,taLeft,toAddBaseline or toWithShadow);
  innerR:=Rect(r.Left+S(8),r.Top+S(BLOCK_TITLE_H)+S(6),r.Right-S(8),r.Bottom-S(8));
end;

function TMainScene.GridCell(const area:TRect;col,row,cols,rows,gap:integer):TRect;
var
  w,h,x,y:integer;
begin
  w:=(area.Right-area.Left-(cols-1)*gap) div cols;
  h:=(area.Bottom-area.Top-(rows-1)*gap) div rows;
  x:=area.Left+col*(w+gap);
  y:=area.Top+row*(h+gap);
  result:=Rect(x,y,x+w,y+h);
end;

procedure TMainScene.DrawOverview(const contentRect:TRect);
var
  area,r,innerR:TRect;
  srcV,srcR:string;
  c,leftX,rightX,anchorX:integer;
begin
  area:=Rect(contentRect.Left+S(10),contentRect.Top+screenTopOffset,contentRect.Right-S(10),contentRect.Bottom-S(20));

  // 0) Raster baseline/align
  r:=GridCell(area,0,0,3,2,S(BLOCK_GAP));
  DrawBlock(r,'Raster: Baseline && Align',innerR);
  leftX:=innerR.Left+S(12);
  rightX:=innerR.Right-S(12);
  anchorX:=rightX-1;
  draw.Line(leftX,innerR.Top+S(14),leftX,innerR.Bottom-S(24),$4060B080);
  draw.Line(rightX,innerR.Top+S(14),rightX,innerR.Bottom-S(24),$70FFFFFF);
  draw.Line(innerR.Left+S(10),innerR.Top+S(16),innerR.Right-S(10),innerR.Top+S(16),$50FFFFFF);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+S(16),(innerR.Left+innerR.Right) div 2,innerR.Bottom-S(24),$30FFFFFF);
  txt.Write(rasterFont,leftX,innerR.Top+S(16),$FFE5EDF7,'baseline (no top flag)',taLeft,0);
  txt.Write(rasterFont,leftX,innerR.Top+S(44),$FF9CD0FF,'top (toAddBaseline)',taLeft,toAddBaseline);
  txt.Write(rasterFont,(innerR.Left+innerR.Right) div 2,innerR.Top+S(76),$FFE5EDF7,'centered label',taCenter,toAddBaseline);
  txt.Write(rasterFont,anchorX,innerR.Top+S(104),$FFE6CFA0,'right label',taRight,toAddBaseline);
  txt.Write(monoFont,leftX,innerR.Bottom-S(8),$FF90C0E8,'bounds: [left, right), right line is exclusive',taLeft,toAddBaseline);

  // 1) Vector baseline/align
  r:=GridCell(area,1,0,3,2,S(BLOCK_GAP));
  DrawBlock(r,'Vector: Baseline && Align',innerR);
  leftX:=innerR.Left+S(12);
  rightX:=innerR.Right-S(12);
  anchorX:=rightX-1;
  draw.Line(leftX,innerR.Top+S(14),leftX,innerR.Bottom-S(24),$4060B080);
  draw.Line(rightX,innerR.Top+S(14),rightX,innerR.Bottom-S(24),$70FFFFFF);
  draw.Line(innerR.Left+S(10),innerR.Top+S(16),innerR.Right-S(10),innerR.Top+S(16),$50FFFFFF);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+S(16),(innerR.Left+innerR.Right) div 2,innerR.Bottom-S(24),$30FFFFFF);
  txt.Write(vectorFont,leftX,innerR.Top+S(16),$FFE5EDF7,'baseline (vector)',taLeft,0);
  txt.Write(vectorFont,leftX,innerR.Top+S(44),$FF9CD0FF,'top (toAddBaseline)',taLeft,toAddBaseline);
  txt.Write(vectorFont,(innerR.Left+innerR.Right) div 2,innerR.Top+S(76),$FFE5EDF7,'centered label',taCenter,toAddBaseline);
  txt.Write(vectorFont,anchorX,innerR.Top+S(104),$FFE6CFA0,'right label',taRight,toAddBaseline);
  txt.Write(monoFont,leftX,innerR.Bottom-S(8),$FF90C0E8,'bounds: [left, right), right line is exclusive',taLeft,toAddBaseline);

  // 2) Center proof with guides and symmetric lines
  r:=GridCell(area,2,0,3,2,S(BLOCK_GAP));
  DrawBlock(r,'Center Proof (Guides)',innerR);
  c:=(innerR.Left+innerR.Right) div 2;
  draw.FillRect(innerR.Left+S(20),innerR.Top+S(24),innerR.Right-S(20),innerR.Bottom-S(18),$24223240);
  draw.Line(c,innerR.Top+S(20),c,innerR.Bottom-S(12),$70A0D0FF);
  draw.Line(c-S(80),innerR.Top+S(20),c-S(80),innerR.Bottom-S(12),$4060B080);
  draw.Line(c+S(80),innerR.Top+S(20),c+S(80),innerR.Bottom-S(12),$4060B080);
  draw.Line(c-S(140),innerR.Top+S(20),c-S(140),innerR.Bottom-S(12),$30406080);
  draw.Line(c+S(140),innerR.Top+S(20),c+S(140),innerR.Bottom-S(12),$30406080);
  txt.Write(bodyFont,c,innerR.Top+S(46),$FFE5EDF7,'Centered text',taCenter,toAddBaseline or toWithShadow);
  txt.Write(bodyFont,c,innerR.Top+S(76),$FF90D0A8,'Equal offsets left/right',taCenter,toAddBaseline);
  txt.Write(bodyFont,c,innerR.Top+S(106),$FFE8CFA0,'Anchor = blue center line',taCenter,toAddBaseline);

  // 3) Multilingual samples (raster + vector)
  r:=GridCell(area,0,1,3,2,S(BLOCK_GAP));
  DrawBlock(r,'Multilingual Samples',innerR);
  txt.Write(rasterFont,innerR.Left+S(10),innerR.Top+S(28),$FFE5EDF7,'RU: Привет, мир!  EN: Hello world!',taLeft,toAddBaseline);
  txt.Write(rasterFont,innerR.Left+S(10),innerR.Top+S(52),$FFBEE8A8,'FR: Première écriture  DE: Grüße',taLeft,toAddBaseline);
  txt.Write(vectorFont,innerR.Left+S(10),innerR.Top+S(82),$FFE5EDF7,'RU: Привет, мир!  EN: Hello world!',taLeft,toAddBaseline);
  txt.Write(vectorFont,innerR.Left+S(10),innerR.Top+S(106),$FFBEE8A8,'FR: Première écriture  DE: Grüße',taLeft,toAddBaseline);

  // 4) Size / color / alpha
  r:=GridCell(area,1,1,3,2,S(BLOCK_GAP));
  DrawBlock(r,'Sizes, Colors, Alpha',innerR);
  draw.FillRect(innerR.Left+S(8),innerR.Top+S(18),innerR.Right-S(8),innerR.Bottom-S(8),$40243044);
  txt.Write(txt.ScaleFont(rasterFont,0.9),innerR.Left+S(12),innerR.Top+S(34),$FFE8EDF8,'raster scale 0.9',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(vectorFont,1.2),innerR.Left+S(12),innerR.Top+S(62),$FF80E0FF,'vector scale 1.2',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(vectorFont,1.6),innerR.Left+S(12),innerR.Top+S(96),$A0FFD070,'vector scale 1.6 alpha',taLeft,toAddBaseline or toWithShadow);
  txt.Write(txt.ScaleFont(rasterFont,1.1),innerR.Left+S(12),innerR.Top+S(122),$70FFFFFF,'raster alpha 0.44',taLeft,toAddBaseline);

  // 5) Runtime and FT status
  r:=GridCell(area,2,1,3,2,S(BLOCK_GAP));
  DrawBlock(r,'Runtime && FreeType Status',innerR);
  if vectorFontLoaded then srcV:='loaded' else srcV:='fallback';
  if rasterFontLoaded then srcR:='loaded' else srcR:='fallback';
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(28),$FFE5EDF7,'Raster font: '+rasterFontName+' ('+srcR+')',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(50),$FFE5EDF7,'Vector font: '+vectorFontName+' ('+srcV+')',taLeft,toAddBaseline);
  {$IFNDEF FREETYPE}
    r:=Rect(innerR.Left+S(10),innerR.Top+S(74),innerR.Right-S(10),innerR.Top+S(130));
    draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$C0402040,S(8));
    draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,S(8),$FFFF8080);
    txt.Write(bodyFont,r.Left+S(10),r.Top+S(12),$FFFF8080,'ALERT: FREETYPE is NOT compiled in this build!',taLeft,toAddBaseline or toWithShadow);
    txt.Write(bodyFont,r.Left+S(10),r.Top+S(34),$FFFFB0B0,'Vector text path is unavailable.',taLeft,toAddBaseline);
  {$ELSE}
    txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(82),$FF9DE0B0,'FreeType support: compiled',taLeft,toAddBaseline);
  {$ENDIF}
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Bottom-S(54),$FFE5EDF7,UTF8.Format('DPI=%d scale=%.2f',[window.surface.dpi,uiScale]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Bottom-S(32),$FFE5EDF7,UTF8.Format('FPS=%.1f smooth=%.1f',[window.timings.fps,window.timings.smoothFps]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Bottom-S(10),$FFE5EDF7,UTF8.Format('frameDelta=%.3fms',[window.frameDeltaMs]),taLeft,toAddBaseline);
end;

procedure TMainScene.DrawWriteFamily(const contentRect:TRect);
var
  area,r,innerR:TRect;
  boundaryX,anchorX:integer;
  wst:String32;
  vfLabel:string;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));

  r:=GridCell(area,0,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'txt.Write(String8)',innerR);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(24),$FFECE8A8,'ASCII + UTF8 path',taLeft,toAddBaseline);
  txt.Write(rasterFont,innerR.Left+S(10),innerR.Top+S(52),$FFDCEBFF,'Raster(Default): Water Elemental',taLeft,toAddBaseline);
  if vectorFontLoaded then
    vfLabel:='Vector(TTF): Water Elemental'
  else
    vfLabel:='Vector(TTF): fallback to raster';
  txt.Write(vectorFont,innerR.Left+S(10),innerR.Top+S(80),$FFDCEBFF,vfLabel,taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'txt.WriteW(String32)',innerR);
  wst:=Str32(SampleWide);
  txt.WriteW(bodyFont,innerR.Left+S(10),innerR.Top+S(24),$FFECE8A8,Str32('Wide/UCS4 path:'),taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+S(10),innerR.Top+S(56),$FFDCEBFF,wst,taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+S(10),innerR.Top+S(88),$FFDCEBFF,Str32('Engine text API supports mixed scripts.'),taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'txt.WriteR (right anchor)',innerR);
  boundaryX:=innerR.Right-S(12);
  anchorX:=boundaryX-1;
  draw.Line(boundaryX,innerR.Top+S(8),boundaryX,innerR.Bottom-S(8),$70FFFFFF);
  txt.WriteR(bodyFont,anchorX,innerR.Top+S(34),$FFE5EDF7,'R1: right-aligned',toAddBaseline);
  txt.WriteR(bodyFont,anchorX,innerR.Top+S(62),$FF90D8FF,'R2: text stays before the guide',toAddBaseline);
  txt.WriteR(bodyFont,anchorX,innerR.Top+S(90),$FFE8D8A0,'R3: useful for stats columns',toAddBaseline);

  r:=GridCell(area,1,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'txt.WriteC (center anchor)',innerR);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+S(8),(innerR.Left+innerR.Right) div 2,innerR.Bottom-S(8),$70FFFFFF);
  txt.WriteC(bodyFont,(innerR.Left+innerR.Right)*0.5,innerR.Top+S(34),$FFE5EDF7,'C1: centered line',toAddBaseline);
  txt.WriteC(bodyFont,(innerR.Left+innerR.Right)*0.5,innerR.Top+S(62),$FF90D8FF,'C2: stable anchor',toAddBaseline);
  txt.WriteC(bodyFont,(innerR.Left+innerR.Right)*0.5,innerR.Top+S(90),$FFE8D8A0,'C3: good for labels',toAddBaseline);
end;

procedure TMainScene.DrawAlignment(const contentRect:TRect);
var
  area,r,innerR:TRect;
  boundaryX,anchorX:integer;
  st:string;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));

  r:=GridCell(area,0,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'taLeft / taCenter / taRight',innerR);
  boundaryX:=innerR.Right-S(10);
  anchorX:=boundaryX-1;
  draw.Line(innerR.Left+S(10),innerR.Top+S(18),innerR.Right-S(10),innerR.Top+S(18),$50FFFFFF);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+S(18),(innerR.Left+innerR.Right) div 2,innerR.Bottom-S(10),$30FFFFFF);
  draw.Line(boundaryX,innerR.Top+S(18),boundaryX,innerR.Bottom-S(10),$50FFFFFF);
  st:='Boundary guide';
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(18),$FF90C0E8,st,taLeft,toAddBaseline);
  txt.Write(bodyFont,(innerR.Left+innerR.Right) div 2,innerR.Top+S(54),$FFE5EDF7,'taCenter',taCenter,toAddBaseline);
  txt.Write(bodyFont,anchorX,innerR.Top+S(90),$FFEBD6A2,'taRight',taRight,toAddBaseline);

  r:=GridCell(area,1,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'taJustify + targetWidth',innerR);
  draw.FillRect(innerR.Left+S(10),innerR.Top+S(10),innerR.Right-S(10),innerR.Bottom-S(10),$30223244);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,
    'Justify this simple and small text block for visual comparison.',
    taJustify,toAddBaseline,innerR.Right-innerR.Left-S(24));
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(84),$FF90C0E8,
    'Same area width used as targetWidth.',taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Baseline vs toAddBaseline',innerR);
  draw.Line(innerR.Left+S(10),innerR.Top+S(45),innerR.Right-S(10),innerR.Top+S(45),$80FFB070);
  draw.Line(innerR.Left+S(10),innerR.Top+S(92),innerR.Right-S(10),innerR.Top+S(92),$8060D0FF);
  txt.Write(bodyFont,innerR.Left+S(14),innerR.Top+S(45),$FFE5EDF7,'Baseline Y (no flag)',taLeft,0);
  txt.Write(bodyFont,innerR.Left+S(14),innerR.Top+S(92),$FFE5EDF7,'Top Y (toAddBaseline)',taLeft,toAddBaseline);

  r:=GridCell(area,1,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Multiline with #13#10',innerR);
  st:='Line A'#13#10'Line B'#13#10'Line C';
  txt.Write(bodyFont,innerR.Left+S(14),innerR.Top+S(36),$FFE5EDF7,st,taLeft,toAddBaseline);
  draw.Rect(innerR.Left+S(10),innerR.Top+S(10),innerR.Right-S(10),innerR.Bottom-S(10),$FF4D6684);
end;

procedure TMainScene.DrawStyles(const contentRect:TRect);
var
  area,r,innerR:TRect;
  fBold,fItalic,fUnderline:TFontHandle;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));

  r:=GridCell(area,0,0,3,2,S(BLOCK_GAP));
  DrawBlock(r,'toBold / toItalic / toUnderline',innerR);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(32),$FFE5EDF7,'Normal',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(58),$FFE5EDF7,'Bold',taLeft,toAddBaseline or toBold);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(84),$FFE5EDF7,'Italic',taLeft,toAddBaseline or toItalic);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(110),$FFE5EDF7,'Underline',taLeft,toAddBaseline or toUnderline);

  r:=GridCell(area,1,0,3,2,S(BLOCK_GAP));
  DrawBlock(r,'toWithShadow / toLetterSpacing',innerR);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(34),$FFF0E8B0,'Shadowed label',taLeft,toAddBaseline or toWithShadow);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(70),$FFE5EDF7,'Letter spacing ON',taLeft,toAddBaseline or toLetterSpacing);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(96),$FFE5EDF7,'Letter spacing OFF',taLeft,toAddBaseline);

  r:=GridCell(area,2,0,3,2,S(BLOCK_GAP));
  DrawBlock(r,'toNoHinting / toAutoHinting',innerR);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(34),$FFE5EDF7,'Default hinting',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(62),$FFE5EDF7,'No hinting',taLeft,toAddBaseline or toNoHinting);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(90),$FFE5EDF7,'Auto hinting',taLeft,toAddBaseline or toAutoHinting);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(118),$FFE5EDF7,'Auto+Italic',taLeft,toAddBaseline or toAutoHinting or toItalic);

  r:=GridCell(area,0,1,3,2,S(BLOCK_GAP));
  DrawBlock(r,'GetFont flags (fsBold/fsItalic/fsUnderline)',innerR);
  fBold:=txt.GetFont(rasterFontName,9,fsBold);
  fItalic:=txt.GetFont(rasterFontName,9,fsItalic);
  fUnderline:=txt.GetFont(rasterFontName,9,fsUnderline);
  txt.Write(fBold,innerR.Left+S(10),innerR.Top+S(34),$FFE5EDF7,'Font style: bold',taLeft,toAddBaseline);
  txt.Write(fItalic,innerR.Left+S(10),innerR.Top+S(62),$FFE5EDF7,'Font style: italic',taLeft,toAddBaseline);
  txt.Write(fUnderline,innerR.Left+S(10),innerR.Top+S(90),$FFE5EDF7,'Font style: underline',taLeft,toAddBaseline);

  r:=GridCell(area,1,1,3,2,S(BLOCK_GAP));
  DrawBlock(r,'ScaleFont()',innerR);
  txt.Write(txt.ScaleFont(bodyFont,0.8),innerR.Left+S(10),innerR.Top+S(34),$FFE5EDF7,'Scale 0.8',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.0),innerR.Left+S(10),innerR.Top+S(62),$FFE5EDF7,'Scale 1.0',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.35),innerR.Left+S(10),innerR.Top+S(94),$FFE5EDF7,'Scale 1.35',taLeft,toAddBaseline);

  r:=GridCell(area,2,1,3,2,S(BLOCK_GAP));
  DrawBlock(r,'SetFontOption() raster/vector',innerR);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(32),$FFE5EDF7,'Down/Upscale factors forced to 1.0',taLeft,toAddBaseline);
  txt.Write(rasterFont,innerR.Left+S(10),innerR.Top+S(58),$FFE5EDF7,'Raster sample',taLeft,toAddBaseline);
  txt.Write(vectorFont,innerR.Left+S(10),innerR.Top+S(82),$FFE5EDF7,'Vector sample (or fallback)',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(10),innerR.Top+S(108),$FF90C0E8,'Helps stable glyph raster selection',taLeft,toAddBaseline);
end;

procedure TMainScene.DrawMeasureLinks(const contentRect:TRect);
var
  area,r,innerR,lr,linkR:TRect;
  query:cardinal;
  i:integer;
  measureStr:String8;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));

  r:=GridCell(area,0,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'toMeasure + MeasuredRect()',innerR);
  query:=Bits.PackW(window.mousePos.x,window.mousePos.y);
  txt.ClearLink;
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,'Measure {b}complex{/b} text and mark char edges.',taLeft,
    toAddBaseline or toMeasure or toComplexText);
  for i:=0 to txt.MeasuredCnt do begin
    lr:=txt.MeasuredRect(i);
    draw.Line(lr.Left,lr.Bottom,lr.Left,lr.Bottom+S(6),$90FFFFFF);
  end;
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(66),$FF90C0E8,'MeasuredCnt='+Conv.ToStr(txt.MeasuredCnt),taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Hyperlinks + query point',innerR);
  txt.ClearLink;
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,
    'Text with {L=1}link one{/L}, {L=2}link two{/L}, {L=3}link three{/L}.',
    taLeft,toAddBaseline or toComplexText or toMeasure,0,query);
  lastLink:=txt.Link;
  linkR:=txt.LinkRect; // keep in a dedicated var for the hover readout below
  if lastLink>0 then begin
    draw.Rect(linkR.Left,linkR.Top,linkR.Right,linkR.Bottom,$FFD8F090);
    txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(66),$FFF0E8A0,'Hovered link id='+Conv.ToStr(lastLink),taLeft,toAddBaseline);
  end else
    txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(66),$FF90C0E8,'Hovered link id=0',taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+S(12),innerR.Top+S(92),$FFD8E7F8,
    UTF8.Format('mouse = %d, %d',[window.mousePos.x,window.mousePos.y]),taLeft,toAddBaseline);
  if lastLink>0 then
    txt.Write(monoFont,innerR.Left+S(12),innerR.Top+S(114),$FFF0E8A0,
      UTF8.Format('link rect [%d,%d .. %d,%d]',[linkR.Left,linkR.Top,linkR.Right,linkR.Bottom]),taLeft,toAddBaseline)
  else
    txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(114),$FF90C0E8,'hover a link in the line above',taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Measure() bounding rect (multi-line + SML)',innerR);
  txt.ClearLink;
  // Measure() returns the full extent of a multi-line, SML-marked-up string in one
  // call (no manual line splitting). The rect is relative to the pen point and is
  // produced by the same layout path that draws the text, so it tracks it exactly.
  measureStr:='Multi-line {b}bold{/b} and'#10'{C=8cd0ff}colored{/C} text,'#10'measured as one {i}rect{/i}.';
  lr:=txt.Measure(bodyFont,measureStr,toComplexText);
  draw.Rect(innerR.Left+S(16)+lr.Left-S(2),innerR.Top+S(44)+lr.Top-S(2),
            innerR.Left+S(16)+lr.Right+S(2),innerR.Top+S(44)+lr.Bottom+S(2),$FF80C0F0);
  txt.Write(bodyFont,innerR.Left+S(16),innerR.Top+S(44),$FFE5EDF7,measureStr,taLeft,toComplexText);

  r:=GridCell(area,1,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'SML alignment modes',innerR);
  draw.FillRect(innerR.Left+S(10),innerR.Top+S(18),innerR.Right-S(10),innerR.Bottom-S(10),$24223240);
  draw.Line(innerR.Left+S(12),innerR.Top+S(26),innerR.Right-S(12),innerR.Top+S(26),$30FFFFFF);
  draw.Line(innerR.Left+S(12),innerR.Top+S(58),innerR.Right-S(12),innerR.Top+S(58),$30FFFFFF);
  draw.Line(innerR.Left+S(12),innerR.Top+S(90),innerR.Right-S(12),innerR.Top+S(90),$30FFFFFF);
  draw.Line(innerR.Left+S(12),innerR.Top+S(122),innerR.Right-S(12),innerR.Top+S(122),$30FFFFFF);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(24),$FFE5EDF7,
    'Same SML string rendered with different alignments and a fixed width.',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(46),$FF90C0E8,
    'Left:  {b}measure{/b} this line of text.',taLeft,toAddBaseline or toComplexText,innerR.Right-innerR.Left-S(24));
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(78),$FF90C0E8,
    'Center: {b}measure{/b} this line of text.',taCenter,toAddBaseline or toComplexText,innerR.Right-innerR.Left-S(24));
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(110),$FFEBD6A2,
    'Right: {b}measure{/b} this line of text.',taRight,toAddBaseline or toComplexText,innerR.Right-innerR.Left-S(24));
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(142),$FFF0E8A0,
    'Justify: {b}measure{/b} this line of text for a wider row.',taJustify,toAddBaseline or toComplexText,innerR.Right-innerR.Left-S(24));
end;

procedure TMainScene.DrawBlockAndCache(const contentRect:TRect);
var
  area,r,innerR:TRect;
  leftR,rightR:TRect;
  i,y,splitX,row1,row2:integer;
  scale:single;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));

  splitX:=area.Left+(area.Right-area.Left)*44 div 100;
  leftR:=Rect(area.Left,area.Top,splitX-S(BLOCK_GAP) div 2,area.Bottom);
  rightR:=Rect(splitX+S(BLOCK_GAP) div 2,area.Top,area.Right,area.Bottom);
  row1:=leftR.Top+(leftR.Bottom-leftR.Top)*42 div 100;
  row2:=leftR.Top+(leftR.Bottom-leftR.Top)*81 div 100;

  r:=Rect(leftR.Left,leftR.Top,leftR.Right,row1-S(BLOCK_GAP) div 2);
  DrawBlock(r,'BeginBlock/EndBlock batch',innerR);
  y:=innerR.Top+S(26);
  for i:=0 to 8 do begin
    txt.Write(bodyFont,innerR.Left+S(12),y,$FFE5EDF7,'Line '+Conv.ToStr(i+1)+' in shared text block.',taLeft,toAddBaseline);
    inc(y,S(18));
  end;
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Bottom-S(10),$FF90C0E8,'All these writes are batched in current frame.',taLeft,toAddBaseline);

  r:=rightR;
  DrawBlock(r,'MAGIC_TEXTCACHE preview',innerR);
  draw.FillRect(innerR.Left+S(10),innerR.Top+S(10),innerR.Right-S(10),innerR.Bottom-S(10),$FFFFFFFF);
  txt.Write(MAGIC_TEXTCACHE,innerR.Left+S(10),innerR.Top+S(10),$FFFFFFFF,'',taLeft,0);
  draw.Rect(innerR.Left+S(10),innerR.Top+S(10),innerR.Right-S(10),innerR.Bottom-S(10),$FF4D6684);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Bottom-S(10),$FF1C2430,'Glyph cache atlas snapshot',taLeft,toAddBaseline);

  r:=Rect(leftR.Left,row1+S(BLOCK_GAP) div 2,leftR.Right,row2-S(BLOCK_GAP) div 2);
  DrawBlock(r,'Temporary glyph cache',innerR);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(24),$FFE5EDF7,
    'toDontCache keeps animated glyphs out of the main atlas.',taLeft,toAddBaseline);
  for i:=0 to 17 do begin
    scale:=0.78+0.025*((window.frameNum+i*7) mod 24);
    txt.Write(txt.ScaleFont(vectorFont,scale),innerR.Left+S(12)+(i mod 3)*S(112),
      innerR.Top+S(58)+(i div 3)*S(24),$FFDDE8F8,'temp '+Conv.ToStr(i+1),
      taLeft,toAddBaseline or toDontCache);
  end;
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Bottom-S(12),$FF90C0E8,
    'Changing sizes use the side cache; stable text stays in the main cache.',taLeft,toAddBaseline);

  r:=Rect(leftR.Left,row2+S(BLOCK_GAP) div 2,leftR.Right,leftR.Bottom);
  DrawBlock(r,'Status',innerR);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(30),$FFE5EDF7,
    UTF8.Format('frame=%d  fps=%.1f',[window.frameNum,window.timings.smoothFps]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(54),$FFE5EDF7,
    UTF8.Format('frameStartMs=%.3f  frameDeltaMs=%.3f',[window.frameStartMs,window.frameDeltaMs]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(78),$FF90C0E8,'Cache diagnostics from old EngineTest moved here.',taLeft,toAddBaseline);
end;

procedure TMainScene.DrawUnicodeComplex(const contentRect:TRect);
var
  area,r,innerR:TRect;
  wideLine:String32;
  st:string;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));
  wideLine:=Str32(SampleWide);

  r:=GridCell(area,0,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Complex markup (toComplexText)',innerR);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,
    '{u}This{!u} {I}is {!I}an {C=FF90E0C0}{B}example{/B/C} text',
    taLeft,toAddBaseline or toComplexText);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(62),$FFE5EDF7,
    'Inline {L=11}link{/L} + {C=FFE0A080}color tag{/C}.',
    taLeft,toAddBaseline or toComplexText);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(90),$FF90C0E8,
    'Markup parser behavior is inherited from EngineTest coverage.',taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'WriteW + mixed scripts',innerR);
  txt.WriteW(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,wideLine,taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+S(12),innerR.Top+S(62),$FFE5EDF7,Str32('Symbols: [ ] { } / \ * + - ='),taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+S(12),innerR.Top+S(90),$FF90C0E8,Str32('String32 path keeps Unicode codepoints explicit.'),taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Multiline + alignment',innerR);
  st:='Alpha'#13#10'Beta'#13#10'Gamma';
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+S(10),(innerR.Left+innerR.Right) div 2,innerR.Bottom-S(10),$50FFFFFF);
  txt.Write(bodyFont,(innerR.Left+innerR.Right) div 2,innerR.Top+S(40),$FFE5EDF7,st,taCenter,toAddBaseline);
  txt.Write(bodyFont,(innerR.Left+innerR.Right) div 2,innerR.Top+S(110),$FF90C0E8,'Center anchor for multiline',taCenter,toAddBaseline);

  r:=GridCell(area,1,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Translation control',innerR);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,'Default call (may use dictionary if configured)',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(62),$FFE5EDF7,'Explicit toDontTranslate',taLeft,toAddBaseline or toDontTranslate);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(90),$FF90C0E8,'Demo keeps toDontTranslate for predictable test output.',taLeft,toAddBaseline);
end;

procedure TMainScene.DrawMetrics(const contentRect:TRect);
var
  area,r,innerR:TRect;
  w1,w2,h:integer;
  wr,wv:integer;
  s8:string;
  s32:String32;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));
  s8:='1) AV Privet - Hello!';
  s32:=Str32(SampleWide);
  w1:=txt.Width(bodyFont,s8);
  w2:=txt.WidthW(bodyFont,s32);
  h:=txt.Height(bodyFont);

  r:=GridCell(area,0,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Width / WidthW / Height',innerR);
  draw.FillRect(innerR.Left+S(12),innerR.Top+S(36),innerR.Left+S(12)+w1,innerR.Top+S(44),$FF7AA0D8);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,s8,taLeft,toAddBaseline);
  draw.FillRect(innerR.Left+S(12),innerR.Top+S(84),innerR.Left+S(12)+w2,innerR.Top+S(92),$FFE09060);
  txt.WriteW(bodyFont,innerR.Left+S(12),innerR.Top+S(82),$FFE5EDF7,s32,taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(122),$FF90C0E8,
    UTF8.Format('Width=%d WidthW=%d Height=%d',[w1,w2,h]),taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,S(BLOCK_GAP));
  DrawBlock(r,'ScaleFont visual check',innerR);
  txt.Write(txt.ScaleFont(bodyFont,0.75),innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,'scale=0.75',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.0),innerR.Left+S(12),innerR.Top+S(62),$FFE5EDF7,'scale=1.00',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.4),innerR.Left+S(12),innerR.Top+S(96),$FFE5EDF7,'scale=1.40',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.9),innerR.Left+S(12),innerR.Top+S(138),$FFE5EDF7,'scale=1.90',taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'SetFontOption stress',innerR);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(34),$FFE5EDF7,'foDownscaleFactor=1.0',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(60),$FFE5EDF7,'foUpscaleFactor=1.0',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(86),$FF90C0E8,'Mirrors important EngineTest setup.',taLeft,toAddBaseline);

  r:=GridCell(area,1,1,2,2,S(BLOCK_GAP));
  DrawBlock(r,'Diagnostic text (raster/vector)',innerR);
  wr:=txt.Width(rasterFont,'Sample');
  wv:=txt.Width(vectorFont,'Sample');
  txt.Write(monoFont,innerR.Left+S(12),innerR.Top+S(34),$FFD8E7F8,UTF8.Format('menuWidth=%d itemH=%d',[menuWidth,menuItemHeight]),taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+S(12),innerR.Top+S(56),$FFD8E7F8,UTF8.Format('window=%dx%d render=%dx%d',
    [window.clientWidth,window.clientHeight,window.canvasWidth,window.canvasHeight]),taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+S(12),innerR.Top+S(78),$FFD8E7F8,UTF8.Format('rasterW=%d vectorW=%d',[wr,wv]),taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+S(12),innerR.Top+S(100),$FFD8E7F8,UTF8.Format('raster=%u vector=%u',[rasterFont,vectorFont]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+S(12),innerR.Top+S(126),$FF90C0E8,'This screen doubles as a quick regression checklist.',taLeft,toAddBaseline);
end;

procedure TMainScene.DrawEffects(const contentRect:TRect);
var
  area,r,innerR:TRect;
  bigFont:TFontHandle;
  glow,outline1,outline2,outline3,halo,shadow:TTextEffectLayer;
  x,y,i:integer;
  alpha:cardinal;
  t,k:double;
begin
  area:=Rect(contentRect.Left+S(BLOCK_GAP),contentRect.Top+screenTopOffset,contentRect.Right-S(BLOCK_GAP),contentRect.Bottom-S(BLOCK_GAP));
  bigFont:=txt.ScaleFont(titleFont,1.5);
  // effect sizes are in render target pixels: scale them as the layout
  k:=uiScale;
  glow:=TTextEffectLayer.Glow($C0FFFFFF,12*k,1*k);
  outline1:=TTextEffectLayer.Outline($FF000000,1*k);
  outline2:=TTextEffectLayer.Outline($FF000000,2*k);
  outline3:=TTextEffectLayer.Outline($FF000000,3*k);
  halo:=TTextEffectLayer.Glow($FFFFFFFF,6*k,1.5*k);
  shadow:=TTextEffectLayer.Shadow($A0000000,3*k,3*k,5*k);

  r:=GridCell(area,0,0,2,3,S(BLOCK_GAP));
  DrawBlock(r,'Glow($C0FFFFFF, blur 12, spread 1)',innerR);
  DrawTextFX(bigFont,innerR.Left+S(20),innerR.Top+S(60),$FF000000,'Version 1.2.3',taLeft,[glow],toAddBaseline);
  DrawTextFX(bodyFont,innerR.Left+S(20),innerR.Top+S(120),$FF203040,'Small text with the same glow',taLeft,[glow],toAddBaseline);

  r:=GridCell(area,1,0,2,3,S(BLOCK_GAP));
  DrawBlock(r,'Outline(black, width 1 / 2 / 3)',innerR);
  x:=innerR.Left+S(20);
  DrawTextFX(bigFont,x,innerR.Top+S(60),$FFFFE080,'12',taLeft,[outline1],toAddBaseline);
  DrawTextFX(bigFont,x+S(110),innerR.Top+S(60),$FFFFE080,'34',taLeft,[outline2],toAddBaseline);
  DrawTextFX(bigFont,x+S(220),innerR.Top+S(60),$FFFFE080,'56',taLeft,[outline3],toAddBaseline);
  DrawTextFX(bodyFont,x,innerR.Top+S(120),$FFFFFFFF,'Two layers: glow + outline',taLeft,[glow,outline2],toAddBaseline);

  r:=GridCell(area,0,1,2,3,S(BLOCK_GAP));
  DrawBlock(r,'Light background: Glow(white, blur 6, spread 1.5)',innerR);
  draw.FillRect(innerR.Left,innerR.Top+S(8),innerR.Right,innerR.Bottom,$FFC8BCA4);
  DrawTextFX(bigFont,innerR.Left+S(20),innerR.Top+S(62),$FF000000,'Halo on parchment',taLeft,[halo],toAddBaseline);
  DrawTextFX(bodyFont,innerR.Left+S(20),innerR.Top+S(120),$FF402010,'Shadow(offset 3,3, blur 5)',taLeft,[shadow],toAddBaseline);

  r:=GridCell(area,1,1,2,3,S(BLOCK_GAP));
  DrawBlock(r,'Anchor check: FX text overdrawn by plain red txt.Write',innerR);
  x:=(innerR.Left+innerR.Right) div 2;
  draw.Line(x,innerR.Top+S(10),x,innerR.Bottom-S(4),$50FFFFFF);
  y:=innerR.Top+S(44);
  for i:=0 to 2 do begin
    DrawTextFX(bodyFont,x,y,$FFFFFFFF,'Anchor',TTextAlignment(i),[outline2],toAddBaseline);
    txt.Write(bodyFont,x,y,$C0FF4040,'Anchor',TTextAlignment(i),toAddBaseline);
    inc(y,S(34));
  end;

  r:=GridCell(area,0,2,2,3,S(BLOCK_GAP));
  DrawBlock(r,'Multiline + markup (toComplexText)',innerR);
  DrawTextFX(bodyFont,innerR.Left+S(20),innerR.Top+S(40),$FFE5EDF7,
    'Line one: {C=FF90E0C0}{B}bold green{/B/C}'#13#10'Line two: {I}italic{!I} and {u}underline{!u}',
    taLeft,[glow,outline1],toAddBaseline or toComplexText);

  r:=GridCell(area,1,2,2,3,S(BLOCK_GAP));
  DrawBlock(r,'Alpha fade: modulated at draw time, baked once',innerR);
  t:=window.frameStartMs/1000;
  alpha:=round(127.5+127.5*sin(t*2));
  DrawTextFX(bigFont,innerR.Left+S(20),innerR.Top+S(62),(alpha shl 24)+$FFFFFF,'Fading glow',taLeft,[glow,outline1],toAddBaseline);
end;

procedure TMainScene.Render;
var
  area,menuRect,contentRect:TRect;
begin
  UpdateDeltaStats;

  if game.screenScale<>uiScale then begin // the DPI changed
    UpdateMetrics;
    RebuildFonts;
  end;

  area:=GetArea;
  menuRect:=Rect(area.Left,area.Top,menuWidth,area.Bottom);
  contentRect:=Rect(menuWidth+contentPadding,contentPadding,area.Right-contentPadding,area.Bottom-contentPadding);

  draw.FillRect(area.Left,area.Top,area.Right,area.Bottom,$FF111821);
  draw.FillGradRect(area.Left,area.Top,area.Right,area.Bottom,$FF182434,$FF111821,true);
  draw.Rect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Bottom,$FF3D5067);

  txt.BeginBlock(baseOpt);
  try
    DrawMenu(menuRect);
    DrawScreenTitle(contentRect,SCREEN_TITLES[currentScreen],SCREEN_HINTS[currentScreen]);
    case currentScreen of
      0:DrawOverview(contentRect);
      1:DrawWriteFamily(contentRect);
      2:DrawAlignment(contentRect);
      3:DrawStyles(contentRect);
      4:DrawMeasureLinks(contentRect);
      5:DrawBlockAndCache(contentRect);
      6:DrawUnicodeComplex(contentRect);
      7:DrawMetrics(contentRect);
      8:DrawEffects(contentRect);
    end;
  finally
    txt.EndBlock;
  end;

  DrawOverlayStats;
end;

end.
