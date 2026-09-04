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
 uses SysUtils, Apus.Core, Apus.Strings, Apus.EventMan, Apus.Colors, Apus.Images,
   Apus.Engine.Types, Apus.Engine.Scene, Apus.Engine.SceneEffects,
   Apus.Engine.UI, Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.Style,
   StyleThemeEditorScene;

 type
  TStyleDemoScene=class(TUIScene)
   procedure CreateUI;
   procedure InitGfx; override; // builds the procedural button skin textures
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
  windowWidth:=1520;
  windowHeight:=860;
  windowSizeable:=false;
  scaleWindowSize:=hiDPI;
 end;

procedure TStyleDemoApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode:=dmFixedWindow;
 end;

procedure RegisterDemoStyles;
 begin
  Styles['demo-label']:='fill:0; border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border-color:0; color:&text; font-size:9;';
  Styles['demo-muted-label']:='fill:0; border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border-color:0; color:&text; font-size:8;';
  Styles['demo-panel']:='fill:&surface; border-color:&border; border-width:1;';
  Styles['demo-showcase']:='fill:&surface-alt; border-color:&border-light; border-width:1;';
  Styles['demo-button']:='border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border-color:0; fill:&control; color:&text;'+
    ':hover { fill:&accent; color:&accent-text; }'+
    ':pressed { fill:&danger; color:&danger-text; }';
  Styles['demo-input']:='fill:&overlay; color:&text; border-color:&border; border-width:1;'+
    ':focused { border-color:&focus; }';
  Styles['demo-list']:='fill:&overlay; color:&text; :selected { fill:&accent; color:&accent-text; }'+
    'border-color:&border; border-width:1;';
  Styles['demo-slider']:='color:&control; track-color:&border-dark; active-color:&accent;'+
    'fill:0; border-color:0; border-width:0; inner-fill:0; inner-border-color:0;'+
    'track-width:0.25; slider-width:0.72; min-size:0.35; radius:0;';
  Styles['demo-check']:='fill:0; border-color:0; border-width:0; radius:0;'+
    'inner-fill:0; inner-border-color:0; border-color:&control; tick-color:&accent; color:&text;';
  Styles['demo-btn']:='@demo-button; fill:&accent; color:&accent-text;';
  Styles['demo-button-01']:='@demo-button; fill:&control; color:&text;'+
    ':hover { fill:&surface-alt; color:&text; }'+
    ':pressed { fill:&border-dark; color:&text; }';
  Styles['demo-button-02']:='@demo-button; fill:&surface-alt; color:&text;'+
    'border-light:&border-light; border-dark:&border-dark;'+
    ':hover { fill:&overlay; color:&text; }'+
    ':pressed { fill:&control; color:&text; }';
  Styles['demo-button-03']:='@demo-button; fill:&overlay; color:&text;'+
    'border-light:$D0FFFFFF; border-dark:&border-dark;'+
    ':hover { fill:&surface-alt; color:&text; }'+
    ':pressed { fill:&control; color:&text; }';
  Styles['demo-button-04']:='@demo-button; fill:&surface-alt; color:&text;'+
    'border-light:&border-dark; border-dark:$90FFFFFF;'+
    ':hover { fill:&overlay; color:&text; }'+
    ':pressed { fill:&border-dark; color:&text; }';
  Styles['demo-button-05']:='@demo-button; fill:$FF4E6078; color:&text;'+
    'border-light:$E0FFFFFF; border-dark:$90000000;'+
    ':hover { fill:$FF5E7490; color:&text; }'+
    ':pressed { fill:$FF334052; color:&text; }';
  Styles['demo-button-06']:='@demo-button; fill:&accent; color:&accent-text;'+
    ':hover { fill:&focus; color:&accent-text; }'+
    ':pressed { fill:&border-dark; color:&text; }';
  Styles['demo-button-07']:='@demo-button; fill:$00303030; color:&accent;'+
    'border-light:&accent; border-dark:&accent;'+
    ':hover { fill:&overlay; color:&text; }'+
    ':pressed { fill:&accent; color:&accent-text; }';
  Styles['demo-button-08']:='@demo-button; fill:&surface; color:&text-muted;'+
    'border-light:&border; border-dark:&border-dark;'+
    ':hover { fill:&control; color:&text; }'+
    ':pressed { fill:&overlay; color:&text; }';
  Styles['demo-button-09']:='@demo-button; fill:&control; color:&text;'+
    ':hover { fill:&surface-alt; color:&text; }'+
    ':pressed { fill:&accent; color:&accent-text; }';
  Styles['demo-button-10']:='@demo-button; fill:&accent; color:&accent-text;'+
    'border-light:$C0FFFFFF; border-dark:$80000000;'+
    ':hover { fill:&focus; color:&accent-text; }'+
    ':pressed { fill:&border-dark; color:&text; }';
  Styles['demo-button-11']:='@demo-button; fill:&control; color:&text;'+
    ':hover { fill:&surface-alt; color:&text; }'+
    ':pressed { fill:&accent; color:&accent-text; }';
  Styles['demo-button-12']:='@demo-button; fill:&surface; color:&text;'+
    'border-light:&border; border-dark:&accent;'+
    ':hover { fill:&overlay; color:&text; }'+
    ':pressed { fill:&surface-alt; color:&accent; }';
  Styles['demo-button-13']:='@demo-button; fill:&surface-alt; color:&text;'+
    'border-light:&accent; border-dark:&border-dark;'+
    ':hover { fill:&overlay; color:&text; }'+
    ':pressed { fill:&control; color:&accent; }';
  Styles['demo-button-14']:='@demo-button; fill:&surface-alt; color:&text;'+
    'border-light:&focus; border-dark:&accent;'+
    ':hover { fill:&overlay; color:&text; }'+
    ':pressed { fill:&accent; color:&accent-text; }';
  Styles['demo-button-15']:='@demo-button; fill:&surface; color:&text;'+
    'border-light:$E0FFFFFF; border-dark:&accent;'+
    ':hover { fill:&surface-alt; color:&text; }'+
    ':pressed { fill:&overlay; color:&accent; }';
  Styles['demo-button-16']:='@demo-button; fill:$FF30343C; color:$FFE4E8F0;'+
    'border-light:$80B8C4D8; border-dark:$D0000000;'+
    ':hover { fill:$FF3C4450; color:$FFFFFFFF; }'+
    ':pressed { fill:$FF20242C; color:$FFC8D0DC; }';
  Styles['demo-button-17']:='@demo-button; fill:$FF20242A; color:$FFB8F0FF;'+
    'border-light:$FF70E8FF; border-dark:$FF1A6470;'+
    ':hover { fill:$FF263844; color:$FFFFFFFF; }'+
    ':pressed { fill:$FF10242C; color:$FF70E8FF; }';
  Styles['demo-button-18']:='@demo-button; fill:$FFEAD8B8; color:$FF3A2614;'+
    'border-light:$FFFFFFFF; border-dark:$FF8A6030;'+
    ':hover { fill:$FFFFE4BC; color:$FF2A180C; }'+
    ':pressed { fill:$FFD0A878; color:$FF2A180C; }';
  Styles['demo-button-19']:='@demo-button; fill:&danger; color:&danger-text;'+
    'border-light:$E0FFFFFF; border-dark:$90000000;'+
    ':hover { fill:$FFFF705C; color:&danger-text; }'+
    ':pressed { fill:$FF8A2020; color:&danger-text; }';
  Styles['demo-button-20']:='@demo-button; fill:$00000000; color:&text;'+
    'border-light:$00000000; border-dark:$00000000;'+
    ':hover { fill:$2030A8FF; color:&accent; }'+
    ':pressed { fill:$4030A8FF; color:&accent; }';
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
   Styles['demo-btn']:='@demo-button; fill:&danger; color:&danger-text;'
  else
   Styles['demo-btn']:='@demo-button; fill:&accent; color:&accent-text;';
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

