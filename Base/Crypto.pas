// Copyright (C) Apus Software, www.apus-software.com
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$H-,Q-,R-}
unit Crypto;
interface
type
 TMatrix32=array[0..31] of cardinal;
 Word64=array[0..1] of cardinal;
 Word128=array[0..3] of cardinal;

 // Protected container
 // Это буфер, хранящий данные в слабошифрованном виде
 TProtContainer=class
  constructor Create(startSize:integer); // Создать буфер с указанным размером
  procedure SetSize(newSize:integer); // Изменить размер буфера (данные не теряются)
  procedure WriteTo(posit,count:integer;var sour); // записать данные в буфер (начиная с позиции posit)
  procedure ReadFrom(posit,count:integer;var dest); // прочитать данные из буфера (начиная с позиции posit)
  destructor Destroy; override; // Освободить буфер
 private
  size,bias:integer;
  buffer:pointer;
 end;

var
 MyRandSeed:cardinal=81921;
 NoiseMask:array[0..255] of byte;

// Own random implementation
function  MyRand(max:cardinal):integer;

// XOR data with pseudorandom sequence based on code
procedure EncryptFast(var data;size,code:integer);

// Generate non-degenerated 32x32 boolean matrix
procedure GenMatrix32(out mat:TMatrix32;code:string);

// Calculate inverted matrix
function InvertMatrix32(mat:TMatrix32):TMatrix32;

// Multiply matrix on vector (32 bit)
function Mult32(var mat:TMatrix32;value:cardinal):cardinal;

// Multiply two matrices (32x32 bit)
function MultMat32(var m1,m2:TMatrix32):TMatrix32;

// Encrypt data using 32x32bit matrix 'mat'
// A-variant is better, old is maintained for backward compatibility
procedure Encrypt32(var data;size:integer;mat:TMatrix32);
procedure Encrypt32A(var data;size:integer;mat:TMatrix32);

// Decrypt data, mat should be inverse matrix
procedure Decrypt32(var data;size:integer;mat:TMatrix32);
procedure Decrypt32A(var data;size:integer;mat:TMatrix32);

// Perform calculation of checksum, that can't be obtained fast
function CheckSumSlow(var data;size,passes:integer):cardinal;

procedure GenerateKeyPair(a,b:WORD64);

implementation
type
 PByte=^byte;


function MyRand;
 begin
  MyRandSeed:=MyRandSeed*69069+1151;
  result:=integer(max*MyRandSeed shr 32);
 end;

procedure EncryptFast;
 var
  p:PByte;
  i:integer;
 begin
  p:=addr(data);
  MyRandSeed:=code;
  for i:=1 to size do begin
   p^:=p^ xor MyRand(256);
   inc(p);
  end;
 end;

procedure GenMatrix32;
 var
  posit,bits:integer;

 function getBit:byte;
  begin
   result:=(byte(code[posit div 8]) shr (posit mod 8)) and 1;
   inc(posit);
   if posit>=bits then posit:=0;
  end;

 procedure PutBit(x,y:integer;value:byte);
  var
   mask:cardinal;
  begin
   mask:=not (1 shl x);
   mat[y]:=mat[y] and mask+(value shl x);
  end;

 procedure FillMatCustom(x,y,size:integer);
  var
   i,j:integer;
  begin
   for i:=0 to size-1 do
    for j:=0 to size-1 do
     PutBit(x+i,y+j,GetBit);
  end;

 procedure FillMat0(x,y,size:integer);
  var
   i,j:integer;
  begin
   for i:=0 to size-1 do
    for j:=0 to size-1 do
     PutBit(x+i,y+j,0);
  end;

 procedure FillMat1(x,y,size:integer);
  begin
   if size=1 then begin
    PutBit(x,y,1);
    exit;
   end;
   size:=size div 2;
   FillMat1(x,y,size);
   FillMat1(x+size,y+size,size);
   if GetBit>0 then begin
    FillMat0(x+size,y,size);
    FillMatCustom(x,y+size,size);
   end else begin
    FillMatCustom(x+size,y,size);
    FillMat0(x,y+size,size);
   end;
  end;

 begin
  MyRandSeed:=182739;
  posit:=0; bits:=length(code)*8;
  FillMat1(0,0,32);
 end;

function InvertMatrix32;
 var
  i,j:integer;
  m2:TMatrix32;

 // Add line i to line j
 procedure AddLine(i,j:integer);
  begin
   mat[j]:=mat[j] xor mat[i];
   m2[j]:=m2[j] xor m2[i];
  end;

 begin
  m2[0]:=1;
  for i:=1 to 31 do
   m2[i]:=m2[i-1] shl 1;
  // Forward Gauss
  for i:=0 to 30 do begin
   if (mat[i] shr i) and 1=0 then begin
    for j:=i+1 to 31 do
     if (mat[j] shr i) and 1>0 then begin
      AddLine(j,i);
      break;
     end;
   end;

   for j:=i+1 to 31 do
    if (mat[j] shr i) and 1>0 then
     AddLine(i,j);
  end;
  // Backward Gauss
  for i:=31 downto 1 do begin
   for j:=0 to i-1 do
    if (mat[j] shr i) and 1>0 then
     AddLine(i,j);
  end;
  result:=m2;
 end;

function Mult32;
 {$IFDEF CPU386}
 asm
   push ebx
   push esi
   mov ebx,value
   mov esi,mat
   mov edx,16
   xor eax,eax
@inner:
   test bl,1
   jz @01
   xor eax,[esi]
@01:
   test bl,2
   jz @02
   xor eax,[esi+4]
