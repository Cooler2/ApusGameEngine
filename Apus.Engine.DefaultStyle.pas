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
  supportOldStyles:boolean=true;

implementation
 uses Apus.Types, Apus.Images, SysUtils, Types, Apus.Common, Apus.AnimatedValues,
    Apus.Colors, Apus.Structs, Apus.EventMan, Apus.Geom2D,
    Apus.Engine.Types, Apus.Engine.API, Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.UIRender;

 type
  TAttributeType=(atColor,atNumber,atString);

  TAttribute=record
   name:string;
   aType:TAttributeType;
  end;

  TElementStyle=record
   fastHash:cardinal;
   fullStyleInfo:String8; // element's original style text
   lastUsed:int64;
   attributes:TVarHash;
   procedure Parse;
   function HasAttr(name:string8):boolean; inline;
   function GetColor(name:string8;default:cardinal=0):cardinal; inline;
   function GetInt(name:string8;default:integer=0):integer; inline;
   function GetNumber(name:string8;default:single=0):single; inline;
   function GetScaled(element:TUIElement;name:string8;default:single=0):single;  inline;
   function GetString(name:string8;default:string8=''):string8; inline;
  private
   function GetAttr(name:string8;default:variant):variant;
   function ActualStyleInfo:string8;
  end;
  PElementStyle=^TElementStyle;

 const
  // All non-string attributes must be listed here
  attribList:array[0..3] of TAttribute=(
    (name:'fill'; aType:atColor),
    (name:'bordercolor'; aType:atColor),
    (name:'innerfill'; aType:atColor),
    (name:'innerborder'; aType:atColor)
   );
 var
  styles:array[0..127] of TElementStyle;
  maxStyle:integer; // max index of used style entry
  //styleHash:TSimpleHash; // element pointer -> style index (may contain outdated values)

  hintImage,tickImage:TTexture;
  imgHash:TSimpleHashS;  // hash of loaded images: filename -> UIntPtr(TTexture)

  blendModeChanged:boolean;

 type
  TContext=class
   disabled:TAnimatedValue;
   hover:TAnimatedValue;
   active:TAnimatedValue;
   constructor Create(element:TUIElement;style:PElementStyle);
   procedure Update(element:TUIElement;style:PElementStyle);
   function HoverState(element:TUIElement;style:PElementStyle):byte;
  end;

 function PrepareContext(element:TUIElement;style:PElementStyle):TContext;
  begin
   if element.styleContext<>nil then begin
    if element.styleContext is TContext then exit(TContext(element.styleContext));
    element.StyleContext.Free;
   end;
   result:=TContext.Create(element,style);
   element.styleContext:=result;
  end;

 procedure SetProperBlendMode(element:TUIElement);
  begin
   if transpBgnd and (element.shape<>shapeEmpty) then begin
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