// A label with an explicit style on top of @demo-label (used for the content-key samples)
procedure StyledLabel(parent:TUIElement;x,y,w:single;const text,styleText:String8);
 var
  lbl:TUILabel;
 begin
  lbl:=TUILabel.Create(w,20,parent);
  lbl.Setup(text);
  lbl.SetPos(x,y,pivotTopLeft);
  lbl.style.Assign('@demo-label; '+styleText);
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

// Procedural button skin: rounded box with a vertical gradient and a dark edge,
// transparent corners. Two variants are registered by name ('demo-skin', 'demo-skin-hover')
// so the button style can refer to them as 'tex:<name>'.
function SkinPixel(tex:TTexture;x,y:integer;top,bottom:cardinal):cardinal;
 var
  r,dx,dy,d,t:single;
 begin
  r:=8;
  dx:=Max(abs(x+0.5-tex.width/2)-(tex.width/2-r),0.0);
  dy:=Max(abs(y+0.5-tex.height/2)-(tex.height/2-r),0.0);
  d:=sqrt(dx*dx+dy*dy)-r; // signed distance to the rounded edge (negative = inside)
  t:=y/(tex.height-1);
  result:=Color.Mix(top,bottom,t);
  if d>-1.5 then result:=Color.Mix(result,$FF202830,Clamp(d+1.5,0,1)); // dark edge
  result:=Color.Scale(result,Clamp(-d+0.5,0,1)); // antialiased outside
 end;

