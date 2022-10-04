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
   procedure SetupGameSettings(var settings:TGameSettings); override;
  end;

 var
  application:TMainApp;

implementation
 uses Apus.CrossPlatform,Apus.EventMan,Apus.Colors,
   Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Initialize; override;
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;
  root:TUIElement;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine: UI Demo'; // app window title
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  //directRenderOnly:=true;
  //windowedMode:=false;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 var
  scale:single;
 begin
  inherited;
  scale:=game.screenDPI/96;
  txt.SetScale(scale);
  SetDefaultUIScale(scale,scale);
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  game.SwitchToScene('Main');
 end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmWindow;
 end;

procedure RootCloseCLick;
 begin
  root.visible:=false;
 end;

procedure InitTestLayer;
 begin
  root.DeleteChildren;
  root.visible:=true;
  TUIButton.Create(100,28,'Root\Close','Back',0,root).
   SetPos(root.clientWidth/2,root.clientHeight-2,pivotBottomCenter).
   SetAnchors(0.5,1,0.5,1);
  UIButton('Root\Close').onClick:=@RootCloseClick;
 end;

procedure TestButtons;
 begin
  InitTestLayer;
 end;

procedure TestWidgets;
 var
  cont:TUIElement;
  lab:TUILabel;
  style:string;
 begin
  InitTestLayer;
  // Container
  cont:=CreateVerticalContainer(150,'Labels',root,0,10);
  cont.SetPos(10,10);
  // Default properties
  TUILabel.SetClassAttribute('defaultStyleInfo','40FFFFFF');
  TUILabel.SetClassAttribute('defaultColor',$FF603000);

  TUILabel.Create(-1,20,'Label1','Simple label',cont);
  TUILabel.CreateCentered(-1,20,'Label2','Centered',cont);
  TUILabel.CreateRight(-1,20,'Label3','Right',cont);
  TUILabel.Create(-1,20,'Label4','With padding',cont).SetPaddings(4,2,4,2);
  TUILabel.CreateCentered(120,20,'Label5','Too Long Text Clipped',cont);

 end;

procedure TestLayouts;
 begin
  InitTestLayer;
  // Status bar

 end;

{ TMainScene }
procedure TMainScene.Initialize;
 var
  font:cardinal;
  btn:TUIButton;
  panel:TUIElement;
 begin
  UI.font:=txt.GetFont('',7.0,fsBold);
  // Create menu panel
  panel:=TUIElement.Create(250,400,UI,'MainMenu');
  panel.scale:=1.5;
  panel.Center;
  panel.SetAnchors(anchorCenter);
  panel.layout:=TRowLayout.CreateVertical(10,true);
  panel.SetPadding(15);
  //panel.styleInfo:='40E0E0E0 60E0E0E0';
  panel.styleInfo:='background-color=4EEE; border-color=6EEE; border-radius=7;';

  // Create menu buttons
  TUIButton.Create(120,30,'Main\Widgets','Widgets',panel).onClick:=@TestWidgets;
  TUIButton.Create(120,30,'Main\Buttons','Buttons',panel).onClick:=@TestButtons;
  TUIButton.Create(120,30,'Main\Layouts','Layouts',panel).onClick:=@TestLayouts;
  TUIButton.Create(120,30,'Main\Close','Exit',0,panel);
  Link('UI\Main\Close\Click','Engine\Cmd\Exit');

  // Create a placeholder UI element for demos
  root:=TUIElement.Create(UI.clientWidth,UI.clientHeight,UI,'Root');
  root.SetAnchors(anchorAll);
  root.styleInfo:='FFB0C0C4 80000000';
  root.shape:=TElementShape.shapeFull;
  root.visible:=false;
 end;

procedure TMainScene.Render;
 begin
  // 1. Draw scene background
  gfx.target.Clear($406080); // clear with black
  // Draw some lines
  inherited;
 end;

end.
