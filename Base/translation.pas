// Text translation routines
// Author Ivan Polyacov (ivan@apus-software.com, cooler@tut.by)
// Dictionary file format (utf-8):
// -----
// LanguageID: ru
// ; comment
// [N] set of rules (0..99)
// Source %* string 1 
// Translated %1 string 1
// (separator - empty string or comment)
// Source string 2
// Translated string 2
// -----
// Принцип работы перевода
// К исходной строке применяются последовательно все правила по порядку.
// %* матчит любые символы, поэтому имеет смысл только в середине выражения.
// %w матчит любые символы, кроме неотображаемых (пробел и т.п)
// %d матчит только цифры
// Т.о. порядок правил в словаре имеет значение.
// По умолчанию подстроки %n при переносе не переводятся, но если нужно перевести -
// нужно использовать формат %n{s}, где s - номер набора правил (0..9), которым следует перевести подстроку
// В самом конце удаляются подстроки вида `d (метки контекста, содержащие 1 цифру)
// Если в начале исходной строки стоит цифра с двоеточием и пробелом - то это цифра
// обозначает номер набора для конкретно этого правила
unit Translation;
interface
 uses MyServis;
 type
  {$IFNDEF UNICODE}
  MyString=WideString;
  {$ELSE}
  MyString=UnicodeString;
  {$ENDIF}
 var
  languageID:string;
  defaultEncoding:TTextEncoding=teUTF8;

  // for statistics
  trRuleFault:cardinal=0;
  trRuleSuccess:cardinal=0;


 // Load dictionary file
 procedure LoadDictionary(filename:string);
 // Add translation rule (ruleset=0..99)
 procedure AddTranslationRule(sour,dest:MyString;ruleset:integer);

 // Translate string using given set of rules (teUnknown = use default encoding)
 function Translate8(st:string;ruleset:integer=0;encoding:TTextEncoding=teUnknown):string;
 function Translate(st:MyString;ruleset:integer=0):MyString;

implementation
 uses SysUtils,StrUtils;
 type
  // single rule
  // Special characters: E1FA-E1FF - in sour (типы спецсимволов подстрок, %*, %w, %d ...)
  // E1E0-E1E9,E1F0-E1F9 - in dest (X or XY, where X is substr index, Y - translation rule)
  TRule=record
   sour,dest:MyString;
   sPos:array[0..9] of smallint;
   sCnt:integer; // кол-во спецсимволов в sour
   mask1,mask2:cardinal;
  end;

  TCache=record
   sour,dest:array[0..31] of MyString;
   first,last:integer; // первый занятый элемент, первый свободный
  end;

  TRulesSet=class
   rules:array of TRule;
   rCount:integer;
   cache:TCache;
   constructor Create;
   destructor Destroy;
   procedure AddRule(sour,dest:MyString);
   function Translate(st:MyString):MyString;
  end;

 var
  sets:array[0..99] of TRulesSet;

 procedure AddTranslationRule(sour,dest:MyString;ruleset:integer);
  begin
   if sets[ruleset]=nil then
    sets[ruleset]:=TRulesSet.Create;
   sets[ruleset].AddRule(sour,dest);
  end;

 procedure LoadDictionary(filename:string);
  var
   f:text;
   st8:string;
   st,sour:MyString;
   i,curSet,localSet:integer;
   utf8:boolean;
  begin
   assign(f,filename);
   try
    reset(f);
    curSet:=0;
    localSet:=-1;
    sour:='';
    utf8:=false;
    // Parse file
    while not eof(f) do begin
     readln(f,st8);
     // convert 8-bit string to unicode
     if not utf8 and IsUTF8(st8) then begin
      utf8:=true;
      delete(st8,1,3);
     end;
     if utf8 then st:=DecodeUTF8(st8)
      else st:=UnicodeFrom(st8,teWin1251);

     if length(st)=0 then begin // empty string
      sour:=''; continue;
     end;
     if st[1]=';' then begin // comment
      sour:=''; continue;
     end;
     if pos('LanguageID: ',st)=1 then begin
      LanguageID:=copy(st,13,100);
      continue;
     end;
     if (st[1]='[') and (length(st)>2) and (st[2] in ['0'..'9']) then begin // set
      curSet:=StrToInt(st[2]);
      if st[3] in ['0'..'9'] then curSet:=curSet*10+StrToInt(st[3]);
      sour:=''; continue;
     end;
     if (length(st)>3) and (st[1] in ['0'..'9']) and (st[2]=':') and (st[3]=' ') then begin
      localSet:=StrToInt(st[1]);
      delete(st,1,3);
     end;
     // Rule
     if sour<>'' then begin
      if localSet>=0 then
       AddTranslationRule(sour,st,localSet)
      else
       AddTranslationRule(sour,st,curSet);
      localSet:=-1; 
     end else
      sour:=st;
    end;
    close(f);
   except
    on e:exception do raise EError.Create('Error in LoadDictionary '+filename+': '+e.message);
   end;
  end;

 function Translate8(st:string;ruleset:integer=0;encoding:TTextEncoding=teUnknown):string;
  var
   wst:MyString;
  begin
   if sets[ruleset]=nil then begin
    result:=st; exit;
   end;
   if encoding=teUnknown then encoding:=defaultEncoding;
   wst:=UnicodeFrom(st,encoding);
   wst:=Translate(wst,ruleset);
   result:=UnicodeTo(wst,encoding);
  end;

 function Translate(st:MyString;ruleset:integer=0):MyString;
  begin
   result:=sets[ruleset].Translate(st);
  end;

 procedure CalcBitmask(st:MyString;var m1,m2:cardinal); // inline;
  var
   i,h:integer;
   w,wPrv:word;
  begin
   m1:=0; m2:=0;
   if length(st)<2 then exit;
   wPrv:=word(st[1]);
   for i:=2 to length(st) do begin
    w:=word(st[i]);
    if ((w<$E1FA) or (w>$E1FF)) and
       ((wPrv<$E1FA) or (wPrv>$E1FF)) then begin // pair of non-special characters
     h:=(w xor wPrv) and 63;
     if h>=32 then m2:=m2 or (1 shl (h-32))
      else m1:=m1 or (1 shl h);
    end;
    wPrv:=w;
   end;
  end;

