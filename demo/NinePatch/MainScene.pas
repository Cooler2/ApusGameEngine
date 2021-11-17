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
  redPatch,overPatch,tiledPatch:TNinePatch;

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
  bar,group1,group2:TUIElement;
 begin
  if FileExists('redPatch.png') then
   redPatch:=LoadNinePatch('redPatch.png');
  if FileExists('overPatch.png') then
   overPatch:=LoadNinePatch('overPatch.png');
  if FileExists('tiledPatch.png') then
   tiledPatch:=LoadNinePatch('tiledPatch.png');

  // Buttons bar
  bar:=TUIElement.Create(130,300,UI).SetPos(0,0).SetPaddings(5);
  bar.layout:=TRowLayout.Create(false,10,true);
  // 1-nd speedbuttons group
  group1:=TUIElement.Create(120,90,bar,'Group1');
  group1.layout:=TRowLayout.Create(false,0,true);
  TUIButton.Create(120,30,'DrawTest','Draw Test',game.defaultFont,group1);
  TUIButton.Create(120,30,'Stress1','Stress Test 1',game.defaultFont,group1);
  TUIButton.Create(120,30,'Stress2','Stress Test 2',game.defaultFont,group1).MakeSwitches;
  // 2-st speedbuttons group
  group2:=TUIElement.Create(120,90,bar,'Group2');
  group2.layout:=TRowLayout.Create(false,0,true);
  TUIButton.Create(120,30,'Patch1','Patch 1',game.defaultFont,group2);
  TUIButton.Create(120,30,'Patch2','Patch 2',game.defaultFont,group2);
  TUIButton.Create(120,30,'Patch3','Patch 3',game.defaultFont,group2).MakeSwitches;
 end;

procedure TMainScene.Render;
 var
  i,w,h,dW,dH:integer;
  patch:TNinePatch;
  time:double;
 procedure DrawPatchWithFrame(x,y,w,h:integer;patch:TNinePatch;scale:single=1);
  begin
   draw.Rect(x-1,y-1,x+w,y+h,$50FFFFFF);
   patch.Draw(x,y,w,h,scale);
  end;
 begin
  // 1. Draw scene background
  gfx.target.Clear($406080); // clear with black
  FindControl('group2').visible:=not UIButton('DrawTest').pressed;

  if UIButton('DrawTest').pressed then begin
   time:=game.frameStartTime/1000;
   dW:=round(20*sin(time));
   dH:=round(20*sin(time+2));
   if redPatch<>nil then begin
    DrawPatchWithFrame(200,10,100,60,redPatch);
    DrawPatchWithFrame(350,20,60,30,redPatch);
    DrawPatchWithFrame(500,10,100,70,redPatch,1.5);
    DrawPatchWithFrame(650,10,100+dW,80+dH,redPatch);
   end;
   if overPatch<>nil then begin
    DrawPatchWithFrame(200,150,100,90,overPatch);
    DrawPatchWithFrame(350,120,200,140,overPatch);
    DrawPatchWithFrame(600,120,120+dW,100+dH,overPatch);
   end;
   if tiledPatch<>nil then begin
    dH:=round(50*sin(time+2));
    DrawPatchWithFrame(200,300,101,90,tiledPatch);
    DrawPatchWithFrame(200,400,170,190,tiledPatch,1.5);
    DrawPatchWithFrame(400,300,200,300,tiledPatch);
    DrawPatchWithFrame(620,300,150+dW,130+dH,tiledPatch);
   end;
  end;

  if UIButton('Patch1').pressed then
   patch:=redPatch
  else
  if UIButton('Patch2').pressed then
   patch:=overPatch
  else
   patch:=tiledPatch;

  if UIButton('Stress1').pressed then begin
   // Stress test #1 - random size
   randSeed:=1;
   for i:=1 to 1000 do begin
    w:=patch.minWidth+random(100);
    h:=patch.minHeight+random(100);
    patch.Draw(120+random(700),10+random(500),w,h);
   end;
  end;

  if UIButton('Stress2').pressed then begin
   // Stress test #2 - (almost) same size
   randSeed:=1;
   for i:=1 to 1000 do begin
    if i and 63=1 then begin
     w:=patch.minWidth+random(100);
     h:=patch.minHeight+random(100);
    end;
    patch.Draw(120+random(700),10+random(500),w,h);
   end;
  end;

  inherited;
 end;

end.
