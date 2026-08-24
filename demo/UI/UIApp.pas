// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit UIApp;
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
 uses Apus.EventMan, Apus.Colors,
   Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure InitGfx; override;
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
  //windowedMode:=false;
  useConsoleScene:=true;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
{  scale:=game.screenDPI/96;
  txt.SetScale(scale);
  SetDefaultUIScale(scale,scale);}
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  game.SwitchToScene('Main');
 end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode:=TDisplayMode.dmWindow; // make window resizeable
 end;

procedure RootCloseCLick;
 begin
  root.Hide;
 end;

procedure InitTestLayer;
 begin
  root.DeleteChildren;
  root.Show;
  TUIButton.Create(100,28,root,'Root\Close').Setup('Back').
   SetPos(root.clientWidth/2,root.clientHeight-2,pivotBottomCenter).
   SetAnchors(0.5,1,0.5,1);
  UIButton('Root\Close').onClickAsync:=@RootCloseClick;
 end;

procedure TestButtons;
 begin
  InitTestLayer;
 end;

procedure TestWidgets;
 var
  cont,hCont:TUIElement;
  lab:TUILabel;
  style:string;
 begin
  InitTestLayer;
  // Container
  cont:=CreateVerticalContainer(150,root,0,10,false);
  cont.SetPos(10,10);
  // Default properties
  TUILabel.SetDefault('styleInfo','40FFFFFF');
  TUILabel.SetDefault('style','color: $FF603000');
  // Labels
  TUILabel.Create(-1,20,cont,'Label1').Setup('Simple label').styleInfo:='hover.fill:F088EEEE; hover.radius=6; hoverTime=1000';
  TUILabel.Create(-1,20,cont,'Label2').Centered('Centered');
  TUILabel.Create(-1,20,cont,'Label3').Right('Right');
  TUILabel.Create(-1,20,cont,'Label4').Setup('With padding').SetPaddings(4,2,4,2);
  TUILabel.Create(120,20,cont,'Label5').Centered('Too Long Text Clipped');
  TUILabel.Create(-1,18,cont,'Label6').Setup('Shifted up').verticalOffset:=2;
  TUILabel.Create(-1,18,cont,'Label7').Setup('Shifted down').verticalOffset:=-2;
  // Buttons
  cont:=CreateVerticalContainer(150,root,0,6,false);
  cont.SetPos(200,10);
  cont.style.SetAttr('color','$FF202020');
  TUIButton.Create(140,30,cont,'Button1').Setup('Button 1');
  TUIButton.Create(140,30,cont,'Disabled').Disable;
  TUISplitter.CreateH(2,cont,$80000000).SetPaddings(5,0,5,0);
  TUIToggleButton.Create(140,30,cont,'Switch1').Setup('Toggle Button');
  hCont:=TUIGroupBox.Create(-1,30,cont);
  hCont.layout:=TRowLayout.Create(true,4,true);
  TUIToggleButton.Create(30,30,hCont,'A').Setup('A',true);
  TUIToggleButton.Create(30,30,hCont,'B').Setup('B');
  TUIToggleButton.Create(30,30,hCont,'C').Setup('C');

  //Create
  TUISplitter.CreateH(2,cont,$80000000).SetPaddings(5,0,5,0);
  // Check boxes
  TUICheckBox.Create(-1,22,cont,'Check1').Setup('checkbox 1 VERYLONG',true);
  TUICheckBox.Create(-1,22,cont,'Check2').Setup('checkbox 2 (red)').SetStyle('tickColor','811');
  TUISplitter.CreateH(10,cont);
  // Radio buttons (TUIGroupBox parent = radio group behavior)
  hCont:=TUIGroupBox.Create(-1,0,cont);
  hCont.layout:=TRowLayout.CreateVertical(0,true);
  TUIRadioButton.Create(100,22,hCont,'Radio1').Setup('radio 1',true);
  TUIRadioButton.Create(100,22,hCont,'Radio2').Setup('radio 2');
  TUIRadioButton.Create(-1,22,hCont,'Radio3').Setup('radio 3 Looooooong');

  TUISplitter.CreateH(2,cont,$80000000).SetPaddings(5,0,5,0);
  // Group box

  cont:=CreateVerticalContainer(150,root,0,6,false);
  cont.SetPos(400,10);
  //Edit boxes
  TUIEditBox.SetDefault('styleInfo','borderColor=444;borderWidth=1; radius=3');
  TUIEditBox.SetDefault('style','color: $FF002040');
  TUIEditBox.Create(-1,24,cont,'Edit1');
  TUIEditBox.Create(-1,24,cont);
  TUISplitter.CreateH(2,cont,$80000000).SetPaddings(5,0,5,0);
  // Scroll
  TUIScrollBar.SetDefault('style','color: $FF405060');
  TUIScrollBar.CreateH(-1,18,cont,'Scroll1');
  TUIScrollBar.CreateH(-1,18,cont,'Scroll2').SetRange(-10,10,0);
  TUIScrollBar.CreateH(-1,18,cont,'Scroll3').SetRange(100,300,50);
  TUISplitter.CreateH(2,cont,$80000000).SetPaddings(5,0,5,0);
  // ListBox
  TUIListBox.SetDefault('styleInfo','borderColor=444; borderWidth=1');
  TUIListBox.Create(-1,80,cont,'List1',20).SetLines(['Line 1','Line 2','Line 3','Line 4','Looong line WWWWW','Last line']);
  UIListBox('List1').textColor:=$FF202020;
  UIListBox('List1').hoverTextColor:=$FF502020;
  // ComboBox
  TUIComboBox.SetDefault('text','Please select...');
  TUIComboBox.Create(-1,22,cont,'Combo1',['Apple','Banana','Cucumber']);

  // Window
  TUIWindow.Create(200,200,true,root,'wnd','Window').
   SetPos(root.clientWidth/2,root.clientHeight*0.9,pivotBottomCenter);

 end;