function SkinBase(tex:TTexture;x,y:integer):cardinal;
 begin
  result:=SkinPixel(tex,x,y,$FF7890B0,$FF3A4A60);
 end;

function SkinHover(tex:TTexture;x,y:integer):cardinal;
 begin
  result:=SkinPixel(tex,x,y,$FFA0B8D8,$FF506888);
 end;

procedure TStyleDemoScene.InitGfx;
 var
  tex:TTexture;
 begin
  inherited;
  tex:=AllocImage(150,32,ipfARGB,0,'demo-skin');
  tex.Fill(@SkinBase);
  tex:=AllocImage(150,32,ipfARGB,0,'demo-skin-hover');
  tex.Fill(@SkinHover);
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
  // local state blocks win over those of @demo-button, so the button keeps its danger
  // colors in every state; the pressed caption shift is data, not drawer code
  StyleButton(btn,'@demo-button; fill:&danger; color:&danger-text;'+
    ':hover { fill:&danger; color:&danger-text; }'+
    ':pressed { fill:&danger; color:&danger-text; text-offset-x:1; text-offset-y:2; }');

  // Skinned button: the box is a texture (auto size, centered), states cross-fade between
  // textures, pressed = darker tint + 1px shift. No custom drawer involved.
  btn:=TUIButton.Create(150,32,panel1,'StyleDemo\BtnSkinned').Setup('Skinned');
  btn.SetPos(12,206,pivotTopLeft);
  StyleButton(btn,'fill:0; border-color:0; border-width:0; radius:0; inner-fill:0; inner-border-color:0;'+
    'color:$FFF0F4FF; background-image:tex:demo-skin;'+
    ':hover { background-image:tex:demo-skin-hover; color:$FFFFFFFF; }'+
    ':pressed { background-tint:$FF505050; background-offset-y:1; }');

  btn:=TUIButton.Create(170,32,panel1,'StyleDemo\BtnSkinnedStretch').Setup('Skinned, stretched');
  btn.SetPos(190,206,pivotTopLeft);
  StyleButton(btn,'fill:0; border-color:0; border-width:0; radius:0; inner-fill:0; inner-border-color:0;'+
    'color:$FFF0F4FF; background-image:tex:demo-skin; background-size:stretch;'+
    ':hover { background-tint:$FFA0A0A0; color:$FFFFFFFF; }'+
    ':pressed { background-tint:$FF505050; }');

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
  MakeLabel(panel4,12,72,286,'Content keys: shadow, decoration and alignment come from the style.',true);
  StyledLabel(panel4,12,100,286,'Shadowed caption','text-shadow:$C0000000 1 1;');
  StyledLabel(panel4,12,126,286,'Underlined caption','text-decoration:underline;');
  StyledLabel(panel4,12,152,286,'Right-aligned by the style','text-align:right;');

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
