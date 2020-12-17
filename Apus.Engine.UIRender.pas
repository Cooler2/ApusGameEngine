// -----------------------------------------------------
// User Interface rendering block
//
// Author: Ivan Polyacov (C) 2003-2014, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------
unit Apus.Engine.UIRender;
interface
 uses Apus.Engine.API, Apus.Engine.UIClasses;
 type
  // процедура отрисовки элемента
  TUIDrawer=procedure(control:TUIElement);

 var
  defaultBtnColor:cardinal=$FFB0A0C0;

 // Render an UI element and all its descendants
 // Use customDraw=true to draw only elements with customDraw=true, otherwise these elements will be skipped
 procedure DrawUI(item:TUIElement;customDraw:boolean=false);

 procedure DrawGlobalShadow(color:cardinal);

 // Set custom style drawer (style=1..50)
 // 0..9 - reserved for engine styles
 // 10..19 - for private game styles
 // 20..50 - 3-rd party libraries
 procedure RegisterUIStyle(style:byte;drawer:TUIDrawer;name:string='');

 // Default style (0) drawer
 procedure DefaultDrawer(control:TUIElement);

 // Prepare hint for drawing
 procedure BuildSimpleHint(hnt:TUIHint);

 // Fill control rect with image (helper function)
 procedure DrawControlWithImage(c:TUIElement;img:TTexture;centered:boolean=false);

 var
  // Глобальная переменная для отрисовщиков: может содержать время, прошедшее с
  // предыдущей отрисовки (время кадра), но может содержать и 0
  frameTime:int64;

  transpBgnd:boolean=false; // render target is (probably) transparent so blMove should be used to fill it

  defaultHintFont:cardinal=0; // Шрифт, которым показываются хинты

implementation
 uses Apus.CrossPlatform, Apus.Images, SysUtils, Types, Apus.MyServis,
    Apus.Colors, Apus.Structs, Apus.EventMan, Apus.Geom2D;

