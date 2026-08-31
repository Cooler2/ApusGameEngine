// Default UI style (0) inspired by CSS
//
// Copyright (C) 2022 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.DefaultStyle;
interface
uses Apus.Engine.UI;
 var
  defaultBtnColor:cardinal=$FFB0A0C0;

implementation
 uses Apus.Types, Apus.Images, SysUtils, Types, Apus.Core, Apus.Tweenings,
    Apus.Colors, Apus.EventMan, Apus.Geom2D,
    Apus.Engine.Types, Apus.Engine.API, Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.UIRender,
    Apus.Lib, Apus.Utils, Apus.Strings;

 var
  hintImage,tickImage:TTexture;
  //imgHash:TObjectMap;  // hash of loaded images: filename -> TTexture

  blendModeChanged:boolean;

 type
  TContext=class
   disabled:TTweening;
   hover:TTweening;
   active:TTweening;
   destructor Destroy; override;
   constructor Create(element:TUIElement);
   procedure Update(element:TUIElement);
   function HoverState(element:TUIElement):byte;
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


 // Get font handle from element's style cascade
 function StyleFont(element:TUIElement):TFontHandle;
  var name:String8; size:single;
  begin
   name:=element.GetStyleValue('font','Default');
   size:=element.GetStyleNumber('font-size',9);
   result:=txt.GetFont(name,round(size*element.globalScale));
  end;

 procedure DrawUIElement(element:TUIElement;x1,y1,x2,y2:integer);
  var
   color:cardinal;
  begin
   if (element.caption<>'') and (element.ClassType=TUIElement) then begin
    color:=element.GetStyleColor('color',$FF808080);
    txt.WriteW(StyleFont(element),(x1+x2)/2,(y1+y2)/2,color,Str32(element.caption),taCenter,toWithShadow);
   end;
  end;

 procedure BuildSimpleHint(hnt:TUIHint);
  var
   lines:Strings8;
   i,h,iWidth,iHeight,dw,lw:integer;
   font:TFontHandle;
  begin
   font:=StyleFont(hnt);
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
     gfx.target.Mask(true,true); // потенциально может вредить отрисовке следующих элементов
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
      // уточнить положение на экране (чтобы всегда был виден)
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

 procedure DrawUILabel(control:TUILabel;x1,y1,x2,y2:integer);
  var
   mY:integer;
   wst:String32;
   bg:cardinal;
   r:TRect;
   font:TFontHandle;
   color:cardinal;
  begin
   font:=StyleFont(control);
   color:=control.GetStyleColor('color',$FF808080);
   with control do begin
     if autoSize then begin

     end;
     r:=GetClientPosOnScreen;
     gfx.clip.Rect(r);
     //mY:=round(y1*0.3+y2*0.7)-topOffset;
     mY:=round((r.top+r.bottom)*0.5+txt.Height(font)*0.45)-verticalOffset;
     wst:=Str32(caption);
     if align=taLeft then
      txt.WriteW(font,r.left,mY,color,wst);
     if align=taRight then
      txt.WriteW(font,r.Right-1,mY,color,wst,taRight);
     if align=taCenter then
      txt.WriteW(font,(r.left+r.right)/2,mY,color,wst,taCenter);
     if align=taJustify then
      txt.WriteW(font,r.left,mY,color,wst,taJustify,0,r.Width);
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
   duration:integer;
   col,vColor,captionColor:cardinal;
   font:TFontHandle;
   d,y,yy,fontH,size:integer;
   v,ss,tt,alpha:single;
   context:TContext;
   inTransition:boolean;
  begin
   context:=element.styleContext as TContext;

   col:=element.GetStyleColor('border-color',$FF808080); // box outline
   captionColor:=element.GetStyleColor('color',col);
   font:=StyleFont(element);
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
   txt.Write(font,x1,y,captionColor,element.caption);
   gfx.clip.Restore;
   if FocusedElement=element then
     draw.Rect(x1,y1,x2,y2,col xor $808080);
  end;

 procedure DrawUIButton(control:TUIButton;x1,y1,x2,y2:integer;context:TContext);
  var
   mY:integer;
   c,c2,baseC,textBaseC:cardinal;
   d:integer;
   hv,av,dv:single;
   wst:String32;
   font:TFontHandle;
  begin
   font:=StyleFont(control);
   with control do begin
      hv:=context.hover.Value;
      av:=context.active.Value;
      dv:=context.disabled.Value;

      // box color ('fill'): base → hover → pressed (layered)
      baseC:=control.GetBaseStyleColor('fill',defaultBtnColor);
      c:=Color.Mix(baseC,control.style.GetStateColor('hover','fill',Color.Add(baseC,$101010)),hv);
      c:=Color.Mix(c,control.style.GetStateColor('pressed','fill',Color.Sub(baseC,$282020)),av);
      if dv>0 then
       c:=Color.Mix(c,control.style.GetStateColor('disabled','fill',Color.Mix(baseC,$FFA0A0A0,128)),dv);

      d:=round(av);
      draw.FillGradRect(x1+1,y1+1,x2-1,y2-1,Color.Add(c,$303030),Color.Sub(c,$303030),true);
      c:=control.GetBaseStyleColor('border-light',$60000000);
      c2:=control.GetBaseStyleColor('border-dark',$80FFFFFF);
      draw.ShadedRect(x1,y1,x2,y2,1,c,c2); // outer frame
      if av>=1 then { pressed, no inner frame }
       else if dv<1 then begin // enabled
         c:=Color.Mix(control.GetBaseStyleColor('border-light',$A0FFFFFF),
                      control.style.GetStateColor('hover','border-light',$A0FFFFFF),hv);
         c2:=Color.Mix(control.GetBaseStyleColor('border-dark',$70000000),
                       control.style.GetStateColor('hover','border-dark',$70000000),hv);
         draw.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,c,c2);
       end else begin // disabled
         c:=control.style.GetStateColor('disabled','border-light',$A0FFFFFF);
         c2:=control.style.GetStateColor('disabled','border-dark',$70000000);
         draw.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,c,c2);
       end;
      // focus ring
      if (FocusedElement=control) or
         (default and ((FocusedElement=nil) or not (FocusedElement is TUIButton))) then
       draw.Rect(x1-1,y1-1,x2+1,y2+1,$80FFFF80);
      // caption
      if caption<>'' then begin
       gfx.clip.Rect(Rect(x1+2,y1+2,x2-2,y2-2));
       textBaseC:=control.GetBaseStyleColor('color',clBlack);
       c:=Color.Mix(textBaseC,control.style.GetStateColor('hover','color',$FF300000),hv);
       if dv>0 then
        c:=Color.Mix(c,control.style.GetStateColor('disabled','color',$80000000),dv);
       mY:=round((y1+y2)*0.5+txt.Height(font)*0.45);
       wSt:=Str32(caption);
       if dv<1 then
        txt.WriteW(font,(x1+x2)/2,mY+d,c,wst,taCenter)
       else begin
        txt.WriteW(font,(x1+x2)/2+1,mY+1,$E0FFFFFF,wSt,taCenter);
        txt.WriteW(font,(x1+x2)/2,mY,$80000000,wSt,taCenter);
       end;
       gfx.clip.Restore;
      end;
    end;
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

 procedure DrawUIImage(control:TUIImage;x1,y1,x2,y2:integer);
  type
   TImageDrawProc=procedure(img:TUIImage);
  var
   img:THandle;
   lname:string;
   p:int64;
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
      // SRC = texture name?
      tex:=nil;
      if src.StartsWith('tex:',true) then begin
       tex:=TTexture(TTexture.FindByName(copy(src,5,200)));
      end else
      if src.StartsWith('file:',true) then begin
       // SRC = filename?
       lname:=Files.FixName(copy(src,6,200));
       tex:=TTexture.FindByFile(lName);
       if tex=nil then
        LoadImage(tex,lname); //
      end else
       raise EWarning.Create('Unsupported image SRC type: '+src);
      if tex<>nil then begin
       draw.Scaled(x1,y1,x2-1,y2-1,tex,control.GetStyleColor('tint',clWhite));
      end;
     end;
    end;
  end;

