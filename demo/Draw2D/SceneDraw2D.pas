// 2D primitives gallery demo for Apus Engine
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit SceneDraw2D;
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
  Math,
  Apus.Core,
  Apus.Images,
  Apus.Colors,
  Apus.Engine.Keys,
  Apus.Engine.Types,
  Apus.Engine.NinePatch,
  Apus.Engine.UI;

type
  TMainScene=class(TUIScene)
    checkerTex,helperTex,atlasTex:TTexture;
    stretchPatch,tiledPatch:TNinePatch;
    particles:array[0..47] of TParticle;
    bandParts:array[0..15] of TParticle;
    titleFont,menuFont,hintFont,bodyFont:TFontHandle;
    currentScreen:integer;
    animTime:double;
    animTimeFrame:integer;
    blockClipActive:boolean;
    layoutScale:single;
    menuWidth,menuTop,menuItemHeight,contentPadding,screenTopOffset:integer;
    lastDPI:integer;
    procedure Load; override;
    procedure Render; override;
    procedure BuildCheckerTexture;
    procedure BuildHelperTexture;
    procedure BuildAtlasTexture;
    procedure BuildNinePatches;
    function BuildMarkedPatch(size:integer;tileMode:boolean;
      topCol,botCol,rimCol,accentCol:cardinal;const name:string):TNinePatch;
    procedure InitParticles;
    procedure UpdateMetrics;
    procedure RebuildFonts;
    procedure HandleInput;
    procedure DrawMenu(const menuRect:TRect);
    procedure DrawScreenTitle(const contentRect:TRect; const title,subtitle:string);
    // returns inner content rect (below title bar)
    procedure DrawBlock(const r:TRect; const title:string; out innerR:TRect);
    procedure FinishBlockClipping;
    // compute cell rect for grid layout; gap between cells = GAP
    function GridCell(const area:TRect; col,row,cols,rows,gap:integer):TRect;
    procedure DrawScreenLines(const contentRect:TRect);
    procedure DrawScreenRects(const contentRect:TRect);
    procedure DrawScreenFillGrad(const contentRect:TRect);
    procedure DrawScreenTriShade(const contentRect:TRect);
    procedure DrawScreenTextured(const contentRect:TRect);
    procedure DrawScreenCombo(const contentRect:TRect);
    procedure DrawScreenImageOps(const contentRect:TRect);
    procedure DrawScreenParticles(const contentRect:TRect);
    procedure DrawScreenNinePatch(const contentRect:TRect);
    procedure DrawScreenClipBlend(const contentRect:TRect);
    procedure UpdateAnimTime;
  end;

const
  SCREEN_COUNT=10;
  MENU_WIDTH=360;
  MENU_TOP=76;
  MENU_ITEM_HEIGHT=58;
  CONTENT_PADDING=18;
  BLOCK_TITLE_H=26; // height of block title bar
  BLOCK_RADIUS=8;
  BLOCK_GAP=10;

SCREEN_TITLES:array[0..SCREEN_COUNT-1] of string=(
  'Lines && Paths',
  'Rects && Rounded',
  'Fill && Gradients',
  'Triangles && Shading',
  'TexturedRect && UV',
  'Combined Playground',
  'Image Helpers',
  'Particles && Band',
  'NinePatch',
  'Clipping && Blend'
);

