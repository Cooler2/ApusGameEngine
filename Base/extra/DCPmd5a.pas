{******************************************************************************}
{* DCPcrypt v2.0 written by David Barton (crypto@cityinthesky.co.uk) **********}
{******************************************************************************}
{* A binary compatible implementation of MD5 **********************************}
{******************************************************************************}
{* Copyright (c) 1999-2002 David Barton                                       *}
{* Permission is hereby granted, free of charge, to any person obtaining a    *}
{* copy of this software and associated documentation files (the "Software"), *}
{* to deal in the Software without restriction, including without limitation  *}
{* the rights to use, copy, modify, merge, publish, distribute, sublicense,   *}
{* and/or sell copies of the Software, and to permit persons to whom the      *}
{* Software is furnished to do so, subject to the following conditions:       *}
{*                                                                            *}
{* The above copyright notice and this permission notice shall be included in *}
{* all copies or substantial portions of the Software.                        *}
{*                                                                            *}
{* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR *}
{* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,   *}
{* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL    *}
{* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER *}
{* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING    *}
{* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER        *}
{* DEALINGS IN THE SOFTWARE.                                                  *}
{******************************************************************************}
// Modified by Ivan Polyacov (ivan@apus-software.com, cooler@tut.by), 2014
// - class declaration removed, simple procedural interface introduced
unit DCPmd5a;

interface
uses
  Sysutils;
 type
  TMD5Hash=array[0..15] of byte;

 procedure MD5(var data;size:integer;out hash:TMD5Hash); overload;
 function MD5(var data;size:integer):AnsiString; overload;
 function MD5(st:RawByteString):AnsiString; overload;

{******************************************************************************}
{******************************************************************************}
implementation
{$R-}{$Q-}

type
 DWord = cardinal;
 PDWord = ^DWord;

