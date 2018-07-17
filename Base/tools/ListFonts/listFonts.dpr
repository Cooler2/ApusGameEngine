program listFonts;
{$APPTYPE CONSOLE}

uses
  MyServis,SysUtils,Images,GfxFormats,FastGFX,freeTypeFont,freeTypeH;

const
 line1:widestring='129) Water Elemental Привет!';  
 line2:widestring='Cooler summons Orc Shaman. (4+5/3 >= 4) Кулер призывает Гидру! ';
var
 sr:TSearchRec;
 r,i,x,y:integer;
 imgs:array[1..200] of TBitmapImage;
 count:integer;
 ext:string;
 img:TBitmapImage;
 data:ByteArray;

procedure RenderFont(fname:string);
 var
  font:TFreeTypeFont;
 begin
  writeln('Processing ',fname);
  try
  font:=TFreeTypeFont.LoadFromFile(fname);
  inc(count);
  imgs[count]:=TBitmapImage.Create(1000,110);
  with imgs[count] do begin
   FillRect(data,pitch,0,0,699,99,$FFE0E0E0);
   FillRect(data,pitch,699,0,699,99,$FFA0A0A0);
   FillRect(data,pitch,0,99,699,99,$FFA0A0A0);
   font.RenderText(data,pitch,3,20,font.name,$FF000000,12);
   font.RenderText(data,pitch,100,30,line1,$FF000000,26);
   font.RenderText(data,pitch,100,58,line2,$FF000000,13,0);
   font.RenderText(data,pitch,100,76,line2,$FF000000,13,FT_LOAD_FORCE_AUTOHINT);
   font.RenderText(data,pitch,100,94,line2,$FF000000,13,FT_LOAD_NO_HINTING);
  end;
  except
   on e:Exception do writeln(e.message);
  end;
 end;

begin
 r:=FindFirst('*.*',0,sr);
 while r=0 do begin
  ext:=UpperCase(ExtractFileExt(sr.name));
  if (ext='.TTF') or (ext='.OTF') then RenderFont(sr.name);
  r:=FindNext(sr);
  if count>=100 then break;
 end;
 FindClose(sr);
 writeln('Building output...');
 if count>0 then begin
  img:=TBitmapImage.Create(1400,100*((count+1) div 2));
  for i:=1 to count do begin
   x:=700*((i-1) mod 2);
   y:=100*((i-1) div 2);
   CopyRect(imgs[i].data,imgs[i].pitch,img.data,img.pitch,
     0,0,700,100,x,y);
  end;
  data:=WriteTGA(img);
  WriteFile('fonts.tga',@data[0],0,length(data));
 end;
 writeln('Done!');
end.
