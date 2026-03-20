// Low poly trees generator

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
   procedure LoadFonts; override;
   procedure SelectFonts; override;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses SysUtils, Apus.Common, Apus.EventMan, Apus.Colors, Apus.Geom3d,
   Apus.Engine.UI, Trees;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure InitUI;
   procedure Load; override;
   procedure Render; override;
   procedure onMouseMove(x,y:integer); override;
   procedure onMouseWheel(delta:integer); override;
  end;

  TTreeBuilder=record
   ground:TTexture;
   gen:TTreeGenerator;
   procedure Init(tree:TTreeType);
  end;

 var
  sceneMain:TMainScene;
  treeGens:array[TTreeType] of TTreeBuilder;
  curTree:^TTreeBuilder;
  cameraZoom:TAnimatedValue;
  cameraAngle,cameraHeight:single;
  mainFont,titleFont:TFontHandle;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Low poly trees generator'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  windowWidth:=1200;
  windowHeight:=800;
  scaleWindowSize:=true;

  //usedPlatform:=spSDL;   // alternative cross-platform solution
  //directRenderOnly:=true; // draw to backbuffer (instead of a screen-size RT-texture for post-processing)
  //windowedMode:=false;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  txt.SetScale(window.screenDPI/96);
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  // (this will wait in a separate thread until scene's Load() is executed
  game.SwitchToScene('Main');
 end;

procedure TMainApp.LoadFonts;
 begin
  inherited;
  txt.LoadFont('Fonts\DroidSans.ttf','Main');
  txt.LoadFont('Fonts\fontawesome-webfont.ttf','Awesome');
 end;

procedure TMainApp.SelectFonts;
 begin
  inherited;
  txt.SetScale(window.screenDPI/96);
  mainFont:=txt.GetFont('Main',10);
  titleFont:=txt.GetFont('Main',12);
 end;

{ TTreeBuilder }

procedure TTreeBuilder.Init(tree:TTreeType);
 var
  path:string;
 begin
  case tree of
   treeGeneric:begin
    gen:=TTreeGenerator.Create('');
   end;
   treeOak:begin
    path:='Trees\Oak';
    ground:=LoadImageFromFile(path+'\ground',liffNoFail);
    gen:=TTreeGenerator.Create(path);
   end;
  end;
 end;

{ TMainScene }

procedure TMainScene.onMouseMove(x,y:integer);
 begin
  inherited;
  // Turn camera around
  if (underMouse=ui) and (window.mouseButtons and mbLeft>0) then begin
   cameraAngle:=cameraAngle-0.5*(x-window.oldMouseX)/window.screenDPI;
   cameraHeight:=Clamp(cameraHeight+0.3*(y-window.oldMouseY)/window.screenDPI,0.35,1.22);
  end;
 end;

procedure TMainScene.onMouseWheel(delta:integer);
 begin
  inherited;
  // Camera zoom
  if (delta<0) and (cameraZoom.FinalValue>0.3) then
   cameraZoom.Animate(cameraZoom.FinalValue/1.3,250,splines.easeInOut);
  if (delta>0) and (cameraZoom.FinalValue<2) then
   cameraZoom.Animate(cameraZoom.FinalValue*1.3,250,splines.easeInOut);
 end;

procedure TMainScene.InitUI;
 var
  font:cardinal;
  btn:TUIButton;
  panel,block:TUIElement;
  lab:TUILabel;
 begin
  font:=txt.GetFont('Default',9);
  UI.SetScale(window.screenDPI/96);

  // UI container
  panel:=TUIElement.Create(220,200,UI,'panel');
  panel.SetPos(ui.clientWidth,0,pivotTopRight);
  panel.SetPadding(5);
  panel.layout:=TRowLayout.CreateVertical(10,true);
  panel.font:=mainFont;

  // View block
  block:=TUIElement.Create(200,100,panel,'Block1');
  block.layout:=TRowLayout.CreateVertical(5,true);
  block.styleInfo:='40202020';

  lab:=TUILabel.Create(200,25,block,'title').Centered('View',titleFont,clWhite);
  lab.styleInfo:='FF305060';

  // Settings block
  block:=TUIElement.Create(200,100,panel,'Block2');
  block.layout:=TRowLayout.CreateVertical(5,true);
  block.styleInfo:='40202020';

  lab:=TUILabel.Create(200,25,block,'title').Centered('View',titleFont,clWhite);
  lab.styleInfo:='FF305060';



{  // Create a button
  btn:=TUIButton.Create(100,32,'Main\Close','Exit',font,UI);
  btn.SetPos(UI.clientWidth/2,UI.clientHeight/2,pivotCenter);
  btn.hint:='Press this button to exit';

  // Link the button click signal to the engine termination signal
  Link('UI\Main\Close\Click','Engine\Cmd\Exit');}
 end;

procedure TMainScene.Load; // This is called from the launch thread, no draw calls allowed
 var
  tree:TTreeType;
 begin
  InitUI;
  cameraZoom.Init(1);
  cameraAngle:=0.75;
  cameraHeight:=0.9;

  for tree:=treeGeneric to treeOak do
    treeGens[tree].Init(tree);

  curTree:=@treeGens[treeGeneric];
 end;

procedure SetupView;
 var
  distance:single;
 begin
  // Set 3D view
  transform.Perspective(1,1,1000);
  distance:=30/cameraZoom.Value;
  transform.SetCamera(
    Point3(distance*cos(cameraAngle)*cos(cameraHeight),
           distance*sin(cameraAngle)*cos(cameraHeight),
           distance*sin(cameraHeight)),
    Point3(0,0,distance*0.25),Point3(0,0,1000));

  gfx.target.UseDepthBuffer(dbPass);

  gfx.SetCullMode(cullNone);
  transform.Transform(Point3(0,0,0));
  gfx.clip.Nothing;
  if curTree.ground<>nil then
   draw.TexturedRect(-20,-20,20,20,curTree.ground,-0.125,-0.125,10.125,-0.125,10.125,10.125,$FFFFFFFF)
  else
   draw.TexturedRect(-20,-20,20,20,game.defaultTexture,-0.125,-0.125,10.125,-0.125,10.125,10.125,$FFFFFFFF);
  // X axis
  draw.Line(0,0,10,0,$FF000090);
  draw.Line(10,0,9,1,$FF000090);
  draw.Line(10,0,9,-1,$FF000090);
  // Y axis
  draw.Line(0,0,0,10,$FF007000);
  draw.Line(0,10,1,9,$FF007000);
  draw.Line(0,10,-1,9,$FF007000);

  gfx.clip.Restore;
 end;

procedure TMainScene.Render;
 begin
  gfx.target.Clear($90B0C0,1); // clear with blue
  SetupView;

  gfx.target.UseDepthBuffer(dbPassLess); // clip anything below the floor plane

  curTree.gen.seed:=1;
  curTree.gen.Build;

  // Setup light and material
  shader.AmbientLight($303030);
  shader.DirectLight(Vector3(1,0.5,1.2),1.0,$FFFFFF);

  // Draw tree skeleton
  curTree.gen.skeleton.Draw;

  // Turn back to 2D view
  transform.DefaultView;
  shader.LightOff;
  shader.DefaultTexMode;
  gfx.target.UseDepthBuffer(dbDisabled); // Disable depth buffer


  inherited; // this will draw the UI elements
 end;


end.
