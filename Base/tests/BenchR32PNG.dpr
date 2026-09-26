{$APPTYPE CONSOLE}
program BenchR32PNG;
uses SysUtils, Apus.Core, Apus.Images, Apus.GfxFormats;
var
  names:array[0..4] of string=('rgba_large','ui_small','palette','gray','interlaced');
  i,j,loops:integer;
  st:string;
  data:ByteArray;
  f:file;
  img:TRawImage;
  tick:int64;
begin
  writeln('PNG decoder: ',{$IFDEF LODEPNG}'LodePNG'{$ELSE}'FPC reader'{$ENDIF});
  for i:=0 to 4 do begin
    st:='r32_png/'+names[i]+'.png';
    Assign(f,st);
    Reset(f,1);
    SetLength(data,FileSize(f));
    BlockRead(f,data[0],length(data));
    Close(f);
    if i=1 then loops:=300 else loops:=30;
    tick:=GetTickCount64;
    for j:=1 to loops do begin
      img:=nil;
      LoadPNG(data,img);
      img.Free;
    end;
    writeln(names[i],': ',length(data),' bytes, ',loops,' decodes, ',
      GetTickCount64-tick,' ms');
  end;
end.
