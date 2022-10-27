// -----------------------------------------------------
// User Interface rendering block
//
// Author: Ivan Polyacov (C) 2003-2014, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------
unit Apus.Engine.UIRender;
interface
 uses Apus.Engine.API, Apus.Engine.UI;
 type
  // процедура отрисовки элемента
  TUIDrawer=procedure(control:TUIElement);

 // Render an UI element and all its descendants (skip elements with manualDraw=true)
 procedure DrawUI(item:TUIElement);
 // Draw just this element (and it descedants with manualDraw=true)
 procedure DrawManualUI(item:TUIElement;recursive:boolean=false);
 // Render single UI element
 procedure DrawUIElement(item:TUIElement;styleOverride:integer=-1);

 procedure BackgroundRenderBegin;
 procedure BackgroundRenderEnd;

 procedure DrawGlobalShadow(color:cardinal);

 // Set custom style drawer (style=1..50)
 // 0..9 - reserved for engine styles
 // 10..19 - for private game styles
 // 20..50 - 3-rd party libraries
 procedure RegisterUIStyle(style:byte;drawer:TUIDrawer;name:string='');

 // Fill control rect with image (helper function)
 procedure DrawControlWithImage(c:TUIElement;img:TTexture;centered:boolean=false);

 var
  // Глобальная переменная для отрисовщиков: может содержать время, прошедшее с
  // предыдущей отрисовки (время кадра), но может содержать и 0
  //frameTime:int64;

  transpBgnd:boolean=false; // render target is (probably) transparent so blMove should be used to fill it

  defaultHintFont:cardinal=0; // Шрифт, которым показываются хинты

implementation
 uses Apus.CrossPlatform, Apus.Images, SysUtils, Types, Apus.Common,
    Apus.EventMan, Apus.Geom2D, Apus.Engine.DefaultStyle;

 var
  styleDrawers:array[0..50] of TUIDrawer;

 procedure DrawGlobalShadow(color:cardinal);
  begin
   draw.FillRect(0,0,game.renderWidth,game.renderHeight,color);
  end;

 procedure BackgroundRenderBegin;
  begin
   if transpBgnd then gfx.target.BlendMode(blMove);
  end;

 procedure BackgroundRenderEnd;
  begin
   if transpBgnd then gfx.target.BlendMode(blAlpha);
  end;

 procedure DrawUITree(item:TUIElement;manualDraw:boolean;recursive:boolean);
  var
   i,j,n,cnt:integer;
   tmp:pointer;
   r:TRect;
   list:array of TUIElement;
   maskChange:boolean;
   clipping:boolean;
  begin
   if not item.visible then exit;
   if item.layout<>nil then begin
    item.layout.Layout(item);
    item.Resize(-1,-1);
   end;
   // Draw self first
   if (item.size.x<=0) or (item.size.y<=0) then exit;
   item.globalRect:=item.GetPosOnScreen;
{   /// TODO: alpha should be masked ONLY if semi-transparent element is drawn on an opaque background, not vice-versa.
   ///  Need to find a generic approach.
   maskChange:=(item.parent<>nil) and (item.parent.transpmode<>tmTransparent);
   maskChange:=false;
   if maskChange then gfx.target.Mask(true,false);}
   try
    // Draw element
    if (item.manualDraw=manualDraw) and
       (item.style>=0) and
       (item.style<=high(styleDrawers)) then
      DrawUIElement(item);

    // Debug: Highlight with border when Ctrl+Alt+Win pressed
    if (game.shiftState and $F=sscCtrl+sscWin+sscAlt) then
     if (item=underMouse) or
        ((underMouse<>nil) and (item=underMouse.parent)) then
       with item.globalRect do begin
         if (item=underMouse) and (game.frameStartTime and $100=0) then
          draw.FillRect(left,top,right-1,bottom-1,$1800FF00);
         draw.Rect(left,top,right-1,bottom-1,$80FFFFFF xor ($FFFFFF*((MyTickCount shr 8) and 1)));
       end;
   except
    on E:Exception do begin
     ForceLogMessage('Error drawing control '+item.name+' - '+ExceptionMsg(e));
     sleep(0);
    end;
   end;

   if not recursive then exit;

   // Now prepare list of child elements to draw
   n:=length(item.children);
   cnt:=0;
   SetLength(list,n);
   for i:=0 to n-1 do
    if item.children[i].visible then begin
     list[cnt]:=item.children[i];
     inc(cnt);
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
     gfx.clip.Rect(r);
    end;

    for i:=0 to cnt-1 do begin
     // если элемент не клипится и фон - не прозрачный - нарисовать без отсечения
     if clipping and not list[i].parentClip and not transpBgnd then begin
      gfx.clip.Nothing;
      DrawUITree(list[i],manualDraw,true);
      gfx.clip.Restore;
     end else
      DrawUITree(list[i],manualDraw,true);
    end;

    if clipping then gfx.clip.Restore;
   end;
{   // вернуть маску назад
   if maskChange then gfx.target.UnMask;}
  end;

 procedure DrawUI(item:TUIElement);
  begin
   DrawUITree(item,false,true);
  end;

 procedure DrawManualUI(item:TUIElement;recursive:boolean=false);
  begin
   DrawUITree(item,true,recursive);
  end;

 procedure DrawUIElement(item:TUIElement;styleOverride:integer=-1);
  begin
   if styleOverride=-1 then styleOverride:=item.style;
   ASSERT(@styleDrawers[styleOverride]<>nil,'Style not registered');
   styleDrawers[styleOverride](item);
  end;

 procedure RegisterUIStyle(style:byte;drawer:TUIDrawer;name:string='');
  begin
   ASSERT(style in [0..high(styleDrawers)]);
   styleDrawers[style]:=drawer;
   if name<>'' then LogMessage(Format('UI style registered: %d - %s',[style,name]));
  end;

 procedure DrawControlWithImage(c:TUIElement;img:TTexture;centered:boolean=false);
  var
   r:TRect;
   scale:single;
  begin
   r:=c.GetPosOnScreen;
   if centered then begin
    scale:=c.globalScale;
    draw.RotScaled((r.left+r.right)/2,(r.top+r.bottom)/2,scale,scale,0,img);
   end else begin
    with r do draw.Scaled(left,top,right+1,bottom+1,img);
   end;
  end;

end.
