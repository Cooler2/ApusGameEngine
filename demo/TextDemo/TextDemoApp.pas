// Text rendering showcase/demo for Apus Engine
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
  Math,
  Apus.Core,
  Apus.Conv,
  Apus.Strings,
  Apus.Engine.Keys,
  Apus.Engine.Types,
  Apus.Engine.Scene,
  Apus.Engine.TextDraw;

type
  TMainScene=class(TGameScene)
    titleFont,menuFont,hintFont,bodyFont,monoFont:TFontHandle;
    vectorFont,rasterFont:TFontHandle;
    currentScreen:integer;
    layoutScale:single;
    menuWidth,menuTop,menuItemHeight,contentPadding,screenTopOffset:integer;
    lastDPI:integer;
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
    procedure Render; override;
    function GetArea:TRect; override;
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
  end;

const
  SCREEN_COUNT=8;
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
    'Metrics && Scale'
  );

  SCREEN_HINTS:array[0..SCREEN_COUNT-1] of string=(
    'Coverage map + controls + runtime info',
    'txt.Write / WriteW / WriteR / WriteC',
    'left/center/right/justify and top-vs-baseline',
    'bold/italic/underline/shadow/hinting/spacing',
    'toMeasure, hyperlinks, query point and SML align modes',
    'BeginBlock/EndBlock, toDontCache and MAGIC_TEXTCACHE preview',
    'multiline Unicode + complex markup + align',
    'Width/WidthW/Height, ScaleFont, font options'
  );

var
  sceneMain:TMainScene;

function LMBClicked:boolean;
begin
  result:=Bits.HasAll(window.mouseButtons,mbLeft) and not Bits.HasAll(window.oldMouseButtons,mbLeft);
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

constructor TMainApp.Create;
begin
  inherited;
  gameTitle:='Apus Engine: TextDemo';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  windowWidth:=1620;
  windowHeight:=920;
  windowSizeable:=false;
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
  currentScreen:=0;
  lastDPI:=0;
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
  y:=window.canvasHeight-round(6*layoutScale);
  st:=Format('frameDelta: %d/%d ms',[window.frameDeltaMs,MaxRecentDeltaMs]);
  txt.Write(hintFont,12,y,$FFE6F0FA,st,taLeft,toWithShadow or toDontTranslate);
end;

procedure TMainScene.TryLoadDemoFonts;
const
  TTF_PATHS:array[0..4] of string=(
    'res\arial.ttf',
    '..\EngineTest\res\arial.ttf',
    'demo\EngineTest\res\arial.ttf',
    '..\..\demo\EngineTest\res\arial.ttf',
    '..\..\..\demo\EngineTest\res\arial.ttf'
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

procedure TMainScene.UpdateMetrics;
begin
  layoutScale:=window.surface.dpi/96;
  if layoutScale<1 then layoutScale:=1;
  menuWidth:=MENU_WIDTH+round((layoutScale-1)*120);
  menuWidth:=ClampI(menuWidth,360,window.canvasWidth div 2);
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
  fs:=window.surface.dpi/96;
  if fs<1 then fs:=1;
  titleFont:=txt.GetFont('Default',F(12));
  menuFont:=txt.GetFont('Default',F(10));
  hintFont:=txt.GetFont('Default',F(8));
  rasterFont:=txt.GetFont(rasterFontName,F(8),fsStrictMatch);
  if rasterFont=0 then rasterFont:=txt.GetFont('Default',F(8));
  vectorFont:=0;
  if vectorFontLoaded then
    vectorFont:=txt.GetFont(vectorFontName,F(8),fsStrictMatch);
  if vectorFont=0 then vectorFont:=rasterFont;
  bodyFont:=rasterFont;
  monoFont:=txt.GetFont('Default',F(7));
  txt.SetFontOption(rasterFont,foDownscaleFactor,1.0);
  txt.SetFontOption(rasterFont,foUpscaleFactor,1.0);
  if vectorFontLoaded then
    txt.SetFontOption(vectorFont,foGlobalScale,1.0);
end;

procedure TMainScene.HandleInput;
const
  F_SCANS:array[0..7] of integer=(59,60,61,62,63,64,65,66); // F1..F8
  D_SCANS:array[0..7] of integer=(2,3,4,5,6,7,8,9); // 1..8
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

  txt.Write(titleFont,20,28,$FFE8F0FA,'TextDemo Screens',taLeft,toAddBaseline or toWithShadow);
  txt.Write(hintFont,20,52,$FFA4B7CE,'Mouse click or keys [F1..F8] / [1..8]',taLeft,toAddBaseline);

  for i:=0 to SCREEN_COUNT-1 do begin
    top:=menuTop+i*menuItemHeight;
    bottom:=top+menuItemHeight-6;
    r:=Rect(menuRect.Left+12,top,menuRect.Right-12,bottom);
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

    draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,bg,8);
    draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,8,border);
    txt.Write(menuFont,r.Left+12,r.Top+17,txtCol,Conv.ToStr(i+1)+'. '+SCREEN_TITLES[i],taLeft,toAddBaseline);
  end;