{ type
  TBasicStyle=class
   styleText:String8;
   bgColor,borderColor:cardinal;
   procedure UpdateIfNeeded(st:AnsiString);
  end;}

 var
  styleDrawers:array[0..50] of TUIDrawer;

  hintImage:TTexture;

  imgHash:THash;

  styleHash:TSimpleHash; // element pointer -> style data


 procedure DrawGlobalShadow(color:cardinal);
  begin
   painter.FillRect(0,0,game.renderWidth,game.renderHeight,color);
  end;

 procedure DrawUI(item:TUIElement;customDraw:boolean=false);
  var
   i,j,n,cnt:integer;
   tmp:pointer;
   r:TRect;
   list:array of TUIElement;
   maskChange:boolean;
   clipping:boolean;
  begin
   if not item.visible then exit;
   if (item.size.x<=0) or (item.size.y<=0) then exit;
   // Draw self first
   if item.layout<>nil then item.layout.Layout(item);
   item.globalRect:=item.GetPosOnScreen;
{   /// TODO: alpha should be masked ONLY if semi-transparent element is drawn on an opaque background, not vice-versa.
   ///  Need to find a generic approach.
   maskChange:=(item.parent<>nil) and (item.parent.transpmode<>tmTransparent);
   maskChange:=false;
   if maskChange then painter.SetMask(true,false);}
   try
    // Draw control
    if (item.customDraw=customDraw) and
       (item.style>=0) and
       (item.style<=high(styleDrawers)) then begin
        ASSERT(@styleDrawers[item.style]<>nil,'Style not registered');
        styleDrawers[item.style](item);
    end;
    // Debug: Highlight with border when Ctrl+Alt+Win pressed
    if (game.shiftState and $F=$E) then
     if (item=underMouse) or
        ((underMouse<>nil) and (item=underMouse.parent)) then
       with item.globalRect do begin
         painter.Rect(left,top,right-1,bottom-1,$80FFFFFF xor ($FFFFFF*((MyTickCount shr 8) and 1)));
       end;
   except
    on E:Exception do begin
     ForceLogMessage('Error drawing control '+item.name+' - '+ExceptionMsg(e));
     sleep(0);
    end;
   end;

   // Now prepare list of child elements to draw
   n:=length(item.children);
   cnt:=0;
   for i:=0 to n-1 do
    if item.children[i].visible then inc(cnt);
   SetLength(list,cnt);
   cnt:=0;
   for i:=0 to n-1 do
    if item.children[i].visible then begin
     list[cnt]:=item.children[i]; inc(cnt);
    end;

   // Process children elements
   if cnt>0 then begin
    // Затем отсортировать и нарисовать вложенные эл-ты
    for i:=0 to cnt-2 do
     for j:=cnt-1 downto i+1 do
      if list[j].order<list[j-1].order then begin
       tmp:=list[j];
       list[j]:=list[j-1];
       list[j-1]:=tmp;
      end;

    clipping:=item.clipChildren;
    if clipping then begin
     r:=item.GetClientPosOnScreen;
     painter.SetClipping(r);
    end;

    for i:=0 to cnt-1 do begin
     // если элемент не клипится и фон - не прозрачный - нарисовать без отсечения
     if clipping and not list[i].parentClip and not transpBgnd then begin
      painter.OverrideClipping;
      DrawUI(list[i]);
      painter.ResetClipping;
     end else
      DrawUI(list[i]);
    end;

    if clipping then painter.ResetClipping;
   end;
{   // вернуть маску назад
   if maskChange then painter.ResetMask;}
  end;

 procedure RegisterUIStyle(style:byte;drawer:TUIDrawer;name:string='');
  begin
   ASSERT(style in [1..high(styleDrawers)]);
   styleDrawers[style]:=drawer;
   if name<>'' then LogMessage(Format('UI style registered: %d - %s',[style,name]));
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
    if font=0 then font:=painter.GetFont('Default',7);
    h:=round(painter.FontHeight(font)*1.5);
    iHeight:=h*length(sa)+9;
    iWidth:=0;
    for i:=1 to length(sa) do
     if iWidth<painter.TextWidthW(font,wsa[i-1]) then
      iWidth:=painter.TextWidthW(font,wsa[i-1]);
    dw:=painter.TextWidthW(font,'M');
    inc(iWidth,4+dw);
    LogMessage('[Re]alloc hint image');
    if HintImage<>nil then painter.texman.FreeImage(HintImage);
    HintImage:=painter.texman.AllocImage(iWidth,iHeight,pfRenderTargetAlpha,aiTexture+aiRenderTarget,'UI_HintImage');
    if hintImage=nil then
      raise EError.Create('Failed to alloc hint image!');
    size:=Point2s(iWidth,iHeight);
    painter.BeginPaint(hintImage);
    try
     painter.SetMask(true,true); // потенциально может вредить отрисовке следующих элементов
     painter.Clear(0,-1,-1);
     painter.FillRect(1,2,iwidth-1,iheight-2,$80000000);
     painter.FillRect(2,1,iwidth-2,iheight-1,$80000000);
     painter.FillGradrect(0,0,iwidth-3,iheight-3,$FFFFFFD0,$FFE0E0A0,true);
     painter.Rect(0,0,iwidth-3,iheight-3,$FF000000);
     painter.ResetMask;
     for i:=0 to length(sa)-1 do
      painter.TextOutW(font,1+dw div 2,round(2+h div 7+(i+0.75)*h),$D0000000,wsa[i]);
    finally
     painter.EndPaint;
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

 procedure DrawControlWithImage(c:TUIElement;img:TTexture;centered:boolean=false);
  var
   r:TRect;
   p:TPoint2s;
   scale:TVector2s;
  begin
   if centered then begin
    p:=c.TransformTo(c.GetRect.Center,c.parent);
    scale:=c.globalScale;
    painter.DrawRotScaled(p.x,p.y,scale.x,scale.y,0,img);
   end else begin
    r:=c.GetPosOnScreen;
    with r do painter.DrawScaled(left,top,right+1,bottom+1,img);
   end;
  end;

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
    if transpBgnd and (control.shape<>shapeEmpty) then painter.SetMode(blMove);
    painter.FillRect(x1,y1,x2,y2,c);
    if transpBgnd then painter.SetMode(blAlpha);
   end;
   if c2<>0 then painter.Rect(x1,y1,x2,y2,c2);
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
        ForceLogMessage('Delete expired hint '+inttohex(cardinal(control),8));
        painter.texman.FreeImage(HintImage);
        HintImage:=nil;
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
     painter.OverrideClipping;
     painter.DrawImage(x1,y1,HintImage,c);
     painter.ResetClipping;
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
     if bg<>0 then painter.FillRect(x1,y1,x2,y2,bg);
     painter.SetClipping(globalRect);
     //mY:=round(y1*0.3+y2*0.7)-topOffset;
     mY:=round((y1+y2)*0.5+painter.FontHeight(font)*0.45)-topOffset;
     wst:=DecodeUTF8(caption);
     if align=taLeft then
      painter.TextOutW(font,x1,mY,color,wst);
     if align=taRight then
      painter.TextOutW(font,x2,mY,color,wst,taRight);
     if align=taCenter then
      painter.TextOutW(font,(x1+x2) div 2,mY,color,wst,taCenter);
     if align=taJustify then
      painter.TextOutW(font,x1,mY,color,wst,taJustify,0,x2-x1);
     painter.ResetClipping;
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
      if pressed then c:=c-$181010;
      painter.FillGradRect(x1+1,y1+1,x2-1,y2-1,ColorAdd(c,$303030),ColorSub(c,$303030),true);
      c:=GetColor(control,2); if c=0 then c:=$60000000;
      c2:=GetColor(control,3); if c2=0 then c2:=$80FFFFFF;
      painter.ShadedRect(x1,y1,x2,y2,1,c,c2); // Внешняя рамка
      if pressed then { painter.ShadedRect(x1+2,y1+2,x2-1,y2-1,1,$80FFFFFF,$50000000)}
       else if enabled then begin
         c:=GetColor(control,4); if c=0 then c:=$A0FFFFFF;
         c2:=GetColor(control,5); if c2=0 then c2:=$70000000;
         painter.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,c,c2);
       end
         else painter.ShadedRect(x1+1,y1+1,x2-1,y2-1,1,$80FFFFFF,$50000000);
      // Нарисовать фокус (также если кнопка дефолтная и никакая другая не имеет фокуса)
      if (focusedControl=control) or
         (default and ((focusedControl=nil) or not (focusedControl is TUIButton))) then
       painter.Rect(x1-1,y1-1,x2+1,y2+1,$80FFFF80);
      // Вывод надписи (если есть)
      if caption<>'' then begin
       painter.SetClipping(Rect(x1+2,y1+2,x2-2,y2-2));
       c:=GetColor(control,1); if c=0 then c:=$FF000000;
       mY:=round(y1*0.5+y2*0.5+painter.FontHeight(font)*0.4); // учесть высоту шрифта!
       wSt:=DecodeUTF8(caption);
       if underMouse=control then c:=$FF300000;
       if enabled then
        painter.TextOutW(font,(x1+x2) div 2+d,mY+d,c,wst,taCenter)
       else begin
        painter.TextOutW(font,(x1+x2) div 2+1,mY+1,$E0FFFFFF,wSt,taCenter);
        painter.TextOutW(font,(x1+x2) div 2,mY,$80000000,wSt,taCenter);
       end;
       painter.ResetClipping;
      end;
     end else begin
      // кнопка - чекбокс или радиобокс
      if group=0 then begin
       // чекбокс
       v:=(y1+y2) div 2;
       if pressed then begin
        painter.DrawLine(x1+3,v,x1+6,v+4,color);
        painter.DrawLine(x1+6,v+4,x1+14,v-6,color);
        painter.DrawLine(x1+3,v-1,x1+7,v+3,color);
        painter.DrawLine(x1+6,v+3,x1+13,v-6,color);
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
       painter.ShadedRect(x1,v-8,x1+15,v+7,2,d,c);
      end else begin
       // радиобокс
      end;
      painter.SetClipping(Rect(x1+19,y1,x2,y2));
      v:=round(y1+(y2-y1)*0.65);
      if FocusedControl=control then
       painter.Rect(x1+19,y1,x1+painter.TextWidth(font,caption),y2,$40+color and $FFFFFF);
      if enabled then
       painter.TextOut(font,x1+20,v,color,caption)
      else begin
       painter.TextOut(font,x1+21,v+1,$60FFFFFF,caption);
       painter.TextOut(font,x1+20,v,ColorMix(color,$C0909090,200),caption);
      end;
      painter.ResetClipping;
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
    if c2=0 then painter.Rect(x1+i,y1+i,x2-i,y2-i,c1)
     else painter.ShadedRect(x1+i,y1+i,x2-i,y2-i,1,c1,c2);
   end;
  end;

 procedure DrawUIImage(control:TUIImage;x1,y1,x2,y2:integer);
  type
   TImageDrawProc=procedure(img:TUIImage);
  var
   img:THandle;
   lname:string;
   p:cardinal;
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
      lname:=lowercase(FileName(src));
      p:=imgHash.Get(lname);
      if p=0 then begin
       tex:=nil;
       LoadImage(tex,lname);
       imgHash.Put(lname,cardinal(tex),true);
      end else
       tex:=pointer(p);
      painter.DrawScaled(x1,y1,x2-1,y2-1,tex,control.color);
     end;
    end;
  end;

 procedure DrawUIWindow(control:TUIWindow;x1,y1,x2,y2:integer);
  var
   c:cardinal;
   tx,ty:integer;
  begin
    with control do begin
    painter.FillRect(x1,y1,x2,y2,color);
    if control=activeWnd then c:=$FF8080E0 // текущее окно
     else c:=$FFB0B0B0;
    c:=ColorMix(color,c,128);
    if resizeable then begin
      painter.FillRect(x1,y1,x2,y1+header-1,c);
      painter.FillRect(x1,y1+header,x1+wcFrameBorder-1,y2,c);
      painter.FillRect(x2-wcFrameBorder+1,y1+header,x2,y2,c);
      painter.FillRect(x1+wcFrameBorder,y2-wcFrameBorder+1,x2-wcFrameBorder,y2,c);
      painter.ShadedRect(x1+wcFrameBorder-1,y1+header-1,x2-wcFrameBorder+1,y2-wcFrameBorder+1,1,$80000000,$80FFFFFF);
    end else begin
      painter.FillRect(x1,y1,x2,y1+header-1,c);
      painter.ShadedRect(x1+3,y1+header-1,x2-3,y1+header,1,$80000000,$80FFFFFF);
    end;
    painter.ShadedRect(x1,y1,x2,y2,2,$C0FFFFFF,$C0000000);

    painter.SetClipping(Rect(x1+2,y1+2,x2-2,y1+header-2));
    tx:=(x1+x2) div 2;
    ty:=y1+round(header*0.7);
    painter.TextOut(font,tx+1,ty+1,$B0000000,DecodeUTF8(caption),taCenter);
    painter.TextOut(font,tx,ty,$FFFFFFD0,DecodeUTF8(caption),taCenter);
    painter.ResetClipping;
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
     painter.FillGradrect(x1,y1,x2,y2,d,c,true);
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
       painter.FillGradrect(x1+i,y1,x1+j,y2,colorMix(v,$FFC0E0F0,192),colorMix(v,$FF0000A0,192),true);
       if (hooked=control) then painter.ShadedRect(x1+i,y1,x1+j,y2,1,d,d)
        else painter.ShadedRect(x1+i,y1,x1+j,y2,1,c,d);
       i:=x1+(i+j) div 2;
       painter.ShadedRect(i-2,y1+3,i-1,y2-3,1,d,c);
       painter.ShadedRect(i+1,y1+3,i+2,y2-3,1,d,c);
      end;
     end;
    end else begin
     // Vertical scrollbar
     painter.FillGradrect(x1,y1,x2,y2,d,c,false);
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
       painter.FillGradrect(x1,y1+i,x2,y1+j,colorMix(v,$FFC0E0F0,192),colorMix(v,$FF0000A0,192),false);
       if (hooked=control) then painter.ShadedRect(x1,y1+i,x2,y1+j,1,d,d)
        else painter.ShadedRect(x1,y1+i,x2,y1+j,1,c,d);
       i:=y1+(i+j) div 2;
       painter.ShadedRect(x1+3,i-2,x2-3,i-1,1,d,c);
       painter.ShadedRect(x1+3,i+1,x2-3,i+2,1,d,c);
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
     painter.FillRect(x1,y1,x2,y2,c);
    end;
    if not noborder then begin
     painter.RRect(x1-1,y1-1,x2+1,y2+1,$A0000000+color and $FFFFFF,1);
    end;

