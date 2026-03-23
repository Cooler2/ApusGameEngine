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
 uses SysUtils, Apus.EventMan, Apus.Colors, Apus.Strings,
   Apus.Engine.Types,Apus.Engine.SceneEffects,Apus.Engine.UI,
   Apus.Engine.Style;

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
   procedure CreateStyleUI; // R-05 style system demo panel
   procedure HandleParticles;
   procedure Render; override;
  end;

 var
  mainScene:TMainScene;
  styleRefToggle:boolean; // for the @ref update button demo

{ TSimpleDemoApp }

constructor TSimpleDemoApp.Create;
 var
  st:string;
 begin
  // Platform must be selected before TGameApplication.Create chooses backend.
  {$IFDEF SDL}
  usedPlatform:=spSDL;
  {$ELSE}
  usedPlatform:=spDefault;
  {$ENDIF}
  inherited;
  // Change dir from \bin or \bin64 to the demo folder
  st:=ExtractFileDir(ParamStr(0));
  SetCurrentDir(st);
  if DirectoryExists('../demo/SimpleDemo') then
    SetCurrentDir('../demo/SimpleDemo');

  // Alter some global settings
  gameTitle:='Simple Engine Demo'; // app window title
  configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  //directRenderOnly:=false;
  //useDepthTexture:=true;
  //windowedMode:=false;
 end;

// This is executed just before the game object is launched
procedure TSimpleDemoApp.SetupGameSettings(var settings: TGameSettings);
 begin
  inherited; // global settings are applied to the instance settings here, so there is no sense to change them later

  settings.mode.displayMode:=dmWindow; // run in window
  settings.mode.displayFitMode:=dfmFullSize;
  //settings.mode.displayFitMode:=dfmCenter;
  //settings.mode.displayFitMode:=dfmKeepAspectRatio;

  settings.mode.displayScaleMode:=dsmDontScale;

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

 procedure ExitBtnClick;
 begin
   Ask('Are you sure?','Engine\Cmd\Exit');
 end;

 // Toggle @demo-btn named style between two color schemes → Btn3 changes too
 procedure StyleDemoUpdateRef;
  var
   named:TStyleBlock;
  begin
   styleRefToggle:=not styleRefToggle;
   named:=FindNamedStyle('demo-btn');
   if named=nil then exit;
   if styleRefToggle then
    named.ParseText('color: $FF6E1E1E; text-color: $FFFFD0CC;')  // warm red
   else
    named.ParseText('color: $FF1E3D6E; text-color: $FFCCE0FF;'); // cool blue
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

  font:=txt.GetFont('Default',8);  // select a font for UI

  // Create an edit box. I don't want to use a variable for it
  TUIEditBox.Create(250,26,box,'MainScene\Edit',font,$FF000030).SetPos(200,100,pivotCenter);
  UIEditBox('MainScene\Edit').defaultText:=Str32('Type something here...'); // referencing UI element by its name

  // Create a button (now using a variable - classic way)
  btn:=TUIButton.Create(100,35,box,'MainScene\Close').Setup('Exit',font);
  btn.SetPos(200,200,pivotCenter);
  btn.hint:='Press this button to exit';
  btn.onClickAsync:=@ExitBtnClick;

  // Link the button click signal to the engine termination signal
  //Link('UI\MainScene\Close\Click','Engine\Cmd\Exit');

  CreateStyleUI;
 end;

// R-05 Style System demo panel.
// Panel position: top-left at (10,10), size 225×255.
// For Robot API visual tests use 'ui.element name=StyleDemo\BtnN' to get screen coords,
// then 'pixel cx cy' to sample the button background color at center.
// Expected colors (button background center, no hover):
//   Btn1: ~$FFB0A0C0 (defaultBtnColor, default gradient)
//   Btn2: ~$FF1E3D6E (custom color, gradient center)
//   Btn3: ~$FF1E3D6E (same via @demo-btn ref)
//   Btn4: ~$FF1E3D6E idle; ~$FF2E5DA0 on hover; ~$FF0E1E3A on press
//   Btn5: ~$FF1E3D6E (disabled, color unchanged; only text-color differs)
procedure TMainScene.CreateStyleUI;
 var
  panel:TUIElement;
  btn:TUIButton;
  font:cardinal;
  named:TStyleBlock;
 begin
  font:=txt.GetFont('Default',8);

  // Register named style reused by Btn2, Btn3 and the @ref update demo
  named:=TStyleBlock.Create;
  named.ParseText('color: $FF1E3D6E; text-color: $FFCCE0FF;');
  RegisterNamedStyle('demo-btn', named);

  // Panel: fixed 225×255 at (10,10) — old styleinfo format (DrawCommonStyle)
  panel:=TUIElement.Create(225, 255, UI, 'StyleDemo\Panel');
  panel.SetPos(10, 10, pivotTopLeft);
  panel.styleinfo:='fill: $BF102030; border-width: 1; border-color: $FF3060A0;';
  TUILabel.Create(205,20,panel,'StyleDemo\Title').Centered('R-05 Style Demo',font,$FF80C8FF).
    SetPos(112,15,pivotCenter);

  // Btn1: no custom style — baseline (defaultBtnColor = $FFB0A0C0)
  TUIButton.Create(195,28,panel,'StyleDemo\Btn1').Setup('Default style',font).
    SetPos(112,45,pivotCenter);

  // Btn2: explicit color+text via SetStyleText
  btn:=TUIButton.Create(195,28,panel,'StyleDemo\Btn2').Setup('Custom color',font);
  btn.SetPos(112,80,pivotCenter);
  btn.SetStyleText('color: $FF1E3D6E; text-color: $FFCCE0FF;');

  // Btn3: @ref to named style (same result as Btn2, but via indirection)
  btn:=TUIButton.Create(195,28,panel,'StyleDemo\Btn3').Setup('@ref style',font);
  btn.SetPos(112,115,pivotCenter);
  btn.SetStyleText('@demo-btn;');

  // Btn4: CSS state blocks — :hover and :pressed override color
  btn:=TUIButton.Create(195,28,panel,'StyleDemo\Btn4').Setup('Hover: state test',font);
  btn.SetPos(112,150,pivotCenter);
  btn.SetStyleText(
    'color: $FF1E3D6E; text-color: $FFCCE0FF;'+
    ':hover { color: $FF2E5DA0; text-color: $FFFFFFFF; }'+
    ':pressed { color: $FF0E1E3A; text-color: $FF8090A0; }');

  // Btn5: disabled — :disabled overrides text-color; button color unchanged
  btn:=TUIButton.Create(195,28,panel,'StyleDemo\Btn5').Setup('Disabled',font);
  btn.SetPos(112,185,pivotCenter);
  btn.SetStyleText(
    'color: $FF1E3D6E; text-color: $FFCCE0FF;'+
    ':disabled { text-color: $FF707070; }');
  btn.flags.enabled:=false;

  // Btn6: click to toggle @demo-btn color → Btn2 and Btn3 update together
  btn:=TUIButton.Create(195,28,panel,'StyleDemo\Btn6').Setup('Toggle @ref color',font);
  btn.SetPos(112,225,pivotCenter);
  btn.onClickAsync:=@StyleDemoUpdateRef;
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
  maxX:=window.renderWidth-1;
  maxY:=window.renderHeight-1;
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