end;

procedure TMainScene.DrawScreenTitle(const contentRect:TRect;const title,subtitle:string);
begin
  draw.FillRect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF1F2A3A);
  draw.Rect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF3D5067);
  txt.Write(titleFont,contentRect.Left+14,contentRect.Top+16,$FFEAF2FC,title,taLeft,toAddBaseline or toWithShadow);
  txt.Write(hintFont,contentRect.Left+14,contentRect.Top+44,$FFA8BDD5,subtitle,taLeft,toAddBaseline);
end;

procedure TMainScene.DrawTag(x,y:integer;const st:string;color:cardinal=$FFE6EEF8);
var
  h:integer;
begin
  h:=txt.Height(bodyFont);
  draw.FillRect(x-4,y-3,x+txt.Width(bodyFont,st)+4,y+h+3,$50202A38);
  txt.Write(bodyFont,x,y,color,st,taLeft,toAddBaseline or toWithShadow);
end;

procedure TMainScene.DrawBlock(const r:TRect;const title:string;out innerR:TRect);
begin
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF1C2836,BLOCK_RADIUS);
  draw.FillRect(r.Left+1,r.Top+1,r.Right-1,r.Top+BLOCK_TITLE_H,$28AACCFF);
  draw.Rect(r.Left,r.Top,r.Right,r.Bottom,$FF3D5270);
  draw.Line(r.Left+1,r.Top+BLOCK_TITLE_H,r.Right-1,r.Top+BLOCK_TITLE_H,$FF3D5270);
  txt.Write(bodyFont,r.Left+10,r.Top+6,$FFDDEEFF,title,taLeft,toAddBaseline or toWithShadow);
  innerR:=Rect(r.Left+8,r.Top+BLOCK_TITLE_H+6,r.Right-8,r.Bottom-8);
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
  area:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);

  // 0) Raster baseline/align
  r:=GridCell(area,0,0,3,2,BLOCK_GAP);
  DrawBlock(r,'Raster: Baseline && Align',innerR);
  leftX:=innerR.Left+12;
  rightX:=innerR.Right-12;
  anchorX:=rightX-1;
  draw.Line(leftX,innerR.Top+14,leftX,innerR.Bottom-24,$4060B080);
  draw.Line(rightX,innerR.Top+14,rightX,innerR.Bottom-24,$70FFFFFF);
  draw.Line(innerR.Left+10,innerR.Top+16,innerR.Right-10,innerR.Top+16,$50FFFFFF);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+16,(innerR.Left+innerR.Right) div 2,innerR.Bottom-24,$30FFFFFF);
  txt.Write(rasterFont,leftX,innerR.Top+16,$FFE5EDF7,'baseline (no top flag)',taLeft,0);
  txt.Write(rasterFont,leftX,innerR.Top+44,$FF9CD0FF,'top (toAddBaseline)',taLeft,toAddBaseline);
  txt.Write(rasterFont,(innerR.Left+innerR.Right) div 2,innerR.Top+76,$FFE5EDF7,'centered label',taCenter,toAddBaseline);
  txt.Write(rasterFont,anchorX,innerR.Top+104,$FFE6CFA0,'right label',taRight,toAddBaseline);
  txt.Write(monoFont,leftX,innerR.Bottom-8,$FF90C0E8,'bounds: [left, right), right line is exclusive',taLeft,toAddBaseline);

  // 1) Vector baseline/align
  r:=GridCell(area,1,0,3,2,BLOCK_GAP);
  DrawBlock(r,'Vector: Baseline && Align',innerR);
  leftX:=innerR.Left+12;
  rightX:=innerR.Right-12;
  anchorX:=rightX-1;
  draw.Line(leftX,innerR.Top+14,leftX,innerR.Bottom-24,$4060B080);
  draw.Line(rightX,innerR.Top+14,rightX,innerR.Bottom-24,$70FFFFFF);
  draw.Line(innerR.Left+10,innerR.Top+16,innerR.Right-10,innerR.Top+16,$50FFFFFF);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+16,(innerR.Left+innerR.Right) div 2,innerR.Bottom-24,$30FFFFFF);
  txt.Write(vectorFont,leftX,innerR.Top+16,$FFE5EDF7,'baseline (vector)',taLeft,0);
  txt.Write(vectorFont,leftX,innerR.Top+44,$FF9CD0FF,'top (toAddBaseline)',taLeft,toAddBaseline);
  txt.Write(vectorFont,(innerR.Left+innerR.Right) div 2,innerR.Top+76,$FFE5EDF7,'centered label',taCenter,toAddBaseline);
  txt.Write(vectorFont,anchorX,innerR.Top+104,$FFE6CFA0,'right label',taRight,toAddBaseline);
  txt.Write(monoFont,leftX,innerR.Bottom-8,$FF90C0E8,'bounds: [left, right), right line is exclusive',taLeft,toAddBaseline);

  // 2) Center proof with guides and symmetric lines
  r:=GridCell(area,2,0,3,2,BLOCK_GAP);
  DrawBlock(r,'Center Proof (Guides)',innerR);
  c:=(innerR.Left+innerR.Right) div 2;
  draw.FillRect(innerR.Left+20,innerR.Top+24,innerR.Right-20,innerR.Bottom-18,$24223240);
  draw.Line(c,innerR.Top+20,c,innerR.Bottom-12,$70A0D0FF);
  draw.Line(c-80,innerR.Top+20,c-80,innerR.Bottom-12,$4060B080);
  draw.Line(c+80,innerR.Top+20,c+80,innerR.Bottom-12,$4060B080);
  draw.Line(c-140,innerR.Top+20,c-140,innerR.Bottom-12,$30406080);
  draw.Line(c+140,innerR.Top+20,c+140,innerR.Bottom-12,$30406080);
  txt.Write(bodyFont,c,innerR.Top+46,$FFE5EDF7,'Centered text',taCenter,toAddBaseline or toWithShadow);
  txt.Write(bodyFont,c,innerR.Top+76,$FF90D0A8,'Equal offsets left/right',taCenter,toAddBaseline);
  txt.Write(bodyFont,c,innerR.Top+106,$FFE8CFA0,'Anchor = blue center line',taCenter,toAddBaseline);

  // 3) Multilingual samples (raster + vector)
  r:=GridCell(area,0,1,3,2,BLOCK_GAP);
  DrawBlock(r,'Multilingual Samples',innerR);
  txt.Write(rasterFont,innerR.Left+10,innerR.Top+28,$FFE5EDF7,'RU: Привет, мир!  EN: Hello world!',taLeft,toAddBaseline);
  txt.Write(rasterFont,innerR.Left+10,innerR.Top+52,$FFBEE8A8,'FR: Première écriture  DE: Grüße',taLeft,toAddBaseline);
  txt.Write(vectorFont,innerR.Left+10,innerR.Top+82,$FFE5EDF7,'RU: Привет, мир!  EN: Hello world!',taLeft,toAddBaseline);
  txt.Write(vectorFont,innerR.Left+10,innerR.Top+106,$FFBEE8A8,'FR: Première écriture  DE: Grüße',taLeft,toAddBaseline);

  // 4) Size / color / alpha
  r:=GridCell(area,1,1,3,2,BLOCK_GAP);
  DrawBlock(r,'Sizes, Colors, Alpha',innerR);
  draw.FillRect(innerR.Left+8,innerR.Top+18,innerR.Right-8,innerR.Bottom-8,$40243044);
  txt.Write(txt.ScaleFont(rasterFont,0.9),innerR.Left+12,innerR.Top+34,$FFE8EDF8,'raster scale 0.9',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(vectorFont,1.2),innerR.Left+12,innerR.Top+62,$FF80E0FF,'vector scale 1.2',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(vectorFont,1.6),innerR.Left+12,innerR.Top+96,$A0FFD070,'vector scale 1.6 alpha',taLeft,toAddBaseline or toWithShadow);
  txt.Write(txt.ScaleFont(rasterFont,1.1),innerR.Left+12,innerR.Top+122,$70FFFFFF,'raster alpha 0.44',taLeft,toAddBaseline);

  // 5) Runtime and FT status
  r:=GridCell(area,2,1,3,2,BLOCK_GAP);
  DrawBlock(r,'Runtime && FreeType Status',innerR);
  if vectorFontLoaded then srcV:='loaded' else srcV:='fallback';
  if rasterFontLoaded then srcR:='loaded' else srcR:='fallback';
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+28,$FFE5EDF7,'Raster font: '+rasterFontName+' ('+srcR+')',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+50,$FFE5EDF7,'Vector font: '+vectorFontName+' ('+srcV+')',taLeft,toAddBaseline);
  {$IFNDEF FREETYPE}
    r:=Rect(innerR.Left+10,innerR.Top+74,innerR.Right-10,innerR.Top+130);
    draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$C0402040,8);
    draw.RRect(r.Left,r.Top,r.Right,r.Bottom,1,8,$FFFF8080);
    txt.Write(bodyFont,r.Left+10,r.Top+12,$FFFF8080,'ALERT: FREETYPE is NOT compiled in this build!',taLeft,toAddBaseline or toWithShadow);
    txt.Write(bodyFont,r.Left+10,r.Top+34,$FFFFB0B0,'Vector text path is unavailable.',taLeft,toAddBaseline);
  {$ELSE}
    txt.Write(bodyFont,innerR.Left+10,innerR.Top+82,$FF9DE0B0,'FreeType support: compiled',taLeft,toAddBaseline);
  {$ENDIF}
  txt.Write(bodyFont,innerR.Left+10,innerR.Bottom-54,$FFE5EDF7,UTF8.Format('DPI=%d scale=%.2f',[window.surface.dpi,layoutScale]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+10,innerR.Bottom-32,$FFE5EDF7,UTF8.Format('FPS=%.1f smooth=%.1f',[window.FPS,window.smoothFPS]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+10,innerR.Bottom-10,$FFE5EDF7,UTF8.Format('frameDelta=%.3fms',[window.frameDeltaMs]),taLeft,toAddBaseline);
end;

procedure TMainScene.DrawWriteFamily(const contentRect:TRect);
var
  area,r,innerR:TRect;
  boundaryX,anchorX:integer;
  wst:String32;
  vfLabel:string;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);

  r:=GridCell(area,0,0,2,2,BLOCK_GAP);
  DrawBlock(r,'txt.Write(String8)',innerR);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+24,$FFECE8A8,'ASCII + UTF8 path',taLeft,toAddBaseline);
  txt.Write(rasterFont,innerR.Left+10,innerR.Top+52,$FFDCEBFF,'Raster(Default): Water Elemental',taLeft,toAddBaseline);
  if vectorFontLoaded then
    vfLabel:='Vector(TTF): Water Elemental'
  else
    vfLabel:='Vector(TTF): fallback to raster';
  txt.Write(vectorFont,innerR.Left+10,innerR.Top+80,$FFDCEBFF,vfLabel,taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,BLOCK_GAP);
  DrawBlock(r,'txt.WriteW(String32)',innerR);
  wst:=Str32(SampleWide);
  txt.WriteW(bodyFont,innerR.Left+10,innerR.Top+24,$FFECE8A8,Str32('Wide/UCS4 path:'),taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+10,innerR.Top+56,$FFDCEBFF,wst,taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+10,innerR.Top+88,$FFDCEBFF,Str32('Engine text API supports mixed scripts.'),taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,BLOCK_GAP);
  DrawBlock(r,'txt.WriteR (right anchor)',innerR);
  boundaryX:=innerR.Right-12;
  anchorX:=boundaryX-1;
  draw.Line(boundaryX,innerR.Top+8,boundaryX,innerR.Bottom-8,$70FFFFFF);
  txt.WriteR(bodyFont,anchorX,innerR.Top+34,$FFE5EDF7,'R1: right-aligned',toAddBaseline);
  txt.WriteR(bodyFont,anchorX,innerR.Top+62,$FF90D8FF,'R2: text stays before the guide',toAddBaseline);
  txt.WriteR(bodyFont,anchorX,innerR.Top+90,$FFE8D8A0,'R3: useful for stats columns',toAddBaseline);

  r:=GridCell(area,1,1,2,2,BLOCK_GAP);
  DrawBlock(r,'txt.WriteC (center anchor)',innerR);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+8,(innerR.Left+innerR.Right) div 2,innerR.Bottom-8,$70FFFFFF);
  txt.WriteC(bodyFont,(innerR.Left+innerR.Right)*0.5,innerR.Top+34,$FFE5EDF7,'C1: centered line',toAddBaseline);
  txt.WriteC(bodyFont,(innerR.Left+innerR.Right)*0.5,innerR.Top+62,$FF90D8FF,'C2: stable anchor',toAddBaseline);
  txt.WriteC(bodyFont,(innerR.Left+innerR.Right)*0.5,innerR.Top+90,$FFE8D8A0,'C3: good for labels',toAddBaseline);
