// Simple demo of the Apus Game Engine framework

// Copyright (C) 2017 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit SimpleDemoApp;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TSimpleDemoApp=class(TGameApplication)
   constructor Create;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TSimpleDemoApp;

implementation
 uses Apus.CrossPlatform,Apus.EventMan,Apus.Colors,
   Apus.Engine.SceneEffects,Apus.Engine.UIClasses,Apus.Engine.UIScene;

 type
  TParticleData=record
   dx,dy:single;
   life:integer;
  end;

  // This will be our single scene
  TMainScene=class(TUIScene)
   particles:array of TParticle;
   particlesData:array of TParticleData;
   particlesTex:TTexture;

   procedure InitParticles;
   procedure CreateUI;
   procedure HandleParticles;
   procedure Render; override;
  end;

 var
  mainScene:TMainScene;

{ TSimpleDemoApp }

constructor TSimpleDemoApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Simple Engine Demo'; // app window title
  configFileName:='SimpleDemo\game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spWindows;
  usedPlatform:=spSDL;
  directRenderOnly:=true;
  //windowedMode:=false;
 end;

// This is executed just before the game object is launched
procedure TSimpleDemoApp.SetupGameSettings(var settings: TGameSettings);
 begin
  inherited; // global settings are applied to the instance settings here, so there is no sense to change them later

  settings.mode.displayMode:=dmWindow; // run in window
  //settings.mode.displayFitMode:=dfmFullSize;

  // Here you can override instance settings
{  // Primary mode settings
  settings.mode.displayMode:=dmWindow; // run in window
  settings.mode.displayFitMode:=dfmStretch; // stretch the backbuffer to match the full window size
  settings.mode.displayScaleMode:=dsmDontScale; // use 1:1 pixel ratio
  // Secondary mode settings (for [Alt]+[Enter])
  settings.altMode.displayMode:=dmFullScreen; // use fullscreen window
  settings.altMode.displayFitMode:=dfmKeepAspectRatio; // use borders to keep the initial aspect ratio
  settings.altMode.displayScaleMode:=dsmDontScale; // use 1:1 pixel ratio
  }
 end;

// Most app initialization is here. Default spinner is running
procedure TSimpleDemoApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  mainScene:=TMainScene.Create;
  mainScene.CreateUI;
  mainScene.InitParticles;
  // just wait a second so you can notice the default loader scene with spinner :-)
  Sleep(1000);
  // switch to the main scene using fade transition effect
  TTransitionEffect.Create(mainScene,250);
 end;

{ TMainScene }
procedure TMainScene.CreateUI;
 var
  box:TUIElement;
  btn:TUIButton;
  font:cardinal;
 begin
  // Let's create a simple container
  box:=TUIElement.Create(400,250,UI,'MainScene\MainMenu');
  box.Center; // make it center
  //c.SetPos(UI.size.x/2,UI.size.y/2,pivotCenter); // another way to make it center
  box.styleinfo:='E0C0C8D0'; // fill color for the default style
  box.SetAnchors(0.5, 0.5, 0.5, 0.5); // make it always centered

  font:=painter.GetFont('Default',9);  // select a font for UI

  // Create an edit box. I don't want to use a variable for it
  TUIEditBox.Create(250,26,'MainScene\Edit',font,$FF000030,box).SetPos(200,100,pivotCenter);
  UIEditBox('MainScene\Edit').defaultText:='Type something here...'; // referencing UI element by its name

  // Create a button (now using a variable - classic way)
  btn:=TUIButton.Create(100,35,'MainScene\Close','Exit',font,box);
  btn.SetPos(200,200,pivotCenter);
  btn.hint:='Press this button to exit';

  // Link the button click signal to the engine termination signal
  Link('UI\MainScene\Close\Click','Engine\Cmd\Exit');
 end;

procedure TMainScene.InitParticles;
 begin
  particlesTex:=LoadImageFromFile('SimpleDemo\particles');
 end;


procedure TMainScene.HandleParticles;
 var
  i,n,count:integer;
  angle:single;
 begin
  // Emit new particles with right mouse button
  if game.mouseButtons and 2>0 then begin
   count:=10;
   n:=length(particles);
   SetLength(particles,n+count);
   SetLength(particlesData,n+count);
   for i:=n to n+count-1 do begin
    particles[i].x:=game.mouseX;
    particles[i].y:=game.mouseY;
    particles[i].z:=0;
    particles[i].color:=MyColor(255,40+random(100),40+random(100),40+random(100));
    particles[i].scale:=0.5+random*3;
    particles[i].angle:=random;
    particles[i].index:=random(3);
    // Additional data
    angle:=random(1000);
    particlesData[i].dx:=(1+random*10)*cos(angle);
    particlesData[i].dy:=(1+random*10)*sin(angle);
    particlesData[i].life:=20+random(10);
   end;
  end;

  // Process particles
  i:=0; count:=length(particles);
  while i<count do
   with particles[i] do begin
    dec(particlesData[i].life);
    // Delete dead
    if particlesData[i].life=0 then begin
     dec(count);
     particlesData[i]:=particlesData[count];
     particles[i]:=particles[count];
     continue;
    end;
    // Fade off
    color:=ColorAlpha(color,particlesData[i].life*0.1);
    scale:=scale*0.98;
    // Movement
    x:=x+particlesData[i].dx;
    y:=y+particlesData[i].dy;
    // Deceleration + gravity
    particlesData[i].dx:=particlesData[i].dx*0.95;
    particlesData[i].dy:=particlesData[i].dy*0.95+0.3;
    inc(i);
   end;
  SetLength(particles,count);
  SetLength(particlesData,count);

  // Draw particles in additive mode
  if count>0 then begin
   painter.SetMode(blAdd);
   painter.DrawParticles(0,0,@particles[0],count,particlesTex,16,1);
   painter.SetMode(blAlpha);
  end;
 end;

procedure TMainScene.Render;
 var
  i,n,maxX,maxY:integer;
  x1,y1,x2,y2,x3,y3,x4,y4:single;
  font:cardinal;
 begin
  // 1. Draw scene background
  painter.Clear(0); // clear with black
  // Draw some lines
  maxX:=game.renderWidth-1;
  maxY:=game.renderHeight-1;
  n:=24;
  for i:=0 to n-1 do begin
    x1:=maxX*i/n; y1:=0;
    x2:=maxX; y2:=maxY*i/n;
    x3:=maxX-maxX*i/n; y3:=maxY;
    x4:=0; y4:=maxY-maxY*i/n;
    painter.DrawLine(x1,y1,x2,y2,$8020C0F0);
    painter.DrawLine(x2,y2,x3,y3,$8020C0F0);
    painter.DrawLine(x3,y3,x4,y4,$8020C0F0);
    painter.DrawLine(x4,y4,x1,y1,$8020C0F0);
  end;
  // Border rects
  painter.Rect(0,0,maxX,maxY, $FFFFC020);
  painter.Rect(10,10,maxX-10,maxY-10, $FFC00000);

  font:=painter.GetFont('Default',7); // Select font (no need to do this every frame)
  painter.TextOut(font,300,200,$FFFFFFFF,'Hello world!'); // Write text using the font

  inherited; // Here all the UI is displayed

  // I want particles to be drawn over the UI so handle them here
  HandleParticles;
 end;

end.
