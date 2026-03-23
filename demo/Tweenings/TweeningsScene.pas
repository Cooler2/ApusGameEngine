// Tweening demo — smooth animation with compensation for interrupted transitions
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit TweeningsScene;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses SysUtils,Apus.EventMan,Apus.Colors,Apus.Geom2D,Apus.Utils,
   Apus.Engine.SceneEffects,Apus.Engine.UI,Apus.Tweenings;

 type
  TMainScene=class(TUIScene)
   pos:TTweening;
   procedure Render; override;
   procedure onMouseBtn(btn:byte;pressed:boolean); override;
  end;

 var
  mainScene:TMainScene;

constructor TMainApp.Create;
 begin
  usedPlatform:=spDefault;
  inherited;
  gameTitle:='Tweening Demo';
  usedAPI:=gaOpenGL2;
 end;

procedure TMainApp.CreateScenes;
 var
  pnt:TVec2;
 begin
  inherited;
  mainScene:=TMainScene.Create;
  pnt.Init(512,384);
  mainScene.pos.Assign(pnt,2);
  TTransitionEffect.Create(mainScene,250);
 end;

procedure TMainScene.onMouseBtn(btn:byte;pressed:boolean);
var
 pnt:TVec2;
begin
 if pressed then begin
  pnt.Init(window.mousePos.x,window.mousePos.y);
  pos.Animate(pnt,500,splines.easeOut);
 end;
end;

procedure TMainScene.Render;
 var
  pnt:TVec2;
 begin
  gfx.target.Clear($406080);
  pos.GetValue(pnt);
  draw.FillRect(pnt.x-15,pnt.y-15,pnt.x+15,pnt.y+15,$FFDDDDDD);
  inherited;
 end;

end.
