// Simple demo of the Apus Game Engine framework

// Copyright (C) 2017 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit SimpleDemoApp;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API, Apus.Engine.MessageScene;
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
 uses SysUtils, Apus.Core, Apus.EventMan, Apus.Colors, Apus.Strings,
   Apus.Engine.Types,Apus.Engine.SceneEffects,Apus.Engine.UI;

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
  // Platform must be selected before TGameApplication.Create chooses backend.
  {$IFDEF SDL}
  usedPlatform:=spSDL;
  {$ELSE}
  usedPlatform:=spDefault;
  {$ENDIF}
  inherited;
  // Start from the engine-resolved resource base: the exe dir normally, or the
  // .app's Contents/Resources when launched from a macOS bundle (BaseDir handles
  // the bundle detection, so no per-demo {$IFDEF DARWIN} is needed here).
  SetCurrentDir(BaseDir);
  // When running straight from the repo, assets live in the source tree instead.
  if DirectoryExists('../demo/SimpleDemo') then
    SetCurrentDir('../demo/SimpleDemo');

  // Alter some global settings
  gameTitle:='Simple Engine Demo'; // app window title
  configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  //useDepthTexture:=true;
  //windowedMode:=false;
 end;

// This is executed just before the game object is launched
procedure TSimpleDemoApp.SetupGameSettings(var settings: TGameSettings);
 begin
  inherited; // global settings are applied to the instance settings here, so there is no sense to change them later

  settings.mode:=dmWindow;          // run in a resizeable window
  settings.altMode:=dmFullScreen;   // [Alt]+[Enter] switches to fullscreen

  // The working surface is declared with the Setup* presets in the constructor
  // (default: the canvas follows the whole client area, 1:1 pixels).
 end;

 procedure ExitBtnClick;
 begin
   Ask('Are you sure?','Engine\Cmd\Exit');
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
 begin
  // Let's create a simple container
  box:=TUIElement.Create(400,250,UI,'MainScene\MainMenu');
  box.Center; // make it center
  //c.SetPos(UI.size.x/2,UI.size.y/2,pivotCenter); // another way to make it center
  box.styleinfo:='fill:#E0C0C8D0'; // fill color for the default style
  box.SetAnchors(0.5, 0.5, 0.5, 0.5); // make it always centered

  // Create an edit box. I don't want to use a variable for it
  TUIEditBox.Create(250,26,box,'MainScene\Edit').SetPos(200,100,pivotCenter);
  UIEditBox('MainScene\Edit').defaultText:=Str32('Type something here...'); // referencing UI element by its name

  // Create a button (now using a variable - classic way)
  btn:=TUIButton.Create(100,35,box,'MainScene\Close').Setup('Exit');
  btn.SetPos(200,200,pivotCenter);
  btn.hint:='Press this button to exit';
  btn.onClickAsync:=@ExitBtnClick;

  // Link the button click signal to the engine termination signal
  //Link('UI\MainScene\Close\Click','Engine\Cmd\Exit');
 end;

procedure TMainScene.InitParticles;
 begin
  particlesTex:=LoadImageFromFile('particles');
 end;


procedure TMainScene.HandleParticles;
 var
  i,n,count:integer;
  angle:single;
 begin
  // Emit new particles with right mouse button
  if window.mouseButtons and 2>0 then begin
   count:=10;
   n:=length(particles);
   SetLength(particles,n+count);
   SetLength(particlesData,n+count);
   for i:=n to n+count-1 do begin
    particles[i].x:=window.mousePos.x;
    particles[i].y:=window.mousePos.y;
    particles[i].z:=0;
    particles[i].color:=Color.ARGB(255,40+random(100),40+random(100),40+random(100));
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
  while i<count do begin
   dec(particlesData[i].life);
   // Delete dead
   if particlesData[i].life=0 then begin
    dec(count);
    particlesData[i]:=particlesData[count];
    particles[i]:=particles[count];
    continue;
   end;
   // Fade off
   particles[i].color:=Color.Scale(particles[i].color,particlesData[i].life*0.1);
   particles[i].scale:=particles[i].scale*0.98;
   // Movement
   particles[i].x:=particles[i].x+particlesData[i].dx;
   particles[i].y:=particles[i].y+particlesData[i].dy;
   // Deceleration + gravity
   particlesData[i].dx:=particlesData[i].dx*0.95;
   particlesData[i].dy:=particlesData[i].dy*0.95+0.3;
   inc(i);
  end;
  SetLength(particles,count);
  SetLength(particlesData,count);

  // Draw particles in additive mode
  if count>0 then begin
   gfx.target.BlendMode(blAdd);
   draw.Particles(0,0,@particles[0],count,particlesTex,16,1);
   gfx.target.BlendMode(blAlpha);
  end;
 end;

procedure TMainScene.Render;
 var
  i,n,maxX,maxY:integer;
  x1,y1,x2,y2,x3,y3,x4,y4:single;
  font:cardinal;
 begin
  // 1. Draw scene background
  gfx.target.Clear(0); // clear with black
  // Draw some lines
  maxX:=window.canvasWidth-1;
  maxY:=window.canvasHeight-1;
  n:=24;
  for i:=0 to n-1 do begin
    x1:=maxX*i/n; y1:=0;
    x2:=maxX; y2:=maxY*i/n;
    x3:=maxX-maxX*i/n; y3:=maxY;
    x4:=0; y4:=maxY-maxY*i/n;
    draw.Line(x1,y1,x2,y2,$8020C0F0);
    draw.Line(x2,y2,x3,y3,$8020C0F0);
    draw.Line(x3,y3,x4,y4,$8020C0F0);
    draw.Line(x4,y4,x1,y1,$8020C0F0);
  end;
  // Border rects
  draw.Rect(0,0,maxX,maxY, $FFFFC020);
  draw.Rect(10,10,maxX-10,maxY-10, $FFC00000);

  font:=txt.GetFont('Default',7); // Select font (no need to do this every frame)
  txt.Write(font,300,200,$FFFFFFFF,'Hello world!'); // Write text using the font

  txt.Write(0,10,20,$FFD0D0D0,'RMB - particles, [Win]+[~] - toggle console. ');

  inherited; // Here all the UI is displayed

  // I want particles to be drawn over the UI so handle them here
  HandleParticles;
 end;

end.
