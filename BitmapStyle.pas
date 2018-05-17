// Стандартный стиль для UI, позволяющий определять внешний вид элементов
// с использованием изображений
//
// Copyright (C) 2006 Apus Software (www.astralmasters.com)
// Author: Ivan Polyacov (cooler@tut.by)
{$R-}
unit BitmapStyle;
interface
 uses EngineCls,UIClasses;

 type
  TButtonState=(bsNormal,bsOver,bsDown,bsDisabled);

  TBitmapStyle=class
   // Этот метод нужно переопределить в модуле проекта
   // Если img=nil - нужно выделить память, иначе - просто перерисовать
   procedure BuildButtonImage(btn:TUIButton;state:TButtonState;var img:TTextureImage); virtual;
   // Возможно переопределение для изменения дефолтной отрисовки
   procedure DrawItem(con:TUIControl); virtual;
   // Возвращает время перехода в/из подсвеченного состояния
   // (param=0 - убираниие подстветки, 1 - появление)
   function AnimationTime(con:TUIControl;param:integer):integer; virtual;
  end;

  procedure InitBitmapStyle(styleID:integer;style:TBitmapStyle);
  // Удаляет ранее созданные изображения кнопки (если они более неактуальны)
  procedure DeleteButtonImages(btn:TUIControl);
  procedure DeleteAllButtonImages;

