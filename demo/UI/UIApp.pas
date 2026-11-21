// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)

unit UIApp;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   procedure SetupApplication; override;
   procedure CreateScenes; override;
   procedure SetupGameSettings(var settings:TGameSettings); override;
  end;

 var
  application:TMainApp;

implementation
 uses Apus.EventMan, Apus.Colors,
   SysUtils, Apus.Core, Apus.Conv, Apus.Geom2D, Apus.Engine.UI, Apus.Engine.UIMenu,
   Apus.Engine.UIColorPicker, Apus.Engine.TextFXStyle, Apus.Engine.DefaultStyle;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure InitGfx; override;
   procedure Render; override;
   procedure ColorPreview(sender:TUIColorButton;oldColor,newColor:cardinal);
   procedure ColorChanged(sender:TUIColorButton;oldColor,newColor:cardinal);
   procedure ColorCancelled(sender:TUIColorButton;oldColor,newColor:cardinal);
   procedure SaveColors;
   procedure ToggleColorAlpha;
  end;

  // An application-owned editor, supplied through the color button's factory.
  // It uses child keyboard focus and exact input instead of the default H/SV fields.
  THexColorEditor=class(TUIColorEditor)
   constructor Create(parent:TUIElement;const name:String8); override;
   procedure SetColor(value:cardinal); override;
   function CanAccept:boolean; override;
   function PreferredSize:TVec2; override;
   function InitialFocus:TUIElement; override;
   procedure Refresh; override;
  private
   input:TUIEditBox;
   procedure EditChanged;
  end;

 var
  sceneMain:TMainScene;
  root:TUIElement;
  demoMenu:TUIPopupMenu;
  menuResult:TUILabel;
  colorResult,saveResult:TUILabel;
  colorA,colorB:TUIColorButton;
  colorCommits,colorSaves:integer;

constructor THexColorEditor.Create(parent:TUIElement;const name:String8);
 begin
  inherited;
  TUILabel.Create(240,22,self,name+'\Title').Setup('Application HEX editor');
  input:=TUIEditBox.Create(240,26,self,name+'\Hex'); input.SetPos(0,26);
  input.maxLength:=8; input.onChange:=EditChanged;
 end;

procedure THexColorEditor.SetColor(value:cardinal);
 begin
  inherited;
  if alphaEnabled then input.text:=Conv.ToHex(color,8)
   else input.text:=Conv.ToHex(color and $FFFFFF,6);
 end;

function THexColorEditor.CanAccept:boolean;
 var
  n:int64;
  digits:integer;
 begin
  if alphaEnabled then digits:=8 else digits:=6;
  result:=(length(input.text)=digits) and TryStrToInt64('$'+string(input.text),n) and (n>=0) and (n<=High(cardinal));
 end;
function THexColorEditor.PreferredSize:TVec2;
 begin result:=Vec2(240,58); end;
function THexColorEditor.InitialFocus:TUIElement;
 begin result:=input; end;
procedure THexColorEditor.EditChanged;
 var n:int64;
 begin
  if CanAccept and TryStrToInt64('$'+string(input.text),n) then ChooseColor(cardinal(n));
 end;
procedure THexColorEditor.Refresh;
 begin
  if alphaEnabled then input.maxLength:=8 else input.maxLength:=6;
 end;

procedure TMainScene.ColorPreview(sender:TUIColorButton;oldColor,newColor:cardinal);
 begin colorResult.caption:='Preview ARGB $'+Conv.ToHex(newColor,8); end;
procedure TMainScene.ColorChanged(sender:TUIColorButton;oldColor,newColor:cardinal);
 begin
  inc(colorCommits);
  colorResult.caption:='Commit '+Conv.ToStr(colorCommits)+' ARGB $'+Conv.ToHex(newColor,8);
 end;
procedure TMainScene.ColorCancelled(sender:TUIColorButton;oldColor,newColor:cardinal);
 begin colorResult.caption:='Cancel ARGB $'+Conv.ToHex(oldColor,8); end;
procedure TMainScene.SaveColors;
 begin
  inc(colorSaves);
  saveResult.caption:='Save '+Conv.ToStr(colorSaves)+' ARGB $'+Conv.ToHex(colorA.color,8)+
   ' $'+Conv.ToHex(colorB.color,8);
 end;