{ TRulesSet }

procedure TRulesSet.AddRule(sour, dest: MyString);
 var
  b:byte;
  i,c,l:integer;
  m1,m2:cardinal;
  w,wPrv:word;
 begin
  if rCount>=length(rules) then begin
   SetLength(rules,length(rules)*2+10);
  end;
  // Заменить %* в sour
  i:=1; c:=0;
  while i<length(sour) do begin
   if (sour[i]='%') and (sour[i+1] in ['*','d']) then begin
    if sour[i+1]='*' then sour[i]:=WideChar($E1FA);
    if sour[i+1]='d' then sour[i]:=WideChar($E1FB);
    if sour[i+1]='w' then sour[i]:=WideChar($E1FC);
    if sour[i+1]='+' then sour[i]:=WideChar($E1FD);
    inc(c);
    delete(sour,i+1,1);
   end;
   inc(i);
  end;
  // Заменить %d{n} в dest
  i:=1;
  while i<length(dest) do begin
   if (dest[i]='%') and (dest[i+1] in ['1'..'9']) then begin
    dest[i]:=WideChar($E1E0+word(dest[i+1])-ord('0'));
    if (dest[i+2]='{') and (dest[i+3] in ['1'..'9']) and (dest[i+4]='}') then begin
     dest[i+1]:=WideChar($E1F0+word(dest[i+3])-ord('0'));
     delete(dest,i+2,3);
    end else begin
     delete(dest,i+1,1);
    end;
   end;
   inc(i);
  end;
  // Добавить префикс и суффикс если необходимо
  w:=word(sour[1]);
  if w<$E1FA then begin
   sour:=WideChar($E1FA)+sour; // %* в начало
   dest:=WideChar($E1E0)+dest; // %0 в начало
  end;
  w:=word(sour[length(sour)]);
  if w<>$E1FA then begin
   sour:=sour+WideChar($E1FA); // %* в конец
   dest:=dest+WideChar($E1E0+c+1); // %n в конец
  end;
  // запомнить позиции спецсимволов
  c:=0;
  for i:=1 to length(sour) do begin
   w:=word(sour[i]);
   if (w>=$E1FA) and (w<=$E1FF) then begin
    rules[rCount].sPos[c]:=i;
    inc(c);
   end;
  end;
  rules[rCount].sCnt:=c;
  // вычислить битмаску
  CalcBitmask(sour,rules[rCount].mask1,rules[rCount].mask2);

  // rule data
  rules[rcount].sour:=sour;
  rules[rcount].dest:=dest;

  // Check for dupe
  for i:=0 to rcount-1 do
   if rules[i].sour=sour then begin
    if rules[i].dest=dest then
     LogMessage('Duplicated translation rule ignored for: '+sour)
    else
     LogMessage('WARNING! Translation rule conflict for: '+sour+' only 1-st rule will be used');
    dec(rCount);
    break;
   end;

  inc(rCount);
  cache.first:=0;
  cache.last:=0;
 end;

