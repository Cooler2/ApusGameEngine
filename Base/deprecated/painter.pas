// Class for painting routines
//
// Copyright (C) 2003 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (cooler@tut.by)
unit Painter;
interface
 uses Images,types,FastGFX;

type
 TextAlignment=(taLeft,taRight,taCenter,taAlign);

 TPainter=class
  constructor Create;
  // Set image as target for drawing
  procedure SetTarget(target:TRawImage); virtual;
  // Free image. It is obligatory to call this method before usage of the image
  procedure FreeTarget; virtual;

  // Set clipping rectangle (example: 0:0-640:480)
  procedure SetClipping(x1,y1,x2,y2:integer); virtual;
  // restore previous clipping settings
  procedure RestoreClipping; virtual;

  // Line drawing
  procedure FastLine(x1,y1,x2,y2:integer;color:cardinal); virtual;
  procedure PreciseLine(x1,y1,x2,y2:single;color:cardinal); virtual;
  procedure SmoothLine(x1,y1,x2,y2:single;color:cardinal); virtual;

  // Ellipse drawing
  procedure FastEllipse(x1,y1,x2,y2:integer;color:cardinal); virtual;
  procedure SmoothEllipse(x1,y1,x2,y2:single;color:cardinal); virtual;

  // Rectangle drawing
  procedure DrawRect(x1,y1,x2,y2:integer;color:cardinal); virtual;
  procedure FillRect(x1,y1,x2,y2:integer;color:cardinal); virtual;

  // Text routines
  procedure PrintText(x,y:integer;color:cardinal;font:byte;
                      alignment:TextAlignment;wrap:boolean;
                      text:string); virtual;
 protected
  pixFmt:ImagePixelFormat;
  buffer:TRawImage;
  NeedLock:boolean;
  cx1,cy1,cx2,cy2:integer;
  clipbuf:array[0..15] of TRect; // clipping queue
  startpos,curpos:byte; // positions in queue

  // ”казатели на процедуры дл€ текущего формата пиксел€
  hLine:THLine;
  vLine:TVLine;
  simLine:TSimpleLine;
  simLineA:TSimpleLine;

  colorFrom:TColorConv;
  colorTo:TColorConv;
 end;

implementation
 uses MyServis;
{ TPainter }

constructor TPainter.Create;
begin
 buffer:=nil;
 startpos:=0; curpos:=0;
end;


procedure TPainter.SetTarget(target: TRawImage);
begin
 PixFmt:=target.PixelFormat;
 if target=nil then
  raise EError.Create('Painter: invalid target passed!');

 case PixFmt of
  ipfARGB,ipfXRGB:begin
    hLine:=HLine32;
    vLine:=VLine32;
    simLine:=SimpleLine32;
    simLineA:=SimpleLine32A;
    colorFrom:=ColorFrom32;
    ColorTo:=ColorTo32;
   end;
  ipf565:begin
    hLine:=HLine16;
    vLine:=VLine16;
    simLine:=SimpleLine16;
    simLineA:=SimpleLine16A;
    colorFrom:=ColorFrom16;
    ColorTo:=ColorTo16;
   end;
  ipf1555:begin
    hLine:=HLine16;
    vLine:=VLine16;
    simLine:=SimpleLine16;
    simLineA:=SimpleLine16A;
    colorFrom:=ColorFrom15A;
    ColorTo:=ColorTo15A;
   end;
  ipf555:begin
    hLine:=HLine16;
    vLine:=VLine16;
    simLine:=SimpleLine16;
    simLineA:=SimpleLine16A;
    colorFrom:=ColorFrom15;
    ColorTo:=ColorTo15;
   end;
  ipf4444:begin
    hLine:=HLine16;
    vLine:=VLine16;
    simLine:=SimpleLine16;
    simLineA:=SimpleLine16A;
    colorFrom:=ColorFrom12;
    ColorTo:=ColorTo12;
   end;
  else raise EError.Create('Painter: target pixel format is not currently supported');
 end;
 buffer:=target;
 SetClipping(0,0,buffer.Width,buffer.height);
 NeedLock:=buffer.NeedLock;
 if NeedLock then buffer.Lock;
end;


procedure TPainter.DrawRect(x1, y1, x2, y2: integer; color: cardinal);
var
 t:integer;
begin

 if (x1>x2) then begin
  t:=x1; x1:=x2; x2:=t;
 end;
 if (y1>y2) then begin
  t:=y1; y1:=y2; y2:=t;
 end;
 FastLine(x1,y1,x2,y1,color);
 if (y2>y1) then begin
  FastLine(x1,y1+1,x1,y2,color);
  if (x2>x1) then
   FastLine(x2,y1+1,x2,y2,color);
 end;
 if (x2>x1+1) and (y2>y1) then
  FastLine(x1+1,y2,x2-1,y2,color);
end;

procedure TPainter.FastEllipse(x1, y1, x2, y2: integer; color: cardinal);
begin

end;

procedure TPainter.FastLine(x1, y1, x2, y2: integer; color: cardinal);
begin

end;

procedure TPainter.PreciseLine(x1, y1, x2, y2: single; color: cardinal);
begin

end;


procedure TPainter.FillRect(x1, y1, x2, y2: integer; color: cardinal);
begin

end;

procedure TPainter.PrintText(x, y: integer; color: cardinal; font: byte;
  alignment: TextAlignment; wrap: boolean; text: string);
begin

end;

procedure TPainter.RestoreClipping;
begin
 if curpos<>startpos then begin
  curpos:=(curpos-1) and 15;
  with clipbuf[curpos] do begin
   cx1:=left; cy1:=top;
   cx2:=right; cy2:=bottom;
  end;
 end;
end;

procedure TPainter.SetClipping(x1, y1, x2, y2: integer);
begin
 if curpos=startpos then startpos:=(startpos+1) and 15;
 with clipbuf[curpos] do begin
  left:=cx1; top:=cy1;
  right:=cx2; bottom:=cy2;
 end;
 curpos:=(curpos+1) and 15;
 cx1:=x1; cy1:=y1; cx2:=x2; cy2:=y2;
end;

procedure TPainter.SmoothEllipse(x1, y1, x2, y2: single; color: cardinal);
begin

end;

procedure TPainter.SmoothLine(x1, y1, x2, y2: single; color: cardinal);
begin

end;

procedure TPainter.FreeTarget;
begin
 if needLock and (buffer<>nil) then buffer.Unlock;
end;

end.
