// R-05 Style System demo for the Apus Game Engine

// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit StyleDemoApp;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;
 type
  TStyleDemoApp=class(TGameApplication)
   constructor Create;
   procedure LoadOptions; override;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TStyleDemoApp;

implementation
 uses SysUtils, Apus.Core, Apus.Strings, Apus.EventMan,
   Apus.Engine.Types, Apus.Engine.Scene, Apus.Engine.SceneEffects,
   Apus.Engine.UI, Apus.Engine.UIWidgets, Apus.Engine.Style,
   StyleThemeEditorScene;

 type
  TStyleDemoScene=class(TUIScene)
   procedure CreateUI;
   procedure Render; override;
  end;

 var
  mainScene:TStyleDemoScene;
  editorScene:TStyleThemeEditorScene;
  styleRefToggle:boolean; // for the @ref update button demo

{ TStyleDemoApp }

constructor TStyleDemoApp.Create;
 var
  st:string;
 begin
  {$IFDEF SDL}
  usedPlatform:=spSDL;
  {$ELSE}
  usedPlatform:=spDefault;
  {$ENDIF}
  inherited;
  windowWidth:=1280;
  windowHeight:=560;
  windowSizeable:=true;
  scaleWindowSize:=false;
  st:=ExtractFileDir(ParamStr(0));
  SetCurrentDir(st);
  if DirectoryExists('../demo/StyleDemo') then
    SetCurrentDir('../demo/StyleDemo');

  gameTitle:='R-05 Style System Demo';
  usedAPI:=gaOpenGL2;
 end;

procedure TStyleDemoApp.LoadOptions;
 begin
  inherited;
  // Keep the showcase wide enough for the separate editor scene even if an old
  // local config contains a smaller StyleDemo window size.
  windowWidth:=1280;
  windowHeight:=560;
  windowSizeable:=true;
  scaleWindowSize:=false;
 end;

procedure TStyleDemoApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.width:=1280;
  settings.height:=560;
  settings.mode.displayMode:=dmWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
 end;

procedure RegisterDemoStyles;
 begin
  Styles['demo-label']:='text-color:&text; color:&text; font-size:9;';
  Styles['demo-muted-label']:='text-color:&text-muted; color:&text-muted; font-size:8;';
  Styles['demo-panel']:='fill:&surface; border-color:&border; border-width:1; radius:8;';
  Styles['demo-showcase']:='fill:&surface-alt; border-color:&border-light; border-width:1; radius:6;';
  Styles['demo-button']:='color:&control; text-color:&text; border-width:1; border-color:&border; radius:5;'+
    ':hover { color:&accent; text-color:&accent-text; }'+
    ':pressed { color:&danger; text-color:&danger-text; }';
  Styles['demo-input']:='fill:&overlay; text-color:&text; border-color:&border; border-width:1; radius:4;'+
    ':focused { border-color:&focus; }';
  Styles['demo-list']:='fill:&overlay; text-color:&text; sel-bg:&accent; sel-text-color:&accent-text;'+
    'border-color:&border; border-width:1; radius:4;';
  Styles['demo-slider']:='col:&control; track-col:&border-dark; active-col:&accent;'+
    'track-width:0.35; slider-width:0.82; min-size:0.4; radius:0.18;';
  Styles['demo-check']:='color:&control; text-color:&text; border-color:&border; radius:4;';
  Styles['demo-btn']:='@demo-button; color:&accent; text-color:&accent-text;';
 end;

procedure TStyleDemoApp.CreateScenes;
 begin
  inherited;
  RegisterDemoStyles;

  mainScene:=TStyleDemoScene.Create('StyleDemo');
  mainScene.CreateUI;
  mainScene.SetStatus(TSceneStatus.ssActive);

  editorScene:=TStyleThemeEditorScene.Create;
  editorScene.CreateUI;
  editorScene.SetStatus(TSceneStatus.ssActive);

  Sleep(250);
  TTransitionEffect.Create(mainScene,250);
 end;

{ TStyleDemoScene }

procedure StyleDemoUpdateRef;
 begin
  styleRefToggle:=not styleRefToggle;
  if styleRefToggle then
   Styles['demo-btn']:='@demo-button; color:&danger; text-color:&danger-text; radius:12;'
  else
   Styles['demo-btn']:='@demo-button; color:&accent; text-color:&accent-text; radius:5;';
 end;