end;

procedure TMainScene.DrawAlignment(const contentRect:TRect);
var
  area,r,innerR:TRect;
  boundaryX,anchorX:integer;
  st:string;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);

  r:=GridCell(area,0,0,2,2,BLOCK_GAP);
  DrawBlock(r,'taLeft / taCenter / taRight',innerR);
  boundaryX:=innerR.Right-10;
  anchorX:=boundaryX-1;
  draw.Line(innerR.Left+10,innerR.Top+18,innerR.Right-10,innerR.Top+18,$50FFFFFF);
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+18,(innerR.Left+innerR.Right) div 2,innerR.Bottom-10,$30FFFFFF);
  draw.Line(boundaryX,innerR.Top+18,boundaryX,innerR.Bottom-10,$50FFFFFF);
  st:='Boundary guide';
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+18,$FF90C0E8,st,taLeft,toAddBaseline);
  txt.Write(bodyFont,(innerR.Left+innerR.Right) div 2,innerR.Top+54,$FFE5EDF7,'taCenter',taCenter,toAddBaseline);
  txt.Write(bodyFont,anchorX,innerR.Top+90,$FFEBD6A2,'taRight',taRight,toAddBaseline);

  r:=GridCell(area,1,0,2,2,BLOCK_GAP);
  DrawBlock(r,'taJustify + targetWidth',innerR);
  draw.FillRect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,$30223244);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,
    'Justify this simple and small text block for visual comparison.',
    taJustify,toAddBaseline,innerR.Right-innerR.Left-24);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+84,$FF90C0E8,
    'Same area width used as targetWidth.',taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,BLOCK_GAP);
  DrawBlock(r,'Baseline vs toAddBaseline',innerR);
  draw.Line(innerR.Left+10,innerR.Top+45,innerR.Right-10,innerR.Top+45,$80FFB070);
  draw.Line(innerR.Left+10,innerR.Top+92,innerR.Right-10,innerR.Top+92,$8060D0FF);
  txt.Write(bodyFont,innerR.Left+14,innerR.Top+45,$FFE5EDF7,'Baseline Y (no flag)',taLeft,0);
  txt.Write(bodyFont,innerR.Left+14,innerR.Top+92,$FFE5EDF7,'Top Y (toAddBaseline)',taLeft,toAddBaseline);

  r:=GridCell(area,1,1,2,2,BLOCK_GAP);
  DrawBlock(r,'Multiline with #13#10',innerR);
  st:='Line A'#13#10'Line B'#13#10'Line C';
  txt.Write(bodyFont,innerR.Left+14,innerR.Top+36,$FFE5EDF7,st,taLeft,toAddBaseline);
  draw.Rect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,$FF4D6684);
