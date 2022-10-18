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


implementation
uses Apus.Geom2D;

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
  begin
   pos:=0;
   for i:=0 to high(item.children) do begin
    c:=item.children[i];
    if not c.visible then continue;
    if c.IsOutOfOrder then continue;
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
  begin
   childSize:=0;
   weightSum:=0;
   with item do begin
    for i:=0 to high(children) do begin
     if not children[i].visible then continue;
     if children[i].IsOutOfOrder then continue;
     if vertical then childSize:=childSize+children[i].size.y
       else childSize:=childSize+children[i].size.x;
     weightSum:=weightSum+children[i].layoutData;
    end;
    if vertical then ownSize:=item.clientHeight
     else ownSize:=item.clientWidth;
    extraSpace:=ownSize-high(children)*spaceBetween-childSize;
    // Distribute extra space among children and position them
    pos:=0;
    for i:=0 to high(children) do begin
     if not children[i].visible then continue;
     if children[i].IsOutOfOrder then continue;
     delta:=extraSpace*children[i].layoutData/weightSum;
     if vertical then begin
      children[i].Resize(-1,children[i].size.y+delta);
      children[i].position.y:=pos;
      pos:=pos+children[i].size.y+spaceBetween;
     end else begin
      children[i].Resize(children[i].size.x+delta,-1);
      children[i].position.x:=pos;
      pos:=pos+children[i].size.x+spaceBetween;
     end;
    end;
   end;
  end;


end.
