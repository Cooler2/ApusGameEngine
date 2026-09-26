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
   blur:single; // soft 3x3 blur of the text alpha (spreads by 1 px at most; ~0..2 is meaningful)
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
 // Effect sizes are in pixels of the current render target. The text is not translated
 // separately for the cache key: call FlushTextFXCache after switching the dictionary.
 procedure DrawTextFX(font:TFontHandle;x,y:single;color:cardinal;const st:String8;
   align:TTextAlignment;const layers:array of TTextEffectLayer;options:cardinal=0);

 // Drop all cached sprites of the calling render thread: call after SetFontOption,
 // font reload or dictionary switch (txt.SetScale is part of the cache key, no flush needed)
 procedure FlushTextFXCache;

implementation
 uses Types, Apus.Images, Apus.Geom2D, Apus.Geom3D,
   Apus.Engine.Resources, Apus.Engine.Graphics, Apus.Engine.TextDraw;

 const
  MAX_ENTRIES = 64;              // cached sprites per render thread
  MAX_PIXELS  = 4*1024*1024;     // total cached area per render thread
  MAX_SIDE    = 2048;            // larger text is drawn without effects
  POOL_STEP   = 64;              // work render targets grow in these steps
  RT_FLAGS    = aiTexture+aiRenderTarget+aiClampUV+aiThreadLocal;

  // Shift by (dx,dy) + soft 3x3 blur of the text alpha
  SOFT_SHADER=
   'uniform vec2 texel;'#13#10+
   'uniform vec2 shift;'#13#10+
   'uniform vec3 weights;'#0+ // center, edge, corner
   'vec2 uv = vTexCoord-shift;'#13#10+
   'float s = weights.x*texture(tex0,uv).a'#13#10+
   ' + weights.y*(texture(tex0,uv+vec2(texel.x,0.0)).a+texture(tex0,uv-vec2(texel.x,0.0)).a'#13#10+
   '             +texture(tex0,uv+vec2(0.0,texel.y)).a+texture(tex0,uv-vec2(0.0,texel.y)).a)'#13#10+
   ' + weights.z*(texture(tex0,uv+texel).a+texture(tex0,uv-texel).a'#13#10+
   '             +texture(tex0,uv+vec2(texel.x,-texel.y)).a+texture(tex0,uv+vec2(-texel.x,texel.y)).a);'#13#10+
   'fragColor = vec4(1.0,1.0,1.0,s);';

  // Box blur along one axis
  BOX_SHADER=
   'uniform vec2 dir;'#13#10+
   'uniform float radius;'#0+
   'int r = int(radius);'#13#10+
   'float s = 0.0;'#13#10+
   'for (int i=-r; i<=r; i++) s += texture(tex0,vTexCoord+dir*float(i)).a;'#13#10+
   'fragColor = vec4(1.0,1.0,1.0,s/float(2*r+1));';

  // Box blur along one axis + power curve + layer color (blended over the accumulator)
  LAYER_SHADER=
   'uniform vec2 dir;'#13#10+
   'uniform float radius;'#13#10+
   'uniform float power;'#13#10+
   'uniform vec4 layerColor;'#0+
   'int r = int(radius);'#13#10+
   'float s = 0.0;'#13#10+
   'for (int i=-r; i<=r; i++) s += texture(tex0,vTexCoord+dir*float(i)).a;'#13#10+
   's = s/float(2*r+1);'#13#10+
   'float u = min(s*(1.0+power),1.0);'#13#10+
   's = u*(1.0-s)+s*s;'#13#10+
   'fragColor = vec4(layerColor.rgb,layerColor.a*s);';

  // Premultiplied accumulator -> straight alpha (regular alpha blending when drawn)
  RESOLVE_SHADER=
   #0+
   'vec4 c = texture(tex0,vTexCoord);'#13#10+
   'if (c.a<=0.0) fragColor = vec4(0.0);'#13#10+
   ' else fragColor = vec4(min(c.rgb/c.a,vec3(1.0)),c.a);';

 type
  // Baked sprite
  TFXEntry=record
   key:String8;
   hash:cardinal;
   tex:TTexture;
   width,height:integer;
   ox,oy:integer; // text anchor inside the sprite
   lastUse:int64;
  end;

  // Per render thread state: work targets and the sprite cache
  TFXState=class
   pool:array[0..3] of TTexture; // text mask, 2 temp layers, premultiplied accumulator
   poolW,poolH:integer;
   entries:array of TFXEntry;
   count:integer;
   pixels:integer;
   useCounter:int64;
   destructor Destroy; override;
   procedure Clear;
   procedure FreePool;
   function EnsurePool(w,h:integer):boolean;
   function Find(const key:String8;hash:cardinal):integer;
   procedure Add(const entry:TFXEntry);
   procedure Evict(idx:integer);
   procedure MakeRoom(pixelsNeeded:integer);
  end;

 threadvar
  fxState:TFXState;

 function GetState:TFXState;
  begin
   if fxState=nil then fxState:=TFXState.Create;
   result:=fxState;
  end;

 { TFXState }

 destructor TFXState.Destroy;
  begin
   Clear;
   inherited;
  end;

 procedure TFXState.FreePool;
  var
   i:integer;
  begin
   for i:=0 to high(pool) do
    if pool[i]<>nil then begin
     FreeImage(pool[i]);
     pool[i]:=nil;
    end;
   poolW:=0; poolH:=0;
  end;

 procedure TFXState.Clear;
  begin
   while count>0 do Evict(count-1);
   FreePool;
  end;

 function TFXState.EnsurePool(w,h:integer):boolean;
  var
   i:integer;
  begin
   if (w<=poolW) and (h<=poolH) then exit(true);
   w:=Max(w,poolW); h:=Max(h,poolH);
   w:=(w+POOL_STEP-1) div POOL_STEP*POOL_STEP;
   h:=(h+POOL_STEP-1) div POOL_STEP*POOL_STEP;
   FreePool;
   for i:=0 to high(pool) do begin
    pool[i]:=AllocImage(w,h,pfRenderTargetAlpha,RT_FLAGS,'TextFX_Work');
    if pool[i]=nil then begin
     FreePool;
     exit(false);
    end;
   end;
   poolW:=w; poolH:=h;
   result:=true;
  end;

 function TFXState.Find(const key:String8;hash:cardinal):integer;
  var
   i:integer;
  begin
   for i:=0 to count-1 do
    if (entries[i].hash=hash) and (entries[i].key=key) then exit(i);
   result:=-1;
  end;

 procedure TFXState.Add(const entry:TFXEntry);
  begin
   MakeRoom(entry.width*entry.height);
   if count>=length(entries) then SetLength(entries,count+16);
   entries[count]:=entry;
   inc(count);
   inc(pixels,entry.width*entry.height);
  end;

 procedure TFXState.Evict(idx:integer);
  begin
   with entries[idx] do begin
    FreeImage(tex);
    dec(pixels,width*height);
   end;
   entries[idx]:=entries[count-1];
   entries[count-1]:=Default(TFXEntry);
   dec(count);
  end;

 // Drop least recently used entries until a new sprite fits the limits
 procedure TFXState.MakeRoom(pixelsNeeded:integer);
  var
   i,oldest:integer;
  begin
   while (count>0) and ((count>=MAX_ENTRIES) or (pixels+pixelsNeeded>MAX_PIXELS)) do begin
    oldest:=0;
    for i:=1 to count-1 do
     if entries[i].lastUse<entries[oldest].lastUse then oldest:=i;
    Evict(oldest);
   end;
  end;

 { Helpers }

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

 procedure AddBytes(var key:String8;const data;size:integer);
  var
   l:integer;
  begin
   l:=length(key);
   SetLength(key,l+size);
   move(data,key[l+1],size);
  end;

 // Everything that affects the baked pixels; the alpha of the text color does not
 function BuildKey(font:TFontHandle;rgb:cardinal;const st:String8;align:TTextAlignment;
   const layers:array of TTextEffectLayer;options:cardinal):String8;
  var
   i:integer;
   b:byte;
   scale:single;
  begin
   result:='';
   AddBytes(result,font,sizeof(font));
   AddBytes(result,rgb,sizeof(rgb));
   AddBytes(result,options,sizeof(options));
   b:=ord(align);
   AddBytes(result,b,1);
   scale:=TTextDrawer.globalScale;
   AddBytes(result,scale,sizeof(scale));
   // field by field: record padding may hold garbage
   for i:=0 to high(layers) do
    with layers[i] do
     if enabled then begin
      AddBytes(result,blur,sizeof(blur));
      AddBytes(result,fastblurX,sizeof(fastblurX));
      AddBytes(result,fastblurY,sizeof(fastblurY));
      AddBytes(result,color,sizeof(color));
      AddBytes(result,dx,sizeof(dx));
      AddBytes(result,dy,sizeof(dy));
      AddBytes(result,power,sizeof(power));
     end;
   result:=result+st;
  end;

 function HashKey(const key:String8):cardinal;
  var
   i:integer;
  begin
   result:=2166136261; // FNV-1a
   for i:=1 to length(key) do
    result:=(result xor byte(key[i]))*16777619;
  end;

 // Smallest integer >= v for v>=0
 function CeilPos(v:single):integer;
  begin
   if v<=0 then exit(0);
   result:=trunc(v);
   if result<v then inc(result);
  end;

 // Extent of a layer outside the text mask on each side
 procedure LayerSpread(const l:TTextEffectLayer;out left,top,right,bottom:integer);
  var
   soft:single;
  begin
   if l.blur>0.01 then soft:=1 else soft:=0; // 3x3 kernel spreads by 1 px whatever the blur value
   left:=CeilPos(l.fastblurX+soft-l.dx);
   right:=CeilPos(l.fastblurX+soft+l.dx);
   top:=CeilPos(l.fastblurY+soft-l.dy);
   bottom:=CeilPos(l.fastblurY+soft+l.dy);
  end;

 // Bind a work target: BeginPaint + optional clear + blending
 procedure BeginPass(target:TTexture;clear:boolean;blend:TBlendingMode);
  begin
   gfx.BeginPaint(target);
   if clear then gfx.target.Clear(0,-1,-1);
   gfx.target.BlendMode(blend);
  end;

 // Draw the w x h part of src 1:1 with the current (customized) shader and close the pass
 procedure DrawPass(src:TTexture;w,h:integer);
  begin
   try
    draw.ImagePart(0,0,src,$FF808080,Rect(0,0,w,h));
    shader.Reset;
   finally
    gfx.EndPaint;
   end;
  end;

 procedure BakeLayer(const l:TTextEffectLayer;state:TFXState;w,h:integer;first:boolean);
  var
   mask,src:TTexture;
   tu,tv,w0,w1,w2,sum,radius:single;
  begin
   mask:=state.pool[0];
   tu:=mask.stepU*2; tv:=mask.stepV*2; // texel size in UV
   // shift + soft 3x3 blur: mask -> pool[1]
   if l.blur>0.01 then begin
    w0:=1/(0.01+l.blur); w1:=1/(1.01+l.blur); w2:=1/(2.01+l.blur);
   end else begin
    w0:=1; w1:=0; w2:=0;
   end;
   sum:=w0+4*w1+4*w2;
   BeginPass(state.pool[1],true,blMove);
   shader.UseCustomized(SOFT_SHADER);
   shader.SetUniform('texel',TVec2.Init(tu,tv));
   shader.SetUniform('shift',TVec2.Init(l.dx*tu,l.dy*tv));
   shader.SetUniform('weights',TVec3.Init(w0/sum,w1/sum,w2/sum));
   DrawPass(mask,w,h);
   src:=state.pool[1];
   // box blur X: pool[1] -> pool[2]
   if l.fastblurX>0 then begin
    BeginPass(state.pool[2],true,blMove);
    shader.UseCustomized(BOX_SHADER);
    shader.SetUniform('dir',TVec2.Init(tu,0));
    radius:=l.fastblurX; // assignment, not single(): that would be a reinterpret cast in FPC
    shader.SetUniform('radius',radius);
    DrawPass(src,w,h);
    src:=state.pool[2];
   end;
   // box blur Y + power + color, blended over the accumulator
   BeginPass(state.pool[3],first,blAlpha);
   shader.UseCustomized(LAYER_SHADER);
   shader.SetUniform('dir',TVec2.Init(0,tv));
   radius:=Max(l.fastblurY,0);
   shader.SetUniform('radius',radius);
   shader.SetUniform('power',l.power);
   shader.SetUniform('layerColor',TShader.VectorFromColor(l.color));
   DrawPass(src,w,h);
  end;

 // Bake text with layers into a new texture; false if it can't be done
 function Bake(font:TFontHandle;rgb:cardinal;const st:String8;align:TTextAlignment;
   const layers:array of TTextEffectLayer;options:cardinal;out entry:TFXEntry):boolean;
  var
   state:TFXState;
   r:TRect;
   i,fh,shift,margin,pl,pt,pr,pb,sl,sTop,sr,sb,w,h:integer;
   first,wasBlock:boolean;
   blockOptions:cardinal;
   savedTransform:TTransformState;
   savedBlend:TBlendingMode;
  begin
   result:=false;
   entry:=Default(TFXEntry);
   if pfRenderTargetAlpha=ipfNone then exit;
   state:=GetState;
   // text extent relative to the anchor (Measure works as taLeft)
   r:=txt.Measure(font,st,options);
   case align of
    TTextAlignment.taRight:shift:=-r.Width;
    TTextAlignment.taCenter:shift:=-(r.Width div 2);
    else shift:=0;
   end;
   OffsetRect(r,shift,0);
   // measured box is ascent..baseline: leave room for descenders, accents and overhangs
   fh:=Max(txt.Height(font),1);
   margin:=fh div 4+2;
   pl:=0; pt:=0; pr:=0; pb:=0;
   for i:=0 to high(layers) do
    if layers[i].enabled then begin
     LayerSpread(layers[i],sl,sTop,sr,sb);
     pl:=Max(pl,sl); pt:=Max(pt,sTop); pr:=Max(pr,sr); pb:=Max(pb,sb);
    end;
   r.Left:=r.Left-margin-pl;
   r.Right:=r.Right+margin+pr;
   r.Top:=r.Top-fh div 2-pt-1;
   r.Bottom:=r.Bottom+fh div 2+2+pb;
   w:=r.Width; h:=r.Height;
   if (w<=0) or (h<=0) or (w>MAX_SIDE) or (h>MAX_SIDE) then exit;
   if not state.EnsurePool(w,h) then exit;

   entry.width:=w; entry.height:=h;
   entry.ox:=-r.Left; entry.oy:=-r.Top;
   entry.tex:=AllocImage(w,h,pfRenderTargetAlpha,RT_FLAGS,'TextFX');
   if entry.tex=nil then exit;

   // Nested render passes: EndPaint resets the caller's transform and blending, and
   // an open text block would swallow our text into the caller's batch
   savedTransform:=transformationAPI.SaveState;
   savedBlend:=renderTargetAPI.CurrentBlendMode;
   wasBlock:=TTextDrawer.textCaching;
   blockOptions:=TTextDrawer.textBlockOptions;
   if wasBlock then txt.EndBlock;
   try
    // text mask
    BeginPass(state.pool[0],true,blAlpha);
    try
     txt.Write(font,entry.ox,entry.oy,$FFFFFFFF,st,align,options);
    finally
     gfx.EndPaint;
    end;
    // layers, in order, into the accumulator
    first:=true;
    for i:=0 to high(layers) do
     if layers[i].enabled then begin
      BakeLayer(layers[i],state,w,h,first);
      first:=false;
     end;
    // text on top
    BeginPass(state.pool[3],false,blAlpha);
    try
     txt.Write(font,entry.ox,entry.oy,rgb or $FF000000,st,align,options);
    finally
     gfx.EndPaint;
    end;
    // resolve into the entry texture
    BeginPass(entry.tex,true,blMove);
    shader.UseCustomized(RESOLVE_SHADER);
    DrawPass(state.pool[3],w,h);
    result:=true;
   finally
    transformationAPI.RestoreState(savedTransform);
    gfx.target.BlendMode(savedBlend);
    if wasBlock then txt.BeginBlock(blockOptions);
    if not result then FreeImage(entry.tex);
   end;
  end;

 procedure DrawTextFX(font:TFontHandle;x,y:single;color:cardinal;const st:String8;
   align:TTextAlignment;const layers:array of TTextEffectLayer;options:cardinal=0);
  var
   key:String8;
   hash,rgb:cardinal;
   idx:integer;
   state:TFXState;
   entry:TFXEntry;
  begin
   ASSERT(options and (toDrawToBitmap or toMeasure)=0,'TextFX: bitmap/measure options are not allowed');
   if st='' then exit;
   if not HasEnabledLayers(layers) then begin
    txt.Write(font,x,y,color,st,align,options); // no effects - plain text, nothing to bake or cache
    exit;
   end;
   if font=0 then font:=game.defaultFont;
   rgb:=color and $FFFFFF;
   key:=BuildKey(font,rgb,st,align,layers,options);
   hash:=HashKey(key);
   state:=GetState;
   idx:=state.Find(key,hash);
   if idx<0 then begin
    if not Bake(font,rgb,st,align,layers,options,entry) then begin
     txt.Write(font,x,y,color,st,align,options); // can't bake (too large, no RT format) - text without effects
     exit;
    end;
    entry.key:=key;
    entry.hash:=hash;
    state.Add(entry);
    idx:=state.count-1;
   end;
   inc(state.useCounter);
   with state.entries[idx] do begin
    lastUse:=state.useCounter;
    // same rounding as txt.Write, so the glyphs land on the same pixels
    draw.ImagePart(SRound(x)-ox,SRound(y)-oy,tex,$808080+color and $FF000000,Rect(0,0,width,height));
   end;
  end;

 procedure FlushTextFXCache;
  begin
   if fxState<>nil then fxState.Clear;
  end;

end.
