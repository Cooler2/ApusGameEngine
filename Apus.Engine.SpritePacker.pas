// Sprite (rect) packing algorithms

// Copyright (C) Apus Software, 2019. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.SpritePacker;
interface
 uses types;
 type
  TRectangles=array of TRect;

 // Pack rectangles into area with given size
 // if allowRotate=true - rectangles can be turned 90deg CCW
 // Some rectangles may not fit - then output record will contain negative values
 function PackSprites(const source:TRectangles;width,height:integer;allowRotate:boolean=true):TRectangles;

implementation
 uses Apus.MyServis;

 function TurnRect(r:TRect):TRect;
  begin
   result:=Rect(0,0,r.Height,r.Width);
  end;

 function RateRect(placement,sprite:TRect):integer;
  begin
   if (placement.Width=sprite.Width) and (placement.height=sprite.height) then
    result:=0
   else
    result:=min2(placement.Width-sprite.Width+1,placement.height-sprite.height+1);
   if result<0 then result:=MaxInt;
  end;

 function PackSprites(const source:TRectangles;width,height:integer;allowRotate:boolean=true):TRectangles;
  var
   i,j,n,idx,w,h,freeW,freeH:integer;
   freeRects:array of TRect;
   freeCnt:integer;
   queue:array of integer; // list of sprites to place
   qCnt:integer;
   rate,rate2,bestRate:integer;
   bestSprite,bestRect:integer;
   bestTurn:boolean;
  begin
   // Prepare
   n:=length(source);
   SetLength(result,n);
   for i:=0 to n-1 do
    result[i]:=Rect(-1,-1,-1,-1);
   SetLength(freeRects,n+1);
   freeCnt:=1;
   freeRects[0]:=Rect(0,0,width,height);
   SetLength(queue,n);
   qCnt:=n;
   for i:=0 to n-1 do queue[i]:=i;
   // Run
   while true do begin
    // Find best pair: freeRect-sprite
    bestRate:=MaxInt;
    bestSprite:=-1;
    for i:=0 to qCnt-1 do
     for j:=0 to freeCnt-1 do begin
      idx:=queue[i];
      if min2(source[idx].Width,source[idx].Height)>min2(freeRects[j].Width,freeRects[j].Height) then continue;
      rate:=RateRect(freeRects[j],source[idx]);
      if rate<bestRate then begin
       bestRate:=rate; bestTurn:=false;
       bestSprite:=i; bestRect:=j;
      end;
      if allowRotate then begin
       rate2:=RateRect(freeRects[j],TurnRect(source[idx]));
       if rate2<bestRate then begin
        bestRate:=rate2; bestTurn:=true;
        bestSprite:=i; bestRect:=j;
       end;
      end;
     end;
    if bestSprite>=0 then begin
     // Place sprite
     idx:=queue[bestSprite];
     queue[bestSprite]:=queue[qCnt-1];
     dec(qCnt);
     with result[idx] do begin
      w:=source[idx].Width;
      h:=source[idx].Height;
      if bestTurn then swap(w,h);
      // Output
      left:=freeRects[bestRect].Left;
      top:=freeRects[bestRect].top;
      right:=left+w;
      bottom:=top+h;
      // Adjust free rect
      freeW:=freeRects[bestRect].Width;
      freeH:=freeRects[bestRect].height;
      if freeW-w<freeH-h then begin
       // Split best rect with horizontal line
       freeRects[freeCnt]:=freeRects[bestRect];
       freeRects[freeCnt].Left:=freeRects[bestRect].Left+w;
       freeRects[freeCnt].bottom:=h;
       if freeRects[freeCnt].Width>2 then inc(freeCnt); // don't add too narrow rect
       inc(freeRects[bestRect].Top,h);
      end else begin
       // Split best rect with vertical line
       freeRects[freeCnt]:=freeRects[bestRect];
       freeRects[freeCnt].top:=freeRects[bestRect].top+h;
       freeRects[freeCnt].right:=w;
       if freeRects[freeCnt].height>2 then inc(freeCnt); // don't add too narrow rect
       inc(freeRects[bestRect].left,w);
      end;
      if (freeRects[bestRect].Width<3) or (freeRects[bestRect].Height<3) then begin
       dec(freeCnt);
       freeRects[bestRect]:=freeRects[freeCnt];
      end;
     end;
    end else
     break;
   end;
  end;

end.
