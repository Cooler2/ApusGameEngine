// Runtime UI style/theme editor scene for StyleDemo

// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit StyleThemeEditorScene;
interface
 uses Apus.Core, Apus.Engine.Scene, Apus.Engine.UIScene, Apus.Engine.UITypes,
   Apus.Engine.UIWidgets;

 type
  // Windowed overlay scene. Kept demo-local for now, but the public shape is
  // intentionally small so it can later move to an engine runtime tuning module.
  TStyleThemeEditorScene=class(TUIScene)
   constructor Create(sceneName:string='StyleThemeEditor');
   procedure CreateUI;
   procedure SetStatus(st:TSceneStatus); override;
   procedure onMouseBtn(btn:byte;pressed:boolean); override;
   function Process:boolean; override;
   procedure Render; override;
   procedure BindElement(element:TUIElement);
  private
   wnd:TUIWindow;
   tokenList,styleList,attrList,themeList:TUIListBox;
   valueEdit,elementStyleEdit:TUIEditBox;
   swatch:TUIElement;
   rSlider,gSlider,bSlider:TUIScrollBar;
   tokenValue,styleValue,attrValue,elementValue:TUILabel;
   selectedElement:TUIElement;
   selectedToken,selectedStyle,selectedAttr:integer;
   lastColor:cardinal;
   lastValue,lastElementStyle:String8;
   editorTheme:String8;
   procedure LoadToken(index:integer);
   procedure LoadStyle(index:integer);
   procedure LoadAttr(index:integer);
   procedure ApplyAttrValue;
   procedure ApplyElementStyle;
  end;

 const
  STYLEDEMO_PALETTE:array[0..18] of String8=(
   'surface','surface-alt','overlay',
   'text','text-muted','text-on-accent',
   'border','border-light','border-dark',
   'control',
   'accent','accent-text',
   'danger','danger-text',
   'success','success-text',
   'warning','warning-text',
   'focus');

  STYLEDEMO_STYLE_NAMES:array[0..6] of String8=(
   'demo-panel','demo-button','demo-input','demo-list','demo-slider',
   'demo-check','demo-showcase');

  STYLEDEMO_STYLE_KEYS:array[0..12] of String8=(
   'color','text-color','fill','border-color','border-width','radius',
   'font-size','inner-fill','inner-border','inner-radius',
   'track-width','slider-width','min-size');

implementation
 uses SysUtils, Apus.Strings, Apus.Conv, Apus.Engine.Types, Apus.Engine.Style;

procedure LabelAt(parent:TUIElement;x,y,w:single;const text:String8);
 var
  lbl:TUILabel;
 begin
  lbl:=TUILabel.Create(w,18,parent);
  lbl.Setup(text);
  lbl.SetPos(x,y,pivotTopLeft);
  lbl.style.Assign('@demo-label;');
 end;

function MakeSlider(parent:TUIElement;y:single;const name:String8):TUIScrollBar;
 begin
  result:=TUIScrollBar.CreateH(180,18,parent,name);
  result.SetPos(214,y,pivotTopLeft);
  result.isInteger:=true;
  result.SetRange(0,255+18,18);
  result.style.Assign('@demo-slider;');
 end;

constructor TStyleThemeEditorScene.Create(sceneName:string);
 begin
  inherited Create(sceneName,false);
  shadowColor:=0;
  selectedToken:=-1;
  selectedStyle:=-1;
  selectedAttr:=-1;
  editorTheme:=ActiveTheme;
  zorder:=$FE0000;
  frequency:=12;
 end;