/// TODO: rework window rendering using common style
 procedure DrawUIWindow(element:TUIWindow;x1,y1,x2,y2:integer);
  var
   c:cardinal;
   tx,ty:integer;
   col:cardinal;
   font:TFontHandle;
  begin
   col:=element.GetStyleColor('fill',$FFB0B0C0);
   font:=StyleFont(element);
   with element do begin
    // body: the common box path already drew 'fill' when the style defines it;
    // draw the default body only for a style without 'fill' (avoids double blending)
    if element.GetStyleValue('fill')='' then draw.FillRect(x1,y1,x2,y2,col);
    if element.IsActiveWindow then c:=$FF8080E0 // текущее окно
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
    tx:=(x1+x2) div 2;
    ty:=y1+round(header*0.7);
    txt.Write(font,tx+1,ty+1,$B0000000,caption,taCenter);
    txt.Write(font,tx,ty,$FFFFFFD0,caption,taCenter);
    gfx.clip.Restore;
   end;
  end;

 procedure DrawUIScrollbar(element:TUIScrollbar;x1,y1,x2,y2:integer);
  var
   c,d,v,col,trackColor:cardinal;
   size,width,startPos,endPos,minSize:integer;
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
    trackColor:=Color.Mix(trackColor,element.style.GetStateColor('hover','track-color',trackColor),context.hover.Value);
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
      col:=element.style.GetStateColor('hover','color',Color.Add(col,$202020)); // hover col
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
   c:cardinal;
   font:TFontHandle;
   col:cardinal;
  begin
   font:=StyleFont(control);
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
    if (selcount>0) and (FocusedElement=control) then begin // часть текста выделена
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
   c,c1,c2:cardinal;
   scrollPos,lineH:single;
   font:TFontHandle;
  begin
   font:=StyleFont(control);
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

 procedure DrawUIComboBox(x1,y1,x2,y2:integer;combo:TUIComboBox);
  var
   st:string8;
   i,cx,cy:integer;
   c:cardinal;
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
     txt.Write(StyleFont(combo),x1+5,round(y2*0.7+y1*0.3),$FF000000,st);
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

 procedure DrawCommonStyle(element:TUIElement;context:TContext;outerBorder:boolean=false);
  var
   fillColor,borderColor:cardinal;
   radius,bWidth,scale:single;
   x1,y1,x2,y2:integer;
   v:single;
  procedure ImportRect(r:TRect;expand:single=0);
   var
    d:integer;
   begin
    d:=round(expand);
    x1:=r.Left-d; x2:=r.right-1+d;
    y1:=r.top-d; y2:=r.bottom-1+d;
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
   ImportRect(element.globalRect);
   scale:=element.globalScale;
   // Outer block: base values
   fillColor:=element.GetBaseStyleColor('fill');
   borderColor:=element.GetBaseStyleColor('border-color');
   radius:=element.GetBaseStyleNumber('radius');
   bWidth:=element.GetBaseStyleNumber('border-width');

   if (fillColor=0) and (borderColor=0) and (radius=0) and (bWidth=0) then exit; // nothing to draw

   // hover blend
   v:=context.hover.Value;
   if v>0 then begin
    fillColor:=Color.Mix(fillColor,element.style.GetStateColor('hover','fill',fillColor),v);
    borderColor:=Color.Mix(borderColor,element.style.GetStateColor('hover','border-color',borderColor),v);
    radius:=Lerp(radius,element.style.GetStateNumber('hover','radius',radius),v);
    bWidth:=Lerp(bWidth,element.style.GetStateNumber('hover','border-width',bWidth),v);
   end;

   // This is important for drawing large semi-transparent areas on a transparent background (render to texture)
   // to avoid duplicate alpha blending (resulting in alpha=sqr(alpha))
   if Color.HasAlpha(fillColor) then SetProperBlendMode(element);
   DrawBlock;
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

 // Отрисовщик по умолчанию
 procedure DefaultDrawer(element:TUIElement);
  var
   x1,y1,x2,y2:integer;
   context:TContext;
  begin
   context:=PrepareContext(element);
   context.Update(element);
   // Plain/toggle buttons own their box (fill+bevel) — skipping the common box path
   // avoids double-blending translucent fills. Unifying both is the B-16 box-path step.
   if not ((element.ClassType=TUIButton) or (element is TUIToggleButton)) or (element is TUICheckbox) then
    DrawCommonStyle(element,context,element is TUIListBox);

   with element.globalrect do begin
    x1:=Left; x2:=right-1;
    y1:=top; y2:=bottom-1;
   end;

   // Просто контейнер - заливка плюс рамка
   if element.ClassType=TUIElement then
    DrawUIElement(element,x1,y1,x2,y2)
   else
   // Надпись
   if element is TUILabel then
    DrawUILabel(element as TUILabel,x1,y1,x2,y2)
   else
   // Кнопка
   if element.ClassType=TUIButton then
    DrawUIButton(element as TUIButton,x1,y1,x2,y2,context)
   else
   if element is TUICheckbox then
    DrawUICheckbox(element as TUICheckbox,x1,y1,x2,y2)
   else
   // Toggle button (tabs, segmented controls): drawn as a button, toggled=pressed.
   // Checkbox/radio are caught above; combo descends from TUIButton, not from toggle.
   if element is TUIToggleButton then
    DrawUIButton(element as TUIButton,x1,y1,x2,y2,context)
   else
   // Рамка
   if element.ClassType=TUIFrame then
    DrawUIFrame(element as TUIFrame,x1,y1,x2,y2)
   else
   // Произвольное изображение
   if element.ClassType=TUIImage then
    DrawUIImage(element as TUIImage,x1,y1,x2,y2)
   else
   // всплывающий хинт
   if element is TUIHint then
    DrawUIHint(element as TUIHint,x1,y1,x2,y2)
   else
   // Window
   if element.ClassType=TUIWindow then
    DrawUIWindow(element as TUIWindow,x1,y1,x2,y2)
   else
   // Scrollbar
   if element.ClassType=TUIScrollBar then
    DrawUIScrollbar(element as TUIScrollBar,x1,y1,x2,y2)
   else
   // EditBox
   if element.ClassType=TUIEditBox then
    DrawUIEditBox(element as TUIEditBox,x1,y1,x2,y2)
   else
   // ListBox
   if element is TUIListBox then
    DrawUIListBox(element as TUIListBox,x1,y1,x2,y2)
   else
   // Combo box
   if element is TUIComboBox then
    DrawUIComboBox(x1,y1,x2,y2,element as TUIComboBox);
   {else
    DrawUIElement(element,x1,y1,x2,y2);}
  end;

{ TContext }

destructor TContext.Destroy;
 begin
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
  hover.Assign(HoverState(element));
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
  v:=HoverState(element);
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
 end;

function TContext.HoverState(element:TUIElement):byte;
 var
  hoverEl:TUIElement;
 begin
  hoverEl:=element;
  if SameText(element.GetStyleValue('hover-target'),'parent') and (element.parent<>nil) then
   hoverEl:=element.parent;
  if (underMouse=hoverEl) or hoverEl.HasChild(underMouse) then result:=1
   else result:=0;
 end;

initialization
 RegisterUIStyle(0,DefaultDrawer,'Default');
 TUIEditBox.SetDefault('styleInfo','border-width:1; radius:3; border-color:8000; fill:8FFF');
end.