SCREEN_HINTS:array[0..SCREEN_COUNT-1] of string=(
  'Line / Polyline / Polygon',
  'Rect / RRect / FillRRect / RoundRect',
  'FillRect / FillGradrect / WithGradient',
  'FillTriangle / ShadedRect',
  'TexturedRect overloads / RotScaled',
  'Mixed static + animated cases',
  'Image / Centered / ImagePart / Scaled / Cover / DoubleTex',
  'Particles / Band',
  'TNinePatch stretch / tiled / animated resize',
  'gfx.clip rect / BlendMode add vs alpha'
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

constructor TMainApp.Create;
begin
  inherited;
  gameTitle:='Apus Engine: Draw2D';
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
  sceneMain:=TMainScene.Create('Main');
  game.SwitchToScene('Main');
end;

procedure TMainScene.BuildCheckerTexture;
var
  x,y:integer;
  row:PCardinalRow;
  color:cardinal;
begin
  checkerTex:=AllocImage(96,96,ipfARGB,aiTexture,'Draw2DChecker');
  checkerTex.Lock;
  for y:=0 to checkerTex.height-1 do begin
    row:=PCardinalRow(checkerTex.ScanLine(y));
    for x:=0 to checkerTex.width-1 do begin
      if ((x div 12+y div 12) and 1)=0 then
        color:=$FF9ABBE7
      else
        color:=$FF24466F;
      row^[x]:=color;
    end;
  end;
  checkerTex.Unlock;
end;

procedure TMainScene.BuildHelperTexture;
var
  x,y,w,h,cx,cy:integer;
  row:PCardinalRow;
  dx,dy,dist,alpha:single;
  col:cardinal;
begin
  w:=128;
  h:=128;
  cx:=w div 2;
  cy:=h div 2;
  helperTex:=AllocImage(w,h,ipfARGB,aiTexture,'Draw2DHelper');
  helperTex.Lock;
  for y:=0 to h-1 do begin
    row:=PCardinalRow(helperTex.ScanLine(y));
    for x:=0 to w-1 do begin
      dx:=x-cx;
      dy:=y-cy;
      dist:=sqrt(dx*dx+dy*dy);
      alpha:=Clamp((58-dist)*0.08,0,1);
      col:=Color.Mix($FF3D6EA8,$FF9DD2F0,Clamp((x+y)/(w+h),0,1));
      row^[x]:=Color.SetAlpha(col,alpha);
    end;
  end;
  helperTex.Unlock;
end;

procedure TMainScene.BuildAtlasTexture;
var
  x,y,w,h,cxCell,cyCell:integer;
  row:PCardinalRow;
  cellX,cellY:integer;
  baseCol,col:cardinal;
  dx,dy,dist:single;
begin
  w:=128;
  h:=128;
  atlasTex:=AllocImage(w,h,ipfARGB,aiTexture,'Draw2DAtlas');
  atlasTex.Lock;
  for y:=0 to h-1 do begin
    row:=PCardinalRow(atlasTex.ScanLine(y));
    for x:=0 to w-1 do begin
      cellX:=x div 32;
      cellY:=y div 32;
      cxCell:=cellX*32+16;
      cyCell:=cellY*32+16;
      dx:=x-cxCell;
      dy:=y-cyCell;
      dist:=sqrt(dx*dx+dy*dy);
      baseCol:=Color.Mix($FF2A3A54,$FF82B8EA,(cellX+cellY*4)/15);
      col:=baseCol;
      if dist<11 then
        col:=Color.Mix($FFFFFFFF,baseCol,dist/11)
      else
      if dist>14 then
        col:=Color.Mix(baseCol,$FF1A2538,Clamp((dist-14)/7,0,1));
      row^[x]:=$FF000000 or (col and $FFFFFF);
    end;
  end;
  atlasTex.Unlock;
end;

// Build a marked image and turn it into a 9-patch.
// Markers live on the top edge (horizontal ranges) and left edge (vertical ranges):
//   transparent = fixed corner, black = stretched, green = tiled.
// Corners are rounded; since corner regions are fixed, the rounding survives any resize.
function TMainScene.BuildMarkedPatch(size:integer;tileMode:boolean;
  topCol,botCol,rimCol,accentCol:cardinal;const name:string):TNinePatch;
var
  img:TTexture;
  x,y,corner,cxRef,cyRef,pos:integer;
  row:PCardinalRow;
  col:cardinal;
  fixed:boolean;
  ty,d:single;
const
  MARK_STRETCH=$FF000000; // black
  MARK_TILE   =$FF00FF00; // green
  MARK_FIXED  =$00000000; // transparent
begin
  corner:=size div 4;
  img:=AllocImage(size,size,ipfARGB,aiTexture,name);
  img.Lock;
  for y:=0 to size-1 do begin
    row:=PCardinalRow(img.ScanLine(y));
    for x:=0 to size-1 do begin
      if (y=0) and (x>=1) and (x<=size-2) then begin
        // top edge marker (horizontal range), pos along X
        pos:=x;
        fixed:=(pos<corner) or (pos>=size-corner);
        if fixed then col:=MARK_FIXED
        else if tileMode then col:=MARK_TILE
        else col:=MARK_STRETCH;
      end else
      if (x=0) and (y>=1) and (y<=size-2) then begin
        // left edge marker (vertical range), pos along Y
        pos:=y;
        fixed:=(pos<corner) or (pos>=size-corner);
        if fixed then col:=MARK_FIXED
        else if tileMode then col:=MARK_TILE
        else col:=MARK_STRETCH;
      end else
      if (x=0) or (y=0) or (x=size-1) or (y=size-1) then
        col:=MARK_FIXED // unused border (bottom/right), cleared later anyway
      else begin
        // interior content
        ty:=(y-1)/(size-3);
        col:=Color.Mix(topCol,botCol,ty);
        // tiled accent so repetition is visible when stretched as tiles
        if tileMode and ((x mod 6) in [2,3]) and ((y mod 6) in [2,3]) then
          col:=accentCol;
        // distance to nearest corner center (full-image coords)
        cxRef:=x; if size-1-x<cxRef then cxRef:=size-1-x;
        cyRef:=y; if size-1-y<cyRef then cyRef:=size-1-y;
        if (cxRef<corner) and (cyRef<corner) then begin
          // rounded corner: rim follows the arc, transparent beyond it
          d:=sqrt(sqr(corner-cxRef)+sqr(corner-cyRef));
          if d>corner then col:=$00000000 // outside rounded corner
          else if d>corner-1.5 then col:=rimCol; // rim along the rounded edge
        end else begin
          // straight edges: outermost interior ring as a 1px rim
          if (x=1) or (y=1) or (x=size-2) or (y=size-2) then
            col:=rimCol;
        end;
      end;
      row^[x]:=col;
    end;
  end;
  img.Unlock;
  result:=TCustomNinePatch.Create(img);
end;

procedure TMainScene.BuildNinePatches;
begin
  // bluish stretchable patch
  stretchPatch:=BuildMarkedPatch(40,false,$FF5E86C8,$FF2C4A78,$FFAFD0F4,$FFFFFFFF,'Draw2DPatchStretch');
  // greenish tiled patch with a dotted accent
  tiledPatch:=BuildMarkedPatch(40,true,$FF4F9E72,$FF234B36,$FFB6ECCB,$FFEFF8C0,'Draw2DPatchTiled');
end;

procedure TMainScene.InitParticles;
var
  i:integer;
  t:single;
begin
  for i:=0 to high(particles) do begin
    t:=i*0.37;
    particles[i].x:=cos(t)*220;
    particles[i].y:=sin(t*1.4)*110;
    particles[i].z:=20+abs(sin(t*0.8))*120;
    particles[i].color:=Color.Mix($FFA0C8FF,$FFFFB080,frac(i*0.13));
    particles[i].scale:=0.7+frac(i*0.19)*0.9;
    particles[i].angle:=t*0.6;
    particles[i].index:=((i and 3)*partPosU)+(((i shr 2) and 3)*partPosV);
  end;

  for i:=0 to high(bandParts) do begin
    t:=i/(high(bandParts)+1);
    bandParts[i].x:=20+i*40;
    bandParts[i].y:=60+PRound(sin(t*Pi*2)*20);
    bandParts[i].z:=0;
    bandParts[i].color:=Color.Mix($FF60D0FF,$FFFFD080,t);
    bandParts[i].scale:=0.8+0.4*sin(t*Pi);
    bandParts[i].angle:=0;
    bandParts[i].index:=SRound(255*t);
  end;
  bandParts[high(bandParts)].index:=bandParts[high(bandParts)].index or partEndpoint;
end;

procedure TMainScene.Load;
begin
  lastDPI:=0;
  currentScreen:=0;
  animTime:=0;
  animTimeFrame:=-1;
  blockClipActive:=false;
  UpdateMetrics;
  RebuildFonts;
  BuildCheckerTexture;
  BuildHelperTexture;
  BuildAtlasTexture;
  BuildNinePatches;
  InitParticles;
  loaded:=true;
end;

procedure TMainScene.UpdateAnimTime;
begin
  if window.frameNum=animTimeFrame then exit;
  animTimeFrame:=window.frameNum;
  if window.frameDeltaMs>0 then
    animTime:=animTime+window.frameDeltaMs*0.001
  else
    animTime:=animTime+1/60;
end;

procedure TMainScene.UpdateMetrics;
begin
  layoutScale:=window.screenDPI/96;
  if layoutScale<1 then layoutScale:=1;
  menuWidth:=MENU_WIDTH+SRound((layoutScale-1)*110);
  menuWidth:=ClampI(menuWidth,340,window.renderWidth div 2);
  menuTop:=SRound(MENU_TOP*layoutScale);
  menuItemHeight:=SRound(MENU_ITEM_HEIGHT*layoutScale);
  contentPadding:=SRound(CONTENT_PADDING*layoutScale);
  screenTopOffset:=SRound(84*layoutScale);
end;

procedure TMainScene.RebuildFonts;
var
  fs:single;
  function F(baseSize:integer):integer;
  begin
    result:=Math.Max(6,SRound(baseSize*fs));
  end;
begin
  fs:=window.screenDPI/96;
  if fs<1 then fs:=1;
  titleFont:=txt.GetFont('Default',F(12));
  menuFont:=txt.GetFont('Default',F(10));
  hintFont:=txt.GetFont('Default',F(8));
  bodyFont:=txt.GetFont('Default',F(8));
end;

procedure TMainScene.HandleInput;
var
  i,item:integer;
const
  SC_DIGIT:array[0..9] of integer=(2,3,4,5,6,7,8,9,10,11); // row keys 1..9,0
  SC_NUM:array[0..9] of integer=(79,80,81,75,76,77,71,72,73,82); // numpad 1..9,0
begin
  for i:=0 to SCREEN_COUNT-1 do begin
    if (window.shiftState=0) and (IsKeyPressed(SC_DIGIT[i]) or IsKeyPressed(SC_NUM[i])) then
      currentScreen:=i;
  end;

  if LMBClicked and (window.mousePos.x>=0) and (window.mousePos.x<menuWidth) and
     (window.mousePos.y>=menuTop) then begin
    item:=(window.mousePos.y-menuTop) div menuItemHeight;
    if InRange(item,0,SCREEN_COUNT-1) then
      currentScreen:=item;
  end;
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

  txt.Write(titleFont,20,30,$FFE8F0FA,'Draw2D Screens',taLeft,toWithShadow);
  txt.Write(hintFont,20,52,$FFA4B7CE,'Mouse click or keys [1..9,0]',taLeft,0);

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
    // vertically center the single text line within the item box (y is the baseline)
    txt.Write(menuFont,r.Left+12,(r.Top+r.Bottom+txt.Height(menuFont)) div 2,txtCol,
      IntToStr(i+1)+'. '+SCREEN_TITLES[i],taLeft,0);
  end;
end;

procedure TMainScene.DrawScreenTitle(const contentRect:TRect; const title,subtitle:string);
begin
  draw.FillRect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF1F2A3A);
  draw.Rect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF3D5067);
  txt.Write(titleFont,contentRect.Left+14,contentRect.Top+20,$FFEAF2FC,title,taLeft,toWithShadow);
  txt.Write(hintFont,contentRect.Left+14,contentRect.Top+42,$FFA8BDD5,subtitle,taLeft,0);
