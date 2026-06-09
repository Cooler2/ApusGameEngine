// Compact first-run demo for the Apus Game Engine
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit HelloEngineApp;
interface
uses
  Apus.Engine.GameApp,
  Apus.Engine.API;

type
  THelloEngineApp=class(TGameApplication)
    constructor Create;
    procedure SetupGameSettings(var settings:TGameSettings); override;
    procedure CreateScenes; override;
  end;

var
  application:THelloEngineApp;

implementation
uses
  SysUtils,
  Math,
  Apus.EventMan,
  Apus.Colors,
  Apus.FastGFX,
  Apus.Engine.Types,
  Apus.Engine.SceneEffects,
  Apus.Engine.UI;

type
  TMainScene=class(TUIScene)
    iconTex:TTexture;
    titleFont,bodyFont:TFontHandle;
    sparkFrame:integer;
    clickCount:integer;
    procedure CreateUI;
    procedure CreateIconTexture;
    procedure TriggerSpark;
    procedure RenderBackground;
    procedure RenderSprite;
    procedure RenderSpark(cx,cy:single);
    procedure Render; override;
    destructor Destroy; override;
  end;

var
  mainScene:TMainScene;

procedure SparkButtonClick;
begin
  if mainScene<>nil then
    mainScene.TriggerSpark;
end;

{ THelloEngineApp }

constructor THelloEngineApp.Create;
var
  st:string;
begin
  {$IFDEF SDL}
  usedPlatform:=spSDL;
  {$ELSE}
  usedPlatform:=spDefault;
  {$ENDIF}
  inherited;

  st:=ExtractFileDir(ParamStr(0));
  SetCurrentDir(st);
  if DirectoryExists('../demo/HelloEngine') then
    SetCurrentDir('../demo/HelloEngine');

  gameTitle:='Apus Engine: HelloEngine';
  usedAPI:=gaOpenGL2;
  windowWidth:=1280;
  windowHeight:=720;
  windowSizeable:=false;
end;

procedure THelloEngineApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
end;

procedure THelloEngineApp.CreateScenes;
begin
  inherited;
  mainScene:=TMainScene.Create;
  mainScene.CreateIconTexture;
  mainScene.CreateUI;
  TTransitionEffect.Create(mainScene,250);
end;

{ TMainScene }

destructor TMainScene.Destroy;
begin
  FreeImage(iconTex);
  inherited;
end;

procedure TMainScene.CreateIconTexture;
var
  x,y,r,g,b:integer;
  dx,dy,dist,light:single;
begin
  iconTex:=AllocImage(64,64,TImagePixelFormat.ipfARGB,0,'HelloEngineIcon');
  DrawToTexture(iconTex);
  ClearRenderTarget(0);
  for y:=0 to 63 do
    for x:=0 to 63 do begin
      dx:=x-31.5;
      dy:=y-31.5;
      dist:=Sqrt(dx*dx+dy*dy);
      if dist>29.0 then continue;
      light:=1.0-dist/29.0;
      r:=40+round(90*light);
      g:=130+round(95*light);
      b:=170+round(70*light);
      if ((x+y) and 7)<3 then begin
        inc(r,20);
        inc(g,20);
      end;
      if (Abs(dx)<2.0) or (Abs(dy)<2.0) then begin
        r:=240;
        g:=250;
        b:=255;
      end;
      PutPixel(x,y,MyColor(255,r,g,b));
    end;
  iconTex.Unlock;
end;

procedure TMainScene.CreateUI;
var
  panel:TUIElement;
  btn:TUIButton;
begin
  panel:=TUIElement.Create(400,130,UI,'Hello\Panel');
  panel.SetPos(0.5*window.renderWidth,window.renderHeight-110,pivotCenter);
  panel.SetAnchors(0.5,1.0,0.5,1.0);
  panel.styleinfo:='fill: $CC172333; border-width: 1; border-color: $FF5EA8C8;';

  TUILabel.Create(360,26,panel,'Hello\Title').
    Centered('HelloEngine').SetPos(200,24,pivotCenter);

  btn:=TUIButton.Create(150,32,panel,'Hello\Spark').Setup('Spark');
  btn.SetPos(110,78,pivotCenter);
  btn.hint:='Trigger a small sprite effect';
  btn.onClickAsync:=@SparkButtonClick;

  btn:=TUIButton.Create(150,32,panel,'Hello\Exit').Setup('Exit');
  btn.SetPos(290,78,pivotCenter);
  Link('UI\Hello\Exit\OnClick','Engine\Cmd\Exit');
end;

procedure TMainScene.TriggerSpark;
begin
  sparkFrame:=window.frameNum;
  inc(clickCount);
end;

procedure TMainScene.RenderBackground;
var
  i,w,h:integer;
begin
  w:=window.renderWidth;
  h:=window.renderHeight;
  draw.FillGradRect(0,0,w,h,$FF101820,$FF243040,true);
  for i:=0 to 11 do
    draw.Line(0,h*i/12,w,h-h*i/18,$2048B0D8);
  draw.FillRect(0,h-92,w,h,$40203038);
end;

procedure TMainScene.RenderSprite;
var
  cx,cy,scale,angle:single;
begin
  cx:=window.renderWidth*0.5;
  cy:=window.renderHeight*0.38;
  scale:=2.35+0.12*Sin(window.frameNum*0.055);
  angle:=window.frameNum*0.018;
  draw.RotScaled(cx,cy,scale,scale,angle,iconTex);
  txt.WriteC(bodyFont,cx,cy+105,$FFD7EEF8,'procedural texture + sprite draw',toAddBaseline);
end;

procedure TMainScene.RenderSpark(cx,cy:single);
var
  i,age:integer;
  a,r,ang:single;
  color:cardinal;
begin
  if sparkFrame=0 then exit;
  age:=window.frameNum-sparkFrame;
  if age>60 then exit;

  a:=1.0-age/60.0;
  r:=28+age*2.1;
  color:=ColorAlpha($FFFFD080,a);
  for i:=0 to 9 do begin
    ang:=i*Pi/5+age*0.08;
    draw.Line(cx+Cos(ang)*20,cy+Sin(ang)*20,
      cx+Cos(ang)*r,cy+Sin(ang)*r,color);
  end;
  txt.WriteC(bodyFont,cx,cy+145,ColorAlpha($FFFFFFFF,a),
    'button signal count: '+IntToStr(clickCount),toAddBaseline);
end;

procedure TMainScene.Render;
var
  cx,cy:single;
begin
  if titleFont=0 then begin
    titleFont:=txt.GetFont('Default',13);
    bodyFont:=txt.GetFont('Default',8);
  end;

  RenderBackground;

  cx:=window.renderWidth*0.5;
  cy:=window.renderHeight*0.38;
  txt.WriteC(titleFont,cx,72,$FFFFFFFF,'Apus Engine',toAddBaseline or toWithShadow);
  txt.WriteC(bodyFont,cx,106,$FFB8D0E0,'scene, text, UI, signal, texture and a tiny effect',toAddBaseline);
  RenderSprite;
  RenderSpark(cx,cy);

  inherited;
end;

end.
