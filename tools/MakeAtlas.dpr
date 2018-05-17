program MakeAtlas;
{$APPTYPE CONSOLE}

uses
  SysUtils,MyServis,images,gfxFormats;

var
 fname,atlasname:string;
 afile:text;
 atlas,img:TBitmapImage;
 width,height,size,x,y,w,h,i:integer;
 st:string;
 data:array of byte;
 f:file;
 sp,dp:PByte;
begin
 if paramcount<>1 then begin
  writeln('Usage: MakeAtlas atlasfile');
  exit;
 end;
 fname:=paramstr(1);
 if pos('.',fname)=0 then fname:=fname+'.atl';
 writeln('Processing '+fname);
 writeln;
 assignfile(afile,fname);
 reset(afile);
 readln(afile,width,height,atlasname);
 atlasname:=chop(atlasname);
 if pos('.',atlasname)=0 then atlasname:=atlasname+'.tga';
 atlas:=TBitmapImage.Create(width,height,ipfARGB);

 atlas.Lock;
 fillchar(atlas.data^,width*height*4,$60);
 while not eof(afile) do begin
  readln(afile,x,y,w,h,st);
  st:=chop(st);
  if st='' then continue;
  if pos('.',st)=0 then st:=st+'.tga';
  if not FileExists(st) then begin
    writeln('File not found: '+st);
    continue;
  end;
  assign(f,st);
  reset(f,1);
  size:=filesize(f);
  setLength(data,size);
  blockread(f,data[0],size);
  close(f);
  LoadTGA(@data[0],TRawImage(img),true);
{  if not (img.PixelFormat in [ipfARGB,ipfXRGB,ipfRGB]) then begin
   writeln(st+' is not a 32-bpp TGA image file!');
   continue;
  end;}
  img.Lock;
  sp:=img.data;
  dp:=atlas.data;
  inc(dp,x*4+y*atlas.pitch);
  for i:=0 to img.height-1 do begin
   ConvertLine(sp^,dp^,img.PixelFormat,ipfARGB,sp,palNone,img.width);
//   move(sp^,dp^,img.width*4);
   inc(sp,img.pitch);
   inc(dp,atlas.pitch);
  end;
  img.Unlock;
  img.Free;
 end;
 atlas.Unlock;
 closefile(afile);

 setlength(data,width*height*4+1024);
 size:=WriteTGA(@data[0],length(data),atlas);
 assign(f,atlasname);
 rewrite(f,1);
 blockwrite(f,data[0],size);
 close(f);
 writeln('Writing output file ',atlasname);
end.
