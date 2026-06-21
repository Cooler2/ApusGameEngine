// UI Lab — interactive demo for the Apus Game Engine UI subsystem.
//
// Focus: behaviour of widgets and layouters (NOT visual styling).
// Styles/themes are intentionally left at engine defaults; the only theme
// switch here flips the scene background through a single point (ApplyTheme),
// so a real engine-level theme can be wired in later without touching pages.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit UILabMain;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;
 type
  TUILabApp=class(TGameApplication)
   constructor Create;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TUILabApp;

implementation
 uses SysUtils, Apus.Core, Apus.EventMan, Apus.Colors, Apus.Strings,
   Apus.Engine.Types, Apus.Engine.UI, Apus.Engine.SceneEffects;

 type
  TUILabScene=class(TUIScene)
   procedure InitGfx; override;
   procedure Render; override;
  end;

 const
  topBarHeight=40;

 var
  scene:TUILabScene;
  content:TUIElement;       // page area below the top bar; rebuilt per tab
  btnTarget:TUIButton;      // States page: button toggled on/off by a checkbox
  darkTheme:boolean=true;
  themeBg:cardinal;         // single source of truth for the background color

// --- Theme -------------------------------------------------------------------

 // The ONLY place that knows theme colors. A future engine theme hooks in here.
 procedure ApplyTheme;
  begin
   if darkTheme then themeBg:=$FF202830
    else themeBg:=$FFC8D0D8;
  end;

 procedure ThemeToggleClick;
  begin
   darkTheme:=not darkTheme;
   ApplyTheme;
   if darkTheme then UIButton('Lab\Theme').Setup('Theme: Dark')
    else UIButton('Lab\Theme').Setup('Theme: Light');
  end;

// --- Small helpers -----------------------------------------------------------

 // Section caption stretched across the page width (follows horizontal resize).
 function AddTitle(const text:String8;y:single):TUILabel;
  begin
   result:=TUILabel.Create(content.clientWidth-32,18,content);
   result.Setup(text).SetPos(16,y);
   result.SetAnchors(anchorTop);
  end;

 // Full-width host element fixed at (16,y); right edge follows the window.
 function AddRow(y,height:single):TUIElement;
  begin
   result:=TUIElement.Create(content.clientWidth-32,height,content);
   result.SetPos(16,y);
   result.SetAnchors(anchorTop);
  end;

// --- Page: Layouts -----------------------------------------------------------

 procedure PageLayouts;
  var
   row,flex,grid:TUIElement;
   i:integer;
  begin
   AddTitle('Layouters react every frame — drag the window edges to see reflow.',8);

   // TRowLayout: simple horizontal arrangement, fixed-size children.
   AddTitle('TRowLayout (horizontal):',36);
   row:=CreateHorizontalContainer(32,content,0,8,'');
   row.SetPos(16,56);
   for i:=1 to 4 do
    TUIButton.Create(90,30,row,'').Setup('Item '+IntToStr(i));

   // TFlexboxLayout: middle child has weight=1, so it absorbs free space.
   AddTitle('TFlexboxLayout (middle item has weight=1, grows with width):',100);
   flex:=AddRow(120,32);
   flex.layout:=TFlexboxLayout.Create(8);
   TUIButton.Create(110,30,flex,'').Setup('Fixed');
   TUIButton.Create(110,30,flex,'').Setup('Stretch').layoutData:=1;
   TUIButton.Create(110,30,flex,'').Setup('Fixed');

   // TGridLayout (resizeable): column count derived from width → items reflow.
   AddTitle('TGridLayout (resizeable, ~120px cells, columns reflow):',168);
   grid:=AddRow(188,content.clientHeight-200);
   grid.SetAnchors(anchorAll);
   grid.layout:=TGridLayout.CreateResizeable(8,8,0,0,120);
   for i:=1 to 12 do
    TUIButton.Create(120,40,grid,'').Setup('Cell '+IntToStr(i));
  end;