@02:
   add esi,8
   shr ebx,2
   dec edx
   jnz @inner
   pop esi
   pop ebx
 end;
 {$ELSE}
 var
  i:integer;
 begin
  result:=0;
  for i:=0 to 31 do begin
   if value and 1>0 then result:=result xor mat[i];
   value:=value shr 1;
  end;
 end;
 {$ENDIF}

function MultMat32;
 var
  i,j,k:integer;
  b:byte;
 begin
  fillchar(result,sizeof(result),0);
  for i:=0 to 31 do
   for j:=0 to 31 do begin
    b:=0;
    for k:=0 to 31 do begin
     b:=b xor ((m1[i] shr k) and 1) and
              ((m2[k] shr j) and 1);
    end;
    result[i]:=result[i] or (b shl j);
   end;
 end;

procedure encrypt32;
 var
  i:integer;
  p:^cardinal;
  old,val:cardinal;
 begin
  p:=addr(data);
  old:=0;
  for i:=1 to size div 4 do begin
   val:=p^;
   p^:=Mult32(mat,p^-old);
   old:=val;
   inc(p);
  end;
 end;
procedure encrypt32A;
 var
  i:integer;
  p:^cardinal;
  old:cardinal;
 begin
  p:=addr(data);
  old:=0;
  for i:=1 to size div 4 do begin
   p^:=Mult32(mat,p^)-old;
   old:=p^;
   inc(p);
  end;
 end;


procedure decrypt32;
 var
  i:integer;
  p:^cardinal;
  old:cardinal;
 begin
  p:=addr(data);
  old:=0;
  for i:=1 to size div 4 do begin
   p^:=old+Mult32(mat,p^);
   old:=p^;
   inc(p);
  end;
 end;
procedure decrypt32A;
 var
  i:integer;
  p:^cardinal;
  old,val:cardinal;
 begin
  p:=addr(data);
  old:=0;
  for i:=1 to size div 4 do begin
   val:=p^;
   p^:=Mult32(mat,p^+old);
   old:=val;
   inc(p);
  end;
 end;


function CheckSumSlow;
 var
  p:^word;
  i,j:integer;
  v:word;
 begin
  p:=addr(data);
  v:=319+p^;
  result:=0;
  for i:=1 to size div 2 do begin
   MyRandSeed:=v;
   for j:=0 to passes do
    inc(result,(2839401+MyRand(100000000)) mod (p^+MyRand(10000)));
   v:=v+p^+19;
   inc(p);
  end;
  if size mod 2=1 then
   inc(result,PByte(p)^);
 end;

 constructor TProtContainer.Create;
  begin
   size:=startsize;
   ReallocMem(buffer,size);
   bias:=MyRand(100);
  end;
 procedure TProtContainer.SetSize;
  begin
   if newsize<>size then begin
    size:=newsize;
    ReallocMem(buffer,size);
   end;
  end;
 procedure TProtContainer.WriteTo;
  var
   p,p2:PByte;
   i,pos:integer;
  begin
   if (posit<0) or (posit+count>size) then exit;
   p:=addr(sour);
   p2:=buffer;
   inc(p2,posit);
   pos:=(posit+bias)*39;
   for i:=1 to count do begin
    p2^:=p^ xor (NoiseMask[pos and 255]+pos);
    inc(pos,39);
    inc(p2); inc(p);
   end;
  end;
 procedure TProtContainer.ReadFrom;
  var
   p,p2:PByte;
   i,pos:integer;
  begin
   if (posit<0) or (posit+count>size) then exit;
   p:=addr(dest);
   p2:=buffer;
   inc(p2,posit);
   pos:=(posit+bias)*39;
   for i:=1 to count do begin
    p^:=p2^ xor (NoiseMask[pos and 255]+pos);
    inc(pos,39);
    inc(p2); inc(p);
   end;
  end;
 destructor TProtContainer.Destroy;
  begin
   ReallocMem(buffer,0);
  end;

 // Деление 128-битного числа на 32-битное с остатком
 procedure Divide128(const sour:Word128;arg:cardinal;var res:Word128;var rest:cardinal);
  var
   i:integer;
   c:cardinal;
   v:int64;
  begin
   fillchar(res,sizeof(res),0); v:=0;
   for i:=3 downto 0 do begin
    v:=v shl 32+sour[i];
    if v<arg then continue;
    res[i]:=v div arg;
    v:=v mod arg;
   end;
   rest:=v;
  end;

 procedure GenerateKeyPair;
  var
   n,n1:Word128;
   i:integer;
   d,r:cardinal;
   dividers:array[1..20] of cardinal;
   divcnt:integer;
   m:int64;
  begin
   randomize;
   repeat
    // попытка сгенерить ключи
    divcnt:=0;
    fillchar(n,sizeof(n),0);
    for i:=0 to 3 do begin
     n[2]:=n[2] or (Random(256) shl (i*8));
     n[3]:=n[3] or (Random(256) shl (i*8));
    end;
    n[0]:=1; m:=1;
    // Теперь будем раскладывать на множители
    d:=3;
    repeat
     Divide128(n,d,n1,r);
     if r=0 then begin // Найден множитель
      m:=m*d; n:=n1; inc(divcnt); dividers[divcnt]:=d;
     end else begin
      inc(d,2);
//      if d mod 3=0 then inc(d,3);
     end;
    until (m>$1000000000) or (d>10000);
    if d>10000 then continue;
    break;
   until false;
   writeln(d,divcnt,dividers[1]);
  end;

var
 i:integer;
begin
 for i:=0 to 255 do
  NoiseMask[i]:=byte(MyRand(256));
end.
