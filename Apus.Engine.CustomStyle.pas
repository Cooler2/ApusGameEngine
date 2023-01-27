// Стандартный стиль для UI, позволяющий определять внешний вид элементов
// с использованием изображений
//
// Copyright (C) 2006 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R-}
unit Apus.Engine.CustomStyle;
interface
 uses Apus.Engine.UI;
 var
  loadScrollBarTextures:boolean=false;

 // Инициализация стиля (id - на какой номер регистрировать стиль)
 // Вызывать ПОСЛЕ инициализации движка
 procedure InitCustomStyle(imgpath:string='Images\cstyle\';styleID:integer=1);
 procedure ApplyCustomStyle(item:TUIElement;styleName:string);

implementation
 uses Classes,SysUtils, Types,
  Apus.Common, Apus.Colors, Apus.Images, Apus.Publics, Apus.Geom2D,
  Apus.Engine.API, Apus.Engine.UITypes, Apus.Engine.UIWidgets,
  Apus.Engine.UIRender, Apus.Engine.UIScript;

 type
  TAlphaMode=(amAuto,amSkip,amWrite);

  PButtonStyle=^TButtonStyle;
  TButtonStyle=record
   name,lowname:string;
   width,height,textOffsetX,textOffsetY:integer;
   offsetX,offsetY:single;
   opacity,timeUp,timeDown:integer; // прозрачность imageOver и скорость ее нарастания/снижения
   image,imageOver,imageDown,imageDefault,imageFocused,imageDisabled:integer;
   imageColor,imageColorOver,imageColorDown,imageColorDisabled:cardinal;
   color,colorOver,colorDown,colorFocused,colorDisabled,ColorShadow,ColorShadowDisabled:cardinal;
   glow,glowboost,glowcolor,glowColorOver:cardinal;
   assigned:string;
   alphamode:TAlphaMode;
   alignment:TTextAlignment;
   underline:boolean;
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
  customStyleID:integer;

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

 procedure DrawBtnImage(pos:TPoint2s;img:TTexture;color:cardinal;scaleX:single=1;scaleY:single=1);
  begin
   draw.RotScaled(pos.x,pos.y,scaleX,scaleY,0,img,color);
{   if (scaleX=1) and (scaleY=1) then
    draw.Image(x,y,img,color)
   else
    draw.Scaled(x,y,x+(img.width-1)*scaleX,y+(img.height-1)*scaleY,img,color);}
  end;

 procedure DrawButton(but:TUIButton;sNum:integer);
  var
   bPos:TPoint2s;
   bScale:single;
   cRect:TRect;
   i,j,k,l,ix,iy,v:integer;
   col,col2,c:cardinal;
   sa:StringArr;
   mode:TTextAlignment;
   sx,sy:single;
   bStyle:PButtonStyle;
  begin
   with but do begin
     if sNum>0 then begin
        bStyle:=@btnStyles[sNum];
        bScale:=but.globalScale;
        bPos:=but.TransformToScreen(Point2s(but.size.x/2,but.size.y/2));
        bPos.x:=bPos.x+bStyle.offsetX*bScale;
        bPos.y:=bPos.y+bStyle.offsetY*bScale;
        sx:=bStyle.scaleX*bScale;
        sy:=bStyle.scaleY*bScale;

        v:=bStyle.opacity;
        if not enabled then tag:=0;
        if enabled and (undermouse=but) then begin
         if bStyle.timeUp>0 then inc(tag,round(20*v/bStyle.timeUp))
          else tag:=v;
         if tag>v then tag:=v;
        end else begin
         if bStyle.timeDown>0 then dec(tag,round(20*v/bStyle.timeDown))
          else tag:=0;
         if tag<0 then tag:=0;
        end;

        // Обычное состояния
        if (enabled or (bStyle.imageDisabled=0)) and (bStyle.image<>0) then begin
         // не рисовать если наведено и переходы мгновенны
         if (tag>0) and enabled and (bStyle.timeUp=0) and
           (bStyle.timeDown=0) or
           (pressed and (bStyle.imageDown<>0)) then
         else begin
          c:=ColorMix(bStyle.imageColorOver,bStyle.imageColor,tag);
          if pressed then c:=bStyle.imageColorDown;
          DrawBtnImage(bPos,btnImages[bStyle.image].image,c,sx,sy);
         end;
        end;
        // Кнопка недоступна
        if not enabled and (bStyle.imageDisabled<>0) then
         DrawBtnImage(bpos,btnImages[bStyle.imageDisabled].image,bStyle.imageColorDisabled,sx,sy);
        // Нажатое состояние
        if (pressed) and (bStyle.imageDown<>0) then
         DrawBtnImage(bpos,btnImages[bStyle.imageDown].image,bStyle.imageColorDown,sx,sy);
        // Кнопка по умолчанию
        if (default) and (bStyle.imageDefault<>0) then
         DrawBtnImage(bpos,btnImages[bStyle.imageDefault].image,bStyle.imageColor,sx,sy);
        // Кнопка имеет фокус
        if (focusedElement=but) and (bStyle.imageFocused<>0) then
         DrawBtnImage(bpos,btnImages[bStyle.imageFocused].image,bStyle.imageColor,sx,sy);
        // Подсветка
        if enabled and (tag>0) and not pressed then
         if bStyle.imageOver<>0 then begin
          if (bStyle.timeUp=0) and (bStyle.timeDown=0) then
           DrawBtnImage(bpos,btnImages[bStyle.imageOver].image,bStyle.imageColorOver,sx,sy)
          else // для подсветки используется отдельное изображение, прозрачность которого уменьшается до opacity
           DrawBtnImage(bpos,btnImages[bStyle.imageOver].image,$808080+tag shl 24,sx,sy);
         end;

        // Вывод надписи (если есть)
        if caption<>'' then begin
         ix:=bStyle.textOffsetX;
         iy:=bStyle.textOffsetY;
         // Вычисление цвета надписи
         col2:=bStyle.ColorShadow;
         if bStyle.color<>0 then col:=bStyle.color;
         if not pressed and (focusedElement=but) and (bStyle.colorFocused<>0) then
           col:=bStyle.colorFocused;
         if not enabled then begin
           if bStyle.colorDisabled<>0 then col:=bStyle.colorDisabled;
           if bStyle.colorShadowDisabled<>0 then col2:=bStyle.ColorShadowDisabled;
         end;
         if tag>0 then col:=ColorMix(bStyle.colorOver,col,tag);
         if pressed and (bStyle.colorDown<>0) then col:=bStyle.colorDown;

         // перевод ДО разделения на подстроки!
         sa:=Split('~',translate(caption),#0);
         cRect:=but.GetClientPosOnScreen;
         gfx.clip.Rect(cRect);
         //draw.TextColorX2:=true;
         if btnStyle=bsCheckbox then begin
          ix:=cRect.left+24+ix; iy:=cRect.top+2+iy;
          mode:=TTextAlignment.taLeft;
         end else begin
          iy:=cRect.top+((globalrect.height-2-txt.Height(font)*length(sa)) div 2)+byte(pressed)+iy;
          mode:=bStyle.alignment;
          if mode=TTextAlignment.taJustify then mode:=TTextAlignment.taCenter;
          if mode=TTextAlignment.taCenter then ix:=cRect.left+cRect.width div 2+byte(pressed)+ix else
          if mode=TTextAlignment.taLeft then ix:=ix+cRect.left+byte(pressed)+cRect.width div 6 else
          if mode=TTextAlignment.taRight then ix:=ix+cRect.left+byte(pressed)+cRect.width*7 div 8;
         end;
          // Вывод обычным текстом (тут всё устаревшее и требует переосмысления)
          for j:=0 to length(sa)-1 do begin
           txt.WriteW(font,ix,iy,col,Str16(sa[j]),mode,toAddBaseline);
           if bStyle.underline then begin
            col:=ColorMult2(col,$80FFFFFF);
            k:=round(txt.Height(font)*0.96);
            l:=txt.Width(font,sa[j]);
            if mode=TTextAlignment.taLeft then
             draw.Line(ix,iy+k,ix+l,iy+k,col);
            if mode=TTextAlignment.taCenter then
             draw.Line(ix-l div 2,iy+k,ix+l div 2,iy+k,col);
            if mode=TTextAlignment.taRight then
             draw.Line(ix-l,iy+k,ix,iy+k,col);
           end;
           inc(iy,txt.Height(font));
           if j=0 then inc(ix);
          end;
         //draw.TextColorX2:=false;
         gfx.clip.Restore;
        end;

     end; // style>0
   end;
  end;

 procedure CustomStyleHandler(item:TUIElement);
  var
   i,j:integer;
   img:TObject;
   timg:TTexture;
   enabl:boolean;
   con:TUIElement;
   x1,y1,x2,y2,ix,iy,v:integer;
   c,d:cardinal;
   bool:boolean;
   int,sNum:integer;
  begin
   // Определение общих св-в элемента
   enabl:=item.enabled;
   con:=item;
   while con.parent<>nil do begin
    con:=con.parent;
    enabl:=enabl and con.enabled;
   end;
   with item.globalrect do begin
    x1:=Left; x2:=right-1;
    y1:=top; y2:=bottom-1;
   end;

   // Элемент - окно
   if item is TUISkinnedWindow then with item as TUISkinnedWindow do begin
    if background<>nil then begin    // нарисовать фон окна
     if TranspBgnd then gfx.target.BlendMode(blMove);
     img:=background;
     if img is TTexture then
      draw.Image(globalRect.Left,globalRect.Top,img as TTexture,color);
     if TranspBgnd then gfx.target.BlendMode(blAlpha);
    end;
   end;

   // Полоса прокрутки
   if item is TUIScrollBar then with item as TUIScrollBar do begin
    v:=colorMix(color,$40101010,96);
    c:=colorAdd(v,$202020);
    d:=ColorSub(v,$202020);
    if horizontal then begin
     // горизонтальная

    end else begin
     // вертикальная
     draw.FillGradrect(x1,y1,x2,y2,d,c,false);
     if enabled and (globalrect.height>=16) and (pagesize<max-min) then begin
      c:=colorMix(color,$FF909090,128);
      if sliderUnder and not (hooked=item) then c:=ColorAdd(c,$101010);
      i:=round((globalrect.height-16)*value/max);
      j:=15+round((globalrect.height-16)*(value+pagesize)/max);
      if i<0 then i:=0;
      if j>=globalrect.height then j:=globalrect.height-1;
      if j>i+15 then begin
       d:=(j-i)*8+round(sqrt((j-i)*10));
       draw.TexturedRect(x1,y1+i,x2,y1+j,scrollTex,0.02,0.5-d/1000,0.98,0.5-d/1000,0.98,0.5+d/1000,c);
       c:=colorAdd(c,$101010);
       draw.Scaled(x1,y1+j-10,x2,y1+j,scroll2,c);
       draw.Scaled(x1,y1+i,x2,y1+i+10,scroll1,c);
      end;
     end;
    end;
   end;

   // Поиск стиля
   sNum:=0;
   j:=(cardinal(item) div 3) and $FF;
   i:=hash[j];
   if (i>0) then
    if ((item.styleinfo<>'') and (UpperCase(btnstyles[i].name)=UpperCase(item.styleinfo))) or
       ((btnStyles[i].assigned<>'') and (pos(UpperCase(item.name)+',',btnStyles[i].assigned)>0)) or
       ((btnStyles[i].assigned='') and
        (item.styleinfo='') and
        (btnStyles[i].width=item.globalrect.width) and
        (btnStyles[i].height=item.globalrect.height)) then begin
     sNum:=i;
    end;
   if sNum=0 then
   for i:=1 to btnStylesCnt do
    if ((item.styleinfo<>'') and (UpperCase(btnstyles[i].name)=UpperCase(item.styleinfo))) or
       ((btnStyles[i].assigned<>'') and (pos(UpperCase(item.name)+',',btnStyles[i].assigned)>0)) or
       ((btnStyles[i].assigned='') and
        (item.styleinfo='') and
        (btnStyles[i].width=item.globalrect.width) and
        (btnStyles[i].height=item.globalrect.height)) then begin
     sNum:=i; break;
    end;
   if (sNum>0) then hash[j]:=sNum;

   if (snum>0) and (btnStyles[snum].alphamode<>amAuto) then begin
    if btnStyles[snum].alphamode=amSkip then gfx.target.Mask(true,false)
     else gfx.target.Mask(true,true);
   end;


   // поле ввода
   if item.ClassType=TUIEditBox then
    with item as TUIEditbox do begin
      if sNum>0 then begin
        ix:=round(x1-btnStyles[sNum].offsetX);
        iy:=round(y1-btnStyles[sNum].offsetY);
        if btnStyles[sNum].image=0 then
         raise EError.create('InpBox style has no image');
        draw.Image(ix,iy,btnImages[btnStyles[i].image].image,$FF808080);
      end;
      bool:=noborder;
      noborder:=true;
      DrawUIElement(item,0);
      noborder:=bool;
    end;

   // Кнопка
   if item.ClassType=TUIButton then
    DrawButton(item as TUIButton,sNum);
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
   customStyleID:=styleID;
   RegisterUIStyle(customStyleID,CustomStyleHandler);
   // адрес произвольный ибо объект уникальный
   PublishVar(@CustomStyleHandler,'CustomStyle',TVarTypeCustomStyle);
  end;

 procedure ApplyCustomStyle(item:TUIElement;styleName:string);
  begin
   item.style:=customStyleID;
   item.styleInfo:=styleName;
  end;

 // Возвращает хэндл изображения, если надо - загружает его
 function ImageHandle(name:string):integer;
  var
   i:integer;
   qual:string;
   pf:TImagePixelFormat;
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
  alignment:=TTextAlignment.taJustify;
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

class function TVarTypeCustomStyle.GetField(variable:pointer;
  fieldName:string;out varClass:TVarClass):pointer;
var
 i,n:integer;
 grp,prop:string;
 item:^TButtonStyle;
 st:string;
begin
 // varname = "group\property" либо "groupName"
 result:=nil;
 i:=pos('\',fieldname);
 if i=0 then begin
  fieldname:=lowercase(fieldname);
  for i:=1 to btnStylesCnt do
   if btnStyles[i].lowname=fieldname then begin
    result:=@btnStyles[i];
    varClass:=TVarTypeBtnStyle;
   end;
  if result=nil then begin
   // группы с таким именем нет => создать
   n:=NewButtonStyle(fieldname);
   result:=@btnStyles[n];
   varClass:=TVarTypeBtnStyle;
  end;
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
       result:=@item^.alignment; varClass:=GetVarTypeFor('TTextAlignment');
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
       result:=@item^.offsetX; varClass:=TVarTypeSingle;
     end else
     if prop='OFFSETY' then begin
       result:=@item^.offsetY; varClass:=TVarTypeSingle;
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
  end; // case
 end;
end;

class function TVarTypeCustomStyle.ListFields:String;
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

class function TVarTypeImageHandle.GetValue(variable:pointer):string;
 var
  h:integer;
 begin
  h:=PInteger(variable)^;
  ASSERT((h>=1) and (h<=high(btnImages)));
  result:=btnImages[h].fname;
 end;

class procedure TVarTypeImageHandle.SetValue(variable:pointer;v:string);
 begin
  PInteger(variable)^:=ImageHandle(v);
 end;

class function TVarTypeAlphaMode.GetValue(variable:pointer):string;
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

class procedure TVarTypeAlphaMode.SetValue(variable:pointer;v:string);
 var
  a:^TAlphaMode;
 begin
  a:=variable;
  a^:=StrToAMode(v);
 end;

{ TVarTypeBtnStyle }

class function TVarTypeBtnStyle.GetValue(variable:pointer):string;
 begin

 end;

class procedure TVarTypeBtnStyle.SetValue(variable:pointer;v:string);
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