end;

procedure TMainScene.DrawStyles(const contentRect:TRect);
var
  area,r,innerR:TRect;
  fBold,fItalic,fUnderline:TFontHandle;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);

  r:=GridCell(area,0,0,3,2,BLOCK_GAP);
  DrawBlock(r,'toBold / toItalic / toUnderline',innerR);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+32,$FFE5EDF7,'Normal',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+58,$FFE5EDF7,'Bold',taLeft,toAddBaseline or toBold);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+84,$FFE5EDF7,'Italic',taLeft,toAddBaseline or toItalic);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+110,$FFE5EDF7,'Underline',taLeft,toAddBaseline or toUnderline);

  r:=GridCell(area,1,0,3,2,BLOCK_GAP);
  DrawBlock(r,'toWithShadow / toLetterSpacing',innerR);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+34,$FFF0E8B0,'Shadowed label',taLeft,toAddBaseline or toWithShadow);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+70,$FFE5EDF7,'Letter spacing ON',taLeft,toAddBaseline or toLetterSpacing);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+96,$FFE5EDF7,'Letter spacing OFF',taLeft,toAddBaseline);

  r:=GridCell(area,2,0,3,2,BLOCK_GAP);
  DrawBlock(r,'toNoHinting / toAutoHinting',innerR);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+34,$FFE5EDF7,'Default hinting',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+62,$FFE5EDF7,'No hinting',taLeft,toAddBaseline or toNoHinting);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+90,$FFE5EDF7,'Auto hinting',taLeft,toAddBaseline or toAutoHinting);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+118,$FFE5EDF7,'Auto+Italic',taLeft,toAddBaseline or toAutoHinting or toItalic);

  r:=GridCell(area,0,1,3,2,BLOCK_GAP);
  DrawBlock(r,'GetFont flags (fsBold/fsItalic/fsUnderline)',innerR);
  fBold:=txt.GetFont(rasterFontName,9*layoutScale,fsBold);
  fItalic:=txt.GetFont(rasterFontName,9*layoutScale,fsItalic);
  fUnderline:=txt.GetFont(rasterFontName,9*layoutScale,fsUnderline);
  txt.Write(fBold,innerR.Left+10,innerR.Top+34,$FFE5EDF7,'Font style: bold',taLeft,toAddBaseline);
  txt.Write(fItalic,innerR.Left+10,innerR.Top+62,$FFE5EDF7,'Font style: italic',taLeft,toAddBaseline);
  txt.Write(fUnderline,innerR.Left+10,innerR.Top+90,$FFE5EDF7,'Font style: underline',taLeft,toAddBaseline);

  r:=GridCell(area,1,1,3,2,BLOCK_GAP);
  DrawBlock(r,'ScaleFont()',innerR);
  txt.Write(txt.ScaleFont(bodyFont,0.8),innerR.Left+10,innerR.Top+34,$FFE5EDF7,'Scale 0.8',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.0),innerR.Left+10,innerR.Top+62,$FFE5EDF7,'Scale 1.0',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.35),innerR.Left+10,innerR.Top+94,$FFE5EDF7,'Scale 1.35',taLeft,toAddBaseline);

  r:=GridCell(area,2,1,3,2,BLOCK_GAP);
  DrawBlock(r,'SetFontOption() raster/vector',innerR);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+32,$FFE5EDF7,'Down/Upscale factors forced to 1.0',taLeft,toAddBaseline);
  txt.Write(rasterFont,innerR.Left+10,innerR.Top+58,$FFE5EDF7,'Raster sample',taLeft,toAddBaseline);
  txt.Write(vectorFont,innerR.Left+10,innerR.Top+82,$FFE5EDF7,'Vector sample (or fallback)',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+10,innerR.Top+108,$FF90C0E8,'Helps stable glyph raster selection',taLeft,toAddBaseline);
