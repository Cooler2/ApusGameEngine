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
  Apus.Engine.UI;

type
  TMainScene=class(TUIScene)
    checkerTex,helperTex,atlasTex:TTexture;
    particles:array[0..47] of TParticle;
    bandParts:array[0..15] of TParticle;
    titleFont,menuFont,hintFont,bodyFont:TFontHandle;
    currentScreen:integer;
    layoutScale:single;
    menuWidth,menuTop,menuItemHeight,contentPadding,screenTopOffset:integer;
    lastDPI:integer;
    procedure Load; override;
    procedure Render; override;
    procedure BuildCheckerTexture;
    procedure BuildHelperTexture;
    procedure BuildAtlasTexture;
    procedure InitParticles;
    procedure UpdateMetrics;
    procedure RebuildFonts;
    procedure HandleInput;
    procedure DrawMenu(const menuRect:TRect);
    procedure DrawScreenTitle(const contentRect:TRect; const title,subtitle:string);
    procedure DrawScreenLines(const contentRect:TRect);
    procedure DrawScreenRects(const contentRect:TRect);
    procedure DrawScreenFillGrad(const contentRect:TRect);
    procedure DrawScreenTriShade(const contentRect:TRect);
    procedure DrawScreenTextured(const contentRect:TRect);
    procedure DrawScreenCombo(const contentRect:TRect);
    procedure DrawScreenImageOps(const contentRect:TRect);
    procedure DrawScreenParticles(const contentRect:TRect);
  end;

const
  SCREEN_COUNT=8;
  MENU_WIDTH=360;
  MENU_TOP=76;
  MENU_ITEM_HEIGHT=58;
  CONTENT_PADDING=18;

SCREEN_TITLES:array[0..SCREEN_COUNT-1] of string=(
  'Lines && Paths',
  'Rects && Rounded',
  'Fill && Gradients',
  'Triangles && Shading',
  'TexturedRect && UV',
  'Combined Playground',
  'Image Helpers',
  'Particles && Band'
);

