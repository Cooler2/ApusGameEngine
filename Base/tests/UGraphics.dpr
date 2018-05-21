{$APPTYPE CONSOLE}
program UGraphics;

{%TogetherDiagram 'ModelSupport_UGraphics\default.txaPackage'}

uses
  types,
  MyServis,
  SysUtils,
  Geom2d,
  Geom3D,
  blitter in 'blitter.pas',
  painter in 'painter.pas',
  colors in 'colors.pas',
  directtext in 'directtext.pas',
  FastGFX in 'FastGFX.pas',
  filters in 'filters.pas',
  gfxformats in 'gfxformats.pas',
  Images in 'Images.pas',
  regions in 'regions.pas',
  formattext in 'formattext.pas',
  UnicodeFont in 'UnicodeFont.pas',
  glyphCaches in 'glyphCaches.pas',
  FreeTypeFont in 'FreeTypeFont.pas',
  AVS in 'AVS.pas',
  AVSUtils in 'AVSUtils.pas',
  AVSPlayer in 'AVSPlayer.pas',
  GifImage in 'GifImage.pas',
  IndexedImages in 'IndexedImages.pas';

procedure TestBlend;
 var
  i:integer;
  c,d,c1,c2:cardinal;
  t:int64;
 begin
  c1:=$FF0080FF;
  c2:=$20400000;
  for i:=0 to 16 do begin
   c:=ColorMix(c2,c1,i*16);
   d:=ColorBlend(c2,c1,i*16);
   writeln(i:2,IntToHex(c,8):10,IntToHex(d,8):10);
  end;
  t:=MyTickCount;
  for i:=1 to 20000000 do
   c:=ColorMix(c2,c1,100);
  writeln('T1 = ',20000000 div (MyTickCount-t), ' b/ms');

  t:=MyTickCount;
  for i:=1 to 20000000 do
   c:=ColorBlend(c2,c1,100);
  writeln('T2 = ',20000000 div (MyTickCount-t), ' b/ms');
 end;

procedure TestBilinear;
 var
  i,j:integer;
  c,d,c0,c1,c2,c3:cardinal;
  t:int64;
 begin
  c0:=$FFD00000;
  c1:=$FF0080FF;
  c2:=$20400000;
  c3:=$00000040;
  for i:=0 to 8 do begin
   for j:=0 to 8 do begin
    c:=BilinearMix(c0,c1,c2,c3,j/8,i/8);
    write(IntToHex(c,8):9);
   end;
   writeln;
  end;
  t:=MyTickCount;
  for i:=1 to 10000000 do
   c:=BilinearMix(c0,c1,c2,c3,0.2,0.3);
  writeln('T1 = ',10000000 div (MyTickCount-t), ' b/ms');
 end;

procedure TestResampleImage;
 type
  CArray=array[0..100] of cardinal;
 var
  sour,dest:TRawImage;
  data:ByteArray;
  size:integer;
  x,y,sx,sy:integer;
  p:PCardinal;
  u,v:single;
  c0,c1,c2,c3:cardinal;
  ps:^CArray;
 begin
//  data:=LoadFile2('btnTest.tga');
  data:=LoadFile2('test2.tga');
  LoadTGA(@data[0],sour,true);
  dest:=TBitmapImage.Create(50,50);
  sour.Lock;
  ps:=sour.data;
  dest.Lock;
  p:=dest.data;
  for y:=0 to 49 do
   for x:=0 to 49 do begin
{   u:=sour.width*x/400;
    v:=sour.height*y/300;}
    u:=sour.width*x/50-0.5;
    v:=sour.height*y/50-0.5;
    sx:=trunc(u); sy:=trunc(v);
    c0:=ps[sx+sy*sour.width];
    c1:=ps[sx+1+sy*sour.width];
    inc(sy);
    c2:=ps[sx+sy*sour.width];
    c3:=ps[sx+1+sy*sour.width];
    p^:=BilinearMix(c0,c1,c2,c3,frac(u),frac(v));
    inc(p);
   end;
  dest.Unlock;
  sour.Unlock;
  data:=SaveTGA(dest);
  WriteFile('btnResampled.tga',@data[0],0,length(data));
  writeln('Done!');
 end;

