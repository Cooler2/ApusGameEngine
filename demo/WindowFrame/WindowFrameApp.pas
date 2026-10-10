// Window frame drawn by the app: caption and window buttons, frame policy switching

// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit WindowFrameApp;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  TWindowFrameApp=class(TGameApplication)
   procedure SetupApplication; override;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TWindowFrameApp;

implementation
 uses SysUtils, Apus.Core, Apus.EventMan, Apus.Engine.Types, Apus.Engine.UI;

 const
  CAPTION_H=32; // caption height, UI units
  BUTTON_W=46;  // window button width, UI units
  frameNames:array[TWindowFrame] of String8=('System','Custom','CustomWhenMaximized');
  stateNames:array[TWindowState] of String8=('Normal','Minimized','Maximized');

 type
  TMainScene=class(TUIScene)
   btnMin,btnMax,btnClose:TUIButton;
   procedure CreateUI;
   function Scale:single;
   // Window areas of the app-drawn frame: the caption, except the window buttons
   function FrameHitTest(x,y:integer):TWindowArea;
   procedure Render; override;
  end;

 var
  mainScene:TMainScene;

{ TWindowFrameApp }

procedure TWindowFrameApp.SetupApplication;
 begin
  inherited;
  {$IFDEF SDL}
  requestBackend.platform:=spSDL;
  {$ENDIF}
  appSetup.title:='Window frame demo';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.resizable:=true;
  windowSetup.frame:=TWindowFrame.Custom;
 end;

procedure TWindowFrameApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.altMode:=dmFullScreen; // [Alt]+[Enter] switches to fullscreen
 end;

procedure TWindowFrameApp.CreateScenes;
 begin
  inherited;
  mainScene:=TMainScene.Create;
  mainScene.CreateUI;
  window.frameHitTest:=mainScene.FrameHitTest;
  game.SwitchToScene(mainScene.name);
 end;

{ Button handlers: run on the window's thread }

procedure MinimizeClick;
 begin
  window.Minimize;
 end;

procedure MaximizeClick;
 begin
  if window.state=TWindowState.Maximized then window.Restore
   else window.Maximize;
 end;

procedure CloseClick;
 begin
  Signal('Engine\Cmd\Exit');
 end;

procedure SetFrame(frame:TWindowFrame);
 var
  settings:TGameSettings;
 begin
  settings:=game.GetSettings;
  settings.frame:=frame;
  game.SetSettings(settings);
 end;

procedure SystemFrameClick;
 begin
  SetFrame(TWindowFrame.System);
 end;

procedure CustomFrameClick;
 begin
  SetFrame(TWindowFrame.Custom);
 end;

procedure CustomMaximizedClick;
 begin
  SetFrame(TWindowFrame.CustomWhenMaximized);
 end;

{ TMainScene }

// Canvas pixels per UI unit: the UI root already carries the DPI scale, so UI elements are
// sized in plain units, while direct drawing and the hit test work in canvas pixels
function TMainScene.Scale:single;
 begin
  result:=UI.scale;
 end;

procedure TMainScene.CreateUI;
 var
  w,h:single;
  box:TUIElement;

  function WindowButton(caption:String8;index:integer;onClick:TProcedure):TUIButton;
   begin
    result:=TUIButton.Create(w,h,UI).Setup(caption);
    result.SetPos(UI.clientWidth-w*index,0,pivotTopRight);
    result.SetAnchors(1,0,1,0);
    result.onClick:=onClick;
   end;

  procedure FrameButton(caption:String8;index:integer;onClick:TProcedure);
   var
    btn:TUIButton;
   begin
    btn:=TUIButton.Create(220,32,box).Setup(caption);
    btn.SetPos(box.clientWidth/2,20+index*44,pivotTopCenter);
    btn.onClick:=onClick;
   end;

 begin
  w:=BUTTON_W;
  h:=CAPTION_H;
  btnClose:=WindowButton('X',0,CloseClick);
  btnMax:=WindowButton('[ ]',1,MaximizeClick);
  btnMin:=WindowButton('_',2,MinimizeClick);

  box:=TUIElement.Create(260,160,UI);
  box.Center;
  box.SetAnchors(0.5,0.5,0.5,0.5);
  FrameButton('OS frame',0,SystemFrameClick);
  FrameButton('Custom frame',1,CustomFrameClick);
  FrameButton('Custom when maximized',2,CustomMaximizedClick);
 end;

function TMainScene.FrameHitTest(x,y:integer):TWindowArea;
 var
  s:single;
 begin
  s:=Scale;
  if (y<CAPTION_H*s) and (x<window.canvasWidth-3*BUTTON_W*s) then result:=TWindowArea.Caption
   else result:=TWindowArea.Client;
 end;

procedure TMainScene.Render;
 var
  shown:boolean;
  s:single;
 begin
  gfx.target.Clear($FF2C3440);
  s:=Scale;
  shown:=window.CustomFrameShown;
  btnMin.flags.visible:=shown;
  btnMax.flags.visible:=shown;
  btnClose.flags.visible:=shown;
  if shown then begin
   draw.FillRect(0,0,window.canvasWidth,round(CAPTION_H*s),$FF1A2028);
   txt.Write(0,12*s,21*s,$FFE0E0E0,'Window frame demo - drag the caption, double-click it');
  end;
  txt.Write(0,12*s,window.canvasHeight-14*s,$FFB0B8C0,
   'Frame: '+frameNames[window.frame]+', state: '+stateNames[window.state]+
   '. Try Win+arrows, snap, resize by the edges, [Alt]+[Enter].');
  inherited;
 end;

end.
