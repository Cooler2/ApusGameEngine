// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit ProjectTemplateApp;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses Apus.EventMan,Apus.Colors,
   Apus.Engine.Types,Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Load; override;
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault; // native on Windows, SDL elsewhere (needs -dSDL)
  // Working surface: by default the canvas covers the whole client area and
  // one canvas unit is one pixel. Other options (call before Prepare):
  //SetupFixedCanvas(1024,768); // fixed canvas, scaled to fit, letterboxed
  //SetupPixelArt(320,200);     // fixed canvas, integer scale, no filtering
  // Audio backends are opt-in: build with -dSDLMIX to link SDL_mixer in.
 end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited; // global settings are applied to the instance settings here
  settings.mode:=dmWindow;        // run in a resizeable window
  settings.altMode:=dmFullScreen; // [Alt]+[Enter] switches to fullscreen
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  // (this will wait in a separate thread until scene's Load() is executed
  game.SwitchToScene('Main');
 end;

{ TMainScene }
procedure TMainScene.Load; // This is called from the launch thread, no draw calls allowed
 var
  btn:TUIButton;
 begin
  // Create a button
  btn:=TUIButton.Create(100,32,UI,'Main\Close').Setup('Exit');
  btn.SetPos(UI.width/2,UI.height/2,pivotCenter);
  btn.hint:='Press this button to exit';

  // Link the button click signal to the engine termination signal
  Link('UI\Main\Close\OnClick','Engine\Cmd\Exit');
 end;

procedure TMainScene.Render;
 begin
  // Clear scene background
  gfx.target.Clear($406080); // clear with blue
  // Draw something here...
  inherited; // this will draw the UI elements
  // You can draw something here over the UI
 end;

end.
