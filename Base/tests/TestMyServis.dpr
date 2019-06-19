// This program is used to
// 1) build core modules
// 2) test core modules in
//    a) interactive mode
//    b) automatic mode
{$APPTYPE CONSOLE}
{$R+}
program TestMyServis;
uses
  windows,
  variants,
  DateUtils,
  SysUtils,
  Math,
  classes,
  DCPmd5a,
  MyServis in '..\MyServis.pas',
  structs in '..\structs.pas',
  clipboard in '..\clipboard.pas',
  myADPCM in '..\myADPCM.pas',
  CrossPlatform in '..\CrossPlatform.pas',
  network in '..\network.pas',
  translation in '..\translation.pas',
  publics in '..\publics.pas',
  eventman in '..\eventman.pas',
  Logging in '..\Logging.pas',
  TextUtils in '..\TextUtils.pas',
  ControlFiles2 in '..\ControlFiles2.pas',
  crypto in '..\crypto.pas',
  GeoIP in '..\GeoIP.pas',
  Geom2d in '..\Geom2d.pas',
  geom3d in '..\geom3d.pas',
  LongMath in '..\LongMath.pas',
  profiling in '..\profiling.pas',
  colors in '..\colors.pas',
  RSA in '..\RSA.pas',
  StackTrace in '..\StackTrace.pas',
  gfxFormats in '..\gfxFormats.pas',
  UnicodeFont in '..\UnicodeFont.pas',
  MemoryLeakUtils in '..\MemoryLeakUtils.pas',
  AnimatedValues in '..\AnimatedValues.pas',
  myHuffman in '..\myHuffman.pas',
  Images in '..\Images.pas',
  httpRequests in '..\httpRequests.pas',
  FastGFX in '..\FastGFX.pas',
  filters in '..\filters.pas',
  FreeTypeFont in '..\FreeTypeFont.pas';

var
 sa:StringArr;
 t,c:cardinal;
 i,j:integer;
 a:array of cardinal;
 pb:PByte;

 testsFailed:boolean;

