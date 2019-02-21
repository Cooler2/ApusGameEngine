unit UDict;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

var
    languageID:integer;
    langCode,langName,langNameEn,langFileName:string;
    unicode,translated:boolean;
    langCreatedBy:UTF8String; // Creator/contributor name
    langBaseDir:UTF8String; // base directory for the language-specific files (default = langCode)


procedure DictInit(fname:UTF8String='';fname2:UTF8String='');
function Translate(s:UTF8String):UTF8String; overload;
function Translate(s:widestring):widestring; overload;
function Tr(s:UTF8String):UTF8String;
function Simply(s:UTF8String):UTF8String;
// Decode UTF8String from UTF8 to 8bit if dictionary is in UTF8
function Decode(s:UTF8String):UTF8String;
function Simplify(s:UTF8String):UTF8String; overload;
function Simplify(s:widestring):widestring; overload;

implementation
uses sysutils,MyServis;

type

 tconv=object
  def,new:UTF8String;
  defW,newW:widestring;
  age:integer;
 end;

var conv:array of tconv;
    replaceconv:array of tconv;
    tcv:tconv;
    numconv,curconv,numreplaceconv:integer;
    sorttime:integer;
    curage:integer;

function Simply(s:UTF8String):UTF8String;
var q:integer;
    c:AnsiChar;
