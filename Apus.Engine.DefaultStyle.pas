// Default UI style (0) inspired by CSS
//
// Copyright (C) 2022 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.DefaultStyle;
interface
uses Apus.Core, Apus.Engine.Types, Apus.Engine.API, Apus.Engine.UI;
 type
  // Resolved text parameters. Extensions never share the private style context.
  TUITextStyle=record
   font:TFontHandle;
   color:cardinal;
   align:TTextAlignment;
   options:cardinal;
   shadowColor:cardinal;
   shadowX,shadowY:single;
   ofsX,ofsY:single; // screen pixels
   hover,pressed,disabled:single; // transition progress
  end;

 // Retain the standard skin/focus/transitions while optionally replacing caption.
 procedure DrawDefaultUI(element:TUIElement;drawButtonCaption:boolean=true);
 function ResolveUITextStyle(element:TUIElement;defColor:cardinal;
   defAlign:TTextAlignment=taLeft;defOptions:cardinal=0;
   defHoverColor:cardinal=0;defDisabledColor:cardinal=0;defPressOfsY:single=0):TUITextStyle;
 procedure WriteUIText(const style:TUITextStyle;x,y:single;const text:String8;targetWidth:integer=0);

 var
  defaultBtnColor:cardinal=$FFB0A0C0;