procedure MD5(var data;size:integer;out hash:TMD5Hash);
 var
   LenHi, LenLo: longword;
   Index: DWord;
   CurrentHash: array[0..3] of DWord;
   HashBuffer: array[0..63] of byte;
   fInitialized:boolean;
   a:array[0..15] of byte;

 function LRot32(a, b: longword): longword;
 begin
  Result:= (a shl b) or (a shr (32-b));
 end;

 procedure Compress;
 var
  Data: array[0..15] of dword;
  A, B, C, D: dword;
 begin
  Move(HashBuffer,Data,Sizeof(Data));
  A:= CurrentHash[0];
  B:= CurrentHash[1];
  C:= CurrentHash[2];
  D:= CurrentHash[3];

  A:= B + LRot32(A + (D xor (B and (C xor D))) + Data[ 0] + $d76aa478,7);
  D:= A + LRot32(D + (C xor (A and (B xor C))) + Data[ 1] + $e8c7b756,12);
  C:= D + LRot32(C + (B xor (D and (A xor B))) + Data[ 2] + $242070db,17);
  B:= C + LRot32(B + (A xor (C and (D xor A))) + Data[ 3] + $c1bdceee,22);
  A:= B + LRot32(A + (D xor (B and (C xor D))) + Data[ 4] + $f57c0faf,7);
  D:= A + LRot32(D + (C xor (A and (B xor C))) + Data[ 5] + $4787c62a,12);
  C:= D + LRot32(C + (B xor (D and (A xor B))) + Data[ 6] + $a8304613,17);
  B:= C + LRot32(B + (A xor (C and (D xor A))) + Data[ 7] + $fd469501,22);
  A:= B + LRot32(A + (D xor (B and (C xor D))) + Data[ 8] + $698098d8,7);
  D:= A + LRot32(D + (C xor (A and (B xor C))) + Data[ 9] + $8b44f7af,12);
  C:= D + LRot32(C + (B xor (D and (A xor B))) + Data[10] + $ffff5bb1,17);
  B:= C + LRot32(B + (A xor (C and (D xor A))) + Data[11] + $895cd7be,22);
  A:= B + LRot32(A + (D xor (B and (C xor D))) + Data[12] + $6b901122,7);
  D:= A + LRot32(D + (C xor (A and (B xor C))) + Data[13] + $fd987193,12);
  C:= D + LRot32(C + (B xor (D and (A xor B))) + Data[14] + $a679438e,17);
  B:= C + LRot32(B + (A xor (C and (D xor A))) + Data[15] + $49b40821,22);

  A:= B + LRot32(A + (C xor (D and (B xor C))) + Data[ 1] + $f61e2562,5);
  D:= A + LRot32(D + (B xor (C and (A xor B))) + Data[ 6] + $c040b340,9);
  C:= D + LRot32(C + (A xor (B and (D xor A))) + Data[11] + $265e5a51,14);
  B:= C + LRot32(B + (D xor (A and (C xor D))) + Data[ 0] + $e9b6c7aa,20);
  A:= B + LRot32(A + (C xor (D and (B xor C))) + Data[ 5] + $d62f105d,5);
  D:= A + LRot32(D + (B xor (C and (A xor B))) + Data[10] + $02441453,9);
  C:= D + LRot32(C + (A xor (B and (D xor A))) + Data[15] + $d8a1e681,14);
  B:= C + LRot32(B + (D xor (A and (C xor D))) + Data[ 4] + $e7d3fbc8,20);
  A:= B + LRot32(A + (C xor (D and (B xor C))) + Data[ 9] + $21e1cde6,5);
  D:= A + LRot32(D + (B xor (C and (A xor B))) + Data[14] + $c33707d6,9);
  C:= D + LRot32(C + (A xor (B and (D xor A))) + Data[ 3] + $f4d50d87,14);
  B:= C + LRot32(B + (D xor (A and (C xor D))) + Data[ 8] + $455a14ed,20);
  A:= B + LRot32(A + (C xor (D and (B xor C))) + Data[13] + $a9e3e905,5);
  D:= A + LRot32(D + (B xor (C and (A xor B))) + Data[ 2] + $fcefa3f8,9);
  C:= D + LRot32(C + (A xor (B and (D xor A))) + Data[ 7] + $676f02d9,14);
  B:= C + LRot32(B + (D xor (A and (C xor D))) + Data[12] + $8d2a4c8a,20);

  A:= B + LRot32(A + (B xor C xor D) + Data[ 5] + $fffa3942,4);
  D:= A + LRot32(D + (A xor B xor C) + Data[ 8] + $8771f681,11);
  C:= D + LRot32(C + (D xor A xor B) + Data[11] + $6d9d6122,16);
  B:= C + LRot32(B + (C xor D xor A) + Data[14] + $fde5380c,23);
  A:= B + LRot32(A + (B xor C xor D) + Data[ 1] + $a4beea44,4);
  D:= A + LRot32(D + (A xor B xor C) + Data[ 4] + $4bdecfa9,11);
  C:= D + LRot32(C + (D xor A xor B) + Data[ 7] + $f6bb4b60,16);
  B:= C + LRot32(B + (C xor D xor A) + Data[10] + $bebfbc70,23);
  A:= B + LRot32(A + (B xor C xor D) + Data[13] + $289b7ec6,4);
  D:= A + LRot32(D + (A xor B xor C) + Data[ 0] + $eaa127fa,11);
  C:= D + LRot32(C + (D xor A xor B) + Data[ 3] + $d4ef3085,16);
  B:= C + LRot32(B + (C xor D xor A) + Data[ 6] + $04881d05,23);
  A:= B + LRot32(A + (B xor C xor D) + Data[ 9] + $d9d4d039,4);
  D:= A + LRot32(D + (A xor B xor C) + Data[12] + $e6db99e5,11);
  C:= D + LRot32(C + (D xor A xor B) + Data[15] + $1fa27cf8,16);
  B:= C + LRot32(B + (C xor D xor A) + Data[ 2] + $c4ac5665,23);

  A:= B + LRot32(A + (C xor (B or (not D))) + Data[ 0] + $f4292244,6);
  D:= A + LRot32(D + (B xor (A or (not C))) + Data[ 7] + $432aff97,10);
  C:= D + LRot32(C + (A xor (D or (not B))) + Data[14] + $ab9423a7,15);
  B:= C + LRot32(B + (D xor (C or (not A))) + Data[ 5] + $fc93a039,21);
  A:= B + LRot32(A + (C xor (B or (not D))) + Data[12] + $655b59c3,6);
  D:= A + LRot32(D + (B xor (A or (not C))) + Data[ 3] + $8f0ccc92,10);
  C:= D + LRot32(C + (A xor (D or (not B))) + Data[10] + $ffeff47d,15);
  B:= C + LRot32(B + (D xor (C or (not A))) + Data[ 1] + $85845dd1,21);
  A:= B + LRot32(A + (C xor (B or (not D))) + Data[ 8] + $6fa87e4f,6);
  D:= A + LRot32(D + (B xor (A or (not C))) + Data[15] + $fe2ce6e0,10);
  C:= D + LRot32(C + (A xor (D or (not B))) + Data[ 6] + $a3014314,15);
  B:= C + LRot32(B + (D xor (C or (not A))) + Data[13] + $4e0811a1,21);
  A:= B + LRot32(A + (C xor (B or (not D))) + Data[ 4] + $f7537e82,6);
  D:= A + LRot32(D + (B xor (A or (not C))) + Data[11] + $bd3af235,10);
  C:= D + LRot32(C + (A xor (D or (not B))) + Data[ 2] + $2ad7d2bb,15);
  B:= C + LRot32(B + (D xor (C or (not A))) + Data[ 9] + $eb86d391,21);

  Inc(CurrentHash[0],A);
  Inc(CurrentHash[1],B);
  Inc(CurrentHash[2],C);
  Inc(CurrentHash[3],D);
  Index:= 0;
  FillChar(HashBuffer,Sizeof(HashBuffer),0);
 end;

 procedure Burn;
 begin
  LenHi:= 0; LenLo:= 0;
  Index:= 0;
  FillChar(HashBuffer,Sizeof(HashBuffer),0);
  FillChar(CurrentHash,Sizeof(CurrentHash),0);
  fInitialized:= false;
 end;

 procedure Init;
 begin
  Burn;
  CurrentHash[0]:= $67452301;
  CurrentHash[1]:= $efcdab89;
  CurrentHash[2]:= $98badcfe;
  CurrentHash[3]:= $10325476;
  fInitialized:= true;
 end;

 procedure Update(const Buffer; Size: longword);
 var
   PBuf: ^byte;
 begin
  Inc(LenHi,Size shr 29);
  Inc(LenLo,Size*8);
  if LenLo< (Size*8) then
    Inc(LenHi);

  PBuf:= @Buffer;
  while Size> 0 do
  begin
    if (Sizeof(HashBuffer)-Index)<= DWord(Size) then
    begin
      Move(PBuf^,HashBuffer[Index],Sizeof(HashBuffer)-Index);
      Dec(Size,Sizeof(HashBuffer)-Index);
      Inc(PBuf,Sizeof(HashBuffer)-Index);
      Compress;
    end
    else
    begin
      Move(PBuf^,HashBuffer[Index],Size);
      Inc(Index,Size);
      Size:= 0;
    end;
  end;
 end;

 procedure Finall(var Digest);
 begin
  HashBuffer[Index]:= $80;
  if Index>= 56 then
    Compress;
  PDWord(@HashBuffer[56])^:= LenLo;
  PDWord(@HashBuffer[60])^:= LenHi;
  Compress;
  Move(CurrentHash,Digest,Sizeof(CurrentHash));
  Burn;
 end;

begin
 Init;
 Update(data,size);
 Finall(a);
 move(a,hash,sizeof(hash));
 Burn;
end;

function MD5(var data;size:integer):AnsiString; overload;
const
 HexDigits:array[0..15] of AnsiChar=('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
var
 i:integer;
 hash:TMD5Hash;
 b:byte;
begin
 MD5(data,size,hash);
 SetLength(result,32);
 for i:=0 to 15 do begin
  b:=hash[i];
  result[i*2+1]:=HexDigits[b shr 4];
  result[i*2+2]:=HexDigits[b and $F];
 end;
end;

function MD5(st:RawByteString):AnsiString; overload;
begin
 result:=MD5(st[1],length(st));
end;

end.