begin
 q:=1;
 while q<=length(s) do
 begin
  c:=s[q];
  if (c=' ')or(c='''')or(c='^')or(c='-')or(c=#0)or(c=#9) then
   delete(s,q,1)
  else
   inc(q);
 end;
 Result:=s;
end;


procedure checknew(num:integer);
begin
 if num>0 then if conv[num].def>conv[(num-1) div 2].def then
 begin
  tcv:=conv[num];
  conv[num]:=conv[(num-1) div 2];
  conv[(num-1) div 2]:=tcv;
  checknew((num-1) div 2);
 end;
end;

procedure checkold(num:integer);
var needchange:integer;
begin
 needchange:=0;
 if (num*2+2<=curconv-1)and(conv[num*2+1].def<conv[num*2+2].def) then
  needchange:=num*2+2
 else
  if num*2+1<=curconv-1 then needchange:=num*2+1
  else
   exit;
 if conv[num].def<conv[needchange].def then
 begin
  tcv:=conv[num];
  conv[num]:=conv[needchange];
  conv[needchange]:=tcv;
  checkold(needchange);
 end;
end;

procedure processString(s:UTF8String);
var s1,s2:UTF8String;
    i,q,w,e:integer;
    sa:StringArr;
begin
 inc(curage);
 if IsUTF8(s) then begin
  unicode:=true;
  delete(s,1,3);
 end;
 w:=pos('//',s);
 if w=1 then exit;
 if w>0 then begin
  q:=0;
  for i:=1 to w-1 do
   if s[i]='''' then inc(q);
  if q mod 2=0 then delete(s,w,length(s)); // comment
 end;
 if uppercase(copy(s,1,10))='LANGUAGEID' then
 begin
  q:=pos('=',s);
  if q>0 then
  begin
   s1:=chop(copy(s,q+1,255));
   sa:=Split(';',s1);
   try
    languageID:=strtoint(sa[0]);
    if (length(sa)>1) and (sa[1]<>'') then langCode:=chop(sa[1]);
    if (length(sa)>2) and (sa[2]<>'') then langNameEn:=chop(sa[2]);
    if (length(sa)>3) and (sa[3]<>'') then langName:=chop(sa[3]);
   except
    languageID:=0;
   end;
  end;
 end;

 if uppercase(copy(s,1,9))='CREATEDBY' then
 begin
  q:=pos('=',s);
  if q>0 then langCreatedBy:=chop(copy(s,q+1,255));
 end;

 if uppercase(copy(s,1,7))='BASEDIR' then
 begin
  q:=pos('=',s);
  if q>0 then langBaseDir:=chop(copy(s,q+1,255));
 end;

 q:=pos(''''+'''',s);
 while q>0 do
 begin
  s:=copy(s,1,q-1)+'^'+copy(s,q+2);
  q:=pos(''''+'''',s);
 end;

 q:=pos('''',s);
 if q<>0 then
 begin
  s:=copy(s,q+1,2555);
  q:=pos('''',s);
  if q<>0 then
  begin
   s1:=copy(s,1,q-1);
   s:=copy(s,q+1,2555);
   q:=pos('''',s);
   if q<>0 then
   begin
    w:=pos('=',s);
    if (w<>0)and(w<q) then
    begin
     s:=copy(s,q+1,2555);
     q:=pos('''',s);
     if q<>0 then
     begin
      s2:=copy(s,1,q-1);
      if (numconv mod 128=0) then
      begin
       setlength(conv,numconv+128);
      end;

      q:=pos('^',s1);
      while q>0 do
      begin
       s1:=copy(s1,1,q-1)+''''{+''''}+copy(s1,q+1);
       q:=pos('^',s1);
      end;
      q:=pos('^',s2);
      while q>0 do
      begin
       s2:=copy(s2,1,q-1)+''''{+''''}+copy(s2,q+1);
       q:=pos('^',s2);
      end;
      conv[numconv].def:=s1;
      conv[numconv].new:=s2;
      if unicode then begin
       conv[numconv].defW:=DecodeUTF8(s1);
       conv[numconv].newW:=DecodeUTF8(s2);
      end else begin
       conv[numconv].defW:=s1;
       conv[numconv].newW:=s2;
      end;
      conv[numconv].age:=curage;
      checknew(numconv);
      inc(numconv);
     end
    end else
    begin
     w:=pos('->',s);
     if (w<>0)and(w<q) then
     begin
      s:=copy(s,q+1,2555);
      q:=pos('''',s);
      if q<>0 then
      begin
       s2:=copy(s,1,q-1);
       if (numreplaceconv mod 32=0) then
       begin
        setlength(replaceconv,numreplaceconv+32);
       end;

       q:=pos('^',s1);
       while q>0 do
       begin
        s1:=copy(s1,1,q-1)+''''{+''''}+copy(s1,q+1);
        q:=pos('^',s1);
       end;
       s1:={' '+}s1;
       s2:={' '+}s2;
       replaceconv[numreplaceconv].def:=s1;
       replaceconv[numreplaceconv].new:=s2;
       if unicode then begin
        replaceconv[numreplaceconv].defW:=DecodeUTF8(s1);
        replaceconv[numreplaceconv].newW:=DecodeUTF8(s2);
       end else begin
        replaceconv[numreplaceconv].defW:=s1;
        replaceconv[numreplaceconv].newW:=s2;
       end;
       replaceconv[numreplaceconv].age:=curage;
       inc(numreplaceconv);
      end;
     end;
    end;
   end;
  end;
 end;
end;


procedure DictInit(fname:UTF8String='';fname2:UTF8String='');
var f:text;
    s:UTF8String;
    q,w,e:integer;
begin
 LogMessage('DictInit: '+fname);
 sorttime:=getcurtime;
 languageID:=0;
 langCreatedBy:='';
 langBaseDir:='';
 langFileName:='';
 numconv:=0;
 unicode:=false;
 curage:=0;
 if fname='' then fname:='language.dic';
 if fileexists(fname) then
 begin
  langFileName:=ExtractFileName(fname);
  assign(f,fname);
  reset(f);
  while not eof(f) do
  begin
   readln(f,s);
   processstring(s);
  end;
  close(f);
 end;
 if fileexists(fname2) then
 begin
  assign(f,fname2);
  reset(f);
  while not eof(f) do
  begin
   readln(f,s);
   processstring(s);
  end;
  close(f);
 end;
 for q:=numconv-1 downto 1 do
 begin
  tcv:=conv[0];
  conv[0]:=conv[q];
  conv[q]:=tcv;
  curconv:=q;
  checkold(0);
 end;
 q:=0;
 w:=0;
 while q<numconv do
 begin
  e:=q;
  if (q+1<numconv)and(conv[q].def=conv[q+1].def)and(conv[q].age<conv[q+1].age) then inc(q);
  if (q-1>0)and(conv[q].def=conv[q-1].def)and(conv[q].age<conv[q-1].age) then inc(q);
  if e=q then
  begin
   if q<>w then
   conv[w]:=conv[q];
   inc(q);
   inc(w);
  end;
 end;
 numconv:=w;
 sorttime:=getcurtime-sorttime;
 if langBaseDir='' then langBaseDir:=langCode;
end;

function SimpleTranslate(s:UTF8String):UTF8String;
var s1,s2:UTF8String;
    q:integer;

function subtranslate(s:UTF8String):UTF8String;
var q,cur,min,max:integer;
begin
 if numconv>0 then
 begin
  min:=0;
  max:=numconv-1;
  while min<=max do
  begin
   cur:=(min+max) div 2;
   if s=conv[cur].def then
   begin
    result:=conv[cur].new;
    translated:=true;
    exit;
   end;
   if s>conv[cur].def then
    min:=cur+1
   else
    max:=cur-1;
  end;
 end;
 result:=s;
 q:=pos('`',s);
 if q>0 then
 begin
  result:=copy(s,1,q-1);
  while (q<length(s))and(s[q]<>' ')and(s[q]<>',')and(s[q]<>'.')and(s[q]<>'!')and(s[q]<>':')and(s[q]<>'(')and(s[q]<>')') do
   inc(q);
  if q<length(s) then
   result:=result+copy(s,q,50000);
 end;
end;

begin
 q:=pos('^',s);
 if q>0 then
 begin
  s1:=copy(s,1,q-1);
  s2:=copy(s,q+1,2555);
  result:=subtranslate(s1)+simpletranslate(s2);
 end else
  result:=subtranslate(s);
end;

function SimpleTranslateW(s:widestring):widestring;
var s1,s2:widestring;
    q:integer;

function subtranslate(s:widestring):widestring;
var q,cur,min,max:integer;
begin
 if numconv>0 then
 begin
  min:=0;
  max:=numconv-1;
  while min<=max do
  begin
   cur:=(min+max) div 2;
   if s=conv[cur].defW then
   begin
    result:=conv[cur].newW;
    translated:=true;
    exit;
   end;
   if s>conv[cur].defW then
    min:=cur+1
   else
    max:=cur-1;
  end;
 end;
 result:=s;
 q:=pos('`',s);
 if q>0 then
 begin                                                           
  result:=copy(s,1,q-1);
  while (q<length(s))and(s[q]<>' ')and(s[q]<>',')and(s[q]<>'.')and(s[q]<>'!')and(s[q]<>':')and(s[q]<>'(')and(s[q]<>')') do
   inc(q);
  if q<length(s) then
   result:=result+copy(s,q,50000);
 end;
end;

begin
 q:=pos('^',s);
 if q>0 then
 begin
  s1:=copy(s,1,q-1);
  s2:=copy(s,q+1,2555);
  result:=subtranslate(s1)+simpletranslateW(s2);
 end else
  result:=subtranslate(s);
//  result:=s;
end;

function Simplify(s:UTF8String):UTF8String;
begin
 while (length(s)>0)and(s[1]='^') do
  s:=copy(s,2,16384);
 while (length(s)>0)and(s[length(s)]='^') do
  s:=copy(s,1,length(s)-1);
 result:=s;
end;

function Simplify(s:widestring):widestring;
begin
 while (length(s)>0)and(s[1]='^') do
  s:=copy(s,2,16384);
 while (length(s)>0)and(s[length(s)]='^') do
  s:=copy(s,1,length(s)-1);
 result:=s;
end;


function Translate(s:UTF8String):UTF8String;
var ss:array[0..5] of UTF8String;
    q,w:integer;

begin
// logmessage('translate: '+s);
 for q:=0 to 5 do ss[q]:='';
 w:=0;
 s:=s+'%%';
 q:=pos('%%',s);
 while q>0 do
 begin
  ss[w]:=Simplify(copy(s,1,q-1));
  inc(w);
  s:=copy(s,q+2,16384);
  q:=pos('%%',s);
 end;
 s:=simpletranslate(ss[0]);
 for q:=1 to 5 do
 begin
  w:=pos('%'+inttostr(q),s);
  if w>0 then
  begin
   ss[0]:=copy(s,w+2,16384);
   if (length(ss[0])>1)and(ss[0,1]='`')and(ss[0,2] in ['1'..'9']) then
   begin
    ss[q]:=ss[q]+copy(ss[0],1,2);
    ss[0]:=copy(ss[0],3,16384);
   end;
   s:=copy(s,1,w-1)+simpletranslate(ss[q])+ss[0];
  end;
 end;

 for q:=0 to numreplaceconv-1 do
 begin
  w:=pos(replaceconv[q].def,s);
  if (w>0)and((w=1)or(s[w-1]=' ')or(s[w-1]='.')or(s[w-1]=',')) then
   s:=copy(s,1,w-1)+replaceconv[q].new+copy(s,w+length(replaceconv[q].def),16384);
 end;
 result:=s;
end;

function Translate(s:widestring):widestring; overload;
var ss:array[0..5] of widestring;
    q,w:integer;
begin
// logmessage('translate: '+s);
 for q:=0 to 5 do ss[q]:='';
 w:=0;
 q:=length(s);
 if (q>0)and(s[q]='%') then
  s:=s+' ';
 s:=s+'%%';
 q:=pos(WideString('%%'),s);
 while q>0 do
 begin
  ss[w]:=Simplify(copy(s,1,q-1));
  inc(w);
  s:=copy(s,q+2,16384);
  q:=pos(WideString('%%'),s);
 end;
 s:=simpletranslateW(ss[0]);
 for q:=1 to 5 do
 begin
  w:=pos(WideString('%'+inttostr(q)),s);
  if w>0 then
  begin
   ss[0]:=copy(s,w+2,16384);
   if (length(ss[0])>1)and(ss[0,1]='`')and(ss[0,2] in ['1'..'9']) then
   begin
    ss[q]:=ss[q]+copy(ss[0],1,2);
    ss[0]:=copy(ss[0],3,16384);
   end;
   s:=copy(s,1,w-1)+simpletranslateW(ss[q])+ss[0];
  end;
 end;
 for q:=0 to numreplaceconv-1 do
 begin
  w:=pos(replaceconv[q].defW,s);
  if (w>0)and((w=1)or(s[w-1]=' ')or(s[w-1]='.')or(s[w-1]=',')) then
   s:=copy(s,1,w-1)+replaceconv[q].newW+copy(s,w+length(replaceconv[q].defW),16384);
 end;
 result:=s;
end;

function Tr(s:UTF8String):UTF8String;
begin
// result:=Translate('^'+s+'^');
 result:=Translate(s);
end;

function Decode(s:UTF8String):UTF8String;
var
 wst:WideString;
begin
 if unicode then begin
  wst:=DecodeUTF8(s);
  result:=wst;
 end else
  result:=s;
end;

initialization
end.