implementation
 uses Apus.Images, SysUtils, Types, Apus.Tweenings,
    Apus.Colors, Apus.EventMan, Apus.Geom2D,
    Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.UIMenu, Apus.Engine.UITable,
    Apus.Engine.UIRender,
    Apus.Engine.Style, // ParseStyleColor/Number for compound values (text-shadow)
    Apus.Lib, Apus.Utils, Apus.Strings;

 var
  hintImage,tickImage:TTexture;
  //imgHash:TObjectMap;  // hash of loaded images: filename -> TTexture
  unsupportedImageSources:Strings8; // already reported to the log

  blendModeChanged:boolean;

 type
  TContext=class
   disabled:TTweening;
   hover:TTweening;
   active:TTweening;
   skinned:boolean; // set by the box path: a background-image was drawn this frame
   destructor Destroy; override;
   constructor Create(element:TUIElement);
   procedure Update(element:TUIElement);
   // Resolve a 'background-image' value to a texture. 'file:' textures are loaded once
   // and memoized (the context holds one reference each); 'tex:' ones are looked up
   // every call and never owned (the creator of a named texture keeps it alive)
   function GetImage(const src:String8):TTexture;
  private
   imgSrc:array of String8;  // memo: source string -> texture (small, linear)
   imgTex:array of TTexture; // one reference per entry, released in the destructor
  end;

 function PrepareContext(element:TUIElement):TContext;
  begin
   if element.styleContext<>nil then begin
    if element.styleContext is TContext then exit(TContext(element.styleContext));
    element.StyleContext.Free;
   end;
   result:=TContext.Create(element);
   element.styleContext:=result;
  end;

 procedure SetProperBlendMode(element:TUIElement);
  begin
   if transpBgnd and (element.shape<>TUIShape.shapeEmpty) then begin
    gfx.target.BlendMode(blMove);
    blendModeChanged:=true;
   end;
  end;

 procedure RestoreBlendMode;
  begin
   if blendModeChanged then begin
    gfx.target.BlendMode(blAlpha);
    blendModeChanged:=false;
   end;
  end;

 // styleinfo="00000000 11111111 22222222 33333333" - list of colors (hex)
{ function GetStyleColor(control:TUIElement;index:integer=0):cardinal;
  var
   i,v:integer;
  begin
   result:=0;
   for i:=1 to length(control.styleinfo) do begin
    if control.styleinfo[i]<'0' then begin
     dec(index);
     if index<0 then exit;
     continue;
    end;
    if index=0 then begin
     v:=(ord(control.styleinfo[i]) and $1F)-$10;
     if v<0 then inc(v,25);
     result:=result shl 4+v;
    end;
   end;
  end;}


 type
  // Content (text) style of an element, resolved for its current state.
  // Offsets are screen pixels (logical style units multiplied by globalScale).
  TTextStyle=TUITextStyle;

 // Resolve the content keys for the element's current state: font, color, text-align,
 // text-decoration, text-shadow, text-offset-x/y. Colors and offsets are tweened through
 // the state values (like the box path); align, decoration and shadow switch instantly.
 // defHoverColor/defDisabledColor - drawer defaults for those states (0 = keep the base
 // color); defPressOfsY - default caption shift while pressed (data can override it).
 function ResolveTextStyle(element:TUIElement;context:TContext;defColor:cardinal;
    defAlign:TTextAlignment=taLeft;defOptions:cardinal=0;
    defHoverColor:cardinal=0;defDisabledColor:cardinal=0;defPressOfsY:single=0):TTextStyle;
  var
   scale:single;
   st:String8;
   parts:Strings8;
   i,n:integer;
  procedure BlendColor(const state:String8;v:single;defC:cardinal);
   begin
    if v<=0 then exit;
    if defC=0 then defC:=result.color;
    result.color:=Color.Mix(result.color,element.GetStateStyleColor(state,'color',defC),v);
   end;
  procedure BlendOffset(const state:String8;v,defY:single);
   begin
    if v<=0 then exit;
    result.ofsX:=Lerp(result.ofsX,element.GetStateStyleNumber(state,'text-offset-x',result.ofsX),v);
    result.ofsY:=Lerp(result.ofsY,element.GetStateStyleNumber(state,'text-offset-y',result.ofsY+defY),v);
   end;
  begin
   scale:=element.globalScale;
   result.font:=element.StyleFont;
   result.hover:=context.hover.Value;
   result.pressed:=context.active.Value;
   result.disabled:=context.disabled.Value;
   result.options:=defOptions;
   result.shadowColor:=0;
   result.shadowX:=1; result.shadowY:=1;
   // Base values (states are blended in, so the base must ignore them)
   result.color:=element.GetBaseStyleColor('color',defColor);
   result.ofsX:=element.GetBaseStyleNumber('text-offset-x');
   result.ofsY:=element.GetBaseStyleNumber('text-offset-y');
   BlendColor('hover',context.hover.Value,defHoverColor);
   BlendColor('pressed',context.active.Value,0);
   BlendColor('disabled',context.disabled.Value,defDisabledColor);
   BlendOffset('hover',context.hover.Value,0);
   BlendOffset('pressed',context.active.Value,defPressOfsY);
   BlendOffset('disabled',context.disabled.Value,0);
   // Alignment: the style overrides the drawer's default (e.g. TUILabel.align)
   result.align:=defAlign;
   st:=element.GetStyleValue('text-align');
   if st<>'' then
    if SameText(st,'left') then result.align:=taLeft else
    if SameText(st,'center') then result.align:=taCenter else
    if SameText(st,'right') then result.align:=taRight else
    if SameText(st,'justify') then result.align:=taJustify;
   // Decoration
   st:=element.GetStyleValue('text-decoration');
   if SameText(st,'underline') then result.options:=result.options or toUnderline else
   if SameText(st,'none') then result.options:=result.options and not toUnderline;
   // Shadow: '<color> [dx dy]' or 'none'; an explicit shadow replaces the built-in one
   st:=element.GetStyleValue('text-shadow');
   if st<>'' then begin
    result.options:=result.options and not toWithShadow;
    if not SameText(st,'none') then begin
     parts:=st.Split(' ');
     n:=0;
     for i:=0 to high(parts) do
      if parts[i].Trim<>'' then begin
       parts[n]:=parts[i].Trim; inc(n);
      end;
     if n>0 then result.shadowColor:=ParseStyleColor(ExpandToken(parts[0]));
     if n>=3 then begin
      result.shadowX:=ParseStyleNumber(parts[1]);
      result.shadowY:=ParseStyleNumber(parts[2]);
     end;
    end;
   end;
   result.ofsX:=result.ofsX*scale;
   result.ofsY:=result.ofsY*scale;
   result.shadowX:=result.shadowX*scale;
   result.shadowY:=result.shadowY*scale;
  end;

 // Anchor point matching ts.align inside a horizontal span (x2 = inclusive right edge)
 function AlignAnchor(const ts:TTextStyle;x1,x2:integer):single;
  begin
   case ts.align of
    taRight:result:=x2;
    taCenter:result:=(x1+x2)/2;
    else result:=x1;
   end;
  end;

 // Draw text with a resolved content style: offsets, shadow layer and options included.
 // x matches ts.align (left edge / center / right edge), y is the baseline.
 procedure WriteStyled(const ts:TTextStyle;x,y:single;const st:String32;targetWidth:integer=0); overload;
  begin
   x:=x+ts.ofsX; y:=y+ts.ofsY;
   if ts.shadowColor<>0 then
    txt.WriteW(ts.font,x+ts.shadowX,y+ts.shadowY,ts.shadowColor,st,ts.align,ts.options,targetWidth);
   txt.WriteW(ts.font,x,y,ts.color,st,ts.align,ts.options,targetWidth);
  end;

 procedure WriteStyled(const ts:TTextStyle;x,y:single;const st:String8;targetWidth:integer=0); overload;
  begin
   x:=x+ts.ofsX; y:=y+ts.ofsY;
   if ts.shadowColor<>0 then
    txt.Write(ts.font,x+ts.shadowX,y+ts.shadowY,ts.shadowColor,st,ts.align,ts.options,targetWidth);
   txt.Write(ts.font,x,y,ts.color,st,ts.align,ts.options,targetWidth);
  end;

 // Resolve an image reference used by style values and TUIImage.src:
 //   tex:<name>  - registered texture (TTexture.FindByName); weak reference: the
 //                 creator of the texture keeps it alive, nothing to free
 //   file:<name> - image file via LoadImage: the first user loads it, later users share
 //                 the same texture; the caller owns one reference (FreeImage when done)
 //   none or ''  - no image (e.g. to cancel an image set by a named style)
 // Returns nil if the reference can't be resolved (yet). An unsupported source is
 // reported to the log once per distinct value.
 function ResolveStyleImage(const src:String8):TTexture;
  var
   i:integer;
  begin
   result:=nil;
   if (src='') or SameText(src,'none') then exit;
   if src.StartsWith('tex:',true) then
    result:=TTexture(TTexture.FindByName(copy(src,5,200)))
   else
   if src.StartsWith('file:',true) then
    LoadImage(result,copy(src,6,200))
   else begin
    for i:=0 to high(unsupportedImageSources) do
     if unsupportedImageSources[i]=src then exit;
    i:=length(unsupportedImageSources);
    SetLength(unsupportedImageSources,i+1);
    unsupportedImageSources[i]:=src;
    Log.Warn('Unsupported image source: '+src);
   end;
  end;

 procedure DrawUIElement(element:TUIElement;x1,y1,x2,y2:integer;context:TContext);
  var
   ts:TTextStyle;
  begin
   if (element.caption<>'') and (element.ClassType=TUIElement) then begin
    ts:=ResolveTextStyle(element,context,$FF808080,taCenter,toWithShadow);
    WriteStyled(ts,AlignAnchor(ts,x1,x2),(y1+y2)/2,Str32(element.caption));
   end;
  end;

 procedure BuildSimpleHint(hnt:TUIHint);
  var
   lines:Strings8;
   i,h,iWidth,iHeight,dw,lw:integer;
   font:TFontHandle;
  begin
   font:=hnt.StyleFont;
   if font=0 then font:=defaultHintFont;
   if font=0 then font:=txt.GetFont('Default',7);
   with hnt do begin
    // line breaks: '~' or a literal '\n' sequence -> a real newline char.
    hnt.simpleText:=StringReplace(hnt.simpleText,'\n',#10,[rfReplaceAll]);
    hnt.simpleText:=StringReplace(hnt.simpleText,'~',#10,[rfReplaceAll]);
    lines:=hnt.simpleText.Split(#10);
    h:=round(txt.Height(font)*1.5);
    iHeight:=h*length(lines)+9;
    iWidth:=0;
    for i:=0 to high(lines) do begin
     lw:=txt.Measure(font,lines[i],toComplexText).Width; // SML-aware width via the real layout path
     if iWidth<lw then iWidth:=lw;
    end;
    dw:=txt.Width(font,'M');
    inc(iWidth,4+dw);
    if (hintImage=nil) or (hintImage.width<>iWidth) or (hintImage.height<>iHeight) then begin
     Log.Debug('[Re]alloc hint image');
     if HintImage<>nil then FreeImage(HintImage);
     hintImage:=AllocImage(iWidth,iHeight,pfRenderTargetAlpha,aiTexture+aiRenderTarget,'UI_HintImage');
     if hintImage=nil then
       raise EError.Create('Failed to alloc hint image!');
    end;
    size.Init(iWidth/globalScale,iHeight/globalScale);
    gfx.BeginPaint(hintImage);
    try
     gfx.target.Mask(true,true); // may potentially break drawing of the following elements
     gfx.target.Clear(0,-1,-1);
     draw.FillGradrect(0,0,iwidth-3,iheight-3,$FFFFFFD0,$FFE0E0A0,true);
     draw.Rect(0,0,iwidth-3,iheight-3,$FF000000);
     // shadow
     draw.Line(1,iHeight-2,iwidth-2,iheight-2,$50000000);
     draw.Line(iwidth-2,iheight-2,iwidth-2,0.5,$50000000);
     draw.Line(2,iHeight-1,iwidth-1,iheight-1,$28000000);
     draw.Line(iwidth-1,iheight-2,iwidth-1,1.5,$28000000);
     gfx.target.UnMask;
     // rich text: SML markup ({B}, {C=...}, ...) is honored; default color $D0000000 unless overridden by {C=...}
     for i:=0 to high(lines) do
      txt.Write(font,1+dw div 2,round(2+h div 7+(i+0.75)*h),$D0000000,lines[i],taLeft,toComplexText);
    finally
     gfx.EndPaint;
    end;
   end;
  end;

 procedure AdjustHint(scrX,scrY:integer;hnt:TUIHint);
  var
   pnt:TVec2;
   remainer:single;
  begin
   with hnt do begin
    adjusted:=true;
    pnt.x:=scrX+(5+size.x)*globalscale; // right side in screen coordinates
    pnt.y:=scrY+(12+size.y)*globalScale; // bottom in screen coordinates
    // Adjust Y
    remainer:=window.canvasHeight-pnt.y;
    if remainer<0 then begin
     position.y:=position.y-size.y;
    end else
     position.y:=position.y+12;
    // Adjust X
    remainer:=window.canvasWidth-pnt.x;
    if remainer<0 then begin
     pnt.x:=scrX+remainer;
     pnt:=parent.TransformFromScreen(pnt);
     position.x:=pnt.x;
    end else
     position.x:=position.x+5;
   end;
  end;

 procedure DrawUIHint(control:TUIHint;x1,y1,x2,y2:integer);
  var
   v:integer;
   c:cardinal;
   savePos:TVec2;
  begin
    with control as TUIHint do begin
     if pfRenderTargetAlpha=ipfNone then exit;
     if not adjusted then begin
      // initialize hint contents before the first draw
      Log.Debug('InitHint '+inttohex(UIntPtr(control),SizeOf(UIntPtr)*2));
      if not active then try
       BuildSimpleHint(control as TUIHint);
      except
       on e:exception do begin
        Log.Msg('Failed to build simple hint - deleted');
        control.flags.visible:=false;
        exit;
       end;
      end;
      // adjust the on-screen position (so it is always visible)
      savePos:=position;
      AdjustHint(x1,y1,control as TUIHint);
      savePos.Sub(position);
      inc(x1,round(savepos.x));
      inc(y1,round(savepos.y));
      control.globalRect:=control.GetPosOnScreen;
      x1:=control.globalRect.Left;
      y1:=control.globalRect.Top;
     end;
     if not hiding then
      v:=(CoreTime.Ticks-created)*2
     else begin
      v:=256-(CoreTime.Ticks-created) div 2;
      if v<=0 then begin
        {FreeImage(HintImage);
        HintImage:=nil;}
        control.flags.visible:=false;
        exit;
      end;
     end;
     if hintImage=nil then begin
      Log.Force('Hint has no image! '+inttohex(UIntPtr(control),SizeOf(UIntPtr)*2));
      exit;
     end;
     if v>256 then v:=256;
     c:=Color.Scale(clNeutral,v/256);
     gfx.clip.Nothing;
     draw.Image(x1,y1,HintImage,c);
     gfx.clip.Restore;
    end;
  end;

 procedure DrawUILabel(control:TUILabel;x1,y1,x2,y2:integer;context:TContext);
  var
   mY,targetWidth:integer;
   wst:String32;
   r:TRect;
   ts:TTextStyle;
  begin
   // control.align is the default: 'text-align' in the style overrides it
   ts:=ResolveTextStyle(control,context,$FF808080,control.align);
   with control do begin
     r:=GetClientPosOnScreen;
     gfx.clip.Rect(r);
     mY:=round((r.top+r.bottom)*0.5+txt.Height(ts.font)*0.45)-verticalOffset;
     wst:=Str32(caption);
     if ts.align=taJustify then targetWidth:=r.Width
      else targetWidth:=0;
     WriteStyled(ts,AlignAnchor(ts,r.left,r.Right-1),mY,wst,targetWidth);
     gfx.clip.Restore;
    end;
  end;

 procedure DrawUICheckbox(element:TUICheckbox;x1,y1,x2,y2:integer);
  const
   TICK_IMAGE = '20 1F ((((~SSS(SSS^SSSESSSDSSS_SSSBSSS &A(*-+&@(*+$&>(%$)*&=(*-$)*&=(*+$+*&=(*+$+*&=(*$)+*&<(%&()*'+
    '&<(*-&()*&<(*,&()/*&;(*-&(),*&<(*&()-*&<(*&().*&<(*+&()*&<(*+&()*&1(&(*&+(*.&(),*&0(*/++,*&)(*,&()+*&0(*-&().*'+
    '&((*&))*&1(.&*)/*#*+&(),*&1(*+&))+*(*-&().*&3(*+&)),%&))*&5(*&*)*&)),*&5(*,&))+&()+*&7(*&.)/*&7(*,&,).*&9(*&,)*'+
    '&:(*,&*)!\SSS*&;(*&))+*&<(*.$)-*&>(*$-*&?(*.%&:(';
  var
   col,vColor:cardinal;
   font:TFontHandle;
   d,y,yy,fontH,size:integer;
   v,ss,tt,alpha:single;
   context:TContext;
   ts:TTextStyle;
   inTransition:boolean;
  begin
   context:=element.styleContext as TContext;

   col:=element.GetStyleColor('border-color',$FF808080); // box outline
   ts:=ResolveTextStyle(element,context,col); // caption is always left-aligned after the box
   ts.align:=taLeft;
   font:=ts.font;
   fontH:=txt.Height(font);
   y:=y2-round((y2-y1+1-fontH)/2);
   size:=round(fontH*1.2);
   inc(x1,round(size*0.3));
   d:=round(size*0.15);
   //
   inTransition:=context.active.IsAnimating(window.frameStartMs);
   if element.classType=TUICheckBox then begin
    vColor:=element.GetStyleColor('tick-color',Color.Add(col,$808080));
    draw.RoundRect(x1,y-size+d,x1+size,y+d,size*0.24,element.globalScale,col,0);
    if tickImage=nil then tickImage:=CreateImageFrom(TICK_IMAGE,1);
    if element.checked or inTransition then begin
     alpha:=1; ss:=1.1;
     if inTransition then begin // transition
      tt:=context.active.Value;
      if context.active.FinalValue=1 then begin
       // appear
       alpha:=splines.easeOut(tt,0,1,0.5,1);
       ss:=Spline(tt, 0.5,3, 1.1,-1);
      end else begin
       // dissolve
       alpha:=tt;
      end;
     end;
     draw.Centered(x1+size*0.65,y-size*0.4,ss*size/tickImage.height,tickImage,Color.Scale(vColor,alpha));
    end;
   end;
   if element.ClassType=TUIRadioButton then begin
    yy:=y-size+d;
    draw.RoundRect(x1,yy,x1+size,yy+size,size*0.5+1,element.globalScale,col,0);
    if element.checked or inTransition then begin
     alpha:=1;
     v:=size*0.24;
     if inTransition then begin // transition
      tt:=context.active.Value;
      if context.active.FinalValue=1 then begin
       // appear
       alpha:=tt;
       v:=size*Spline(tt, 0.4,-0.8, 0.24,0.8);
      end else begin
       // dissolve
       alpha:=tt;
       v:=size*(0.24+tt*0.2);
      end;
     end;
     vColor:=Color.Scale(element.GetStyleColor('tick-color',col),alpha);
     draw.RoundRect(x1+v,yy+v,x1+size-v,yy+size-v,size*0.5+1-v,1,vColor,vColor);
    end;
   end;
   // Caption
   inc(x1,round(size*1.5));
   gfx.clip.Rect(Rect(x1,y1,x2,y2));
   WriteStyled(ts,x1,y,element.caption);
   gfx.clip.Restore;
   if FocusedElement=element then
     draw.Rect(x1,y1,x2,y2,col xor $808080);
  end;

 procedure DrawUIButton(control:TUIButton;x1,y1,x2,y2:integer;context:TContext;drawCaption:boolean);
  var
   localRect:TRect2;
   captionRect:TRect;
   mY:integer;
   c,c2:cardinal;
   hv,av,dv:single;
   wst:String32;
   ts:TTextStyle;
  begin
   with control do begin
      hv:=context.hover.Value;
      av:=context.active.Value;
      dv:=context.disabled.Value;

      // The box (fill / background-image, state-blended) is drawn by the common box path.
      // Procedural look adds a bevel on top of it; a skinned button has the bevel baked in.
      if not context.skinned then begin
       draw.FillGradRect(x1+1,y1+1,x2-1,y2-1,$30FFFFFF,$30000000,true); // bevel gradient
       c:=control.GetBaseStyleColor('border-light',$60000000);
       c2:=control.GetBaseStyleColor('border-dark',$80FFFFFF);
       draw.ShadedRect(x1,y1,x2,y2,1,c,c2); // outer frame
       if av>=1 then { pressed, no inner frame }
        else if dv<1 then begin // enabled
          c:=Color.Mix(control.GetBaseStyleColor('border-light',$A0FFFFFF),
                       control.GetStateStyleColor('hover','border-light',$A0FFFFFF),hv);
          c2:=Color.Mix(control.GetBaseStyleColor('border-dark',$70000000),
                        control.GetStateStyleColor('hover','border-dark',$70000000),hv);
          draw.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,c,c2);
        end else begin // disabled
          c:=control.GetStateStyleColor('disabled','border-light',$A0FFFFFF);
          c2:=control.GetStateStyleColor('disabled','border-dark',$70000000);
          draw.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,c,c2);
        end;
       // focus ring (a skin expresses focus via ':focused { background-image }')
       if (FocusedElement=control) or
          (default and ((FocusedElement=nil) or not (FocusedElement is TUIButton))) then
        draw.Rect(x1-1,y1-1,x2+1,y2+1,$80FFFF80);
      end;
      // The caption and child widgets share the same client-content displacement.
      // Explicit text-offset values remain an additional caption-only adjustment.
      if drawCaption and (caption<>'') and
         not SameText(control.GetStyleValue('caption-display'),'none') then begin
       gfx.clip.Rect(Rect(x1+2,y1+2,x2-2,y2-2));
       ts:=ResolveTextStyle(control,context,clBlack,taCenter,0,$FF300000,$80000000);
       localRect:=GetRect;
       localRect.MoveBy(-scroll.X,-scroll.Y);
       captionRect:=TransformToScreen(localRect).Rounded;
       // fully disabled: engraved look (light shadow under the dimmed caption)
       if (dv>=1) and (ts.shadowColor=0) then ts.shadowColor:=$E0FFFFFF;
       mY:=round((captionRect.Top+captionRect.Bottom-1)*0.5+txt.Height(ts.font)*0.45);
       wSt:=Str32(caption);
       WriteStyled(ts,AlignAnchor(ts,captionRect.Left,captionRect.Right-1),mY,wst);
       gfx.clip.Restore;
      end;
    end;
  end;

 // Menu line: the box (hover = the current line) is drawn by the common path. Caption on the
 // left, shortcut on the right in 'shortcut-color' (the text color by default; the text color
 // anyway while highlighted or disabled)
 procedure DrawUIMenuItem(item:TUIMenuItem;context:TContext);
  var
   r:TRect;
   ts:TTextStyle;
   y:integer;
  begin
   ts:=ResolveTextStyle(item,context,clBlack,taLeft);
   r:=item.GetClientPosOnScreen;
   y:=round((r.Top+r.Bottom-1)*0.5+txt.Height(ts.font)*0.45);
   gfx.clip.Rect(item.GetPosOnScreen);
   WriteStyled(ts,AlignAnchor(ts,r.Left,r.Right-1),y,item.caption);
   if item.shortcut<>'' then begin
    ts.align:=taRight;
    ts.font:=item.ShortcutFont; // smaller by default, on the same baseline
    ts.color:=Color.Mix(item.GetStyleColor('shortcut-color',ts.color),ts.color,
      Max(context.hover.Value,context.disabled.Value));
    WriteStyled(ts,r.Right-1,y,item.shortcut);
   end;
   gfx.clip.Restore;
  end;

 procedure DrawUIMenuSeparator(sep:TUIMenuSeparator;x1,y1,x2,y2:integer);
  var
   d,y:integer;
  begin
   d:=round(4*sep.globalScale);
   y:=(y1+y2) div 2;
   draw.Line(x1+d,y,x2-d,y,sep.GetStyleColor('line-color',$60000000));
  end;

 procedure DrawUIFrame(control:TUIFrame;x1,y1,x2,y2:integer);
  var
   c1,c2:cardinal;
   i:integer;
  begin
   c1:=control.GetStyleColor('border-color',clBlack);
   c2:=control.GetStyleColor('border-dark',0); // 0 = flat frame
   for i:=0 to round(control.padding.Left)-1 do begin
    if c2=0 then draw.Rect(x1+i,y1+i,x2-i,y2-i,c1)
     else draw.ShadedRect(x1+i,y1+i,x2-i,y2-i,1,c1,c2);
   end;
  end;

 procedure DrawUIImage(control:TUIImage;x1,y1,x2,y2:integer;context:TContext);
  type
   TImageDrawProc=procedure(img:TUIImage);
  var
   tex:TTexture;
   proc:TImageDrawProc;
  begin
    with control do begin
     if src<>'' then begin
      // SRC = procesure address?
      if src.StartsWith('proc:',true) then begin
       proc:=pointer(Conv.HexToInt(copy(src,6,20)));
       proc(control);
       exit;
      end;
      // SRC = event (must be immediate)
      if src.StartsWith('event:',true) then begin
       Signal(copy(src,7,200),PtrUInt(control));
       exit;
      end;
      // SRC = image reference: 'tex:<name>' or 'file:<name>'
      tex:=context.GetImage(src);
      if tex<>nil then begin
       draw.Scaled(x1,y1,x2-1,y2-1,tex,control.GetStyleColor('tint',clWhite));
      end;
     end;
    end;
  end;

 // Window chrome (header, frame, caption). A skinned window (background-image) has its
 // chrome painted by the artist, so only the box path draws it.
 procedure DrawUIWindow(element:TUIWindow;x1,y1,x2,y2:integer;context:TContext);
  var
   c:cardinal;
   ty:integer;
   col:cardinal;
   ts:TTextStyle;
  begin
   if context.skinned then exit;
   col:=element.GetStyleColor('fill',$FFB0B0C0);
   ts:=ResolveTextStyle(element,context,$FFFFFFD0,taCenter);
   if ts.shadowColor=0 then ts.shadowColor:=$B0000000; // classic title shadow
   with element do begin
    // body: the common box path already drew 'fill' when the style defines it;
    // draw the default body only for a style without 'fill' (avoids double blending)
    if element.GetStyleValue('fill')='' then draw.FillRect(x1,y1,x2,y2,col);
    if boundToWindow then exit; // the app draws the caption row of an OS window frame
    if element.IsActiveWindow then c:=$FF8080E0 // current window
     else c:=$FFB0B0B0;
    c:=Color.Mix(col,c,128);
    if resizeable then begin
      draw.FillRect(x1,y1,x2,y1+header-1,c);
      draw.FillRect(x1,y1+header,x1+wcFrameBorder-1,y2,c);
      draw.FillRect(x2-wcFrameBorder+1,y1+header,x2,y2,c);
      draw.FillRect(x1+wcFrameBorder,y2-wcFrameBorder+1,x2-wcFrameBorder,y2,c);
      draw.ShadedRect(x1+wcFrameBorder-1,y1+header-1,x2-wcFrameBorder+1,y2-wcFrameBorder+1,1,$80000000,$80FFFFFF);
    end else begin
      draw.FillRect(x1,y1,x2,y1+header-1,c);
      draw.ShadedRect(x1+3,y1+header-1,x2-3,y1+header,1,$80000000,$80FFFFFF);
    end;
    draw.ShadedRect(x1,y1,x2,y2,2,$C0FFFFFF,$C0000000);

    gfx.clip.Rect(Rect(x1+2,y1+2,x2-2,y1+header-2));
    ty:=y1+round(header*0.7);
    WriteStyled(ts,AlignAnchor(ts,x1,x2),ty,caption);
    gfx.clip.Restore;
   end;
  end;

 procedure DrawUIScrollbar(element:TUIScrollbar;x1,y1,x2,y2:integer);
  var
   col,trackColor:cardinal;
   size,width:integer;
   scale,trackWidth,sliderWidth,sliderRadius,f:single;
   sStyle:string8;
   context:TContext;
   sliderVisible:boolean;
   r:TRect2;
  begin
   size:=x2-x1; width:=y2-y1;
   if not element.horizontal then Swap(size,width);
   // Calculate parameters
   element.CalcSliderPos(element.GetStyleNumber('min-size',0.75));
   sliderVisible:=(element.sliderEnd>element.sliderStart) and (element.sliderEnd-element.sliderStart<1);

   // Draw
   context:=TContext(element.styleContext);
   sStyle:=element.GetStyleValue('variant','flat');
   col:=element.GetStyleColor('color',$FFA8B0BC); // slider color
   scale:=element.globalScale;

   if SameText(sStyle,'flat') then begin
    // Flat style
    trackWidth:=element.GetStyleNumber('track-width',1);
    sliderWidth:=element.GetStyleNumber('slider-width',0.9);
    sliderRadius:=element.GetStyleNumber('radius',0)*width*sliderWidth;
    // Draw track
    trackColor:=element.GetBaseStyleColor('track-color',Color.Scale(col,0.5));
    trackColor:=Color.Mix(trackColor,element.GetStateStyleColor('hover','track-color',trackColor),context.hover.Value);
    r.Init(x1,y1,x2,y2);
    f:=(1-trackWidth)/2;
    if element.horizontal then begin
     r.y1:=Lerp(y1,y2,f);
     r.y2:=Lerp(y1,y2,1-f);
    end else begin
     r.x1:=Lerp(x1,x2,f);
     r.x2:=Lerp(x1,x2,1-f);
    end;
    draw.FillRect(r.x1,r.y1,r.x2,r.y2,trackColor);

    // Draw slider
    if sliderVisible then begin
     // slider rect
     f:=(1-sliderWidth)/2;
     if element.horizontal then begin
      r.x1:=Lerp(x1,x2,element.sliderStart);
      r.y1:=Lerp(y1,y2,f);
      r.x2:=Lerp(x1,x2,element.sliderEnd);
      r.y2:=Lerp(y1,y2,1-f);
     end else begin
      r.x1:=Lerp(x1,x2,f);
      r.y1:=Lerp(y1,y2,element.sliderStart);
      r.x2:=Lerp(x1,x2,1-f);
      r.y2:=Lerp(y1,y2,element.sliderEnd);
     end;
     // col
     if hooked=element then
      col:=element.GetStyleColor('active-color',Color.Add(col,$404040)) // pressed/dragging
     else if element.sliderUnder then
      col:=element.GetStateStyleColor('hover','color',Color.Add(col,$202020)); // hover col
     if sliderRadius=0 then
      draw.FillRect(r.left,r.top,r.right,r.bottom,col)
     else begin
      r.Round;
      draw.RoundRect(r.left,r.top,r.right,r.bottom,sliderRadius,0,col,col);
     end;
    end;
   end else begin
    // Default (3D) style

    // Draw track
{    c:=colorAdd(col,$202020);
    d:=Color.Sub(col,$202020);
    iwidth:=x2-x1;
    iheight:=y2-y1;
    draw.FillGradrect(x1,y1,x2,y2,d,c,element.horizontal);
    // Draw slider (if needed)

    if element.horizontal then begin
     minWidth:=Max(8,round((y2-y1)*0.75));
     if element.flags.enabled and (iwidth>=minWidth) and (pagesize<max-min) then begin
      v:=colorMix(Color.Add(col,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if sliderUnder and not (hooked=element) then v:=Color.Add(v,$101010);
      i:=round((x2-x1)*(sliderStart/size.x));
      j:=round((x2-x1)*(sliderEnd/size.x));
      if i<0 then i:=0;
      if j>iwidth then j:=iwidth;
      if j>i+6 then begin
       draw.FillGradrect(x1+i,y1,x1+j,y2,colorMix(v,$FFC0E0F0,192),colorMix(v,$FF0000A0,192),true);
       if (hooked=element) then draw.ShadedRect(x1+i,y1,x1+j,y2,1,d,d)
        else draw.ShadedRect(x1+i,y1,x1+j,y2,1,c,d);
       i:=x1+(i+j) div 2;
       draw.ShadedRect(i-2,y1+3,i-1,y2-3,1,d,c);
       draw.ShadedRect(i+1,y1+3,i+2,y2-3,1,d,c);
      end;
     end;
    end else begin
     // Vertical scrollbar
     draw.FillGradrect(x1,y1,x2,y2,d,c,false);
     minWidth:=Max(8,round((x2-x1)*0.75));
     if enabled and (iheight>=minWidth) and (pagesize<max-min) then begin
      v:=colorMix(Color.Add(col,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if sliderUnder and not (hooked=element) then v:=Color.Add(v,$101010);
      i:=round((y2-y1)*(sliderStart/size.y));
      j:=round((y2-y1)*(sliderEnd/size.y));
      if i<0 then i:=0;
      if j>iheight then j:=iheight;
      if j>i+6 then begin
       draw.FillGradrect(x1,y1+i,x2,y1+j,colorMix(v,$FFC0E0F0,192),colorMix(v,$FF0000A0,192),false);
       if (hooked=element) then draw.ShadedRect(x1,y1+i,x2,y1+j,1,d,d)
        else draw.ShadedRect(x1,y1+i,x2,y1+j,1,c,d);
       i:=y1+(i+j) div 2;
       draw.ShadedRect(x1+3,i-2,x2-3,i-1,1,d,c);
       draw.ShadedRect(x1+3,i+1,x2-3,i+2,1,d,c);
      end;
     end;
    end;}
   end;
  end;

 procedure DrawUIEditBox(control:TUIEditBox;x1,y1,x2,y2:integer);
  var
   wst:String32;
   i,j,mY,d,curX,scrollPixels,xStart,prefixWidth,selEndWidth,selX1,selX2,targetX,midX,txtLen:integer;
   font:TFontHandle;
   col:cardinal;
  begin
   font:=control.StyleFont;
   col:=control.GetStyleColor('color',$FF202020);
   with control do begin
    wst:=realtext;
    if password then begin
      SetLength(wst,length(wst));
      for j:=0 to high(wst) do
        wst[j]:=Char32('*');
    end;
    if (scroll.X>0) and (txt.WidthW(font,wst)<(x2-x1)) then Scroll.X:=0;
    gfx.clip.Rect(Rect(x1+2,y1,x2-2,y2));
    my:=round(y1*0.47+y2*0.53+txt.Height(font)*0.4);
    // Default text?
    if realtext.IsEmpty and (not defaultText.IsEmpty) and (FocusedElement<>control) then begin
     txt.WriteW(font,x1+2+offset,mY,Color.Mix(col,$00808080,160),defaultText,taLeft,toDontTranslate);
     gfx.clip.Restore;
     exit;
    end;
    txtLen:=length(wst);
    // Measure full string once and use the same metrics for:
    // caret position, mouse hit-test, and selection bounds.
    if txtLen>0 then
     txt.WriteW(font,0,mY,col,wst,taLeft,toDontTranslate or toDontDraw or toMeasure);

    if needpos>=0 then begin
     targetX:=needPos-3+round(scroll.X);
     cursorpos:=0;
     while cursorpos<txtLen do begin
      midX:=(txt.MeasuredRect(cursorpos).Left+txt.MeasuredRect(cursorpos+1).Left) div 2;
      if targetX<midX then break;
      inc(cursorpos);
     end;
     needpos:=-1;
    end;
    if txtLen=0 then
     i:=0
    else
     i:=txt.MeasuredRect(cursorpos).Left; // caret x in text-local coordinates
    d:=round((y2-y1)*0.15)+8; // left text margin + right padding to keep cursor visible
    if i-scroll.X<0 then scroll.X:=i;
    if i-scroll.X>(x2-x1-d-offset) then scroll.X:=i-(x2-x1-d-offset);
    scrollPixels:=round(scroll.X); // scroll.X is already in screen pixels
    xStart:=x1+round((y2-y1)*0.15)-scrollPixels;
    if not completion.IsEmpty then begin
     j:=xStart+txt.WidthW(font,wst);
     txt.WriteW(font,j+offset,mY,Color.Mix(col,$00808080,160),
       copy(completion,length(wst),length(completion)-length(wst)),taLeft,toDontTranslate);
    end;
    if (selcount>0) and (FocusedElement=control) then begin // part of the text is selected
     j:=xStart+offset;
     if txtLen=0 then begin
      prefixWidth:=0;
      selEndWidth:=0;
     end else begin
      prefixWidth:=txt.MeasuredRect(selstart).Left;
      selEndWidth:=txt.MeasuredRect(selstart+selcount).Left;
     end;
     selX1:=j+prefixWidth;
     selX2:=j+selEndWidth;

     // Draw in three parts, but with x-positions taken from full-string metrics.
     txt.WriteW(font,j,mY,col,copy(wst,0,selstart),taLeft,toDontTranslate);
     d:=selX2-selX1;
     if d>0 then begin
      draw.FillRect(selX1,y1+1,selX2-1,y2-1,$FF4488CC); // selection highlight
      txt.WriteW(font,selX1,mY,$FFFFFFFF,copy(wst,selstart,selcount),taLeft,toDontTranslate);
     end;
     txt.WriteW(font,selX2,mY,col,
       copy(wst,selstart+selcount,length(wst)-selstart-selcount),taLeft,toDontTranslate);
    end else
     txt.WriteW(font,xStart+offset,mY,col,wst,taLeft,toDontTranslate);
    if (FocusedElement=control) and ((CoreTime.Ticks-cursortimer) mod 360<200) then begin // cursor
     curX:=xStart+offset+i-1; // slight visual alignment tweak: 1px to the left
     draw.Line(curX,y1+2,curX,y2-2,Color.Add(col,$404040));
    end;
    gfx.clip.Restore;
   end;
  end;

 procedure DrawUIListBox(control:TUIListBox;x1,y1,x2,y2:integer);
  var
   i,lY:integer;
   c:cardinal;
   scrollPos,lineH:single;
   font:TFontHandle;
  begin
   font:=control.StyleFont;
   with control do begin
     if bgColor<>0 then draw.FillRect(x1,y1,x2,y2,bgColor);
     if scrollerV<>nil then scrollPos:=scrollerV.GetValue*globalScale
      else scrollPos:=0;
      gfx.clip.Rect(Rect(x1,y1,x2+1,y2+1));
      lineH:=lineHeight*globalScale;
      for i:=0 to length(lines)-1 do begin
       lY:=y1+round(i*lineH-scrollPos); /// TODO: check
       if lY+lineH<y1 then continue;
       if lY>y2 then break;
       if i=selectedLine then begin
        draw.FillRect(x1,lY,x2,round(lY+lineH),bgSelColor);
        c:=selTextColor;
       end else
       if i=hoverLine then begin
        draw.FillRect(x1,lY,x2,round(lY+lineH),bgHoverColor);
        c:=hoverTextColor;
       end else
        c:=textColor;
       txt.Write(font,x1+4,lY+round(lineH*0.73),c,lines[i],taLeft,toComplexText);
      end;
     gfx.clip.Restore;
    end;
  end;

 // Table: the box is drawn by the common path. The header in 'header-fill' with captions in
 // 'header-color', the column under the mouse in 'header-hover-fill', a triangle for the sort
 // column and 'line-color' lines; rows striped with 'row-alt-fill', the hovered one in
 // 'row-hover-fill', the selected one in 'selection-fill' with 'selection-color' text
 procedure DrawUITable(table:TUITable);
  var
   r,cell:TRect;
   font:TFontHandle;
   scale,rowH,pos:single;
   textColor,selColor,lineColor,c:cardinal;
   headerBottom,rowsRight,first,place,row,col,y,base,pad,tri,x,cx1,cx2:integer;

  // the columns are clipped by the rows' width (the scrollbar keeps its place)
  function ColumnRect(col:integer;y1,y2:integer):TRect;
   begin
    result.Left:=r.Left+round(table.ColumnLeft(col)*scale);
    result.Right:=Min(rowsRight,r.Left+round((table.ColumnLeft(col)+table.ColumnWidth(col))*scale));
    result.Top:=y1;
    result.Bottom:=y2;
   end;

  procedure WriteCell(const area:TRect;align:TTextAlignment;color:cardinal;const text:String8;
    rightGap:integer);
   begin
    if (text='') or (area.Right-area.Left<=2*pad) then exit;
    gfx.clip.Rect(Rect(area.Left+pad,area.Top,area.Right-pad-rightGap,area.Bottom));
    case align of
     taRight:x:=area.Right-pad-rightGap-1;
     taCenter:x:=(area.Left+area.Right-rightGap) div 2;
     else x:=area.Left+pad;
    end;
    base:=round((area.Top+area.Bottom-1)*0.5+txt.Height(font)*0.45);
    txt.Write(font,x,base,color,text,align);
    gfx.clip.Restore;
   end;

  begin
   font:=table.StyleFont;
   scale:=table.globalScale;
   r:=table.GetClientPosOnScreen;
   textColor:=table.GetStyleColor('color',$FFE0E0E0);
   selColor:=table.GetStyleColor('selection-color',textColor);
   lineColor:=table.GetStyleColor('line-color',$40808080);
   pad:=round(5*scale);
   headerBottom:=r.Top+round(table.headerHeight*scale);
   rowsRight:=r.Left+round(table.RowsWidth*scale);
   gfx.clip.Rect(r);
   // rows
   rowH:=table.rowHeight*scale;
   pos:=table.ScrollPos*scale;
   gfx.clip.Rect(Rect(r.Left,headerBottom,r.Right,r.Bottom));
   if rowH>0 then first:=trunc(pos/rowH) else first:=table.RowCount;
   for place:=first to table.RowCount-1 do begin
    y:=headerBottom+round(place*rowH-pos);
    if y>=r.Bottom then break;
    row:=table.RowAt(place);
    c:=0;
    if row=table.selected then c:=table.GetStyleColor('selection-fill',$90406070)
    else
    if row=table.hoverRow then c:=table.GetStyleColor('row-hover-fill',0)
    else
    if odd(place) then c:=table.GetStyleColor('row-alt-fill',0);
    cell:=Rect(r.Left,y,rowsRight,headerBottom+round((place+1)*rowH-pos));
    if c<>0 then draw.FillRect(cell.Left,cell.Top,cell.Right-1,cell.Bottom-1,c);
    if row=table.selected then c:=selColor else c:=textColor;
    for col:=0 to high(table.columns) do
     WriteCell(ColumnRect(col,cell.Top,cell.Bottom),table.columns[col].align,c,
       table.CellText(row,col),0);
   end;
   gfx.clip.Restore;
   // header
   if headerBottom>r.Top then begin
    c:=table.GetStyleColor('header-fill',0);
    if c<>0 then draw.FillRect(r.Left,r.Top,r.Right-1,headerBottom-1,c);
    c:=table.GetStyleColor('header-color',textColor);
    tri:=round(table.headerHeight*scale*0.18);
    for col:=0 to high(table.columns) do begin
     cell:=ColumnRect(col,r.Top,headerBottom);
     if cell.Right<=cell.Left then continue;
     if col=table.hoverColumn then
      draw.FillRect(cell.Left,cell.Top,cell.Right-1,cell.Bottom-2,table.GetStyleColor('header-hover-fill',0));
     if col=table.sortColumn then begin
      // a triangle at the right edge: up - ascending, down - descending
      cx2:=cell.Right-pad;
      cx1:=cx2-2*tri;
      y:=(cell.Top+cell.Bottom) div 2;
      if table.sortDescending then
       draw.FillTriangle(cx1,y-tri*0.5,cx2,y-tri*0.5,(cx1+cx2)*0.5,y+tri*0.5,c,c,c)
      else
       draw.FillTriangle(cx1,y+tri*0.5,cx2,y+tri*0.5,(cx1+cx2)*0.5,y-tri*0.5,c,c,c);
      WriteCell(cell,table.columns[col].align,c,table.columns[col].caption,2*tri+pad);
     end else
      WriteCell(cell,table.columns[col].align,c,table.columns[col].caption,0);
     if col<high(table.columns) then
      draw.Line(cell.Right-0.5,cell.Top+3*scale,cell.Right-0.5,cell.Bottom-3*scale,lineColor);
    end;
    draw.Line(r.Left,headerBottom-0.5,r.Right,headerBottom-0.5,lineColor);
   end;
   gfx.clip.Restore;
  end;

 procedure DrawUIComboBox(x1,y1,x2,y2:integer;combo:TUIComboBox;context:TContext);
  var
   st:string8;
   i,cx,cy:integer;
   c:cardinal;
   ts:TTextStyle;
  begin
   if (undermouse=combo) or combo.frame.flags.visible then
    draw.FillGradrect(x1+1,y1+1,x2-1,y2-1,$FFFFFFFF,$FFE0E0DC,true)
   else
    draw.FillGradrect(x1+1,y1+1,x2-1,y2-1,$FFE0E0DC,$FFFFFFFF,true);

   draw.RRect(x1,y1,x2,y2,$80000000,1);
   if FocusedElement=combo then
    draw.RRect(x1,y1,x2,y2,$90A00000);
   with combo do begin
    if (length(items)>0) and (curItem>=0) and (curItem<=high(items)) or
       (curItem<0) and (defaultText<>'') then begin
     gfx.clip.Rect(Rect(x1+1,y1+1,x2-21,y2-1));
     if curItem>=0 then st:=items[curItem]
      else st:=defaultText;
     ts:=ResolveTextStyle(combo,context,$FF000000);
     ts.align:=taLeft;
     WriteStyled(ts,x1+5,round(y2*0.7+y1*0.3),st);
     gfx.clip.Restore;
    end;
    // Arrow
    cx:=x2-round((y2-y1)*0.4);
    cy:=(y1+y2) div 2-1;
    c:=$FF000000;
    for i:=0 to 2 do begin
     draw.Line(cx,cy+2+i,cx-4,cy-2+i,c);
     draw.Line(cx,cy+2+i,cx+4,cy-2+i,c);
    end;
   end;
  end;

 // 'box-shadow: <color> [dx dy [blur]]' or 'none'; dx,dy,blur in logical units.
 // The blur is a piecewise linear falloff: full color inside, half at the shifted box edge,
 // zero at blur/2 outside; corners are fans. The core is not filled under the box itself,
 // except a strip of the corner radius - the box covers the rest.
 procedure DrawBoxShadow(element:TUIElement;radius:single);
  const
   CORNER_STEPS=6;
   MAX_VERTICES=2*(4+4*CORNER_STEPS)*6+4*6;
  var
   st:String8;
   parts:Strings8;
   i,n,cnt:integer;
   col,half,none:cardinal;
   dx,dy,blur,b2,scale:single;
   mx1,my1,mx2,my2,ix1,iy1,ix2,iy2,c:single;
   vrt:array[0..MAX_VERTICES-1] of TVertex;
  procedure Add(x,y:single;color:cardinal);
   begin
    vrt[cnt].Init(x,y,0,color);
    inc(cnt);
   end;
  procedure Quad(x1,y1,x2,y2,x3,y3,x4,y4:single;c1,c2:cardinal); // edge 1-2 in c1, 3-4 in c2
   begin
    Add(x1,y1,c1); Add(x2,y2,c1); Add(x3,y3,c2);
    Add(x1,y1,c1); Add(x3,y3,c2); Add(x4,y4,c2);
   end;
  procedure Fill(x1,y1,x2,y2:single);
   begin
    if (x2>x1) and (y2>y1) then Quad(x1,y1,x2,y1,x2,y2,x1,y2,col,col);
   end;
  // A band from distance d1 (color c1) to d2 (color c2) around the core box
  procedure Band(d1,d2:single;c1,c2:cardinal);
   procedure Corner(cx,cy,a:single);
    var
     k:integer;
     a0,a1:single;
    begin
     for k:=0 to CORNER_STEPS-1 do begin
      a0:=a+k*(Pi/2)/CORNER_STEPS;
      a1:=a0+(Pi/2)/CORNER_STEPS;
      Quad(cx+cos(a0)*d1,cy+sin(a0)*d1,cx+cos(a1)*d1,cy+sin(a1)*d1,
           cx+cos(a1)*d2,cy+sin(a1)*d2,cx+cos(a0)*d2,cy+sin(a0)*d2,c1,c2);
     end;
    end;
   begin
    Quad(ix1,iy1-d1,ix2,iy1-d1,ix2,iy1-d2,ix1,iy1-d2,c1,c2); // top
    Quad(ix2+d1,iy1,ix2+d1,iy2,ix2+d2,iy2,ix2+d2,iy1,c1,c2); // right
    Quad(ix2,iy2+d1,ix1,iy2+d1,ix1,iy2+d2,ix2,iy2+d2,c1,c2); // bottom
    Quad(ix1-d1,iy2,ix1-d1,iy1,ix1-d2,iy1,ix1-d2,iy2,c1,c2); // left
    Corner(ix1,iy1,Pi);
    Corner(ix2,iy1,Pi*1.5);
    Corner(ix2,iy2,0);
    Corner(ix1,iy2,Pi*0.5);
   end;
  begin
   st:=element.GetStyleValue('box-shadow');
   if (st='') or SameText(st,'none') then exit;
   parts:=st.Split(' ');
   n:=0;
   for i:=0 to high(parts) do
    if parts[i].Trim<>'' then begin
     parts[n]:=parts[i].Trim; inc(n);
    end;
   col:=ParseStyleColor(ExpandToken(parts[0]));
   if col shr 24=0 then exit;
   scale:=element.globalScale;
   dx:=0; dy:=0; blur:=0;
   if n>=3 then begin
    dx:=ParseStyleNumber(parts[1])*scale;
    dy:=ParseStyleNumber(parts[2])*scale;
   end;
   if n>=4 then blur:=Max(ParseStyleNumber(parts[3])*scale,0);
   half:=(col and $FFFFFF) or ((col shr 25) shl 24);
   none:=col and $FFFFFF;
   // the box in vertex coordinates (pixel edges), the core: the shifted box shrunk by blur/2
   with element.globalRect do begin
    mx1:=Left-0.5; my1:=Top-0.5;
    mx2:=Right-0.5; my2:=Bottom-0.5;
   end;
   b2:=blur/2;
   ix1:=mx1+dx+b2; ix2:=mx2+dx-b2;
   iy1:=my1+dy+b2; iy2:=my2+dy-b2;
   if ix2<ix1 then begin c:=(ix1+ix2)/2; ix1:=c; ix2:=c; end;
   if iy2<iy1 then begin c:=(iy1+iy2)/2; iy1:=c; iy2:=c; end;
   cnt:=0;
   if b2>=0.5 then begin
    Band(0,b2,col,half);
    Band(b2,blur,half,none);
   end;
   // the core minus the box (inset by the radius)
   radius:=radius*scale;
   mx1:=mx1+radius; my1:=my1+radius;
   mx2:=mx2-radius; my2:=my2-radius;
   if (mx2<=ix1) or (mx1>=ix2) or (my2<=iy1) or (my1>=iy2) then
    Fill(ix1,iy1,ix2,iy2)
   else begin
    Fill(ix1,iy1,ix2,my1); // above
    Fill(ix1,my2,ix2,iy2); // below
    Fill(ix1,Max(iy1,my1),mx1,Min(iy2,my2)); // left
    Fill(mx2,Max(iy1,my1),ix2,Min(iy2,my2)); // right
   end;
   if cnt>0 then draw.TrgList(@vrt[0],cnt div 3,nil);
  end;

 // Common box path: fill / background-image, border, radius, inner block.
 // All box keys are state-blended (hover/pressed/disabled) through the context tweenings.
 // Sets context.skinned when a background-image was drawn.
 procedure DrawCommonStyle(element:TUIElement;context:TContext;outerBorder:boolean=false);
  type
   TImageLayer=record
    tex:TTexture;
    tint:cardinal;
    weight:single; // cross-fade weight (alpha multiplier)
   end;
  var
   fillColor,borderColor:cardinal;
   radius,bWidth,scale:single;
   x1,y1,x2,y2:integer;
   hv,av,dv:single;
   isButton:boolean;
   layers:array[0..3] of TImageLayer;
   layerCount:integer;
   baseImage:String8;
   ofsX,ofsY:single;
   stretch,topLeft:boolean;
  procedure ImportRect(r:TRect;expand:single=0);
   var
    d:integer;
   begin
    d:=round(expand);
    x1:=r.Left-d; x2:=r.right-1+d;
    y1:=r.top-d; y2:=r.bottom-1+d;
   end;
  // Blend box colors/metrics toward a state block (fillDef = default fill for the state)
  procedure BlendState(const state:String8;v:single;fillDef:cardinal);
   begin
    if v<=0 then exit;
    fillColor:=Color.Mix(fillColor,element.GetStateStyleColor(state,'fill',fillDef),v);
    borderColor:=Color.Mix(borderColor,element.GetStateStyleColor(state,'border-color',borderColor),v);
    radius:=Lerp(radius,element.GetStateStyleNumber(state,'radius',radius),v);
    bWidth:=Lerp(bWidth,element.GetStateStyleNumber(state,'border-width',bWidth),v);
   end;
  // Blend image offsets toward a state block (logical units)
  procedure BlendOffset(const state:String8;v:single);
   begin
    if v<=0 then exit;
    ofsX:=Lerp(ofsX,element.GetStateStyleNumber(state,'background-offset-x',ofsX),v);
    ofsY:=Lerp(ofsY,element.GetStateStyleNumber(state,'background-offset-y',ofsY),v);
   end;
  // Add a state image layer: same image -> blend tint only, other image -> cross-fade layer
  procedure AddImageState(const state:String8;v:single);
   var
    src:String8;
    tex:TTexture;
    tint:cardinal;
   begin
    // requested even when the state is inactive: preloads it, no file load on the first hover
    src:=element.GetStateStyleValue(state,'background-image',baseImage);
    tex:=context.GetImage(src);
    if (v<=0) or (tex=nil) then exit;
    tint:=element.GetStateStyleColor(state,'background-tint',layers[layerCount-1].tint);
    if tex=layers[layerCount-1].tex then begin
     layers[layerCount-1].tint:=Color.Mix(layers[layerCount-1].tint,tint,v);
     exit;
    end;
    if layerCount>high(layers) then exit;
    layers[layerCount].tex:=tex;
    layers[layerCount].tint:=tint;
    layers[layerCount].weight:=v;
    inc(layerCount);
   end;
  procedure DrawImageLayers;
   var
    i:integer;
    tint:cardinal;
    w,h,cx,cy,dx,dy:single;
   begin
    dx:=ofsX*scale; dy:=ofsY*scale;
    for i:=0 to layerCount-1 do begin
     tint:=layers[i].tint;
     if layers[i].weight<1 then tint:=Color.Scale(tint,layers[i].weight);
     if stretch then
      draw.Scaled(x1-0.5+dx,y1-0.5+dy,x2+0.5+dx,y2+0.5+dy,layers[i].tex,tint)
     else begin
      // auto: native size in logical units (scaled by globalScale), centered by default or anchored at the top left
      w:=layers[i].tex.width*scale; h:=layers[i].tex.height*scale;
      if topLeft then begin
       cx:=x1+dx+w/2; cy:=y1+dy+h/2;
      end else begin
       cx:=(x1+x2+1)/2+dx; cy:=(y1+y2+1)/2+dy;
      end;
      draw.Image(cx-w/2,cy-h/2,scale,layers[i].tex,tint,0,0);
     end;
    end;
   end;
  procedure DrawBlock;
   var
    i,bw:integer;
   begin
    if radius>1 then begin
     if outerBorder then begin
      if fillColor<>0 then
       draw.RoundRect(x1,y1,x2,y2,radius*scale,0,0,fillColor);
      if (borderColor<>0) and (bWidth>0) then
       draw.RoundRect(x1-bWidth*scale,y1-bWidth*scale,x2+bWidth*scale,y2+bWidth*scale,
         (radius+bWidth)*scale,bWidth*scale,borderColor,0);
     end else
      draw.RoundRect(x1,y1,x2,y2,radius*scale,bWidth*scale,borderColor,fillColor);
    end else begin
     if fillColor<>0 then
      draw.FillRect(x1,y1,x2,y2,fillColor);
     if borderColor<>0 then begin
      bw:=round(bWidth*scale);
      if outerBorder then begin
       for i:=0 to bw-1 do
        draw.Rect(x1-1-i,y1-1-i,x2+1+i,y2+1+i,borderColor)
      end else begin
       for i:=0 to bw-1 do
        draw.Rect(x1+i,y1+i,x2-i,y2-i,borderColor)
      end;
     end;
    end;
   end;
  begin
   context.skinned:=false;
   ImportRect(element.globalRect);
   scale:=element.globalScale;
   hv:=context.hover.Value;
   av:=context.active.Value;
   dv:=context.disabled.Value;
   // Plain/toggle buttons (not checkbox/radio/combo) have a default box and derived state colors
   isButton:=(element is TUIButton) and not (element is TUICheckbox) and
     not (element is TUIComboBox) and not (element is TUIMenuItem);

   // Outer block: base values
   if isButton then fillColor:=element.GetBaseStyleColor('fill',defaultBtnColor)
    else fillColor:=element.GetBaseStyleColor('fill');
   borderColor:=element.GetBaseStyleColor('border-color');
   radius:=element.GetBaseStyleNumber('radius');
   bWidth:=element.GetBaseStyleNumber('border-width');
   DrawBoxShadow(element,radius); // under the box

   // Background image: base layer + state layers (cross-fade)
   layerCount:=0;
   baseImage:=element.GetStyleValue('background-image');
   if baseImage<>'' then begin
    layers[0].tex:=context.GetImage(baseImage);
    if layers[0].tex<>nil then begin
     layers[0].tint:=element.GetBaseStyleColor('background-tint',clNeutral);
     layers[0].weight:=1;
     layerCount:=1;
     AddImageState('hover',hv);
     AddImageState('pressed',av);
     AddImageState('disabled',dv);
     stretch:=SameText(element.GetStyleValue('background-size','auto'),'stretch');
     topLeft:=SameText(element.GetStyleValue('background-position','center'),'top-left');
     ofsX:=element.GetBaseStyleNumber('background-offset-x');
     ofsY:=element.GetBaseStyleNumber('background-offset-y');
     BlendOffset('hover',hv);
     BlendOffset('pressed',av);
     BlendOffset('disabled',dv);
    end;
   end;

   if (fillColor=0) and (borderColor=0) and (radius=0) and (bWidth=0) and (layerCount=0) then exit; // nothing to draw

   // State blend: hover -> pressed -> disabled (layered)
   if isButton then begin
    BlendState('hover',hv,Color.Add(fillColor,$101010));
    BlendState('pressed',av,Color.Sub(fillColor,$282020));
    BlendState('disabled',dv,Color.Mix(fillColor,$FFA0A0A0,128));
   end else begin
    BlendState('hover',hv,fillColor);
    BlendState('pressed',av,fillColor);
    BlendState('disabled',dv,fillColor);
   end;

   // This is important for drawing large semi-transparent areas on a transparent background (render to texture)
   // to avoid duplicate alpha blending (resulting in alpha=sqr(alpha))
   if Color.HasAlpha(fillColor) or (layerCount>0) then SetProperBlendMode(element);
   DrawBlock;
   if layerCount>0 then begin
    DrawImageLayers;
    context.skinned:=true;
   end;
   RestoreBlendMode;

   // Inner (client) block
   outerBorder:=false;
   fillColor:=element.GetBaseStyleColor('inner-fill');
   borderColor:=element.GetBaseStyleColor('inner-border-color');
   radius:=element.GetBaseStyleNumber('inner-radius',radius);
   bWidth:=element.GetBaseStyleNumber('inner-border-width',bWidth);
   if (fillColor<>0) or (borderColor<>0) then begin
    ImportRect(element.GetClientPosOnScreen,bWidth*scale);
    DrawBlock;
   end;
  end;

 // Default UI drawer
 procedure DrawDefaultUI(element:TUIElement;drawButtonCaption:boolean);
  var
   x1,y1,x2,y2:integer;
   context:TContext;
  begin
   context:=PrepareContext(element);
   context.Update(element);
   if (element is TUIButton) and not (element is TUICheckbox) and
     not (element is TUIComboBox) and not (element is TUIMenuItem) then begin
    // Buttons use scroll to move all children as a group. Assign absolutely.
    element.scroll.X:=0;
    element.scroll.Y:=-context.active.Value*element.GetStyleNumber('content-press-offset',1);
   end;
   DrawCommonStyle(element,context,element is TUIListBox);

   with element.globalrect do begin
    x1:=Left; x2:=right-1;
    y1:=top; y2:=bottom-1;
   end;

   // Plain container - fill plus frame
   if element.ClassType=TUIElement then
    DrawUIElement(element,x1,y1,x2,y2,context)
   else
   // Label
   if element is TUILabel then
    DrawUILabel(element as TUILabel,x1,y1,x2,y2,context)
   else
   // Button
   if (element is TUIButton) and not (element is TUIToggleButton) and
     not (element is TUIComboBox) and not (element is TUIMenuItem) then
    DrawUIButton(element as TUIButton,x1,y1,x2,y2,context,drawButtonCaption)
   else
   if element is TUICheckbox then
    DrawUICheckbox(element as TUICheckbox,x1,y1,x2,y2)
   else
   // Toggle button (tabs, segmented controls): drawn as a button, toggled=pressed.
   // Checkbox/radio are caught above; combo descends from TUIButton, not from toggle.
   if element is TUIToggleButton then
    DrawUIButton(element as TUIButton,x1,y1,x2,y2,context,drawButtonCaption)
   else
   // Frame
   if element.ClassType=TUIFrame then
    DrawUIFrame(element as TUIFrame,x1,y1,x2,y2)
   else
   // Arbitrary image
   if element.ClassType=TUIImage then
    DrawUIImage(element as TUIImage,x1,y1,x2,y2,context)
   else
   // popup hint
   if element is TUIHint then
    DrawUIHint(element as TUIHint,x1,y1,x2,y2)
   else
   // Window
   if element.ClassType=TUIWindow then
    DrawUIWindow(element as TUIWindow,x1,y1,x2,y2,context)
   else
   // Scrollbar
   if element.ClassType=TUIScrollBar then
    DrawUIScrollbar(element as TUIScrollBar,x1,y1,x2,y2)
   else
   // EditBox
   if element is TUIEditBox then
    DrawUIEditBox(element as TUIEditBox,x1,y1,x2,y2)
   else
   // ListBox
   if element is TUIListBox then
    DrawUIListBox(element as TUIListBox,x1,y1,x2,y2)
   else
   if element is TUITable then
    DrawUITable(element as TUITable)
   else
   // Combo box
   if element is TUIComboBox then
    DrawUIComboBox(x1,y1,x2,y2,element as TUIComboBox,context)
   else
   // Popup menu: the panel is drawn by the common box path
   if element is TUIMenuItem then
    DrawUIMenuItem(element as TUIMenuItem,context)
   else
   if element is TUIMenuSeparator then
    DrawUIMenuSeparator(element as TUIMenuSeparator,x1,y1,x2,y2);
   {else
    DrawUIElement(element,x1,y1,x2,y2);}
  end;

 procedure DefaultDrawer(element:TUIElement);
  begin
   DrawDefaultUI(element);
  end;

 function ResolveUITextStyle(element:TUIElement;defColor:cardinal;
   defAlign:TTextAlignment;defOptions:cardinal;
   defHoverColor:cardinal;defDisabledColor:cardinal;defPressOfsY:single):TUITextStyle;
  var context:TContext; temporary:boolean;
  begin
   // Reading parent text must not destroy another drawer's private context.
   temporary:=(element.styleContext<>nil) and not (element.styleContext is TContext);
   if temporary then context:=TContext.Create(element)
    else context:=PrepareContext(element);
   try
    context.Update(element);
    result:=ResolveTextStyle(element,context,defColor,defAlign,defOptions,
      defHoverColor,defDisabledColor,defPressOfsY);
   finally
    if temporary then context.Free;
   end;
  end;

 procedure WriteUIText(const style:TUITextStyle;x,y:single;const text:String8;targetWidth:integer);
  begin
   WriteStyled(style,x,y,text,targetWidth);
  end;

{ TContext }

destructor TContext.Destroy;
 var
  i:integer;
 begin
  for i:=0 to high(imgTex) do FreeImage(imgTex[i]);
  hover.Free;
  active.Free;
  disabled.Free;
  inherited;
 end;

constructor TContext.Create(element:TUIElement);
 var
  v:integer;
 begin
  if element.IsEnabled then v:=0 else v:=1;
  disabled.Assign(v);
  hover.Assign(ord(element.IsHovered));
  v:=0;
  if element is TUIButton then
   if TUIButton(element).pressed then v:=1;
  if element is TUIToggleButton then
   if TUIToggleButton(element).toggled then v:=1;
  active.Assign(v);
 end;

procedure TContext.Update(element:TUIElement);
 var
  v,duration:integer;
 begin
  // Mouse hover state
  v:=ord(element.IsHovered);
  if hover.FinalValue<>v then begin
   if v=1 then duration:=120 else duration:=80; // default
   duration:=element.GetStyleInt('hover-time',duration);
   if v=1 then duration:=element.GetStyleInt('hover-time-in',duration)
    else duration:=element.GetStyleInt('hover-time-out',duration);
   hover.Animate(v,duration);
  end;
  // sync hover state to element.style for CSS :hover blocks
  element.SetState('hover',v=1);

  // Click/toggle state
  v:=0;
  if element is TUIButton then
   if TUIButton(element).pressed then v:=1;
  if element is TUIToggleButton then
   if TUIToggleButton(element).toggled then v:=1;
  if active.FinalValue<>v then begin
   if v=1 then duration:=120 else duration:=80;
   duration:=element.GetStyleInt('press-time',duration);
   if v=0 then duration:=element.GetStyleInt('release-time',duration);
   active.Animate(v,duration);
  end;
  // sync pressed/toggled state
  element.SetState('pressed',v=1);

  // Disabled state
  if element.IsEnabled then v:=0 else v:=1;
  if disabled.FinalValue<>v then begin
   duration:=element.GetStyleInt('disable-time',0);
   if v=0 then duration:=element.GetStyleInt('enable-time',duration);
   disabled.Animate(v,duration);
  end;
  // sync disabled state
  element.SetState('disabled',v=1);
  // Keyboard focus (no tweening: ':focused' blocks switch instantly)
  element.SetState('focused',FocusedElement=element);
 end;

function TContext.GetImage(const src:String8):TTexture;
 var
  i,n:integer;
 begin
  if not src.StartsWith('file:',true) then exit(ResolveStyleImage(src)); // weak reference, no memo
  for i:=0 to high(imgSrc) do
   if imgSrc[i]=src then exit(imgTex[i]);
  result:=ResolveStyleImage(src);
  if result=nil then exit; // not available yet: retry next frame
  n:=length(imgSrc);
  SetLength(imgSrc,n+1);
  SetLength(imgTex,n+1);
  imgSrc[n]:=src;
  imgTex[n]:=result;
 end;

initialization
 RegisterUIStyle(0,DefaultDrawer,'Default');
 TUIEditBox.SetDefault('styleInfo','border-width:1; radius:3; border-color:8000; fill:8FFF');
 TUIPopupMenu.SetDefault('styleInfo','fill:&surface-alt; border-color:&border-dark; border-width:1; radius:3; '+
   'color:&text; box-shadow:&shadow 2 3 4');
 TUIMenuItem.SetDefault('styleInfo','radius:2; hover-time:0; '+
   ':hover { fill:&accent; color:&accent-text; } :disabled { color:&text-muted; }');
 TUIMenuSeparator.SetDefault('styleInfo','line-color:&border-dark');
 TUITable.SetDefault('styleInfo','fill:&surface; border-color:&border-dark; border-width:1; '+
   'color:&text; header-fill:&surface-alt; header-hover-fill:&overlay; line-color:&border-dark; '+
   'row-alt-fill:$0C808080; row-hover-fill:$20808080; selection-fill:&accent; selection-color:&accent-text');
end.

