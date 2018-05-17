unit RSA;
interface
 uses LongMath;

 var
  RSArandom:array[0..63] of byte;


 procedure GenerateKeyPair(var base,pub,pvt:TBigInt);
 procedure GenerateKeyPair2(var base,pub,pvt:TBigInt2);

 function IsPrime(v:TBigInt;iterations:integer=100):boolean;
 procedure GetPrime(var v:TBigInt);
 function IsPrime2(v:TBigInt2;iterations:integer=100):boolean;
 procedure GetPrime2(var v:TBigInt2);
 procedure FillRand(var buf;size:integer);

implementation

 var
  randpos:integer;
  SmallPrimes:array[1..2000] of integer;

 procedure FillRand(var buf;size:integer);
  var
   pb:^Byte;
   i:integer;
  begin
   pb:=@buf;
   for i:=1 to size do begin
    pb^:=random(256) xor RSArandom[randpos and 63];
    inc(pb);
    inc(randpos,random(5));
   end;
  end;

 function ForceTestPrime(v:int64):boolean;
  var
   i:integer;
   max:integer;
   d:double;
  begin
   d:=v;
   max:=round(sqrt(d));
   for i:=2 to max do
    if v mod i=0 then begin
     result:=false; exit;
    end;
   result:=true;
  end;

 function IsPrime(v:TBigInt;iterations:integer=100):boolean;
  var
   i,j,l,s,found,cnt,max:integer;
   t:TBigInt;
   a,m,r,k,v1:TBigInt;
   fl:boolean;
  begin
   l:=bLastBit(v);
   if l<28 then max:=round(sqrt(v[0]))
    else max:=1000000;
   // простой тест
   result:=true;
   fillchar(m,sizeof(m),0);
   for i:=2 to length(SmallPrimes) do begin
    m[0]:=SmallPrimes[i];
    if m[0]>max then exit;
    bDiv(v,m,r,k);
    if IsZero(k) then begin
     result:=false;
     exit;
    end;
   end;
   // Продвинутый тест - Миллера-Рабина
   if l<=28 then exit; // для маленьких чисел достаточно простого теста
   l:=l div 8;
   for s:=1 to 255 do // 0-й бит не рассматриваем - он вычитается
    if v[s shr 5] and (1 shl (s and 31))>0 then break;
   t:=v;
   bShr(t,s);
   found:=0;
   v1:=v;
   bDec(v1);
   repeat
    // генерация случайного числа 1 < a < v
    FillChar(a,sizeof(a),0);
    repeat
     FillRand(a,l);
    until a[0]>1;
    // Проверка на свидетеля простоты
    bDiv(v,a,r,k);
    if isZero(k) then begin // однозначно не простое
     result:=false; exit;
    end;
    a:=bPowMod(a,t,v);
    if (a[0]=1) and (a[1]=0) and (a[2]=0) and (a[3]=0) then begin
     inc(found);  continue;
    end;
    fl:=false;
    for j:=0 to s-1 do begin
     if j>0 then begin
      bSqr(a);
      bDiv(a,v,r,k);
      a:=k;
     end;
     if bCmp(a,v1)=0 then begin
      fl:=true; break;
     end;
    end;
    if not fl then begin
      result:=false; exit;
    end else inc(found);
   until found>=iterations;
  end;

 function IsPrime2(v:TBigInt2;iterations:integer=100):boolean;
  var
   i,j,l,s,found,cnt,max:integer;
   t:TBigInt2;
   a,m,r,k,v1:TBigInt2;
   fl:boolean;
  begin
   l:=bLastBit2(v);
   if l<28 then max:=round(sqrt(v[0]))
    else max:=1000000;
   // простой тест
   result:=true;
   fillchar(m,sizeof(m),0);
   for i:=2 to length(SmallPrimes) do begin
    m[0]:=SmallPrimes[i];
    if m[0]>max then exit;
    bDiv2(v,m,r,k);
    if IsZero2(k) then begin
     result:=false;
     exit;
    end;
   end;
   // Продвинутый тест - Миллера-Рабина
   if l<=28 then exit; // для маленьких чисел достаточно простого теста
   l:=l div 8;
   for s:=1 to 255 do // 0-й бит не рассматриваем - он вычитается
    if v[s shr 5] and (1 shl (s and 31))>0 then break;
   t:=v;
   bShr2(t,s);
   found:=0;
   v1:=v;
   bDec2(v1);
   repeat
    // генерация случайного числа 1 < a < v
    FillChar(a,sizeof(a),0);
    repeat
     FillRand(a,l);
    until a[0]>1;
    // Проверка на свидетеля простоты
    bDiv2(v,a,r,k);
    if isZero2(k) then begin // однозначно не простое
     result:=false; exit;
    end;
    a:=bPowMod2(a,t,v);
    if (a[0]=1) and (a[1]=0) and (a[2]=0) and (a[3]=0) then begin
     inc(found);  continue;
    end;
    fl:=false;
    for j:=0 to s-1 do begin
     if j>0 then begin
      bSqr2(a);
      bDiv2(a,v,r,k);
      a:=k;
     end;
     if bCmp2(a,v1)=0 then begin
      fl:=true; break;
     end;
    end;
    if not fl then begin
      result:=false; exit;
    end else inc(found);
   until found>=iterations;
  end;

 procedure GetPrime(var v:TBigInt);
  var
   c:cardinal;
  begin
   if v[0] and 1=0 then bDec(v);
   while not isPrime(v,100) do begin
    bDec(v,2);
   end;
{   if not ForceTestPrime(int64(v[1]) shl 32+v[0]) then
     writeln('Failed!');}
  end;

 procedure GetPrime2(var v:TBigInt2);
  var
   c:cardinal;
  begin
   if v[0] and 1=0 then bDec2(v);
   while not isPrime2(v,100) do begin
    bDec2(v,2);
   end;
  end;

 procedure GenerateKeyPair(var base,pub,pvt:TBigInt);
  var
   i,j:integer;
   p,q,a,b:TBigInt;
   p1q1:TBigInt;
   qa:array[2..80] of TBigInt;
  begin
   fillchar(p,sizeof(p),0);
   fillchar(q,sizeof(q),0);
   FillRand(p,8);
   p[1]:=p[1] or $80000000;
   repeat
    FillRand(q,8);
    q[1]:=q[1] or $80000000;
   until (p[1] and $FC000000<>q[1] and $FC000000);
   GetPrime(p);
   GetPrime(q);
   base:=bMult(p,q);
   bDec(p);
   bDec(q);
   p1q1:=bMult(p,q);
   fillchar(pub,sizeof(pub),0);
   FillRand(pub,6);
   GetPrime(pub);
   // Расширенный алг. Евклида для поиска pvt
   i:=2;
   a:=p1q1;
   b:=pub;
   repeat
    bDiv(a,b,qa[i],p);
    a:=b; b:=p;
    inc(i);
   until (b[0]=1) and (b[1]=0) and (b[2]=0) and (b[3]=0);
   dec(i);
   // p=1
   fillchar(p,sizeof(p),0);
   bInc(p);
   q:=qa[i];
   bNeg(q);
   while i>2 do begin
    dec(i);
    a:=p;
    p:=q;
    q:=bMult(p,qa[i]);
    bSub(q,a);
    bNeg(q);
   end;
   bAdd(q,p1q1);
   pvt:=q;
  end;

 procedure GenerateKeyPair2(var base,pub,pvt:TBigInt2);
  var
   i,j:integer;
   p,q,a,b:TBigInt2;
   p1q1:TBigInt2;
   qa:array[2..180] of TBigInt2;
  begin
   fillchar(p,sizeof(p),0);
   fillchar(q,sizeof(q),0);
   FillRand(p,16);
   p[3]:=p[3] or $80000000;
   repeat
    FillRand(q,16);
    q[3]:=q[3] or $80000000;
   until (p[3] and $FC000000<>q[3] and $FC000000);
   GetPrime2(p);
   GetPrime2(q);
   base:=bMult2(p,q);
   bDec2(p);
   bDec2(q);
   p1q1:=bMult2(p,q);
   fillchar(pub,sizeof(pub),0);
   FillRand(pub,7);
   GetPrime2(pub);
   // Расширенный алг. Евклида для поиска pvt
   i:=2;
   a:=p1q1;
   b:=pub;
   repeat
    bDiv2(a,b,qa[i],p);
    a:=b; b:=p;
    inc(i);
   until (b[0]=1) and (b[1]=0) and (b[2]=0) and (b[3]=0) and
    (b[4]=0) and (b[5]=0) and (b[6]=0) and (b[7]=0);
   dec(i);
   // p=1
   fillchar(p,sizeof(p),0);
   bInc2(p);
   q:=qa[i];
   bNeg2(q);
   while i>2 do begin
    dec(i);
    a:=p;
    p:=q;
    q:=bMult2(p,qa[i]);
    bSub2(q,a);
    bNeg2(q);
   end;
   bAdd2(q,p1q1);
   pvt:=q;
  end;

var
 i,j,c,v,d:integer;
 fl:boolean;
begin
 SmallPrimes[1]:=2;
 SmallPrimes[2]:=3;
 c:=2;
 v:=5;
 while c<2000 do begin
  fl:=true;
  j:=round(sqrt(v));
  for i:=2 to c do begin
   d:=SmallPrimes[i];
   if d>j then break;
   if v mod d=0 then begin
    fl:=false; break;
   end;
  end;
  if fl then begin
   inc(c); SmallPrimes[c]:=v;
  end;
  inc(v,2);
 end;
end.