procedure TestDraw;
 var
  img:TBitmapImage;
  data:ByteArray;
  x,y:integer;
  pc:PCardinal;
  tex,tex2:array[0..7,0..7] of cardinal;
 begin
  img:=TBitmapImage.Create(64,64);
  pc:=img.data;
  for y:=0 to 63 do
   for x:=0 to 63 do begin
    pc^:=MyColor(Min2(y*8,255),$10,x*2,(x xor y)*4);
    inc(pc);
   end;

  for y:=0 to 7 do
   for x:=0 to 7 do
    tex[y,x]:=MyColor(x*32,y*32,0,0);

  for y:=0 to 7 do
   for x:=0 to 7 do
    if (x>0) and (y>0) and (x<7) and (y<7) then
     tex2[y,x]:=MyColor(255,max2(abs(x-4),abs(y-4))*60,0,0)
    else tex2[y,x]:=0;

{  for y:=1 to 5 do
   for x:=1 to 5 do
    SimpleDraw(@tex2,32,img.data,256,x*10,y*10,8,8);}

 for y:=1 to 2 do
   for x:=1 to 2 do
    StretchDraw(@tex2,32,img.data,256,
      x*20-8,y*20-8,x*20+8,y*20+8,
      1,1,6,6,blBlend);
  data:=SaveTGA(img);
  WriteFile('DrawTest.tga',@data[0],0,length(data));
  writeln('Done!');
 end;

procedure TestDraw2;
 var
  img:TBitmapImage;
  data:ByteArray;
  i,j,x,y:integer;
  pc:PCardinal;
  tex:array[0..7,0..7] of cardinal;
  v:single;
  font:TUnicodeFont;
  t:int64;
 begin
  img:=TBitmapImage.Create(300,200);

  font:=TUnicodeFont.LoadFromFile('arial14u.fnt',true);
  t:=MyTickCount;
  for j:=1 to 100 do begin
   img.Clear($FFC0C0C0);
   for i:=0 to 5 do begin
    v:=0.9+i*0.1;
    font.RenderText(img.data,img.pitch,3,40+i*20+(i*i),'Привет, Медвед! 123',$FF400010,v);
   end;
  end;
  writeln('Time = ',(MyTickCount-t)/100:4:2, ' ms');

  fillchar(tex,sizeof(tex),0);
  for y:=0 to 7 do
   for x:=0 to 7 do begin
    v:=sqr(x-3.5)+sqr(y-3.5);
    if (v>2.0) and (v<9) then tex[y,x]:=$FF0000F0
     else tex[y,x]:=$F0;
   end;

  SimpleDraw(@tex,32,img.data,img.pitch,1,1,8,8,blBlend);
  for i:=0 to 6 do begin
   v:=1+i*0.2;
   x:=i*25+30; y:=11;
   StretchDraw2(@tex,32,img.data,img.pitch,
      x-v*3,y-v*3,x+v*3,y+v*3,
      1,1,7,7,
      blBlend);
  end;

  data:=SaveTGA(img);
  WriteFile('DrawTest.tga',@data[0],0,length(data));
  writeln('Done!');
 end;

procedure TestFilters8;
 var
  img:TBitmapImage;
  sour:array[1..10,1..24] of byte;
  dest:array[1..10,1..16] of byte;
  x,y:integer;
  pb:PByte;
  res:pointer;
  v:integer;
  data:ByteArray;
 begin
  img:=TBitmapImage.Create(24,10,ipf8bit);
  for y:=1 to 10 do
   for x:=1 to 24 do
    if y<>5 then sour[y,x]:=random(255)
     else sour[y,x]:=x*10;
  move(sour,img.data^,10*24);
  data:=SaveTGA(img);
  WriteFile('FilterTest1.tga',@data[0],0,length(data));
  img.Free;

  img:=TBitmapImage.Create(16,10,ipf8bit);
{  res:=Blur8(@sour,24,16,10);
  move(res^,img.data^,160);
  FreeMem(res); }

  Minimum8(@sour,0,0,15,9,24,1,1);
  for y:=1 to 10 do
   for x:=1 to 16 do
    dest[y,x]:=sour[y,x];
  move(dest,img.data^,160);

  data:=SaveTGA(img);
  WriteFile('FilterTest2.tga',@data[0],0,length(data));
  writeln('Done');
 end;