end;

procedure TMainScene.DrawMeasureLinks(const contentRect:TRect);
var
  area,r,innerR,lr,linkR:TRect;
  query:cardinal;
  i:integer;
  measureStr:String8;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);

  r:=GridCell(area,0,0,2,2,BLOCK_GAP);
  DrawBlock(r,'toMeasure + MeasuredRect()',innerR);
  query:=Bits.PackW(window.mousePos.x,window.mousePos.y);
  txt.ClearLink;
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,'Measure {b}complex{/b} text and mark char edges.',taLeft,
    toAddBaseline or toMeasure or toComplexText);
  for i:=0 to txt.MeasuredCnt do begin
    lr:=txt.MeasuredRect(i);
    draw.Line(lr.Left,lr.Bottom,lr.Left,lr.Bottom+6,$90FFFFFF);
  end;
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+66,$FF90C0E8,'MeasuredCnt='+Conv.ToStr(txt.MeasuredCnt),taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,BLOCK_GAP);
  DrawBlock(r,'Hyperlinks + query point',innerR);
  txt.ClearLink;
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,
    'Text with {L=1}link one{/L}, {L=2}link two{/L}, {L=3}link three{/L}.',
    taLeft,toAddBaseline or toComplexText or toMeasure,0,query);
  lastLink:=txt.Link;
  linkR:=txt.LinkRect; // keep in a dedicated var for the hover readout below
  if lastLink>0 then begin
    draw.Rect(linkR.Left,linkR.Top,linkR.Right,linkR.Bottom,$FFD8F090);
    txt.Write(bodyFont,innerR.Left+12,innerR.Top+66,$FFF0E8A0,'Hovered link id='+Conv.ToStr(lastLink),taLeft,toAddBaseline);
  end else
    txt.Write(bodyFont,innerR.Left+12,innerR.Top+66,$FF90C0E8,'Hovered link id=0',taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+12,innerR.Top+92,$FFD8E7F8,
    UTF8.Format('mouse = %d, %d',[window.mousePos.x,window.mousePos.y]),taLeft,toAddBaseline);
  if lastLink>0 then
    txt.Write(monoFont,innerR.Left+12,innerR.Top+114,$FFF0E8A0,
      UTF8.Format('link rect [%d,%d .. %d,%d]',[linkR.Left,linkR.Top,linkR.Right,linkR.Bottom]),taLeft,toAddBaseline)
  else
    txt.Write(bodyFont,innerR.Left+12,innerR.Top+114,$FF90C0E8,'hover a link in the line above',taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,BLOCK_GAP);
  DrawBlock(r,'Measure() bounding rect (multi-line + SML)',innerR);
  txt.ClearLink;
  // Measure() returns the full extent of a multi-line, SML-marked-up string in one
  // call (no manual line splitting). The rect is relative to the pen point and is
  // produced by the same layout path that draws the text, so it tracks it exactly.
  measureStr:='Multi-line {b}bold{/b} and'#10'{C=8cd0ff}colored{/C} text,'#10'measured as one {i}rect{/i}.';
  lr:=txt.Measure(bodyFont,measureStr,toComplexText);
  draw.Rect(innerR.Left+16+lr.Left-2,innerR.Top+44+lr.Top-2,
            innerR.Left+16+lr.Right+2,innerR.Top+44+lr.Bottom+2,$FF80C0F0);
  txt.Write(bodyFont,innerR.Left+16,innerR.Top+44,$FFE5EDF7,measureStr,taLeft,toComplexText);

  r:=GridCell(area,1,1,2,2,BLOCK_GAP);
  DrawBlock(r,'SML alignment modes',innerR);
  draw.FillRect(innerR.Left+10,innerR.Top+18,innerR.Right-10,innerR.Bottom-10,$24223240);
  draw.Line(innerR.Left+12,innerR.Top+26,innerR.Right-12,innerR.Top+26,$30FFFFFF);
  draw.Line(innerR.Left+12,innerR.Top+58,innerR.Right-12,innerR.Top+58,$30FFFFFF);
  draw.Line(innerR.Left+12,innerR.Top+90,innerR.Right-12,innerR.Top+90,$30FFFFFF);
  draw.Line(innerR.Left+12,innerR.Top+122,innerR.Right-12,innerR.Top+122,$30FFFFFF);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+24,$FFE5EDF7,
    'Same SML string rendered with different alignments and a fixed width.',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+46,$FF90C0E8,
    'Left:  {b}measure{/b} this line of text.',taLeft,toAddBaseline or toComplexText,innerR.Right-innerR.Left-24);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+78,$FF90C0E8,
    'Center: {b}measure{/b} this line of text.',taCenter,toAddBaseline or toComplexText,innerR.Right-innerR.Left-24);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+110,$FFEBD6A2,
    'Right: {b}measure{/b} this line of text.',taRight,toAddBaseline or toComplexText,innerR.Right-innerR.Left-24);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+142,$FFF0E8A0,
    'Justify: {b}measure{/b} this line of text for a wider row.',taJustify,toAddBaseline or toComplexText,innerR.Right-innerR.Left-24);
