// Tweening demo
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit TweeningsScene;
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
   Apus.Engine.UI, Apus.Common, Apus.Tweenings;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   pos:TTweening;
   procedure Initialize; override;
   procedure Render; override;
   procedure onMouseBtn(btn:byte;pressed:boolean); override;
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


procedure TMainScene.Initialize;
var
 pnt:TVec2;
begin
 pnt.Init(window.renderWidth/2,window.renderHeight/2);
 pos.Assign(pnt,2);
end;

procedure TMainScene.onMouseBtn(btn:byte;pressed:boolean);
var
 pnt:TVec2;
begin
 if pressed then begin
   pnt.Init(window.mouseX,window.mouseY);
   pos.Assign(pnt,2);
 end;
end;

procedure TMainScene.Render;
 var
  pnt:TVec2;
 begin
  // Clear scene background
  gfx.target.Clear($406080); // clear with blue

  pos.GetValue(pnt);
  draw.RoundRect(pnt,30,30,15,0,0,$FFDDDDDD);

  inherited; // this will draw the UI elements
 end;

end.