{ function GetStyleNumber(name:string8;style:PElementStyle;context:TContext;default:single;defaultOver):single;
  var
   normValue,:single;
  begin
   normValue:=style.GetNumber(name,default);
   if CurValue(context.active)>0 then begin

   end;
   if CurValue(context.disabled)>0 then begin

   end else begin

   end;
  end;}

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

 // Creates a style entry for the element, returns its index
 function CreateStyleEntry(element:TUIElement):integer;
  var
   i,best:integer;
   min:int64;
  begin
   min:=MAX_INT64;
   for i:=0 to high(styles) do
    if styles[i].fullStyleInfo='' then begin
      if i>maxStyle then maxStyle:=i;
      best:=i; min:=0;
      break;
     end else begin
      if styles[i].lastUsed<min then begin
       min:=styles[i].lastUsed; best:=i;
      end;
     end;
   ASSERT(min<MAX_INT64);
   styles[best].fullStyleInfo:=element.styleInfo;
   styles[best].fastHash:=FastHash(styles[best].fullStyleInfo);
   styles[best].Parse;
   result:=best;
  end;

 function GetElementStyle(element:TUIElement):PElementStyle;
  var
   i,idx:integer;
   fHash:cardinal;
  begin
   idx:=-1;
   if element.styleInfo='' then exit(nil);
   fHash:=FastHash(element.styleInfo);
   for i:=0 to maxStyle do
    if styles[i].fastHash=fHash then
     if SameText(styles[i].fullStyleInfo,element.styleInfo) then begin
      idx:=i; break;
     end;
   if idx<0 then idx:=CreateStyleEntry(element);
   styles[idx].lastUsed:=game.frameStartTime;
   result:=@styles[idx];
  end;

 procedure DrawUIElement(element:TUIElement;x1,y1,x2,y2:integer);
  var
   color:cardinal;
  begin
   if (element.caption<>'') and (element.ClassType=TUIElement) then begin
    color:=element.color;
    if color=clDefault then color:=$FF808080;
    txt.WriteW(element.font,(x1+x2)/2,(y1+y2)/2,color,Str16(element.caption),taCenter,toWithShadow);
   end;
  end;

 procedure BuildSimpleHint(hnt:TUIHint);
  var
   sa:StringArr;
   wsa:WStringArr;
   i,h,iWidth,iHeight,dw:integer;
  begin
   with hnt do begin
    hnt.simpleText:=StringReplace(hnt.simpleText,'~','\n',[rfReplaceAll]);
    sa:=split('\n',hnt.simpleText,'"');
    wsa:=DecodeUTF8A(sa);
    if font=0 then font:=defaultHintFont;
    if font=0 then font:=txt.GetFont('Default',7);
    h:=round(txt.Height(font)*1.5);
    iHeight:=h*length(sa)+9;
    iWidth:=0;
    for i:=1 to length(sa) do
     if iWidth<txt.WidthW(font,wsa[i-1]) then
      iWidth:=txt.WidthW(font,wsa[i-1]);
    dw:=txt.WidthW(font,'M');
    inc(iWidth,4+dw);
    if (hintImage=nil) or (hintImage.width<>iWidth) or (hintImage.height<>iHeight) then begin
     LogMessage('[Re]alloc hint image');
     if HintImage<>nil then FreeImage(HintImage);
     hintImage:=AllocImage(iWidth,iHeight,pfRenderTargetAlpha,aiTexture+aiRenderTarget,'UI_HintImage');
     if hintImage=nil then
       raise EError.Create('Failed to alloc hint image!');
    end;
    size:=Point2s(iWidth/globalScale,iHeight/globalScale);
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
     for i:=0 to length(sa)-1 do
      txt.WriteW(font,1+dw div 2,round(2+h div 7+(i+0.75)*h),$D0000000,wsa[i]);
    finally
     gfx.EndPaint;
    end;
   end;
  end;

 procedure AdjustHint(sx,sy:integer;hnt:TUIHint);
  var
   xx1,xx2,sc:single;
   pnt:TPoint2s;
  begin
   with hnt do begin
    adjusted:=true;
    pnt.x:=sx+size.x*globalscale; // right side in screen coordinates
    if pnt.x>game.renderWidth then begin
     pnt.x:=sx;
     pnt:=GetRoot.TransformTo(pnt,parent); // transform from screen to parent space
     position.x:=pnt.x;
    end else
     position.x:=position.x+4;

