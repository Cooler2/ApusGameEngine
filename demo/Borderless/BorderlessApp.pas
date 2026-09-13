// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit BorderlessApp;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   procedure SetupApplication; override;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses Apus.CrossPlatform,Apus.EventMan,Apus.Colors,
   Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Load; override;
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;

procedure TMainApp.SetupApplication;
 begin
  inherited;
  //requestBackend.platform:=spSDL;   // alternative cross-platform solution
  appSetup.title:='Apus Game Engine'; // app window title
  //appSetup.configFile:='game.ctl';
  requestBackend.graphicsAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  windowSetup.borderless:=true;
  windowSetup.resizable:=true;
  //windowSetup.fullscreen:=true;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 var
  scale:single;
 begin
  inherited;
  scale:=window.surface.dpi/96;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  sceneMain.UI.SetScale(scale);
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
  btn.SetPos(UI.clientWidth/2,UI.clientHeight/2,pivotCenter);
  btn.SetAnchors(anchorCenter);
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
