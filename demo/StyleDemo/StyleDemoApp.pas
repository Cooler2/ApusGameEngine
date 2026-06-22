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
   Apus.Engine.Types, Apus.Engine.SceneEffects, Apus.Engine.UI, Apus.Engine.UIWidgets,
   Apus.Engine.Style;

 type
  TStyleDemoScene=class(TUIScene)
   procedure CreateUI;
   procedure CreateEditor(parent:TUIElement);
   function Process:boolean; override;
   procedure Render; override;
  end;

 const
  // Full palette, in the same order as the built-in themes (Apus.Engine.Style).
  // The editor lets you tune any of these live; demo widgets bind to a subset.
  PALETTE:array[0..18] of String8=(
   'surface','surface-alt','overlay',
   'text','text-muted','text-on-accent',
   'border','border-light','border-dark',
   'control',
   'accent','accent-text',
   'danger','danger-text',
   'success','success-text',
   'warning','warning-text',
   'focus');

 var
  mainScene:TStyleDemoScene;
  styleRefToggle:boolean; // for the @ref update button demo
  // --- editor widgets + state ---
  edCombo:TUIComboBox;          // token selector
  edSwatch:TUIElement;          // shows the selected token color (fill:&<token>)
  edR,edG,edB:TUIScrollBar;     // R/G/B channel sliders (0..255)
  edDark:TUICheckBox;           // dark/light theme toggle
  edSel:integer;                // currently loaded token index (-1 = force reload)
  edLastColor:cardinal;         // last color loaded/written (avoids redundant SetToken)
  edTheme:String8;              // theme name currently driven by the checkbox

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
  st:=ExtractFileDir(ParamStr(0));
  SetCurrentDir(st);
  if DirectoryExists('../demo/StyleDemo') then
    SetCurrentDir('../demo/StyleDemo');

  gameTitle:='R-05 Style System Demo';
  usedAPI:=gaOpenGL2;
 end;

procedure TStyleDemoApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
 end;

procedure TStyleDemoApp.CreateScenes;
 begin
  inherited;
  mainScene:=TStyleDemoScene.Create('StyleDemo');
  mainScene.CreateUI;
  Sleep(500);
  TTransitionEffect.Create(mainScene, 250);
 end;

{ TStyleDemoScene }

// Toggle @demo-btn named style between two semantic tokens → Btn3 updates too
procedure StyleDemoUpdateRef;
 begin
  styleRefToggle:=not styleRefToggle;
  if styleRefToggle then
   Styles['demo-btn']:='color:&danger; text-color:&danger-text;'
  else
   Styles['demo-btn']:='color:&accent; text-color:&accent-text;';
 end;

// Left panel: the "test subjects". Their styles bind to palette tokens, so editing
// a token in the right-hand editor recolors them live.
//   Btn1: no style — default drawer (baseline, ignores tokens)
//   Btn2: color:&control
//   Btn3: @demo-btn → color:&accent  (toggled to &danger by Btn6)
//   Btn4: states — base &control, :hover &accent, :pressed &danger
//   Btn5: disabled — :disabled text-color:&text-muted
//   Btn6: toggles @demo-btn between &accent and &danger
procedure TStyleDemoScene.CreateUI;
 var
  panel,editor:TUIElement;
  btn:TUIButton;
  lbl:TUILabel;
 begin
  // Named style reused by Btn3 and the @ref toggle demo
  Styles['demo-btn']:='color:&accent; text-color:&accent-text;';

  // --- Left panel: test subjects (280×330 at 10,10) ---
  panel:=TUIElement.Create(280, 330, UI, 'StyleDemo\Panel');
  panel.SetPos(10, 10, pivotTopLeft);
  panel.styleinfo:='fill:&surface; border-width:1; border-color:&border;';
  lbl:=TUILabel.Create(260, 20, panel, 'StyleDemo\Title');
  lbl.Centered('Test subjects (bound to tokens)').SetPos(140, 18, pivotCenter);
  lbl.style.SetAttr('color','&text');

  // Btn1: no custom style — default drawer (baseline)
  TUIButton.Create(250, 30, panel, 'StyleDemo\Btn1').Setup('Default style').
    SetPos(140, 55, pivotCenter);

  // Btn2: face color from &control token
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn2').Setup('color:&control');
  btn.SetPos(140, 93, pivotCenter);
  btn.style.Assign('color:&control; text-color:&text;');

  // Btn3: @ref to a token-based named style
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn3').Setup('@demo-btn (accent)');
  btn.SetPos(140, 131, pivotCenter);
  btn.style.Assign('@demo-btn;');

  // Btn4: state blocks reference tokens too
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn4').Setup('States: hover/pressed');
  btn.SetPos(140, 169, pivotCenter);
  btn.style.Assign(
    'color:&control; text-color:&text;'+
    ':hover { color:&accent; text-color:&accent-text; }'+
    ':pressed { color:&danger; text-color:&danger-text; }');

  // Btn5: disabled — :disabled overrides text-color with &text-muted
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn5').Setup('Disabled button');
  btn.SetPos(140, 207, pivotCenter);
  btn.style.Assign(
    'color:&control; text-color:&text;'+
    ':disabled { text-color:&text-muted; }');
  btn.flags.enabled:=false;

  // Btn6: click toggles @demo-btn → Btn3 updates (cascade demo)
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn6').Setup('Toggle @demo-btn (accent/danger)');
  btn.SetPos(140, 245, pivotCenter);
  btn.onClickAsync:=@StyleDemoUpdateRef;

  // --- Right panel: live token editor ---
  editor:=TUIElement.Create(380, 330, UI, 'StyleDemo\Editor');
  editor.SetPos(320, 10, pivotTopLeft);
  editor.styleinfo:='fill:&surface; border-width:1; border-color:&border;';
  CreateEditor(editor);

  // Exit button outside the panels
  btn:=TUIButton.Create(120, 30, UI, 'StyleDemo\Exit').Setup('Exit');
  btn.SetPos(10, 355, pivotTopLeft);
  Link('UI\StyleDemo\Exit\OnClick', 'Engine\Cmd\Exit');
 end;

