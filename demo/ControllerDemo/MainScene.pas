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
 uses Apus.MyServis,Apus.EventMan,Apus.Colors,SysUtils,
   Apus.Engine.SceneEffects,Apus.Engine.UIClasses,Apus.Engine.UIScene,Apus.Engine.Controller;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;
  baseDir:string;
  imgJoystick,imgGamepad:TTexture;
  uiTestMode:boolean;

{ TSimpleDemoApp }

constructor TMainApp.Create;
 var
  a:integer;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Game Controllers Test'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spSDL; // Important!
  //directRenderOnly:=true;
  baseDir:='';
  if DirectoryExists('../Demo/ControllerDemo') then
   baseDir:='../Demo/ControllerDemo/';
 end;

procedure OnToggleBtn;
 begin
  uiTestMode:=not uiTestMode;
  if uiTestMode then
   game.gamepadNavigationMode:=gnmAuto
  else
   game.gamepadNavigationMode:=gnmDisabled;
  game.DebugFeature(dfShowNavigationPoints,uiTestMode);
 end;

procedure TMainApp.CreateScenes;
 begin
  inherited;
  imgJoystick:=LoadImageFromFile(baseDir+'joystick');
  imgGamepad:=LoadImageFromFile(baseDir+'gamepad');
  // initialize our main scene
  sceneMain:=TMainScene.Create;
  TUIButton.Create(200,32,'ToggleInput','Toggle UI Test',txt.GetFont('Default',9),
   sceneMain.UI).SetPos(game.renderWidth/2,game.renderHeight-25,pivotCenter);
  UIButton('ToggleInput').onClick:=OnToggleBtn;
  sceneMain.SetStatus(ssActive);
 end;

{ TMainScene }

procedure DrawControllerState(x,y,width,height:integer;const con:TGameController);
 var
  font:TFontHandle;
  status:string;
  scale:single;
  i,yy:integer;
  btn:TConButtonType;
 begin
  case con.controllerType of
   gcUnplugged:status:='Not connected';
   gcUnknown:status:='Unknown controller';
   gcJoystick:status:='Joystick';
   gcGamepad:status:='Gamepad';
   gcWheel:status:='Wheel';
  end;
  scale:=min2(width,height)/400;
  font:=txt.GetFont('Default',18*scale);
  txt.WriteW(font,x+10,y+round(scale*40),$FF302020,IntToStr(con.index)+'. '+status);
  if con.controllerType=gcUnplugged then exit;


  // Properties
  inc(x,round(scale*20));
  yy:=y+round(scale*70);
  font:=txt.GetFont('Default',10*scale);
  txt.WriteW(font,x,yy,$FF302020,
    Format('Device name: %s',[con.name]));
  inc(yy,round(scale*22));
  txt.WriteW(font,x,yy,$FF302020,
    Format('Axes: %d, buttons: %d',[con.numAxes,con.numButtons]));
  inc(yy,round(scale*22));

  // Image
  if con.controllerType=gcJoystick then
   draw.Image(x,yy,scale*0.5,imgJoystick);
  if con.controllerType=gcGamepad then
   draw.Image(x,yy,scale*0.5,imgGamepad);

  // Values
  inc(x,width div 2);
  yy:=y+round(scale*30);
  font:=txt.GetFont('Default',9*scale);
  for i:=1 to con.numAxes do begin
   txt.WriteW(font,x,yy,$FF000000,Format('Axis %d: %.5f',[i,con.axes[TConAxisType(i-1)]]));
   inc(yy,round(scale*20));
  end;
  if con.controllerType=gcGamepad then begin
   for btn:=btButtonA to btButtonRightShoulder do
    if con.GetButton(btn) then begin
     txt.WriteW(font,x,yy,$FF000000,Format('Button %s pressed',[GetButtonName(btn)]));
     inc(yy,round(scale*20));
    end;
  end else
   for i:=0 to con.numButtons-1 do
    if GetBit(con.buttons,i) then begin
     txt.WriteW(font,x,yy,$FF000000,Format('Button %d pressed',[i]));
     inc(yy,round(scale*20));
    end;
 end;

procedure DefineManualUI;
 var
  i,x,y:integer;
 begin
  randSeed:=2;
  for i:=1 to 10 do begin
   x:=20+random(game.renderWidth-40);
   y:=20+random(game.renderHeight-100);
   game.DPadCustomPoint(x,y); // Tell the engine that this point should be available for gamepad navigation
  end;
 end;

procedure TMainScene.Render;
 var
  w2,h2:integer;
 begin
  gfx.target.Clear($FFE0E0E0);
  w2:=game.renderWidth div 2;
  h2:=game.renderHeight div 2;
  draw.Line(w2,0,w2,h2*2,$FF200000);
  draw.Line(0,h2,w2*2,h2,$FF200000);

  DrawControllerState(0,0,  w2,h2,controllers[0]);
  DrawControllerState(w2,0, w2,h2,controllers[1]);
  DrawControllerState(0,h2, w2,h2,controllers[2]);
  DrawControllerState(w2,h2,w2,h2,controllers[3]);

  DefineManualUI;
  inherited;
 end;

end.
