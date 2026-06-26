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
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TStyleDemoApp;

implementation
 uses SysUtils, Apus.Core, Apus.Strings, Apus.EventMan, Apus.Colors,
   Apus.Engine.Types, Apus.Engine.Scene, Apus.Engine.SceneEffects,
   Apus.Engine.UI, Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.Style,
   StyleThemeEditorScene;

 type
  TStyleDemoScene=class(TUIScene)
   procedure CreateUI;
   procedure onMouseBtn(btn:byte;pressed:boolean); override;
   procedure Render; override;
  end;

 var
  mainScene:TStyleDemoScene;
  editorScene:TStyleThemeEditorScene;
  styleRefToggle:boolean; // for the @ref update button demo

{ TStyleDemoApp }

function HasParamEarly(const paramName:string):boolean;
 var
  i:integer;
 begin
  result:=false;
  for i:=1 to ParamCount do
   if UpperCase(ParamStr(i))=paramName then exit(true);
 end;

constructor TStyleDemoApp.Create;
 var
  st:string;
  hiDPI:boolean;
 begin
  {$IFDEF SDL}
  usedPlatform:=spSDL;
  {$ELSE}
  usedPlatform:=spDefault;
  {$ENDIF}
  inherited;
  st:=ExtractFileDir(ParamStr(0));
  SetCurrentDir(st);
  if DirectoryExists('../demo/StyleDemo') then
    SetCurrentDir('../demo/StyleDemo');

  gameTitle:='R-05 Style System Demo';
  usedAPI:=gaOpenGL2;
  hiDPI:=HasParamEarly('-HIDPI') or HasParamEarly('-REALDPI');
  if HasParamEarly('-LOWDPI') then hiDPI:=false;
  useRealDPI:=hiDPI;
  windowWidth:=1520;
  windowHeight:=860;
  windowSizeable:=false;
  scaleWindowSize:=hiDPI;
 end;

procedure TStyleDemoApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmFixedWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
 end;