{    savey:=y1;
    savey2:=y2;
    inc(y1,((y2-y1)-painter.GetFontHeight) div 2);
    y2:=y1+painter.GetFontHeight;}
    wst:=realtext;
    if password then
      wst:=StringOfChar('*',length(wst));
    if (scroll.X>0) and (painter.TextWidthW(font,wst)<(x2-x1)) then Scroll.X:=0;
    i:=painter.TextWidthW(font,copy(wst,1,cursorpos)); // позиция курсора
//    if cursorpos>0 then dec(i);
    if i-scroll.X<0 then scroll.X:=i;
    if i-scroll.X>(x2-x1-5-offset) then scroll.X:=i-(x2-x1-5-offset);
    painter.SetClipping(Rect(x1+2,y1,x2-2,y2));
    my:=round(y1*0.47+y2*0.53+painter.FontHeight(font)*0.4);
    // Default text?
    if (realtext='') and (defaultText<>'') and (FocusedControl<>control) then begin
     painter.TextOutW(font,x1+2+offset,mY,ColorMix(color,$00808080,160),defaultText,taLeft,toDontTranslate);
     painter.ResetClipping;
     exit;
    end;
    scrollPixels:=round(scroll.X*globalScale.x);

    if needpos>=0 then begin
     cursorpos:=0;
     while (cursorpos<length(wst)) and
           (-scroll.X+painter.TextWidthW(font,copy(wst,1,cursorpos))<needPos-3) do
       inc(cursorpos);
     needpos:=-1;
    end;
    if completion<>'' then begin
     j:=x1+2-scrollPixels+painter.TextWidthW(font,wst);
     painter.TextOutW(font,j+offset,mY,ColorMix(color,$00808080,160),
       copy(completion,length(wst)+1,length(completion)),taLeft,toDontTranslate);
    end;
    if (selcount>0) and (focusedControl=control) then begin // часть текста выделена
     j:=x1+2-scrollPixels+offset;
     painter.TextOutW(font,j,mY,color,copy(wst,1,selstart-1),taLeft,toDontTranslate); // до выделения
     j:=j+painter.TextWidthW(font,copy(wst,1,selstart))-
          painter.TextWidthW(font,copy(wst,selstart,1));
     d:=painter.TextWidthW(font,copy(wst,selstart,selcount));
     painter.FillRect(j,y1+1,j+d-1,y2-1,ColorSub(color,$60202020));
     painter.TextOutW(font,j,mY,color and $FF000000,
        copy(wst,selstart,selcount),taLeft,toDontTranslate); // выделенная часть
     if selstart+selcount-1<=length(text) then begin
      j:=j+painter.TextWidthW(font,copy(wst,selstart,selcount+1))-
           painter.TextWidthW(font,copy(wst,selstart+selcount,1));
      painter.TextOutW(font,j,mY,color,
         copy(wst,selstart+selcount,length(wst)-selstart-selcount+1),taLeft,toDontTranslate); // остаток
     end;
    end else
     painter.TextOutW(font,x1+2-scrollPixels+offset,mY,color,wst,taLeft,toDontTranslate);
    painter.ResetClipping;
    if (focusedControl=control) and ((mytickcount-cursortimer) mod 360<200) then begin // курсор
     curX:=x1+2+i-scrollPixels+offset; // first pixel of the character
     painter.DrawLine(curX,y1+2,curX,y2-2,colorAdd(color,$404040));