{    sc:=globalscale;
    xx1:=sx;
    xx2:=size.x*globalscale;
    xx1:=xx1+xx2;
    if sx+size.x*globalscale+2<game.renderWidth then position.x:=position.x+4
     else position.x:=position.x-(sx+size.x*globalscale-game.renderWidth)/globalscale;}

    {if sy+size.y*2+4>game.renderHeight then position.y:=position.y-(size.y+4)
     else position.y:=position.y+10+game.renderHeight div 60;  dd }
   end;
  end;

 procedure DrawUIHint(control:TUIHint;x1,y1,x2,y2:integer);
  var
   v:integer;
   c:cardinal;
   savePos:TPoint2s;
  begin
    with control as TUIHint do begin
     if pfRenderTargetAlpha=ipfNone then exit;
     if not adjusted then begin
      // нужно провести инициализацию
      ForceLogMessage('InitHint '+inttohex(cardinal(control),8));
      if not active then try
       BuildSimpleHint(control as TUIHint);
      except
       on e:exception do begin
        LogMessage('Failed to build simple hint - deleted');
        control.visible:=false;
        exit;
       end;
      end;
      // уточнить положение на экране (чтобы всегда был виден)
      savePos:=position;
      AdjustHint(x1,y1,control as TUIHint);
      VectSub(savePos,position);
      inc(x1,round(savepos.x));
      inc(y1,round(savepos.y));
      control.globalRect:=control.GetPosOnScreen;
      x1:=control.globalRect.Left;
      y1:=control.globalRect.Top;
     end;
     if not hiding then
      v:=(MyTickCount-created)*2
     else begin
      v:=256-(MyTickCount-created) div 2;
      if v<=0 then begin
        LogMessage('Hide expired hint '+inttohex(cardinal(control),8));
        {FreeImage(HintImage);
        HintImage:=nil;}
        control.visible:=false;
        exit;
      end;
     end;
     if hintImage=nil then begin
      ForceLogMessage('Hint has no image! '+inttohex(cardinal(control),8));
      exit;
     end;
     if v>256 then v:=256;
     c:=ColorAlpha(clNeutral,v/256);
     gfx.clip.Nothing;
     draw.Image(x1,y1,HintImage,c);
     gfx.clip.Restore;
    end;
  end;

 procedure DrawUILabel(control:TUILabel;x1,y1,x2,y2:integer);
  var
   mY:integer;
   wst:WideString;
   bg:cardinal;
   r:TRect;
  begin
    with control do begin
     if autoSize then begin

     end;
     r:=GetClientPosOnScreen;
     gfx.clip.Rect(r);
     //mY:=round(y1*0.3+y2*0.7)-topOffset;
     mY:=round((r.top+r.bottom)*0.5+txt.Height(font)*0.45)-verticalOffset;
     wst:=DecodeUTF8(caption);
     if align=taLeft then
      txt.WriteW(font,r.left,mY,color,wst);
     if align=taRight then
      txt.WriteW(font,r.Right,mY,color,wst,taRight);
     if align=taCenter then
      txt.WriteW(font,(r.left+r.right)/2,mY,color,wst,taCenter);
     if align=taJustify then
      txt.WriteW(font,r.left,mY,color,wst,taJustify,0,r.Width);
     gfx.clip.Restore;
    end;
  end;

 procedure DrawUICheckbox(element:TUICheckbox;eStyle:PElementStyle;x1,y1,x2,y2:integer);
  const
   TICK_IMAGE = '20 1F ((((~SSS(SSS^SSSESSSDSSS_SSSBSSS &A(*-+&@(*+$&>(%$)*&=(*-$)*&=(*+$+*&=(*+$+*&=(*$)+*&<(%&()*'+
    '&<(*-&()*&<(*,&()/*&;(*-&(),*&<(*&()-*&<(*&().*&<(*+&()*&<(*+&()*&1(&(*&+(*.&(),*&0(*/++,*&)(*,&()+*&0(*-&().*'+
    '&((*&))*&1(.&*)/*#*+&(),*&1(*+&))+*(*-&().*&3(*+&)),%&))*&5(*&*)*&)),*&5(*,&))+&()+*&7(*&.)/*&7(*,&,).*&9(*&,)*'+
    '&:(*,&*)!\SSS*&;(*&))+*&<(*.$)-*&>(*$-*&?(*.%&:(';
  var
   duration:integer;
   color,vColor:cardinal;
   font:TFontHandle;
   d,y,yy,fontH,size:integer;
   v,ss,tt,alpha:single;
   context:TContext;
   inTransition:boolean;
  begin
   context:=element.styleContext as TContext;

   color:=element.color;
   font:=element.font;
   fontH:=txt.Height(font);
   y:=y2-round((y2-y1+1-fontH)/2);
   size:=round(fontH*1.2);
   inc(x1,round(size*0.3));
   d:=round(size*0.15);
   //
   inTransition:=context.active.IsAnimating(game.frameStartTime);
   if element.classType=TUICheckBox then begin
    vColor:=eStyle.GetColor('tick-color',color);
    draw.RoundRect(x1,y-size+d,x1+size,y+d,size*0.24,element.globalScale,vColor,0);
    if tickImage=nil then tickImage:=CreateImageFrom(TICK_IMAGE,1);
    if element.checked or inTransition then begin
     alpha:=1; ss:=1.1;
     if inTransition then begin // transition
      tt:=CurValue(context.active);
      if context.active.FinalValue=1 then begin
       // appear
       alpha:=splines.easeOut(tt,0,1,0.5,1);
       ss:=Spline(tt, 0.5,3, 1.1,-1);
      end else begin
       // dissolve
       alpha:=tt;
      end;
     end;
     draw.Centered(x1+size*0.65,y-size*0.4,ss*size/tickImage.height,tickImage,ColorAlpha(vColor,alpha));
    end;
   end;
   if element.ClassType=TUIRadioButton then begin
    yy:=y-size+d;
    draw.RoundRect(x1,yy,x1+size,yy+size,size*0.5+1,element.globalScale,color,0);
    if element.checked or inTransition then begin
     alpha:=1;
     v:=size*0.24;
     if inTransition then begin // transition
      tt:=CurValue(context.active);
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
     vColor:=ColorAlpha(color,alpha);
     draw.RoundRect(x1+v,yy+v,x1+size-v,yy+size-v,size*0.5+1-v,1,vColor,vColor);
    end;
   end;
   // Caption
   inc(x1,round(size*1.5));
   gfx.clip.Rect(Rect(x1,y1,x2,y2));
   txt.WriteW(font,x1,y,color,element.caption);
   gfx.clip.Restore;
   if FocusedElement=element then
     draw.Rect(x1,y1,x2,y2,color xor $808080);
  end;

 procedure DrawUIButton(control:TUIButton;eStyle:PElementStyle;x1,y1,x2,y2:integer);
  var
   v,mY:integer;
   c,c2:cardinal;
   d:integer;
   wst:WideString;
  begin
    with control do begin
      // обычная кнопка
      c:=eStyle.GetColor('color',defaultBtnColor); // main (background) color
      d:=byte(pressed);
      if not enabled then c:=ColorMix(c,$FFA0A0A0,128);
      if enabled and (underMouse=control) then inc(c,$101010);
      if pressed then c:=c-$282020;
      draw.FillGradRect(x1+1,y1+1,x2-1,y2-1,ColorAdd(c,$303030),ColorSub(c,$303030),true);
      c:=eStyle.GetColor('border-light',$60000000);
      c2:=eStyle.GetColor('border-dark',$80FFFFFF);
      draw.ShadedRect(x1,y1,x2,y2,1,c,c2); // Внешняя рамка
      if pressed then { draw.ShadedRect(x1+2,y1+2,x2-1,y2-1,1,$80FFFFFF,$50000000)}
       else if enabled then begin
         c:=eStyle.GetColor('disabled.border-light',$A0FFFFFF);
         c2:=eStyle.GetColor('disabled.border-dark',$70000000);
         draw.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,c,c2);
       end
         else draw.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,$80FFFFFF,$50000000);
      // Нарисовать фокус (также если кнопка дефолтная и никакая другая не имеет фокуса)
      if (FocusedElement=control) or
         (default and ((FocusedElement=nil) or not (FocusedElement is TUIButton))) then
       draw.Rect(x1-1,y1-1,x2+1,y2+1,$80FFFF80);
      // Вывод надписи (если есть)
      if caption<>'' then begin
       gfx.clip.Rect(Rect(x1+2,y1+2,x2-2,y2-2));
       c:=eStyle.GetColor('text-color',clBlack);
       mY:=round((y1+y2)*0.5+txt.Height(font)*0.45);
       wSt:=DecodeUTF8(caption);
       if underMouse=control then c:=$FF300000;
       if enabled then
        txt.WriteW(font,(x1+x2)/2,mY+d,c,wst,taCenter)
       else begin
        txt.WriteW(font,(x1+x2)/2+1,mY+1,$E0FFFFFF,wSt,taCenter);
        txt.WriteW(font,(x1+x2)/2,mY,$80000000,wSt,taCenter);
       end;
       gfx.clip.Restore;
      end;
    end;
  end;

 procedure DrawUIFrame(control:TUIFrame;eStyle:PElementStyle;x1,y1,x2,y2:integer);
  var
   c1,c2:cardinal;
   i:integer;
  begin
   c1:=eStyle.GetColor('color',clBlack);
   c2:=eStyle.GetColor('color-dark',0);
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
      if HasPrefix(src,'proc:') then begin
       proc:=pointer(HexToInt(copy(src,6,20)));
       proc(control);
       exit;
      end;
      // SRC = event (must be immediate)
      if HasPrefix(src,'event:') then begin
       Signal(copy(src,7,200),PtrUInt(control));
       exit;
      end;
      // SRC = texture name?
      tex:=nil;
      if HasPrefix(src,'tex:') then begin
       tex:=TTexture(TTexture.FindByName(copy(src,5,200)));
      end else
      if HasPrefix(src,'file:') then begin
       // SRC = filename?
       lname:=FileName(copy(src,6,200));
       tex:=TTexture.FindByFile(lName);
       if tex=nil then
        LoadImage(tex,lname); //
      end else
       raise EWarning.Create('Unsupported image SRC type: '+src);
      if tex<>nil then begin
       draw.Scaled(x1,y1,x2-1,y2-1,tex,control.color);
      end;
     end;
    end;
  end;