procedure RegisterDemoStyles;
 begin
  Styles['demo-label']:='fill:0; border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border:0; text-color:&text; color:&text; font-size:9;';
  Styles['demo-muted-label']:='fill:0; border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border:0; text-color:&text; color:&text; font-size:8;';
  Styles['demo-panel']:='fill:&surface; border-color:&border; border-width:1;';
  Styles['demo-showcase']:='fill:&surface-alt; border-color:&border-light; border-width:1;';
  Styles['demo-button']:='fill:0; border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border:0; color:&control; text-color:&text;'+
    ':hover { color:&accent; text-color:&accent-text; }'+
    ':pressed { color:&danger; text-color:&danger-text; }';
  Styles['demo-input']:='fill:&overlay; text-color:&text; border-color:&border; border-width:1;'+
    ':focused { border-color:&focus; }';
  Styles['demo-list']:='fill:&overlay; text-color:&text; sel-bg:&accent; sel-text-color:&accent-text;'+
    'border-color:&border; border-width:1;';
  Styles['demo-slider']:='col:&control; track-col:&border-dark; active-col:&accent;'+
    'fill:0; border-color:0; border-width:0; inner-fill:0; inner-border:0;'+
    'track-width:0.25; slider-width:0.72; min-size:0.35; radius:0;';
  Styles['demo-check']:='fill:0; border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border:0; color:&control; col:&control; tick-col:&accent; text-color:&text;';
  Styles['demo-btn']:='@demo-button; color:&accent; text-color:&accent-text;';
  Styles['demo-button-01']:='@demo-button; color:&control; text-color:&text;'+
    ':hover { color:&surface-alt; text-color:&text; }'+
    ':pressed { color:&border-dark; text-color:&text; }';
  Styles['demo-button-02']:='@demo-button; color:&surface-alt; text-color:&text;'+
    'border-light:&border-light; border-dark:&border-dark;'+
    ':hover { color:&overlay; text-color:&text; }'+
    ':pressed { color:&control; text-color:&text; }';
  Styles['demo-button-03']:='@demo-button; color:&overlay; text-color:&text;'+
    'border-light:$D0FFFFFF; border-dark:&border-dark;'+
    ':hover { color:&surface-alt; text-color:&text; }'+
    ':pressed { color:&control; text-color:&text; }';
  Styles['demo-button-04']:='@demo-button; color:&surface-alt; text-color:&text;'+
    'border-light:&border-dark; border-dark:$90FFFFFF;'+
    ':hover { color:&overlay; text-color:&text; }'+
    ':pressed { color:&border-dark; text-color:&text; }';
  Styles['demo-button-05']:='@demo-button; color:$FF4E6078; text-color:&text;'+
    'border-light:$E0FFFFFF; border-dark:$90000000;'+
    ':hover { color:$FF5E7490; text-color:&text; }'+
    ':pressed { color:$FF334052; text-color:&text; }';
  Styles['demo-button-06']:='@demo-button; color:&accent; text-color:&accent-text;'+
    ':hover { color:&focus; text-color:&accent-text; }'+
    ':pressed { color:&border-dark; text-color:&text; }';
  Styles['demo-button-07']:='@demo-button; color:$00303030; text-color:&accent;'+
    'border-light:&accent; border-dark:&accent;'+
    ':hover { color:&overlay; text-color:&text; }'+
    ':pressed { color:&accent; text-color:&accent-text; }';
  Styles['demo-button-08']:='@demo-button; color:&surface; text-color:&text-muted;'+
    'border-light:&border; border-dark:&border-dark;'+
    ':hover { color:&control; text-color:&text; }'+
    ':pressed { color:&overlay; text-color:&text; }';
  Styles['demo-button-09']:='@demo-button; color:&control; text-color:&text;'+
    ':hover { color:&surface-alt; text-color:&text; }'+
    ':pressed { color:&accent; text-color:&accent-text; }';
  Styles['demo-button-10']:='@demo-button; color:&accent; text-color:&accent-text;'+
    'border-light:$C0FFFFFF; border-dark:$80000000;'+
    ':hover { color:&focus; text-color:&accent-text; }'+
    ':pressed { color:&border-dark; text-color:&text; }';
  Styles['demo-button-11']:='@demo-button; color:&control; text-color:&text;'+
    ':hover { color:&surface-alt; text-color:&text; }'+
    ':pressed { color:&accent; text-color:&accent-text; }';
  Styles['demo-button-12']:='@demo-button; color:&surface; text-color:&text;'+
    'border-light:&border; border-dark:&accent;'+
    ':hover { color:&overlay; text-color:&text; }'+
    ':pressed { color:&surface-alt; text-color:&accent; }';
  Styles['demo-button-13']:='@demo-button; color:&surface-alt; text-color:&text;'+
    'border-light:&accent; border-dark:&border-dark;'+
    ':hover { color:&overlay; text-color:&text; }'+
    ':pressed { color:&control; text-color:&accent; }';
  Styles['demo-button-14']:='@demo-button; color:&surface-alt; text-color:&text;'+
    'border-light:&focus; border-dark:&accent;'+
    ':hover { color:&overlay; text-color:&text; }'+
    ':pressed { color:&accent; text-color:&accent-text; }';
  Styles['demo-button-15']:='@demo-button; color:&surface; text-color:&text;'+
    'border-light:$E0FFFFFF; border-dark:&accent;'+
    ':hover { color:&surface-alt; text-color:&text; }'+
    ':pressed { color:&overlay; text-color:&accent; }';
  Styles['demo-button-16']:='@demo-button; color:$FF30343C; text-color:$FFE4E8F0;'+
    'border-light:$80B8C4D8; border-dark:$D0000000;'+
    ':hover { color:$FF3C4450; text-color:$FFFFFFFF; }'+
    ':pressed { color:$FF20242C; text-color:$FFC8D0DC; }';
  Styles['demo-button-17']:='@demo-button; color:$FF20242A; text-color:$FFB8F0FF;'+
    'border-light:$FF70E8FF; border-dark:$FF1A6470;'+
    ':hover { color:$FF263844; text-color:$FFFFFFFF; }'+
    ':pressed { color:$FF10242C; text-color:$FF70E8FF; }';
  Styles['demo-button-18']:='@demo-button; color:$FFEAD8B8; text-color:$FF3A2614;'+
    'border-light:$FFFFFFFF; border-dark:$FF8A6030;'+
    ':hover { color:$FFFFE4BC; text-color:$FF2A180C; }'+
    ':pressed { color:$FFD0A878; text-color:$FF2A180C; }';
  Styles['demo-button-19']:='@demo-button; color:&danger; text-color:&danger-text;'+
    'border-light:$E0FFFFFF; border-dark:$90000000;'+
    ':hover { color:$FFFF705C; text-color:&danger-text; }'+
    ':pressed { color:$FF8A2020; text-color:&danger-text; }';
  Styles['demo-button-20']:='@demo-button; color:$00000000; text-color:&text;'+
    'border-light:$00000000; border-dark:$00000000;'+
    ':hover { color:$2030A8FF; text-color:&accent; }'+
    ':pressed { color:$4030A8FF; text-color:&accent; }';
 end;

