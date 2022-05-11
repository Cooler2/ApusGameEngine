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
   Apus.Engine.SceneEffects,Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure CreateUI;
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;

{ TSimpleDemoApp }

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  //directRenderOnly:=true;
  //windowedMode:=false;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  sceneMain.CreateUI;
  // switch to the main scene using fade transition effect
  game.SwitchToScene('Main');
 end;

{ TMainScene }
procedure TMainScene.CreateUI;
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
  // 1. Draw scene background
  gfx.target.Clear($406080); // clear with black
  // Draw some lines
  inherited;
 end;

end.