SCREEN_HINTS:array[0..SCREEN_COUNT-1] of string=(
  'Line / Polyline / Polygon',
  'Rect / RRect / RoundRect',
  'FillRect / FillRRect / FillGradrect / WithGradient',
  'FillTriangle / ShadedRect',
  'TexturedRect overloads',
  'Mixed static + animated cases',
  'Image / Centered / Scaled / Cover / Inside / DoubleTex',
  'Particles / Band / SetZ'
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
  row:PCardinal;
  color:cardinal;
begin
  checkerTex:=AllocImage(96,96,ipfARGB,aiTexture,'Draw2DChecker');
  checkerTex.Lock;
  for y:=0 to checkerTex.height-1 do begin
    row:=PCardinal(UIntPtr(checkerTex.data)+UIntPtr(y*checkerTex.pitch));
    for x:=0 to checkerTex.width-1 do begin
      if ((x div 12+y div 12) and 1)=0 then
        color:=$FF9ABBE7
      else
        color:=$FF24466F;
      row^:=color;
      inc(row);
    end;
  end;
  checkerTex.Unlock;
end;

procedure TMainScene.BuildHelperTexture;
var
  x,y,w,h,cx,cy:integer;
  row:PCardinal;
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
    row:=PCardinal(UIntPtr(helperTex.data)+UIntPtr(y*helperTex.pitch));
    for x:=0 to w-1 do begin
      dx:=x-cx;
      dy:=y-cy;
      dist:=sqrt(dx*dx+dy*dy);
      alpha:=Clamp((58-dist)*0.08,0,1);
      col:=ColorMixF($FF3D6EA8,$FF9DD2F0,Clamp((x+y)/(w+h),0,1));
      row^:=(round(alpha*255) shl 24) or (col and $FFFFFF);
      inc(row);
    end;
  end;
  helperTex.Unlock;
end;

procedure TMainScene.BuildAtlasTexture;
var
  x,y,w,h,cx,cy,cxCell,cyCell:integer;
  row:PCardinal;
  cellX,cellY:integer;
  baseCol,col:cardinal;
  dx,dy,dist:single;
begin
  w:=128;
  h:=128;
  atlasTex:=AllocImage(w,h,ipfARGB,aiTexture,'Draw2DAtlas');
  atlasTex.Lock;
  for y:=0 to h-1 do begin
    row:=PCardinal(UIntPtr(atlasTex.data)+UIntPtr(y*atlasTex.pitch));
    for x:=0 to w-1 do begin
      cellX:=x div 32;
      cellY:=y div 32;
      cxCell:=cellX*32+16;
      cyCell:=cellY*32+16;
      dx:=x-cxCell;
      dy:=y-cyCell;
      dist:=sqrt(dx*dx+dy*dy);
      baseCol:=ColorMixF($FF2A3A54,$FF82B8EA,(cellX+cellY*4)/15);
      col:=baseCol;
      if dist<11 then
        col:=ColorMixF($FFFFFFFF,baseCol,dist/11)
      else
      if dist>14 then
        col:=ColorMixF(baseCol,$FF1A2538,Clamp((dist-14)/7,0,1));
      row^:=$FF000000 or (col and $FFFFFF);
      inc(row);
    end;
  end;
  atlasTex.Unlock;
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
    particles[i].color:=ColorMixF($FFA0C8FF,$FFFFB080,frac(i*0.13));
    particles[i].scale:=0.7+frac(i*0.19)*0.9;
    particles[i].angle:=t*0.6;
    particles[i].index:=((i and 3)*partPosU)+(((i shr 2) and 3)*partPosV);
  end;

  for i:=0 to high(bandParts) do begin
    t:=i/(high(bandParts)+1);
    bandParts[i].x:=20+i*40;
    bandParts[i].y:=60+round(sin(t*Pi*2)*20);
    bandParts[i].z:=0;
    bandParts[i].color:=ColorMixF($FF60D0FF,$FFFFD080,t);
    bandParts[i].scale:=0.8+0.4*sin(t*Pi);
    bandParts[i].angle:=0;
    bandParts[i].index:=round(255*t);
  end;
  bandParts[high(bandParts)].index:=bandParts[high(bandParts)].index or partEndpoint;
end;

procedure TMainScene.Load;
begin
  lastDPI:=0;
  currentScreen:=0;
  UpdateMetrics;
  RebuildFonts;
  BuildCheckerTexture;
  BuildHelperTexture;
  BuildAtlasTexture;
  InitParticles;
  loaded:=true;
end;

  procedure TMainScene.UpdateMetrics;
  begin
    layoutScale:=window.screenDPI/96;
    if layoutScale<1 then layoutScale:=1;
    menuWidth:=MENU_WIDTH+round((layoutScale-1)*110);
    menuWidth:=ClampI(menuWidth,340,window.renderWidth div 2);
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
      result:=Math.Max(6,round(baseSize*fs));
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
begin
  for i:=0 to SCREEN_COUNT-1 do begin
    if IsKeyPressed(ord(TKey.D1)+i) or IsKeyPressed(ord(TKey.Num1)+i) then
      currentScreen:=i;
  end;

  if LMBClicked and (window.mouseX>=0) and (window.mouseX<menuWidth) and
     (window.mouseY>=menuTop) then begin
    item:=(window.mouseY-menuTop) div menuItemHeight;
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

  txt.Write(titleFont,20,30,$FFE8F0FA,'Draw2D Screens',taLeft,toAddBaseline);
  txt.Write(hintFont,20,52,$FFA4B7CE,'Mouse click or keys [1..8]',taLeft,toAddBaseline);

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
    txt.Write(menuFont,r.Left+12,r.Top+18,txtCol,IntToStr(i+1)+'. '+SCREEN_TITLES[i],taLeft,toAddBaseline);
  end;
end;

procedure TMainScene.DrawScreenTitle(const contentRect:TRect; const title,subtitle:string);
begin
  draw.FillRect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF1F2A3A);
  draw.Rect(contentRect.Left,contentRect.Top,contentRect.Right,contentRect.Top+screenTopOffset-10,$FF3D5067);
  txt.Write(titleFont,contentRect.Left+14,contentRect.Top+20,$FFEAF2FC,title,taLeft,toAddBaseline);
  txt.Write(hintFont,contentRect.Left+14,contentRect.Top+42,$FFA8BDD5,subtitle,taLeft,toAddBaseline);
end;

procedure TMainScene.DrawScreenLines(const contentRect:TRect);
var
  r1,r2:TRect;
  p:array[0..8] of TVec2;
  i:integer;
  t:single;
