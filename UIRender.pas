// -----------------------------------------------------
// User Interface rendering block
//
// Author: Ivan Polyacov (C) 2003-2014, Apus Software
// Mail me: ivan@games4win.com or cooler@tut.by
// ------------------------------------------------------
unit UIRender;
interface
 uses EngineCls,UIClasses;
 type
  // процедура отрисовки элемента
  TUIDrawer=procedure(control:TUIControl);

 // Процедура выполняет отрисовку элемента интерфейса (включая все вложенные элементы)
 // в соответствиии с их стилями и установленными отрисовщиками
 procedure DrawUI(root:TUIControl;customDraw:boolean=false);

 procedure DrawGlobalShadow(color:cardinal);

 // Установить отрисовщик для заданого стиля (стиль - от 1 до 50),
 // 0..9 - reserved for engine styles
 // 10..19 - for private game styles
 // 20..50 - 3-rd party libraries
 procedure RegisterUIStyle(style:byte;drawer:TUIDrawer;name:string='');

 procedure DefaultDrawer(control:TUIControl);

 procedure BuildSimpleHint(hnt:TUIHint);

 // Рисует указанное изображение по размеру заданного элемента UI
 procedure DrawControlWithImage(c:TUIControl;img:TTexture);

 var
  // Глобальная переменная для отрисовщиков: может содержать время, прошедшее с
  // предыдущей отрисовки (время кадра), но может содержать и 0
  frameTime:int64;

  transpBgnd:boolean=false; // Отрисовка на прозрачный фон?

  defaultHintFont:cardinal=0; // Шрифт, которым показываются хинты