procedure TStyleDemoScene.CreateEditor(parent:TUIElement);
 var
  i:integer;

  function MakeSlider(y:single; nm:String8):TUIScrollBar;
   begin
    result:=TUIScrollBar.CreateH(240, 18, parent, 'StyleDemo\'+nm);
    result.SetPos(40, y, pivotTopLeft);
    result.isInteger:=true;
    result.SetRange(0, 255+18, 18); // value range becomes 0..255 (max-pageSize)
   end;

 begin
  // Token selector (all palette entries)
  edCombo:=TUIComboBox.Create(215, 26, parent, 'StyleDemo\TokenCombo');
  edCombo.SetPos(70, 42, pivotTopLeft);
  for i:=0 to high(PALETTE) do
   edCombo.AddItem(PALETTE[i], i);
  edCombo.curItem:=10; // 'accent' — a token used by several test buttons

  // Swatch: bound to the selected token via fill, so it tracks live edits + theme swaps
  edSwatch:=TUIElement.Create(72, 54, parent, 'StyleDemo\Swatch');
  edSwatch.SetPos(295, 40, pivotTopLeft);

  // R/G/B channel sliders
  edR:=MakeSlider(108, 'SliderR');
  edG:=MakeSlider(146, 'SliderG');
  edB:=MakeSlider(184, 'SliderB');

  // Theme toggle
  edDark:=TUICheckBox.Create(200, 24, parent, 'StyleDemo\DarkChk');
  edDark.Setup('Dark theme', false);
  edDark.SetPos(40, 226, pivotTopLeft);

  edSel:=-1;       // force first-frame load
  edTheme:='light';
 end;

function TStyleDemoScene.Process:boolean;
 var
  ti,r,g,b:integer;
  col:cardinal;
  want:String8;
 begin
  result:=inherited Process;
  if edCombo=nil then exit; // UI not built yet

  // 1. Theme swap (checkbox is the source of truth, polled each frame)
  if edDark.checked then want:='dark' else want:='light';
  if want<>edTheme then begin
   ApplyTheme(want);
   edTheme:=want;
   edSel:=-1; // token values changed → reload sliders for the current token
  end;

  ti:=edCombo.curItem;
  if (ti<0) or (ti>high(PALETTE)) then exit;

  if ti<>edSel then begin
   // selection changed → load the token's color into the sliders (no write-back)
   edSel:=ti;
   col:=ParseStyleColor(GetToken(PALETTE[ti]));
   edR.value:=(col shr 16) and $FF;
   edG.value:=(col shr 8) and $FF;
   edB.value:=col and $FF;
   edLastColor:=col;
   edSwatch.styleinfo:='fill:&'+PALETTE[ti]+'; border-width:1; border-color:&border;';
  end else begin
   // same token → apply slider edits to the token (only when actually changed)
   r:=round(edR.value); g:=round(edG.value); b:=round(edB.value);
   col:=cardinal($FF000000) or cardinal(r shl 16) or cardinal(g shl 8) or cardinal(b);
   if col<>edLastColor then begin
    SetTokenColor(PALETTE[ti], col);
    edLastColor:=col;
   end;
  end;
 end;

procedure TStyleDemoScene.Render;
 var
  font:cardinal;
  px,py,r,g,b:integer;
 begin
  gfx.target.Clear($FF101014);
  font:=txt.GetFont('Default', 7);
  px:=320; py:=10; // editor panel origin

  txt.Write(font, px+14, py+14, $FFFFFFFF, 'Live token editor');
  txt.Write(font, px+14, py+48, $FFE0E0E0, 'Token:');

  r:=round(edR.value); g:=round(edG.value); b:=round(edB.value);
  txt.Write(font, px+18, py+108, $FFFF8080, 'R');
  txt.Write(font, px+18, py+146, $FF80FF80, 'G');
  txt.Write(font, px+18, py+184, $FF8080FF, 'B');
  txt.Write(font, px+286, py+108, $FFFFFFFF, IntToStr(r));
  txt.Write(font, px+286, py+146, $FFFFFFFF, IntToStr(g));
  txt.Write(font, px+286, py+184, $FFFFFFFF, IntToStr(b));
  if (edSel>=0) and (edSel<=high(PALETTE)) then
   txt.Write(font, px+14, py+264, $FFD0D0D0,
    Format('%s = #%.6x', [PALETTE[edSel], (r shl 16) or (g shl 8) or b]));

  txt.Write(font, 10, 400, $FFB0B0B0, 'Pick a token, drag R/G/B to retune the palette live.');
  txt.Write(font, 10, 418, $FFB0B0B0, 'Toggle "Dark theme" to swap the whole palette at once.');
  inherited;
 end;

end.
