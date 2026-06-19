// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit ParticlesMain;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses SysUtils,Apus.Common,Apus.EventMan,Apus.Colors,Apus.Geom3D, Math,
   Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Initialize; override;
   procedure Render; override;
   procedure onMouseMove(x,y:integer); override;
   procedure onMouseWheel(delta:integer); override;
  end;

 var
  sceneMain:TMainScene;
  baseDir:string;
  tex:TTexture;
  depthTex:TTexture;
  cameraAngleX:single=0.8;
  cameraAngleY:single=0.7;
  cameraZoom:TAnimatedValue;

  particles:array of TParticle;
  testProc:TProcedure;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Particles demo - Apus Game Engine'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  //directRenderOnly:=false;
  //useDepthTexture:=true;
  //windowedMode:=false;
  if DirectoryExists('..\Demo\Particles') then
   baseDir:='..\Demo\Particles\';
 end;

procedure SetupCamera;
 var
  cameraPos:TVec3;
 begin
  transform.Perspective(1/cameraZoom.Value,1,1000);
  cameraPos.x:=30*cos(cameraAngleX)*cos(cameraAngleY);
  cameraPos.y:=30*sin(cameraAngleX)*cos(cameraAngleY);
  cameraPos.z:=30*sin(cameraAngleY);
  transform.SetCamera(cameraPos,Point3s(0,0,1),Point3s(0,0,100000));
 end;

procedure BasicTest;
 begin
  gfx.target.Clear($406080,1);
  SetupCamera;

  gfx.target.SetDepthMode(TDepthTest.Pass);

  gfx.SetCullMode(TCullMode.DrawAll);
  transform.Transform(Point3(0,0,0));
  gfx.clip.Nothing;
  // 2D primitives are drawn on XY plane (z=0) so it's OK to draw floor like this :)
  draw.TexturedRect(-20,-20,20,20,game.defaultTexture,-0.125,-0.125,10.125,-0.125,10.125,10.125,$FFFFFFFF);
  // X axis
  draw.Line(0,0,10,0,$FF000090);
  draw.Line(10,0,9,1,$FF000090);
  draw.Line(10,0,9,-1,$FF000090);
  // Y axis
  draw.Line(0,0,0,10,$FF007000);
  draw.Line(0,10,1,9,$FF007000);
  draw.Line(0,10,-1,9,$FF007000);

  gfx.clip.Restore;

  draw.Particles(@particles[0],length(particles),tex,16);
  transform.DefaultView;
 end;

procedure StartBasicTest;
 var
  i:integer;
 begin
  // Particles
  SetLength(particles,5);
  for i:=0 to high(particles) do
   with particles[i] do begin
    x:=i*2;
    y:=0;
    z:=2;
    color:=Color.ARGB(255-i*30,128,128,128);
    scale:=1+i*0.2;
    angle:=i*0.2;
    index:=i and 1;
   end;

  testProc:=BasicTest;
  UIElement('Menu').Hide;
 end;

procedure Start3DEffect;
 var
  i:integer;
 begin
  // Particles
  SetLength(particles,5);
  for i:=0 to high(particles) do
   with particles[i] do begin
    x:=i*2;
    y:=0;
    z:=2;
    color:=Color.ARGB(255-i*30,128,128,128);
    scale:=1+i*0.2;
    angle:=i*0.2;
    index:=i and 1;
   end;

  testProc:=BasicTest;
  UIElement('Menu').Hide;
 end;

procedure GalaxyTest;
 begin
  gfx.target.Clear(0,1);
  SetupCamera;

  gfx.target.SetDepthMode(TDepthTest.Disabled);
  gfx.target.BlendMode(blAdd);
  draw.Particles(@particles[0],sizeof(TParticle),length(particles),tex,16,false);
  gfx.target.BlendMode(blAlpha);
  transform.DefaultView;
  cameraAngleX:=cameraAngleX+0.002;
  if cameraAngleY>0.2 then
   cameraAngleY:=cameraAngleY-0.0002;
 end;

procedure StartGalaxy;
 var
  i:integer;
  a,r:single;
  vec:TVec3;
 begin
  // Particles
  SetLength(particles,300000);
  for i:=0 to high(particles) do
   with particles[i] do begin
    r:=(random-random+random-random)*20;
    if abs(r)<3+random*15 then begin
     vec.Init(random-random+random-random+random-random+random-random,
        random-random+random-random+random-random+random-random,
        random-random+random-random+random-random+random-random);
     r:=vec.Length;
     vec.Multiply(r*1.2+0.2*r*r);
     x:=vec.x;
     y:=vec.y;
     z:=5+vec.z*0.4;
    end else begin
     a:=sqr(random-random+random-random)+random-random+abs(r)*0.22;
     x:=r*cos(a)+random-random;
     y:=r*sin(a)+random-random;
     z:=5+(random-random+random-random+random-random)*0.5;
    end;
    color:=Color.ARGB(150,random(random(120)),random(random(120)),random(random(120)));
    scale:=(3+random(random(10)))*0.04;
    angle:=i/10;
    index:=partPosV*1;
   end;

  testProc:=GalaxyTest;
  UIElement('Menu').Hide;
 end;