begin
  r1:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+560,contentRect.Bottom-20);
  r2:=Rect(contentRect.Left+580,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  FillChar(p,SizeOf(p),0);
  draw.FillRRect(r1.Left,r1.Top,r1.Right,r1.Bottom,$FF202D3D,10);
  draw.FillRRect(r2.Left,r2.Top,r2.Right,r2.Bottom,$FF202D3D,10);

  for i:=0 to 13 do
    draw.Line(r1.Left+20,r1.Top+20+i*22,r1.Right-20,r1.Top+20+i*22,$FF304A66+i*$00090909);

  p[0].Init(r2.Left+40,r2.Bottom-70);
  p[1].Init(r2.Left+130,r2.Top+40);
  p[2].Init(r2.Left+200,r2.Bottom-120);
  p[3].Init(r2.Left+280,r2.Top+65);
  p[4].Init(r2.Left+360,r2.Bottom-80);
  p[5].Init(r2.Left+430,r2.Top+45);
  p[6].Init(r2.Right-70,r2.Bottom-95);
  draw.Polyline(@p[0],7,$FFFFD070,false);
  draw.Polyline(@p[0],7,$9040E0FF,true);

  t:=window.frameStartTime*0.0025;
  for i:=0 to 5 do begin
    draw.Line(r2.Left+40,r2.Top+220,
      r2.Left+240+cos(t+i)*170,
      r2.Top+220+sin(t*1.2+i)*120,
      $FFA0D8FF-i*$00141000);
  end;
end;

procedure TMainScene.DrawScreenRects(const contentRect:TRect);
var
  a,b:TRect;
  t:single;
begin
  a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+620,contentRect.Bottom-20);
  b:=Rect(contentRect.Left+640,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF212D3E,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF212D3E,10);

  draw.Rect(a.Left+22,a.Top+20,a.Right-22,a.Bottom-22,$FFE9BE78);
  draw.Rect(a.Left+48.5,a.Top+46.5,a.Right-48.5,a.Bottom-48.5,$FF87D3FF);

  draw.RRect(a.Left+70,a.Top+80,a.Right-70,a.Top+170,$FFE7A870,14);
  draw.RRect(a.Left+90,a.Top+200,a.Right-90,a.Top+320,4,18,$FF79DAA9);
  draw.FillRRect(a.Left+140,a.Top+345,a.Right-140,a.Bottom-40,$B0B7704A,16);
  draw.RRect(a.Left+140,a.Top+345,a.Right-140,a.Bottom-40,1,16,$FFFFE9D0);

  t:=window.frameStartTime*0.002;
  draw.RoundRect(
    TVec2.Init((b.Left+b.Right)*0.5,b.Top+150),
    360+sin(t)*120,170+cos(t*1.3)*45,
    26+sin(t*1.5)*8,3,$FFBFD8F7,$704F6FA4);
  draw.RoundRect(b.Left+80,b.Top+250,b.Right-80,b.Bottom-40,24,0,$00000000,$A05295C0);
  draw.RoundRect(b.Left+120,b.Top+285,b.Right-120,b.Bottom-75,14,1,$FFEAF6FF,$80435A73);
end;

procedure TMainScene.DrawScreenFillGrad(const contentRect:TRect);
var
  a,b:TRect;
  g:TColorGradient;
  t:single;
begin
  a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+620,contentRect.Bottom-20);
  b:=Rect(contentRect.Left+640,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202C3C,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202C3C,10);

  draw.FillRect(a.Left+24,a.Top+24,a.Left+250,a.Top+180,$B0E97B5A);
  draw.FillRect(a.Left+210,a.Top+70,a.Right-24,a.Top+250,$909CE8A8);
  draw.FillRect(a.Left+80.5,a.Top+280.5,a.Right-100.5,a.Top+380.5,$70D8D8FF);
  draw.FillGradrect(a.Left+24,a.Top+410,a.Right-24,a.Bottom-24,$FF4A74D4,$FFC7ECFF,true);

  draw.FillGradrect(b.Left+24,b.Top+24,b.Right-24,b.Top+180,$FFF0A040,$FF7030A0,false);
  draw.FillGradrect(b.Left+24,b.Top+210,b.Right-24,b.Top+360,$FFE06060,$FF50A0E0,true);

  t:=window.frameStartTime*0.0015;
  draw.WithGradient($FFF1B45F,$FF4F92D8,t,0.7+0.2*sin(t));
  draw.FillRRect(b.Left+70,b.Top+390,b.Right-70,b.Bottom-120,$FFFFFFFF,18);
  g.Init($FF73DCAA,$FF4B4EA9,t+Pi*0.5,0.55);
  draw.WithGradient(g,true);
  draw.FillRect(b.Left+100,b.Bottom-100,b.Right-100,b.Bottom-30,$FFFFFFFF);
  draw.NoGradient;
  draw.Rect(b.Left+70,b.Top+390,b.Right-70,b.Bottom-120,$FFE7F1FF);