//     painter.DrawLine(x1+4+i-scrollX,y1+2,x1+4+i-scrollX,y2-2,colorAdd(color,$404040));
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
     if bgColor<>0 then painter.FillRect(x1,y1,x2,y2,bgColor);
     if scrollerV<>nil then scr:=scrollerV.value
      else scr:=0;
     painter.SetClipping(Rect(x1,y1,x2+1,y2+1));
     for i:=0 to length(lines)-1 do begin
      lY:=y1+round(i*lineHeight-scr); /// TODO: check
      if lY+lineHeight<y1 then continue;
      if lY>y2 then break;
      if i=selectedLine then begin
       painter.FillRect(x1,lY,x2,round(lY+lineHeight),bgSelColor);
       c:=selTextColor;
      end else
      if i=hoverLine then begin
       painter.FillRect(x1,lY,x2,round(lY+lineHeight),bgHoverColor);
       c:=hoverTextColor;
      end else
       c:=textColor;
      painter.TextOut(font,x1+4,lY+round(lineHeight*0.73),c,lines[i],taLeft,toComplexText);
     end;
     painter.ResetClipping;
    end;
  end;

 procedure DrawUIComboBox(x1,y1,x2,y2:integer;combo:TUIComboBox);
  var
   st:string;
   i,cx,cy:integer;
   c:cardinal;
  begin
   if (undermouse=combo) or combo.frame.visible then
    painter.FillGradrect(x1+1,y1+1,x2-1,y2-1,$FFFFFFFF,$FFE0E0DC,true)
   else
    painter.FillGradrect(x1+1,y1+1,x2-1,y2-1,$FFE0E0DC,$FFFFFFFF,true);

   painter.RRect(x1,y1,x2,y2,$80000000,1);
   if FocusedControl=combo then
    painter.RRect(x1,y1,x2,y2,$90A00000);
   with combo do begin
    if (length(items)>0) and (curItem>=0) and (curItem<=high(items)) or
       (curItem<0) and (defaultText<>'') then begin
     painter.SetClipping(Rect(x1+1,y1+1,x2-21,y2-1));
     if curItem>=0 then st:=items[curItem]
      else st:=defaultText;
     painter.TextOutW(combo.font,x1+5,round(y2*0.7+y1*0.3),$FF000000,st);
     painter.ResetClipping;
    end;
    // Arrow
    cx:=x2-round((y2-y1)*0.4);
    cy:=(y1+y2) div 2-1;
    c:=$FF000000;
    for i:=0 to 2 do begin
     painter.DrawLine(cx,cy+2+i,cx-4,cy-2+i,c);
     painter.DrawLine(cx,cy+2+i,cx+4,cy-2+i,c);
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
 StyleDrawers[0]:=DefaultDrawer;
 imgHash.Init;
end.