end;

// draw a labeled block; innerR = area below the title bar for content
procedure TMainScene.DrawBlock(const r:TRect; const title:string; out innerR:TRect);
begin
  FinishBlockClipping;
  draw.FillRRect(r.Left,r.Top,r.Right,r.Bottom,$FF1C2836,BLOCK_RADIUS);
  draw.FillRect(r.Left+1,r.Top+1,r.Right-1,r.Top+BLOCK_TITLE_H,$28AACCFF);
  draw.Rect(r.Left,r.Top,r.Right,r.Bottom,$FF3D5270);
  draw.Line(r.Left+1,r.Top+BLOCK_TITLE_H,r.Right-1,r.Top+BLOCK_TITLE_H,$FF3D5270);
  txt.Write(bodyFont,r.Left+10,r.Top+BLOCK_TITLE_H-5,$FFDDEEFF,title,taLeft,toWithShadow);
  innerR:=Rect(r.Left+8,r.Top+BLOCK_TITLE_H+6,r.Right-8,r.Bottom-8);
  gfx.clip.Rect(innerR);
  blockClipActive:=true;
end;

procedure TMainScene.FinishBlockClipping;
begin
  if not blockClipActive then exit;
  gfx.clip.Restore;
  blockClipActive:=false;
end;

// returns rect of grid cell (col,row) within area, zero-based
function TMainScene.GridCell(const area:TRect; col,row,cols,rows,gap:integer):TRect;
var
  w,h,x,y:integer;
begin
  w:=(area.Right-area.Left-(cols-1)*gap) div cols;
  h:=(area.Bottom-area.Top-(rows-1)*gap) div rows;
  x:=area.Left+col*(w+gap);
  y:=area.Top+row*(h+gap);
  result:=Rect(x,y,x+w,y+h);
end;