end;

procedure TMainScene.DrawScreenTriShade(const contentRect:TRect);
var
  a,b:TRect;
  cx,cy,t:single;
  i:integer;
begin
  a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+620,contentRect.Bottom-20);
  b:=Rect(contentRect.Left+640,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,10);

  draw.FillTriangle(a.Left+60,a.Bottom-40,a.Right-70,a.Bottom-30,(a.Left+a.Right)*0.5,a.Top+26,
    $FFE96A6A,$FF63E18C,$FF5A86ED);
  draw.FillTriangle(a.Left+110,a.Bottom-120,a.Right-120,a.Bottom-100,(a.Left+a.Right)*0.5,a.Top+120,
    $60FFFFFF,$C0FFD080,$50A0B0FF);

  draw.ShadedRect(b.Left+60,b.Top+40,b.Right-60,b.Top+120,3,$FFD0DCEC,$FF4A5C71);
  draw.ShadedRect(b.Left+60,b.Top+160,b.Right-60,b.Top+230,1,$FFD3E0EE,$FF415266);
  draw.ShadedRect(b.Left+120,b.Top+280,b.Right-120,b.Top+360,2,$FFD0DCEC,$FF455A72);

  cx:=(b.Left+b.Right)*0.5;
  cy:=b.Top+500;
  t:=window.frameStartTime*0.0022;
  for i:=0 to 2 do
    draw.FillTriangle(cx,cy,cx+cos(t+i*2.09)*180,cy+sin(t+i*2.09)*120,
      cx+cos(t+i*2.09+0.9)*170,cy+sin(t+i*2.09+0.9)*120,
      $30FF8060+i*$00202020,$50A0C0FF,$30A0FFB0);
  draw.FillRRect(round(cx-14),round(cy-14),round(cx+14),round(cy+14),$FFEFF5FC,12);
end;

procedure TMainScene.DrawScreenTextured(const contentRect:TRect);
var
  a,b:TRect;
  t,s:single;
begin
    a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+620,contentRect.Bottom-20);
    b:=Rect(contentRect.Left+640,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,10);
  if checkerTex=nil then exit;

  draw.TexturedRect(Rect(a.Left+30,a.Top+30,a.Left+280,a.Top+280),checkerTex,$FF8CB0FF);
  draw.TexturedRect(Rect(a.Left+310,a.Top+30,a.Right-30,a.Top+280),checkerTex,$FFB6F0B0);
  draw.TexturedRect(a.Left+100,a.Top+330,a.Right-100,a.Bottom-40,checkerTex,0,0,1,0,0.25,1,$FFFFFFFF);
  draw.Rect(a.Left+100,a.Top+330,a.Right-100,a.Bottom-40,$FFEAF3FF);

  t:=window.frameStartTime*0.0018;
  s:=1.2+0.35*sin(t);
  draw.TexturedRect(Rect(b.Left+40,b.Top+30,b.Right-40,b.Bottom-180),checkerTex,$FF94A6C8);
  draw.RotScaled((b.Left+b.Right)*0.5,b.Bottom-95,s,s,t,checkerTex,$FFE8F0FF);
  draw.RRect(b.Left+40,b.Top+30,b.Right-40,b.Bottom-180,1,10,$FF7C91AD);
end;

procedure TMainScene.DrawScreenCombo(const contentRect:TRect);
var
  r:array[0..3] of TRect;
  i,x,y:integer;
  t:single;
  p:array[0..5] of TVec2;
