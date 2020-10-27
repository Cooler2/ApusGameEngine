
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.ADPCM;
interface

 function Compress_ADPCM4(var sour,dest;samples:integer;channels:byte):integer;
 procedure Decompress_ADPCM4(var sour,dest;samples:integer;channels:byte);

implementation
 type
  PSample=^smallint;
 var
  curMode:integer=0;
  comp1,comp2:array[-1024..1024] of byte;
  decomp1,decomp2:array[0..47] of integer;

 // V1 = 0..10, V2 = 0..22
 procedure Init_ADPCM4;
  var
   i,j,d,b,bestD:integer;
  begin
   if curmode=1 then exit;
   for i:=-5 to 5 do
    decomp1[i+5]:=10*i*i*i+i*80;
   for i:=-11 to 11 do
    decomp2[i+11]:=3*i*i*i+i*40;

   for i:=-1024 to 1024 do begin
    b:=-1; bestD:=100000;
    for j:=0 to 10 do begin
     d:=abs(decomp1[j]-(i*32));
     if d<bestD then begin
      bestD:=d; b:=j;
     end;
    end;
    comp1[i]:=b;

    b:=-1; bestD:=100000;
    for j:=0 to 22 do begin
     d:=abs(decomp2[j]-(i*32));
     if d<bestD then begin
      bestD:=d; b:=j;
     end;
    end;
    comp2[i]:=b;
   end;
   curmode:=1;
  end;

 function Compress_ADPCM4;
  var
   ch,block,cnt,i,curval,v1,v2:integer;
   s:PSample;
   d:PByte;
  begin
   Init_ADPCM4;
   d:=@dest;
   for block:=0 to (samples+1023) div 1024 do begin
    cnt:=samples-block*1024;
    if cnt>1024 then cnt:=1024;
    cnt:=cnt div 2;
    for ch:=0 to channels-1 do begin
     s:=@sour;
     inc(s,ch+channels*block*1024);
     curval:=s^;
     move(curval,d^,2); inc(s,channels); inc(d,2); // initial value
     for i:=0 to cnt-1 do begin
      v1:=s^; inc(s,channels);
      v2:=s^; inc(s,channels);
      v1:=v1-(curval+v2) div 2;
      v2:=v2-curval;
      if v2>10000 then v2:=10000;
      if v2<-10000 then v2:=-10000;
      if v1>10000 then v1:=10000;
      if v1<-10000 then v1:=-10000;
      v2:=comp2[v2 div 32];
      v1:=comp1[v1 div 32];
      d^:=v1+v2*11;
      inc(d);
      curval:=curval+decomp2[v2];
     end;
    end;
   end;
   result:=cardinal(d)-cardinal(@dest);
  end;

 procedure Decompress_ADPCM4;
  var
   ch,block,cnt,i,curval,v1,v2:integer;
   s:PByte;
   d:PSample;
  begin
   Init_ADPCM4;
   s:=@sour;
   for block:=0 to (samples+1023) div 1024 do begin
    cnt:=samples-block*1024;
    if cnt>1024 then cnt:=1024;
    cnt:=cnt div 2;
    for ch:=0 to channels-1 do begin
     d:=@dest;
     inc(d,ch+channels*block*1024);
     move(s^,d^,2); inc(s,2); // initial value
     curval:=d^; inc(d,channels);
     for i:=0 to cnt-1 do begin
      v1:=s^ mod 11;
      v2:=s^ div 11;
      inc(s);
      v2:=curval+decomp2[v2];
      v1:=(curval+v2) div 2+decomp1[v1];
      if v2>32767 then v2:=32767;
      if v1>32767 then v1:=32767;
      if v2<-32767 then v2:=-32767;
      if v1<-32767 then v1:=-32767;
      d^:=v1; inc(d,channels);
      d^:=v2; inc(d,channels);
      curval:=v2;
     end;
    end;
   end;
  end;

end.