procedure TMainScene.ToggleColorAlpha;
 begin colorA.alphaEnabled:=TUIToggleButton(TUIButton.Sender).toggled; end;

procedure TMainApp.SetupApplication;
 begin
  inherited;
  appSetup.title:='Apus Game Engine: UI Demo'; // app window title
  requestBackend.graphicsAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  //requestBackend.platform:=spSDL;
  //windowSetup.fullscreen:=true;
  startupScenes.console:=true;
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
 var
  panel:TUIElement;
  check:TUICheckBox;
  radio:TUIRadioButton;
  button:TUIButton;
  i,j:integer;
  id,disabledStyle,shadowOffset:String8;
  emboss:TUIEmbossStyle;
 begin
  InitTestLayer;
  for i:=0 to 2 do begin
   id:='Disabled'+Conv.ToStr(i);
   panel:=TUIElement.Create(250,490,root,id);
   panel.SetPos(16+i*264,16);
   panel.shape:=TUIShape.shapeFull;
   case i of
    0:panel.styleInfo:='fill:$FFE0E0E0; color:$FF303030';
    1:panel.styleInfo:='fill:$FF282C34; color:$FFE0E0E0';
    else panel.styleInfo:='fill:$FF607C70; color:$FF183028';
   end;
   panel.style.SetAttr('disabled-effect','emboss'); // inherited by all controls below
   emboss:=ResolveEmboss(panel.GetStyleColor('color'));
   shadowOffset:=Conv.ToStr(emboss.highlightX/panel.globalScale)+' '+Conv.ToStr(emboss.highlightY/panel.globalScale);
   TUILabel.Create(230,24,panel,id+'Title').Setup('Enabled / disabled').SetPos(10,8);
   TUICheckBox.Create(230,26,panel,id+'EnabledOn').Setup('Enabled checked',true).SetPos(10,40);
   TUICheckBox.Create(230,26,panel,id+'EnabledOff').Setup('Enabled unchecked').SetPos(10,70);
   for j:=0 to 2 do begin
    case j of
     0:disabledStyle:=''; // derive both dimming and highlight from the inherited text color
     1:disabledStyle:=':disabled { border-light:$FFFFFFFF; text-shadow:$FFFFFFFF '+shadowOffset+'; }';
     else disabledStyle:=':disabled { border-light:$30FFFFFF; text-shadow:$30FFFFFF '+shadowOffset+'; }';
    end;
    case j of
     0:TUILabel.Create(230,20,panel,id+'White').Setup('Automatic emboss').SetPos(10,110);
     1:TUILabel.Create(230,20,panel,id+'Tinted').Setup('Override: opaque white').SetPos(10,200);
     2:TUILabel.Create(230,20,panel,id+'Flat').Setup('Override: weak white').SetPos(10,290);
    end;
    check:=TUICheckBox.Create(230,26,panel,id+'On'+Conv.ToStr(j));
    check.Setup('Disabled checked',true).SetPos(10,132+j*90);
    check.styleInfo:=disabledStyle; check.Disable;
    check:=TUICheckBox.Create(230,26,panel,id+'Off'+Conv.ToStr(j));
    check.Setup('Disabled unchecked').SetPos(10,158+j*90);
    check.styleInfo:=disabledStyle; check.Disable;
   end;
   radio:=TUIRadioButton.Create(230,26,panel,id+'Radio');
   radio.Setup('Disabled radio',true).SetPos(10,370); radio.Disable;
   button:=TUIButton.Create(230,30,panel,id+'Button').Setup('Disabled button');
   button.SetPos(10,408); button.styleInfo:='fill:none; fill-shade:none; border-light:0; border-dark:0';
   button.Disable;
   button:=TUIButton.Create(230,30,panel,id+'TextFX').Setup('Disabled TextFX');
   button.SetPos(10,448); button.styleInfo:='fill:none; fill-shade:none; border-light:0; border-dark:0';
   button.drawer:=@DrawTextFXStyle; button.Disable;
  end;
 end;