procedure TestFilters32;
 var
  img:TBitmapImage;
  sour:array[1..10,1..24] of cardinal;
  dest:array[1..10,1..16] of cardinal;
  x,y:integer;
  pb:PByte;
  res:pointer;
  v:integer;
  data:ByteArray;
 begin
  img:=TBitmapImage.Create(24,10,ipfARGB);
  for y:=1 to 10 do
   for x:=1 to 24 do
    if y<>5 then sour[y,x]:=$FF800000+(y*$2000)+(x*$50) and $FF
     else sour[y,x]:=$FF000000+x*10;
  move(sour,img.data^,10*24*4);
  data:=SaveTGA(img);
  WriteFile('FilterTest1.tga',@data[0],0,length(data));
  img.Free;

  img:=TBitmapImage.Create(16,10,ipfARGB);
  res:=Blur32(@sour,24*4,16,10);
  move(res^,img.data^,160*4);
  FreeMem(res);

{  Minimum8(@sour,0,0,15,9,24,1,1);
  for y:=1 to 10 do
   for x:=1 to 16 do
    dest[y,x]:=sour[y,x];
  move(dest,img.data^,160);}

  data:=SaveTGA(img);
  WriteFile('FilterTest2.tga',@data[0],0,length(data));
  writeln('Done');
 end;


procedure TestGlyphCache;
 var
  c:TDynamicGlyphCache;
  i,j,cd,c1,c2,c3,w,h,s,n,n1:integer;
  p,p2:TPoint;
  r1,r2:TGlyphInfoRec;
  a:array[1..100] of integer;
  b:array[1..100] of TPoint;
  tex:array of integer;
 begin
  c:=TDynamicGlyphCache.Create(512,512);
  SetLength(tex,512*512);
  FillRect(@tex[0],2048,0,0,511,511,$FFFFFFFF);
  c1:=0; c2:=0; c3:=0;
  s:=0; n:=0; n1:=0;
  for i:=1 to 250 do begin
   // Cache random string
//   writeln(i);
   c.Keep;
   for j:=1 to 100 do begin
    cd:=random(100);
    a[j]:=cd;
    r1:=c.Find(cd);
    if r1.x<0 then begin
     w:=8+random(20);
     h:=8+random(20);
     inc(s,w*h); inc(n);
     p:=c.Alloc(w,h,0,0,cd);
     b[j]:=p;
     r2:=c.Find(cd);
     inc(c1);
     if (r1.x<>r2.x) or (r1.y<>r2.y) then inc(c2);
     FillRect(@tex[0],2048,p.X,p.y,p.x+w-1,p.Y+h-1,cd);
    end else
     b[j]:=p;
   end;
   // Check
   for j:=1 to 100 do
    if tex[b[j].Y*512+b[j].x]<>a[j] then begin
     inc(c3);
     writeln('Error ',i,':',j);
    end;
   c.Release;
   writeln('s/n:',s:9,n:6,(n-n1):4,s/n:8:1, c.Usage:8:3);
   n1:=n;
  end;
  writeln('Misses: ',c1,'   Errors: ',c2,' ',c3);
 end;

procedure TestSharpen;
 var
  buf:array[0..2,0..2] of cardinal;
  c:cardinal;
 begin
  c:=$FFC08020;
  buf[0,0]:=c; buf[0,1]:=c; buf[0,2]:=c;
  buf[2,0]:=c; buf[2,1]:=c; buf[2,2]:=c;
  c:=$FF000010;
  buf[1,0]:=c; buf[1,1]:=c; buf[1,2]:=c;
  Sharpen(@buf,3*4,3,3,256);
 end;

procedure TestStretchDraw2;
 var
  sour:array[0..3,0..3] of cardinal;
  dest:array[0..5,0..5] of cardinal;
 begin
  sour[1,1]:=$FFFF0000;
  sour[1,2]:=$FFFF00FF;
  sour[2,1]:=$FF00FF00;
  sour[2,2]:=$FF00FFFF;
  fillchar(dest,sizeof(dest),$33);
  StretchDraw1(@sour,4*4,@dest,6*4,
    1,1,4,5, // full area: 0,0 - width-1,height-1
    1,1,2,2,
    blCopy);
 end;

