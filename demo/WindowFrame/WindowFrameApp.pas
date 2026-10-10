// Window frame drawn by the app: TUIWindow bound to the OS window, caption row with a menu
// and window buttons, frame policy switching

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
  CAPTION_H=32; // caption row height, UI units
  BUTTON_W=46;  // window button width, UI units
  MENU_W=56;    // menu item width, UI units
  frameNames:array[TWindowFrame] of String8=('System','Custom','CustomWhenMaximized');
  stateNames:array[TWindowState] of String8=('Normal','Minimized','Maximized');

 type
  TMainScene=class(TUIScene)
   frameWnd:TUIWindow;
   captionRow:TUIElement;
   status:TUILabel;
   procedure CreateUI;
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

procedure FullscreenClick;
 begin
  game.SwitchToAltSettings; // as [Alt]+[Enter]
 end;

{ TMainScene }

procedure TMainScene.CreateUI;
 var
  box:TUIElement;
  lab:TUILabel;

  function WindowButton(caption:String8;index:integer;onClick:TProcedure):TUIButton;
   begin
    result:=TUIButton.Create(BUTTON_W,CAPTION_H,captionRow).Setup(caption);
    result.SetPos(captionRow.clientWidth-BUTTON_W*index,0,pivotTopRight);
    result.SetAnchors(1,0,1,0);
    result.onClick:=onClick;
   end;

  procedure MenuItem(caption:String8;index:integer);
   begin
    TUIButton.Create(MENU_W,CAPTION_H,captionRow).Setup(caption).SetPos(index*MENU_W,0);
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
  frameWnd:=TUIWindow.Create(UI.clientWidth,UI.clientHeight,true,UI,'MainFrame');
  frameWnd.styleInfo:='fill:FF2C3440';
  frameWnd.BindToWindow;
  frameWnd.header:=CAPTION_H;

  // Caption row: transparent for the hit test, so its empty part drags the window,
  // while the menu items and window buttons in it work as usual
  captionRow:=TUIElement.Create(frameWnd.clientWidth,CAPTION_H,frameWnd,'CaptionRow');
  captionRow.shape:=TUIShape.shapeEmpty;
  captionRow.styleInfo:='fill:FF1A2028';
  captionRow.SetAnchors(0,0,1,0);
  MenuItem('File',0);
  MenuItem('View',1);
  lab:=TUILabel.Create(300,CAPTION_H,captionRow).Setup('Window frame demo');
  lab.shape:=TUIShape.shapeEmpty;
  lab.SetPos(3*MENU_W,0);
  WindowButton('X',0,CloseClick);
  WindowButton('[ ]',1,MaximizeClick);
  WindowButton('_',2,MinimizeClick);

  box:=TUIElement.Create(260,204,frameWnd);
  box.Center;
  box.SetAnchors(0.5,0.5,0.5,0.5);
  FrameButton('OS frame',0,SystemFrameClick);
  FrameButton('Custom frame',1,CustomFrameClick);
  FrameButton('Custom when maximized',2,CustomMaximizedClick);
  FrameButton('Fullscreen',3,FullscreenClick);

  status:=TUILabel.Create(frameWnd.clientWidth-24,24,frameWnd).Setup('');
  status.SetPos(12,frameWnd.clientHeight-4,pivotBottomLeft);
  status.SetAnchors(0,1,1,1);
 end;

procedure TMainScene.Render;
 begin
  gfx.target.Clear($FF2C3440);
  // with the OS frame the OS draws the caption
  captionRow.flags.visible:=window.CustomFrameShown;
  status.caption:='Frame: '+frameNames[window.frame]+', state: '+stateNames[window.state]+
   '. Drag or double-click the caption, try Win+arrows, snap, resize by the edges, [Alt]+[Enter].';
  inherited;
 end;

end.