// --- Page: Widget states -----------------------------------------------------

 procedure EnableTargetClick;
  begin
   if btnTarget=nil then exit;
   if UICheckBox('Lab\EnableChk').checked then btnTarget.Enable
    else btnTarget.Disable;
  end;

 procedure PageStates;
  var
   col,group,seg:TUIElement;
  begin
   AddTitle('Hover / press the controls. Some states are driven dynamically.',8);

   // Left column: dynamic enable/disable + independent toggle.
   col:=CreateVerticalContainer(220,content,0,8,false,'');
   col.SetPos(16,40);
   btnTarget:=TUIButton.Create(200,30,col,'Lab\Target').Setup('Target button');
   TUICheckBox.Create(200,24,col,'Lab\EnableChk').Setup('Target enabled',true).onClick:=@EnableTargetClick;
   TUISplitter.CreateH(2,col,$60808080).SetPaddings(0,4,0,4);
   TUIToggleButton.Create(200,30,col,'').Setup('Independent toggle');
   TUIButton.Create(200,30,col,'').Setup('Disabled button').Disable;

   // Right column: radio group + segmented (toggle group) + checkboxes.
   col:=CreateVerticalContainer(220,content,0,8,false,'');
   col.SetPos(260,40);

   AddTitle('Radio group (one of many):',0).SetPos(260,16);
   group:=TUIGroupBox.Create(200,0,col);
   group.layout:=TRowLayout.CreateVertical(2,true);
   TUIRadioButton.Create(180,22,group,'').Setup('Option A',true);
   TUIRadioButton.Create(180,22,group,'').Setup('Option B');
   TUIRadioButton.Create(180,22,group,'').Setup('Option C');

   TUISplitter.CreateH(8,col);

   // Segmented control: toggle buttons in a group → radio behaviour.
   seg:=TUIGroupBox.Create(200,30,col);
   seg.layout:=TRowLayout.CreateHorizontal(0,true,true);
   TUIToggleButton.Create(60,30,seg,'').Setup('Day',true);
   TUIToggleButton.Create(60,30,seg,'').Setup('Week');
   TUIToggleButton.Create(60,30,seg,'').Setup('Month');

   TUISplitter.CreateH(8,col);
   TUICheckBox.Create(200,22,col,'').Setup('Independent A',true);
   TUICheckBox.Create(200,22,col,'').Setup('Independent B');
  end;

// --- Page: Input & focus -----------------------------------------------------

 procedure PageInput;
  var
   col:TUIElement;
   edit:TUIEditBox;
  begin
   AddTitle('Tab moves focus between fields. Click to focus, type to edit.',8);

   col:=CreateVerticalContainer(280,content,0,8,false,'');
   col.SetPos(16,40);

   edit:=TUIEditBox.Create(260,26,col,'Lab\EditName');
   edit.defaultText:=Str32('Type your name...');   // placeholder

   edit:=TUIEditBox.Create(260,26,col,'Lab\EditLimited');
   edit.defaultText:=Str32('Max 8 chars');
   edit.maxLength:=8;

   edit:=TUIEditBox.Create(260,26,col,'Lab\EditPass');
   edit.defaultText:=Str32('Password');
   edit.password:=true;

   edit:=TUIEditBox.Create(260,26,col,'Lab\EditComplete');
   edit.completion:=Str32('autocompletion');       // ghost text, accepted on Enter

   // Selection widgets on the right.
   col:=CreateVerticalContainer(220,content,0,8,false,'');
   col.SetPos(320,40);
   AddTitle('ListBox (single select):',0).SetPos(320,16);
   TUIListBox.Create(200,120,col,'Lab\List',20).SetLines(
     ['Apple','Banana','Cherry','Date','Elderberry','Fig','Grape','Kiwi']);

   TUISplitter.CreateH(6,col);
   AddTitle('ComboBox (popup):',0).SetPos(320,176);
   TUIComboBox.Create(200,24,col,'Lab\Combo',['Low','Medium','High','Ultra']);
  end;

// --- Page: Scroll & clipping -------------------------------------------------

 procedure PageScroll;
  var
   panel,inner:TUIElement;
   list:TUIListBox;
   i:integer;
  begin
   AddTitle('TUIListBox scrolls itself; the panel clips overflowing children.',8);

   // TUIListBox owns its scrollbar (created internally) and reacts to the mouse
   // wheel — no external scrollbar needed. Linking one would just fight the
   // built-in scroller, so we let the list manage itself.
   AddTitle('List (mouse wheel or built-in scrollbar):',36);
   list:=TUIListBox.Create(240,180,content,'Lab\ScrollList',20);
   list.SetPos(16,58);
   for i:=1 to 40 do
    list.AddLine('Line '+IntToStr(i));

   // Clipping demonstration: a panel that clips its overflowing child,
   // plus a sibling marked noParentClip that escapes the clip rect.
   AddTitle('Clipping (gray clipped, orange escapes):',0).SetPos(300,36);
   panel:=TUIElement.Create(240,150,content,'Lab\ClipPanel');
   panel.SetPos(300,58);
   panel.style.SetAttr('fill','$FF405068');
   panel.style.SetAttr('border','$FFFFFFFF');
   panel.shape:=TUIShape.shapeFull;

   inner:=TUIElement.Create(160,40,panel,'');
   inner.SetPos(140,120);                  // hangs off the panel → clipped
   inner.style.SetAttr('fill','$FF808890');
   inner.shape:=TUIShape.shapeFull;
   TUILabel.Create(-1,20,inner).Centered('clipped');

   inner:=TUIElement.Create(150,36,panel,'');
   inner.SetPos(180,20);                    // also outside, but escapes the clip
   inner.flags.noParentClip:=true;
   inner.style.SetAttr('fill','$FFE08040');
   inner.style.SetAttr('border','$FFFFFFFF');
   inner.shape:=TUIShape.shapeFull;
   TUILabel.Create(-1,20,inner).Centered('noParentClip');
  end;