/// TODO: rework window rendering using common style
 procedure DrawUIWindow(element:TUIWindow;x1,y1,x2,y2:integer);
  var
   c:cardinal;
   tx,ty:integer;
  begin
    with element do begin
    draw.FillRect(x1,y1,x2,y2,color);
    if element.IsActiveWindow then c:=$FF8080E0 // текущее окно
     else c:=$FFB0B0B0;
    c:=ColorMix(color,c,128);
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
    txt.WriteW(font,tx+1,ty+1,$B0000000,caption,taCenter);
    txt.WriteW(font,tx,ty,$FFFFFFD0,caption,taCenter);
    gfx.clip.Restore;
   end;
  end;

 procedure DrawUIScrollbar(element:TUIScrollbar;style:PElementStyle;x1,y1,x2,y2:integer);
  var
   c,d,v,color,trackColor:cardinal;
   size,width,startPos,endPos,minSize:integer;
   scale,trackWidth,sliderWidth,sliderRadius,f:single;
   sStyle:string8;
   context:TContext;
   sliderVisible:boolean;
   r:TRect2s;
  begin
   size:=x2-x1; width:=y2-y1;
   if not element.horizontal then Swap(size,width);
   // Calculate parameters
   element.CalcSliderPos(style.GetAttr('minSize',0.75));
   sliderVisible:=(element.sliderEnd>element.sliderStart) and (element.sliderEnd-element.sliderStart<1);

   // Draw
   context:=TContext(element.styleContext);
   sStyle:=style.GetAttr('style','flat');
   color:=element.color;
   if color=clDefault then color:=$FFA8B0BC;
   scale:=element.globalScale;

   if SameText(sStyle,'flat') then begin
    // Flat style
    trackWidth:=style.GetNumber('trackWidth',1);
    sliderWidth:=style.GetNumber('sliderWidth',0.9);
    sliderRadius:=style.getNumber('radius',0)*width*sliderWidth;
    // Draw track
    trackColor:=style.GetAttr('trackColor',ColorAlpha(color,0.5));
    trackColor:=ColorMixF(trackColor,style.GetAttr('hover.trackColor',trackColor),CurValue(context.hover));
    r.Init(x1,y1,x2,y2);
    f:=(1-trackWidth)/2;
    if element.horizontal then begin
     r.y1:=LinearMix(y1,y2,f);
     r.y2:=LinearMix(y1,y2,1-f);
    end else begin
     r.x1:=LinearMix(x1,x2,f);
     r.x2:=LinearMix(x1,x2,1-f);
    end;
    draw.FillRect(r.x1,r.y1,r.x2,r.y2,trackColor);

    // Draw slider
    if sliderVisible then begin
     // slider rect
     f:=(1-sliderWidth)/2;
     if element.horizontal then begin
      r.x1:=LinearMix(x1,x2,element.sliderStart);
      r.y1:=LinearMix(y1,y2,f);
      r.x2:=LinearMix(x1,x2,element.sliderEnd);
      r.y2:=LinearMix(y1,y2,1-f);
     end else begin
      r.x1:=LinearMix(x1,x2,f);
      r.y1:=LinearMix(y1,y2,element.sliderStart);
      r.x2:=LinearMix(x1,x2,1-f);
      r.y2:=LinearMix(y1,y2,element.sliderEnd);
     end;
     // color
     if element.sliderUnder then
      color:=style.GetAttr('hover.color',ColorAdd(color,$202020)); // hover color
     if sliderRadius=0 then
      draw.FillRect(r.left,r.top,r.right,r.bottom,color)
     else begin
      r.Round;
      draw.RoundRect(r.left,r.top,r.right,r.bottom,sliderRadius,0,color,color);
     end;
    end;
   end else begin
    // Default (3D) style

    // Draw track
{    c:=colorAdd(color,$202020);
    d:=ColorSub(color,$202020);
    iwidth:=x2-x1;
    iheight:=y2-y1;
    draw.FillGradrect(x1,y1,x2,y2,d,c,element.horizontal);
    // Draw slider (if needed)

    if element.horizontal then begin
     minWidth:=max2(8,round((y2-y1)*0.75));
     if element.enabled and (iwidth>=minWidth) and (pagesize<max-min) then begin
      v:=colorMix(ColorAdd(color,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if sliderUnder and not (hooked=element) then v:=ColorAdd(v,$101010);
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
     minWidth:=max2(8,round((x2-x1)*0.75));
     if enabled and (iheight>=minWidth) and (pagesize<max-min) then begin
      v:=colorMix(ColorAdd(color,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if sliderUnder and not (hooked=element) then v:=ColorAdd(v,$101010);
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
   wst:WideString;
   i,j,mY,d,curX,scrollPixels,xStart:integer;
   c:cardinal;
  begin
   with control do begin
    wst:=realtext;
    if password then
      wst:=StringOfChar('*',length(wst));
    if (scroll.X>0) and (txt.WidthW(font,wst)<(x2-x1)) then Scroll.X:=0;
    i:=txt.WidthW(font,copy(wst,1,cursorpos)); // позиция курсора
    if i-scroll.X<0 then scroll.X:=i;
    if i-scroll.X>(x2-x1-5-offset) then scroll.X:=i-(x2-x1-5-offset);
    gfx.clip.Rect(Rect(x1+2,y1,x2-2,y2));
    my:=round(y1*0.47+y2*0.53+txt.Height(font)*0.4);
    // Default text?
    if (realtext='') and (defaultText<>'') and (FocusedElement<>control) then begin
     txt.WriteW(font,x1+2+offset,mY,ColorMix(color,$00808080,160),defaultText,taLeft,toDontTranslate);
     gfx.clip.Restore;
     exit;
    end;
    scrollPixels:=round(scroll.X*globalScale);

    if needpos>=0 then begin
     cursorpos:=0;
     while (cursorpos<length(wst)) and
           (-scroll.X+txt.WidthW(font,copy(wst,1,cursorpos))<needPos-3) do
       inc(cursorpos);
     needpos:=-1;
    end;
    xStart:=x1+round((y2-y1)*0.15)-scrollPixels;
    if completion<>'' then begin
     j:=xStart+txt.WidthW(font,wst);
     txt.WriteW(font,j+offset,mY,ColorMix(color,$00808080,160),
       copy(completion,length(wst)+1,length(completion)),taLeft,toDontTranslate);
    end;
    if (selcount>0) and (FocusedElement=control) then begin // часть текста выделена
     j:=xStart+offset;
     txt.WriteW(font,j,mY,color,copy(wst,1,selstart-1),taLeft,toDontTranslate); // до выделения
     j:=j+txt.WidthW(font,copy(wst,1,selstart))-
          txt.WidthW(font,copy(wst,selstart,1));
     d:=txt.WidthW(font,copy(wst,selstart,selcount));
     draw.FillRect(j,y1+1,j+d-1,y2-1,ColorSub(color,$60202020));
     txt.WriteW(font,j,mY,color and $FF000000,
        copy(wst,selstart,selcount),taLeft,toDontTranslate); // выделенная часть
     if selstart+selcount-1<=length(text) then begin
      j:=j+txt.WidthW(font,copy(wst,selstart,selcount+1))-
           txt.WidthW(font,copy(wst,selstart+selcount,1));
      txt.WriteW(font,j,mY,color,
         copy(wst,selstart+selcount,length(wst)-selstart-selcount+1),taLeft,toDontTranslate); // остаток
     end;
    end else
     txt.WriteW(font,xStart+offset,mY,color,wst,taLeft,toDontTranslate);
    gfx.clip.Restore;
    if (FocusedElement=control) and ((mytickcount-cursortimer) mod 360<200) then begin // курсор
     curX:=xStart+offset+i; // first pixel of the character
     draw.Line(curX,y1+2,curX,y2-2,colorAdd(color,$404040));
//     draw.Line(x1+4+i-scrollX,y1+2,x1+4+i-scrollX,y2-2,colorAdd(color,$404040));
    end;
   end;
  end;

 procedure DrawUIListBox(control:TUIListBox;x1,y1,x2,y2:integer);
  var
   i,lY:integer;
   c,c1,c2:cardinal;
   scrollPos,lineH:single;
  begin
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
      txt.WriteW(font,x1+4,lY+round(lineH*0.73),c,lines[i],taLeft,toComplexText);
     end;
     gfx.clip.Restore;
    end;
  end;

 procedure DrawUIComboBox(x1,y1,x2,y2:integer;combo:TUIComboBox);
  var
   st:string;
   i,cx,cy:integer;
   c:cardinal;
  begin
   if (undermouse=combo) or combo.frame.visible then
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
     txt.WriteW(combo.font,x1+5,round(y2*0.7+y1*0.3),$FF000000,st);
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

 function MixColor(style:PElementStyle;name:string8;baseValue:cardinal;t:single):cardinal;
  var
   c:cardinal;
  begin
   c:=style.GetColor(name,clDefault);
   if c<>clDefault then
    result:=ColorMixF(baseValue,c,t)
   else
    result:=baseValue;
  end;

 procedure DrawCommonStyle(element:TUIElement;style:PElementStyle;context:TContext);
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
    i:integer;
   begin
    if (bWidth>0) and (borderColor=clDefault) then borderColor:=element.color;
    if radius>1 then begin
     draw.RoundRect(x1,y1,x2,y2,radius*scale,bWidth*scale,borderColor,fillColor);
    end else begin
     if fillColor<>0 then
      draw.FillRect(x1,y1,x2,y2,fillColor);
     if borderColor<>0 then begin
      for i:=0 to round(bWidth*scale)-1 do
       draw.Rect(x1+i,y1+i,x2-i,y2-i,borderColor)
     end;
    end;
   end;
  begin
   ImportRect(element.globalRect);
   scale:=element.globalScale;
   // Outer block
   fillColor:=style.GetColor('fill');
   borderColor:=style.GetColor('borderColor');
   radius:=style.GetNumber('radius');
   bWidth:=style.GetNumber('borderWidth',0);

   v:=CurValue(context.hover);
   if v>0 then begin
    fillColor:=MixColor(style,'hover.fill',fillColor,v);
    borderColor:=MixColor(style,'hover.borderColor',borderColor,v);
    radius:=LinearMix(radius,style.GetNumber('hover.radius',radius),v);
    bWidth:=LinearMix(bWidth,style.GetNumber('hover.borderWidth',bWidth),v);
   end;

   // This is important for drawing large semi-transparent areas on a transparent background (render to texture)
   // to avoid duplicate alpha blending (resulting in alpha=sqr(alpha))
   if IsSemiTransparent(fillColor) then SetProperBlendMode(element);
   DrawBlock;
   RestoreBlendMode;

   // Inner (client) block
   fillColor:=style.GetColor('innerFill');
   borderColor:=style.GetColor('innerBorder');
   radius:=style.GetNumber('innerRadius',radius);
   bWidth:=style.GetNumber('innerBorderWidth',bWidth);
   if (fillColor<>0) or (borderColor<>0) then begin
    ImportRect(element.GetClientPosOnScreen,bWidth*scale);
    DrawBlock;
   end;
  end;

 // Отрисовщик по умолчанию
 procedure DefaultDrawer(element:TUIElement);
  var
   x1,y1,x2,y2:integer;
   eStyle:PElementStyle;
   context:TContext;
  begin
   eStyle:=GetElementStyle(element);
   context:=PrepareContext(element,eStyle); // make sure element has proper context
   context.Update(element,eStyle);
   if eStyle<>nil then
    DrawCommonStyle(element,eStyle,context);

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
    DrawUIButton(element as TUIButton,eStyle,x1,y1,x2,y2)
   else
   if element is TUICheckbox then
    DrawUICheckbox(element as TUICheckbox,eStyle,x1,y1,x2,y2)
   else
   // Рамка
   if element.ClassType=TUIFrame then
    DrawUIFrame(element as TUIFrame,eStyle,x1,y1,x2,y2)
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
    DrawUIScrollbar(element as TUIScrollBar,eStyle,x1,y1,x2,y2)
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

{ TElementStyle }

function TElementStyle.GetAttr(name:string8;default:variant):variant;
  begin
   if @self=nil then exit(default);
   result:=attributes.Get(name);
   if not HasValue(result) then result:=default;
  end;

 function TElementStyle.GetColor(name:string8;default:cardinal):cardinal;
  begin
   result:=GetAttr(name,default)
  end;

 function TElementStyle.GetInt(name:string8;default:integer):integer;
  begin
   result:=GetAttr(name,default);
  end;

function TElementStyle.GetNumber(name:string8;default:single):single;
  begin
   result:=GetAttr(name,default);
  end;

 function TElementStyle.GetScaled(element:TUIElement;name:string8;default:single=0):single;
  begin
   result:=GetAttr(name,default);
   result:=result*element.globalScale;
  end;

 function TElementStyle.GetString(name,default:string8):string8;
  begin
   result:=GetAttr(name,default);
  end;

 function TElementStyle.HasAttr(name:string8):boolean;
  begin
   if @self=nil then exit(false);
   result:=attributes.HasKey(name);
  end;

function TElementStyle.ActualStyleInfo:string8;
  var
   i:integer;
   notOldStyle:boolean;
   items:StringArray8;
  begin
   result:=fullStyleInfo;
   if supportOldStyles and (fullStyleInfo<>'') then begin
    // Check for old
    notOldStyle:=false;
    for i:=1 to length(fullStyleInfo) do
     if not (fullStyleInfo[i] in ['0'..'9','A'..'F','a'..'f','$',' ']) then begin
      notOldStyle:=true; break;
     end;
    if not notOldStyle then begin
     items:=SplitA(' ',fullStyleInfo);
     if length(items)>0 then result:='fill:'+items[0];
     if length(items)>1 then result:='; border:'+items[1];
     exit;
    end;
   end;
  end;

 procedure TElementStyle.Parse;
  var
   i,start:integer;
   prefix:string8;
   actualStyle:string8;

  function ParseColor(s:string8):cardinal;
   begin
    result:=clDefault;
    if length(s)<2 then exit;
    if s[1] in ['#','$'] then delete(s,1,1);
    if length(s)=8 then result:=ParseInt('$'+s)
    else
    if length(s)=6 then result:=ParseInt('$FF'+s)
    else if length(s)=3 then begin
     s:='$FF'+s[1]+s[1]+s[2]+s[2]+s[3]+s[3];
     result:=ParseInt(s);
    end else
    if length(s)=4 then begin
     s:='$'+s[1]+s[1]+s[2]+s[2]+s[3]+s[3]+s[4]+s[4];
     result:=ParseInt(s);
    end;
   end;

  function ParseValue(name,s:string8):variant;
   var
    i,p:integer;
   begin
    if length(s)<1 then exit(false);
    p:=pos('.',name);
    if p>0 then delete(name,1,p);
    for i:=0 to high(attribList) do
     if name=attribList[i].name then begin
      case attribList[i].aType of
       atColor:result:=ParseColor(s);
       atNumber:result:=ParseFloat(s);
       atString:result:=s;
      end;
      exit;
     end;
    if LastChar(s)='%' then begin
     result:=ParseFloat(s)*0.01;
     exit;
    end;
    result:=s;
   end;

  procedure ParsePart(from,last:integer);
   var
    p:integer;
    attr,aVal:string8;
    value:variant;
   begin
    if actualStyle[from]='[' then begin
     p:=PosFrom(']',actualStyle,from+1);
     if p>from then begin
      prefix:=LowerCase(Copy(actualStyle,from+1,p-from-1));
      from:=p+1;
     end else
      raise EWarning.Create('Style syntax error at %d: "%s"',[from,actualStyle]);
    end;
    p:=PosFromTo(':',actualStyle,from+1,last);
    if (p=0) or (p>last) then p:=PosFromTo('=',actualStyle,from+1,last);
    if p>0 then begin
     // name:value pair
     attr:=LowerCase(Chop(Copy(actualStyle,from,p-from)));
     aVal:=Chop(Copy(actualStyle,p+1,last-p));
     value:=ParseValue(attr,aVal);
    end else begin
     // valueless attribute -> value=true
     attr:=LowerCase(Chop(copy(actualStyle,from,last-from+1)));
     value:=true;
    end;
    if prefix<>'' then attr:=prefix+'.'+LowerCase(attr);
    attributes.Put(attr,value);
   end;
  begin
   actualStyle:=ActualStyleInfo;
   attributes.Init(32);
   start:=1; i:=start;
   while i<=length(actualStyle) do begin
    if (i=start) and (actualStyle[i]<=' ') then begin
     inc(start); inc(i); continue;
    end;
    if actualStyle[i]=';' then begin
     ParsePart(start,i-1);
     start:=i+1;
     i:=start;
    end else
     inc(i);
   end;
   if start<length(actualStyle) then
    ParsePart(start,length(actualStyle));
  end;

{ TCheckboxContext }

constructor TContext.Create(element:TUIElement;style:PElementStyle);
 var
  v:integer;
  hoverEl:TUIElement;
 begin
  if element.IsEnabled then v:=0 else v:=1;
  disabled.Init(v);
  hover.Init(HoverState(element,style));
  v:=0;
  if element is TUIButton then
   if TUIButton(element).pressed then v:=1;
  if element is TUICheckBox then
   if TUICheckbox(element).checked then v:=1;
  active.Init(v);
 end;

procedure TContext.Update(element:TUIElement;style:PElementStyle);
 var
  v,duration:integer;
 begin
  // Mouse hover state
  v:=HoverState(element,style);
  if hover.FinalValue<>v then begin
   if v=1 then duration:=120 else duration:=80; // default
   duration:=style.GetInt('hoverTime',duration);
   if v=1 then duration:=style.GetInt('hoverTimeUp',duration)
    else duration:=style.GetInt('hoverTimeDown',duration);
   hover.Animate(v,duration);
  end;

  // Click state
  v:=0;
  if element is TUIButton then
   if TUIButton(element).pressed then v:=1;
  if element is TUICheckBox then
   if TUICheckbox(element).checked then v:=1;
  if active.finalValue<>v then begin
   if v=1 then duration:=120 else duration:=80; // default
   duration:=style.GetInt('pressTime',duration);
   if v=0 then duration:=style.GetInt('releaseTime',duration);
   active.Animate(v,duration);
  end;

  // Disabled state
  if element.IsEnabled then v:=0 else v:=1;
  if disabled.FinalValue<>v then begin
   duration:=0; // default
   duration:=style.GetInt('disableTime',duration);
   if v=0 then duration:=style.GetInt('enableTime',duration);
   disabled.Animate(v,duration);
  end;
 end;

function TContext.HoverState(element:TUIElement;style:PElementStyle):byte;
 var
  hoverEl:TUIElement;
 begin
  hoverEl:=element;
  if SameText(style.GetString('hover'),'parent') and (element.parent<>nil) then
   hoverEl:=element.parent;
  if (underMouse=hoverEl) or hoverEl.HasChild(underMouse) then result:=1
   else result:=0;
 end;

initialization
 RegisterUIStyle(0,DefaultDrawer,'Default');
 TUIEditBox.SetDefault('styleInfo','borderWidth=1; radius=3; borderColor:8000; fill:8FFF');
end.
