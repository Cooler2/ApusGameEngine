{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestMath;
uses
  Apus.Common,
  SysUtils,
  Math,
  Apus.Geom2D,
  Apus.Geom3D;

 var
  time:int64;
  i:integer;

 procedure StartTimer;
  begin
   time:=MyTickCount;
  end;

 procedure EndTimer(msg:string);
  begin
   writeln(msg,': ',MyTickCount-time);
   time:=MyTickCount;
  end;

 procedure TestMatrices;
  var
   m4,mInv,m4a:TMatrix4s;
   m3:TMatrix3s;
   v:single;
  begin
   MatrixFromYawRollPitch(m3,1,-1,0.5);
   v:=Det(m3);
   ASSERT(IsEqual(v,1));

   TVector4s(m4[0]):=QuaternionS(0,1,2,3);
   TVector4s(m4[1]):=QuaternionS(2,0,3,1);
   TVector4s(m4[2]):=QuaternionS(1,3,2,1);
   TVector4s(m4[3]):=QuaternionS(2,1,3,0);

   InvertFull(m4,mInv);
   MultMat(m4,mInv,m4a);
   ASSERT(IsEqual(m4a,IdentMatrix4s));

   StartTimer;
   for i:=1 to 2000000 do
    InvertFull(m4,mInv);
   EndTimer('Invert4Full time');

   for i:=1 to 5000000 do
    MultMat(m4,mInv,m4a);
   EndTimer('Mult4s time');

   writeln('Matrices OK');
  end;

 procedure TestRotationMat;
  var
   i:integer;
   m1,m2,m3:TMatrix3s;
   angle:single;
   vec:TVector3s;
  begin
   time:=MyTickCount;
{   for i:=1 to 1000000 do
    m2:=RotationAroundVector(Vector3s(0,0,1),angle);
   writeln(MyTickCount-time);}

   for i:=-20 to 30 do begin
    angle:=i/3;
    // Z
    MatrixFromYawRollPitch(m1,angle,0,0);
    m2:=RotationAroundVector(Vector3s(0,0,1),angle);
    m3:=RotationZMat3s(angle);
    ASSERT(IsEqual(m1,m2));
    ASSERT(IsEqual(m1,m3));
    // Y
    MatrixFromYawRollPitch(m1,0,angle,0);
    m2:=RotationAroundVector(Vector3s(0,1,0),angle);
    m3:=RotationYMat3s(angle);
    ASSERT(IsEqual(m1,m2));
    ASSERT(IsEqual(m1,m3));
    // X
    MatrixFromYawRollPitch(m1,0,0,angle);
    m2:=RotationAroundVector(Vector3s(1,0,0),angle);
    m3:=RotationXMat3s(angle);
    ASSERT(IsEqual(m1,m2));
    ASSERT(IsEqual(m1,m3));
   end;

   m1:=RotationAroundVector(Vector3s(1,1,1),1);
   m2:=RotationAroundVector(Vector3s(1,1,1),-1);
   MultMat(m1,m2,m3);
   ASSERT(IsEqual(m3,IdentMatrix3s));

   for i:=1 to 100 do begin
    vec:=Vector3s(random-random,random-random,random-random);
    m1:=RotationAroundVector(vec,2*Pi);
    ASSERT(IsEqual(m1,IdentMatrix3s));
    m1:=RotationAroundVector(vec,-2*Pi);
    ASSERT(IsEqual(m1,IdentMatrix3s));
   end;

   writeln('RotationMat OK');
  end;

 procedure TestQuaternions;
  begin
  end;

 procedure TestQuaternionConversions;
  var
   q,q1,q2,q3:TQuaternionS;
   mat:TMatrix4s;
   m3,mm3,m:TMatrix3s;
   i:integer;
   vec:TVector3s;
   a:single;
  begin
   m3:=RotationZMat3s(0.1);
   q:=MatrixToQuaternion(m3);
   ASSERT(IsEqual(q.Length,1));

   // Single test
   vec:=Vector3s(0.26242, -0.36225, 0.62695);
   a:=2.8916;
   m3:=RotationAroundVector(vec,a);
   q:=MatrixToQuaternion(m3);
   ASSERT(IsEqual(q.Length,1));
   QuaternionToMatrix(q,mm3);
   ASSERT(IsEqual(m3,mm3,150),Format('Fail: vec=(%.6f,%.6f,%.6f) angle=%.6f',[vec.x,vec.y,vec.z,a]));

   // Repeat
   for i:=1 to 1000 do begin
    vec:=Vector3s(random-random,random-random,random-random);
    a:=5*(random-random);
    m3:=RotationAroundVector(vec,a);
    q:=MatrixToQuaternion(m3);
    ASSERT(IsEqual(q.Length,1));
    QuaternionToMatrix(q,mm3);
    if not IsEqual(m3,mm3,150) then
     IsEqual(m3,mm3,150);
    ASSERT(IsEqual(m3,mm3,150),Format('Fail: vec=(%.7f,%.7f,%.7f) angle=%.7f',[vec.x,vec.y,vec.z,a]));
   end;

   mat:=ScaleMat4s(1.5, 1.7, 1.9);
   mat:=MultMat(mat,RotationZMat4s(0.1));
   mat:=MultMat(mat,TranslationMat4s(2,2.5,3));
   DecomposeMartix(mat,q1,q2,q3);
   ASSERT(IsEqual(q1.xyz,Vector3s(2,2.5,3)));
   ASSERT(IsEqual(q3.xyz,Vector3s(1.5, 1.7, 1.9)));
   ASSERT(IsEqual(q2,QuaternionS(0,0,0.04998,0.99875)));
   ASSERT(IsEqual(q2.Length,1));

   // Perf
   time:=MyTickCount;
   for i:=0 to 10000000 do
    MatrixFromQuaternion(q2,mat);
   writeln('Conv time: ',MyTickCount-time);

   writeln('Quaternion conversions OK');
  end;

// Some long math code (reference implementation + experimental implementation)

type
  uint256=array[0..3] of uint64;
  uint512=array[0..7] of uint64;

 function Cmp256(const a,b:uint256):integer;
  var
   i:integer;
  begin
   result:=0;
   for i:=3 downto 0 do begin
    if a[i]=b[i] then continue;
    if a[i]<b[i] then exit(-1)
      else exit(1);
   end;
  end;

 function Cmp512(const a,b:uint512):integer;
  var
   i:integer;
  begin
   result:=0;
   for i:=7 downto 0 do begin
    if a[i]=b[i] then continue;
    if a[i]<b[i] then exit(-1)
      else exit(1);
   end;
  end;

 procedure Add256(var a:uint256;const b:uint256);
  asm
    mov rax,[b]
    add [a],rax
    mov rax,[b+8]
    adc [a+8],rax
    mov rax,[b+16]
    adc [a+16],rax
    mov rax,[b+24]
    adc [a+24],rax
  end;

 procedure Add512(var a:uint512;const b:uint512);
  asm
    mov rax,[b]
    add [a],rax
    mov rax,[b+8]
    adc [a+8],rax
    mov rax,[b+16]
    adc [a+16],rax
    mov rax,[b+24]
    adc [a+24],rax
    mov rax,[b+32]
    adc [a+32],rax
    mov rax,[b+40]
    adc [a+40],rax
    mov rax,[b+48]
    adc [a+48],rax
    mov rax,[b+56]
    adc [a+56],rax
  end;

 procedure Sub256(var a:uint256;const b:uint256);
  asm
    mov rax,[b]
    sub [a],rax
    mov rax,[b+8]
    sbb [a+8],rax
    mov rax,[b+16]
    sbb [a+16],rax
    mov rax,[b+24]
    sbb [a+24],rax
  end;

 procedure Sub512(var a:uint512;const b:uint512);
  asm
    mov rax,[b]
    sub [a],rax
    mov rax,[b+8]
    sbb [a+8],rax
    mov rax,[b+16]
    sbb [a+16],rax
    mov rax,[b+24]
    sbb [a+24],rax
    mov rax,[b+32]
    sbb [a+32],rax
    mov rax,[b+40]
    sbb [a+40],rax
    mov rax,[b+48]
    sbb [a+48],rax
    mov rax,[b+56]
    sbb [a+56],rax
  end;


 function GetB(const a:uint256;bit:integer):boolean; overload;
  begin
   result:=GetBit(a[bit div 64],bit mod 64);
  end;

 procedure SetB(var a:uint256;bit:integer;value:boolean); overload;
  begin
   SetBit(a[bit div 64],bit mod 64,value);
  end;

 function GetB(const a:uint512;bit:integer):boolean; overload;
  begin
   result:=GetBit(a[bit div 64],bit mod 64);
  end;

 procedure SetB(var a:uint512;bit:integer;value:boolean); overload;
  begin
   SetBit(a[bit div 64],bit mod 64,value);
  end;


 procedure ShiftL(var a:uint256;n:integer); overload;
  var
   i:integer;
   b:boolean;
  begin
   for i:=255 downto 0 do begin
    if i-n>=0 then b:=GetB(a,i-n)
     else b:=false;
    SetB(a,i,b);
   end;
  end;

 procedure ShiftR(var a:uint256;n:integer); overload;
  var
   i:integer;
   b:boolean;
  begin
   for i:=0 to 255 do begin
    if i+n<256 then b:=GetB(a,i+n)
     else b:=false;
    SetB(a,i,b);
   end;
  end;

 procedure ShiftL(var a:uint512;n:integer); overload;
  var
   i:integer;
   b:boolean;
  begin
   for i:=511 downto 0 do begin
    if i-n>=0 then b:=GetB(a,i-n)
     else b:=false;
    SetB(a,i,b);
   end;
  end;

 procedure ShiftR(var a:uint512;n:integer); overload;
  var
   i:integer;
   b:boolean;
  begin
   for i:=0 to 511 do begin
    if i+n<512 then b:=GetB(a,i+n)
     else b:=false;
    SetB(a,i,b);
   end;
  end;

 function Mult256(a,b:uint256):uint256;
  var
   i:integer;
  begin
   ZeroMem(result,sizeof(result));
   for i:=0 to 255 do begin
    if GetB(b,i) then
     Add256(result,a);
    ShiftL(a,1);
   end;
  end;

 function Mult256_512(a,b:uint256):uint512;
  var
   i:integer;
   tmp:uint512;
  begin
   ZeroMem(result,sizeof(result));
   ZeroMem(tmp,sizeof(tmp));
   move(a,tmp,sizeof(a));
   for i:=0 to 255 do begin
    if GetB(b,i) then
     Add512(result,tmp);
    ShiftL(tmp,1);
   end;
  end;

 function GetHighestBit(const a:uint256):integer;
  var
   i:integer;
   v:uint64;
  begin
   result:=255;
   for i:=3 downto 0 do begin
    if a[i]=0 then
     dec(result,64)
    else begin
     v:=a[i];
     while v and $8000000000000000=0 do begin
       dec(result);
       v:=v shl 1;
     end;
     exit;
    end;
   end;
  end;

 procedure Div256Ref(a,b:uint256;out d,rem:uint256);
  var
   i:integer;
   bitA,bitB,shift:integer;
  begin
   zeromem(d,sizeof(d));
   bitA:=GetHighestBit(a);
   bitB:=GetHighestBit(b);
   shift:=bitA-bitB;
   if shift<0 then begin
    rem:=a;
    exit;
   end;
   ShiftL(b,shift);
   while shift>=0 do begin
    if Cmp256(a,b)>=0 then begin
     Sub256(a,b);
     SetB(d,shift,true);
    end;
    dec(shift);
    dec(bitA);
    ShiftR(b,1);
   end;
   rem:=a;
  end;

 procedure Div512Ref(a,b:uint512;out d,rem:uint512);
  var
   i:integer;
  begin
   zeromem(d,sizeof(d));
   i:=0;
   while not GetB(b,511) do begin
    ShiftL(b,1); inc(i);
   end;
   while i>=0 do begin
    if Cmp512(a,b)>=0 then begin
      Sub512(a,b);
      SetB(d,i,true);
    end;
    ShiftR(b,1);
    dec(i);
   end;
   rem:=a;
  end;


 // d:=a/b
 procedure Div256(a,b:uint256;out d,rem:uint256);
  var
   i:integer;
   tmp:uint256;
   v:uint64;
  begin
   {
     - Сдвинуть делитель на максимум - N слов
     - Текущая позиция - i=3, позция вычисляемой цифры - N
     - (1) Вычисляем цифру: делим A[i+1].A[i] на B[i]+1 (потому что B[1]+1... заведомо больше, чем B, а значит переполнения не будет)
       - результат деления (K) прибавляем к текущей цифре
       - умножаем S = B*K и вычитаем это из A: A := A - B*K
       - если A всё еще >= B - продолжаем и повторяем (1)
       - Если N=0 - завершаем цикл иначе переходим к следующей цифре
       - N:=N-1, i:=i-1, сдвигаем B на 1 слово вправо
     - завершение
   }
   for i:=3 downto 0 do begin
    tmp:=b;
    ShiftL(tmp,i);
    if Cmp256(a,tmp)>=0 then begin
     d[i]:=a[i] div tmp[i];

    end;
   end;
  end;

 // деление цифрами по 16 бит
{ procedure bDiv(a,m:TBigInt;var r,k:TBigInt); // r=a/m, k=a mod m
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
   fillchar(r,sizeof(r),0); // результат
   l:=15;
   while (l>=0) and (a2[l]=0) do dec(l); // сколько непустых слов в делимом
   t:=15;
   while (t>=0) and (m2[t]=0) do dec(t); // сколько значимых слов в делителе
   s:=l-t; // на сколько слов можно сдвинуть делитель чтобы выровнять с делимым
   n:=m;
   if s>0 then // Сдвиг на s слов влево
    for i:=15 downto 0 do
     if i>=s then n2[i]:=n2[i-s] else n2[i]:=0;

   if l<15 then v:=a2[l+1] else v:=0;
   u:=m2[t]; // старшее слово делителя
   if t>0 then u:=u shl 16+m2[t-1]; // если есть возможность добавить слово - сдвинуть и добавить

   for i:=s downto 0 do begin // заполняем цифры
    v:=v shl 16+a2[l];
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
  end;    }

 function LongFrom256(const a:uint256):uint512;
  var
   i:integer;
  begin
   for i:=0 to 7 do
    if i<4 then result[i]:=a[i]
     else result[i]:=0;
  end;

 function ToStr256(const a:uint256):string;
  var
   i:integer;
  begin
   result:='';
   for i:=3 downto 0 do
     result:=result+IntToHex(a[i])+' ';
  end;

 function ToStr512(const a:uint512):string;
  var
   i:integer;
  begin
   result:='';
   for i:=5 downto 0 do
     result:=result+IntToHex(a[i])+' ';
  end;


 function FromStr(s:string):uint256;
  var
   i:integer;
   d,v,ten,dig:uint256;
  begin
   ZeroMem(result,sizeof(result));
   ZeroMem(d,sizeof(d));
   d[0]:=1;
   ZeroMem(ten,sizeof(d));
   ten[0]:=10;
   for i:=length(s) downto 1 do begin
    ZeroMem(dig,sizeof(dig));
    dig[0]:=StrToInt(s[i]);
    v:=Mult256(d,dig);
    Add256(result,v);
    d:=Mult256(d,ten);
   end;
  end;

 function Inverse(a,n:uint256):uint256;
  var
   r,rNext:uint256;
   t,tNext:uint256;
   q,rem,tmp:uint256;
   m,nl,ql,rl:uint512;
   i:integer;
  begin
   r:=n;
   rNext:=a;
   ZeroMem(t,sizeof(t));
   ZeroMem(tNext,sizeof(tNext));
   tNext[0]:=1;
   i:=1;
   repeat
     //writeln('r',i,'=',ToStr256(r));
     writeln('t',i,'=',ToStr256(t));
     //writeln;
     inc(i);
     Div256Ref(r,rNext,q,rem);
     r:=rNext;
     rNext:=rem;
     tmp:=tNext;
     tNext:=Mult256(tNext,q);
     Sub256(t,tNext);
     tNext:=t;
     t:=tmp;

   until IsZeroMem(rNext,sizeof(rNext));
   if GetB(t,255) then
     Add256(t,n);
   writeln('r',i,'=',ToStr256(r));
   writeln('t',i,'=',ToStr256(t));
   writeln;
   result:=t;

   // Verify
   m:=Mult256_512(a,t);
   writeln('m=',ToStr512(m));
   nl:=LongFrom256(n);
   Div512Ref(m,nl,ql,rl);
   writeln('r=',IntToHex(rl[0]));
  end;

function Inverse2(x, n: Int64): Int64;
var
  a, b, t: Int64;
begin
  a := x;
  b := n;
  t := 0;
  while b > 0 do
  begin
    t := t - (a div b) * t;
    a := a mod b;
    t := t xor b;
    b := b mod a;
    t := t xor a;
  end;
  if t < 0 then
    t := t + n;
  Result := t;
end;


 procedure Tmp;
  const
   c1:uint256=($ffffffffffff1234, $3333333333333333, $2222222222222222, $9999999955555555);
   c2:uint256=($ffffffffffffffff,1,0,0);
   //c1l:uint512 = ($7970538E90EA3C3C, $6DFA874F0AEA6517, $6CA5BBC031FD0DCD, $14489278BD86C546, $1289A0D4918FB461, $C2, 0,0);
   //c2l:uint512 = ($16C786BF7D2A160F, $1E83EC2CD19CD5FC, $1325B6CEA8, 0,0,0,0,0);

   c1l:uint512 = ($a9978a8bd8acaa40, $46ce14e608245ab3, $0a38e08ba8175a94, $3a9458e4ce328956,
      $babc9729ab9b055c, $4204ac15a8c24e05, $4b75ec8c64650978, $39e58a8055b6fb26);
   c2l:uint512 = ($bfd25e8cd0364141, $baaedce6af48a03b, $fffffffffffffffe, $ffffffffffffffff,0,0,0,0);
  var
   a,b,c,n:uint256;
   d,rem:uint256;
   al,bl:uint512;
   dl,remL:uint512;
   i:integer;
   t:int64;
   r:double;
  begin
    t:=Inverse2(100,101);
{   ZeroMem(a,sizeof(a));
   a[0]:=1;
   for i:=1 to 20 do begin
     a:=Mult256(a,c2);
   end;}
   n:=FromStr('426547670886165437617759515601');
   a:=FromStr('104130493325328738596120700629');
   n:=FromStr('27983840505772671487968461833206861626271855154703');
   a:=FromStr('24634943240713076522001245835841682166714817919351');
   //c:=Inverse(a,n);

//   ffffffffffffffff fffffffffffffffe baaedce6af48a03b bfd25e8cd0364141

{   39e58a8055b6fb26 4b75ec8c64650978 4204ac15a8c24e05 babc9729ab9b055c
   3a9458e4ce328956 0a38e08ba8175a94 46ce14e608245ab3 a9978a8bd8acaa40}

   StartMeasure(t);
   for i:=1 to 1000 do begin
    al:=c1l; bl:=c2l;
    Div512Ref(al,bl,dl,remL);
   end;
   r:=EndMeasure(t);

   a:=c1; b:=c2;
   Div256Ref(a,b,d,rem);
   Writeln(ToStr256(d));
   Writeln(ToStr256(rem));
   c:=Mult256(b,d);
   b[1]:=0;
   c:=Mult256(d,b);
   Add256(c,rem);
  end;


begin
 try
  TestMatrices;
  TestRotationMat;
  TestQuaternions;
  TestQuaternionConversions;
  writeln('All OK');
 except
  on e:Exception do begin
   writeln('Error: ',ExceptionMsg(e));
   halt(255);
  end;
 end;
 if HasParam('wait') then readln;
end.