implementation
 uses CrossPlatform,images,SysUtils,types,myservis,engineTools,ImageMan,colors,structs,EventMan;

 var
  StyleDrawers:array[0..50] of TUIDrawer;

  HintImage:TTexture;

  imgHash:THash;

 procedure DrawGlobalShadow(color:cardinal);
  begin
   painter.FillRect(0,0,game.renderWidth,game.renderHeight,color);
  end;  

 procedure DrawUI(root:TUIControl;customDraw:boolean=false);
  var
   i,j,n,cnt:integer;
   tmp:pointer;
   r:TRect;
   list:array of TUIControl;
  begin
   if not root.visible then exit;
   if (root.width<=0) or (root.height<=0) then exit;
   // Сначала нарисовать себя
   root.globalRect:=root.GetPosOnScreen;
   if (root.parent<>nil) and (root.parent.transpmode<>tmTransparent) then
    painter.SetMask(true,false);
   try
    // Draw control
    if (root.customDraw=customDraw) and
       (root.style>=0) and
       (root.style<=high(styleDrawers)) then StyleDrawers[root.style](root);
    // Highlight
    if (game.shiftState and $F=$E) then
     if (root=underMouse) or
        ((underMouse<>nil) and (root=underMouse.parent)) then
       with root.globalRect do begin
         painter.Rect(left,top,right-1,bottom-1,$80FFFFFF xor ($FFFFFF*((MyTickCount shr 8) and 1)));
       end;
   except
    on E:Exception do begin
     ForceLogMessage('Error drawing control '+root.name+' - '+ExceptionMsg(e));
     sleep(0);
    end;
   end;
   // List of child elements to draw
   n:=length(root.children);
   cnt:=0;
   for i:=0 to n-1 do
    if root.children[i].visible then inc(cnt);
   SetLength(list,cnt);
   cnt:=0;
   for i:=0 to n-1 do
    if root.children[i].visible then begin
     list[cnt]:=root.children[i]; inc(cnt);
    end;

   if cnt>0 then begin
    r:=root.globalRect;
    inc(r.Left,root.ncLeft); inc(r.top,root.ncTop);
    dec(r.Right,root.ncRight); dec(r.Bottom,root.ncBottom);
    painter.SetClipping(r);
    // Затем отсортировать и нарисовать вложенные эл-ты
    for i:=0 to cnt-2 do
     for j:=cnt-1 downto i+1 do
      if list[j].order<list[j-1].order then begin
       tmp:=list[j];
       list[j]:=list[j-1];
       list[j-1]:=tmp;
      end;
    for i:=0 to cnt-1 do begin
     // если элемент не клипится и фон - не прозрачный - нарисовать без отсечения
     if not list[i].parentClip and not transpBgnd then begin
      painter.OverrideClipping;
      DrawUI(list[i]);
      painter.ResetClipping;
     end else
      DrawUI(list[i]);
    end;
    painter.ResetClipping;
   end;
   // вернуть маску назад
   if (root.parent<>nil) and (root.parent.transpmode<>tmTransparent) then
    painter.ResetMask;
  end;

 procedure RegisterUIStyle(style:byte;drawer:TUIDrawer;name:string='');
  begin
   ASSERT(style in [1..50]);
   StyleDrawers[style]:=drawer;
   if name<>'' then LogMessage(Format('UI style registered: %d - %s',[style,name]));
  end;

 procedure BuildSimpleHint(hnt:TUIHint);
  var
   sa:StringArr;
   wsa:WStringArr;
   i,h:integer;
  begin
   with hnt do begin
    hnt.simpleText:=StringReplace(hnt.simpleText,'~','\n',[rfReplaceAll]);
    sa:=split('\n',hnt.simpleText,'"');
    wsa:=DecodeUTF8A(sa);
    if font=0 then font:=defaultHintFont;
    if font=0 then font:=painter.GetFont('Default',7);
    h:=round(painter.FontHeight(font)*1.5);
    height:=h*length(sa)+8;
    width:=0;
    for i:=1 to length(sa) do
     if width<painter.TextWidthW(font,wsa[i-1]) then
      width:=painter.TextWidthW(font,wsa[i-1]);
    inc(width,10);
    LogMessage('[Re]alloc hint image');
    if HintImage<>nil then texman.FreeImage(HintImage);
    HintImage:=texman.AllocImage(width,height,pfRTAlphaNorm,aiTexture+aiRenderTarget,'UI_HintImage');
    if hintImage=nil then
      raise EError.Create('Failed to alloc hint image!');
    painter.BeginPaint(hintImage);
    try
     painter.SetMask(true,true); // потенциально может вредить отрисовке следующих элементов
     painter.Clear(0,-1,-1);
     painter.FillRect(1,2,width-1,height-2,$80000000);
     painter.FillRect(2,1,width-2,height-1,$80000000);
     painter.FillGradrect(0,0,width-3,height-3,$FFFFFFD0,$FFE0E0A0,true);
     painter.Rect(0,0,width-3,height-3,$FF000000);
     painter.ResetMask;
     for i:=0 to length(sa)-1 do
      painter.TextOut(font,3,round(2+h div 7+(i+0.75)*h),$D0000000,sa[i]);
    finally
     painter.EndPaint;
    end;
   end;
  end;

 procedure AdjustHint(sx,sy:integer;hnt:TUIHint);
  begin
   with hnt do begin
    adjusted:=true;
    if (sx+width+2<game.renderWidth) then inc(x,4)
     else dec(x,sx+width-game.renderWidth);
    if (sy+height*2+4>game.renderHeight) then dec(y,height+4)
     else inc(y,20);
   end;
  end;

 procedure DrawControlWithImage(c:TUIControl;img:TTexture);
  var
   r:TRect;
  begin
   r:=c.GetPosOnScreen;
   with r do painter.DrawScaled(left,top,Right,bottom,img);
  end;

 {$R-}
 // styleinfo="00000000 11111111 22222222 33333333" - list of colors (hex)
 function GetColor(control:TUIControl;index:integer=0):cardinal;
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

 procedure DrawUIControl(control:TUIControl;x1,y1,x2,y2:integer);
  var
   i,c,c2:integer;
   st:string;
  begin
   if control.styleinfo='' then exit;
   c:=GetColor(control,0);
   c2:=GetColor(control,1);
   if c<>0 then begin
    if transpBgnd and (control.transpmode<>tmTransparent) then painter.SetMode(blMove);
    painter.FillRect(x1,y1,x2,y2,c);
    if transpBgnd then painter.SetMode(blAlpha);
   end;
   if c2<>0 then painter.Rect(x1,y1,x2,y2,c2);
  end;

 procedure DrawUIHint(control:TUIHint;x1,y1,x2,y2:integer);
  var
   v,sx,sy:integer;
   c:cardinal;
  begin
    with control as TUIHint do begin
     if pfRTAlphaNorm=ipfNone then exit;
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
      sx:=x; sy:=y;
      AdjustHint(x1,y1,control as TUIHint);
      inc(x1,x-sx); inc(x2,x-sx);
      inc(y1,y-sy); inc(y2,y-sy);
     end;
     if transpMode=tmOpaque then v:=(MyTickCount-created)*2
      else begin
       v:=256-(MyTickCount-created) div 2;
       if v<=0 then begin
        ForceLogMessage('Delete expired hint '+inttohex(cardinal(control),8));
        texman.FreeImage(HintImage);
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
     mY:=round(y1*0.3+y2*0.7)-topOffset;
     wst:=DecodeUTF8(caption);
     if align=taLeft then
      painter.TextOutW(font,x1,mY,color,wst);
     if align=taRight then
      painter.TextOutW(font,x2,mY,color,wst,taRight);
     if align=taCenter then
      painter.TextOutW(font,x1+width div 2,mY,color,wst,taCenter);
     if align=taJustify then
      painter.TextOutW(font,x1,mY,color,wst,taJustify,0,width);
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
      if c=0 then c:=$FFB0A0C0;
      d:=byte(pressed);
      if not enabled then c:=ColorMix(c,$FFA0A0A0,128);
      if enabled and (underMouse=control) then inc(c,$101010);
      if pressed then c:=c-$181010;
      painter.FillGradRect(x1+1,y1+1,x2-1,y2-1,ColorAdd(c,$303030),ColorSub(c,$303030),true);
      c:=GetColor(control,2); if c=0 then c:=$60000000;
      c2:=GetColor(control,3); if c=0 then c2:=$80FFFFFF;
      painter.ShadedRect(x1,y1,x2,y2,1,c,c2); // Внешняя рамка
      if pressed then { painter.ShadedRect(x1+2,y1+2,x2-1,y2-1,1,$80FFFFFF,$50000000)}
       else if enabled then begin
         c:=GetColor(control,4); if c=0 then c:=$A0FFFFFF;
         c2:=GetColor(control,5); if c=0 then c2:=$70000000;
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
        painter.TextOutW(font,x1+width div 2+d,mY+d,c,wst,taCenter)
       else begin
        painter.TextOutW(font,x1+width div 2+1,mY+1,$E0FFFFFF,wSt,taCenter);
        painter.TextOutW(font,x1+width div 2,mY,$80000000,wSt,taCenter);
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
   for i:=0 to control.ncLeft-1 do begin
    if c2=0 then painter.Rect(x1+i,y1+i,x2-i,y2-i,c1)
     else painter.ShadedRect(x1+i,y1+i,x2-i,y2-i,1,c1,c2);
   end;
  end;

 procedure DrawUIImage(control:TUIImage;x1,y1:integer);
  var
   img:THandle;
   lname:string;
   p:cardinal;
   tex:TTexture;
  begin
    with control do begin
     if src<>'' then begin
      if copy(src,1,6)='event:' then begin
       Signal(copy(src,7,200),PtrUInt(control));
       exit;
      end;
      lname:=lowercase(FileName(src));
      p:=imgHash.Get(lname);
      if p=0 then begin
       tex:=LoadImageFromFile(lname);
       imgHash.Put(lname,cardinal(tex),true);
      end else
       tex:=pointer(p);
      painter.DrawScaled(x1,y1,x1+control.width-1,y1+control.height-1,tex,control.color);
     end else begin
      img:=GetImageHandle('images\'+name);
      DrawImage(img,x1,y1,color,width,height,0,0);
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
{    painter.SetFont(font);
    painter.WriteSimple((x1+x2) div 2+1,y1+(header-painter.GetFontHeight) div 2+1,$B0000000,caption,taCenter);
    painter.WriteSimple((x1+x2) div 2,y1+(header-painter.GetFontHeight) div 2,$FFFFFFD0,caption,taCenter);}
    painter.ResetClipping;
   end;
  end;

 procedure DrawUIScrollbar(control:TUIScrollbar;x1,y1,x2,y2:integer);
  var
   c,d,v:cardinal;
   i,j:integer;
  begin
   with control do begin
    c:=colorAdd(color,$202020);
    d:=ColorSub(color,$202020);
    if horizontal then begin
     // Horizontal scrollbar
     painter.FillGradrect(x1,y1,x2,y2,d,c,true);
     if enabled and (width>=8) and (pagesize<max-min) then begin
      v:=colorMix(ColorAdd(color,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if over and not (hooked=control) then v:=ColorAdd(v,$101010);
      i:=round((width-10)*value/max);
      j:=9+round((width-10)*(value+pagesize)/max);
      if i<0 then i:=0;
      if j>=width then j:=width-1;
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
     if enabled and (height>=8) and (pagesize<max-min) then begin
      v:=colorMix(ColorAdd(color,$80101010),$FF6090C0,192);
      c:=colorMix(v,$FFFFFFFF,160);
      d:=colorMix(v,$FF404040,128);
      if over and not (hooked=control) then v:=ColorAdd(v,$101010);
      i:=round((height-10)*value/max);
      j:=9+round((height-10)*(value+pagesize)/max);
      if i<0 then i:=0;
      if j>=height then j:=height-1;
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
   i,j,mY,d,curX:integer;
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
    if (scrollX>0) and (painter.TextWidthW(font,wst)<(x2-x1)) then ScrollX:=0;
    i:=painter.TextWidthW(font,copy(wst,1,cursorpos)); // позиция курсора
//    if cursorpos>0 then dec(i);
    if i-scrollX<0 then scrollX:=i;
    if i-scrollX>(x2-x1-5-offset) then scrollX:=i-(x2-x1-5-offset);
    painter.SetClipping(Rect(x1+2,y1,x2-2,y2));
    my:=round(y1*0.47+y2*0.53+painter.FontHeight(font)*0.4);
    // Default text?
    if (realtext='') and (defaultText<>'') and (FocusedControl<>control) then begin
     painter.TextOutW(font,x1+2+offset,mY,ColorMix(color,$00808080,160),defaultText,taLeft,toDontTranslate);
     painter.ResetClipping;
     exit;
    end;

    if needpos>=0 then begin
     cursorpos:=0;
     while (cursorpos<length(wst)) and
           (-scrollX+painter.TextWidthW(font,copy(wst,1,cursorpos))<needPos-3) do
       inc(cursorpos);
     needpos:=-1;
    end;
    if completion<>'' then begin
     j:=x1+2-scrollX+painter.TextWidthW(font,wst);
     painter.TextOutW(font,j+offset,mY,ColorMix(color,$00808080,160),
       copy(completion,length(wst)+1,length(completion)),taLeft,toDontTranslate);
    end;
    if (selcount>0) and (focusedControl=control) then begin // часть текста выделена
     j:=x1+2-scrollX+offset;
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
     painter.TextOutW(font,x1+2-scrollX+offset,mY,color,wst,taLeft,toDontTranslate);
    painter.ResetClipping;
    if (focusedControl=control) and ((mytickcount-cursortimer) mod 360<200) then begin // курсор
     curX:=x1+2+i-scrollX+offset; // first pixel of the character
     painter.DrawLine(curX,y1+2,curX,y2-2,colorAdd(color,$404040));
//     painter.DrawLine(x1+4+i-scrollX,y1+2,x1+4+i-scrollX,y2-2,colorAdd(color,$404040));
    end;
   end;
  end;

 procedure DrawUIListBox(control:TUIListBox;x1,y1,x2,y2:integer);
  var
   i,lY,scr:integer;
   c,c1,c2:cardinal;
  begin
    with control as TUIListBox do begin
     if bgColor<>0 then painter.FillRect(x1,y1,x2,y2,bgColor);
     if scrollerV<>nil then scr:=scrollerV.value
      else scr:=0;
     painter.SetClipping(Rect(x1,y1,x2+1,y2+1));
     for i:=0 to length(lines)-1 do begin
      lY:=y1+i*lineHeight-scr;
      if lY+lineHeight<y1 then continue;
      if lY>y2 then break;
      if i=selectedLine then begin
       painter.FillRect(x1,lY,x2,lY+lineHeight,bgSelColor);
       c:=selTextColor;
      end else
      if i=hoverLine then begin
       painter.FillRect(x1,lY,x2,lY+lineHeight,bgHoverColor);
       c:=hoverTextColor;
      end else
       c:=textColor;
      painter.TextOut(font,x1+4,lY+round(lineHeight*0.71),c,lines[i],taLeft,toComplexText);
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
    cx:=x2-round(height*0.4);
    cy:=(y1+y2) div 2-1;
    c:=$FF000000;
    for i:=0 to 2 do begin
     painter.DrawLine(cx,cy+2+i,cx-4,cy-2+i,c);
     painter.DrawLine(cx,cy+2+i,cx+4,cy-2+i,c);
    end;
   end;
  end;

 // Отрисовщик по умолчанию
 procedure DefaultDrawer(control:TUIControl);
  var
   enabl:boolean;
   con:TUIControl;
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
   if control.ClassType=TUIControl then
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
    DrawUIImage(control as TUIImage,x1,y1)
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
