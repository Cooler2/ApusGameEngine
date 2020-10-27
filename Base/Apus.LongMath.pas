// -----------------------------------------------------
// Long-integer math
// Author: Ivan Polyacov (C) 2007-2008, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
// ------------------------------------------------------
{$R-}
unit Apus.LongMath;
interface
type
 // 256b number
 TBigInt=array[0..7] of cardinal;
 // 512b number
 TBigInt2=array[0..15] of cardinal;

 // Long math
 procedure bInc(var a:TBigInt;v:integer=1); register;
 procedure bDec(var a:TBigInt;v:integer=1); register;
 procedure bInc2(var a:TBigInt2;v:integer=1); register;
 procedure bDec2(var a:TBigInt2;v:integer=1); register;
 procedure bAdd(var a:TBigInt;b:TBigInt); register;
 procedure bSub(var a:TBigInt;b:TBigInt); register;
 procedure bAdd2(var a:TBigInt2;b:TBigInt2); register;
 procedure bSub2(var a:TBigInt2;b:TBigInt2); register;
 procedure bNeg(var a:TBigInt); register;
 procedure bNeg2(var a:TBigInt2); register;
 procedure bSqr(var a:TBigInt);
 procedure bSqr2(var a:TBigInt2);
 function bMult(a,b:TBigInt):TBigInt;
 function bMult2(a,b:TBigInt2):TBigInt2;
 procedure bShr(var a:TBigInt;n:integer);
 procedure bShl(var a:TBigInt;n:integer);
 procedure bShr2(var a:TBigInt2;n:integer);
 procedure bShl2(var a:TBigInt2;n:integer);
 procedure bDiv(a,m:TBigInt;var r,k:TBigInt); // r=a/m, k=a mod m
 procedure bDiv2(a,m:TBigInt2;var r,k:TBigInt2); // r=a/m, k=a mod m
 procedure bMod(var a:TBigInt;m:TBigInt); // a=a mod m
 function bPowMod(a,b,m:TBigInt):TBigInt; // a^b mod m
 function bPowMod2(a,b,m:TBigInt2):TBigInt2; // a^b mod m

 function bLastBit(a:TBigInt):integer; inline; // кол-во значащих битов
 function bLastBit2(a:TBigInt2):integer; inline;
 function IsZero(v:TBigInt):boolean; inline;
 function IsZero2(v:TBigInt2):boolean; inline;
 function bCmp(a,b:TBigInt):integer; inline; // unsigned compare
 function bCmp2(a,b:TBigInt2):integer; inline; // unsigned compare