procedure TestQuotes;
 const
  str:array[1..8] of string=('','A','"A','A"','""','"""','"A "" A"','A "A"A"A');
 var
  s:string;
  i:integer;
 begin
  writeln(Unescape('\n0\n0\n0\n0'));
  writeln('== TestQuotes ==');
  writeln(QuoteStr('',false));
  writeln(QuoteStr(' ',false));
  writeln(QuoteStr('Just a string',false));
  writeln(QuoteStr('Just a string with "quotes"',false));
  writeln(QuoteStr('"quotes"',false));
  writeln(QuoteStr('"',false));
  writeln(QuoteStr('hello',false));
  writeln(QuoteStr('hello',true));
  writeln;
  writeln(UnQuoteStr('hello'));
  writeln(UnQuoteStr(''));
  writeln(UnQuoteStr('"hello"'));
  writeln(UnQuoteStr('""""'));
  writeln(UnQuoteStr('"String "" with quote"'));
  writeln(UnQuoteStr('hello world'));
  for i:=1 to high(str) do begin
   s:=QuoteStr(str[i],false,'"');
   if UnquoteStr(s)<>str[i] then begin
    writeln('Test failed ',i);
    testsFailed:=true;
   end;
  end;
 end;

 procedure TestSplitCombine;
  const
   tests:array[1..12] of string=
     ('Hello World',
      '12||3 1|23',
      '"A|A"',
      '"BBB"',
      '""CCC""',
      'A"B |C"D',
      ' AA BB',
      'AA BB ',
      '" B',
      'A "BC',
      '"|" AB ""',
      'A" | C"');
  var
   sa,sa2:StringArr;
   st:string;
   i,j:integer;
   fl,total:boolean;
  begin
   writeln('== TestSplit ==');
   sa:=split(#0,'AAA'#0'BBB');
   sa:=split(#0,'AAA'#0#0'BBB'#0);
   sa:=split(#0,#0'AAA'#0);
   total:=true;
   for i:=high(tests) downto low(tests) do begin
    sa:=split(' ',tests[i]);
    write(join(sa,' '),'  ==>  ');
    st:=combine(sa,'|','"');
    write(st,'  ==>  ');
    sa2:=split('|',st,'"');
    write(join(sa2,' '));
    fl:=false;
    if length(sa)=length(sa2) then begin
     fl:=true;
     for j:=0 to length(sa)-1 do
      if sa[j]<>sa2[j] then fl:=false;
    end;
    if fl then writeln('  OK')
     else writeln('   FAILED!!!');
    total:=total and fl;
   end;
   if not total then begin
    writeln('TESTS FAILED!');
    testsFailed:=true;
   end;
  end;

 procedure TestCompression;
  var
   date,baseDate:TDateTime;
   st:string;
   i:integer;
   f:file;
   buf,buf2:array of smallint;
   dest:array of byte;
  begin
   writeln('== Test Compression ==');
   st:=LoadFileAsString(paramStr(1));
   if pos('.packed',paramstr(1))>0 then begin
    st:=SimpleDecompress(st);
    WriteFile(StringReplace(paramstr(1),'.packed','.unpacked',[]),@st[1],0,length(st));
   end else begin
    st:=SimpleCompress(st);
    WriteFile(paramStr(1)+'.packed',@st[1],0,length(st));
   end;
  { st:=SimpleCompress('hello my dear friend!');
   st:=SimpleDecompress(st);
   writeln(st);}
  end;

 procedure TestADPCM;
  var
   f:file;
   i:integer;
   buf,buf2:array of smallint;
   dest:array of byte;
  begin
   writeln('== TestADPCM ==');
   assign(f,'menu1.pcm');
   reset(f,2);
   setLength(buf,filesize(f));
   blockread(f,buf[0],filesize(f));
   close(f);
   setLength(dest,round(length(buf)*0.55));
   i:=Compress_ADPCM4(buf[0],dest[0],length(buf) div 2,2);
   assign(f,'menu1.adpcm');
   rewrite(f,1);
   blockwrite(f,dest[0],i);
   close(f);
   setLength(buf2,length(buf));
   Decompress_ADPCM4(dest[0],buf2[0],length(buf) div 2,2);
   assign(f,'menu1_.pcm');
   rewrite(f,2);
   blockwrite(f,buf2[0],length(buf));
   close(f);
  end;

 procedure TestTranslation;
  var
   st:WideString;
   i:integer;
   t:cardinal;
  begin
   writeln('== TestTranslations ==');
   LoadDictionary('translate.lng');
   st:=Translate('Goblin Warrior deals 3 damage to Snow Wolf.');
   writeln(st);
   t:=MyTickCount;
   for i:=1 to 100000 do begin
    st:=Translate('Attacks as soon as summoned.');
    st:=Translate('Deals (Fire Power +4) damage to all except player''s tower (buildings receive halved damage).');
    st:=Translate('Hello. Deals damage to enemy tower equal to player''s Fire Power. test');
    st:=Translate('Hello. Any damage dealt by player''s spells is increased by 1. Unlocks "Flaming Tower". test');
   end;
   t:=MyTickCount-t;
   writeln(t,trRuleFault:8,' ',st);
  end;

 procedure TestAnimations;
  var
   i:integer;
   a,b:TAnimatedValue;
   v:single;
  begin
   writeln('== TestAnimations ==');

   a.Init(50);
   b.Init(50);
   b.Animate(100,2000,Spline0);
   a.Animate(100,1000,spline0);
   a.Animate(40,1000,spline0,1500);
   for i:=1 to 30 do begin
{    if i=2 then a.Animate(100,1800,Spline0);
    if i=15 then a.Animate(30,1700,Spline0);
    if i=20 then a.Animate(90,450,Spline0);
    if i=7 then b.Animate(60,2000,Spline0);}
    sleep(100);
    v:=a.Value;                     
    writeln(i:3,' ',v:6:1,' ',b.Value:6:1);
   end;

   a.Assign(0);
   a.logName:='Test';
   a.Animate(3,200,spline0,0);
   a.Animate(1,200,spline0,400);
   for i:=1 to 25 do begin
    writeln(MyTickCount mod 1000,a.value:8:3);
    sleep(30);
   end;
  end;

 procedure TestHash;
  var
   hash:THash;
   i,j,v,k,n,m,errors:integer;
   key:string;
   t,t2,t3:cardinal;
   ref:array of integer;
   vr,vr2,vr3:variant;
  begin
   writeln('== TestHash ==');
   randomize;
   SetLength(ref,2000);
   for i:=0 to High(ref) do ref[i]:=-1;

   // TEST 1: тест малых объемов, ключ уникальный
   t:=MyTickCount;
   errors:=0;
   for i:=1 to 80000 do begin // проводим тест 80000 раз
    for j:=0 to 11 do ref[j]:=-1;
    hash.Init;
    // заносим в хэш 20 случайных значений с ключами от 0 до 11
    for j:=1 to 20 do begin
     k:=random(12);
     v:=random(100)-10;
     key:='K'+IntToStr(k);
     if v>0 then begin
      hash.Put(key,v);
      ref[k]:=v;
     end else begin
      hash.Put(key,Unassigned); // удаление
      ref[k]:=-1;
     end;
    end;
    if i and 15=0 then hash.SortKeys;
    // Проверяем корректность
    for j:=0 to 11 do begin
     key:='K'+IntToStr(j);
     vr:=hash.Get(key);
     vr2:=hash.Get(key);
     vr3:=hash.Get(key);
     if vr2<>vr3 then inc(errors);
     if (ref[j]=-1) and not VarIsEmpty(vr) then
      inc(errors);
     if (ref[j]>0) and (vr<>ref[j]) then
      inc(errors);
    end;
   end;
   writeln('TEST1 time: ',MyTickCount-t,'  errors: ',errors);

   // TEST 2: тест пограничных объемов, ключ уникальный
   t:=MyTickCount;
   errors:=0;
   for i:=1 to 50000 do begin
    m:=5+i and 31;
    for j:=0 to m do ref[j]:=-1;
    hash.Init;
    // заносим в хэш 30 случайных значений с ключами от 0 до m
    for j:=1 to 30 do begin
     k:=random(m);
     v:=random(100)-10;
     key:='K'+IntToStr(k)+'Hello!';
     if v>0 then begin
      hash.Put(key,v);
      ref[k]:=v;
     end else begin
      hash.Put(key,Unassigned); // удаление
      ref[k]:=-1;
     end;
    end;
    if i<1000 then hash.SortKeys;
    // Проверяем корректность
    for j:=0 to m-1 do begin
     key:='K'+IntToStr(j)+'Hello!';
     vr:=hash.Get(key);
     vr2:=hash.Get(key);
     if vr<>vr2 then inc(errors);
     vr2:=hash.Get(key);
     if vr<>vr2 then inc(errors);
     if (ref[j]=-1) and not VarIsEmpty(vr) then
      inc(errors);
     if (ref[j]>0) and (vr<>ref[j]) then
      inc(errors);
    end;
   end;
   writeln('TEST2 time: ',MyTickCount-t,'  errors: ',errors);


   // TEST 3: тест больших объемов, ключ уникальный
   t:=MyTickCount;
   errors:=0;
   randSeed:=12345678;
   for i:=1 to 5000 do begin
    for j:=0 to 199 do ref[j]:=-1;
    hash.Init;
    // заносим в хэш 300 случайных значений с ключами от 0 до 199
    for j:=1 to 300 do begin
     k:=random(200);
     v:=random(1000)-100;
     key:='K'+IntToStr(k);
     if v>0 then begin
      hash.Put(key,v);
      ref[k]:=v;
     end else begin
      hash.Put(key,Unassigned); // удаление
      ref[k]:=-1;
     end;
    end;
//    if i and 15=0 then
     hash.SortKeys;
    // Проверяем корректность
    for j:=0 to 199 do begin
     key:='K'+IntToStr(j);
     vr:=hash.Get(key);
     vr2:=hash.Get(key);
     if vr2<>vr then inc(errors);
     if (ref[j]=-1) and not VarIsEmpty(vr) then
      inc(errors);
     if (ref[j]>0) and (vr<>ref[j]) then
      inc(errors);
    end;
   end;
   writeln('TEST3 time: ',MyTickCount-t,'  errors: ',errors);

   // TEST 1M: тест малых объемов, множественные значения
   t:=MyTickCount;
   errors:=0;
   for i:=1 to 50000 do begin
    for j:=0 to 11 do ref[j]:=0;
    hash.Init(true);
    // заносим в хэш 20 случайных значений с ключами от 0 до 11
    for j:=1 to 20 do begin
     k:=random(12);
     v:=random(100);
     key:='K'+IntToStr(k);
     if v>0 then begin
      hash.Put(key,v);
      inc(ref[k]);
     end;
    end;
    if i and 15=0 then hash.SortKeys;
    // Проверяем корректность
    for j:=0 to 11 do begin
     key:='K'+IntToStr(j);
     n:=0;
     vr:=hash.Get(key);
     while not VarIsEmpty(vr) do begin
      inc(n); vr:=hash.GetNext;
     end;
     if (ref[j]<>n) then inc(errors);
    end;
   end;
   writeln('TEST1M time: ',MyTickCount-t,'  errors: ',errors);

   // TEST 3M: тест больших объемов, множественные значения
   t:=MyTickCount;
   errors:=0;
   for i:=1 to 500 do begin
    for j:=0 to 1999 do ref[j]:=0;
    hash.Init(true);
    // заносим в хэш 3000 случайных значений с ключами от 0 до 1999
    for j:=1 to 4000 do begin
     k:=random(2000);
     v:=random(10000);
     key:='K'+IntToStr(k);
     if v>0 then begin
      hash.Put(key,v);
      inc(ref[k]);
     end;
    end;
    if i and 15=0 then hash.SortKeys;
    // Проверяем корректность
    for j:=0 to 1999 do begin
     key:='K'+IntToStr(j);
     n:=0;
     vr:=hash.Get(key);
     while not VarIsEmpty(vr) do begin
      inc(n); vr:=hash.GetNext;
     end;
     if (ref[j]<>n) then inc(errors);
    end;
   end;
   writeln('TEST3M time: ',MyTickCount-t,'  errors: ',errors);
  end;

 function RandomVariant:variant;
  begin
   case random(3) of
    0:result:=random(10000000)-random(10000000); // integer
    1:result:=100*(random-random); // floating point
    2:result:=RandomStr(6);
   end;
  end;

 procedure TestHashEx;
  var
   hash:THash;
   table:array[0..499,1..15] of variant;
   i,j,k,test,errors:integer;
   t:int64;
   fl:boolean;
   line:TVariants;
   v:variant;
   sa,keys:StringArr;
  begin
   writeln('=== TestHashEx ===');
   errors:=0;
   t:=MyTickCount;
   SetLength(keys,length(table));
   // repeat 100 times
   for test:=1 to 100 do begin
    hash.Init(true);
    // Fill the table
    for i:=0 to high(table) do begin
     fl:=true;
     keys[i]:=RandomStr(7+random(3)); // ключ
     for j:=1 to 15 do begin
      if fl then table[i,j]:=RandomVariant
       else table[i,j]:=Unassigned;
      if random<0.1 then fl:=false;
     end;
    end;
    // Move data to the hash
    for i:=0 to high(table) do begin
     for j:=1 to 15 do begin
      if VarIsEmpty(table[i,j]) then break;
      hash.Put(keys[i],table[i,j]);
     end;
    end;
    if test mod 10=2 then hash.SortKeys;

    // Проверяем корректность данных
    for i:=1 to 1000 do begin
     k:=random(length(table)); // проверяем эту строку
     // 1. Через GetAll
     line:=hash.GetAll(keys[k]);
     for j:=0 to high(line) do
      if (VarType(line[j])<>VarType(table[k,1+j])) or (line[j]<>table[k,1+j]) then
        inc(errors);
     if length(line)<15 then
      if not VarIsEmpty(table[k,1+length(line)]) then
        inc(errors);
     // 2. Через Get + GetNext
     j:=1;
     v:=hash.Get(keys[k]);
     while not VarIsEmpty(v) do begin
      if j>15 then
        inc(errors);
      if v<>table[k,j] then
        inc(errors);
      inc(j);
      v:=hash.GetNext;
     end;
     // 3. Через Get(idx)
     j:=random(15);
     v:=hash.Get(keys[k],j);
     if v<>table[k,1+j] then
      inc(errors);
    end;

    // Проверяем AllKeys
    sa:=hash.AllKeys;
    SortStrings(sa);
    SortStrings(keys);
    if length(sa)<>length(keys) then
      inc(errors);
    for i:=0 to high(sa) do
     if sa[i]<>keys[i] then
       inc(errors);
   end;
   writeln('TEST_EX time: ',MyTickCount-t,'  errors: ',errors);
   if errors>0 then testsFailed:=true;
  end;

 procedure TestSortStrings;
  var
   sa:StringArr;
   i,j,n,errors:integer;
   t:int64;
  begin
   writeln('== Sort Strings ==');
   t:=MyTickCount;
   errors:=0;
   for i:=1 to 300 do begin
    n:=10+random(10000);
    SetLength(sa,n);
    for j:=0 to high(sa) do
     sa[j]:=RandomStr(4+random(3));
    SortStrings(sa);
    for j:=1 to high(sa) do
     if sa[j]<sa[j-1] then
      inc(errors); 
   end;
   writeln('SortStr time: ',MyTickCount-t,'  errors: ',errors);
   if errors>0 then testsFailed:=true;
  end;

 function GetVar(name:string):double;
  var
   v:pointer;
   vc:TVarClass;
  begin
   result:=NaN;
   if name='width' then result:=51;
   if IsNaN(result) then begin
    v:=FindVar(name,vc);
    if v<>nil then result:=StrToFloat(vc.GetValue(v));
   end;
  end;
 procedure TestEval;
  var
   a,i:integer;
   time:int64;
  procedure Compare(v1,v2:double);
   begin
    if IsNaN(v1) then begin
     writeln('FAILED - NAN!'); exit;
    end;
    if v1=v2 then writeln('Passed')
     else writeln('FAILED!!!');
   end;
  begin
   writeln('== TestEval ==');
   a:=3;
   PublishVar(@a,'a',TVarTypeInteger);
   PublishConst('C_1','10');
   PublishConst('C_2','-0.04');
   Compare(Eval('-0.05'),-0.05);
   Compare(Eval('C_1-c_2'),10+0.04);
   Compare(Eval('min(3,4,5,1,-2,3)/max(0,a)'),-2/a);
   Compare(Eval('1+max(a,-2.001)'),1+3);
   Compare(Eval('125',nil),125);
   Compare(Eval('$A0C0DEFF',nil),$A0C0DEFF);
   Compare(Eval('-9',nil),-9);
   Compare(Eval(' -9.381 ',nil),-9.381);
   Compare(Eval('1123.998',nil),1123.998);
   Compare(Eval(' 1 - 3 + 2',nil),1-3+2);
   Compare(Eval('-3*3+5',nil),-3*3+5);
   Compare(Eval('(3+5)*(2-3)',nil),(3+5)*(2-3));
   Compare(Eval('3/-2',nil),3/-2);
   Compare(Eval('a',nil),a);
   Compare(Eval('-a*3+ width ',GetVar),-a*3+GetVar('width'));
   Compare(Eval('2+3*width/-width+4',GetVar),2+3*GetVar('width')/-GetVar('width')+4);
   for i:=0 to 255 do
    PublishConst('C'+inttostr(i),inttostr(i));
   time:=MyTickCount;
   for i:=1 to 200000 do
    Eval('2.45*C'+inttostr(i and $FF)+'+C8');
   writeln('Avg Eval() time = ',(MyTickCount-time)/200000:7:5,' ms');  
  end;

type
 TMyObjType=class(TVarTypeStruct)
   class function GetField(variable:pointer;fieldName:string;out varClass:TVarClass):pointer; override;
 end;

 PMyObj=^TMyObj;
 TMyObj=record
  x,y:integer;
  next:PMyObj;
 end;

 procedure Fail(n:integer);
  begin
   writeln('FAIL',n);
   testsFailed:=true;
  end;

 var
  arr:array[1..300] of integer;
 procedure TestPublics;
  var
   v:integer;
   p:pointer;
   vc:TVarClass;
   obj1,obj2:TMyObj;
   i:integer;
   r:TRect;
  begin
   writeln('== TestPublics ==');

//   TMyObjType.IsStruct:=true;
   for i:=1 to 108 do
    PublishVar(@arr[i],'a'+IntToStr(i),TVarTypeInteger);
   PublishVar(@arr[109],'a'+IntToStr(109),TVarTypeInteger);
   for i:=1 to 14 do
    UnPublishVar(@arr[1+i*i div 2]);
   for i:=201 to 250 do
    PublishVar(@arr[i],'a'+IntToStr(i),TVarTypeInteger);
   p:=FindVar('A210',vc);
   if p<>@arr[210] then Fail(1);
   p:=FindVar('A6',vc);
   if p<>@arr[6] then Fail(2);
   p:=FindVar('A27',vc);
   if p<>@arr[27] then Fail(3);
   p:=FindVar('A1',vc);
   if p<>nil then Fail(4);

   for i:=201 to 250 do UnpublishVar(@arr[i]);

   v:=100;
   PublishVar(@v,'MyVar',TVarTypeInteger);
   p:=FindVar('myVar',vc);
   writeln('Value=',vc.GetValue(p));
   inc(v);
   writeln('Value=',vc.GetValue(p));
   vc.SetValue(p,'$FF');
   writeln('v=',v);
   UnpublishVar(@v);
   p:=FindVar('myvar',vc);
   writeln('P='+inttoStr(cardinal(p)),' - ',inttoStr(cardinal(@v)));
   obj1.x:=10; obj1.y:=20; obj1.next:=@obj2;
   obj2.x:=2; obj2.y:=-3; obj2.next:=@obj1;
   PublishVar(@obj1,'obj1',TMyObjType);
   p:=FindVar('obj1.x',vc);
   if p=@obj1.x then writeln('OK') else Fail(101);
   p:=FindVar('obj1.y',vc);
   if p=@obj1.y then writeln('OK') else Fail(102);
   p:=FindVar('obj1.next',vc);
   if p=@obj2 then writeln('OK') else Fail(103);
   p:=FindVar('obj1.Next.y',vc);
   if p=@obj2.y then writeln('OK') else Fail(104);
   p:=FindVar('x',vc,@obj1,TMyObjType);
   if p=@obj1.x then writeln('OK') else Fail(105);
   p:=FindVar('next.X',vc,@obj1,TMyObjType);
   if p=@obj2.x then writeln('OK') else Fail(106);
   p:=FindVar('Next.next.x',vc,@obj1,TMyObjType);
   if p=@obj1.x then writeln('OK') else Fail(107);

   PublishVar(@r,'Rect',TVarTypeRect);
   r.Left:=1; r.top:=2;
   r.right:=100; r.bottom:=50;
   p:=FindVar('rect',vc);
   writeln(vc.GetValue(p));

   for i:=1 to 100 do PublishConst('ABc'+inttostr(i),inttostr(i));
   for i:=1 to 20 do UnpublishConst('abC'+inttostr(i*10));
   for i:=1 to 20 do PublishConst('aBC'+inttostr(i*5),'REL');
   for i:=1 to 8 do UnpublishConst('AbC'+inttostr(i*10+4));

   for i:=1 to 110 do begin
    write(i:3,'=',FindConstValue('ABC'+inttostr(i)):4);
    if i mod 5=5 then writeln;
   end;  
  end;

{ TMyObjType }

class function TMyObjType.GetField(variable: pointer; fieldName: string;
  out varClass: TVarClass): pointer;
begin
 if fieldname='x' then begin
  result:=@(PMyObj(variable).x);
  varClass:=TVarTypeInteger;
 end else
 if fieldname='y' then begin
  result:=@(PMyObj(variable).y);
  varClass:=TVarTypeInteger;
 end else
 if fieldname='next' then begin
  result:=PMyObj(variable).next;
  varClass:=TMyObjType;
 end else begin
  result:=nil;
  varClass:=nil;
 end;
end;

 var
   hMT:TSimpleHash;
   gCount:integer;

 function TestThread(tag:cardinal):integer;
  var
   i,j,e:integer;
  begin
   InterlockedIncrement(gCount);
   e:=0;
   // заполнение
   for i:=1 to 1000000 do begin
    j:=random(500)*2;
    hMT.Put(j,j*10);
   end;
   // проверка
   for i:=1 to 499 do begin
    if hMT.HasValue(i*2-1) then
     inc(e);
    if hMT.HasValue(i*2) then
     if hMT.Get(i*2)<>i*20 then
      inc(e);
   end;
   if e>0 then begin
    writeln('Errors - ',e);
    testsFailed:=true;
   end;
   InterlockedDecrement(gCount);
  end;

 procedure testSimpleHash;
  var
   h:TSimpleHash;
   i,j,n,e:integer;
   t:cardinal;
   a:array of integer;
   id1,id2:TThreadID;
  begin
   writeln('== TestSimpleHash ==');

   h.Init(1000);
   t:=MyTickCount;
   e:=0;
   for i:=1 to 5000 do
    h.Put(i*5,i*5);
   for n:=1 to 100 do
    for i:=1 to 25000 do begin
     j:=h.Get(i);
     if (i mod 5=0) then begin
      if (j<>i) then
       inc(e);
     end else begin
      if j<>-1 then
       inc(e);
     end;
    end;
   writeln('Time: ',MyTickCount-t,' Errors: ',e);

   // Более чёткий тест
   SetLength(a,10000);
   for i:=0 to 9999 do
    a[i]:=i*100+random(100);

   h.Init(5000);
   for i:=0 to 9999 do h.Put(a[i],a[i]);
   for i:=0 to 999 do h.Remove(a[i]);
   t:=MyTickCount; e:=0;
   for i:=0 to 999 do
    if h.Get(a[i])<>-1 then inc(e);
   for i:=1000 to 9999 do
    if h.Get(a[i])<>a[i] then inc(e);
   writeln('Time: ',MyTickCount-t,' Errors: ',e);

   // Еще более чёткий тест!
   SetLength(a,1000);
   for i:=0 to 999 do a[i]:=-1; // empty
   h.Init(300);
   t:=MyTickCount; e:=0;
   for i:=0 to 100000 do begin
    j:=10+random(1000-10);
    if random(10)>2 then begin
     h.Put(j,j); a[j]:=j;
    end else begin
     h.Remove(j); a[j]:=-1;
    end;
   end;
   // Check
   for i:=0 to 999 do begin
    if h.HasValue(i)<>(a[i]>=0) then
     inc(e);
    if a[i]<>h.get(i) then
     inc(e);
   end;
   writeln('Time: ',MyTickCount-t,' Errors: ',e);

   hMT.Init(200);
   t:=MyTickCount; gCount:=0;
   BeginThread(@TestThread,nil,id1,65536);
   BeginThread(@TestThread,nil,id2,65536);
   sleep(10);
   repeat
    sleep(0);
   until gCount=0;
{   WaitForSingleObject(id1,3000);
   WaitForSingleObject(id2,3000);}
   writeln('Time: ',MyTickCount-t);

   if e>0 then testsFailed:=true;
  end;

 procedure TestTStrHash;
  var
   sa:StringArr;
   hash:TStrHash;
   key:string;
   v,sum:integer;
  begin
   writeln('== Test TStrHash ==');
   hash:=TStrHash.Create;
   SetLength(sa,321);
   sum:=0;
   for i:=0 to high(sa) do begin
    sum:=sum+i;
    sa[i]:=IntToStr(i);
    hash.Put(sa[i],pointer(i));
   end;
   key:=hash.FirstKey;
   while hash.LastError<>esNoMoreItems do begin
    v:=StrToInt(key);
    if (v<0) or (v>high(sa)) then raise EWarning.Create('Invalid key');
    dec(sum,v);
    key:=hash.NextKey;
   end;
   if sum<>0 then raise EWarning.Create('Not all keys iterated');
  end;

  {$R-}
  function HashValueS(const k:string):cardinal;
   var
    i:integer;
   begin
    result:=length(k);
    for i:=1 to length(k) do result:=result*$20844 xor byte(k[i]);
//    result:=result and 4095;
   end;

{ function StrHash(const st:string):cardinal; 
  var
   i:integer;
  begin
   result:=length(st);
   for i:=1 to length(st) do
    result:=result*$20844 xor byte(st[i]);
  end;                   }
  {$R+}
   
 procedure TestStrHash;
  var
   i,j,l,min,max:integer;
   st:string;
   arr:array[0..65535] of integer;
   t:int64;
   h:cardinal;
   sa:StringArr;
  begin
   writeln('== TestStrHash ==');
   FillChar(arr,sizeof(arr),0);
   SetLength(sa,4000000);
   for i:=1 to 4000000 do begin
    l:=2+random(random(30));
    SetLength(st,l);
    for j:=1 to l do
     st[j]:=chr(32+random(126-32));
    sa[i-1]:=st;
   end;
   
   t:=MyTickCount;
   for i:=0 to high(sa) do begin
//    h:=length(sa[i]);
    h:=StrHash(sa[i]);
//    h:=HashValueS(sa[i]);
    inc(arr[h and $FFF]);
   end;
   t:=MyTickCount-t;

   min:=10000; max:=0; h:=0;
   l:=round(length(sa)/$1000);
   for i:=0 to $FFF do begin
    if arr[i]<min then min:=arr[i];
    if arr[i]>max then max:=arr[i];
    if (arr[i]<l*0.9) or (arr[i]>l*1.1) then inc(h);
   end;
   writeln('Min = ',min,'  Max = ',max,'  H = ',(100*h/$1000):0:2,'% time=',t);
  end;

 procedure TestGeoIP;
  var
   i:integer;
   ip:cardinal;
   time:cardinal;
  begin
   writeln('== TestGeoIP ==');
   time:=MyTickCount;
   InitGeoIP('e:\web\geoIP');
   writeln('Loading time = ',MyTickCount-time);

   writeln(GetCountryByIP(StrToIp('93.170.184.83')));
   time:=MyTickCount;
   for i:=1 to 1000000 do begin
    ip:=cardinal(random(65500)) shl 16 + random(65500);
    GetCountryByIP(ip)
//    writeln(IpToStr(ip),' - ',GetCountryByIP(ip));
   end;
   writeln('Time = ',MyTickCount-time);
  end;

 procedure TestSplines;
  var
   i,v:integer;
  begin
   writeln('== TestSplines ==');
   Spline(0.999,0,1,1,1);   
   for i:=0 to 20 do begin
    writeln(i:4,
            Spline(i/20,0,1,0,-1):8:3,
            Spline(i/20,0,1,0,2):7:3,
            Spline(i/20,0,1,1,1):7:3,
            Spline(i/20,0,0,1,-1):7:3);
   end;
   writeln;
   for i:=0 to 10 do begin
    writeln(i:4,
            SatSpline(i/10,0,200,0):8,
            SatSpline(i/10,100,200,0):5,
            SatSpline(i/10,240,240,0):5,
            SatSpline(i/10,240,50,0):5,
            SatSpline(i/10,240,40,100):5);
   end;
   writeln;
   for i:=0 to 12 do begin
    writeln(i:4,
            SatSpline3(i/12,0,200,200,0):8,
            SatSpline3(i/12,100,200,100,200):5,
            SatSpline3(i/12,240,240,0,0):5,
            SatSpline3(i/12,240,100,100,0):5,
            SatSpline3(i/12,240,40,100,100):5);
   end;
  end;

procedure TestRLE;
 var
  sour,dest,res:ByteArray;
  i:integer;
  t:int64;
 procedure Check;
  var
   i:integer;
   fail:boolean;
  begin
   fail:=false;
   if length(sour)=length(res) then begin
    for i:=0 to high(sour) do
     if sour[i]<>res[i] then fail:=true;
   end else
    fail:=true;
   if fail then begin
    writeln('TEST FAILURE');
    testsFailed:=true;
   end else
    writeln('OK! (ratio=',100*length(dest)/length(sour):2:1,'%)');
  end;
 begin
  writeln('== TestRLE ==');
  SetLength(sour,1024);
  // Test 1
  for i:=0 to high(sour) do sour[i]:=byte(i);
  dest:=PackRLE(@sour[0],length(sour),false);
  res:=UnpackRLE(dest,length(dest));
  Check;
  // Test 2
  for i:=0 to high(sour) do sour[i]:=random(random(4));
  dest:=PackRLE(@sour[0],length(sour),false);
  res:=UnpackRLE(dest,length(dest));
  Check;
  // Test 3
  for i:=0 to high(sour) do sour[i]:=i div 194;
  dest:=PackRLE(@sour[0],length(sour),false);
  res:=UnpackRLE(dest,length(dest));
  Check;

  // Speed test
  SetLength(sour,1024*1024); // 1Mb
  for i:=0 to high(sour) do sour[i]:=random(random(4));
  dest:=PackRLE(@sour[0],length(sour));
  res:=UnpackRLE(dest,length(dest));
  Check;

  t:=MyTickCount;
  for i:=1 to 100 do
   dest:=PackRLE(@sour[0],length(sour));
  writeln('Pack time (100Mb) = ',MyTickCount-t);
  
  t:=MyTickCount;
  for i:=1 to 100 do
   res:=UnpackRLE(dest,length(dest));
  writeln('Unpack time (100Mb) = ',MyTickCount-t);
 end;

procedure TestPatch;
var
 sour,dest,patch:ByteArray;
 i,size:integer;
 hash:int64;
procedure FillDest(r:integer);
 var
  i:integer;
 begin
  for i:=0 to size-1 do
   if random(1000)<r then dest[i]:=random(256)
    else dest[i]:=sour[i];
 end;
begin
 writeln('Test diff patch');
 size:=1000000;
// size:=127*228+2;
 SetLength(sour,size);
 SetLength(dest,size);
 for i:=0 to size-1 do
  sour[i]:=random(256);

 hash:=CheckSum64(@sour[0],size);

 FillDest(1000);
 patch:=CreateDiffPatch(@sour[0],@dest[0],size);
 ApplyDiffPatch(@dest[0],size,@patch[0],length(patch));
 if CheckSum64(@dest[0],size)<>hash then raise EError.Create('PATCH CASE 1 FAILED!')
  else write('CASE 1 OK ');

 FillDest(100);
 patch:=CreateDiffPatch(@sour[0],@dest[0],size);
 ApplyDiffPatch(@dest[0],size,@patch[0],length(patch));
 if CheckSum64(@dest[0],size)<>hash then raise EError.Create('PATCH CASE 2 FAILED!')
  else write('CASE 2 OK ');

 FillDest(10);
 patch:=CreateDiffPatch(@sour[0],@dest[0],size);
 ApplyDiffPatch(@dest[0],size,@patch[0],length(patch));
 if CheckSum64(@dest[0],size)<>hash then raise EError.Create('PATCH CASE 3 FAILED!')
  else write('CASE 3 OK ');

 FillDest(0);
 patch:=CreateDiffPatch(@sour[0],@dest[0],size);
 ApplyDiffPatch(@dest[0],size,@patch[0],length(patch));
 if CheckSum64(@dest[0],size)<>hash then raise EError.Create('PATCH CASE 4 FAILED!')
  else write('CASE 4 OK ');

end;

procedure TestB64;
var
 src,dst:array[1..50] of byte;
 i,j,size,newSize:integer;
 st:string;
begin
 writeln('== TestB64 ==');

{ src[1]:=$5D; size:=1;
 st:=EncodeB64(@src,size);
 DecodeB64(st,@dst,newSize);}

 for i:=1 to 1000 do begin
  size:=1+random(15);
  for j:=1 to size do src[j]:=random(255);
  st:=EncodeB64(@src,size);
  DecodeB64(st,@dst,newSize);
  if newSize<>size then begin
   writeln(i,' Size mismatch');
   testsFailed:=true;
  end;
  if not CompareMem(@src,@dst,size) then begin
   writeln(i,' Failed! ');
   writeln(' src = ',HexDump(@src,size));
   writeln(' dst = ',HexDump(@dst,size));
   testsFailed:=true;
  end;
 end;
end;

type
 TTestThread=class(TThread)
  procedure Execute; override;
 end;

procedure DoSomeJob(cnt:integer=1000);
 var
  i:integer;
  a:array[1..100] of integer;
 begin
  while cnt>0 do begin
   for i:=low(a) to high(a) do begin
    a[i]:=random(1000);
    inc(a[i]);
   end;
   dec(cnt);
  end;
 end;

procedure TTestThread.execute;
 var
  i:integer;
 begin
  for i:=1 to 60 do begin
   DoSomeJob(100000);
   sleep(1);
   write('*');
  end;
 end;

procedure TestProfiling;
 var
  thread:TTestThread;
 begin
  thread:=TTestThread.Create(false);
  AddThreadForProfiling(thread.Handle,'T1');
  StartProfiling(500,500);
  sleep(3000);
  StopProfiling;
  SaveProfilingResults('profiling.dat');
  writeln;
 end;

procedure TestMemoryStat;
 var i,s,c,prev,next:integer;
  p:pointer;
 begin
  c:=0; s:=0;
  prev:=GetMemoryAllocated;
  writeln('       ',c:8,prev:10);
  for i:=1 to 24 do begin
   s:=10+random(random(30000));
   inc(c,s);
   GetMem(p,s);
   next:=GetMemoryAllocated;
   writeln(c:8,s:7,(next-prev):10);
   prev:=next;
  end;
 end;

 procedure TestDateTime;
  var
   st1,st2,st3:string;
   d1,d2,d3,d4:TDateTime;
   i:integer;
   f1,f2,f3:boolean;
  begin
   writeln('== TestDateTime ==');
   for i:=1 to 20 do begin
    d1:=30000+random(20000)+random;
    st1:=FormatDateTime('dd.mm.yy hh:nn:ss',d1);
    st2:=FormatDateTime('dd.mm.yyyy hh:nn',d1);
    st3:=FormatDateTime('yyyy.mm.dd hh:nn',d1);
    d2:=GetDateFromStr(st1);
    d3:=GetDateFromStr(st2);
    d4:=GetDateFromStr(st3);
    f1:=abs(d2-d1)>2/86400;
    f2:=abs(d2-d1)>2/1440;
    f3:=abs(d3-d1)>2/1440;
    writeln(st1:18,st2:18,abs(d2-d1):12:5,abs(d3-d1):9:5,abs(d4-d1):9:5);
    if f1 or f2 or f3 then testsFailed:=true;
   end;
  end;

 procedure TestTime;
  var
   i:integer;
   t,t0:int64;
   c,c0,f:int64;
   v,v0:int64;
   maxD:double;
   cD:double;
  begin
   QueryPerformanceFrequency(f);
   t0:=MyTickCount;
   for i:=1 to 1000000 do t:=MyTickCount;
   write('Avg MTC time: ',(t-t0),' ns.   ');
   t0:=MyTickCount;
   for i:=1 to 10000000 do t:=GetTickCount;
   t:=MyTickCount;
   write('Avg GTC time: ',(t-t0)/10:4:1,' ns.   ');
   t0:=MyTickCount;
   for i:=1 to 1000000 do QueryPerformanceCounter(t);
   t:=MyTickCount;
   writeln('Avg QPC time: ',(t-t0),' ns');

   t0:=MyTickCount;
   QueryPerformanceCounter(c0);
   v0:=GetTickCount;
   maxD:=0;
   for i:=1 to 20 do begin
    sleep(50+random(50));
    QueryPerformanceCounter(c);
    t:=MyTickCount;
    v:=GetTickCount;
    cD:=1000*(c-c0)/f+0.5;
    c:=round(cd);
    writeln(Format('QPC: %-7.1f      MyTC: %-5d (%4.1f)       GTC: %-5d (%4.1f)',
      [cd,t-t0,t-t0-cd,v-v0,v-v0-cd]));
    maxD:=max2D(maxD,abs(t-t0-cd));
   end;
   writeln('Max error: ',maxD:4:1);
   if maxD>2 then testsFailed:=true;
  end;

 // Вывод: сравнение через lowercase - в 4-5 раз быстрее, чем через AnsiSameText
 procedure TestSort;
  var
   data:array[1..5000] of string;
   i,j,n,c:integer;
   t:int64;
   st:string;
  begin
   n:=3000;
   for i:=1 to n do begin
    data[i]:='';
    for j:=1 to 12 do begin
     data[i]:=data[i]+chr(65+random(15)+32*(1-random(2)*random(2)*random(2)));
     if (j>2) and (random(100)<10) then break;
    end;
   end;
   t:=MyTickCount;
   c:=0;
   for i:=1 to n-1 do begin
    st:=lowercase(data[i]);
    for j:=i+1 to n do
     if st=lowercase(data[j]) then begin
      writeln(data[i],' = ',data[j],i:5,j:5); inc(c);
     end;
   end;

   writeln('c=',c,' Time=',MyTickCount-t);
  end;

 procedure TestStringTools;
  var
   st:string;
   r:integer;
  begin
   st:=ExtractStr('<!--HELLO-->','<!--','-->',r);
   writeln('{'+st+'} ',r);
   st:=ExtractStr('!-- <!--test--> ddd  -->','<!--','-->',r);
   writeln('{'+st+'} ',r);
  end;

 procedure TestTextUtils;
  var
   i,j,k:integer;
   t:int64;
   w1,w2:WideString;
   ia:IntArray;
   sa:WStringArr;
  begin
{   t:=MyTickCount;
   for i:=1 to 100000 do
    sa:=SplitToWords('I think I mentioned that I would prefer a 20ish SP cap and 80ish Life cap. '+
      'The only reason I hold against having a life cap is that then you don''t get the fun of '+
      'trying to see how high of Life you can get (I wonder at what amount the game either breaks or doesn''t give you anymore?).');
   t:=MyTickCount-t;
   writeln('Time1 = ',t);}

   t:=MyTickCount;
   w1:='невероятный';
   w2:='невероятным';
   for i:=1 to 1000000 do
    k:=GetWordsDistance(w1,w2);
//    ia:=GetMaxSubsequence(w1,w2);
   t:=MyTickCount-t;
   writeln('Time2 = ',t);
  end;

 var
  handled:integer=0;
  sent:integer=0;
  trID:DWORD;

 function EventHandler(event:eventStr;tag:TTag):boolean;
  var
   i,j:integer;
  begin
   j:=1;
   for i:=1 to 300000 do inc(j,i);
   result:=j and $400>0;
   inc(handled);
   LogMessage('Handled: '+event+':'+inttostr(tag));
  end;

 function ThreadProc(param:pointer):cardinal; stdcall;
  begin
   SetEventHandler('TESTEVENT',eventHandler,emQueued);
   repeat
    sleep(0);
    HandleSignals;
   until handled>=1500;
   LogMessage('Thread finished');
  end;

 procedure TestEvents;
  var
   i:integer;
  begin
   CreateThread(nil,0,@threadProc,nil,0,trID);
   sleep(50);
   for i:=1 to 1501 do begin
    Signal('TESTEVENT\'+inttostr(i),i);
    inc(sent);
    LogMessage('Sent: '+inttostr(i));
   end;
   sleep(100);
   Writeln('OK');
  end;

{
 procedure TestHuffman;
  var
   sour1,dest1:ByteArray;
   sour2,dest2:WordArray;
   compressed:ByteArray;
   alphabet:IntArray;
   i,j,size:integer;
  begin
   writeln('== Test Huffman Coder ==');
   size:=100;
   SetLength(sour1,size);
   for i:=0 to size-1 do
    sour1[i]:=10+random(random(200));
   alphabet:=CreateAlphabetForBytes(sour1);

  end;    }

 procedure TestClipboard;
  const
   TEST:UTF8String='[Привет!]';
   TEST_W:WideString='[Привет!]';
  begin
   CopyStrToClipboard(TEST);
   ASSERT(PasteStrFromClipboard=TEST,'Clipboard test 1');
   CopyStrToClipboard(TEST_W);
   ASSERT(PasteStrFromClipboardW=TEST_W,'Clipboard test 2');
  end;

 procedure TestPNG;
  var
   img:TRawImage;
   data,res:ByteArray;
  begin
   data:=LoadFileAsBytes('test.png');
   LoadPNG(data,img);
   res:=SavePNG(img);
   SaveFile('test_out.png',res);
  end;

 procedure TestStackTrace;
  procedure p2;
   var
    a:array of integer;
   begin
    writeln('Hello from p2');
    SetLength(a,4);
    a[1]:=0;
    a[0]:=a[0] div a[1];
    //a[6]:=1;
   end;
  procedure p1;
   var
    a,b,c,d:integer;
   begin
    writeln('Hello from p1');
    a:=1; b:=2; c:=3; d:=4;
    if a+b+c+d>0 then p2;
   end;
  begin
   EnableStackTrace;
   p1;
  end;

var
 ar:array of cardinal;
 st:WideString;
 pc:PChar;
 rc:array[1..10] of integer;
 wst:WideString;
begin
 UseLogFile('log.txt',true);
// LogCacheMode(true);
 try
  TestTranslation;
  TestStackTrace;

  TestPNG;
  TestAnimations;
  TestEval;
  TestClipboard;
  TestSortStrings;
  TestTStrHash;
  TestB64;
  TestPublics;
  TestHash;
  TestHashEx;
  testQuotes;
  TestSplitCombine;
  TestStrHash;
  TestSimpleHash;
  TestGeoIP;
  TestSplines;
  TestRLE;
  TestProfiling;
  TestMemoryStat;
  TestDateTime;
  TestTextUtils;
  TestStringTools;
  TestSortStrings;
  TestSort;
  TestSplitCombine;
  TestTime;
  TestPatch;

//  TestEvents;
 except
  on e:exception do begin
   writeln('ERROR: ',ExceptionMsg(e));
   testsFailed:=true;
  end;
 end;
 if testsFailed then begin
  writeln('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
  writeln('!!!!!!!!!! TESTS FAILED !!!!!!!!!!!!!!');
  writeln('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
 end else
  writeln('--------------------- DONE! ---------------------'#13#10' Everything is OK!');
 readln;
end.