procedure TStyleDemoApp.CreateScenes;
 begin
  inherited;
  RegisterDemoStyles;

  mainScene:=TStyleDemoScene.Create('StyleDemo');
  mainScene.CreateUI;

  Sleep(250);
  TTransitionEffect.Create(mainScene,250);

  editorScene:=TStyleThemeEditorScene.Create;
  editorScene.CreateUI;
  editorScene.SetStatus(TSceneStatus.ssActive);
 end;

{ TStyleDemoScene }

procedure StyleDemoUpdateRef;
 begin
  styleRefToggle:=not styleRefToggle;
  if styleRefToggle then
   Styles['demo-btn']:='@demo-button; color:&danger; text-color:&danger-text;'
  else
   Styles['demo-btn']:='@demo-button; color:&accent; text-color:&accent-text;';
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

const
 BUTTON_SKETCH_TITLES:array[0..19] of String8=(
  'Classic bevel','Flat border','Soft raised','Inset press','Glass strip',
  'Accent solid','Ghost','Toolbar compact','Segmented','Pill candidate',
  'Selected fill','Underline idea','Left marker idea','Inner glow','Raised tab',
  'Metal panel','Tech frame','Warm light','Danger action','Text button');

function ButtonSketchStyle(index:integer):String8;
 begin
  result:='@demo-button-'+IntToStr(index+1)+';';
 end;

procedure AddButtonSketch(parent:TUIElement;index:integer;x,y:single);
 var
  lbl:TUILabel;
  btn:TUIToggleButton;
 begin
  lbl:=TUILabel.Create(112,16,parent,'StyleDemo\SketchLabel'+IntToStr(index+1));
  lbl.Setup(BUTTON_SKETCH_TITLES[index]);
  lbl.SetPos(x,y,pivotTopLeft);
  lbl.style.Assign('@demo-muted-label; font-size:8;');

  btn:=TUIToggleButton.Create(112,26,parent,'StyleDemo\SketchBtn'+IntToStr(index+1));
  btn.Setup('Button',index in [10..14]);
  btn.SetPos(x,y+17,pivotTopLeft);
  StyleButton(btn,ButtonSketchStyle(index));
 end;

procedure AddButtonSketches(parent:TUIElement);
 var
  i:integer;
  col,row:integer;
 begin
  MakeLabel(parent,12,40,690,'Twenty parameterized directions. Hover and press them live; selected ideas start toggled.',true);
  for i:=0 to high(BUTTON_SKETCH_TITLES) do begin
   col:=i mod 10;
   row:=i div 10;
   AddButtonSketch(parent,i,12+col*119,66+row*55);
  end;
 end;

procedure DrawSketchText(x1,y1,x2,y2:integer;const caption:String8;color:cardinal);
 var
  font:TFontHandle;
  y:integer;
 begin
  font:=txt.GetFont('Default',8);
  y:=round((y1+y2)*0.5+txt.Height(font)*0.42);
  txt.Write(font,(x1+x2)*0.5,y,color,caption,taCenter);
 end;

