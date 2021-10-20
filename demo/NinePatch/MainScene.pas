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
 uses SysUtils,Apus.MyServis,Apus.EventMan,Apus.Colors,
   Apus.Engine.SceneEffects,Apus.Engine.UIClasses,Apus.Engine.UIScene;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure CreateUI;
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;
  fileName:string;
  redPatch,tiledPatch:TNinePatch;

{ TSimpleDemoApp }

constructor TMainApp.Create;
 var
  st:string;
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
  if paramCount>0 then begin
   st:=ParamStr(1);
   if FileExists(st) then
    fileName:=ExpandFileName(st);
  end;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 var
  st:string;
 begin
  st:=ExtractFileDir(ParamStr(0));
  SetCurrentDir(st);
  if DirectoryExists('../demo/NinePatch') then
    SetCurrentDir('../demo/NinePatch');
  st:=GetCurrentDir;

  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create;
  sceneMain.CreateUI;
  // switch to the main scene using fade transition effect
  sceneMain.SetStatus(ssActive);
 end;

{ TMainScene }
procedure TMainScene.CreateUI;
 var
  img:TTexture;
 begin
  if FileExists('redPatch.png') then
   redPatch:=LoadNinePatch('redPatch.png');
  if FileExists('tiledPatch.png') then
   tiledPatch:=LoadNinePatch('tiledPatch.png');
 end;


procedure TMainScene.Render;
 var
  i,w,h:integer;
 begin
  // 1. Draw scene background
  gfx.target.Clear($406080); // clear with black

  if redPatch<>nil then begin
   w:=100; h:=60;
   draw.Rect(9,9,10+w,10+h,$50FFFFFF);
   redPatch.Draw(10,10,w,h);

   w:=60; h:=30;
   draw.Rect(129,9,130+w,10+h,$50FFFFFF);
   redPatch.Draw(130,10,w,h);
  end;

  // Stress test #1 - random size
{  randSeed:=1;
  for i:=1 to 1000 do begin
   w:=60+random(100); h:=30+random(100);
   redPatch.Draw(random(700),100+random(500),w,h);
  end;}

  // Stress test #2 - (almost) same size
{  randSeed:=1;
  for i:=1 to 1000 do begin
   if i and 63=0 then begin
    w:=60+random(100); h:=30+random(100);
   end;
   redPatch.Draw(random(700),100+random(500),w,h);
  end;}

  inherited;
 end;

end.
