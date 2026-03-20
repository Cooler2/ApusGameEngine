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
  Types,
  Math,
  Apus.Core,
  Apus.Images,
  Apus.Colors,
  Apus.Geom2D,
  Apus.Engine.UI;

 type
  PCardinalArray=^TCardinalArray;
  TCardinalArray=array[0..0] of cardinal;

  TMainScene=class(TUIScene)
   checkerTex:TTexture;
   titleFont,captionFont,cardFont:TFontHandle;
   procedure Load; override;
   procedure Render; override;
   procedure BuildCheckerTexture;
   procedure DrawGallery;
  end;

const
 CARD_COLUMNS=4;
 CARD_COUNT=12;
 CARD_MARGIN_X=14;
 CARD_GAP_X=12;
 CARD_GAP_Y=12;
 CARD_TOP=58;
 CARD_HEIGHT=180;
 HEADER_HEIGHT=34;

var
 sceneMain:TMainScene;

constructor TMainApp.Create;
 begin
  inherited;
  gameTitle:='Apus Engine: Draw2D';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  windowWidth:=1460;
  windowHeight:=720;
  windowSizeable:=true;
 end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmWindow;
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
  row:PCardinalArray;
  color:cardinal;
 begin
  checkerTex:=AllocImage(64,64,ipfARGB,aiTexture,'PrimitivesChecker');
  checkerTex.Lock;
  for y:=0 to checkerTex.height-1 do begin
   row:=PCardinalArray(UIntPtr(checkerTex.data)+UIntPtr(y*checkerTex.pitch));
   for x:=0 to checkerTex.width-1 do begin
    if ((x div 8+y div 8) and 1)=0 then
     color:=$FF90B0E0
    else
     color:=$FF204070;
    row^[x]:=color;
   end;
  end;
  checkerTex.Unlock;
 end;

procedure TMainScene.Load;
 begin
  titleFont:=txt.GetFont('Default',10);
  captionFont:=txt.GetFont('Default',8);
  cardFont:=txt.GetFont('Default',7);
  BuildCheckerTexture;
  loaded:=true;
 end;

procedure CardRects(index,cardWidth:integer;out outer,body:TRect);
 var
  col,row,left,top:integer;
 begin
  col:=index mod CARD_COLUMNS;
  row:=index div CARD_COLUMNS;
  left:=CARD_MARGIN_X+col*(cardWidth+CARD_GAP_X);
  top:=CARD_TOP+row*(CARD_HEIGHT+CARD_GAP_Y);
  outer:=Rect(left,top,left+cardWidth-1,top+CARD_HEIGHT-1);
  body:=Rect(outer.Left+8,outer.Top+HEADER_HEIGHT,outer.Right-8,outer.Bottom-8);
 end;

procedure DrawCardBase(const outer:TRect;title:string;subtitle:string;fontTitle,fontCaption:TFontHandle);
 begin
  draw.FillRRect(outer.Left,outer.Top,outer.Right,outer.Bottom,$FF1F2734,8);
  draw.RRect(outer.Left,outer.Top,outer.Right,outer.Bottom,1,8,$FF4A5F7A);
  draw.FillRect(outer.Left+1,outer.Top+1,outer.Right-1,outer.Top+HEADER_HEIGHT-1,$FF273244);
  draw.Line(outer.Left+1,outer.Top+HEADER_HEIGHT,outer.Right-1,outer.Top+HEADER_HEIGHT,$FF425268);
  txt.Write(fontTitle,outer.Left+8,outer.Top+11,$FFE8EEF8,title);
  txt.Write(fontCaption,outer.Left+8,outer.Top+25,$FF99A9C0,subtitle);
 end;