function Panel(parent:TUIElement;x,y,w,h:single;const name,title:String8):TUIElement;
 var
  lbl:TUILabel;
 begin
  result:=TUIElement.Create(w,h,parent,'StyleDemo\'+name);
  result.SetPos(x,y,pivotTopLeft);
  result.style.Assign('@demo-panel;');
  lbl:=TUILabel.Create(w-24,20,result,'StyleDemo\'+name+'Title');
  lbl.Setup(title);
  lbl.SetPos(12,10,pivotTopLeft);
  lbl.style.Assign('@demo-label; font-size:10;');
 end;

procedure MakeLabel(parent:TUIElement;x,y,w:single;const text:String8;muted:boolean=false);
 var
  lbl:TUILabel;
 begin
  lbl:=TUILabel.Create(w,18,parent);
  lbl.Setup(text);
  lbl.SetPos(x,y,pivotTopLeft);
  if muted then lbl.style.Assign('@demo-muted-label;')
   else lbl.style.Assign('@demo-label;');
 end;

procedure StyleButton(btn:TUIButton;const styleText:String8='@demo-button;');
 begin
  btn.style.Assign(styleText);
 end;

procedure TStyleDemoScene.CreateUI;
 var
  panel1,panel2,panel3,panel4:TUIElement;
  group:TUIGroupBox;
  btn:TUIButton;
  edit:TUIEditBox;
  list:TUIListBox;
  scroll:TUIScrollBar;
 begin
  panel1:=Panel(UI,18,18,370,250,'Buttons','Buttons and states');
  MakeLabel(panel1,12,40,320,'Buttons demonstrate @refs, hover, pressed and disabled states.',true);

  btn:=TUIButton.Create(150,32,panel1,'StyleDemo\BtnDefault').Setup('Default drawer');
  btn.SetPos(12,74,pivotTopLeft);

  btn:=TUIButton.Create(170,32,panel1,'StyleDemo\BtnToken').Setup('Token button');
  btn.SetPos(190,74,pivotTopLeft);
  StyleButton(btn);

  btn:=TUIButton.Create(150,32,panel1,'StyleDemo\BtnRef').Setup('@demo-btn');
  btn.SetPos(12,118,pivotTopLeft);
  StyleButton(btn,'@demo-btn;');

  btn:=TUIButton.Create(170,32,panel1,'StyleDemo\BtnToggleRef').Setup('Toggle @demo-btn');
  btn.SetPos(190,118,pivotTopLeft);
  StyleButton(btn);
  btn.onClickAsync:=@StyleDemoUpdateRef;

  btn:=TUIButton.Create(150,32,panel1,'StyleDemo\BtnDisabled').Setup('Disabled');
  btn.SetPos(12,162,pivotTopLeft);
  StyleButton(btn);
  btn.flags.enabled:=false;

  btn:=TUIButton.Create(170,32,panel1,'StyleDemo\BtnDanger').Setup('Danger override');
  btn.SetPos(190,162,pivotTopLeft);
  StyleButton(btn,'@demo-button; color:&danger; text-color:&danger-text; radius:12;');

  panel2:=Panel(UI,18,286,370,226,'Inputs','Inputs and selection');
  MakeLabel(panel2,12,40,330,'These widgets use editable named style blocks.',true);

  edit:=TUIEditBox.Create(210,26,panel2,'StyleDemo\SampleEdit');
  edit.text:='Editable text';
  edit.SetPos(12,74,pivotTopLeft);
  edit.style.Assign('@demo-input;');

  group:=TUIGroupBox.Create(140,74,panel2,'StyleDemo\RadioGroup');
  group.SetPos(228,70,pivotTopLeft);
  TUICheckBox.Create(130,24,group,'StyleDemo\Check').Setup('Checkbox',true).
    SetPos(0,0,pivotTopLeft).style.Assign('@demo-check;');
  TUIRadioButton.Create(130,24,group,'StyleDemo\Radio1').Setup('Radio A',true).
    SetPos(0,26,pivotTopLeft).style.Assign('@demo-check;');
  TUIRadioButton.Create(130,24,group,'StyleDemo\Radio2').Setup('Radio B',false).
    SetPos(0,52,pivotTopLeft).style.Assign('@demo-check;');

  list:=TUIListBox.Create(210,74,panel2,'StyleDemo\SampleList',22);
  list.SetPos(12,122,pivotTopLeft);
  list.style.Assign('@demo-list;');
  list.AddLine('ListBox item: surface');
  list.AddLine('ListBox item: accent');
  list.AddLine('ListBox item: warning');
  list.SelectLine(1);

  panel3:=Panel(UI,410,286,330,226,'Metrics','Non-color style parameters');
  MakeLabel(panel3,12,40,290,'Try radius, border-width, font-size and slider metrics.',true);
  MakeLabel(panel3,12,78,80,'Scrollbar');
  scroll:=TUIScrollBar.CreateH(230,20,panel3,'StyleDemo\SampleScroll');
  scroll.SetPos(86,78,pivotTopLeft);
  scroll.SetRange(0,100,20);
  scroll.value:=45;
  scroll.style.Assign('@demo-slider;');

  MakeLabel(panel3,12,118,295,'The editor window is a separate scene layered above this one.',true);
  MakeLabel(panel3,12,142,290,'Later it can become an engine module for runtime UI tuning.',true);

  panel4:=Panel(UI,410,18,330,250,'Theme coverage','Styled containers');
  MakeLabel(panel4,12,40,286,'Panels, labels, inputs, lists, toggles and sliders all bind to tokens.',true);
  MakeLabel(panel4,12,82,286,'Edit named styles in the right window to affect whole widget groups.',false);
  MakeLabel(panel4,12,112,286,'Palette edits change every style that uses &token references.',false);

  btn:=TUIButton.Create(120,30,panel4,'StyleDemo\Exit').Setup('Exit');
  btn.SetPos(12,188,pivotTopLeft);
  StyleButton(btn);
  Link('UI\StyleDemo\Exit\OnClick','Engine\Cmd\Exit');
 end;

procedure TStyleDemoScene.Render;
 begin
  gfx.target.Clear($FF101014);
  inherited;
 end;

end.