implementation

 function bCmp(a,b:TBigInt):integer;
  var
   i:integer;
  begin
   result:=0;
   for i:=7 downto 0 do begin
    if a[i]<b[i] then begin
     result:=-1; exit;
    end;
    if a[i]>b[i] then begin
     result:=1; exit;
    end;
   end;
  end;

 function bCmp2(a,b:TBigInt2):integer;
  var
   i:integer;
  begin
   result:=0;
   for i:=15 downto 0 do begin
    if a[i]<b[i] then begin
     result:=-1; exit;
    end;
    if a[i]>b[i] then begin
     result:=1; exit;
    end;
   end;
  end;

 function IsZero(v:TBigInt):boolean;
  begin
   result:=v[0]=0;
   if not result then exit;
   result:=(v[1]=0) and (v[2]=0) and (v[3]=0) and (v[4]=0) and
     (v[5]=0) and (v[6]=0) and (v[7]=0);
  end;

 function IsZero2(v:TBigInt2):boolean;
  var
   i:integer;
  begin
   result:=v[0]=0;
   if not result then exit;
   for i:=1 to 15 do
    if v[i]<>0 then begin
     result:=false; exit;
    end;
   result:=true;
  end;


 procedure bInc(var a:TBigInt;v:integer=1);
  {$IFDEF CPU386}
  asm
   add [eax],v
   jnc @exit;
   adc dword ptr [eax+4],0
   adc dword ptr [eax+8],0
   adc dword ptr [eax+12],0
   adc dword ptr [eax+16],0
   adc dword ptr [eax+20],0
   adc dword ptr [eax+24],0
   adc dword ptr [eax+28],0
   @exit:
  end;
  {$ELSE}
  var
   i:integer;
  begin
   for i:=0 to 7 do begin
    inc(a[i]);
    if a[i]<>0 then break;
   end;
  end;
  {$ENDIF}

 procedure bDec(var a:TBigInt;v:integer);
  {$IFDEF CPU386}
  asm
   sub [eax],v
   jnc @exit;
   sbb dword ptr [eax+4],0
   sbb dword ptr [eax+8],0
   sbb dword ptr [eax+12],0
   sbb dword ptr [eax+16],0
   sbb dword ptr [eax+20],0
   sbb dword ptr [eax+24],0
   sbb dword ptr [eax+28],0
   @exit:
  end;
  {$ELSE}
  var
   i:integer;
  begin
   for i:=0 to 7 do begin
    dec(a[i]);
    if a[i]<>$FFFFFFFF then break;
   end;
  end;
  {$ENDIF}

 procedure bInc2(var a:TBigInt2;v:integer=1);
  {$IFDEF CPU386}
  asm
   add [eax],v
   jnc @exit;
   adc dword ptr [eax+4],0
   adc dword ptr [eax+8],0
   adc dword ptr [eax+12],0
   adc dword ptr [eax+16],0
   adc dword ptr [eax+20],0
   adc dword ptr [eax+24],0
   adc dword ptr [eax+28],0
   adc dword ptr [eax+32],0
   adc dword ptr [eax+36],0
   adc dword ptr [eax+40],0
   adc dword ptr [eax+44],0
   adc dword ptr [eax+48],0
   adc dword ptr [eax+52],0
   adc dword ptr [eax+56],0
   adc dword ptr [eax+60],0
   @exit:
  end;
  {$ELSE}
  var
   i:integer;
  begin
   for i:=0 to 7 do begin
    inc(a[i],v);
    if a[i]>=v then break;
    v:=1;
   end;
  end;
  {$ENDIF}

 procedure bDec2(var a:TBigInt2;v:integer);
  {$IFDEF CPU386}
  asm
   sub [eax],v
   jnc @exit;
   sbb dword ptr [eax+4],0
   sbb dword ptr [eax+8],0
   sbb dword ptr [eax+12],0
   sbb dword ptr [eax+16],0
   sbb dword ptr [eax+20],0
   sbb dword ptr [eax+24],0
   sbb dword ptr [eax+28],0
   sbb dword ptr [eax+32],0
   sbb dword ptr [eax+36],0
   sbb dword ptr [eax+40],0
   sbb dword ptr [eax+44],0
   sbb dword ptr [eax+48],0
   sbb dword ptr [eax+52],0
   sbb dword ptr [eax+56],0
   sbb dword ptr [eax+60],0
   @exit:
  end;
  {$ELSE}
  var
   i:integer;
  begin
   for i:=0 to 7 do begin
    dec(a[i],v);
    if a[i]<=$FFFFFFFF-v then break;
    v:=1;
   end;
  end;
  {$ENDIF}

 procedure bAdd(var a:TBigInt;b:TBigInt);
  {$IFDEF CPU386}
  asm
   clc
   mov ecx,[edx]
   add [eax],ecx
   mov ecx,[edx+4]
   adc [eax+4],ecx
   mov ecx,[edx+8]
   adc [eax+8],ecx
   mov ecx,[edx+12]
   adc [eax+12],ecx
   mov ecx,[edx+16]
   adc [eax+16],ecx
   mov ecx,[edx+20]
   adc [eax+20],ecx
   mov ecx,[edx+24]
   adc [eax+24],ecx
   mov ecx,[edx+28]
   adc [eax+28],ecx
  end;
  {$ELSE}
  var
    i:integer;
    c,d:cardinal;
  begin
   c:=0;
   for i:=0 to 7 do
    d:=(a[i]+b[i]+c) shr 32;
    a[i]:=(a[i]+b[i]+c) and $FFFFFFFF;
    c:=d;
  end;
  {$ENDIF}

 procedure bSub(var a:TBigInt;b:TBigInt);
  {$IFDEF CPU386}
  asm
   clc
   mov ecx,[edx]
   sub [eax],ecx
   mov ecx,[edx+4]
   sbb [eax+4],ecx
   mov ecx,[edx+8]
   sbb [eax+8],ecx
   mov ecx,[edx+12]
   sbb [eax+12],ecx
   mov ecx,[edx+16]
   sbb [eax+16],ecx
   mov ecx,[edx+20]
   sbb [eax+20],ecx
   mov ecx,[edx+24]
   sbb [eax+24],ecx
   mov ecx,[edx+28]
   sbb [eax+28],ecx
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

 procedure bAdd2(var a:TBigInt2;b:TBigInt2);
  {$IFDEF CPU386}
  asm
   clc
   mov ecx,[edx]
   add [eax],ecx
   mov ecx,[edx+4]
   adc [eax+4],ecx
   mov ecx,[edx+8]
   adc [eax+8],ecx
   mov ecx,[edx+12]
   adc [eax+12],ecx
   mov ecx,[edx+16]
   adc [eax+16],ecx
   mov ecx,[edx+20]
   adc [eax+20],ecx
   mov ecx,[edx+24]
   adc [eax+24],ecx
   mov ecx,[edx+28]
   adc [eax+28],ecx
   mov ecx,[edx+32]
   adc [eax+32],ecx
   mov ecx,[edx+36]
   adc [eax+36],ecx
   mov ecx,[edx+40]
   adc [eax+40],ecx
   mov ecx,[edx+44]
   adc [eax+44],ecx
   mov ecx,[edx+48]
   adc [eax+48],ecx
   mov ecx,[edx+52]
   adc [eax+52],ecx
   mov ecx,[edx+56]
   adc [eax+56],ecx
   mov ecx,[edx+60]
   adc [eax+60],ecx
  end;
{$ELSE}
  var
   i:integer;
   c:cardinal;
  begin
   c:=0;
   for i:=0 to 15 do begin
    a[i]:=a[i]+b[i]+c;
    if a[i]<b[i] then c:=1
     else c:=0;
   end;
  end;
{$ENDIF}

 procedure bSub2(var a:TBigInt2;b:TBigInt2);
  {$IFDEF CPU386}
  asm
   clc
   mov ecx,[edx]
   sub [eax],ecx
   mov ecx,[edx+4]
   sbb [eax+4],ecx
   mov ecx,[edx+8]
   sbb [eax+8],ecx
   mov ecx,[edx+12]
   sbb [eax+12],ecx
   mov ecx,[edx+16]
   sbb [eax+16],ecx
   mov ecx,[edx+20]
   sbb [eax+20],ecx
   mov ecx,[edx+24]
   sbb [eax+24],ecx
   mov ecx,[edx+28]
   sbb [eax+28],ecx
   mov ecx,[edx+32]
   sbb [eax+32],ecx
   mov ecx,[edx+36]
   sbb [eax+36],ecx
   mov ecx,[edx+40]
   sbb [eax+40],ecx
   mov ecx,[edx+44]
   sbb [eax+44],ecx
   mov ecx,[edx+48]
   sbb [eax+48],ecx
   mov ecx,[edx+52]
   sbb [eax+52],ecx
   mov ecx,[edx+56]
   sbb [eax+56],ecx
   mov ecx,[edx+60]
   sbb [eax+60],ecx
  end;
{$ELSE}
  begin
  end;
{$ENDIF}

 procedure bNeg(var a:TBigInt);
  {$IFDEF CPU386}
  asm
   not dword ptr [eax]
   not dword ptr [eax+4]
   not dword ptr [eax+8]
   not dword ptr [eax+12]
   not dword ptr [eax+16]
   not dword ptr [eax+20]
   not dword ptr [eax+24]
   not dword ptr [eax+28]
   add dword ptr [eax],1
   jnc @exit
   adc dword ptr [eax+4],0
   adc dword ptr [eax+8],0
   adc dword ptr [eax+12],0
   adc dword ptr [eax+16],0
   adc dword ptr [eax+20],0
   adc dword ptr [eax+24],0
   adc dword ptr [eax+28],0
   @exit:
  end;
{$ELSE}
  begin
  end;
{$ENDIF}

 procedure bNeg2(var a:TBigInt2);
  {$IFDEF CPU386}
  asm
   not dword ptr [eax]
   not dword ptr [eax+4]
   not dword ptr [eax+8]
   not dword ptr [eax+12]
   not dword ptr [eax+16]
   not dword ptr [eax+20]
   not dword ptr [eax+24]
   not dword ptr [eax+28]
   not dword ptr [eax+32]
   not dword ptr [eax+36]
   not dword ptr [eax+40]
   not dword ptr [eax+44]
   not dword ptr [eax+48]
   not dword ptr [eax+52]
   not dword ptr [eax+56]
   not dword ptr [eax+60]
   add dword ptr [eax],1
   jnc @exit
   adc dword ptr [eax+4],0
   adc dword ptr [eax+8],0
   adc dword ptr [eax+12],0
   adc dword ptr [eax+16],0
   adc dword ptr [eax+20],0
   adc dword ptr [eax+24],0
   adc dword ptr [eax+28],0
   adc dword ptr [eax+32],0
   adc dword ptr [eax+36],0
   adc dword ptr [eax+40],0
   adc dword ptr [eax+44],0
   adc dword ptr [eax+48],0
   adc dword ptr [eax+52],0
   adc dword ptr [eax+56],0
   adc dword ptr [eax+60],0
   @exit:
  end;
{$ELSE}
  var
   i:integer;
  begin
   for i:=0 to 15 do a[i]:=not a[i];
   for i:=0 to 15 do begin
    inc(a[i]);
    if a[i]<>0 then break;
   end;
  end;
{$ENDIF}

 procedure bShl(var a:TBigInt;n:integer);
  var
   i:integer;
   c,v:cardinal;
  begin
   if n>=32 then begin
    c:=n div 32;
    for i:=7 downto 0 do
     if i>=c then a[i]:=a[i-c] else a[i]:=0;
    n:=n mod 32;
    if n=0 then exit;
   end;
   c:=0;
   for i:=0 to 7 do begin
    v:=a[i];
    a[i]:=a[i] shl n+c;
    c:=v shr (32-n);
   end;
  end;

 procedure bShr(var a:TBigInt;n:integer);
  var
   i:integer;
   c,v:cardinal;
  begin
   if n>=32 then begin
    c:=n div 32;
    for i:=0 to 7 do
     if i+c<8 then a[i]:=a[i+c] else a[i]:=0;
    n:=n mod 32;
    if n=0 then exit;
   end;
   c:=0;
   for i:=7 downto 0 do begin
    v:=a[i];
    a[i]:=a[i] shr n+c;
    c:=v shl (32-n);
   end;
  end;

 procedure bShl2(var a:TBigInt2;n:integer);
  var
   i:integer;
   c,v:cardinal;
  begin
   if n>=32 then begin
    c:=n div 32;
    for i:=15 downto 0 do
     if i>=c then a[i]:=a[i-c] else a[i]:=0;
    n:=n mod 32;
    if n=0 then exit;
   end;
   c:=0;
   for i:=0 to 15 do begin
    v:=a[i];
    a[i]:=a[i] shl n+c;
    c:=v shr (32-n);
   end;
  end;

 procedure bShr2(var a:TBigInt2;n:integer);
  var
   i:integer;
   c,v:cardinal;
  begin
   if n>=32 then begin
    c:=n div 32;
    for i:=0 to 15 do
     if i+c<8 then a[i]:=a[i+c] else a[i]:=0;
    n:=n mod 32;
    if n=0 then exit;
   end;
   c:=0;
   for i:=15 downto 0 do begin
    v:=a[i];
    a[i]:=a[i] shr n+c;
    c:=v shl (32-n);
   end;
  end;

 function bLastBit(a:TBigInt):integer;
  var
   i:integer;
  begin
   result:=255;
   while result>=0 do begin
    if a[result shr 5] and (1 shl (result and 31))>0 then begin
     inc(result);
     exit;
    end;
    dec(result);
   end;
   inc(result);
  end;

 function bLastBit2(a:TBigInt2):integer;
  var
   i:integer;
  begin
   result:=511;
   while result>=0 do begin
    if a[result shr 5] and (1 shl (result and 31))>0 then begin
     inc(result);
     exit;
    end;
    dec(result);
   end;
   inc(result);
  end;

 function bMult(a,b:TBigInt):TBigInt;
  var
   i,l:integer;
   c:TBigInt;
   v:int64;
   neg:boolean;
  begin
   neg:=false;
   if (a[7] and $80000000>0) or (b[7] and $80000000>0) then begin
    // умножение со знаком
    neg:=(a[7] and $80000000>0) xor (b[7] and $80000000>0);
    if a[7] and $80000000>0 then bNeg(a);
    if b[7] and $80000000>0 then bNeg(b);
   end;
   v:=int64(a[0])*int64(b[0]);
   result[0]:=v; v:=v shr 32;
   v:=v+int64(a[1])*int64(b[0]);
   result[1]:=v; v:=v shr 32;
   v:=v+int64(a[2])*int64(b[0]);
   result[2]:=v; v:=v shr 32;
   v:=v+int64(a[3])*int64(b[0]);
   result[3]:=v; v:=v shr 32;
   result[4]:=v;
   result[5]:=0;
   result[6]:=0;
   result[7]:=0;

   c[0]:=0;
   v:=int64(a[0])*int64(b[1]);
   c[1]:=v; v:=v shr 32;
   v:=v+int64(a[1])*int64(b[1]);
   c[2]:=v; v:=v shr 32;
   v:=v+int64(a[2])*int64(b[1]);
   c[3]:=v; v:=v shr 32;
   v:=v+int64(a[3])*int64(b[1]);
   c[4]:=v; v:=v shr 32;
   c[5]:=v;
   c[6]:=0;
   c[7]:=0;
   bAdd(result,c);

   c[0]:=0;
   c[1]:=0;
   v:=int64(a[0])*int64(b[2]);
   c[2]:=v; v:=v shr 32;
   v:=v+int64(a[1])*int64(b[2]);
   c[3]:=v; v:=v shr 32;
   v:=v+int64(a[2])*int64(b[2]);
   c[4]:=v; v:=v shr 32;
   v:=v+int64(a[3])*int64(b[2]);
   c[5]:=v; v:=v shr 32;
   c[6]:=v;
   c[7]:=0;
   bAdd(result,c);

   c[0]:=0;
   c[1]:=0;
   c[2]:=0;
   v:=int64(a[0])*int64(b[3]);
   c[3]:=v; v:=v shr 32;
   v:=v+int64(a[1])*int64(b[3]);
   c[4]:=v; v:=v shr 32;
   v:=v+int64(a[2])*int64(b[3]);
   c[5]:=v; v:=v shr 32;
   v:=v+int64(a[3])*int64(b[3]);
   c[6]:=v; v:=v shr 32;
   c[7]:=v;
   bAdd(result,c);
   if neg then bNeg(result);
  end;


 function bMult2(a,b:TBigInt2):TBigInt2;
  var
   i,j,l:integer;
   c:TBigInt2;
   v:int64;
   neg:boolean;
  begin
   neg:=false;
   if (a[15] and $80000000>0) or (b[15] and $80000000>0) then begin
    // умножение со знаком
    neg:=(a[15] and $80000000>0) xor (b[15] and $80000000>0);
    if a[15] and $80000000>0 then bNeg2(a);
    if b[15] and $80000000>0 then bNeg2(b);
   end;
   fillchar(result,sizeof(result),0);
   for i:=0 to 7 do begin
    // умножить a на a[i] и прибавить к результату
    v:=0;
    fillchar(c,sizeof(c),0);
    for j:=0 to 7 do begin
     v:=v shr 32+int64(a[i])*int64(b[j]);
     c[i+j]:=cardinal(v);
    end;
    c[i+8]:=v shr 32;
    bAdd2(result,c);
   end;
   if neg then bNeg2(result);
  end;

 function bMultOld(a,b:TBigInt):TBigInt;
  var
   i,l:integer;
   c:cardinal;
  begin
   fillchar(result,sizeof(result),0);
   c:=1;
   l:=bLastBit(b);
   for i:=0 to l do begin
    if b[i shr 5] and c>0 then
     bAdd(result,a);
    c:=c shl 1;
    if c=0 then c:=1;
    bShl(a,1);
   end;
  end;

 procedure bSqr(var a:TBigInt);
 {$IFDEF CPU386}
  var
   aa,ab,ac,ad,bb,bc,bd,cc,cd,d2,v:int64;
   b:array[1..3] of cardinal;
  asm
   push esi
   push edi
   push ebx
   mov esi,a
   mov ecx,[esi+12];
   // AA
   mov eax,[esi+12]
   mul ecx
   mov dword ptr aa,eax
   mov dword ptr aa+4,edx
   // AB
   mov eax,[esi+08]
   mul ecx
   mov dword ptr ab,eax
   mov dword ptr ab+4,edx
   // AC
   mov eax,[esi+04]
   mul ecx
   mov dword ptr ac,eax
   mov dword ptr ac+4,edx
   // AD
   mov eax,[esi]
   mul ecx
   mov dword ptr ad,eax
   mov dword ptr ad+4,edx

   mov ecx,[esi+8]
   // BB
   mov eax,ecx
   mul ecx
   mov dword ptr bb,eax
   mov dword ptr bb+4,edx
   // BC
   mov eax,[esi+4]
   mul ecx
   mov dword ptr bc,eax
   mov dword ptr bc+4,edx
   // BD
   mov eax,[esi]
   mul ecx
   mov dword ptr bd,eax
   mov dword ptr bd+4,edx

   mov ecx,[esi+4]
   // CC
   mov eax,ecx
   mul ecx
   mov dword ptr cc,eax
   mov dword ptr cc+4,edx
   // CD
   mov eax,[esi]
   mul ecx
   mov dword ptr cd,eax
   mov dword ptr cd+4,edx
   // DD
   mov eax,[esi]
   mul eax
   mov dword ptr d2,eax
   mov dword ptr d2+4,edx
   // 1-st
   mov eax,dword ptr d2
   mov [esi],eax
   mov eax,dword ptr d2+4
   xor edx,edx
   add eax,dword ptr cd
   adc edx,dword ptr cd+4
   mov [esi+4],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr bd
   adc edx,dword ptr bd+4
   mov [esi+8],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr ad
   adc edx,dword ptr ad+4
   mov [esi+12],eax
   mov [esi+16],edx
   xor edx,edx
   mov [esi+20],edx
   mov [esi+24],edx
   mov [esi+28],edx
   // 2-nd
   lea edi,b
   mov ecx,dword ptr cd

   mov eax,dword ptr cd+4
   add eax,dword ptr cc
   adc edx,dword ptr cc+4
   mov [edi],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr bc
   adc edx,dword ptr bc+4
   mov [edi+4],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr ac
   adc edx,dword ptr ac+4
   mov [edi+8],eax
   // add
   add [esi+4],ecx
   mov eax,[edi]
   adc [esi+8],eax
   mov eax,[edi+4]
   adc [esi+12],eax
   mov eax,[edi+8]
   adc [esi+16],eax
   adc [esi+20],edx
   // 3rd
   mov ecx,dword ptr bd
   xor edx,edx

   mov eax,dword ptr bd+4
   add eax,dword ptr bc
   adc edx,dword ptr bc+4
   mov [edi],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr bb
   adc edx,dword ptr bb+4
   mov [edi+4],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr ab
   adc edx,dword ptr ab+4
   mov [edi+8],eax
   // add
   add [esi+8],ecx
   mov eax,[edi]
   adc [esi+12],eax
   mov eax,[edi+4]
   adc [esi+16],eax
   mov eax,[edi+8]
   adc [esi+20],eax
   adc [esi+24],edx
   // 4-th
   mov ecx,dword ptr ad
   xor edx,edx

   mov eax,dword ptr ad+4
   add eax,dword ptr ac
   adc edx,dword ptr ac+4
   mov [edi],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr ab
   adc edx,dword ptr ab+4
   mov [edi+4],eax
   mov eax,edx
   xor edx,edx
   add eax,dword ptr aa
   adc edx,dword ptr aa+4
   mov [edi+8],eax
   // add
   add [esi+12],ecx
   mov eax,[edi]
   adc [esi+16],eax
   mov eax,[edi+4]
   adc [esi+20],eax
   mov eax,[edi+8]
   adc [esi+24],eax
   adc [esi+28],edx

   pop ebx
   pop edi
   pop esi
  end;
 {$ELSE}
 begin
 end;
 {$ENDIF}

 procedure bSqr2(var a:TBigInt2);
  var
   i,j:integer;
   v:int64;
   res,r:TBigInt2;
  begin
   fillchar(res,sizeof(res),0);
   for i:=0 to 7 do begin
    // умножить a на a[i] и прибавить к результату
    v:=0;
    fillchar(r,sizeof(r),0);
    for j:=0 to 7 do begin
     v:=v shr 32+int64(a[i])*int64(a[j]);
     r[i+j]:=cardinal(v);
    end;
    r[i+8]:=v shr 32;
    bAdd2(res,r);
   end;
   move(res,a,sizeof(res));
  end;


 // Это в 13 раз быстрее, чем bMult(a,a)
 procedure bSqrOld(var a:TBigInt);
  var
   aa,ab,ac,ad,bb,bc,bd,cc,cd,dd,v:int64;
   b:TBigInt;
  begin
   aa:=int64(a[3])*int64(a[3]);
   ab:=int64(a[3])*int64(a[2]);
   ac:=int64(a[3])*int64(a[1]);
   ad:=int64(a[3])*int64(a[0]);
   bb:=int64(a[2])*int64(a[2]);
   bc:=int64(a[2])*int64(a[1]);
   bd:=int64(a[2])*int64(a[0]);
   cc:=int64(a[1])*int64(a[1]);
   cd:=int64(a[1])*int64(a[0]);
   dd:=int64(a[0])*int64(a[0]);
   // 1-st
   v:=dd;
   a[0]:=v; v:=v shr 32;
   v:=v+cd;
   a[1]:=v; v:=v shr 32;
   v:=v+bd;
   a[2]:=v; v:=v shr 32;
   v:=v+ad;
   a[3]:=v; v:=v shr 32;
   a[4]:=v;
   a[5]:=0;
   a[6]:=0;
   a[7]:=0;
   // b1
   b[0]:=0;
   v:=cd;
   b[1]:=v; v:=v shr 32;
   v:=v+cc;
   b[2]:=v; v:=v shr 32;
   v:=v+bc;
   b[3]:=v; v:=v shr 32;
   v:=v+ac;
   b[4]:=v; v:=v shr 32;
   b[5]:=v;
   b[6]:=0;
   b[7]:=0;
   bAdd(a,b);
   // b2
   b[1]:=0;
   v:=bd;
   b[2]:=v; v:=v shr 32;
   v:=v+bc;
   b[3]:=v; v:=v shr 32;
   v:=v+bb;
   b[4]:=v; v:=v shr 32;
   v:=v+ab;
   b[5]:=v; v:=v shr 32;
   b[6]:=v;
   bAdd(a,b);
   // b3
   b[2]:=0;
   v:=ad;
   b[3]:=v; v:=v shr 32;
   v:=v+ac;
   b[4]:=v; v:=v shr 32;
   v:=v+ab;
   b[5]:=v; v:=v shr 32;
   v:=v+aa;
   b[6]:=v; v:=v shr 32;
   b[7]:=v;
   bAdd(a,b);
  end;

 // деление цифрами по 16 бит
 procedure bDiv(a,m:TBigInt;var r,k:TBigInt); // r=a/m, k=a mod m
  type
   TBigInt2=array[0..15] of word;
  var
   i,j,l,t,s:integer;
   a2:TBigInt2 absolute a;
   m2:TBigInt2 absolute m;
   r2:TBigInt2 absolute r;
   k2:TBigInt2 absolute k;
   n:TBigInt;
   n2:TBigInt2 absolute n;
   nd:TBigInt;
   v,u,w:int64;
   d:cardinal;
  begin
   fillchar(r,sizeof(r),0);
   l:=15;
   while (l>=0) and (a2[l]=0) do dec(l);
   t:=15;
   while (t>=0) and (m2[t]=0) do dec(t);
   s:=l-t;
   n:=m;
   if s>0 then // Сдвиг на s слов влево
    for i:=15 downto 0 do
     if i>=s then n2[i]:=n2[i-s] else n2[i]:=0;

   if l<15 then v:=a2[l+1] else v:=0;
   u:=m2[t];
   if t>0 then u:=u shl 16+m2[t-1];

   for i:=s downto 0 do begin
    v:=v shl 16+a2[l];