procedure TStyleThemeEditorScene.CreateUI;
 var
  i:integer;
 begin
  wnd:=TUIWindow.Create(500,590,true,UI,'StyleDemo\EditorWindow','Runtime UI style editor');
  wnd.SetPos(760,18,pivotTopLeft);
  wnd.minW:=500;
  wnd.minH:=540;
  wnd.style.Assign('@demo-panel; color:&surface-alt;');
  wnd.moveable:=true;

  LabelAt(wnd,14,16,160,'Palette tokens');
  tokenList:=TUIListBox.Create(150,258,wnd,'StyleDemo\TokenList',22);
  tokenList.SetPos(14,38,pivotTopLeft);
  tokenList.style.Assign('@demo-list;');
  for i:=0 to high(STYLEDEMO_PALETTE) do
   tokenList.AddLine(STYLEDEMO_PALETTE[i],i);
  tokenList.SelectLine(10);

  swatch:=TUIElement.Create(70,42,wnd,'StyleDemo\TokenSwatch');
  swatch.SetPos(184,38,pivotTopLeft);

  LabelAt(wnd,184,94,16,'R');
  rSlider:=MakeSlider(wnd,94,'StyleDemo\SliderR');
  tokenValue:=TUILabel.Create(50,18,wnd);
  tokenValue.Right('').SetPos(424,94,pivotTopLeft);
  tokenValue.style.Assign('@demo-label;');

  LabelAt(wnd,184,126,16,'G');
  gSlider:=MakeSlider(wnd,126,'StyleDemo\SliderG');
  LabelAt(wnd,184,158,16,'B');
  bSlider:=MakeSlider(wnd,158,'StyleDemo\SliderB');

  LabelAt(wnd,184,206,70,'Theme');
  themeList:=TUIListBox.Create(110,52,wnd,'StyleDemo\ThemeList',22);
  themeList.SetPos(244,206,pivotTopLeft);
  themeList.style.Assign('@demo-list;');
  themeList.AddLine('light');
  themeList.AddLine('dark');
  if editorTheme='dark' then themeList.SelectLine(1)
   else themeList.SelectLine(0);

  LabelAt(wnd,184,250,290,'Drag RGB sliders to retune selected token live.');
  LabelAt(wnd,184,272,290,'Theme list swaps the whole palette.');

  LabelAt(wnd,14,314,130,'Style blocks');
  styleList:=TUIListBox.Create(145,118,wnd,'StyleDemo\StyleList',22);
  styleList.SetPos(14,336,pivotTopLeft);
  styleList.style.Assign('@demo-list;');
  for i:=0 to high(STYLEDEMO_STYLE_NAMES) do
   styleList.AddLine(STYLEDEMO_STYLE_NAMES[i],i);
  styleList.SelectLine(1);

  LabelAt(wnd,172,314,130,'Parameters');
  attrList:=TUIListBox.Create(145,118,wnd,'StyleDemo\AttrList',22);
  attrList.SetPos(172,336,pivotTopLeft);
  attrList.style.Assign('@demo-list;');
  for i:=0 to high(STYLEDEMO_STYLE_KEYS) do
   attrList.AddLine(STYLEDEMO_STYLE_KEYS[i],i);
  attrList.SelectLine(0);

  LabelAt(wnd,330,314,120,'Value');
  valueEdit:=TUIEditBox.Create(150,24,wnd,'StyleDemo\ValueEdit');
  valueEdit.SetPos(330,336,pivotTopLeft);
  valueEdit.style.Assign('@demo-input;');

  styleValue:=TUILabel.Create(150,18,wnd);
  styleValue.Setup('').SetPos(330,372,pivotTopLeft);
  styleValue.style.Assign('@demo-label;');

  attrValue:=TUILabel.Create(150,18,wnd);
  attrValue.Setup('').SetPos(330,394,pivotTopLeft);
  attrValue.style.Assign('@demo-label;');

  LabelAt(wnd,330,426,150,'&token, color, number, percent.');

  LabelAt(wnd,14,462,450,'RMB/MMB any visible element: inspect and edit its local style');
  elementValue:=TUILabel.Create(466,18,wnd);
  elementValue.Setup('selected: (none)').SetPos(14,484,pivotTopLeft);
  elementValue.style.Assign('@demo-label;');

  elementStyleEdit:=TUIEditBox.Create(466,26,wnd,'StyleDemo\ElementStyleEdit');
  elementStyleEdit.SetPos(14,510,pivotTopLeft);
  elementStyleEdit.style.Assign('@demo-input;');
  elementStyleEdit.maxLength:=1200;

  LabelAt(wnd,14,542,466,'This field replaces element.style.Text live; use @refs or key:value pairs.');

  LoadToken(tokenList.selectedLine);
  LoadStyle(styleList.selectedLine);
  LoadAttr(attrList.selectedLine);
 end;

procedure TStyleThemeEditorScene.LoadToken(index:integer);
 var
  col:cardinal;
 begin
  if (index<0) or (index>high(STYLEDEMO_PALETTE)) then exit;
  selectedToken:=index;
  col:=ParseStyleColor(GetToken(STYLEDEMO_PALETTE[index]));
  rSlider.value:=(col shr 16) and $FF;
  gSlider.value:=(col shr 8) and $FF;
  bSlider.value:=col and $FF;
  lastColor:=col;
  swatch.style.Assign('fill:&'+STYLEDEMO_PALETTE[index]+'; border-width:1; border-color:&border;');
 end;

procedure TStyleThemeEditorScene.SetStatus(st:TSceneStatus);
 begin
  inherited;
  if (st=TSceneStatus.ssActive) and (wnd<>nil) then
   wnd.SetFocus;
 end;