begin
    r[0]:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+610,contentRect.Top+410);
    r[1]:=Rect(contentRect.Left+630,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Top+410);
    r[2]:=Rect(contentRect.Left+10,contentRect.Top+430,contentRect.Left+610,contentRect.Bottom-20);
    r[3]:=Rect(contentRect.Left+630,contentRect.Top+430,contentRect.Right-10,contentRect.Bottom-20);
  FillChar(p,SizeOf(p),0);
  for i:=0 to 3 do
    draw.FillRRect(r[i].Left,r[i].Top,r[i].Right,r[i].Bottom,$FF202D3D,10);

  // static mix
  draw.ShadedRect(r[0].Left+24,r[0].Top+24,r[0].Right-24,r[0].Top+88,2,$FFD0DCEC,$FF495B70);
  draw.FillGradrect(r[0].Left+24,r[0].Top+110,r[0].Right-24,r[0].Bottom-24,$FF5C86E0,$FF2F4565,true);
  txt.Write(bodyFont,r[0].Left+28,r[0].Top+66,$FFFFFFFF,'ShadedRect + FillGradrect',taLeft,toAddBaseline);

  // lines + polygon
  p[0].Init(r[1].Left+40,r[1].Top+260);
  p[1].Init(r[1].Left+120,r[1].Top+60);
  p[2].Init(r[1].Left+260,r[1].Top+250);
  p[3].Init(r[1].Left+360,r[1].Top+90);
  p[4].Init(r[1].Left+520,r[1].Top+250);
  draw.Polygon(@p[0],5,$4060C0FF);
  draw.Polyline(@p[0],5,$FFBEE8FF,true);
  for i:=0 to 9 do
    draw.Line(r[1].Left+28,r[1].Top+24+i*28,r[1].Right-28,r[1].Top+24+i*28,$50447296);

  // animated path
  t:=window.frameStartTime*0.003;
  x:=(r[2].Left+r[2].Right) div 2;
  y:=(r[2].Top+r[2].Bottom) div 2;
  draw.WithGradient($FFF1B25C,$FF4E8DD0,t);
  draw.FillRRect(r[2].Left+30,r[2].Top+30,r[2].Right-30,r[2].Bottom-30,$FFFFFFFF,18);
  draw.NoGradient;
  for i:=0 to 6 do
    draw.Line(x,y,x+round(cos(t+i*0.7)*220),y+round(sin(t*1.2+i*0.7)*110),$FFD8EEFF);
  draw.FillRRect(x-12,y-12,x+12,y+12,$FFFFFFFF,10);

  // textured + roundrect frame
  if checkerTex<>nil then begin
    draw.TexturedRect(Rect(r[3].Left+30,r[3].Top+30,r[3].Right-30,r[3].Bottom-30),checkerTex,$FFBACBE2);
    draw.RoundRect(r[3].Left+40,r[3].Top+40,r[3].Right-40,r[3].Bottom-40,20,3,$FFF0F8FF,$20406080);
    draw.FillTriangle(r[3].Left+100,r[3].Bottom-60,r[3].Right-100,r[3].Bottom-70,
      (r[3].Left+r[3].Right)*0.5,r[3].Top+70,$FFE96B6B,$FF66DF90,$FF6D92EF);
  end;
end;

procedure TMainScene.DrawScreenImageOps(const contentRect:TRect);
var
  a,b:TRect;
  uvRect:TRect;
  cScale,iScale:single;
