program MakeAtlas2;
{$APPTYPE CONSOLE}

uses
  types,SysUtils,MyServis,images,gfxFormats;

var
 fname,atlasname:string;
 afile:text;
 atlas:TBitmapImage;
 border:integer=2;

 images:array[1..500] of TBitmapImage;
 fnames:array[1..500] of string;
 places:array[1..500] of TPoint;
 order:array[1..500] of integer;
 count:integer;
 usagemap:array[0..511,0..511] of byte;
 mapW,mapH:integer;

 width,height,size,x,y,w,h,i:integer;
 st:string;
 data:array of byte;
 f:file;

 // Sort by width
 procedure Sort;
  var
   i,j,k:integer;
  begin
   for i:=1 to count do
    order[i]:=i;
   for i:=1 to count-1 do
    for j:=i+1 to count do
     if images[order[j]].width>images[order[i]].width then begin
      k:=order[j];
      order[j]:=order[i];
      order[i]:=k;
     end;
  end;

 procedure FindBestPlaceFor(idx:integer);
  var
   i,x,y,iw,ih,last,cnt,tx,ty:integer;
   fl:boolean;
  begin
   // Find leftmost position, choose upper if multiple choice
   iw:=(images[idx].width+border+3) div 4;
   ih:=(images[idx].height+border+3) div 4;
   for x:=0 to mapW-iw do begin
    last:=-1; cnt:=0;
    for y:=0 to mapH-1 do begin
     if usagemap[x,y]<>0 then begin
      cnt:=0;
     end else begin
      if cnt=0 then last:=y;
      inc(cnt);
      if cnt=ih then begin // try this placement
       fl:=true;
       for tx:=1 to iw-1 do begin
        for ty:=0 to ih-1 do
         if usagemap[x+tx,last+ty]<>0 then begin
          fl:=false; break;
         end;
        if not fl then break;
       end;
       if fl then begin // placement found
        places[idx].X:=x*4+border div 2;
        places[idx].Y:=last*4+border div 2;
        for tx:=0 to iw-1 do
         for ty:=0 to ih-1 do
          usagemap[x+tx,last+ty]:=idx;
        write('*');
        exit;
       end;
      end;
     end;
    end;
   end;
   writeln('Error! No placement for image '+fnames[idx]);
   places[idx].X:=0;
   places[idx].Y:=0;
  end;

 procedure PlaceImage(idx:integer);
  var
   i,j,k:integer;
   sp,dp:PByte;
   c:cardinal;
  begin
   with images[idx] do begin
    Lock;
    sp:=data;
    dp:=atlas.data;
    inc(dp,places[idx].x*4+places[idx].y*atlas.pitch);
    for i:=0 to images[idx].height-1 do begin
     ConvertLine(sp^,dp^,PixelFormat,ipfARGB,palette^,paletteFormat,images[idx].width);
     if border>0 then begin
      // before line
      j:=border div 2;
      move(dp^,c,4);
      dec(dp,j*4);
      for k:=1 to j do begin
       move(c,dp^,4);
       inc(dp,4);
      end;
      // after line
      j:=border-border div 2;
      inc(dp,images[idx].width*4-4);
      move(dp^,c,4);
      for k:=1 to j do begin
       inc(dp,4);
       move(c,dp^,4);
      end;
      dec(dp,(j+images[idx].width-1)*4);
     end;
     inc(sp,pitch);
     inc(dp,atlas.pitch);
    end;

    if border>0 then begin // top & bottom margin
     j:=border div 2;
     sp:=atlas.data;
     inc(sp,(places[idx].x-j)*4+places[idx].y*atlas.pitch);
     for k:=1 to j do begin
      dp:=atlas.data;
      inc(dp,(places[idx].x-border div 2)*4+(places[idx].y-k)*atlas.pitch);
      move(sp^,dp^,(images[idx].width+border)*4);
     end;
     j:=border-border div 2;
     sp:=atlas.data;
     inc(sp,(places[idx].x-border div 2)*4+(places[idx].y+images[idx].height-1)*atlas.pitch);
     for k:=1 to j do begin
      dp:=atlas.data;

      inc(dp,(places[idx].x-border div 2)*4+(places[idx].y+images[idx].height-1+k)*atlas.pitch);
      move(sp^,dp^,(images[idx].width+border)*4);
     end;
    end;
    Unlock;
   end;
  end;

 procedure BuildAtlas;
  var
   i:integer;
  begin
   // 1. Sort
   Sort;
   // 2. Calculate positions
   mapW:=width div 4;
   mapH:=height div 4;
   for i:=1 to count do
    FindBestPlaceFor(order[i]);
   writeln;
   // 3. Transfer data
   atlas.Lock;
   for i:=1 to count do
    PlaceImage(i);
   atlas.Unlock;
  end;

begin
 if paramcount<1 then begin
  writeln('Usage: MakeAtlas2 atlasfile [border=n]');
  exit;
 end;
 fname:=paramstr(1);
 if paramcount>1 then
  for i:=2 to paramcount do begin
   st:=paramStr(i);
   if pos(st,'border=')=0 then begin
    delete(st,1,7);
    border:=strtointdef(st,border);
   end;
  end;
 if pos('.',fname)=0 then fname:=fname+'.atl';
 writeln('Processing '+fname);
 assignfile(afile,fname);
 reset(afile);
 readln(afile,width,height,atlasname);
 atlasname:=chop(atlasname);
 i:=pos(' border=',atlasname);
 if i>0 then begin
  st:=copy(atlasname,i+8,2);
  border:=StrToIntDef(st,border);
  setLength(atlasname,i-1);
 end;
 writeln('Border=',border);

 if pos('.',atlasname)=0 then atlasname:=atlasname+'.tga';
 atlas:=TBitmapImage.Create(width,height,ipfARGB);

 writeln('Loading images...');
 // Load all source files
 fillchar(atlas.data^,width*height*4,$00);
 while not eof(afile) do begin
  readln(afile,x,y,w,h,st);
  st:=chop(st);
  if st='' then continue;
  inc(count);
  if count>=500 then begin
   writeln('Too many images!');
   break;
  end;
  fnames[count]:=st;
  if pos('.',st)=0 then st:=st+'.tga';
  if not FileExists(st) then begin
    writeln('File not found: '+st);
    dec(count);
    continue;
  end;
  assign(f,st);
  reset(f,1);
  size:=filesize(f);
  setLength(data,size);
  blockread(f,data[0],size);
  close(f);
  try
   LoadTGA(@data[0],TRawImage(images[count]),true);
  except
   on e:exception do begin
    writeln('Error in file ',st,': ',e.message);
    dec(count);
   end;
  end;
 end;
 closefile(afile);
 
 writeln('Building the atlas...');
 BuildAtlas;

 writeln('Rewriting atlas file...');
 rewrite(afile);
 writeln(afile,width,' ',height,' ',atlasname,' border=',border);
 for i:=1 to count do
  writeln(afile,places[i].x:5,places[i].Y:5,
    images[i].width:6,images[i].height:5,' ',fnames[i]);
 close(afile);

 writeln('Writing output file ',atlasname);
 setlength(data,width*height*4+1024);
 size:=WriteTGA(@data[0],length(data),atlas);
 assign(f,atlasname);
 rewrite(f,1);
 blockwrite(f,data[0],size);
 close(f);
 writeln('Done!');
end.