end;

procedure TMainScene.DrawBlockAndCache(const contentRect:TRect);
var
  area,r,innerR:TRect;
  leftR,rightR:TRect;
  i,y,splitX,row1,row2:integer;
  scale:single;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);

  splitX:=area.Left+(area.Right-area.Left)*44 div 100;
  leftR:=Rect(area.Left,area.Top,splitX-BLOCK_GAP div 2,area.Bottom);
  rightR:=Rect(splitX+BLOCK_GAP div 2,area.Top,area.Right,area.Bottom);
  row1:=leftR.Top+(leftR.Bottom-leftR.Top)*42 div 100;
  row2:=leftR.Top+(leftR.Bottom-leftR.Top)*81 div 100;

  r:=Rect(leftR.Left,leftR.Top,leftR.Right,row1-BLOCK_GAP div 2);
  DrawBlock(r,'BeginBlock/EndBlock batch',innerR);
  y:=innerR.Top+26;
  for i:=0 to 8 do begin
    txt.Write(bodyFont,innerR.Left+12,y,$FFE5EDF7,'Line '+Conv.ToStr(i+1)+' in shared text block.',taLeft,toAddBaseline);
    inc(y,18);
  end;
  txt.Write(bodyFont,innerR.Left+12,innerR.Bottom-10,$FF90C0E8,'All these writes are batched in current frame.',taLeft,toAddBaseline);

  r:=rightR;
  DrawBlock(r,'MAGIC_TEXTCACHE preview',innerR);
  draw.FillRect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,$FFFFFFFF);
  txt.Write(MAGIC_TEXTCACHE,innerR.Left+10,innerR.Top+10,$FFFFFFFF,'',taLeft,0);
  draw.Rect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,$FF4D6684);
  txt.Write(bodyFont,innerR.Left+12,innerR.Bottom-10,$FF1C2430,'Glyph cache atlas snapshot',taLeft,toAddBaseline);

  r:=Rect(leftR.Left,row1+BLOCK_GAP div 2,leftR.Right,row2-BLOCK_GAP div 2);
  DrawBlock(r,'Temporary glyph cache',innerR);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+24,$FFE5EDF7,
    'toDontCache keeps animated glyphs out of the main atlas.',taLeft,toAddBaseline);
  for i:=0 to 17 do begin
    scale:=0.78+0.025*((window.frameNum+i*7) mod 24);
    txt.Write(txt.ScaleFont(vectorFont,scale),innerR.Left+12+(i mod 3)*112,
      innerR.Top+58+(i div 3)*24,$FFDDE8F8,'temp '+Conv.ToStr(i+1),
      taLeft,toAddBaseline or toDontCache);
  end;
  txt.Write(bodyFont,innerR.Left+12,innerR.Bottom-12,$FF90C0E8,
    'Changing sizes use the side cache; stable text stays in the main cache.',taLeft,toAddBaseline);

  r:=Rect(leftR.Left,row2+BLOCK_GAP div 2,leftR.Right,leftR.Bottom);
  DrawBlock(r,'Status',innerR);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+30,$FFE5EDF7,
    UTF8.Format('frame=%d  fps=%.1f',[window.frameNum,window.smoothFPS]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+54,$FFE5EDF7,
    UTF8.Format('frameStartMs=%.3f  frameDeltaMs=%.3f',[window.frameStartMs,window.frameDeltaMs]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+78,$FF90C0E8,'Cache diagnostics from old EngineTest moved here.',taLeft,toAddBaseline);
end;

procedure TMainScene.DrawUnicodeComplex(const contentRect:TRect);
var
  area,r,innerR:TRect;
  wideLine:String32;
  st:string;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  wideLine:=Str32(SampleWide);

  r:=GridCell(area,0,0,2,2,BLOCK_GAP);
  DrawBlock(r,'Complex markup (toComplexText)',innerR);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,
    '{u}This{!u} {I}is {!I}an {C=FF90E0C0}{B}example{/B/C} text',
    taLeft,toAddBaseline or toComplexText);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+62,$FFE5EDF7,
    'Inline {L=11}link{/L} + {C=FFE0A080}color tag{/C}.',
    taLeft,toAddBaseline or toComplexText);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+90,$FF90C0E8,
    'Markup parser behavior is inherited from EngineTest coverage.',taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,BLOCK_GAP);
  DrawBlock(r,'WriteW + mixed scripts',innerR);
  txt.WriteW(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,wideLine,taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+12,innerR.Top+62,$FFE5EDF7,Str32('Symbols: [ ] { } / \ * + - ='),taLeft,toAddBaseline);
  txt.WriteW(bodyFont,innerR.Left+12,innerR.Top+90,$FF90C0E8,Str32('String32 path keeps Unicode codepoints explicit.'),taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,BLOCK_GAP);
  DrawBlock(r,'Multiline + alignment',innerR);
  st:='Alpha'#13#10'Beta'#13#10'Gamma';
  draw.Line((innerR.Left+innerR.Right) div 2,innerR.Top+10,(innerR.Left+innerR.Right) div 2,innerR.Bottom-10,$50FFFFFF);
  txt.Write(bodyFont,(innerR.Left+innerR.Right) div 2,innerR.Top+40,$FFE5EDF7,st,taCenter,toAddBaseline);
  txt.Write(bodyFont,(innerR.Left+innerR.Right) div 2,innerR.Top+110,$FF90C0E8,'Center anchor for multiline',taCenter,toAddBaseline);

  r:=GridCell(area,1,1,2,2,BLOCK_GAP);
  DrawBlock(r,'Translation control',innerR);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,'Default call (may use dictionary if configured)',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+62,$FFE5EDF7,'Explicit toDontTranslate',taLeft,toAddBaseline or toDontTranslate);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+90,$FF90C0E8,'Demo keeps toDontTranslate for predictable test output.',taLeft,toAddBaseline);