begin
  a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+620,contentRect.Bottom-20);
  b:=Rect(contentRect.Left+640,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,10);
  if (checkerTex=nil) or (helperTex=nil) or (atlasTex=nil) then exit;

  // Image overloads + Centered
  draw.Image(a.Left+24,a.Top+30,checkerTex,$FF95B0FF);
  draw.Image(a.Left+170,a.Top+94,1.35,helperTex,$FFD8F4FF,0.5,0.5);
  draw.Centered(a.Left+330,a.Top+90,atlasTex,$FFFFFFFF);
  draw.Centered(a.Left+510,a.Top+90,0.8,atlasTex,$FFC0FFD0);

  // ImagePart + ImagePart90 + flip
  uvRect:=Rect(32,32,95,95);
  draw.ImagePart(a.Left+40,a.Top+220,atlasTex,$FFFFFFFF,uvRect);
  draw.ImagePart90(a.Left+160,a.Top+220,atlasTex,$FFFFFFFF,uvRect,1);
  draw.ImageFlipped(a.Left+280,a.Top+220,checkerTex,true,false,$FFE0F2FF);
  draw.ImageFlipped(a.Left+410,a.Top+220,checkerTex,false,true,$FFFFD6A0);

  // Scaled overloads
  draw.Scaled(a.Left+40,a.Top+360,a.Left+210,a.Bottom-40,checkerTex,$FFFFFFFF);
  draw.Scaled(a.Left+300,a.Top+430,0.9,helperTex,$FFD8EEFF);

  // SetZ demo: far then near
  draw.SetZ(-40);
  draw.FillRRect(a.Left+420,a.Top+360,a.Right-30,a.Bottom-40,$90274A74,14);
  draw.SetZ(40);
  draw.FillRRect(a.Left+450,a.Top+390,a.Right-60,a.Bottom-70,$C0A7D8FF,12);
  draw.SetZ(0);

  // Cover / Inside + DoubleTex / DoubleRotScaled
  draw.Rect(b.Left+24,b.Top+30,b.Right-24,b.Top+250,$FF6E8CAC);
  cScale:=draw.Cover(b.Left+24,b.Top+30,b.Right-24,b.Top+250,checkerTex,$FFFFFFFF);
  iScale:=draw.Inside(b.Left+24,b.Top+270,b.Right-24,b.Bottom-24,checkerTex,$FFFFFFFF);
  draw.Rect(b.Left+24,b.Top+270,b.Right-24,b.Bottom-24,$FF6E8CAC);
  txt.Write(bodyFont,b.Left+30,b.Top+246,$FFCFE2F8,'Cover='+FormatFloat('0.00',cScale),taLeft,toAddBaseline);
  txt.Write(bodyFont,b.Left+30,b.Bottom-28,$FFCFE2F8,'Inside='+FormatFloat('0.00',iScale),taLeft,toAddBaseline);

  draw.DoubleTex((b.Left+b.Right) div 2,b.Top+145,checkerTex,helperTex,$FFE8F8FF);
  draw.DoubleRotScaled((b.Left+b.Right)*0.5,b.Bottom-120,1.0,1.0,1.35,0.85,
    window.frameStartTime*0.0018,checkerTex,helperTex,$FFE8F8FF);
end;

procedure TMainScene.DrawScreenParticles(const contentRect:TRect);
var
  a,b:TRect;
  i:integer;
  t:single;
begin
  a:=Rect(contentRect.Left+10,contentRect.Top+screenTopOffset,contentRect.Left+620,contentRect.Bottom-20);
  b:=Rect(contentRect.Left+640,contentRect.Top+screenTopOffset,contentRect.Right-10,contentRect.Bottom-20);
  draw.FillRRect(a.Left,a.Top,a.Right,a.Bottom,$FF202D3D,10);
  draw.FillRRect(b.Left,b.Top,b.Right,b.Bottom,$FF202D3D,10);
  if atlasTex=nil then exit;

  t:=window.frameStartTime*0.0016;
  for i:=0 to high(particles) do begin
    particles[i].angle:=t+i*0.2;
    particles[i].x:=cos(t+i*0.31)*(190+30*sin(t*0.7+i));
    particles[i].y:=sin(t*1.1+i*0.43)*(95+20*cos(t*0.9+i));
  end;

  draw.FillRect(a.Left+24,a.Top+24,a.Right-24,a.Bottom-24,$30203854);
  draw.EnableSoftParticles(0);
  draw.Particles((a.Left+a.Right) div 2,(a.Top+a.Bottom) div 2,@particles[0],length(particles),atlasTex,16,280);
  draw.Particles((a.Left+a.Right) div 2,(a.Top+a.Bottom) div 2,@particles[0],SizeOf(TParticle),length(particles),
    atlasTex,16,280);

  for i:=0 to high(bandParts) do
    bandParts[i].y:=60+round(sin(t*1.8+i*0.5)*28);
  draw.FillRect(b.Left+24,b.Top+24,b.Right-24,b.Bottom-24,$30203854);
  draw.Band(b.Left+40,b.Top+130,@bandParts[0],length(bandParts),atlasTex,Rect(0,0,31,31));
  txt.Write(bodyFont,b.Left+30,b.Bottom-34,$FFD7E7F9,'Band + Particles (both 2D overloads)',taLeft,toAddBaseline);
end;

procedure TMainScene.Render;
var
  menuRect,contentRect:TRect;
  dpiNow:integer;
begin
  UpdateMetrics;
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
  end;

  txt.Write(hintFont,contentRect.Left+12,contentRect.Bottom-18,$FF9BB0C8,
    'Tip: switch screens with mouse or numeric keys [1..8]',taLeft,toAddBaseline);
  inherited;
end;

end.
