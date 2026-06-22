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
  dynList:TUIListBox;       // Scroll page: list grown/shrunk by Add/Remove buttons
  dynCount:integer;         // Scroll page: current item count of dynList
  dynCountLabel:TUILabel;   // Scroll page: shows dynCount
  freeSlider:TUIScrollBar;  // Scroll page: standalone scrollbar used as a slider
  sliderValLabel:TUILabel;  // Scroll page: live readout of freeSlider.value
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

 // Narrow caption at an explicit (x,y); used for side-by-side column titles.
 function AddCaption(const text:String8;x,y,w:single):TUILabel;
  begin
   result:=TUILabel.Create(w,18,content);
   result.Setup(text).SetPos(x,y);
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
   // Titles flow inside the container (no absolute SetPos) so they can't collide
   // with the page title or with the controls as the layout shifts.
   col:=CreateVerticalContainer(220,content,0,8,false,'');
   col.SetPos(16,40);
   TUILabel.Create(200,18,col).Setup('Dynamic enable & toggle:');
   btnTarget:=TUIButton.Create(200,30,col,'Lab\Target').Setup('Target button');
   TUICheckBox.Create(200,24,col,'Lab\EnableChk').Setup('Target enabled',true).onClick:=@EnableTargetClick;
   TUISplitter.CreateH(2,col,$60808080).SetPaddings(0,4,0,4);
   TUIToggleButton.Create(200,30,col,'').Setup('Independent toggle');
   TUIButton.Create(200,30,col,'').Setup('Disabled button').Disable;

   // Right column: radio group + segmented (toggle group) + checkboxes.
   col:=CreateVerticalContainer(220,content,0,8,false,'');
   col.SetPos(260,40);

   TUILabel.Create(200,18,col).Setup('Radio group (one of many):');
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
   TUICheckBox.Create(200,22,col,'').Setup('Disabled checkbox',true).Disable;
   TUIRadioButton.Create(200,22,col,'').Setup('Disabled radio').Disable;
  end;

// --- Page: Input & focus -----------------------------------------------------

 procedure PageInput;
  var
   col:TUIElement;
   edit:TUIEditBox;
   combo:TUIComboBox;
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

   // Selection widgets on the right. Titles are flowing children of the column,
   // so they track the real layout instead of being pinned at guessed Y offsets
   // (which used to land the combobox caption on top of the combobox).
   col:=CreateVerticalContainer(220,content,0,8,false,'');
   col.SetPos(320,40);
   TUILabel.Create(200,18,col).Setup('ListBox (single select):');
   TUIListBox.Create(200,120,col,'Lab\List',20).SetLines(
     ['Apple','Banana','Cherry','Date','Elderberry','Fig','Grape','Kiwi']);

   TUISplitter.CreateH(6,col);
   TUILabel.Create(200,18,col).Setup('ComboBox (popup):');
   combo:=TUIComboBox.Create(200,24,col,'Lab\Combo',['Low','Medium','High','Ultra']);
   combo.defaultText:='Select quality...'; // placeholder shown while nothing is picked
   combo.curItem:=-1;                       // refresh caption to the placeholder
  end;

// --- Page: Scroll & clipping -------------------------------------------------

 // Rebuild dynList from scratch with dynCount generated items (SetLines is the
 // only public bulk setter; for a demo rebuilding the whole list is fine).
 procedure RebuildDynList;
  var
   i:integer;
   items:Strings8;
  begin
   if dynList=nil then exit;
   SetLength(items,dynCount);
   for i:=0 to dynCount-1 do
    items[i]:='Item '+IntToStr(i+1);
   dynList.SetLines(items);
   if dynCountLabel<>nil then dynCountLabel.Setup('Items: '+IntToStr(dynCount));
  end;

 procedure AddItemClick;    begin inc(dynCount); RebuildDynList; end;
 procedure RemoveItemClick; begin if dynCount>0 then dec(dynCount); RebuildDynList; end;

 procedure PageScroll;
  var
   panel,inner:TUIElement;
   slider:TUIScrollBar;
   btn:TUIButton;
  begin
   AddTitle('Add/remove items to watch the built-in scrollbar appear and hide.',8);

   // Dynamic list: starts below the scroll threshold (no bar); the Add/Remove
   // buttons grow/shrink it across the threshold so the scrollbar shows/hides.
   AddCaption('Dynamic list — Add/Remove items:',16,34,260);
   dynList:=TUIListBox.Create(220,140,content,'Lab\DynList',20);
   dynList.SetPos(16,56);

   btn:=TUIButton.Create(70,26,content,'Lab\AddItem');
   btn.Setup('+ Add').SetPos(16,204);
   btn.onClick:=@AddItemClick;
   btn:=TUIButton.Create(90,26,content,'Lab\RemoveItem');
   btn.Setup('- Remove').SetPos(92,204);
   btn.onClick:=@RemoveItemClick;
   dynCountLabel:=TUILabel.Create(120,18,content);
   dynCountLabel.SetPos(192,208);

   dynCount:=5;            // below threshold (140/20=7 visible) → no scrollbar yet
   RebuildDynList;

   // Clipping demonstration: a panel that clips its overflowing child,
   // plus a sibling marked noParentClip that escapes the clip rect.
   AddCaption('Clipping (gray clipped, orange escapes):',470,34,260);
   panel:=TUIElement.Create(240,150,content,'Lab\ClipPanel');
   panel.SetPos(470,56);
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

   // Standalone scrollbar used as a value slider: drag the thumb or use the
   // wheel over it. The live value is shown by sliderValLabel, refreshed each
   // frame in TUILabScene.Render.
   AddCaption('Free scrollbar as a slider (drag the thumb or use the wheel):',16,250,440);
   slider:=TUIScrollBar.CreateH(360,18,content,'Lab\Slider');
   slider.SetPos(16,274);
   slider.SetRange(0,100,8);
   slider.step:=5;
   slider.MoveTo(30);
   freeSlider:=slider;
   sliderValLabel:=TUILabel.Create(120,18,content);
   sliderValLabel.Setup('Value: 30').SetPos(386,276);
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
   // Explicit height (8+8 padding + 5*28 + 4*6 spacing = 180) so clientHeight is
   // valid immediately — the auto-height overload reports 0 until the first
   // reflow, which made the pinned button below land at the top of the panel.
   panel:=CreateVerticalContainer(220,180,content,8,6,false,'Lab\OOOPanel');
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
   content.DeleteChildren;          // frees page widgets; clear dangling globals below
   btnTarget:=nil;
   dynList:=nil;
   dynCountLabel:=nil;
   freeSlider:=nil;
   sliderValLabel:=nil;
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
  if (freeSlider<>nil) and (sliderValLabel<>nil) then
   sliderValLabel.Setup('Value: '+IntToStr(round(freeSlider.value)));
  inherited;
 end;

end.
