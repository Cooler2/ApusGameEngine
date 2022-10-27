// -----------------------------------------------------
// Standard UI Layouters
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------unit Apus.Engine.UILayout;
unit Apus.Engine.UILayout;
interface
uses Apus.Engine.UITypes;

type
 // Layout elements in a row/column
 // spaceBetween - spacing between elements
 // resizeToContent - make item size match
 // center - align elements to item's central line
 TRowLayout=class(TLayouter)
  constructor CreateVertical(spaceBetween:single=0;resizeToContent:boolean=false;center:boolean=false);
  constructor CreateHorizontal(spaceBetween:single=0;resizeToContent:boolean=false;center:boolean=false);
  constructor Create(horizontal:boolean=true;spaceBetween:single=0;resizeToContent:boolean=false;center:boolean=false);
  procedure Layout(item:TUIElement); override;
 private
  fHorizontal,fResize,fCenter:boolean;
  fSpaceBetween:single;
 end;

 TFlexboxLayout=class(TLayouter)
  constructor Create(spaceBetween:single=0);
  constructor CreateVertical(spaceBetween:single=0);
  procedure Layout(item:TUIElement); override;
 private
  vertical:boolean;
  spaceBetween:single;
 end;

 // Arrange elements in a grid
 TGridLayout=class(TLayouter)
  // Don't alter items size
  constructor Create(spaceV,spaceH,paddingH,paddingV:single;center:boolean=false);
  // Resize items proportionally to fill all width
  constructor CreateResizeable(spaceV,spaceH,paddingH,paddingV:single;desiredItemWidth:single);
  procedure Layout(item:TUIElement); override;
 private
  vertSpace,horSpace,desiredWidth,paddingV,paddingH:single;
  center,allowResize:boolean;
  procedure LayoutFixed(parent:TUIElement;list:TUIElements);
  procedure LayoutFlex(parent:TUIElement;list:TUIElements);
 end;


implementation
uses Apus.Common, Apus.Types, Apus.Geom2D;

 { TRowLayout }

 constructor TRowLayout.Create(horizontal:boolean;spaceBetween:single;
    resizeToContent,center:boolean);
  begin
   fHorizontal:=horizontal;
   fSpaceBetween:=spaceBetween;
   fResize:=resizeToContent;
   fCenter:=center;
  end;

 constructor TRowLayout.CreateHorizontal(spaceBetween:single;resizeToContent,center:boolean);
  begin
   Create(true,spaceBetween,resizeToContent,center);
  end;

 constructor TRowLayout.CreateVertical(spaceBetween:single;resizeToContent,center:boolean);
  begin
   Create(false,spaceBetween,resizeToContent,center);
  end;

procedure TRowLayout.Layout(item:TUIElement);
  var
   i:integer;
   pos:single;
   r:TRect2s;
   delta:TVector2s;
   c:TUIElement;
   list:TUIElements;
  begin
   pos:=0;
   list:=GetItems(item);
   for i:=0 to high(list) do begin
    c:=TUIElement(list[i]);
    r:=c.TransformTo(c.GetRect,item);
    if fHorizontal then begin
     delta.x:=pos-r.x1;
     pos:=pos+r.width+fSpaceBetween;
     if fCenter then delta.y:=((item.clientHeight-r.y2)-r.y1)/2
      else delta.y:=0;
    end else begin
     delta.y:=pos-r.y1;
     pos:=pos+r.height+fSpaceBetween;
     if fCenter then delta.x:=((item.clientWidth-r.x2)-r.x1)/2
      else delta.x:=0;
    end;
    VectAdd(c.position,delta);
   end;
   if fResize then begin
    if fHorizontal then item.ResizeClient(pos-fSpaceBetween,-1)
     else item.ResizeClient(-1,pos-fSpaceBetween);
   end;
  end;