implementation
 uses SysUtils,myservis,EventMan,EngineTools,UIRender,colors,structs,publics;

 type
  // Для каждого элемента UI хранится такая структура с картинками и прочими сведениями
  TButtonData=record
   width,height:integer; // текущий размер кнопки
   imgNormal,imgOver,imgDown,imgDisabled:TTextureImage;
   dynamicImg:boolean; // обновлять изображения каждый кадр?
   overState:TAnimatedValue; // состояние Over (0..1)
   lastCaption:string;
  end;

  TLabelData=record
   prevCaption:string;
   img:TTextureImage;
  end;

 var
  styleCls:TBitmapStyle;
  buttons:array[1..200] of TButtonData;
  bCount:integer;
  btnHash:THash; // button name -> index of TButtonData

  lHash:THash;  // labelHash

  imgHash:THash; // images hash: filename -> TTexture object (cardinal)

  crSect:TMyCriticalSection;

 procedure BitmapStyleHandler(control:TUIControl);
  begin
   styleCls.DrawItem(control);
  end;

 function EventHandler(event:EventStr;tag:integer):boolean;
  var
   name:string;
   btn:TUIControl;
  begin
   result:=true;
   event:=UpperCase(event);
   if pos('BITMAPSTYLE\INVALIDATE\',event)=1 then begin
    LogMessage(event+' '+inttohex(cardinal(tag),8));
    name:=event;
    delete(name,1,23);
    if (name='*') or (name='ALL') then begin
     DeleteAllButtonImages;
    end else begin
     btn:=FindControl(name,false);
     if btn<>nil then DeleteButtonImages(btn);
    end;
   end;
  end;

 procedure InitBitmapStyle(styleID:integer;style:TBitmapStyle);
  begin
   LogMessage('Init bitmap style');
   InitCritSect(crSect,'BitmapStyle',70);
   SetEventHandler('BitmapStyle',@eventHandler,sync);  /// заменить sync на mixed!
   styleCls:=style;
   RegisterUIStyle(styleID,BitmapStyleHandler);
   btnHash.Init;
   imgHash.Init;
   bCount:=0;
   fillchar(buttons,sizeof(buttons),0);
  end;

// x,y - button center
procedure DrawBtnImage(btn:TUIButton;state:TButtonState;xc,yc:single;var img:TTextureImage;color:cardinal);
 var
  x,y:integer;
 begin
  if (img=nil) or (img.name='OUT_OF_DATE') then
   styleCls.BuildButtonImage(btn,state,img);
  x:=round(xc+0.1); y:=round(yc+0.1);
  if img<>nil then begin
   painter.DrawCentered(x,y,img,color);
  end else begin
   dec(x,btn.width div 2);
   dec(y,btn.height div 2);
   painter.FillGradrect(x,y,x+btn.width-1,y+btn.height-1,$FFE0E0EE,$FFB0B0C0,true);
   painter.Rect(x,y,x+btn.width-1,y+btn.height-1,$A0FFFFFF);
  end;
 end;

// x,y - button center
procedure DrawBtnImageInt(btn:TUIButton;xc,yc:single;var imgNormal,imgOver:TTextureImage;color:cardinal;intFactor:single);
 var
  x,y:integer;
 begin
  if (imgNormal=nil) or (imgNormal.name='OUT_OF_DATE') then
   styleCls.BuildButtonImage(btn,bsNormal,imgNormal);
  if (imgOver=nil) or (imgOver.name='OUT_OF_DATE') then
   styleCls.BuildButtonImage(btn,bsOver,imgOver);
  if (imgNormal<>nil) and (imgOver<>nil) then begin
    x:=round(xc+0.1);
    y:=round(yc+0.1);
//    if imgNormal.width and 1=1 then x:=round(xc+0.5);
//    if imgNormal.height and 1=1 then y:=round(yc+0.5);
    dec(x,imgNormal.width div 2);
    dec(y,imgNormal.height div 2);
    painter.SetTexMode(1,tblInterpolate,tblInterpolate,fltBilinear,intFactor);
//    painter.SetTexInterpolationMode(1,tintFactor,intFactor);
    painter.DrawDouble(x,y,imgNormal,imgOver,color);
    painter.SetTexMode(1,tblDisable,tblDisable,fltUndefined);
  end;
 end; 

procedure DeleteAllButtonImages;
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 LogMessage('Deleting all button images!');
 try
 for i:=1 to bCount do
  with buttons[i] do begin
   texman.FreeImage(imgNormal);
   texman.FreeImage(imgOver);
   texman.FreeImage(imgDown);
   texman.FreeImage(imgDisabled);
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;


procedure DeleteButtonImages(btn: TUIControl);
var
 idx:integer;
begin
 EnterCriticalSection(crSect);
 try
 idx:=btnHash.Get(btn.name);
 if idx>0 then
  with buttons[idx] do begin
   texman.FreeImage(imgNormal);
   texman.FreeImage(imgOver);
   texman.FreeImage(imgDown);
   texman.FreeImage(imgDisabled);
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure InvalidateImages(bData:integer);
begin
 EnterCriticalSection(crSect);
 with buttons[bData] do try
  if imgNormal<>nil then imgNormal.name:='OUT_OF_DATE';
  if imgOver<>nil then imgOver.name:='OUT_OF_DATE';
  if imgDown<>nil then imgDown.name:='OUT_OF_DATE';
  if imgDisabled<>nil then imgDisabled.name:='OUT_OF_DATE';
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TBitmapStyle.DrawItem(con: TUIControl);
 var
  i,j:integer;
  enabl:boolean;
  x1,y1,x2,y2,a:integer;
  xc,yc:single;
  bData:integer;
  st:string;
  c,btnColor:cardinal;
  img:TTexture;
  btn:TUIButton;
 begin
  // Определение общих св-в элемента
  enabl:=con.enabled; // для отрисовки кнопок доступность предков значения не имеет
  with con.globalrect do begin
   x1:=Left; x2:=right-1;
   y1:=top; y2:=bottom-1;
   xc:=(x1+x2)/2;
   yc:=(y1+y2)/2;
  end;
  EnterCriticalSection(crSect);
  try

  // Кнопка
  if (con.ClassType=TUIButton) or (con.classtype=TUIComboBox) then
   with con as TUIButton do begin
    bData:=btnHash.Get(con.name);
    if bData=0 then begin
     inc(bCount);
     bData:=bCount;
     btnHash.Put(con.name,bData);
     buttons[bData].overState.Init(byte(underMouse=con));
     buttons[bData].lastCaption:=TUIButton(con).caption;
    end else begin
     if buttons[bData].lastCaption<>TUIButton(con).caption then begin
      if pos('%UPDATE%',TUIButton(con).caption)=1 then delete(TUIButton(con).caption,1,8);
      // caption changed - invalidate images
      buttons[bData].lastCaption:=TUIButton(con).caption;
      InvalidateImages(bData);
     end;
    end;
    // Разместить кнопку с привязкой к правому краю
    if con.classtype=TUIComboBox then begin
     xc:=x2-round(con.height/2);
    end;

    btnColor:=TUIButton(con).color;
    btnColor:=$FF808080; // пока так - чтобы не поломать везде всё
    with buttons[bData] do
     if enabl then begin // Button enabled
      if pressed then begin
       DrawBtnImage(TUIButton(con),bsDown,xc,yc,imgDown,btnColor);
//       overState.Assign(0);
      end else begin // Not pressed
       if (underMouse=con) and (overState.FinalValue<>1) then
         overState.Animate(1,styleCls.AnimationTime(con,1),Spline0);
       if (underMouse<>con) and (not overState.IsAnimating) and (overState.Value<>0) then
         overState.Animate(0,styleCls.AnimationTime(con,0),Spline0);

       a:=round(255*overState.Value);
       if a>0 then begin
        if FindConst(con.styleinfo+'\overlay')>=0 then begin
          // btnOver image is an overlay image
          DrawBtnImage(TUIButton(con),bsNormal,xc,yc,imgNormal,btnColor);
          DrawBtnImage(TUIButton(con),bsOver,xc,yc,imgOver,btnColor and $FFFFFF+a shl 24);
        end else begin
          // btnOver image is a standalone image
          if a<255 then
           DrawBtnImageInt(TUIButton(con),xc,yc,imgNormal,imgOver,btnColor,1-a/255)
          else
           DrawBtnImage(TUIButton(con),bsOver,xc,yc,imgOver,btnColor);
        end;
       end else
        DrawBtnImage(TUIButton(con),bsNormal,xc,yc,imgNormal,btnColor);
      end;
     end else begin // Disabled
      DrawBtnImage(TUIButton(con),bsDisabled,xc,yc,imgDisabled,btnColor);
      overState.Assign(0);
     end;
   end;

  if con.ClassType=TUILabel then
   with con as TUILabel do begin
    st:=lHash.Get(con.name);
    if st<>caption then begin
     // Redraw
    end;
    if caption<>'' then lHash.Put(con.name,caption,true);
   end;

  if con.ClassType=TUIImage then
   with con as TUIImage do begin
    c:=imgHash.Get(con.name);
    if c=0 then begin
     img:=LoadImageFromFile(TUIImage(con).src);
     imgHash.Put(con.name,cardinal(img),true);
    end else
     img:=pointer(c);
//    painter.DrawRotScaled(xc,yc,img,TUIImage(con).color);
   end;


  finally
   LeaveCriticalSection(crSect);
  end;
 end;

{ TBitmapStyle }
function TBitmapStyle.AnimationTime(con: TUIControl; param: integer): integer; begin
  case param of
   0:result:=100;
   1:result:=200;
  end;
 end;

procedure TBitmapStyle.BuildButtonImage(btn: TUIButton; state: TButtonState;  var img: TTextureImage);
 begin
  img:=nil;
 end;

end.