//    if bCmp(a,n)>=0 then begin
     // цифра ненулевая, нужно её угадать
     if t=0 then d:=v div u // тривиальный случай
     else
      if l>0 then d:=(v shl 16+a2[l-1]) div u
       else d:=0;

     r2[i]:=d;

     if d<>0 then begin
     // Умножение на d
     w:=int64(n[0])*d;
     nd[0]:=w;
     for j:=1 to 7 do begin
      w:=w shr 32;
      w:=w+int64(n[j])*d;
      nd[j]:=w;
     end;

{     if bCmp(a,nd)<0 then begin // Ошибочка вышла (довольно редко, кстати)
      dec(d);
      r2[i]:=d;
      bSub(nd,n);
     end;}
     bSub(a,nd);
     if a[7] and $80000000>0 then begin
      bAdd(a,n);
      dec(r2[i]);
     end;
     v:=a2[l];
     if l<15 then v:=v+a2[l+1] shl 16;
    end;
    for j:=0 to 14 do
     n2[j]:=n2[j+1];
    n2[15]:=0;
    dec(l);
   end;
   k:=a;
  end;

 procedure bDiv2(a,m:TBigInt2;var r,k:TBigInt2); // r=a/m, k=a mod m
  type
   TBigIntW=array[0..31] of word;
  var
   i,j,l,t,s:integer;
   a2:TBigIntW absolute a;
   m2:TBigIntW absolute m;
   r2:TBigIntW absolute r;
   k2:TBigIntW absolute k;
   n:TBigInt2;
   n2:TBigIntW absolute n;
   nd:TBigInt2;
   v,u,w:int64;
   d:cardinal;
  begin
   fillchar(r,sizeof(r),0);
   l:=31;
   while (l>=0) and (a2[l]=0) do dec(l);
   t:=31;
   while (t>=0) and (m2[t]=0) do dec(t);
   s:=l-t;
   n:=m;
   if s>0 then // Сдвиг на s слов влево
    for i:=31 downto 0 do
     if i>=s then n2[i]:=n2[i-s] else n2[i]:=0;

   if l<31 then v:=a2[l+1] else v:=0;
   u:=m2[t];
   if t>0 then u:=u shl 16+m2[t-1];

   for i:=s downto 0 do begin
    v:=v shl 16+a2[l];