// --- Page: Out-of-order elements ---------------------------------------------

 procedure PageOutOfOrder;
  var
   panel,pinned:TUIElement;
   i:integer;
  begin
   AddTitle('An out-of-order element ignores the layouter and parent clipping.',8);
   AddTitle('Below: 5 buttons are arranged by TRowLayout; "Pinned" is pulled out.',30);

   // Managed children: laid out vertically by the panel's row layout.
   panel:=CreateVerticalContainer(220,content,8,6,false,'Lab\OOOPanel');
   panel.SetPos(16,60);
   panel.style.SetAttr('fill','$FF304058');
   panel.style.SetAttr('border','$FF90A0C0');
   panel.shape:=TUIShape.shapeFull;
   for i:=1 to 5 do
    TUIButton.Create(200,28,panel,'').Setup('Row item '+IntToStr(i));

   // Out-of-order child: order>=$10000 makes IsOutOfOrder true, so the layouter
   // skips it and it stays where we put it; noParentClip lets it cross the edge.
   pinned:=TUIButton(TUIButton.Create(140,30,panel,'Lab\Pinned').Setup('Pinned'));
   pinned.SetPos(panel.clientWidth-50,panel.clientHeight-15);
   pinned.order:=$10000;             // stay-on-top + excluded from layout
   pinned.flags.noParentClip:=true;  // not clipped by the panel

   AddTitle('The "Pinned" button keeps its manual position and overhangs the panel.',
     content.clientHeight-30).SetAnchors(anchorBottom);
  end;

// --- Navigation --------------------------------------------------------------

 procedure ShowPage(index:integer);
  begin
   content.DeleteChildren;
   btnTarget:=nil;
   case index of
    0: PageLayouts;
    1: PageStates;
    2: PageInput;
    3: PageScroll;
    4: PageOutOfOrder;
   end;
  end;

 procedure TabLayouts;  begin ShowPage(0); end;
 procedure TabStates;   begin ShowPage(1); end;
 procedure TabInput;    begin ShowPage(2); end;
 procedure TabScroll;   begin ShowPage(3); end;
 procedure TabOutOfOrder; begin ShowPage(4); end;

// --- Application -------------------------------------------------------------

constructor TUILabApp.Create;
 begin
  inherited;
  gameTitle:='Apus Game Engine: UI Lab';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  useConsoleScene:=true;
 end;

procedure TUILabApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmWindow; // resizeable window — needed for layout demos
 end;

procedure TUILabApp.CreateScenes;
 begin
  inherited;
  scene:=TUILabScene.Create('UILab');
  game.SwitchToScene('UILab');
 end;

// --- Scene -------------------------------------------------------------------

procedure TUILabScene.InitGfx;
 var
  tabs:TUIGroupBox;
  themeBtn:TUIButton;
 begin
  ApplyTheme;

  // Top bar: tab group on the left, theme toggle pinned to the right.
  tabs:=TUIGroupBox.Create(700,topBarHeight-6,UI,'Lab\Tabs');
  tabs.SetPos(6,3);
  tabs.layout:=TRowLayout.CreateHorizontal(4,true,true);
  TUIToggleButton.Create(90,30,tabs,'').Setup('Layouts',true).onClick:=@TabLayouts;
  TUIToggleButton.Create(90,30,tabs,'').Setup('States').onClick:=@TabStates;
  TUIToggleButton.Create(90,30,tabs,'').Setup('Input').onClick:=@TabInput;
  TUIToggleButton.Create(90,30,tabs,'').Setup('Scroll').onClick:=@TabScroll;
  TUIToggleButton.Create(110,30,tabs,'').Setup('Out-of-order').onClick:=@TabOutOfOrder;

  themeBtn:=TUIButton.Create(110,30,UI,'Lab\Theme').Setup('Theme: Dark');
  themeBtn.SetPos(UI.clientWidth-6,3,pivotTopRight).SetAnchors(anchorTopRight);
  themeBtn.onClick:=@ThemeToggleClick;

  // Content area fills everything below the top bar and follows the window.
  content:=TUIElement.Create(UI.clientWidth,UI.clientHeight-topBarHeight,UI,'Lab\Content');
  content.SetPos(0,topBarHeight);
  content.SetAnchors(anchorAll);

  ShowPage(0);
 end;

procedure TUILabScene.Render;
 begin
  gfx.target.Clear(themeBg);
  inherited;
 end;

end.