// screen 0: Line / Polyline / Polygon — 3 blocks in a row
procedure TMainScene.DrawScreenLines(const contentRect:TRect);
var
  area,r,innerR:TRect;
  p:array[0..6] of TVec2;
  i:integer;
  t,cx,cy:single;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  FillChar(p,SizeOf(p),0);

  // block 0: draw.Line (horizontal ramp)
  r:=GridCell(area,0,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.Line',innerR);
  draw.BeginLines;
  for i:=0 to 12 do
    draw.Line(innerR.Left+10,innerR.Top+14+i*((innerR.Bottom-innerR.Top-20) div 13),
      innerR.Right-10,innerR.Top+14+i*((innerR.Bottom-innerR.Top-20) div 13),
      $FF2E4866+i*$000A0A0A);
  draw.EndLines;

  // block 1: draw.Line (animated fan)
  r:=GridCell(area,1,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.Line  [animated]',innerR);
  draw.BeginLines;
  t:=animTime*2.5;
  cx:=innerR.Left+(innerR.Right-innerR.Left)*0.4;
  cy:=innerR.Top+(innerR.Bottom-innerR.Top)*0.55;
  for i:=0 to 5 do
    draw.Line(cx,cy,
      cx+cos(t+i)*((innerR.Right-innerR.Left)*0.45),
      cy+sin(t*1.2+i)*((innerR.Bottom-innerR.Top)*0.42),
      $FFA0D8FF-i*$00141000);
  draw.EndLines;
  draw.FillRRect(cx-6,cy-6,cx+6,cy+6,$FFEEF6FF,5);

  // block 2: draw.Polyline + draw.Polygon
  r:=GridCell(area,2,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.Polyline / draw.Polygon',innerR);
  p[0].Init(innerR.Left+20, innerR.Bottom-40);
  p[1].Init(innerR.Left+80, innerR.Top+30);
  p[2].Init(innerR.Left+160,innerR.Bottom-80);
  p[3].Init(innerR.Left+230,innerR.Top+55);
  p[4].Init(innerR.Left+310,innerR.Bottom-60);
  p[5].Init(innerR.Left+380,innerR.Top+40);
  p[6].Init(innerR.Right-20,innerR.Bottom-70);
  draw.Polyline(@p[0],7,$FFFFD070,false);
  // closed polygon with fill using first 5 pts
  p[0].Init(innerR.Left+60, innerR.Top+100);
  p[1].Init(innerR.Left+140,innerR.Top+50);
  p[2].Init(innerR.Left+210,innerR.Top+110);
  p[3].Init(innerR.Left+180,innerR.Top+180);
  p[4].Init(innerR.Left+80, innerR.Top+190);
  draw.Polygon(@p[0],5,$4060C0FF);
  draw.Polyline(@p[0],5,$FFBEE8FF,true);
end;

// screen 1: Rect / RRect / FillRRect / RoundRect — 2x2 grid
procedure TMainScene.DrawScreenRects(const contentRect:TRect);
var
  area,r,innerR:TRect;
  t:single;
  cx,cy:single;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  t:=animTime*2.0;

  // block [0,0]: draw.Rect
  r:=GridCell(area,0,0,2,2,BLOCK_GAP);
  DrawBlock(r,'draw.Rect',innerR);
  draw.BeginLines;
  draw.Rect(innerR.Left+14,innerR.Top+14,innerR.Right-14,innerR.Bottom-14,$FFE9BE78);
  draw.Rect(innerR.Left+34,innerR.Top+34,innerR.Right-34,innerR.Bottom-34,$FF87D3FF);
  draw.Rect(innerR.Left+54,innerR.Top+54,innerR.Right-54,innerR.Bottom-54,$FF70C090);
  // sub-pixel rect
  draw.Rect(innerR.Left+70.5,innerR.Top+70.5,innerR.Right-70.5,innerR.Bottom-70.5,$FFFFC060);
  draw.EndLines;

  // block [1,0]: draw.RRect
  r:=GridCell(area,1,0,2,2,BLOCK_GAP);
  DrawBlock(r,'draw.RRect',innerR);
  draw.RRect(innerR.Left+12,innerR.Top+12,innerR.Right-12,innerR.Top+(innerR.Bottom-innerR.Top) div 3,$FFE7A870,10);
  draw.RRect(innerR.Left+20,innerR.Top+(innerR.Bottom-innerR.Top) div 3+10,
    innerR.Right-20,innerR.Top+2*(innerR.Bottom-innerR.Top) div 3,4,16,$FF79DAA9);
  draw.RRect(innerR.Left+30,innerR.Top+2*(innerR.Bottom-innerR.Top) div 3+10,
    innerR.Right-30,innerR.Bottom-12,2,22,$FFB080FF);

  // block [0,1]: draw.FillRRect
  r:=GridCell(area,0,1,2,2,BLOCK_GAP);
  DrawBlock(r,'draw.FillRRect',innerR);
  draw.FillRRect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,$40607090,12);
  draw.FillRRect(innerR.Left+30,innerR.Top+30,innerR.Right-30,innerR.Bottom-30,$80B7704A,16);
  draw.FillRRect(innerR.Left+50,innerR.Top+50,innerR.Right-50,innerR.Bottom-50,$B0C8A060,20);

  // block [1,1]: draw.RoundRect (animated)
  r:=GridCell(area,1,1,2,2,BLOCK_GAP);
  DrawBlock(r,'draw.RoundRect  [animated]',innerR);
  cx:=(innerR.Left+innerR.Right)*0.5;
  cy:=innerR.Top+(innerR.Bottom-innerR.Top)*0.38;
  draw.RoundRect(TVec2.Init(cx,cy),
    (innerR.Right-innerR.Left-60)*0.5+sin(t)*((innerR.Right-innerR.Left-60)*0.25),
    (innerR.Bottom-innerR.Top)*0.28+cos(t*1.3)*((innerR.Bottom-innerR.Top)*0.08),
    20+sin(t*1.5)*7,3,$FFBFD8F7,$704F6FA4);
  draw.RoundRect(innerR.Left+20,innerR.Top+(innerR.Bottom-innerR.Top) div 2+10,
    innerR.Right-20,innerR.Bottom-20,18,0,$00000000,$A05295C0);
  draw.RoundRect(innerR.Left+36,innerR.Top+(innerR.Bottom-innerR.Top) div 2+26,
    innerR.Right-36,innerR.Bottom-36,12,1,$FFEAF6FF,$80435A73);
end;

// screen 2: FillRect / FillGradrect / WithGradient — 3 blocks
procedure TMainScene.DrawScreenFillGrad(const contentRect:TRect);
var
  area,r,innerR:TRect;
  g:TColorGradient;
  t:single;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  t:=animTime*1.5;

  // block 0: draw.FillRect — solid + alpha layering
  r:=GridCell(area,0,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.FillRect',innerR);
  draw.FillRect(innerR.Left+10,innerR.Top+10,innerR.Left+160,innerR.Top+160,$B0E97B5A);
  draw.FillRect(innerR.Left+80,innerR.Top+60,innerR.Right-30,innerR.Top+220,$909CE8A8);
  draw.FillRect(innerR.Left+30,innerR.Top+200,innerR.Right-50,innerR.Bottom-20,$70D8D8FF);

  // block 1: draw.FillGradrect — horizontal and vertical
  r:=GridCell(area,1,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.FillGradrect',innerR);
  draw.FillGradrect(innerR.Left+10,innerR.Top+10,innerR.Right-10,
    innerR.Top+(innerR.Bottom-innerR.Top) div 2-5,$FFF0A040,$FF7030A0,false); // horizontal
  draw.FillGradrect(innerR.Left+10,innerR.Top+(innerR.Bottom-innerR.Top) div 2+5,
    innerR.Right-10,innerR.Bottom-10,$FFE06060,$FF50A0E0,true); // vertical

  // block 2: draw.WithGradient / draw.NoGradient — animated
  r:=GridCell(area,2,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.WithGradient  [animated]',innerR);
  draw.WithGradient($FFF1B45F,$FF4F92D8,t,0.7+0.2*sin(t));
  draw.FillRRect(innerR.Left+20,innerR.Top+10,innerR.Right-20,
    innerR.Top+(innerR.Bottom-innerR.Top) div 2-5,$FFFFFFFF,16);
  g.Init($FF73DCAA,$FF4B4EA9,t+Pi*0.5,0.55);
  draw.WithGradient(g,true);
  draw.FillRect(innerR.Left+30,innerR.Top+(innerR.Bottom-innerR.Top) div 2+5,
    innerR.Right-30,innerR.Bottom-10,$FFFFFFFF);
  draw.NoGradient;
  draw.Rect(innerR.Left+20,innerR.Top+10,innerR.Right-20,
    innerR.Top+(innerR.Bottom-innerR.Top) div 2-5,$FFE7F1FF);
end;

// screen 3: FillTriangle / ShadedRect — 3 blocks
procedure TMainScene.DrawScreenTriShade(const contentRect:TRect);
var
  area,r,innerR:TRect;
  cx,cy,t:single;
  i,h3:integer;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  t:=animTime*2.2;

  // block 0: draw.FillTriangle (static)
  r:=GridCell(area,0,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.FillTriangle',innerR);
  cx:=(innerR.Left+innerR.Right)*0.5;
  draw.FillTriangle(innerR.Left+20,innerR.Bottom-20,innerR.Right-20,innerR.Bottom-20,cx,innerR.Top+20,
    $FFE96A6A,$FF63E18C,$FF5A86ED);
  draw.FillTriangle(innerR.Left+50,innerR.Bottom-60,innerR.Right-50,innerR.Bottom-55,cx,innerR.Top+80,
    $60FFFFFF,$C0FFD080,$50A0B0FF);

  // block 1: draw.FillTriangle (animated)
  r:=GridCell(area,1,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.FillTriangle  [animated]',innerR);
  cx:=(innerR.Left+innerR.Right)*0.5;
  cy:=(innerR.Top+innerR.Bottom)*0.5;
  for i:=0 to 2 do
    draw.FillTriangle(cx,cy,
      cx+cos(t+i*2.09)*((innerR.Right-innerR.Left)*0.44),
      cy+sin(t+i*2.09)*((innerR.Bottom-innerR.Top)*0.44),
      cx+cos(t+i*2.09+0.9)*((innerR.Right-innerR.Left)*0.42),
      cy+sin(t+i*2.09+0.9)*((innerR.Bottom-innerR.Top)*0.42),
      $30FF8060+i*$00202020,$50A0C0FF,$30A0FFB0);
  draw.FillRRect(cx-12,cy-12,cx+12,cy+12,$FFEFF5FC,10);

  // block 2: draw.ShadedRect (three variants)
  r:=GridCell(area,2,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.ShadedRect',innerR);
  h3:=(innerR.Bottom-innerR.Top-20) div 3;
  draw.ShadedRect(innerR.Left+14,innerR.Top+10,innerR.Right-14,innerR.Top+10+h3,3,$FFD0DCEC,$FF4A5C71);
  draw.ShadedRect(innerR.Left+14,innerR.Top+10+h3+10,innerR.Right-14,innerR.Top+10+h3*2,1,$FFD3E0EE,$FF415266);
  draw.ShadedRect(innerR.Left+30,innerR.Top+10+h3*2+10,innerR.Right-30,innerR.Bottom-10,2,$FFD0DCEC,$FF455A72);
end;

// screen 4: TexturedRect / RotScaled — 3 blocks
procedure TMainScene.DrawScreenTextured(const contentRect:TRect);
var
  area,r,innerR:TRect;
  t,s:single;
  cx,cy:single;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  if checkerTex=nil then exit;
  t:=animTime*1.8;
  s:=1.2+0.35*sin(t);

  // block 0: draw.TexturedRect(TRect) with color tint
  r:=GridCell(area,0,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.TexturedRect(TRect)',innerR);
  draw.TexturedRect(Rect(innerR.Left+10,innerR.Top+10,innerR.Left+180,innerR.Bottom-10),
    checkerTex,$FF8CB0FF);
  draw.TexturedRect(Rect(innerR.Left+195,innerR.Top+10,innerR.Right-10,innerR.Bottom-10),
    checkerTex,$FFB6F0B0);

  // block 1: draw.TexturedRect(UV overload)
  r:=GridCell(area,1,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.TexturedRect(UV)',innerR);
  draw.TexturedRect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,
    checkerTex,0,0,1,0,0.5,1,$FFFFFFFF);
  draw.Rect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,$FFEAF3FF);

  // block 2: draw.RotScaled (animated)
  r:=GridCell(area,2,0,3,1,BLOCK_GAP);
  DrawBlock(r,'draw.RotScaled  [animated]',innerR);
  cx:=(innerR.Left+innerR.Right)*0.5;
  cy:=(innerR.Top+innerR.Bottom)*0.5;
  draw.TexturedRect(Rect(innerR.Left+6,innerR.Top+6,innerR.Right-6,innerR.Bottom-6),
    checkerTex,$FF94A6C8);
  draw.RotScaled(cx,cy,s,s,t,checkerTex,$FFE8F0FF);
  draw.RRect(innerR.Left+6,innerR.Top+6,innerR.Right-6,innerR.Bottom-6,1,8,$FF7C91AD);
end;

// screen 5: Combined Playground — 2x2 blocks
procedure TMainScene.DrawScreenCombo(const contentRect:TRect);
var
  area,r,innerR:TRect;
  i,cx,cy:integer;
  t:single;
  p:array[0..4] of TVec2;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  FillChar(p,SizeOf(p),0);
  t:=animTime*3.0;

  // block [0,0]: ShadedRect + FillGradrect
  r:=GridCell(area,0,0,2,2,BLOCK_GAP);
  DrawBlock(r,'ShadedRect + FillGradrect',innerR);
  draw.ShadedRect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Top+60,2,$FFD0DCEC,$FF495B70);
  draw.FillGradrect(innerR.Left+10,innerR.Top+75,innerR.Right-10,innerR.Bottom-10,$FF5C86E0,$FF2F4565,true);

  // block [1,0]: Polygon + Polyline + Line
  r:=GridCell(area,1,0,2,2,BLOCK_GAP);
  DrawBlock(r,'Polygon + Polyline + Line',innerR);
  p[0].Init(innerR.Left+30, innerR.Bottom-30);
  p[1].Init(innerR.Left+80, innerR.Top+30);
  p[2].Init(innerR.Left+200,innerR.Bottom-40);
  p[3].Init(innerR.Left+310,innerR.Top+40);
  p[4].Init(innerR.Right-30,innerR.Bottom-30);
  draw.Polygon(@p[0],5,$4060C0FF);
  draw.Polyline(@p[0],5,$FFBEE8FF,true);
  for i:=0 to 7 do
    draw.Line(innerR.Left+10,innerR.Top+12+i*((innerR.Bottom-innerR.Top-20) div 8),
      innerR.Right-10,innerR.Top+12+i*((innerR.Bottom-innerR.Top-20) div 8),$30447296);

  // block [0,1]: WithGradient + FillRRect + Line (animated)
  r:=GridCell(area,0,1,2,2,BLOCK_GAP);
  DrawBlock(r,'WithGradient + FillRRect + Line  [animated]',innerR);
  cx:=(innerR.Left+innerR.Right) div 2;
  cy:=(innerR.Top+innerR.Bottom) div 2;
  draw.WithGradient($FFF1B25C,$FF4E8DD0,t);
  draw.FillRRect(innerR.Left+16,innerR.Top+16,innerR.Right-16,innerR.Bottom-16,$FFFFFFFF,16);
  draw.NoGradient;
  for i:=0 to 6 do
    draw.Line(cx,cy,cx+PRound(cos(t+i*0.7)*((innerR.Right-innerR.Left) div 2-20)),
      cy+PRound(sin(t*1.2+i*0.7)*((innerR.Bottom-innerR.Top) div 2-20)),$FFD8EEFF);
  draw.FillRRect(cx-10,cy-10,cx+10,cy+10,$FFFFFFFF,8);

  // block [1,1]: TexturedRect + RoundRect + FillTriangle
  r:=GridCell(area,1,1,2,2,BLOCK_GAP);
  DrawBlock(r,'TexturedRect + RoundRect + FillTriangle',innerR);
  if checkerTex<>nil then begin
    draw.TexturedRect(Rect(innerR.Left+6,innerR.Top+6,innerR.Right-6,innerR.Bottom-6),
      checkerTex,$FFBACBE2);
    draw.RoundRect(innerR.Left+20,innerR.Top+20,innerR.Right-20,innerR.Bottom-20,16,2,$FFF0F8FF,$20406080);
    draw.FillTriangle(
      innerR.Left+30,innerR.Bottom-30,
      innerR.Right-30,innerR.Bottom-30,
      (innerR.Left+innerR.Right)*0.5,innerR.Top+30,
      $FFE96B6B,$FF66DF90,$FF6D92EF);
  end;
end;

// screen 6: Image Helpers — 3x2 grid
procedure TMainScene.DrawScreenImageOps(const contentRect:TRect);
var
  area,r,innerR:TRect;
  uvRect:TRect;
  cScale,iScale:single;
  cx:integer;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  if (checkerTex=nil) or (helperTex=nil) or (atlasTex=nil) then exit;
  uvRect:=Rect(32,32,95,95);

  // row 0, col 0: draw.Image / draw.Centered
  r:=GridCell(area,0,0,3,2,BLOCK_GAP);
  DrawBlock(r,'draw.Image / draw.Centered',innerR);
  cx:=(innerR.Left+innerR.Right) div 2;
  draw.Image(innerR.Left+10,innerR.Top+10,checkerTex,$FF95B0FF);
  draw.Image(innerR.Left+120,innerR.Top+10,1.2,helperTex,$FFD8F4FF,0.5,0.5);
  draw.Centered(cx,innerR.Top+60,atlasTex,$FFFFFFFF);
  draw.Centered(cx+80,innerR.Top+60,0.75,atlasTex,$FFC0FFD0);

  // row 0, col 1: draw.ImagePart / ImagePart90 / ImageFlipped
  r:=GridCell(area,1,0,3,2,BLOCK_GAP);
  DrawBlock(r,'draw.ImagePart / ImagePart90 / ImageFlipped',innerR);
  draw.ImagePart(innerR.Left+10,innerR.Top+10,atlasTex,$FFFFFFFF,uvRect);
  draw.ImagePart90(innerR.Left+90,innerR.Top+10,atlasTex,$FFFFFFFF,uvRect,1);
  draw.ImageFlipped(innerR.Left+10,innerR.Top+80,checkerTex,true,false,$FFE0F2FF);
  draw.ImageFlipped(innerR.Left+120,innerR.Top+80,checkerTex,false,true,$FFFFD6A0);

  // row 0, col 2: draw.Scaled
  r:=GridCell(area,2,0,3,2,BLOCK_GAP);
  DrawBlock(r,'draw.Scaled',innerR);
  draw.Scaled(innerR.Left+10,innerR.Top+10,innerR.Left+130,innerR.Bottom-10-70,checkerTex,$FFFFFFFF);
  draw.Scaled(innerR.Left+140,innerR.Top+20,0.85,helperTex,$FFD8EEFF);

  // row 1, col 0: draw.SetZ
  r:=GridCell(area,0,1,3,2,BLOCK_GAP);
  DrawBlock(r,'draw.SetZ',innerR);
  draw.SetZ(-40);
  draw.FillRRect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Bottom-10,$90274A74,12);
  draw.SetZ(40);
  draw.FillRRect(innerR.Left+30,innerR.Top+30,innerR.Right-30,innerR.Bottom-30,$C0A7D8FF,10);
  draw.SetZ(0);

  // row 1, col 1: draw.Cover / draw.Inside
  r:=GridCell(area,1,1,3,2,BLOCK_GAP);
  DrawBlock(r,'draw.Cover / draw.Inside',innerR);
  draw.Rect(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Top+(innerR.Bottom-innerR.Top) div 2-4,$FF6E8CAC);
  cScale:=draw.Cover(innerR.Left+10,innerR.Top+10,innerR.Right-10,innerR.Top+(innerR.Bottom-innerR.Top) div 2-4,checkerTex,$FFFFFFFF);
  draw.Rect(innerR.Left+10,innerR.Top+(innerR.Bottom-innerR.Top) div 2+4,innerR.Right-10,innerR.Bottom-10,$FF6E8CAC);
  iScale:=draw.Inside(innerR.Left+10,innerR.Top+(innerR.Bottom-innerR.Top) div 2+4,innerR.Right-10,innerR.Bottom-10,checkerTex,$FFFFFFFF);
  txt.Write(bodyFont,innerR.Left+14,innerR.Top+(innerR.Bottom-innerR.Top) div 2-6,$FFCFE2F8,
    'Cover='+FormatFloat('0.00',cScale),taLeft,0);
  txt.Write(bodyFont,innerR.Left+14,innerR.Bottom-12,$FFCFE2F8,
    'Inside='+FormatFloat('0.00',iScale),taLeft,0);

  // row 1, col 2: draw.DoubleTex / draw.DoubleRotScaled
  r:=GridCell(area,2,1,3,2,BLOCK_GAP);
  DrawBlock(r,'draw.DoubleTex / draw.DoubleRotScaled',innerR);
  cx:=(innerR.Left+innerR.Right) div 2;
  draw.DoubleTex(cx,innerR.Top+60,checkerTex,helperTex,$FFE8F8FF);
  draw.DoubleRotScaled(cx,(innerR.Top+innerR.Bottom) div 2+60,
    1.0,1.0,1.2,0.8,animTime*1.8,checkerTex,helperTex,$FFE8F8FF);
end;

// screen 7: Particles / Band — 2 blocks side by side
procedure TMainScene.DrawScreenParticles(const contentRect:TRect);
var
  area,r,innerR:TRect;
  i:integer;
  t:single;
  cx,cy:integer;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  if atlasTex=nil then exit;
  t:=animTime*1.6;

  // block 0: draw.Particles
  r:=GridCell(area,0,0,2,1,BLOCK_GAP);
  DrawBlock(r,'draw.Particles  [animated]',innerR);
  cx:=(innerR.Left+innerR.Right) div 2;
  cy:=(innerR.Top+innerR.Bottom) div 2;
  for i:=0 to high(particles) do begin
    particles[i].angle:=t+i*0.2;
    particles[i].x:=cos(t+i*0.31)*((innerR.Right-innerR.Left)*0.40);
    particles[i].y:=sin(t*1.1+i*0.43)*((innerR.Bottom-innerR.Top)*0.38);
  end;
  draw.FillRect(innerR.Left,innerR.Top,innerR.Right,innerR.Bottom,$30203854);
  draw.EnableSoftParticles(0);
  draw.Particles(cx,cy,@particles[0],length(particles),atlasTex,16,240);

  // block 1: draw.Band
  r:=GridCell(area,1,0,2,1,BLOCK_GAP);
  DrawBlock(r,'draw.Band  [animated]',innerR);
  for i:=0 to high(bandParts) do begin
    bandParts[i].x:=innerR.Left+10+i*((innerR.Right-innerR.Left-20) div high(bandParts));
    bandParts[i].y:=(innerR.Top+innerR.Bottom) div 2+PRound(sin(t*1.8+i*0.5)*((innerR.Bottom-innerR.Top)*0.28));
  end;
  draw.FillRect(innerR.Left,innerR.Top,innerR.Right,innerR.Bottom,$30203854);
  draw.Band(0,0,@bandParts[0],length(bandParts),atlasTex,Rect(0,0,31,31));
end;

// screen 8: NinePatch — stretch / tiled / animated resize (3 blocks in a row)
procedure TMainScene.DrawScreenNinePatch(const contentRect:TRect);
var
  area,r,innerR:TRect;
  t,k:single;
  dw,dh,by2,bh2:integer;
  procedure Patch(p:TNinePatch;x,y,w,h:integer);
  begin
    if p=nil then exit;
    draw.Rect(x-1,y-1,x+w,y+h,$50FFFFFF);
    p.Draw(x,y,w,h);
  end;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  t:=animTime;

  // block 0: stretched patch at several fixed sizes
  r:=GridCell(area,0,0,3,1,BLOCK_GAP);
  DrawBlock(r,'patch.Draw  [stretched]',innerR);
  Patch(stretchPatch,innerR.Left+16,innerR.Top+14,60,40);
  Patch(stretchPatch,innerR.Left+16,innerR.Top+70,innerR.Right-innerR.Left-32,46);
  Patch(stretchPatch,innerR.Left+16,innerR.Top+130,120,innerR.Bottom-innerR.Top-150);

  // block 1: tiled patch at several fixed sizes
  r:=GridCell(area,1,0,3,1,BLOCK_GAP);
  DrawBlock(r,'patch.Draw  [tiled]',innerR);
  Patch(tiledPatch,innerR.Left+16,innerR.Top+14,70,50);
  Patch(tiledPatch,innerR.Left+16,innerR.Top+78,innerR.Right-innerR.Left-32,52);
  Patch(tiledPatch,innerR.Left+16,innerR.Top+144,150,innerR.Bottom-innerR.Top-164);

  // block 2: animated resize of both patches
  r:=GridCell(area,2,0,3,1,BLOCK_GAP);
  DrawBlock(r,'patch.Draw  [animated resize]',innerR);
  k:=0.5+0.5*sin(t*1.6);
  dw:=SRound(k*(innerR.Right-innerR.Left-130));
  dh:=SRound((0.5+0.5*sin(t*1.1))*120);
  // upper band: stretched patch (max height = 46 + 120 div 3 = 86)
  Patch(stretchPatch,innerR.Left+16,innerR.Top+16,70+dw,46+(dh div 3));
  // lower band: tiled patch, placed below the stretch band so they never overlap
  by2:=innerR.Top+16+86+20;
  bh2:=60+dh;
  if by2+bh2>innerR.Bottom-8 then bh2:=innerR.Bottom-8-by2;
  if bh2>0 then Patch(tiledPatch,innerR.Left+16,by2,90+dw,bh2);
end;

// screen 9: Clipping && Blend — absorbs EngineTest clip + blend-mode 2D cases (2 blocks)
procedure TMainScene.DrawScreenClipBlend(const contentRect:TRect);
var
  area,r,innerR,clipR:TRect;
  t:single;
  i,x,y,cx,cy:integer;
begin
  area:=Rect(contentRect.Left+BLOCK_GAP,contentRect.Top+screenTopOffset,
    contentRect.Right-BLOCK_GAP,contentRect.Bottom-BLOCK_GAP);
  t:=animTime;

  // block 0: gfx.clip — moving box clipped to a window (nested under the block clip)
  r:=GridCell(area,0,0,2,1,BLOCK_GAP);
  DrawBlock(r,'gfx.clip.Rect  [animated]',innerR);
  clipR:=Rect(innerR.Left+30,innerR.Top+30,innerR.Left+230,innerR.Top+230);
  draw.Rect(clipR.Left-1,clipR.Top-1,clipR.Right,clipR.Bottom,$FFF0C080);
  gfx.clip.Rect(clipR);
  x:=(clipR.Left+clipR.Right) div 2+SRound(70*cos(t*1.3));
  y:=(clipR.Top+clipR.Bottom) div 2-SRound(70*sin(t*1.3));
  draw.FillRRect(x-40,y-40,x+40,y+40,$FF3080C0,8);
  draw.FillRRect(x-16,y-16,x+16,y+16,$FFEAF6FF,5);
  gfx.clip.Restore; // back to the block clip
  txt.Write(bodyFont,clipR.Left,clipR.Bottom+16,$FFB7C8DC,'box is clipped to the framed window',taLeft,0);

  // block 1: BlendMode — same translucent stack drawn with alpha vs additive
  r:=GridCell(area,1,0,2,1,BLOCK_GAP);
  DrawBlock(r,'gfx.target.BlendMode  [alpha vs add]',innerR);
  cx:=innerR.Left+(innerR.Right-innerR.Left) div 4;
  cy:=(innerR.Top+innerR.Bottom) div 2;
  // left: alpha blending
  draw.FillRect(innerR.Left+10,innerR.Top+10,(innerR.Left+innerR.Right) div 2-6,innerR.Bottom-30,$FF101822);
  for i:=0 to 5 do begin
    x:=cx+SRound(34*cos(t*0.7+i*1.05));
    y:=cy+SRound(34*sin(t*0.7+i*1.05));
    draw.FillRRect(x-40,y-40,x+40,y+40,$60FF8060+(i shl 18),16);
  end;
  txt.Write(bodyFont,innerR.Left+14,innerR.Bottom-12,$FFB7C8DC,'blAlpha',taLeft,0);
  // right: additive blending
  cx:=innerR.Left+3*(innerR.Right-innerR.Left) div 4;
  draw.FillRect((innerR.Left+innerR.Right) div 2+6,innerR.Top+10,innerR.Right-10,innerR.Bottom-30,$FF101822);
  gfx.target.BlendMode(blAdd);
  for i:=0 to 5 do begin
    x:=cx+SRound(34*cos(t*0.7+i*1.05));
    y:=cy+SRound(34*sin(t*0.7+i*1.05));
    draw.FillRRect(x-40,y-40,x+40,y+40,$60FF8060+(i shl 18),16);
  end;
  gfx.target.BlendMode(blAlpha);
  txt.Write(bodyFont,(innerR.Left+innerR.Right) div 2+10,innerR.Bottom-12,$FFB7C8DC,'blAdd',taLeft,0);
end;

procedure TMainScene.Render;
var
  menuRect,contentRect:TRect;
  dpiNow:integer;
begin
  UpdateMetrics;
  UpdateAnimTime;
  dpiNow:=window.screenDPI;
  if dpiNow<>lastDPI then begin
    lastDPI:=dpiNow;
    RebuildFonts;
  end;
  HandleInput;
  gfx.target.Clear($FF151C27);

  menuRect:=Rect(0,0,menuWidth-1,window.renderHeight-1);
  contentRect:=Rect(menuWidth+contentPadding,contentPadding,
    window.renderWidth-contentPadding-1,window.renderHeight-contentPadding-1);

  DrawMenu(menuRect);
  DrawScreenTitle(contentRect,SCREEN_TITLES[currentScreen],SCREEN_HINTS[currentScreen]);

  case currentScreen of
    0:DrawScreenLines(contentRect);
    1:DrawScreenRects(contentRect);
    2:DrawScreenFillGrad(contentRect);
    3:DrawScreenTriShade(contentRect);
    4:DrawScreenTextured(contentRect);
    5:DrawScreenCombo(contentRect);
    6:DrawScreenImageOps(contentRect);
    7:DrawScreenParticles(contentRect);
    8:DrawScreenNinePatch(contentRect);
    9:DrawScreenClipBlend(contentRect);
  end;
  FinishBlockClipping;

  txt.Write(hintFont,contentRect.Left+12,contentRect.Bottom-18,$FF9BB0C8,
    'Tip: switch screens with mouse or numeric keys [1..9,0]',taLeft,0);
  inherited;
end;

end.