{ TFlexboxLayout }

 constructor TFlexboxLayout.Create(spaceBetween:single);
  begin
   self.spaceBetween:=spaceBetween;
   vertical:=false;
  end;

 constructor TFlexboxLayout.CreateVertical(spaceBetween:single);
  begin
   self.spaceBetween:=spaceBetween;
   vertical:=true;
  end;

 procedure TFlexboxLayout.Layout(item:TUIElement);
  var
   childSize,ownSize,extraSpace,weightSum,delta,pos:single;
   i:integer;
   list:TUIElements;
   e:TUIElement;
  begin
   list:=GetItems(item);
   childSize:=0;
   weightSum:=0;
   for i:=0 to high(list) do begin
    e:=list[i];
    if vertical then childSize:=childSize+list[i].size.y
      else childSize:=childSize+list[i].size.x;
    weightSum:=weightSum+list[i].layoutData;
   end;
   if vertical then ownSize:=item.clientHeight
    else ownSize:=item.clientWidth;
   extraSpace:=ownSize-high(list)*spaceBetween-childSize;
   // Distribute extra space among children and position them
   pos:=0;
   for i:=0 to high(list) do begin
     e:=list[i];
     delta:=extraSpace*e.layoutData/weightSum;
     if vertical then begin
      e.Resize(-1,e.size.y+delta);
      e.position.y:=pos;
      pos:=pos+e.size.y+spaceBetween;
     end else begin
      e.Resize(e.size.x+delta,-1);
      e.position.x:=pos;
      pos:=pos+e.size.x+spaceBetween;
     end;
   end;
  end;


{ TGridLayout }

 constructor TGridLayout.Create(spaceV,spaceH,paddingH,paddingV:single;center:boolean);
  begin
   vertSpace:=spaceV;
   horSpace:=spaceH;
   self.center:=center;
   allowResize:=false;
   self.paddingH:=paddingH;
   self.paddingV:=paddingV;
  end;

 constructor TGridLayout.CreateResizeable(spaceV,spaceH,paddingH,paddingV,desiredItemWidth:single);
  begin
   vertSpace:=spaceV;
   horSpace:=spaceH;
   allowResize:=true;
   desiredWidth:=desiredItemWidth;
   self.paddingH:=paddingH;
   self.paddingV:=paddingV;
  end;

 procedure TGridLayout.Layout(item:TUIElement);
  var
   list:TUIElements;
  begin
   list:=GetItems(item);
   if allowResize then LayoutFlex(item,list)
    else LayoutFixed(item,list);
  end;

 procedure TGridLayout.LayoutFixed(parent:TUIElement;list:TUIElements);
  var
   i,j,last:integer;
   x,y,h:single;
  begin
   last:=0;
   x:=paddingH; y:=paddingV; // position for the next item
   for i:=0 to high(list) do begin
    if i>last then x:=x+horSpace;
    list[i].SetPos(x,y);
    x:=x+list[i].width;
    if (x>=parent.clientWidth-paddingH) and (i>last) then begin // current item should be wrapped to the next row
     if center then begin
      x:=x-list[i].width-horSpace;
      for j:=last to i-1 do
       list[j].position.x:=list[j].position.x+(parent.clientWidth-paddingH*2-x)/2;
     end;
     h:=0;
     for j:=last to i do
      h:=max2s(h,list[j].size.y);
     y:=y+h+vertSpace;
     list[i].SetPos(paddingH,y);
     x:=paddingH+list[i].width;
     last:=i;
    end;
   end;
  end;

 procedure TGridLayout.LayoutFlex(parent:TUIElement;list:TUIElements);
  var
   i,cols,row,col:integer;
   y,itemWidth,itemHeight,rowHeight:single;
  begin
   cols:=max2(1,round(parent.clientWidth/desiredWidth));
   itemWidth:=round((parent.clientWidth-paddingH*2-(cols-1)*horSpace)/cols);
   y:=0; rowHeight:=0;
   for i:=0 to high(list) do begin
    col:=i mod cols;
    if col=0 then begin
     if i>0 then y:=y+vertSpace;
     y:=y+rowHeight;
     rowHeight:=0;
    end;
    itemHeight:=itemWidth*(list[i].initialSize.y/list[i].initialSize.x);
    list[i].Resize(itemWidth,itemHeight);
    rowHeight:=max2s(rowHeight,itemHeight);
    list[i].SetPos(paddingH+col*itemWidth+col*horSpace,y+paddingV);
   end;
  end;

end.
