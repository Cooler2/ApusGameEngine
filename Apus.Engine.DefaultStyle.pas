// Default UI style (0) inspired by CSS
//
// Copyright (C) 2022 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.DefaultStyle;
interface
uses Apus.Engine.UI;

 procedure DefaultDrawer(control:TUIElement);

implementation
 uses Apus.CrossPlatform, Apus.Images, SysUtils, Types, Apus.MyServis,
    Apus.Colors, Apus.Structs, Apus.EventMan, Apus.Geom2D,
    Apus.Engine.API, Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.UIRender;

 var
  imgHash:TSimpleHashS;  // hash of loaded images: filename -> UIntPtr(TTexture)
  styleHash:TSimpleHash; // element pointer -> style data

  hintImage:TTexture;

 {$R-}
 // styleinfo="00000000 11111111 22222222 33333333" - list of colors (hex)
 function GetColor(control:TUIElement;index:integer=0):cardinal;
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
  end;

 procedure DrawUIControl(control:TUIElement;x1,y1,x2,y2:integer);
  var
   i,c,c2:integer;
   st:string;
  begin
   if control.styleinfo='' then exit;
   c:=GetColor(control,0);
   c2:=GetColor(control,1);
   if c<>0 then begin
    if transpBgnd and (control.shape<>shapeEmpty) then gfx.target.BlendMode(blMove);
    draw.FillRect(x1,y1,x2,y2,c);
    if transpBgnd then gfx.target.BlendMode(blAlpha);
   end;
   if c2<>0 then draw.Rect(x1,y1,x2,y2,c2);
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
    size:=Point2s(iWidth/globalScale.x,iHeight/globalScale.y);
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
  begin
   with hnt do begin
    adjusted:=true;
    if sx+size.x+2<game.renderWidth then position.x:=position.x+4
     else position.x:=position.x-(sx+size.x-game.renderWidth);

    if sy+size.y*2+4>game.renderHeight then position.y:=position.y-(size.y+4)
     else position.y:=position.y+10+game.renderHeight div 60;
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
     if shape=shapeFull then v:=(MyTickCount-created)*2
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
     c:=ColorMix($FF808080,$808080,v);
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
  begin
    with control do begin
     bg:=GetColor(control);
     if bg<>0 then draw.FillRect(x1,y1,x2,y2,bg);
     gfx.clip.Rect(globalRect);
     //mY:=round(y1*0.3+y2*0.7)-topOffset;
     mY:=round((y1+y2)*0.5+txt.Height(font)*0.45)-topOffset;
     wst:=DecodeUTF8(caption);
     if align=taLeft then
      txt.WriteW(font,x1,mY,color,wst);
     if align=taRight then
      txt.WriteW(font,x2,mY,color,wst,taRight);
     if align=taCenter then
      txt.WriteW(font,(x1+x2) div 2,mY,color,wst,taCenter);
     if align=taJustify then
      txt.WriteW(font,x1,mY,color,wst,taJustify,0,x2-x1);
     gfx.clip.Restore;
    end;
  end;

 procedure DrawUIButton(control:TUIButton;x1,y1,x2,y2:integer);
  var
   v,mY:integer;
   c,c2:cardinal;
   d:integer;
   wst:WideString;
  begin
    with control as TUIButton do begin
     if btnStyle<>bsCheckbox then begin
      // обычная кнопка
      c:=GetColor(control,0); // main (background) color
      if c=0 then c:=defaultBtnColor;
      d:=byte(pressed);
      if not enabled then c:=ColorMix(c,$FFA0A0A0,128);
      if enabled and (underMouse=control) then inc(c,$101010);
      if pressed then c:=c-$282020;
      draw.FillGradRect(x1+1,y1+1,x2-1,y2-1,ColorAdd(c,$303030),ColorSub(c,$303030),true);
      c:=GetColor(control,2); if c=0 then c:=$60000000;
      c2:=GetColor(control,3); if c2=0 then c2:=$80FFFFFF;
      draw.ShadedRect(x1,y1,x2,y2,1,c,c2); // Внешняя рамка
      if pressed then { draw.ShadedRect(x1+2,y1+2,x2-1,y2-1,1,$80FFFFFF,$50000000)}
       else if enabled then begin
         c:=GetColor(control,4); if c=0 then c:=$A0FFFFFF;
         c2:=GetColor(control,5); if c2=0 then c2:=$70000000;
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
       c:=GetColor(control,1); if c=0 then c:=$FF000000;
       mY:=round(y1*0.5+y2*0.5+txt.Height(font)*0.4); // учесть высоту шрифта!
       wSt:=DecodeUTF8(caption);
       if underMouse=control then c:=$FF300000;
       if enabled then
        txt.WriteW(font,(x1+x2) div 2+d,mY+d,c,wst,taCenter)
       else begin
        txt.WriteW(font,(x1+x2) div 2+1,mY+1,$E0FFFFFF,wSt,taCenter);
        txt.WriteW(font,(x1+x2) div 2,mY,$80000000,wSt,taCenter);
       end;
       gfx.clip.Restore;
      end;
     end else begin
      // кнопка - чекбокс или радиобокс
      if group=0 then begin
       // чекбокс
       v:=(y1+y2) div 2;
       if pressed then begin
        draw.Line(x1+3,v,x1+6,v+4,color);
        draw.Line(x1+6,v+4,x1+14,v-6,color);
        draw.Line(x1+3,v-1,x1+7,v+3,color);
        draw.Line(x1+6,v+3,x1+13,v-6,color);
       end;
       c:=ColorMix(color,$80FFFFFF,64);
       d:=ColorMix(color,$80000000,128);
       if (underMouse=control) and enabled then begin
        c:=ColorAdd(c,$40000000);
        d:=ColorAdd(d,$40000000);
       end;
       if not enabled then begin
        c:=colorMix(c,$80808080,200);
        d:=colorMix(d,$80808080,200);
       end;
       draw.ShadedRect(x1,v-8,x1+15,v+7,2,d,c);
      end else begin
       // радиобокс
      end;
      gfx.clip.Rect(Rect(x1+19,y1,x2,y2));
      v:=round(y1+(y2-y1)*0.65);
      if FocusedElement=control then
       draw.Rect(x1+19,y1,x1+txt.Width(font,caption),y2,$40+color and $FFFFFF);
      if enabled then
       txt.WriteW(font,x1+20,v,color,caption)
      else begin
       txt.WriteW(font,x1+21,v+1,$60FFFFFF,caption);
       txt.WriteW(font,x1+20,v,ColorMix(color,$C0909090,200),caption);
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
   c1:=GetColor(control,0);
   if c1=0 then c1:=$FF000000;
   c2:=GetColor(control,1);
   for i:=0 to round(control.paddingLeft)-1 do begin
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
      if copy(src,1,5)='proc:' then begin
       proc:=pointer(HexToInt(copy(src,6,20)));
       proc(control);
       exit;
      end;
      // SRC = event (must be immediate)
      if copy(src,1,6)='event:' then begin
       Signal(copy(src,7,200),PtrUInt(control));
       exit;
      end;
      // SRC = filename?
      lname:=FileName(src);
      p:=imgHash.Get(lname);
      if p=-1 then begin
       tex:=nil;
       LoadImage(tex,lname);
       imgHash.Put(lname,UIntPtr(tex));
      end else
       tex:=pointer(p);
      draw.Scaled(x1,y1,x2-1,y2-1,tex,control.color);
     end;
    end;
  end;

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

 procedure DrawUIScrollbar(control:TUIScrollbar;x1,y1,x2,y2:integer);
  var
   c,d,v:cardinal;
   i,j,iWidth,iHeight:integer;
  begin
   with control do begin
    c:=colorAdd(color,$202020);
    d:=ColorSub(color,$202020);
    iwidth:=x2-x1;
    iheight:=y2-y1;
    if horizontal then begin
     // Horizontal scrollbar
     draw.FillGradrect(x1,y1,x2,y2,d,c,true);
     if enabled and (iwidth>=8) and (pagesize<max-min) then begin
      v:=colorMix(ColorAdd(color,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if over and not (hooked=control) then v:=ColorAdd(v,$101010);
      i:=round((iwidth-8)*value/max);
      j:=9+round((iwidth-8)*(value+pagesize)/max);
      if i<0 then i:=0;
      if j>=iwidth then j:=iwidth-1;
      if j>i+6 then begin
       draw.FillGradrect(x1+i,y1,x1+j,y2,colorMix(v,$FFC0E0F0,192),colorMix(v,$FF0000A0,192),true);
       if (hooked=control) then draw.ShadedRect(x1+i,y1,x1+j,y2,1,d,d)
        else draw.ShadedRect(x1+i,y1,x1+j,y2,1,c,d);
       i:=x1+(i+j) div 2;
       draw.ShadedRect(i-2,y1+3,i-1,y2-3,1,d,c);
       draw.ShadedRect(i+1,y1+3,i+2,y2-3,1,d,c);
      end;
     end;
    end else begin
     // Vertical scrollbar
     draw.FillGradrect(x1,y1,x2,y2,d,c,false);
     if enabled and (iheight>=8) and (pagesize<max-min) then begin
      v:=colorMix(ColorAdd(color,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if over and not (hooked=control) then v:=ColorAdd(v,$101010);
      i:=round((iheight-8)*value/max);
      j:=9+round((iheight-8)*(value+pagesize)/max);
      if i<0 then i:=0;
      if j>iheight then j:=iheight;
      if j>i+6 then begin
       draw.FillGradrect(x1,y1+i,x2,y1+j,colorMix(v,$FFC0E0F0,192),colorMix(v,$FF0000A0,192),false);
       if (hooked=control) then draw.ShadedRect(x1,y1+i,x2,y1+j,1,d,d)
        else draw.ShadedRect(x1,y1+i,x2,y1+j,1,c,d);
       i:=y1+(i+j) div 2;
       draw.ShadedRect(x1+3,i-2,x2-3,i-1,1,d,c);
       draw.ShadedRect(x1+3,i+1,x2-3,i+2,1,d,c);
      end;
     end;
    end;
   end;
  end;

 procedure DrawUIEditBox(control:TUIEditBox;x1,y1,x2,y2:integer);
  var
   wst:WideString;
   i,j,mY,d,curX,scrollPixels:integer;
   c:cardinal;
  begin
   with control as TUIEditBox do begin
    if backgnd<>0 then begin
     c:=backgnd;
     if UnderMouse=control then
      c:=ColorAdd(backgnd,$404040);
     draw.FillRect(x1,y1,x2,y2,c);
    end;
    if not noborder then begin
     draw.RRect(x1-1,y1-1,x2+1,y2+1,$A0000000+color and $FFFFFF,1);
    end;

{    savey:=y1;
    savey2:=y2;
    inc(y1,((y2-y1)-txt.GetFontHeight) div 2);
    y2:=y1+txt.GetFontHeight;}
    wst:=realtext;
    if password then
      wst:=StringOfChar('*',length(wst));
    if (scroll.X>0) and (txt.WidthW(font,wst)<(x2-x1)) then Scroll.X:=0;
    i:=txt.WidthW(font,copy(wst,1,cursorpos)); // позиция курсора
//    if cursorpos>0 then dec(i);
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
    scrollPixels:=round(scroll.X*globalScale.x);

    if needpos>=0 then begin
     cursorpos:=0;
     while (cursorpos<length(wst)) and
           (-scroll.X+txt.WidthW(font,copy(wst,1,cursorpos))<needPos-3) do
       inc(cursorpos);
     needpos:=-1;
    end;
    if completion<>'' then begin
     j:=x1+2-scrollPixels+txt.WidthW(font,wst);
     txt.WriteW(font,j+offset,mY,ColorMix(color,$00808080,160),
       copy(completion,length(wst)+1,length(completion)),taLeft,toDontTranslate);
    end;
    if (selcount>0) and (FocusedElement=control) then begin // часть текста выделена
     j:=x1+2-scrollPixels+offset;
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
     txt.WriteW(font,x1+2-scrollPixels+offset,mY,color,wst,taLeft,toDontTranslate);
    gfx.clip.Restore;
    if (FocusedElement=control) and ((mytickcount-cursortimer) mod 360<200) then begin // курсор
     curX:=x1+2+i-scrollPixels+offset; // first pixel of the character
     draw.Line(curX,y1+2,curX,y2-2,colorAdd(color,$404040));
//     draw.Line(x1+4+i-scrollX,y1+2,x1+4+i-scrollX,y2-2,colorAdd(color,$404040));
    end;
   end;
  end;

 procedure DrawUIListBox(control:TUIListBox;x1,y1,x2,y2:integer);
  var
   i,lY:integer;
   c,c1,c2:cardinal;
   scr:single;
  begin
    with control as TUIListBox do begin
     if bgColor<>0 then draw.FillRect(x1,y1,x2,y2,bgColor);
     if scrollerV<>nil then scr:=scrollerV.GetValue
      else scr:=0;
     gfx.clip.Rect(Rect(x1,y1,x2+1,y2+1));
     for i:=0 to length(lines)-1 do begin
      lY:=y1+round(i*lineHeight-scr); /// TODO: check
      if lY+lineHeight<y1 then continue;
      if lY>y2 then break;
      if i=selectedLine then begin
       draw.FillRect(x1,lY,x2,round(lY+lineHeight),bgSelColor);
       c:=selTextColor;
      end else
      if i=hoverLine then begin
       draw.FillRect(x1,lY,x2,round(lY+lineHeight),bgHoverColor);
       c:=hoverTextColor;
      end else
       c:=textColor;
      txt.WriteW(font,x1+4,lY+round(lineHeight*0.73),c,lines[i],taLeft,toComplexText);
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

 // Отрисовщик по умолчанию
 procedure DefaultDrawer(control:TUIElement);
  var
   enabl:boolean;
   con:TUIElement;
   x1,y1,x2,y2:integer;
  begin
   enabl:=control.enabled;
   con:=control;
   while con.parent<>nil do begin
    con:=con.parent;
    enabl:=enabl and con.enabled;
   end;

   with control.globalrect do begin
    x1:=Left; x2:=right-1;
    y1:=top; y2:=bottom-1;
   end;

   // Просто контейнер - заливка плюс рамка
   if control.ClassType=TUIElement then
    DrawUIControl(control,x1,y1,x2,y2)
   else
   // Надпись
   if control is TUILabel then
    DrawUILabel(control as TUILabel,x1,y1,x2,y2)
   else
   // Кнопка
   if control.ClassType=TUIButton then
    DrawUIButton(control as TUIButton,x1,y1,x2,y2)
   else
   // Рамка
   if control.ClassType=TUIFrame then
    DrawUIFrame(control as TUIFrame,x1,y1,x2,y2)
   else
   // Произвольное изображение
   if control.ClassType=TUIImage then
    DrawUIImage(control as TUIImage,x1,y1,x2,y2)
   else
   // всплывающий хинт
   if control is TUIHint then
    DrawUIHint(control as TUIHint,x1,y1,x2,y2)
   else
   // Window
   if control.ClassType=TUIWindow then
    DrawUIWindow(control as TUIWindow,x1,y1,x2,y2)
   else
   // Scrollbar
   if control.ClassType=TUIScrollBar then
    DrawUIScrollbar(control as TUIScrollbar,x1,y1,x2,y2)
   else
   // EditBox
   if control.ClassType=TUIEditBox then
    DrawUIEditBox(control as TUIEditBox,x1,y1,x2,y2)
   else
   // ListBox
   if control is TUIListBox then
    DrawUIListBox(control as TUIListBox,x1,y1,x2,y2)
   else
   // Combo box
   if control is TUIComboBox then
    DrawUIComboBox(x1,y1,x2,y2,control as TUIComboBox)
   else
    DrawUIControl(control,x1,y1,x2,y2);
  end;

initialization
 RegisterUIStyle(0,DefaultDrawer,'Default');
end.
