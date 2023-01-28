program SliceImg;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils, Apus.Common, Apus.Images, Apus.GfxFormats, Apus.FastGfx;

var
 data:ByteArray;
 img:TRawImage;
 bmp:TBitmapImage;
 xStart,yStart,width,height,stepX, stepY:integer;
 x,y,n:integer;
 ext:string;

begin
  if paramCount<5 then begin
   writeln('Usage: SliceImg image.png/jpg xStart yStart width height [stepX] [stepY]');
   halt;
  end;
  try
   img:=nil;
   data:=LoadFileAsBytes(ParamStr(1));
   ext:=ExtractFileExt(ParamStr(1));
   if SameText(ext,'.jpg') then
    LoadJPEG(data,img)
   else
   if SameText(ext,'.png') then
    LoadPNG(data,img)
   else begin
    Writeln('Unsupported file type: ',ext);
    halt;
   end;

   xStart:=ParseInt(ParamStr(2));
   yStart:=ParseInt(ParamStr(3));
   width:=ParseInt(ParamStr(4));
   height:=ParseInt(ParamStr(5));
   stepX:=width; stepY:=height;
   if ParamCount>5 then stepX:=ParseInt(ParamStr(6));
   if ParamCount>6 then stepY:=ParseInt(ParamStr(7));
   x:=xStart; y:=yStart;
   n:=1;
   repeat
     bmp:=TBitmapImage.Create(width,height);
     CopyRect(img.data,img.pitch,
       bmp.data,bmp.pitch,
       x,y,width,height,
       0,0);
     data:=SavePNG(bmp);
     bmp.Free;
     SaveFile(Format('slice%.3d.png',[n]),data);
     inc(x,stepX);
     if x+width>img.width then begin
       inc(y,stepY);
       x:=xStart;
     end;
     inc(n);
   until y+height>img.height;
  except
   on e:exception do writeln('Error: '+ExceptionMsg(e));
  end;
end.