procedure DrawButtonSketch(index:integer;x,y:integer);
 var
  x2,y2:integer;
  c1,c2,textC:cardinal;
 begin
  x2:=x+112;
  y2:=y+26;
  textC:=$FFE8EDF4;
  case index of
   0:begin
     draw.FillGradRect(x+1,y+1,x2-1,y2-1,$FFE2E7F0,$FF8C96A8,true);
     draw.ShadedRect(x,y,x2,y2,1,$FFFFFFFF,$FF303848);
     draw.ShadedRect(x+2,y+2,x2-2,y2-2,1,$C0FFFFFF,$90000000);
     textC:=$FF1C2430;
    end;
   1:begin
     draw.FillRect(x,y,x2,y2,$FF445064);
     draw.Rect(x,y,x2,y2,$FFAEB8C8);
    end;
   2:begin
     draw.FillRRect(x+3,y+4,x2+2,y2+3,$50000000,5);
     draw.FillGradRect(x+1,y+1,x2-1,y2-1,$FF6F7F98,$FF435166,true);
     draw.RRect(x,y,x2,y2,$D0C8D4E8,5);
    end;
   3:begin
     draw.FillGradRect(x+1,y+1,x2-1,y2-1,$FF2D3542,$FF59687D,true);
     draw.ShadedRect(x,y,x2,y2,2,$C0000000,$90FFFFFF);
    end;
   4:begin
     draw.FillGradRect(x,y,x2,y2,$FF49637C,$FF263546,true);
     draw.FillRect(x+3,y+3,x2-3,y+10,$58FFFFFF);
     draw.Rect(x,y,x2,y2,$C0FFFFFF);
    end;
   5:begin
     draw.FillRRect(x,y,x2,y2,$FF2F8EFF,4);
     draw.FillRect(x+2,y+2,x2-2,y+7,$36FFFFFF);
     draw.RRect(x,y,x2,y2,$C0FFFFFF,4);
    end;
   6:begin
     draw.RRect(x,y,x2,y2,$FF4EA5FF,4);
     draw.FillRect(x+1,y+1,x2-1,y2-1,$102F8EFF);
     textC:=$FF83C4FF;
    end;
   7:begin
     draw.FillRect(x,y,x2,y2,$FF303846);
     draw.Line(x,y,x2,y,$FF77869A);
     draw.Line(x,y2,x2,y2,$FF151A22);
     draw.Line(x,y,x,y2,$FF566272);
     draw.Line(x2,y,x2,y2,$FF151A22);
    end;
   8:begin
     draw.FillRect(x,y,x2,y2,$FF334155);
     draw.FillRect(x,y,x+7,y2,$FF2F8EFF);
     draw.Rect(x,y,x2,y2,$FF708096);
    end;
   9:begin
     draw.FillRRect(x,y,x2,y2,$FF2F8EFF,13);
     draw.RRect(x,y,x2,y2,$C0FFFFFF,13);
    end;
   10:begin
     draw.FillRRect(x,y,x2,y2,$FF2F8EFF,4);
     draw.RRect(x,y,x2,y2,$FFFFFFFF,4);
     textC:=$FFFFFFFF;
    end;
   11:begin
     draw.FillRect(x,y,x2,y2,$FF303846);
     draw.FillRect(x+8,y2-4,x2-8,y2-2,$FF2F8EFF);
     draw.Rect(x,y,x2,y2,$FF66758A);
    end;
   12:begin
     draw.FillRect(x,y,x2,y2,$FF303846);
     draw.FillRect(x,y,x+5,y2,$FF2F8EFF);
     draw.Rect(x,y,x2,y2,$FF66758A);
    end;
   13:begin
     draw.FillRRect(x,y,x2,y2,$FF263546,5);
     draw.RRect(x+2,y+2,x2-2,y2-2,$FF67D9FF,3);
     draw.RRect(x,y,x2,y2,$8030A8FF,5);
    end;
   14:begin
     draw.FillRect(x,y+4,x2,y2,$FF2F3C4E);
     draw.FillGradRect(x+1,y,x2-1,y2-3,$FF566E88,$FF38485C,true);
     draw.Line(x,y2,x2,y2,$FF2F8EFF);
    end;
   15:begin
     draw.FillGradRect(x,y,x2,y2,$FF454A54,$FF171A20,true);
     draw.ShadedRect(x,y,x2,y2,2,$FF9AA8BA,$FF000000);
     draw.Line(x+3,y+3,x2-3,y+3,$70FFFFFF);
    end;
   16:begin
     draw.FillRect(x+5,y,x2-5,y2,$FF17242C);
     draw.FillRect(x,y+5,x2,y2-5,$FF17242C);
     draw.Rect(x+5,y,x2-5,y2,$FF70E8FF);
     draw.Rect(x,y+5,x2,y2-5,$FF236C78);
     textC:=$FFB8F0FF;
    end;
   17:begin
     draw.FillGradRect(x,y,x2,y2,$FFFFE4BC,$FFD1A778,true);
     draw.RRect(x,y,x2,y2,$FF8A6030,4);
     textC:=$FF3A2614;
    end;
   18:begin
     draw.FillGradRect(x,y,x2,y2,$FFFF705C,$FF8A2020,true);
     draw.RRect(x,y,x2,y2,$FFFFC0B8,4);
     textC:=$FFFFFFFF;
    end;
   else begin
     draw.FillRect(x,y,x2,y2,$00000000);
     draw.Line(x+15,y2-4,x2-15,y2-4,$FF2F8EFF);
     textC:=$FF83C4FF;
    end;
  end;
  if index in [10..14] then begin
   c1:=Color.Mix($002F8EFF,$802F8EFF,120);
   c2:=Color.Mix($402F8EFF,$C02F8EFF,100);
   draw.Rect(x-2,y-2,x2+2,y2+2,c2);
   draw.FillRect(x+3,y+3,x+8,y2-3,c1);
  end;
  DrawSketchText(x,y,x2,y2,'Button',textC);
 end;