procedure TestColors;
 var
  custom:TUIColorButton;
 begin
  InitTestLayer;
  colorCommits:=0; colorSaves:=0;
  TUILabel.Create(640,26,root,'Colors\Help').Setup('Choose a color, then click Save or another swatch. Escape cancels.').SetPos(20,20);
  colorA:=TUIColorButton.Create(100,36,root,'Colors\A');
  colorA.SetPos(20,64); colorA.color:=$FF40A0D0;
  colorA.onPreview:=sceneMain.ColorPreview; colorA.onChange:=sceneMain.ColorChanged; colorA.onCancel:=sceneMain.ColorCancelled;
  colorB:=TUIColorButton.Create(100,36,root,'Colors\B');
  colorB.SetPos(140,64); colorB.color:=$FFD09040;
  colorB.alphaEnabled:=false;
  colorB.onPreview:=sceneMain.ColorPreview; colorB.onChange:=sceneMain.ColorChanged; colorB.onCancel:=sceneMain.ColorCancelled;
  custom:=TUIColorButton.Create(100,36,root,'Colors\Custom');
  custom.SetPos(260,64); custom.color:=$FF406040; custom.editorClass:=THexColorEditor;
  custom.onPreview:=sceneMain.ColorPreview; custom.onChange:=sceneMain.ColorChanged; custom.onCancel:=sceneMain.ColorCancelled;
  TUILabel.Create(240,22,root,'Colors\CustomLabel').Setup('Custom ARGB HEX editor').SetPos(260,104);
  TUICheckBox.Create(230,24,root,'Colors\AlphaEnabled').Setup('Alpha for first picker',true).SetPos(20,112);
  UIButton('Colors\AlphaEnabled').onClickMethod:=sceneMain.ToggleColorAlpha;
  TUIButton.Create(100,32,root,'Colors\Save').Setup('Save').SetPos(400,64);
  UIButton('Colors\Save').onClickMethod:=sceneMain.SaveColors;
  colorResult:=TUILabel.Create(640,26,root,'Colors\Result'); colorResult.SetPos(20,150);
  saveResult:=TUILabel.Create(640,26,root,'Colors\Saved'); saveResult.SetPos(20,182);
  // Edge placement and a different scale use the same editor and shared MRU.
  custom:=TUIColorButton.Create(80,30,root,'Colors\Edge');
  custom.SetPos(root.clientWidth-90,root.clientHeight-45).SetAnchors(1,1,1,1);
  custom.color:=$80A060C0;
  custom.onChange:=sceneMain.ColorChanged; custom.onCancel:=sceneMain.ColorCancelled;
 end;

// Commands of the popup menu on the Widgets page
procedure CmdNew;
 begin
  menuResult.caption:='Menu: New';
 end;

procedure CmdOpen;
 begin
  menuResult.caption:='Menu: Open';
 end;

procedure CmdSave;
 begin
  menuResult.caption:='Menu: Save';
 end;

procedure CmdRecent;
 begin
  menuResult.caption:='Menu: '+TUIButton.Sender.caption;
 end;

// The Menu button owns the menu: the menu opens below it, the next press closes it.
// A tool button takes no focus, so closing the menu returns the focus where it was
procedure ShowDemoMenu;
 begin
  demoMenu.OpenBelow(UIButton('MenuBtn'));
 end;

// Popup menu: lines with shortcut texts (display only), separators, disabled lines, submenus.
// A line is a button: its command is onClick, onClickAsync, onClickEvent or a method in 'handler'.
// A submenu opens on hover (after a delay), a click or Right/Enter; Left/Esc close one level
procedure CreateDemoMenu;
 var
  recent,older:TUIPopupMenu;
 begin
  demoMenu:=TUIPopupMenu.Create(root,'DemoMenu');
  demoMenu.Add('New','Ctrl+N').onClick:=@CmdNew;
  demoMenu.Add('Open...','Ctrl+O').onClick:=@CmdOpen;
  recent:=demoMenu.AddSubmenu('Recent files');
  recent.Add('notes.txt').onClick:=@CmdRecent;
  recent.Add('picture.png').onClick:=@CmdRecent;
  older:=recent.AddSubmenu('Older');
  older.Add('draft.txt').onClick:=@CmdRecent;
  older.Add('old.png').onClick:=@CmdRecent;
  demoMenu.Add('Save','Ctrl+S').onClick:=@CmdSave;
  demoMenu.AddSeparator;
  demoMenu.Add('Undo','Ctrl+Z').Disable;
  demoMenu.Add('Redo','Ctrl+Y').Disable;
  demoMenu.AddSeparator;
  demoMenu.Add('Close page').onClickAsync:=@RootCloseClick; // like the Back button
 end;