procedure TestFigures;
 var
  img:TBitmapImage;
  buf:ByteArray;
  f:file;
  i:integer;
 begin
  img:=TBitmapImage.Create(50,50);
  img.Lock;
  FillRect(img.data,img.pitch,0,0,img.width-1,img.height-1,$FFFFFFFF);
  SetRenderTarget(img.data,img.pitch,img.width,img.height);
//  FillCircle(5,50,20,$FFC0E000);
  for i:=1 to 30 do
   FillCircle(random(200)/4,random(200)/4,3+random(100)/10,$C0000000+$30*(i and 3)+$2000*(i shr 2)+$500000*(i shr 4));
  buf:=SaveTGA(img);
  img.Free;
  WriteFile('figures.tga',@buf[0],0,length(buf));
 end;

procedure TestFigures2;
 var
  img:TBitmapImage;
  buf:ByteArray;
  f:file;
  i,j:integer;
  points:array[0..20] of TPoint2s;
  x,y:integer;
  a,r:single;
 begin
  randSeed:=314159265;
  img:=TBitmapImage.Create(600,500);
  img.Lock;
  FillRect(img.data,img.pitch,0,0,img.width-1,img.height-1,$FFFFFFFF);
  SetRenderTarget(img.data,img.pitch,img.width,img.height);
  // Polylines
  for i:=0 to 29 do begin
   x:=20+(i mod 10)*62;
   y:=40+(i div 10)*50;
   for j:=0 to 9 do begin
    a:=j*0.6; r:=10+random*20;
    points[j].x:=x+r*cos(a);
    points[j].y:=y+r*sin(a);
   end;
   DrawPolyline(@points,10,true,MyColor(100+random(150),random(200),random(200),random(200)),1);
  end;
  // Polygons
  for i:=0 to 29 do begin
   x:=20+(i mod 10)*62;
   y:=240+(i div 10)*50;
   for j:=0 to 9 do begin
    a:=j*0.6; r:=10+random*20;
    points[j].x:=x+r*cos(a);
    points[j].y:=y+r*sin(a);
   end;
   FillPolygon(@points,10,MyColor(100+random(150),random(200),random(200),random(200)));
  end;

  buf:=SaveTGA(img);
  img.Free;
  WriteFile('figures2.tga',@buf[0],0,length(buf));
 end;

procedure TestPie;
 var
  img,img2:TBitmapImage;
  buf,buf2:ByteArray;
  f:file;
  i,j:integer;
  points:array[0..20] of TPoint2s;
  x,y:integer;
  a,r:single;
 begin
  randSeed:=314159265;
  img:=TBitmapImage.Create(600,500);
  img2:=TBitmapImage.Create(img.width div 2,img.height div 2);
  img.Lock;
  FillRect(img.data,img.pitch,0,0,img.width-1,img.height-1,$FFFFFFFF);
  SetRenderTarget(img.data,img.pitch,img.width,img.height);
  for i:=1 to 9 do
   for j:=1 to 11 do begin
    PieSlice(j*50-25,i*50-25,20,j/3,j/3+i/2,$FF600000);
   end;

  for i:=0 to 20 do
   FillRect(img.data,img.pitch,i,0,i,10,$FF005000+(i and 1)*$B0);

  buf:=SaveTGA(img);
  img2.Lock;
  Downsample2x(img.data,img.pitch,img2.data,img2.pitch,img.width,img.height);
  buf2:=SaveTGA(img2);
  img.Free;
  img2.Free;
  WriteFile('pie.tga',@buf[0],0,length(buf));
  WriteFile('pie2.tga',@buf2[0],0,length(buf2));
 end;


 procedure TestColors;
  var
   i,j,k:integer;
   mat:TMatrix43s;
  begin
   for i:=0 to 8 do begin
     mat:=Hue(i/3);
     for j:=0 to 2 do
      writeln(mat[j,0]:6:2,mat[j,1]:6:2,mat[j,2]:6:2);
    writeln;
   end;
  end;

begin
 try
//   TestColors;
//   TestFigures;
   TestPie;
//  TestStretchDraw2;
//  TestSharpen;
//  TestBlend;
//  TestBilinear;
//  TestResampleImage;
//  TestDraw2;
//  TestFilters32;
//  TestFilters8;
//  TestGlyphCache;
  writeln('Done!');
 except
  on e:exception do writeln('ERROR: '+e.message);
 end;
 readln;
end.