//    if bCmp(a,n)>=0 then begin
     // цифра ненулевая, нужно её угадать
     if t=0 then d:=v div u // тривиальный случай
     else
      if l>0 then d:=(v shl 16+a2[l-1]) div u
       else d:=0;

     r2[i]:=d;

     if d<>0 then begin
     // Умножение на d
     w:=int64(n[0])*d;
     nd[0]:=w;
     for j:=1 to 15 do begin
      w:=w shr 32;
      w:=w+int64(n[j])*d;
      nd[j]:=w;
     end;

{     if bCmp(a,nd)<0 then begin // Ошибочка вышла (довольно редко, кстати)
      dec(d);
      r2[i]:=d;
      bSub(nd,n);
     end;}
     bSub2(a,nd);
     if a[15] and $80000000>0 then begin
      bAdd2(a,n);
      dec(r2[i]);
     end;
     v:=a2[l];
     if l<31 then v:=v+a2[l+1] shl 16;
    end;
    for j:=0 to 30 do
     n2[j]:=n2[j+1];
    n2[31]:=0;
    dec(l);
   end;
   k:=a;
  end;

 procedure bDivOld(a,m:TBigInt;var r,k:TBigInt); // r=a/m, k=a mod m
  var
   i,l,t,s:integer;
   n:TBigInt;
  begin
   fillchar(r,sizeof(r),0);
   l:=bLastBit(a);
   t:=bLastBit(m);
   l:=l-t;
   n:=m;
   if l>0 then bShl(n,l);
   for i:=l downto 0 do begin
    if bCmp(a,n)>=0 then begin
     r[i shr 5]:=r[i shr 5] or (1 shl (i and 31));
     bSub(a,n);
    end;
    bShr(n,1);
   end;
   k:=a;
  end;

 procedure bMod(var a:TBigInt;m:TBigInt); // a=a mod m
  begin

  end;

 function bPowMod(a,b,m:TBigInt):TBigInt; // a^b mod m
  var
   i,j,l:integer;
   r,k:TBigInt;
  begin
   l:=bLastBit(b);
   fillchar(result,sizeof(result),0);
   result[0]:=1;
   for i:=0 to l do begin
    if b[i shr 5] and (1 shl (i and 31))>0 then begin
     result:=bMult(result,a);
     bDiv(result,m,r,k);
     result:=k;
    end;
    bSqr(a);
    bDiv(a,m,r,k);
    a:=k;
   end;
  end;

 function bPowMod2(a,b,m:TBigInt2):TBigInt2; // a^b mod m
  var
   i,j,l:integer;
   r,k:TBigInt2;
  begin
   l:=bLastBit2(b);
   fillchar(result,sizeof(result),0);
   result[0]:=1;
   for i:=0 to l do begin
    if b[i shr 5] and (1 shl (i and 31))>0 then begin
     result:=bMult2(result,a);
     bDiv2(result,m,r,k);
     result:=k;
    end;
    bSqr2(a);
    bDiv2(a,m,r,k);
    a:=k;
   end;
  end;

end.