constructor TRulesSet.Create;
 var
  i:integer;
 begin
  rCount:=0;
  setLength(rules,10);
  cache.first:=0;
  cache.last:=0;
 end;

destructor TRulesSet.Destroy;
 begin
  setLength(rules,0);
 end;

// Locate substr in str starting from index, returns index of substr or 0 if not found
function WStrPos(substr,str:MyString;index:integer):integer; inline;
 var
  c,m,l:integer;
 begin
  result:=0;
  l:=length(substr);
  m:=length(str)-l+1;
  while index<=m do begin
   c:=0;
   while c<l do begin
    if str[index+c]<>substr[c+1] then break;
    inc(c);
   end;
   if c=l then begin
    result:=index; exit;
   end;
   inc(index);
  end;
 end;

function TRulesSet.Translate(st: MyString): MyString;
 var
  i,j,k,r,p1,p2:integer;
  m1,m2:cardinal;
  mPos,mEnd:array[0..10] of integer;
  mCnt:integer;
  w,w2:word;
  tmp:MyString;
 begin
  result:=st;
  if self=nil then exit;
  if rcount=0 then exit;
  // поиск в кэше
  with cache do begin
   if first<>last then begin
    i:=last;
    j:=length(st);
    while i<>first do begin
     i:=(i-1) and 31;
     if sour[i]=st then begin
      result:=dest[i];
      exit;
     end;
    end;
   end;
   sour[last]:=st;
  end;

  CalcBitmask(st,m1,m2);
  for i:=0 to rCount-1 do with rules[i] do begin
   // если в масках правила есть хоть один бит, которого нет в маске строки - значит правило к строке не подходит
   if ((mask1 and not m1)>0) or
      ((mask2 and not m2)>0) then continue;
   // попробуем применить правило
   // нужно а) найти все подстроки из правила в правильном порядке б) произвести замены
   mcnt:=0; // сколько подстрок найдено
   k:=1; // точка начала поиска
   p1:=sPos[0];
   for j:=1 to sCnt-1 do begin
    p2:=sPos[j];
    r:=WStrPos(copy(sour,p1+1,p2-p1-1),st,k);
    if r=0 then break;
    inc(mcnt);
    mPos[mcnt]:=r; // индекс начала найденной цепочки в st
    mEnd[mcnt]:=r+p2-p1-2;
    k:=(p2-p1-1)+r; // тут еще нужна валидация очередного спецсимвола, если он необычный
    p1:=p2;
   end;
   if mcnt<sCnt-1 then begin
    inc(trRuleFault);
    continue; // правило не подходит
   end;
   // если дошли сюда - значит правило подходит и нужно его применить
   inc(trRuleSuccess);
   // здесь используется ручной код вместо стандартных ф-ций т.к. это НАМНОГО увеличивает скорость
   setLength(result,length(dest)+length(st)); // заведомо достаточная длина
   k:=0; // кол-во добавленных в result символов
   mEnd[0]:=0;
   mPos[mcnt+1]:=length(st)+1;
   for j:=1 to length(dest) do begin
    w:=word(dest[j]);
    if (w>=$E1F0) and (w<=$E1F9) then continue;
    if (w>=$E1E0) and (w<=$E1E9) then begin
     w:=w-$E1E0;
     if j<length(dest) then w2:=word(dest[j+1])
      else w2:=0;
     if (w2>=$E1F0) and (w2<=$E1F9) then begin
      // translate substring
      w2:=w2-$E1F0;
      r:=mEnd[w]+1;
      tmp:=sets[w2].Translate(copy(st,r,mPos[w+1]-r));
      r:=1;
      while r<=length(tmp) do begin
       inc(k);
       result[k]:=tmp[r];
       inc(r);
      end;
     end else begin
      // just copy substring from st
      r:=mEnd[w]+1;
      while r<mPos[w+1] do begin
       inc(k);
       result[k]:=st[r];
       inc(r);
      end;
     end;
     continue;
    end;
    inc(k);
    result[k]:=WideChar(w);
   end;
   setLength(result,k);
   st:=result;
   CalcBitmask(st,m1,m2);
  end;
  // Add to cache
  with cache do begin
   dest[last]:=result;
   last:=(last+1) and 31;
   if last=first then first:=(first+1) and 31;
  end;
 end;

end.
