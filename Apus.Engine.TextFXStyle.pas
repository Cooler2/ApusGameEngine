// Optional TextFX UI style: extends standard buttons and draws caption children.
// Copyright (C) 2026 Apus Software
// Licensed under BSD-3; see license.txt.
unit Apus.Engine.TextFXStyle;
interface
 uses Apus.Engine.UITypes;

 // Assign to a button's drawer to reuse the default button rendering and add
 // its TextFX caption. Assign to a mouse-transparent child to draw its caption
 // (caption-source:parent selects the parent caption and text state).
 // Supported containers: ordinary and toggle buttons (excluding checkboxes).
 // Supported caption children: TUIElement, TUILabel and TUIImage.
 // Effect keys: text-glow-color, text-glow-blur, text-glow-spread.
 // Buttons move all their children via scroll while pressed; no per-child nudge.
 procedure DrawTextFXStyle(element:TUIElement);

 // Optional numeric style registration for UIScript; direct drawer assignment
 // does not require registration. The caller selects an unused style ID.
 procedure RegisterTextFXStyle(styleID:byte);

implementation
 uses SysUtils, Types, Apus.Core, Apus.Colors, Apus.Geom2D,
   Apus.Engine.Types, Apus.Engine.API, Apus.Engine.UIWidgets, Apus.Engine.Style,
   Apus.Engine.DefaultStyle, Apus.Engine.UIRender, Apus.Engine.TextEffects;

 function EffectValue(element,source:TUIElement;const key:String8;const defaultValue:String8):String8;
  begin
   result:=element.GetStyleValue(key,source.GetStyleValue(key,defaultValue));
  end;

 procedure DrawTextFXStyle(element:TUIElement);
  var
   source:TUIElement;
   ts:TUITextStyle;
   r,clipRect:TRect;
   localRect:TRect2;
   x,y,scale,blur,spread:single;
   color:cardinal;
   targetWidth:integer;
   text:String8;
   layer:TTextEffectLayer;
   isButton:boolean;
  begin
   isButton:=(element.ClassType=TUIButton) or
     ((element is TUIToggleButton) and not (element is TUICheckBox));
   if not isButton and (element.ClassType<>TUIElement) and
     not (element is TUILabel) and not (element is TUIImage) then begin
     Assert(false,'TextFXStyle: expected a button, label or image');
     exit;
    end;
   source:=element;
   if isButton then begin
    DrawDefaultUI(element,false);
    if SameText(element.GetStyleValue('caption-display'),'none') then exit;
   end else
    if SameText(element.GetStyleValue('caption-source'),'parent') and (element.parent<>nil) then
     source:=element.parent;
   text:=source.caption;
   if text='' then exit;
   if source is TUIButton then begin
    // No default per-caption press nudge: button.scroll already shifts content.
    ts:=ResolveUITextStyle(source,clBlack,taCenter,0,$FF300000,$80000000);
    if (ts.disabled>=1) and (ts.shadowColor=0) then ts.shadowColor:=$E0FFFFFF;
   end else begin
    if source is TUILabel then
     ts:=ResolveUITextStyle(source,$FF808080,TUILabel(source).align)
    else ts:=ResolveUITextStyle(source,$FF808080,taCenter);
   end;
   if source<>element then begin
    // Caption/state come from the parent; the child keeps its own
    // font overrides and render scale through the ordinary style cascade.
    // Alignment, color and text offsets follow the parent text state.
    ts.font:=txt.GetFont(element.GetStyleValue('font',source.GetStyleValue('font','Default')),
      round(element.GetStyleNumber('font-size',source.GetStyleNumber('font-size',9))*element.globalScale));
   end;
   if isButton then begin
    clipRect:=element.GetPosOnScreen;
    localRect:=element.GetRect;
    localRect.MoveBy(-element.scroll.X,-element.scroll.Y);
    r:=element.TransformToScreen(localRect).Rounded;
   end else r:=element.GetClientPosOnScreen;
   case ts.align of
    taRight:x:=r.Right-1;
    taCenter:x:=(r.Left+r.Right-1)*0.5;
    else x:=r.Left;
   end;
   if isButton then
    y:=round((r.Top+r.Bottom-1)*0.5+txt.Height(ts.font)*0.45)
   else
    y:=round((r.Top+r.Bottom)*0.5+txt.Height(ts.font)*0.45);
   if element is TUILabel then y:=y-TUILabel(element).verticalOffset;
   targetWidth:=0;
   if (element is TUILabel) and (ts.align=taJustify) then targetWidth:=r.Width;
   scale:=element.globalScale;
   blur:=ParseStyleNumber(EffectValue(element,source,'text-glow-blur','0'))*scale;
   spread:=ParseStyleNumber(EffectValue(element,source,'text-glow-spread','0'))*scale;
   if blur<0 then blur:=0;
   if blur>MAX_BLUR then blur:=MAX_BLUR;
   if spread<0 then spread:=0;
   if spread>MAX_SPREAD then spread:=MAX_SPREAD;
   color:=ParseStyleColor(EffectValue(element,source,'text-glow-color','#000000'));
   if isButton then gfx.clip.Rect(Rect(clipRect.Left+2,clipRect.Top+2,clipRect.Right-3,clipRect.Bottom-3))
    else gfx.clip.Rect(r);
   try
    if (targetWidth=0) and ((blur>0) or (spread>0)) and (color shr 24<>0) then begin
     layer:=TTextEffectLayer.Glow(color,blur,spread);
     // Glow replaces the separate text shadow, as in the legacy game style.
     ts.shadowColor:=0;
     ts.options:=ts.options and not toWithShadow;
     if ts.color shr 24<$FF then
      // Fade the composite once: separately faded layers/glyphs would overlap
      // differently at partially covered pixels.
      DrawTextFX(ts.font,x+ts.ofsX,y+ts.ofsY,ts.color,text,ts.align,[layer],ts.options)
     else begin
      DrawTextFXLayers(ts.font,x+ts.ofsX,y+ts.ofsY,$FF,text,ts.align,[layer],ts.options);
      WriteUIText(ts,x,y,text,targetWidth);
     end;
    end else
     WriteUIText(ts,x,y,text);
   finally
    gfx.clip.Restore;
   end;
  end;

 procedure RegisterTextFXStyle(styleID:byte);
  begin
   if (styleID=0) or (styleID>50) then
    raise EArgumentException.Create('TextFXStyle: style ID must be 1..50');
   RegisterUIStyle(styleID,@DrawTextFXStyle,'TextFX');
  end;
end.