procedure TStyleThemeEditorScene.BindElement(element:TUIElement);
 begin
  if element=nil then exit;
  selectedElement:=element;
  lastElementStyle:=element.style.GetText;
  elementStyleEdit.text:=lastElementStyle;
  elementValue.caption:='selected: '+element.ClassName+' '+element.name;
 end;

procedure TStyleThemeEditorScene.onMouseBtn(btn:byte;pressed:boolean);
 var
  c:TUIElement;
 begin
  inherited;
  if not pressed then exit;
  if (btn<>2) and (btn<>3) then exit;
  if (UI<>nil) and UI.FindAnyElementAt(curMouseX,curMouseY,c) then
   if c<>elementStyleEdit then BindElement(c);
 end;

procedure TStyleThemeEditorScene.LoadStyle(index:integer);
 begin
  if (index<0) or (index>high(STYLEDEMO_STYLE_NAMES)) then exit;
  selectedStyle:=index;
  styleValue.caption:='style: '+STYLEDEMO_STYLE_NAMES[index];
  selectedAttr:=-1;
  LoadAttr(attrList.selectedLine);
 end;

procedure TStyleThemeEditorScene.LoadAttr(index:integer);
 var
  block:TStyleBlock;
 begin
  if (selectedStyle<0) or (selectedStyle>high(STYLEDEMO_STYLE_NAMES)) then exit;
  if (index<0) or (index>high(STYLEDEMO_STYLE_KEYS)) then exit;
  selectedAttr:=index;
  block:=Styles.Block(STYLEDEMO_STYLE_NAMES[selectedStyle]);
  if block=nil then begin
   Styles[STYLEDEMO_STYLE_NAMES[selectedStyle]]:='';
   block:=Styles.Block(STYLEDEMO_STYLE_NAMES[selectedStyle]);
  end;
  lastValue:=block.GetValue(STYLEDEMO_STYLE_KEYS[index],'');
  valueEdit.text:=lastValue;
  attrValue.caption:=STYLEDEMO_STYLE_KEYS[index]+': '+lastValue;
 end;

procedure TStyleThemeEditorScene.ApplyAttrValue;
 var
  block:TStyleBlock;
 begin
  if (selectedStyle<0) or (selectedAttr<0) then exit;
  if valueEdit.text=lastValue then exit;
  block:=Styles.Block(STYLEDEMO_STYLE_NAMES[selectedStyle]);
  if block=nil then exit;
  lastValue:=valueEdit.text;
  if lastValue='' then
   block.RemoveAttr(STYLEDEMO_STYLE_KEYS[selectedAttr])
  else
   block.SetAttr(STYLEDEMO_STYLE_KEYS[selectedAttr],lastValue);
  attrValue.caption:=STYLEDEMO_STYLE_KEYS[selectedAttr]+': '+lastValue;
 end;

procedure TStyleThemeEditorScene.ApplyElementStyle;
 begin
  if (selectedElement=nil) or (elementStyleEdit=nil) then exit;
  if elementStyleEdit.text=lastElementStyle then exit;
  lastElementStyle:=elementStyleEdit.text;
  selectedElement.style.Assign(lastElementStyle);
 end;

function TStyleThemeEditorScene.Process:boolean;
 var
  want:String8;
  r,g,b:integer;
  col:cardinal;
 begin
  result:=inherited Process;
  if tokenList=nil then exit;

  if themeList.selectedLine=1 then want:='dark' else want:='light';
  if want<>editorTheme then begin
   ApplyTheme(want);
   editorTheme:=want;
   LoadToken(tokenList.selectedLine);
  end;

  if tokenList.selectedLine<>selectedToken then
   LoadToken(tokenList.selectedLine)
  else begin
   r:=round(rSlider.value);
   g:=round(gSlider.value);
   b:=round(bSlider.value);
   col:=cardinal($FF000000) or cardinal(r shl 16) or cardinal(g shl 8) or cardinal(b);
   if col<>lastColor then begin
    SetTokenColor(STYLEDEMO_PALETTE[selectedToken],col);
    lastColor:=col;
   end;
   tokenValue.caption:='#'+Conv.ToHex((r shl 16) or (g shl 8) or b,6);
  end;

  if styleList.selectedLine<>selectedStyle then
   LoadStyle(styleList.selectedLine);
  if attrList.selectedLine<>selectedAttr then
   LoadAttr(attrList.selectedLine);
  ApplyAttrValue;
  ApplyElementStyle;
  ignoreKeyboardEvents:=not ((FocusedElement<>nil) and FocusedElement.HasParent(UI));
 end;

procedure TStyleThemeEditorScene.Render;
 begin
  inherited;
 end;

end.