procedure TMainScene.DrawGallery;
 var
  i,w:integer;
  outer,body:TRect;
  p:array[0..7] of TVec2;
  x1,y1,x2,y2,mx,my:single;
  t:single;
 begin
  w:=(window.renderWidth-CARD_MARGIN_X*2-CARD_GAP_X*(CARD_COLUMNS-1)) div CARD_COLUMNS;

  // 0: lines + polyline
  i:=0;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'Line + Polyline','basic line primitives',cardFont,cardFont);
  for i:=0 to 6 do
   draw.Line(body.Left+10,body.Top+8+i*13,body.Right-10,body.Top+8+i*13,$FF203850+i*$00161507);
  p[0].x:=body.Left+14; p[0].y:=body.Bottom-40;
  p[1].x:=body.Left+34; p[1].y:=body.Bottom-58;
  p[2].x:=body.Left+58; p[2].y:=body.Bottom-34;
  p[3].x:=body.Left+84; p[3].y:=body.Bottom-54;
  p[4].x:=body.Left+108; p[4].y:=body.Bottom-28;
  p[5].x:=body.Left+132; p[5].y:=body.Bottom-44;
  draw.Polyline(@p[0],6,$FFFFC060,false);
  draw.Polyline(@p[0],6,$8040E0FF,true);

  // 1: polygon
  i:=1;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'Polygon','convex fill with 5+ points',cardFont,cardFont);
  p[0].x:=body.Left+20;  p[0].y:=body.Top+35;
  p[1].x:=body.Left+70;  p[1].y:=body.Top+12;
  p[2].x:=body.Right-18; p[2].y:=body.Top+40;
  p[3].x:=body.Right-30; p[3].y:=body.Bottom-18;
  p[4].x:=body.Left+40;  p[4].y:=body.Bottom-12;
  draw.Polygon(@p[0],5,$FF5CB3D8);
  draw.Polyline(@p[0],5,$FFE8F8FF,true);

  // 2: rect overloads
  i:=2;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'Rect','integer and subpixel overloads',cardFont,cardFont);
  draw.Rect(body.Left+12,body.Top+12,body.Right-12,body.Bottom-12,$FFE0C060);
  draw.Rect(body.Left+26.5,body.Top+26.5,body.Right-26.5,body.Bottom-26.5,$FF90D0F0);
  draw.Rect(body.Left+42,body.Top+44,body.Right-44,body.Bottom-40,$FFFF8A70);

  // 3: rounded rect outline
  i:=3;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'RRect','thin and thick rounded borders',cardFont,cardFont);
  draw.RRect(body.Left+10,body.Top+10,body.Right-10,body.Top+50,$FFE8B078,9);
  draw.RRect(body.Left+20,body.Top+62,body.Right-20,body.Bottom-16,3,14,$FF71D6A2);
  draw.RRect(body.Left+30,body.Top+74,body.Right-30,body.Bottom-28,1,9,$FF2B3E56);

  // 4: fill rect + gradrect
  i:=4;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'FillRect + FillGradrect','solid, alpha and directional gradient',cardFont,cardFont);
  draw.FillRect(body.Left+10,body.Top+10,body.Left+78,body.Top+62,$A0E87357);
  draw.FillRect(body.Left+62,body.Top+26,body.Left+144,body.Top+86,$8098E7A0);
  draw.FillGradrect(body.Left+156,body.Top+10,body.Right-10,body.Top+62,$FF5070D0,$FFB0E0FF,true);
  draw.FillGradrect(body.Left+156,body.Top+74,body.Right-10,body.Top+126,$FFF0A040,$FF7030A0,false);

  // 5: fill triangle
  i:=5;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'FillTriangle','vertex color interpolation',cardFont,cardFont);
  x1:=body.Left+26; y1:=body.Bottom-20;
  x2:=body.Right-28; y2:=body.Bottom-14;
  x3:=(body.Left+body.Right)*0.5; y3:=body.Top+14;
  draw.FillTriangle(x1,y1,x2,y2,x3,y3,$FFE05050,$FF50E070,$FF5070E0);
  draw.Line(x1,y1,x2,y2,$FFD0D8E8);
  draw.Line(x2,y2,x3,y3,$FFD0D8E8);
  draw.Line(x3,y3,x1,y1,$FFD0D8E8);

  // 6: fill rounded rect
  i:=6;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'FillRRect','rounded filled blocks',cardFont,cardFont);
  draw.FillRRect(body.Left+10,body.Top+12,body.Left+96,body.Top+68,$FF4E88D6,12);
  draw.FillRRect(body.Left+54,body.Top+54,body.Right-12,body.Bottom-14,$C0E08A68,18);
  draw.RRect(body.Left+54,body.Top+54,body.Right-12,body.Bottom-14,1,18,$FFF7E8DD);

  // 7: shaded rect
  i:=7;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'ShadedRect','UI-like bevel depth',cardFont,cardFont);
  draw.ShadedRect(body.Left+16,body.Top+14,body.Right-16,body.Top+52,3,$FFC8D2DF,$FF44556A);
  draw.ShadedRect(body.Left+16,body.Top+70,body.Right-16,body.Top+108,1,$FFCED8E7,$FF3E4D61);
  draw.FillRect(body.Left+20,body.Top+116,body.Right-20,body.Bottom-16,$304A5E79);

  // 8: gradient mode
  i:=8;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'WithGradient / NoGradient','global primitive gradient override',cardFont,cardFont);
  draw.WithGradient($FFE7AA54,$FF4B90D9,Pi/5);
  draw.FillRect(body.Left+10,body.Top+12,body.Right-10,body.Top+60,$FFFFFFFF);
  draw.WithGradient($FF6EDFAA,$FF3A4E98,0.0,0.6);
  draw.FillRRect(body.Left+24,body.Top+74,body.Right-24,body.Bottom-14,$FFFFFFFF,12);
  draw.NoGradient;
  draw.Rect(body.Left+24,body.Top+74,body.Right-24,body.Bottom-14,$FFE8F4FF);

  // 9: round rect helper
  i:=9;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'RoundRect helper','border+fill in one call',cardFont,cardFont);
  draw.RoundRect(body.Left+12,body.Top+12,body.Right-12,body.Top+64,12,2,$FFF5E1A2,$D0835030);
  draw.RoundRect(body.Left+28,body.Top+76,body.Right-28,body.Bottom-16,16,0,$00000000,$B03A8CB8);
  draw.RoundRect(body.Left+40,body.Top+90,body.Right-40,body.Bottom-30,10,1,$FFE8F4FF,$702B3C4E);

  // 10: textured rect
  i:=10;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'TexturedRect','with color tint and custom UV',cardFont,cardFont);
  if checkerTex<>nil then begin
   draw.TexturedRect(Rect(body.Left+8,body.Top+10,body.Left+100,body.Top+102),checkerTex,$FF90A0FF);
   draw.TexturedRect(Rect(body.Left+112,body.Top+10,body.Right-10,body.Top+102),checkerTex,$FFB0FFB0);
   draw.TexturedRect(body.Left+24,body.Top+112,body.Right-20,body.Bottom-12,
    checkerTex,0,0,1,0,0.22,1,$FFFFFFFF);
   draw.Rect(body.Left+24,body.Top+112,body.Right-20,body.Bottom-12,$FFE5EEF8);
  end;

  // 11: animated combination
  i:=11;
  CardRects(i,w,outer,body);
  DrawCardBase(outer,'Combined example','animated mix of primitives',cardFont,cardFont);
  mx:=(body.Left+body.Right)*0.5;
  my:=(body.Top+body.Bottom)*0.5;
  t:=window.frameStartTime*0.002;
  draw.FillRect(body.Left+10,body.Top+10,body.Right-10,body.Bottom-10,$182B3C50);
  draw.RRect(body.Left+12,body.Top+12,body.Right-12,body.Bottom-12,2,12,$FF7E96B4);
  draw.Line(mx,my,mx+cos(t)*56,my+sin(t)*40,$FFFFCB75);
  draw.Line(mx,my,mx+cos(t+2.09)*56,my+sin(t+2.09)*40,$FF86E7A3);
  draw.Line(mx,my,mx+cos(t+4.18)*56,my+sin(t+4.18)*40,$FF6BA0F2);
  draw.FillRRect(round(mx-10),round(my-10),round(mx+10),round(my+10),$FFF1F4FA,8);
 end;

procedure TMainScene.Render;
 begin
  gfx.target.Clear($FF151B24);
  draw.FillGradrect(0,0,window.renderWidth-1,52,$FF1E2736,$FF151B24,false);
  txt.Write(titleFont,14,16,$FFEAF1FC,'2D Primitives Gallery');
  txt.Write(captionFont,14,36,$FF9FB1CA,
   'Modern standalone demo replacing old EngineDemo primitive section');

  DrawGallery;
  inherited;
 end;

end.
