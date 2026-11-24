// Copyright (C) Apus Software, https://github.com/Cooler2/ApusGameEngine
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (https://github.com/Cooler2/ApusGameEngine)
{$H-,Q-,R-}
{$I defines.inc}
unit Apus.Crypto;
interface
type
 TMatrix32=array[0..31] of cardinal;
 Word64=array[0..1] of cardinal;
 Word128=array[0..3] of cardinal;

 // Protected container
 // A buffer that stores data in weakly encrypted form
 TProtContainer=class
  constructor Create(startSize:integer); // create a buffer of the given size
  procedure SetSize(newSize:integer); // change the buffer size (data is preserved)
  procedure WriteTo(posit,count:integer;var sour); // write data to the buffer (starting at position posit)
  procedure ReadFrom(posit,count:integer;var dest); // read data from the buffer (starting at position posit)
  destructor Destroy; override; // free the buffer
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

type
 TSHA1Digest=array[0..19] of byte;

// SHA-1 hash (FIPS 180-4). SHA-1 is broken for collision resistance: use it only where
// a protocol requires it (e.g. the WebSocket handshake), not in new security designs
function SHA1(data:pointer;size:integer):TSHA1Digest; overload;
function SHA1(const data:RawByteString):TSHA1Digest; overload;

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

 // Division of a 128-bit number by a 32-bit one with remainder
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
    // attempt to generate keys
    divcnt:=0;
    fillchar(n,sizeof(n),0);
    for i:=0 to 3 do begin
     n[2]:=n[2] or (Random(256) shl (i*8));
     n[3]:=n[3] or (Random(256) shl (i*8));
    end;
    n[0]:=1; m:=1;
    // Now factorize
    d:=3;
    repeat
     Divide128(n,d,n1,r);
     if r=0 then begin // factor found
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

// --- SHA-1 ---
type
 TSHA1State=array[0..4] of cardinal;
 TSHA1Block=array[0..63] of byte;
 PSHA1Block=^TSHA1Block;

function Rol32(x:cardinal;n:integer):cardinal; inline;
 begin
  result:=(x shl n) or (x shr (32-n));
 end;

procedure SHA1Transform(var h:TSHA1State;block:PSHA1Block);
 var
  w:array[0..79] of cardinal;
  a,b,c,d,e,f,k,t:cardinal;
  i:integer;
 begin
  for i:=0 to 15 do
   w[i]:=(cardinal(block[i*4]) shl 24) or (cardinal(block[i*4+1]) shl 16) or
         (cardinal(block[i*4+2]) shl 8) or cardinal(block[i*4+3]);
  for i:=16 to 79 do
   w[i]:=Rol32(w[i-3] xor w[i-8] xor w[i-14] xor w[i-16],1);
  a:=h[0]; b:=h[1]; c:=h[2]; d:=h[3]; e:=h[4];
  for i:=0 to 79 do begin
   if i<20 then begin
    f:=(b and c) or ((not b) and d); k:=$5A827999;
   end else
   if i<40 then begin
    f:=b xor c xor d; k:=$6ED9EBA1;
   end else
   if i<60 then begin
    f:=(b and c) or (b and d) or (c and d); k:=$8F1BBCDC;
   end else begin
    f:=b xor c xor d; k:=$CA62C1D6;
   end;
   t:=Rol32(a,5)+f+e+k+w[i];
   e:=d; d:=c; c:=Rol32(b,30); b:=a; a:=t;
  end;
  inc(h[0],a); inc(h[1],b); inc(h[2],c); inc(h[3],d); inc(h[4],e);
 end;

function SHA1(data:pointer;size:integer):TSHA1Digest;
 var
  h:TSHA1State;
  p:PSHA1Block;
  tail:array[0..127] of byte;
  rest,tailSize,i:integer;
  bits:uint64;
 begin
  ASSERT(size>=0);
  h[0]:=$67452301; h[1]:=$EFCDAB89; h[2]:=$98BADCFE; h[3]:=$10325476; h[4]:=$C3D2E1F0;
  p:=data;
  rest:=size;
  while rest>=64 do begin
   SHA1Transform(h,p);
   p:=PSHA1Block(UIntPtr(p)+64);
   dec(rest,64);
  end;
  // padding: $80, zeros, 64-bit big-endian length in bits
  fillchar(tail,sizeof(tail),0);
  if rest>0 then move(p^,tail,rest);
  tail[rest]:=$80;
  if rest<56 then tailSize:=64 else tailSize:=128;
  bits:=uint64(size)*8;
  for i:=0 to 7 do
   tail[tailSize-1-i]:=byte(bits shr (i*8));
  SHA1Transform(h,PSHA1Block(@tail[0]));
  if tailSize=128 then SHA1Transform(h,PSHA1Block(@tail[64]));
  for i:=0 to 4 do begin
   result[i*4]:=byte(h[i] shr 24);
   result[i*4+1]:=byte(h[i] shr 16);
   result[i*4+2]:=byte(h[i] shr 8);
   result[i*4+3]:=byte(h[i]);
  end;
 end;

function SHA1(const data:RawByteString):TSHA1Digest;
 begin
  result:=SHA1(pointer(data),length(data));
 end;

var
 i:integer;
begin
 for i:=0 to 255 do
  NoiseMask[i]:=byte(MyRand(256));
end.
