{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestGFX;
uses
  Apus.Colors,
  Apus.MyServis,
  SysUtils,
  Apus.FastGFX;

procedure TestBilinear;
 var
  i:integer;
  time:int64;
  v:array[0..4] of single;
  c:array[0..4] of cardinal;
  f:single;
  col:cardinal;
  uu,vv:single;
 begin
  // float values
  v[0]:=0; v[1]:=1; v[2]:=2; v[3]:=-2;
  // Reference version
  uu:=0.6; vv:=0.4;
  f:=BilinearMixF(v[0],v[1],v[2],v[3],uu,vv);
  ASSERT(abs(f-0.2)<0.001);
  // SSE version
  f:=BilinearMixF(@v,0.6,0.4);
  ASSERT(abs(f-0.2)<0.001);
  f:=0;
  time:=MyTickCount;
  for i:=0 to 10000000 do begin
   f:=f+BilinearMixF(v[0],v[1],v[2],v[3],uu,vv)+
        BilinearMixF(v[0],v[1],v[2],v[3],vv,uu);
  end;
  time:=MyTickCount-time;
  writeln('Bilinear time: ',time,f:20:2);

  f:=0;
  time:=MyTickCount;
  for i:=0 to 10000000 do begin
   f:=f+BilinearMixF(@v,uu,vv)+
        BilinearMixF(@v,vv,uu);
  end;
  time:=MyTickCount-time;
  writeln('Bilinear time (SSE): ',time,f:20:2);

  // Colors
  c[0]:=$FF000000; c[1]:=$FF800000;
  c[2]:=$8000C000; c[3]:=$000000FF;
  // reference version
  col:=BilinearMix(c[0],c[1],c[2],c[3],0.5,0.5);
  ASSERT(SimpleColorDiff(col,$9F20303F)<6);
  col:=BilinearMix(c[0],c[1],c[2],c[3],0.4,0.2);
  ASSERT(SimpleColorDiff(col,$DB291713)<6);
  // SSE version
  col:=BilinearMix(@c,0.5,0.5);
  ASSERT(SimpleColorDiff(col,$9F20303F)<6);
  col:=BilinearMix(@c,0.4,0.2);
  ASSERT(SimpleColorDiff(col,$DB291713)<6);
  // Benchmark
  time:=MyTickCount;
  for i:=0 to 10000000 do begin
   col:=BilinearMix(c[0],c[1],c[2],c[3],0.4,0.2);
   col:=BilinearMix(c[0],c[1],c[2],c[3],0.4,0.2);
  end;
  time:=MyTickCount-time;
  writeln('Bilinear color time: ',time);
  // SSE
  time:=MyTickCount;
  for i:=0 to 10000000 do begin
   col:=BilinearMix(@c,0.4,0.2);
   col:=BilinearMix(@c,0.4,0.2);
  end;
  time:=MyTickCount-time;
  writeln('Bilinear color time (SSE): ',time);

 end;

procedure TestColors;
 var
  c1,c2,c3,c4:cardinal;
  i:integer;
  time:int64;
 begin
  c1:=$FF808080;
  c2:=$80004020;
  c3:=Blend(c1,c2);
  ASSERT(SimpleColorDiff(c3,$FF406050)<5);
  c4:=$30C0C0C0; // transparent background
  c3:=Blend(c4,c2);
  ASSERT(SimpleColorDiff(c3,$981D5338)<5);
  time:=MyTickCount;
  for i:=0 to 10000000 do begin
   c3:=Blend(c1,c2);
   c3:=Blend(c4,c2);
  end;
  time:=MyTickCount-time;
  writeln('Blend time: ',time);
 end;

begin
 try
  TestBilinear;
  TestColors;
  writeln('All OK');
 except
  on e:Exception do begin
   writeln('Error: ',ExceptionMsg(e));
   halt(255);
  end;
 end;
 readln;
end.
