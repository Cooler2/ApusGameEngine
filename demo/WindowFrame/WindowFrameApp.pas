// Window frame drawn by the app: TUIWindow bound to the OS window, caption row with a menu
// and window buttons, frame policy switching, confirmation before closing

// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@astralheroes.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)

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
 uses SysUtils, Apus.Core, Apus.EventMan, Apus.Engine.Types, Apus.Engine.UI, Apus.Engine.MessageScene;

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
  askOnClose:boolean; // ask before closing the window
  asking:boolean;     // the question is shown

// The OS close button, Alt+F4 or the app's own one. The handler runs right away in the
// window's thread: ClosePending keeps the window, the answer comes later
procedure CloseRequestEvent(event:TEventStr;tag:TTag);
 begin
  if not askOnClose then exit; // the window closes
  window.ClosePending;
  if asking then exit; // the question is already shown
  asking:=true;
  Ask('Close the window?','Demo\Close\Yes','Demo\Close\No');
 end;

procedure CloseAnswerEvent(event:TEventStr;tag:TTag);
 begin
  asking:=false;
  if SameText(event,'Demo\Close\Yes') then window.Terminate; // close without asking again
 end;

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
  SetEventHandler('ENGINE\WINDOW\CLOSEREQUEST',CloseRequestEvent);
  SetEventHandler('Demo\Close',CloseAnswerEvent);
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
  window.RequestClose; // the same way as the OS close button
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
  askBox:TUICheckBox;

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

  box:=TUIElement.Create(260,248,frameWnd);
  box.Center;
  box.SetAnchors(0.5,0.5,0.5,0.5);
  FrameButton('OS frame',0,SystemFrameClick);
  FrameButton('Custom frame',1,CustomFrameClick);
  FrameButton('Custom when maximized',2,CustomMaximizedClick);
  FrameButton('Fullscreen',3,FullscreenClick);
  askBox:=TUICheckBox.Create(220,32,box).Setup('Ask before closing',askOnClose);
  askBox.SetPos(box.clientWidth/2,20+4*44,pivotTopCenter);
  askBox.linkedToggled:=@askOnClose;

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