procedure SoftTest;
 var
  i,n:integer;
 begin
  gfx.target.Clear(0,1);
  SetupCamera;
  gfx.target.SetDepthMode(TDepthTest.Pass);

  gfx.SetCullMode(TCullMode.DrawAll);
  transform.Transform(Point3(0,0,0));
  gfx.clip.Nothing;
  // 2D primitives are drawn on XY plane (z=0) so it's OK to draw floor like this :)
  draw.TexturedRect(-20,-20,20,20,game.defaultTexture,-0.125,-0.125,10.125,-0.125,10.125,10.125,$FFA09070);
  // X axis
  draw.Line(0,0,10,0,$FF000090);
  draw.Line(10,0,9,1,$FF000090);
  draw.Line(10,0,9,-1,$FF000090);
  // Y axis
  draw.Line(0,0,0,10,$FF007000);
  draw.Line(0,10,1,9,$FF007000);
  draw.Line(0,10,-1,9,$FF007000);

  gfx.clip.Restore;

  n:=0;
  for i:=0 to high(particles) do begin
   if particles[i].custom=0 then begin
    if n>1 then continue;
    inc(n);
    particles[i].x:=(random-random)*6;
    particles[i].y:=(random-random)*6;
    particles[i].z:=-2;
    particles[i].scale:=1+random;
    particles[i].custom:=100;
    particles[i].index:=i mod 2;
   end else begin
    dec(particles[i].custom);
    //particles[i].x:=particles[i].x*1.001+0.001*((i*49 mod 13)-6);
    //particles[i].y:=particles[i].y*1.001+0.001*(((i+16)*67 mod 15)-7);
    particles[i].z:=particles[i].z+0.07+(i mod 3)*0.002;
    particles[i].angle:=0;
    //particles[i].scale:=particles[i].scale+0.01;
   end;
   particles[i].color:=Color.GrayAlpha(PikeS(1-particles[i].custom/100,0.2,1,1,0));
  end;

  gfx.target.SetDepthMode(TDepthTest.Less,TDepthWrite.Off);
  draw.EnableSoftParticles(0.9);
  draw.Particles(@particles[0],length(particles),tex,16);

  gfx.target.SetDepthMode(TDepthTest.Disabled);
  transform.DefaultView;

 end;

procedure StartSoft;
 begin
  AllocImage(window.renderWidth,window.renderHeight,TImagePixelFormat.ipfDepth32f,aiDepthBuffer,'DepthTex');
  SetLength(particles,300);
  testProc:=SoftTest;
  UIElement('Menu').Hide;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  game.SwitchToScene('Main');
 end;

{ TMainScene }
procedure TMainScene.onMouseMove(x,y:integer);
 begin
  inherited;
  // Turn camera around
  if window.mouseButtons and mbLeft>0 then begin
   cameraAngleX:=cameraAngleX-(x-window.oldMousePos.x)*0.01;
   cameraAngleY:=Clamp(cameraAngleY+(y-window.oldMousePos.y)*0.005, 0.1,1.2);
  end;
 end;

procedure TMainScene.onMouseWheel(delta:integer);
 begin
  inherited;
  // Camera zoom
  if (delta<0) and (cameraZoom.FinalValue>0.7) then
   cameraZoom.Animate(cameraZoom.FinalValue/1.3,250,splines.easeInOut);
  if (delta>0) and (cameraZoom.FinalValue<3) then
   cameraZoom.Animate(cameraZoom.FinalValue*1.3,250,splines.easeInOut);
 end;

procedure TMainScene.Initialize;
 var
  i,x,y:integer;
  c:cardinal;
  panel:TUIElement;
 begin
  inherited;
  cameraZoom.Init(1);
  // Particle image
  tex:=LoadImageFromFile(baseDir+'res\particles');

  panel:=TUIElement.Create(200,200,UI,'Menu');
  panel.Center;
  panel.layout:=TRowLayout.CreateVertical(10,true);
  TUIButton.Create(180,35,panel,'Menu\Demo').Setup('Basic Test').onClickAsync:=StartBasicTest;
  TUIButton.Create(180,35,panel,'Menu\Demo2').Setup('3D Effect').onClickAsync:=Start3DEffect;
  TUIButton.Create(180,35,panel,'Menu\Demo3').Setup('Galaxy').onClickAsync:=StartGalaxy;
  TUIButton.Create(180,35,panel,'Menu\Demo4').Setup('Soft Particles').onClickAsync:=StartSoft;
 end;

procedure TMainScene.Render;
 begin
  if @testProc<>nil then TestProc
   else gfx.target.Clear($406080,1);

  inherited;
 end;

end.