procedure DrawButtonSketchOverlay;
 var
  i,col,row:integer;
 begin
  for i:=0 to high(BUTTON_SKETCH_TITLES) do begin
   col:=i mod 10;
   row:=i div 10;
   DrawButtonSketch(i,30+col*119,709+row*55);
  end;
 end;

procedure TStyleDemoScene.CreateUI;
 var
  panel1,panel2,panel3,panel4,panel5:TUIElement;
  group:TUIGroupBox;
  btn:TUIButton;
  chk:TUICheckBox;
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
  StyleButton(btn,'@demo-button; color:&danger; text-color:&danger-text;');

  panel2:=Panel(UI,18,286,370,226,'Inputs','Inputs and selection');
  MakeLabel(panel2,12,40,330,'These widgets use editable named style blocks.',true);

  edit:=TUIEditBox.Create(210,26,panel2,'StyleDemo\SampleEdit');
  edit.text:='Editable text';
  edit.SetPos(12,74,pivotTopLeft);
  edit.style.Assign('@demo-input;');

  chk:=TUICheckBox.Create(130,24,panel2,'StyleDemo\Check').Setup('Checkbox',true);
  chk.SetPos(228,74,pivotTopLeft);
  chk.style.Assign('@demo-check;');
  group:=TUIGroupBox.Create(140,52,panel2,'StyleDemo\RadioGroup');
  group.SetPos(228,104,pivotTopLeft);
  TUIRadioButton.Create(130,24,group,'StyleDemo\Radio1').Setup('Radio A',true).
    SetPos(0,0,pivotTopLeft).style.Assign('@demo-check;');
  TUIRadioButton.Create(130,24,group,'StyleDemo\Radio2').Setup('Radio B',false).
    SetPos(0,26,pivotTopLeft).style.Assign('@demo-check;');

  list:=TUIListBox.Create(210,82,panel2,'StyleDemo\SampleList',22);
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
  MakeLabel(panel3,12,178,290,'Launch with -HIDPI for crisp DPI-aware rendering.',true);

  panel4:=Panel(UI,410,18,330,250,'ThemeCoverage','Styled containers');
  MakeLabel(panel4,12,40,286,'Panels, labels, inputs, lists, toggles and sliders all bind to tokens.',true);
  MakeLabel(panel4,12,82,286,'Edit named styles in the right window to affect whole widget groups.',false);
  MakeLabel(panel4,12,112,286,'Palette edits change every style that uses &token references.',false);

  btn:=TUIButton.Create(120,30,panel4,'StyleDemo\Exit').Setup('Exit');
  btn.SetPos(12,188,pivotTopLeft);
  StyleButton(btn);
  Link('UI\StyleDemo\Exit\OnClick','Engine\Cmd\Exit');

  panel5:=Panel(UI,18,626,1220,210,'ButtonSketches','Button visual sketches');
  AddButtonSketches(panel5);
 end;

procedure TStyleDemoScene.onMouseBtn(btn:byte;pressed:boolean);
 var
  c:TUIElement;
 begin
  inherited;
  if not pressed then exit;
  if (btn<>2) and (btn<>3) then exit;
  if (editorScene<>nil) and (UI<>nil) and UI.FindAnyElementAt(curMouseX,curMouseY,c) then
   editorScene.BindElement(c);
 end;

procedure TStyleDemoScene.Render;
 begin
  gfx.target.Clear($FF101014);
  inherited;
  DrawButtonSketchOverlay;
 end;

end.
