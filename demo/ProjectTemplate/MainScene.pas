// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit MainScene;
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

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;   // alternative cross-platform solution
  //directRenderOnly:=true; // draw to backbuffer (instead of a screen-size RT-texture for post-processing)
  //windowedMode:=false;
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
  font:cardinal;
  btn:TUIButton;
 begin
  font:=txt.GetFont('Default',9);
  // Create a button
  btn:=TUIButton.Create(100,32,'Main\Close','Exit',font,UI);
  btn.SetPos(UI.width/2,UI.height/2,pivotCenter);
  btn.hint:='Press this button to exit';

  // Link the button click signal to the engine termination signal
  Link('UI\Main\Close\Click','Engine\Cmd\Exit');
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