// Menu bar page: File/Edit/View/Help over the page. A click opens a heading, then hover
// switches the headings; Left/Right move between them, the other keys work in the menus.
// The keyboard: F10 or a single Alt selects the first heading, Alt+letter opens a heading,
// a letter in a menu runs its line ('&' marks the mnemonics, underlined in the keyboard mode).
// The edit box shows that the focus returns where it was when the menu closes
var
  barResult:TUILabel;

procedure CmdBar;
 begin
  barResult.caption:='Menu bar: '+MenuCaptionText(TUIButton.Sender.caption);
 end;

procedure TestMenuBar;
 var
  bar:TUIMenuBar;
  m,s:TUIPopupMenu;
 begin
  InitTestLayer;
  bar:=TUIMenuBar.Create(root,'MenuBar');
  bar.SetPos(0,0).SetAnchors(0,0,1,0);
  m:=bar.AddSubmenu('&File');
  m.Add('&New','Ctrl+N').onClick:=@CmdBar;
  m.Add('&Open...','Ctrl+O').onClick:=@CmdBar;
  s:=m.AddSubmenu('&Recent files');
  s.Add('&notes.txt').onClick:=@CmdBar;
  s.Add('&picture.png').onClick:=@CmdBar;
  m.Add('&Save','Ctrl+S').onClick:=@CmdBar;
  m.AddSeparator;
  m.Add('&Close page').onClickAsync:=@RootCloseClick;
  m:=bar.AddSubmenu('&Edit');
  m.Add('&Undo','Ctrl+Z').Disable;
  m.Add('Cu&t','Ctrl+X').onClick:=@CmdBar;
  m.Add('&Copy','Ctrl+C').onClick:=@CmdBar;
  m.Add('&Paste','Ctrl+V').onClick:=@CmdBar;
  m:=bar.AddSubmenu('&View');
  s:=m.AddSubmenu('&Panels');
  s.Add('&Layers').onClick:=@CmdBar;
  s.Add('&Colors').onClick:=@CmdBar;
  m.Add('Zoom &in','Ctrl++').onClick:=@CmdBar;
  m.Add('Zoom &out','Ctrl+-').onClick:=@CmdBar;
  bar.AddSubmenu('&Tools').ownerItem.Disable; // a disabled heading is skipped
  bar.AddSubmenu('&Help').Add('&About').onClick:=@CmdBar;
  TUIEditBox.Create(200,24,root,'MenuBarEdit').SetPos(20,60);
  barResult:=TUILabel.Create(300,22,root,'MenuBarResult');
  barResult.SetPos(20,100);
  barResult.caption:='Menu bar: -';
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
  TUILabel.SetDefault('styleInfo','fill:$40FFFFFF; color:$FF603000');
  // Labels
  TUILabel.Create(-1,20,cont,'Label1').Setup('Simple label').styleInfo:='hover.fill:F088EEEE; hover.radius=6; hover-time:1000';
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
  TUIToolButton.Create(140,30,cont,'MenuBtn').Setup('Menu').onClick:=@ShowDemoMenu;
  menuResult:=TUILabel.Create(-1,20,cont,'MenuResult');
  CreateDemoMenu;
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
  TUICheckBox.Create(-1,22,cont,'Check2').Setup('checkbox 2 (red)').style.SetAttr('tick-color','#811');
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
  TUIEditBox.SetDefault('styleInfo','border-color:#444; border-width:1; radius:3; color:$FF002040');
  TUIEditBox.Create(-1,24,cont,'Edit1');
  TUIEditBox.Create(-1,24,cont);
  TUISplitter.CreateH(2,cont,$80000000).SetPaddings(5,0,5,0);
  // Scroll
  TUIScrollBar.SetDefault('styleInfo','color:$FF405060');
  TUIScrollBar.CreateH(-1,18,cont,'Scroll1');
  TUIScrollBar.CreateH(-1,18,cont,'Scroll2').SetRange(-10,10,0);
  TUIScrollBar.CreateH(-1,18,cont,'Scroll3').SetRange(100,300,50);
  TUISplitter.CreateH(2,cont,$80000000).SetPaddings(5,0,5,0);
  // ListBox
  TUIListBox.SetDefault('styleInfo','border-color:#444; border-width:1');
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
  panel.styleInfo:='fill:FF505080; border-color:FFFFFFFF; radius=4';
  panel.shape:=TUIShape.shapeFull;

  // noParentClip popup hanging off panel's right edge
  popup:=TUIElement.Create(160,80,panel,'HT\Popup');
  popup.SetPos(220,30); // x=220 is beyond panel.width=200 → outside panel rect
  popup.flags.noParentClip:=true;
  popup.styleInfo:='fill:FFE08040; border-color:FFFFFFFF; radius=4';
  popup.shape:=TUIShape.shapeFull;
  TUILabel.Create(-1,20,popup,'HT\Popup\Label').Centered('noParentClip');

  // Negative control: a sibling at the same X offset WITHOUT noParentClip.
  // It must be visually clipped and NOT hit-testable outside the panel.
  clipped:=TUIElement.Create(160,30,panel,'HT\Clipped');
  clipped.SetPos(220,110); // also outside panel
  clipped.styleInfo:='fill:FFE04040; border-color:FFFFFFFF';
  clipped.shape:=TUIShape.shapeFull;
  TUILabel.Create(-1,20,clipped,'HT\Clipped\Label').Centered('clipped');

  // Deep-nesting case: panel(clips) → mid(clips) → deep(noParentClip).
  // The bug fixed by R-08 is that "deep" was unreachable because the outer
  // panel skipped the mid container (mid has no noParentClip).
  panel:=TUIElement.Create(200,150,root,'HT\Panel2');
  panel.SetPos(50,260);
  panel.styleInfo:='fill:FF508050; border-color:FFFFFFFF; radius=4';
  panel.shape:=TUIShape.shapeFull;
  popup:=TUIElement.Create(180,120,panel,'HT\Mid');     // intermediate clipper
  popup.SetPos(10,10);
  popup.styleInfo:='fill:FF306030';
  popup.shape:=TUIShape.shapeFull;
  deep:=TUIElement.Create(160,40,popup,'HT\Deep');
  deep.SetPos(230,20); // outside both Mid and Panel2
  deep.flags.noParentClip:=true;
  deep.styleInfo:='fill:FF40C0E0; border-color:FFFFFFFF; radius=4';
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
  panel.styleInfo:='Fill:4EEE; border-color:9EEE; radius=6;';
  panel.style.SetAttr('color','$FF202040');

  // Create menu buttons
  TUIButton.Create(120,30,panel,'Main\Widgets').Setup('Widgets').onClickAsync:=@TestWidgets;
  TUIButton.Create(120,30,panel,'Main\Buttons').Setup('Buttons').onClickAsync:=@TestButtons;
  TUIButton.Create(120,30,panel,'Main\Layouts').Setup('Layouts').onClickAsync:=@TestLayouts;
  TUIButton.Create(120,30,panel,'Main\HitTest').Setup('HitTest').onClickAsync:=@TestHitTest;
  TUIButton.Create(120,30,panel,'Main\Colors').Setup('Color Picker').onClick:=@TestColors;
  TUIButton.Create(120,30,panel,'Main\MenuBar').Setup('Menu bar').onClickAsync:=@TestMenuBar;
  TUIButton.Create(120,30,panel,'Main\Close').Setup('Exit');
  Link('UI\Main\Close\OnClick','Engine\Cmd\Exit');

  // Create a placeholder UI element for demos
  root:=TUIElement.Create(-1,-1,UI,'Root');
  root.SetAnchors(anchorAll);
  //root.styleInfo:='FFB0C0C4 80000000';
  root.styleInfo:='fill:FFB0C0C4; border-color:80000000';
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
