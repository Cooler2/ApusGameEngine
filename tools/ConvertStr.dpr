// Convert image (PNG/TGA) to/from STR(ing)
program ConvertStr;
{$APPTYPE CONSOLE}

uses
  System.SysUtils, Apus.Common, Apus.Colors, Apus.Images, Apus.GfxFormats;

var
 image,image2:TRawImage;
 src,dst:string;
 data:ByteArray;
 imgType:TImageFileType;
 str:string8;
 x,y,diff:integer;
begin
 if ParamCount=0 then begin
  writeln('Usage: ConvertStr source[.png/.tga] [target]');
  exit;
 end;
 try
  src:=ParamStr(1);
  if ParamCount>1 then dst:=ParamStr(2)
   else dst:=ChangeFileExt(src,'.str');
  writeln('Reading ',src);
  if SameText(ExtractFileExt(src),'.str') then begin
   // Reverce conversion
   LoadStr(LoadFileAsString(src),image);
   writeln('Converting to PNG...');
   data:=SavePNG(image);
   dst:=ChangeFileExt(src,'.png');
   writeln('Saving to ',dst);
   SaveFile(dst,data);
   writeln('Done!');
   exit;
  end;
  data:=LoadFileAsBytes(src);
  writeln('Unpacking...');
  imgType:=CheckImageFormat(data);
  case imgType of
   ifTGA:LoadTGA(data,image,true);
   ifPNG:LoadPNG(data,image);
   else
    raise EError.Create('Unsupported image file format');
  end;
  ASSERT(image<>nil);
  writeln('Converting to STR...');
  str:=SaveSTR(image);
  writeln('Verifying...');
  LoadSTR(str,image2);
  for y:=0 to image.height-1 do
   for x:=0 to image.width-1 do begin
    diff:=SimpleColorDiff(image.GetPixelARGB(x,y),image2.GetPixel(x,y));
    if diff>4 then
     Sleep(0);
    //ASSERT(diff<5,'Color difference too high');
   end;
  writeln('Saving...');
  SaveFile(dst,str);
  /// SaveFile('test.png',SavePng(image2));  // for debug
  writeln('Done!');
 except
  on e:Exception do writeln('ERROR: '+ExceptionMsg(e));
 end;
end.