end;

procedure TMainScene.DrawMetrics(const contentRect:TRect);
var
  area,r,innerR:TRect;
  w1,w2,h:integer;
  wr,wv:integer;
  s8:string;
  s32:String32;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  s8:='1) AV Privet - Hello!';
  s32:=Str32(SampleWide);
  w1:=txt.Width(bodyFont,s8);
  w2:=txt.WidthW(bodyFont,s32);
  h:=txt.Height(bodyFont);

  r:=GridCell(area,0,0,2,2,BLOCK_GAP);
  DrawBlock(r,'Width / WidthW / Height',innerR);
  draw.FillRect(innerR.Left+12,innerR.Top+36,innerR.Left+12+w1,innerR.Top+44,$FF7AA0D8);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,s8,taLeft,toAddBaseline);
  draw.FillRect(innerR.Left+12,innerR.Top+84,innerR.Left+12+w2,innerR.Top+92,$FFE09060);
  txt.WriteW(bodyFont,innerR.Left+12,innerR.Top+82,$FFE5EDF7,s32,taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+122,$FF90C0E8,
    UTF8.Format('Width=%d WidthW=%d Height=%d',[w1,w2,h]),taLeft,toAddBaseline);

  r:=GridCell(area,1,0,2,2,BLOCK_GAP);
  DrawBlock(r,'ScaleFont visual check',innerR);
  txt.Write(txt.ScaleFont(bodyFont,0.75),innerR.Left+12,innerR.Top+34,$FFE5EDF7,'scale=0.75',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.0),innerR.Left+12,innerR.Top+62,$FFE5EDF7,'scale=1.00',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.4),innerR.Left+12,innerR.Top+96,$FFE5EDF7,'scale=1.40',taLeft,toAddBaseline);
  txt.Write(txt.ScaleFont(bodyFont,1.9),innerR.Left+12,innerR.Top+138,$FFE5EDF7,'scale=1.90',taLeft,toAddBaseline);

  r:=GridCell(area,0,1,2,2,BLOCK_GAP);
  DrawBlock(r,'SetFontOption stress',innerR);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+34,$FFE5EDF7,'foDownscaleFactor=1.0',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+60,$FFE5EDF7,'foUpscaleFactor=1.0',taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+86,$FF90C0E8,'Mirrors important EngineTest setup.',taLeft,toAddBaseline);

  r:=GridCell(area,1,1,2,2,BLOCK_GAP);
  DrawBlock(r,'Diagnostic text (raster/vector)',innerR);
  wr:=txt.Width(rasterFont,'Sample');
  wv:=txt.Width(vectorFont,'Sample');
  txt.Write(monoFont,innerR.Left+12,innerR.Top+34,$FFD8E7F8,UTF8.Format('menuWidth=%d itemH=%d',[menuWidth,menuItemHeight]),taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+12,innerR.Top+56,$FFD8E7F8,UTF8.Format('window=%dx%d render=%dx%d',
    [window.clientWidth,window.clientHeight,window.canvasWidth,window.canvasHeight]),taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+12,innerR.Top+78,$FFD8E7F8,UTF8.Format('rasterW=%d vectorW=%d',[wr,wv]),taLeft,toAddBaseline);
  txt.Write(monoFont,innerR.Left+12,innerR.Top+100,$FFD8E7F8,UTF8.Format('raster=%u vector=%u',[rasterFont,vectorFont]),taLeft,toAddBaseline);
  txt.Write(bodyFont,innerR.Left+12,innerR.Top+126,$FF90C0E8,'This screen doubles as a quick regression checklist.',taLeft,toAddBaseline);
end;

procedure TMainScene.Render;
var
  area,menuRect,contentRect:TRect;
begin
  UpdateDeltaStats;

  if window.surface.dpi<>lastDPI then begin
    lastDPI:=window.surface.dpi;
    UpdateMetrics;
    RebuildFonts;
  end;

  HandleInput;
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
    end;
  finally
    txt.EndBlock;
  end;

  DrawOverlayStats;
end;

end.
