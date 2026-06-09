// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit MainScene;
interface
uses
  Apus.Engine.GameApp,
  Apus.Engine.API;

type
  TMainApp=class(TGameApplication)
    constructor Create;
    procedure SetupGameSettings(var settings:TGameSettings); override;
    procedure CreateScenes; override;
  end;

var
  application:TMainApp;

implementation
uses
  Apus.EventMan,
  Apus.Engine.Types,
  Apus.Engine.UI;

type
  TMainScene=class(TUIScene)
    procedure CreateUI;
    procedure Render; override;
  end;

var
  sceneMain:TMainScene;

constructor TMainApp.Create;
begin
  {$IFDEF SDL}
  usedPlatform:=spSDL;
  {$ELSE}
  usedPlatform:=spDefault;
  {$ENDIF}
  inherited;
  gameTitle:='Apus Game Engine';
  usedAPI:=gaOpenGL2;
  windowWidth:=960;
  windowHeight:=540;
  windowSizeable:=false;
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
end;

procedure TMainApp.CreateScenes;
begin
  inherited;
  sceneMain:=TMainScene.Create('Main');
  sceneMain.CreateUI;
  game.SwitchToScene('Main');
end;

{ TMainScene }

procedure TMainScene.CreateUI;
var
  btn:TUIButton;
begin
  btn:=TUIButton.Create(120,34,UI,'Main\Close').Setup('Exit');
  btn.SetPos(UI.width/2,UI.height/2,pivotCenter);
  btn.hint:='Press this button to exit';
  Link('UI\Main\Close\OnClick','Engine\Cmd\Exit');
end;

procedure TMainScene.Render;
begin
  gfx.target.Clear($FF203040);
  inherited;
end;

end.
