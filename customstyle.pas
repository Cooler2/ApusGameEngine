// Стандартный стиль для UI, позволяющий определять внешний вид элементов
// с использованием изображений
//
// Copyright (C) 2006 Apus Software (www.astralmasters.com)
// Author: Ivan Polyacov (cooler@tut.by)
{$R-}
unit customstyle;
interface
 uses UIClasses;

 var
  loadScrollBarTextures:boolean=false;

 // Инициализация стиля (id - на какой номер регистрировать стиль)
 // Вызывать ПОСЛЕ инициализации движка
 procedure InitCustomStyle(imgpath:string='Images\cstyle\';id:integer=1);

implementation
 uses classes,SysUtils,myservis,EngineCls,EngineTools,UIRender,colors,
      images,publics,uDict;
 type
  TAlphaMode=(amAuto,amSkip,amWrite);

  TButtonStyle=record
   name,lowname:string;
   width,height,offsetX,offsetY,textOffsetX,textOffsetY:integer;
   opacity,timeUp,timeDown:integer; // прозрачность imageOver и скорость ее нарастания/снижения
   image,imageOver,imageDown,imageDefault,imageFocused,imageDisabled:integer;
   imageColor,imageColorOver,imageColorDown,imageColorDisabled:cardinal;
   color,colorOver,colorDown,colorFocused,colorDisabled,ColorShadow,ColorShadowDisabled:cardinal;
   glow,glowboost,glowcolor,glowColorOver:cardinal;
   assigned:string;
   alphamode:TAlphaMode;
   alignment:TTextAlignment;
   underline:boolean;
   xRes,yRes:integer; // button images are for this resolution (0,0 - not scaled)
   scaleX,scaleY:single; // scale button images 
   procedure InitWithDefaultValues(bsName:string);
  end;

  TButtonImage=record
   fname:string;
   image:TTexture;
  end;
  
  TVarTypeCustomStyle=class(TVarTypeStruct)
   class function GetField(variable:pointer;fieldName:string;out varClass:TVarClass):pointer; override;
   class function ListFields:String; override;
  end;

  TVarTypeBtnStyle=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeAlphaMode=class(TVarTypeEnum)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeImageHandle=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

{  TCustomStyleCls=class(TPublishedClass)
   class function ReadVar(objname,varname:string):string; override;
   class function WriteVar(objname,varname,value:string):string; override;
  end;}
 var
  btnImages:array[1..300] of TButtonImage;
  btnImagesCnt:integer;
  btnStyles:array[1..120] of TButtonStyle;
  btnStylesCnt:integer;
  scrolltex,scroll1,scroll2:TTexture;

  hash:array[0..255] of byte;

  path:string; // путь к битмапкам

 function StrToAMode(s:string):TAlphaMode;
  begin
   result:=amAuto;
   s:=uppercase(s);
   if s='SKIP' then result:=amSkip;
   if s='WRITE' then result:=amWrite;
   if s='AUTO' then result:=amAuto;
  end;

 procedure DrawBtnImage(x,y:integer;img:TTexture;color:cardinal;scaleX:single=1;scaleY:single=1);
  begin
   if (scaleX=1) and (scaleY=1) then
    painter.DrawImage(x,y,img,color)
   else
    painter.DrawScaled(x,y,x+(img.width-1)*scaleX,y+(img.height-1)*scaleY,img,color);
  end;

 procedure DrawButton(but:TUIButton;sNum:integer;x1,y1,x2,y2:integer);
  var
   i,j,k,l,ix,iy,v:integer;
   col,col2,c:cardinal;
   sa:StringArr;
   mode:TTextAlignment;
   sx,sy:single;
  begin
   with but do begin
     if true then begin
      // обычная кнопка
      col:=color;
      if sNum>0 then begin
        i:=sNum;
        ix:=x1-btnStyles[i].offsetX;
        iy:=y1-btnStyles[i].offsetY;
        sx:=btnStyles[i].scaleX;
        sy:=btnStyles[i].scaleY;

        v:=btnStyles[i].opacity;
        if not enabled then tag:=0;
        if enabled and (undermouse=but) then begin
         if btnStyles[i].timeUp>0 then inc(tag,round(20*v/btnStyles[i].timeUp))
          else tag:=v;
         if tag>v then tag:=v;
        end else begin
         if btnStyles[i].timeDown>0 then dec(tag,round(20*v/btnStyles[i].timeDown))
          else tag:=0;
         if tag<0 then tag:=0;
        end;

        // Обычное состояния
        if (enabled or (btnStyles[i].imageDisabled=0)) and (btnStyles[i].image<>0) then begin
         // не рисовать если наведено и переходы мгновенны
         if (tag>0) and enabled and (btnStyles[i].timeUp=0) and
           (btnStyles[i].timeDown=0) or
           (pressed and (btnStyles[i].imageDown<>0)) then
         else begin
          c:=ColorMix(btnStyles[i].imageColorOver,btnStyles[i].imageColor,tag);
          if pressed then c:=btnStyles[i].imageColorDown;
          DrawBtnImage(ix,iy,btnImages[btnStyles[i].image].image,c,sx,sy);
         end;
        end;
        // Кнопка недоступна
        if not enabled and (btnStyles[i].imageDisabled<>0) then
         DrawBtnImage(ix,iy,btnImages[btnStyles[i].imageDisabled].image,btnStyles[i].imageColorDisabled,sx,sy);
        // Нажатое состояние
        if (pressed) and (btnStyles[i].imageDown<>0) then
         DrawBtnImage(ix,iy,btnImages[btnStyles[i].imageDown].image,btnStyles[i].imageColorDown,sx,sy);
        // Кнопка по умолчанию
        if (default) and (btnStyles[i].imageDefault<>0) then
         DrawBtnImage(ix,iy,btnImages[btnStyles[i].imageDefault].image,btnStyles[i].imageColor,sx,sy);
        // Кнопка имеет фокус
        if (focusedControl=but) and (btnStyles[i].imageFocused<>0) then
         DrawBtnImage(ix,iy,btnImages[btnStyles[i].imageFocused].image,btnStyles[i].imageColor,sx,sy);
        // Подсветка
        if enabled and (tag>0) and not pressed then
         if btnStyles[i].imageOver<>0 then begin
          if (btnstyles[i].timeUp=0) and (btnstyles[i].timeDown=0) then
           DrawBtnImage(ix,iy,btnImages[btnStyles[i].imageOver].image,btnstyles[i].imageColorOver,sx,sy)
          else // для подсветки используется отдельное изображение, прозрачность которого уменьшается до opacity
           DrawBtnImage(ix,iy,btnImages[btnStyles[i].imageOver].image,$808080+tag shl 24,sx,sy);
         end;

        ix:=btnStyles[i].textOffsetX;
        iy:=btnStyles[i].textOffsetY;
        // Вычисление цвета надписи
        col2:=btnStyles[i].ColorShadow;
        if btnStyles[i].color<>0 then col:=btnStyles[i].color;
        if not pressed and (focusedControl=but) and (btnStyles[i].colorFocused<>0) then
          col:=btnStyles[i].colorFocused;
        if not enabled then begin
          if btnStyles[i].colorDisabled<>0 then col:=btnStyles[i].colorDisabled;
          if btnStyles[i].colorShadowDisabled<>0 then col2:=btnStyles[i].ColorShadowDisabled;
        end;
        if tag>0 then col:=ColorMix(btnStyles[i].colorOver,col,tag);
        if pressed and (btnStyles[i].colorDown<>0) then col:=btnStyles[i].colorDown;

        // Вывод надписи (если есть)
        if caption<>'' then begin
         // перевод ДО разделения на подстроки!
         sa:=Split('~',translate(caption),#0);
         painter.SetClipping(Rect(x1+4,y1+2,x2-4,y2-2));
         painter.SetFont(font);
         painter.TextColorX2:=true;
         if btnStyle=bsCheckbox then begin
          ix:=x1+24+ix; iy:=y1+2+iy;
          mode:=taLeft;
         end else begin
          iy:=y1+((height-2-painter.GetFontHeight*length(sa)) div 2)+byte(pressed)+iy;
          mode:=btnstyles[i].alignment;
          if mode=taJustify then mode:=taCenter;
          if mode=taCenter then ix:=x1+width div 2+byte(pressed)+ix else
          if mode=taLeft then ix:=ix+x1+byte(pressed)+width div 6 else
          if mode=taRight then ix:=ix+x1+byte(pressed)+width*7 div 8;
         end;
         if btnstyles[i].glow>0 then with painter do begin
          fillchar(textEffects[1],sizeof(textEffects[1]),0);
          textEffects[1].enabled:=true;
          textEffects[1].blur:=btnstyles[i].glow/10;
          textEffects[1].fastblurX:=btnstyles[i].glow div 20;
          textEffects[1].fastblurY:=btnstyles[i].glow div 20;
          texteffects[1].color:=btnstyles[i].glowcolor;
          textEffects[2].enabled:=false;
          if btnstyles[i].glowBoost<>0 then
           textEffects[1].power:=btnstyles[i].glowBoost/10;
          for i:=0 to length(sa)-1 do
           WriteEx(ix,iy+i*painter.GetFontHeight,col,sa[i],mode);
         end else begin
          // Вывод обычным текстом (тут всё устаревшее и требует переосмысления)
          for j:=0 to length(sa)-1 do begin
           if col2<>0 then begin
            i:=1+(painter.GetFontHeight-10) div 12;
            painter.WriteSimple(ix+i,iy+i,col2,sa[j],mode);
            if btnStyles[i].underline then begin
             k:=round(painter.GetFontHeight*0.96);
             painter.DrawLine(ix+i,iy+i+k,ix+i+painter.GetTextWidth(sa[j]),iy+i+k,col2);
            end;
           end;
           painter.TextOut(font,ix,iy,col,sa[j],mode,toAddBaseline);
//           painter.WriteSimple(ix,iy,col,sa[j],mode);
           if btnStyles[i].underline then begin
            col:=ColorMult2(col,$80FFFFFF);
            k:=round(painter.GetFontHeight*0.96);
            l:=painter.GetTextWidth(sa[j]);
            if mode=taLeft then
             painter.DrawLine(ix,iy+k,ix+l,iy+k,col);
            if mode=taCenter then
             painter.DrawLine(ix-l div 2,iy+k,ix+l div 2,iy+k,col);
            if mode=taRight then
             painter.DrawLine(ix-l,iy+k,ix,iy+k,col);
           end;
           inc(iy,painter.GetFontHeight);
           if j=0 then inc(ix);
          end;
         end;
         painter.TextColorX2:=false;
         painter.ResetClipping;
        end;

      end; // style>0
     end; // true
   end;
  end;

 procedure CustomStyleHandler(control:TUIControl);
  var
   i,j,k,l:integer;
   img:TObject;
   timg:TTexture;
   enabl:boolean;
   con:TUIControl;
   x1,y1,x2,y2,ix,iy,v:integer;
   col,col2:cardinal;
   c,d:cardinal;
   bool:boolean;
   int,sNum:integer;
  begin
   // Определение общих св-в элемента
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

   // Элемент - окно
   if control is TUISkinnedWindow then with control as TUISkinnedWindow do begin
    if background<>nil then begin    // нарисовать фон окна
     if TranspBgnd then painter.SetMode(blMove);
     img:=background;
     if img is TLargeImage then
      (img as TLargeImage).Draw(globalRect.Left,globalRect.Top,color);
     if img is TTexture then
      painter.DrawImage(globalRect.Left,globalRect.Top,img as TTexture,color);
     if TranspBgnd then painter.SetMode(blAlpha);
    end;
   end;

   // Полоса прокрутки
   if control is TUIScrollBar then with control as TUIScrollBar do begin
    v:=colorMix(color,$40101010,96);
    c:=colorAdd(v,$202020);
    d:=ColorSub(v,$202020);
    if horizontal then begin
     // горизонтальная

    end else begin
     // вертикальная
     painter.FillGradrect(x1,y1,x2,y2,d,c,false);
     if enabled and (height>=16) and (pagesize<max-min) then begin
      c:=colorMix(color,$FF909090,128);
      if over and not (hooked=control) then c:=ColorAdd(c,$101010);
      i:=round((height-16)*value/max);
      j:=15+round((height-16)*(value+pagesize)/max);
      if i<0 then i:=0;
      if j>=height then j:=height-1;
      if j>i+15 then begin
       d:=(j-i)*8+round(sqrt((j-i)*10));
       painter.TexturedRect(x1,y1+i,x2,y1+j,scrollTex,0.02,0.5-d/1000,0.98,0.5-d/1000,0.98,0.5+d/1000,c);
       c:=colorAdd(c,$101010);
       painter.DrawScaled(x1,y1+j-10,x2,y1+j,scroll2,c);
       painter.DrawScaled(x1,y1+i,x2,y1+i+10,scroll1,c);
      end;
     end;
    end;
   end;

   // Поиск стиля
   sNum:=0;
   j:=(cardinal(control) div 3) and $FF;
   i:=hash[j];
   if (i>0) then
    if ((control.styleinfo<>'') and (UpperCase(btnstyles[i].name)=UpperCase(control.styleinfo))) or
       ((btnStyles[i].assigned<>'') and (pos(UpperCase(control.name)+',',btnStyles[i].assigned)>0)) or
       ((btnStyles[i].assigned='') and
        (control.styleinfo='') and
        (btnStyles[i].width=control.width) and
        (btnStyles[i].height=control.height)) then begin
     sNum:=i;
    end;
   if sNum=0 then
   for i:=1 to btnStylesCnt do
    if ((control.styleinfo<>'') and (UpperCase(btnstyles[i].name)=UpperCase(control.styleinfo))) or
       ((btnStyles[i].assigned<>'') and (pos(UpperCase(control.name)+',',btnStyles[i].assigned)>0)) or
       ((btnStyles[i].assigned='') and
        (control.styleinfo='') and
        (btnStyles[i].width=control.width) and
        (btnStyles[i].height=control.height)) then begin
     sNum:=i; break;
    end;
   if (sNum>0) then hash[j]:=sNum;

   if (snum>0) and (btnStyles[snum].alphamode<>amAuto) then begin
    if btnStyles[snum].alphamode=amSkip then painter.SetMask(true,false)
     else painter.SetMask(true,true);
   end;


   // поле ввода
   if control.ClassType=TUIEditBox then
    with control as TUIEditbox do begin
      if sNum>0 then begin
        ix:=x1-btnStyles[sNum].offsetX;
        iy:=y1-btnStyles[sNum].offsetY;
        if btnStyles[sNum].image=0 then
         raise EError.create('InpBox style has no image');
        painter.DrawImage(ix,iy,btnImages[btnStyles[i].image].image,$FF808080);
      end;
      bool:=noborder;
      int:=backgnd;
      noborder:=true;
      backgnd:=0;
      DefaultDrawer(control);
      noborder:=bool;
      backgnd:=int;
    end;

   // Кнопка
   if control.ClassType=TUIButton then
    DrawButton(control as TUIButton,sNum,x1,y1,x2,y2);
  end;

 procedure InitCustomStyle;
  begin
   LogMessage('Custom style init');
   path:=imgpath;
   if not (path[length(path)] in ['\','/']) then path:=path+'\';
   if loadScrollBarTextures then begin
    scrollTex:=LoadImageFromFile(path+'scrolltex',liffTexture,pfTrueColorAlpha);
    scroll1:=LoadImageFromFile(path+'scroll_top',liffMH512,pfTrueColorAlpha);
    scroll2:=LoadImageFromFile(path+'scroll_bottom',liffMH512,pfTrueColorAlpha);
   end;
   RegisterUIStyle(id,CustomStyleHandler);
   // адрес произвольный ибо объект уникальный
   PublishVar(@CustomStyleHandler,'CustomStyle',TVarTypeCustomStyle);
  end;

 // Возвращает хэндл изображения, если надо - загружает его
 function ImageHandle(name:string):integer;
  var
   i:integer;
   qual:string;
   pf:ImagePixelFormat;
  begin
   result:=0;
   i:=pos(',',name);
   if i>0 then begin
    qual:=copy(name,i+1,length(name)-i);
    SetLength(name,i-1);
   end;
   for i:=1 to btnImagesCnt do
    if (btnImages[i].fname=name) and (btnImages[i].image<>nil) then begin
//     ASSERT(btnImages[i].image<>nil,inttostr(i)+' '+name);
     result:=i; exit;
    end;
   inc(btnImagesCnt);
   with btnImages[btnImagesCnt] do begin
    fname:=name;
    pf:=pfTrueColorAlpha;
    if qual='LOW' then pf:=pfTrueColorAlphaLow;
    image:=LoadImageFromFile(path+fname,liffMH512,pf);
    ASSERT(image<>nil);
   end;
   result:=btnImagesCnt;
  end;

procedure TButtonStyle.InitWithDefaultValues(bsName:string);
 begin
  // Defaults
  opacity:=255;
  timeUp:=0;
  timeDown:=0;
  name:=bsName;
  lowname:=lowercase(bsName);
  imageColor:=$FF808080;
  imageColorOver:=$FF808080;
  imageColorDown:=$FF808080;
  imageColorDisabled:=$FF808080;
  alignment:=taJustify;
  xRes:=0; yRes:=0;
  scaleX:=1; scaleY:=1;
 end;

function NewButtonStyle(name:string):integer;
 begin
  if btnStylesCnt>=120 then raise EError.Create('CustomStyle: out of style groups');
  inc(btnStylesCnt);
  result:=btnStylesCnt;
  fillchar(btnStyles[result],sizeof(TButtonStyle),0);
  btnStyles[result].InitWithDefaultValues(name);
 end;

{ TVarTypeCustomStyle }

class function TVarTypeCustomStyle.GetField(variable: pointer;
  fieldName: string; out varClass: TVarClass): pointer;
var
 i,n:integer;
 grp,prop:string;
 item:^TButtonStyle;
 st:string;
begin
 // varname = "group\property" либо "groupName"
 i:=pos('\',fieldname);
 if i=0 then begin
  fieldname:=lowercase(fieldname);
  for i:=1 to btnStylesCnt do
   if btnStyles[i].lowname=fieldname then begin
    result:=@btnStyles[i];
    varClass:=TVarTypeBtnStyle;
   end;
  // группы с таким именем нет => создать
  n:=NewButtonStyle(fieldname);
  result:=@btnStyles[n];
  varClass:=TVarTypeBtnStyle;
 end else begin
  grp:=copy(fieldname,1,i-1);
  prop:=copy(fieldname,i+1,length(fieldname)-i);
  if length(grp)=0 then raise EWarning.Create('Invalid style group name');
  if length(prop)=0 then raise EWarning.Create('Invalid style property');
  n:=0;
  st:=lowercase(grp);
  prop:=uppercase(prop);
  for i:=1 to btnStylesCnt do
   if btnStyles[i].lowname=st then begin n:=i; break; end;
  if n=0 then
   n:=NewButtonStyle(grp);
  item:=@btnStyles[n];
  result:=nil; varClass:=nil;
  case prop[1] of
   'A':begin
     if prop='ALPHAMODE' then begin
       result:=@item^.alphamode; varClass:=TVarTypeAlphaMode;
     end else
     if prop='ALIGNMENT' then begin
       result:=@item^.alignment; varClass:=TVarTypeAlignment;
     end
   end;
   'C':begin
     if prop='COLOR' then begin
       result:=@item^.color; varClass:=TVarTypeARGB;
     end else
     if prop='COLOROVER' then begin
       result:=@item^.colorover; varClass:=TVarTypeARGB;
     end else
     if prop='COLORDOWN' then begin
       result:=@item^.colordown; varClass:=TVarTypeARGB;
     end else
     if prop='COLORDISABLED' then begin
       result:=@item^.colordisabled; varClass:=TVarTypeARGB;
     end else
     if prop='COLORFOCUSED' then begin
       result:=@item^.colorfocused; varClass:=TVarTypeARGB;
     end;
   end;
   'G':begin
     if prop='GLOW' then begin
       result:=@item^.glow; varClass:=TVarTypeCardinal;
     end else
     if prop='GLOWBOOST' then begin
       result:=@item^.glowboost; varClass:=TVarTypeCardinal;
     end else
     if prop='GLOWCOLOR' then begin
       result:=@item^.glowcolor; varClass:=TVarTypeARGB;
     end else
     if prop='GLOWCOLOROVER' then begin
       result:=@item^.glowcolorover; varClass:=TVarTypeARGB;
     end;
   end;
   'I':begin
     if prop='IMAGE' then begin
       result:=@item^.image; varClass:=TVarTypeImageHandle;
     end else
     if prop='IMAGEOVER' then begin
       result:=@item^.imageover; varClass:=TVarTypeImageHandle;
     end else
     if prop='IMAGEDOWN' then begin
       result:=@item^.imagedown; varClass:=TVarTypeImageHandle;
     end else
     if prop='IMAGECOLOR' then begin
       result:=@item^.imageColor; varClass:=TVarTypeARGB;
     end else
     if prop='IMAGECOLOROVER' then begin
       result:=@item^.imageColorOver; varClass:=TVarTypeARGB;
     end else
     if prop='IMAGECOLORDOWN' then begin
       result:=@item^.imageColorDown; varClass:=TVarTypeARGB;
     end else
     if prop='IMAGECOLORDISABLED' then begin
       result:=@item^.imageColorDisabled; varClass:=TVarTypeARGB;
     end else
     if prop='IMAGEDISABLED' then begin
       result:=@item^.imagedisabled; varClass:=TVarTypeImageHandle;
     end else
     if prop='IMAGEFOCUSED' then begin
       result:=@item^.imagefocused; varClass:=TVarTypeImageHandle;
     end else
     if prop='IMAGEDEFAULT' then begin
       result:=@item^.imagedefault; varClass:=TVarTypeImageHandle;
     end;
   end;
   'O':begin
     if prop='OFFSETX' then begin
       result:=@item^.offsetX; varClass:=TVarTypeInteger;
     end else
     if prop='OFFSETY' then begin
       result:=@item^.offsetY; varClass:=TVarTypeInteger;
     end else
     if prop='OPACITY' then begin
       result:=@item^.opacity; varClass:=TVarTypeInteger;
     end;
   end;
   'S':begin
     if prop='SHADOW' then begin
       result:=@item^.colorShadow; varClass:=TVarTypeARGB;
     end else
     if prop='SHADOWDISABLED' then begin
       result:=@item^.colorShadowDisabled; varClass:=TVarTypeARGB;
     end else
     if prop='SCALEX' then begin
       result:=@item^.scaleX; varClass:=TVarTypeSingle;
     end else
     if prop='SCALEY' then begin
       result:=@item^.scaleY; varClass:=TVarTypeSingle;
     end;
   end;
   'T':begin
     if prop='TEXTOFFSETX' then begin
       result:=@item^.textOffsetX; varClass:=TVarTypeInteger;
     end else
     if prop='TEXTOFFSETY' then begin
       result:=@item^.textOffsetY; varClass:=TVarTypeInteger;
     end else
     if prop='TIMEUP' then begin
       result:=@item^.timeUp; varClass:=TVarTypeInteger;
     end else
     if prop='TIMEDOWN' then begin
       result:=@item^.timeDown; varClass:=TVarTypeInteger;
     end;
   end;
   'U':begin
     if prop='UNDERLINE' then begin
       result:=@item^.underline; varClass:=TVarTypeBool;
     end;
   end;
   'X':
     if prop='XRES' then begin
       result:=@item^.xRes; varClass:=TVarTypeInteger;
     end;
   'Y':
     if prop='YRES' then begin
       result:=@item^.yRes; varClass:=TVarTypeInteger;
     end;
  end; // case
 end;
end;

class function TVarTypeCustomStyle.ListFields: String;
 var
  i:integer;
 begin
  result:='';
  for i:=1 to btnStylesCnt do begin
   result:=result+btnStyles[i].name;
   if i<btnStylesCnt then result:=result+',';
  end;
 end;

{ TVarTypeImageHandle }

class function TVarTypeImageHandle.GetValue(variable: pointer): string;
 var
  h:integer;
 begin
  h:=PInteger(variable)^;
  ASSERT((h>=1) and (h<=high(btnImages)));
  result:=btnImages[h].fname;
 end;

class procedure TVarTypeImageHandle.SetValue(variable: pointer; v: string);
 begin
  PInteger(variable)^:=ImageHandle(v);
 end;

class function TVarTypeAlphaMode.GetValue(variable: pointer): string;
 var
  a:^TAlphaMode;
 begin
  a:=variable;
  case a^ of
   amSkip:result:='Skip';
   amWrite:result:='Write';
   amAuto:result:='Auto';
  end;
 end;

class procedure TVarTypeAlphaMode.SetValue(variable: pointer; v: string);
 var
  a:^TAlphaMode;
 begin
  a:=variable;
  a^:=StrToAMode(v);
 end;

{ TVarTypeBtnStyle }

class function TVarTypeBtnStyle.GetValue(variable: pointer): string;
 begin

 end;

class procedure TVarTypeBtnStyle.SetValue(variable: pointer; v: string);
 var
  i,n:integer;
  b:^TButtonStyle;
  name,lowname:string;
 begin
  v:=lowercase(v);
  b:=variable;
  for i:=1 to btnStylesCnt do
   if btnStyles[i].lowname=v then begin
    name:=b^.name;
    lowname:=b^.lowname;
    b^:=btnstyles[i];
    b^.name:=name;
    b^.lowname:=lowname;
    exit;
   end;
  raise EWarning.Create('No such group to assign - '+v);
 end;

end.