procedure TestLayouts;
 begin
  InitTestLayer;
  // Status bar

 end;

// R-08 fixture: clipping panel containing two out-of-bounds children.
// - "Popup" has noParentClip → must be hit-testable outside the panel.
// - "Clipped" sibling without noParentClip → must NOT be hit-testable outside.
procedure TestHitTest;
 var
  panel,popup,clipped,deep:TUIElement;
 begin
  InitTestLayer;
  // Clipping panel near top-left
  panel:=TUIElement.Create(200,150,root,'HT\Panel');
  panel.SetPos(50,50);
  panel.styleInfo:='fill:FF505080; border:FFFFFFFF; radius=4';
  panel.shape:=TUIShape.shapeFull;

  // noParentClip popup hanging off panel's right edge
  popup:=TUIElement.Create(160,80,panel,'HT\Popup');
  popup.SetPos(220,30); // x=220 is beyond panel.width=200 → outside panel rect
  popup.flags.noParentClip:=true;
  popup.styleInfo:='fill:FFE08040; border:FFFFFFFF; radius=4';
  popup.shape:=TUIShape.shapeFull;
  TUILabel.Create(-1,20,popup,'HT\Popup\Label').Centered('noParentClip');

  // Negative control: a sibling at the same X offset WITHOUT noParentClip.
  // It must be visually clipped and NOT hit-testable outside the panel.
  clipped:=TUIElement.Create(160,30,panel,'HT\Clipped');
  clipped.SetPos(220,110); // also outside panel
  clipped.styleInfo:='fill:FFE04040; border:FFFFFFFF';
  clipped.shape:=TUIShape.shapeFull;
  TUILabel.Create(-1,20,clipped,'HT\Clipped\Label').Centered('clipped');

  // Deep-nesting case: panel(clips) → mid(clips) → deep(noParentClip).
  // The bug fixed by R-08 is that "deep" was unreachable because the outer
  // panel skipped the mid container (mid has no noParentClip).
  panel:=TUIElement.Create(200,150,root,'HT\Panel2');
  panel.SetPos(50,260);
  panel.styleInfo:='fill:FF508050; border:FFFFFFFF; radius=4';
  panel.shape:=TUIShape.shapeFull;
  popup:=TUIElement.Create(180,120,panel,'HT\Mid');     // intermediate clipper
  popup.SetPos(10,10);
  popup.styleInfo:='fill:FF306030';
  popup.shape:=TUIShape.shapeFull;
  deep:=TUIElement.Create(160,40,popup,'HT\Deep');
  deep.SetPos(230,20); // outside both Mid and Panel2
  deep.flags.noParentClip:=true;
  deep.styleInfo:='fill:FF40C0E0; border:FFFFFFFF; radius=4';
  deep.shape:=TUIShape.shapeFull;
  TUILabel.Create(-1,20,deep,'HT\Deep\Label').Centered('deep noParentClip');
 end;

{ TMainScene }
procedure TMainScene.InitGfx;
 var
  btn:TUIButton;
  panel:TUIElement;
 begin
  // Create menu panel
  panel:=TUIElement.Create(250,400,UI,'MainMenu');
  panel.scale:=1.2;
  panel.Center;
  panel.SetAnchors(anchorCenter);
  panel.layout:=TRowLayout.CreateVertical(10,true,true);
  panel.SetPadding(15);
  //panel.styleInfo:='40E0E0E0 60E0E0E0';
  panel.styleInfo:='Fill:4EEE; border:9EEE; radius=6;';
  panel.style.SetAttr('color','$FF202040');

  // Create menu buttons
  TUIButton.Create(120,30,panel,'Main\Widgets').Setup('Widgets').onClickAsync:=@TestWidgets;
  TUIButton.Create(120,30,panel,'Main\Buttons').Setup('Buttons').onClickAsync:=@TestButtons;
  TUIButton.Create(120,30,panel,'Main\Layouts').Setup('Layouts').onClickAsync:=@TestLayouts;
  TUIButton.Create(120,30,panel,'Main\HitTest').Setup('HitTest').onClickAsync:=@TestHitTest;
  TUIButton.Create(120,30,panel,'Main\Close').Setup('Exit');
  Link('UI\Main\Close\OnClick','Engine\Cmd\Exit');

  // Create a placeholder UI element for demos
  root:=TUIElement.Create(-1,-1,UI,'Root');
  root.SetAnchors(anchorAll);
  //root.styleInfo:='FFB0C0C4 80000000';
  root.styleInfo:='fill:FFB0C0C4; border:80000000';
  root.shape:=TUIShape.shapeFull;
  root.Hide;
 end;

procedure TMainScene.Render;
 var
  i:integer;
 begin
  // 1. Draw scene background
  gfx.target.Clear($406080);
{  for i:=1 to 100 do begin
   draw.Line(1500+i*2,10,1500+i*2,200,$50FFFFFF);
   draw.Line(500+i*2,10,500+i*2,100,$80FFFFFF);
  end;}
  inherited;
  //LogMessage('Color: %8x',[gfx.GetPixelValue(130,20)]);
 end;

end.
