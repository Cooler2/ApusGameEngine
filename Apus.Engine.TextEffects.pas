// Text with effect layers: glow, soft outline, shadow (R-33)
//
// Layer semantics follow Engine 2 WriteEx: for each enabled layer the text alpha is
// shifted by (dx,dy), softly blurred (3x3), box-blurred (fastblurX/Y), boosted (power)
// and filled with the layer color; layers are stacked in order, the text goes on top.
// The composite is baked once (on GPU, through the regular txt.Write path) and cached;
// the alpha of the text color modulates the whole composite at draw time, so fading
// text never re-bakes.
//
// Design: Work/R-33_text_effects_design.md
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// -----------------------------------------------------
unit Apus.Engine.TextEffects;
interface
 uses Apus.Core, Apus.Engine.API;

 type
  // One effect layer under the text
  TTextEffectLayer=record
   enabled:boolean; // disabled layers are skipped
   blur:single; // soft 3x3 blur of the text alpha, pixels (spreads by 1 px at most; ~0..2 is meaningful)
   fastblurX,fastblurY:integer; // box blur radius, pixels (strong and cheap)
   color:cardinal; // layer fill color, alpha = layer opacity
   emboss,embossX,embossY:single; // emboss based on the text alpha: NOT supported, must be 0
   dx,dy:single; // layer offset, pixels
   power:single; // alpha boost: 0 - none, 1 - strong
  end;

 // Draw text with effect layers (glow, outline, soft shadow).
 // x,y is the text anchor exactly as in txt.Write: the same call without layers
 // puts the glyphs at the same pixels. color.RGB = text color (baked);
 // color.alpha modulates the whole composite at draw time (fading is free).
 // The result is baked on GPU once and cached per (font,text,align,options,text RGB,layers).
 procedure DrawTextFX(font:TFontHandle;x,y:single;color:cardinal;const st:String8;
   align:TTextAlignment;const layers:array of TTextEffectLayer;options:cardinal=0);

 // Drop all cached sprites of the calling render thread (context loss, font reload, global text scale change)
 procedure FlushTextFXCache;

implementation

 // True if at least one layer is enabled
 function HasEnabledLayers(const layers:array of TTextEffectLayer):boolean;
  var
   i:integer;
  begin
   for i:=0 to high(layers) do
    if layers[i].enabled then begin
     ASSERT((layers[i].emboss=0) and (layers[i].embossX=0) and (layers[i].embossY=0),'TextFX: emboss is not supported');
     exit(true);
    end;
   result:=false;
  end;

 procedure DrawTextFX(font:TFontHandle;x,y:single;color:cardinal;const st:String8;
   align:TTextAlignment;const layers:array of TTextEffectLayer;options:cardinal=0);
  begin
   ASSERT(options and (toDrawToBitmap or toMeasure)=0,'TextFX: bitmap/measure options are not allowed');
   if st='' then exit;
   if HasEnabledLayers(layers) then begin
    // TODO(R-33 T2): bake enabled layers on GPU and draw the cached sprite;
    // until then the text is drawn without effects
   end;
   // no effects - plain text, nothing to bake or cache
   txt.Write(font,x,y,color,st,align,options);
  end;

 procedure FlushTextFXCache;
  begin
   // TODO(R-33 T3): cache is not implemented yet
  end;

end.
