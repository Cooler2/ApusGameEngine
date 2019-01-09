// Public variables
// Copyright (C) 2014 Apus Software. Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
unit publics;
interface
 uses MyServis;
 type
  // Такой класс обслуживает все переменные одного конкретного типа
  // (один тип переменной не обязательно соответствует одному типу языка)
  TVarClass=class of TVarType;
  TVarClassStruct=class of TVarTypeStruct;
  // Простой тип данных (обычная переменная какого-либо типа)
  TVarType=class
{   class var
    IsStruct:boolean; // индикатор структурного типа (такой тип содержит поля и должен
                      // реализовывать метод GetField}
   // Запись значения (из строки) в переменную
   class procedure SetValue(variable:pointer;v:string); virtual; abstract;
   // Чтение значения переменной в виде строки
   class function GetValue(variable:pointer):string; virtual;
  end;

  // Перечисляемый тип - принимает одно из нескольких возможных значений
  TVarTypeEnum=class(TVarType)
   // возвращает список возможных значений (через запятую)
   class function ListValues:string; virtual;
  end;

  // Структурный тип данных - содержит поля
  TVarTypeStruct=class(TVarType)
   // Чтение значения переменной в виде строки
   class function GetValue(variable:pointer):string; override;
   // Следующие методы - только для структурированных типов (IsStruct=true)
   // Проверка наличия поля с заданным именем (возвращает класс типа и адрес собственно значения)
   class function GetField(variable:pointer;fieldName:string;out varClass:TVarClass):pointer; virtual;
   // Возвращает список всех полей (через запятую)
   class function ListFields:String; virtual;
  end;

  TVarTypeInteger=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeCardinal=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeSingle=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeBool=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeString=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeWideString=class(TVarType)
   class procedure SetValue(variable:pointer;v:string); override;
   class function GetValue(variable:pointer):string; override;
  end;

  TVarTypeARGB=class(TVarTypeCardinal)
  end;

  TVarTypeRect=class(TVarTypeStruct)
   class function GetField(variable:pointer;fieldName:string;out varClass:TVarClass):pointer; override;
   class function ListFields:String; override;
  end;

  TVarFunc=function(name:string):double; // ф-ция для получения значения переменной по имени (для Eval)
  TFunction=function(params:string;tag:integer;context:pointer;contextClass:TVarClassStruct):double; // произвольная ф-ция (context is passed for use in Eval)

  // Опубликованная переменная
  TPublishedVariable=record
   addr:pointer;         // pointer to variable (nil - empty)
   name,lowname:string;  // variable name (original and lowercase)
   varClass:TVarClass;   // type class reference
   next:integer;         // index of the next variable with the same hash value, or next free item
  end;

  // Опубликованная константа
  TPublishedConstant=record
   name,lowname,value:string;
  end;

 var
  // global array of publically available variables
  publicVars:array of TPublishedVariable;
  publicConsts:array of TPublishedConstant; // Sorted by name!

 // Main routines
 procedure PublishVar(variable:pointer;name:string;vtype:TVarClass);
 procedure UnpublishVar(variable:pointer); // нужно при удалении объектов
 procedure PublishConst(name:string;value:string);
 procedure UnpublishConst(name:string);
 procedure PublishFunction(name:string;f:TFunction;tag:integer=0); // например f=sin(x): PublishFunction('sin',f);
 function FindVar(name:string;out varClass:TVarClass;context:pointer=nil;contextClass:TVarClassStruct=nil):pointer;
 function FindConstValue(name:string):string;
 // Get index of a published constant (in publicConsts)
 function FindConst(name:string):integer;

 // Вычисляет значение выражения (выражение состоит из арифметических операций, скобок, констант и переменных)
 // VarFunc используется для получения значений переменных, если nil - используется механизм опубликованных переменных
 function Eval(expression:string;VarFunc:TVarFunc=nil;context:pointer=nil;contextClass:TVarClassStruct=nil):double;

 // OVERRIDABLE GLOBAL VARIABLES
 // ----------------------------
 var
  // Global variables for tweaking
  gF0,gF1,gF2,gF3,gF4,gF5,gF6,gF7:single;
  gI0,gI1,gI2,gI3:integer;
  gC0,gC1,gC2,gC3:cardinal;

 // Присваивает значения глобальным переменным.
 // Команда имеет вид: "gF3=3.14; gI1=1;gC2=$FF807060; gi0(0..2)=2"
 // Такая команда называется контекстом
 procedure SetGlobals(cmd:string;contextName:string);

 // List of global contexts
 function GetGlobalContexts(out lastContextIndex:integer):StringArr;

 // Override a variable for given context
 procedure OverrideGlobal(varName:string;const value;forContext:string);

 // Get overridden value of a variable (in string representation, '' if not overridden)
 function GetOverriddenValue(varName:string;forContext:string):string;

implementation
 uses SysUtils,Math,types;
 type
  TPublicFunction=record
   name:string;
   f:TFunction;
   tag:integer; // allows to use one generalized implementation for multiple functions 
  end;

  TGlobalOverride=record
   case integer of
    1:(IntValue:integer);
    2:(FloatValue:single);
    3:(DWordValue:cardinal);
  end;

  TGlobalContext=record
   name,defaultCmd:string;
   ovrMask:cardinal;
   ovrValues:array[0..15] of TGlobalOverride;
  end;
  
 var
  crSection:TMyCriticalSection; // используется для доступа к глобальным переменным

  publicVarHash:array[0..63] of integer;
  lastFreeItem:integer; // индекс последней "дырки" (-1 - нет)
  functions:array of TPublicFunction; // список поддерживается в отсортированном виде!

  // Контексты (наборы дефолтных присваиваний)
  globalContexts:array[0..5] of TGlobalContext;
  globalContextsCount:integer;
  lastContextIdx:integer;

 function ValidIdentifier(name:string):boolean;
  var
   i:integer;
  begin
   if name='' then begin
    result:=false; exit;
   end;
   if name[1] in ['0'..'9'] then begin
    result:=false; exit;
   end;
   result:=true;
   for i:=1 to length(name) do
    if not (name[i] in ['A'..'Z','a'..'z','0'..'9','_','\']) then begin
     result:=false; exit;
    end;
  end;

 // Проверяет, является ли выражение - вызовом ф-ции, и если да - возвращает ф-цию и изменяет аргумент на аргумент ф-ции
 // Если нет - возвращает nil, аргумент не меняет
 function IsFunction(var expression:string;out tag:integer):TFunction;
  var
   name:string;
   i,j,k,p:integer;
  begin
   result:=nil;
   if expression[length(expression)]<>')' then exit;
   p:=pos('(',expression);
   if p=0 then exit;
   name:=lowercase(copy(expression,1,p-1));
   for i:=0 to high(functions) do
    if functions[i].name=name then begin
     result:=functions[i].f;
     tag:=functions[i].tag;
     expression:=copy(expression,p+1,length(expression)-p-1);
    end;
  end;

 function Eval(expression:string;VarFunc:TVarFunc=nil;context:pointer=nil;contextClass:TVarClassStruct=nil):double;
  var
   i,d,tag:integer;
   v1,v2:double;
   fl:boolean;
   v:pointer;
   vc:TVarClass;
   f:TFunction;
   st:string;
  begin
   expression:=chop(expression);
   if length(expression)=0 then begin
    result:=0; exit;
   end;
   // Сканирование на операции типа сравнения
   d:=0;
   for i:=length(expression) downto 2 do begin
    if expression[i]=')' then inc(d);
    if expression[i]='(' then dec(d);
    if (d=0) and (expression[i] in ['<','>','=']) then begin
     v2:=Eval(copy(expression,i+1,length(expression)),varFunc,context,contextClass);
     if (expression[i]='>') and (expression[i-1]='<') then begin
      v1:=Eval(copy(expression,1,i-2),varFunc,context,contextClass);
      result:=byte(v1<>v2);
      exit;
     end else
      v1:=Eval(copy(expression,1,i-1),varFunc,context,contextClass);
     if expression[i]='=' then result:=byte(v1=v2) else
     if expression[i]='<' then result:=byte(v1<v2) else
     if expression[i]='>' then result:=byte(v1>v2);
     exit;
    end;
   end;
   // Сканирование на операции типа сложения
   d:=0;
   for i:=length(expression) downto 2 do begin
    if expression[i]=')' then inc(d);
    if expression[i]='(' then dec(d);
    if (d=0) and (expression[i] in ['+','-']) then begin
     if (expression[i]='-') and (expression[i-1] in ['*','/']) then continue; // унарный минус, а не вычитание
     v1:=Eval(copy(expression,1,i-1),varFunc,context,contextClass);
     v2:=Eval(copy(expression,i+1,length(expression)),varFunc,context,contextClass);
     if expression[i]='+' then result:=v1+v2
       else result:=v1-v2;
     exit;
    end;
   end;
   // Сканирование на операции типа умножения
   d:=0;
   for i:=length(expression) downto 2 do begin
    if expression[i]=')' then inc(d);
    if expression[i]='(' then dec(d);
    if (d=0) and (expression[i] in ['*','/']) then begin
     v1:=Eval(copy(expression,1,i-1),varFunc,context,contextClass);
     v2:=Eval(copy(expression,i+1,length(expression)),varFunc,context,contextClass);
     if expression[i]='*' then result:=v1*v2
       else begin
        if v2<>0 then result:=v1/v2
         else result:=NaN;
       end;
     exit;
    end;
   end;
   // Раскрытие скобок
   if (expression[1]='(') and (expression[length(expression)]=')') then begin
    result:=Eval(copy(expression,2,length(expression)-2),VarFunc,context,contextClass);
    exit;
   end;
   // Константа, переменная либо функция
   if expression[1]='$' then begin
    // Hex-константа
    result:=HexToInt(expression);
    exit;
   end;
   fl:=true;
   for i:=1 to length(expression) do
    if not (expression[i] in ['-','0'..'9','.']) then begin
     fl:=false; break;
    end;
   if fl then begin
    // Числовая константа
    d:=pos('.',expression);
    if d=0 then begin
     // integer
     result:=StrToInt(expression);
    end else begin
     // ручной парсинг чтобы не иметь проблем с '.' в качестве разделителя
     v1:=StrToInt(copy(expression,1,d-1));
     v2:=0;
     for i:=length(expression) downto d+1 do
      v2:=v2/10+(byte(expression[i])-$30);
     if v1<0 then result:=v1-v2/10
      else result:=v1+v2/10;
     if (v1=0) and (expression[1]='-') then result:=-result;  
    end;
   end else begin
    // переменная или константа
    fl:=false;
    if expression[1]='-' then begin // унарный минус
     delete(expression,1,1);
     fl:=true;
    end;
    result:=NaN;
    st:=FindConstValue(expression);
    if st<>'' then result:=ParseFloat(st)
    else begin
     f:=IsFunction(expression,tag);
     if @f<>nil then begin
      result:=f(expression,tag,context,contextClass);
     end else begin
      if @varFunc<>nil then
       result:=VarFunc(expression)
      else begin
       v:=FindVar(expression,vc,context,contextClass);
       if v<>nil then begin
        if vc=TVarTypeBool then
         result:=byte(PBoolean(v^))
        else begin
         st:=vc.GetValue(v);
         if st[1]='$' then result:=StrToInt64(st)
          else result:=ParseFloat(st);
        end;
       end;
      end;
     end;
    end;
    if fl and not IsNaN(result) then result:=-result;
   end;
   if IsNAN(result) then raise EWarning.Create('Invalid expression: '+expression);
  end;

 procedure PublishFunction(name:string;f:TFunction;tag:integer=0);
  var
   i,n:integer;
  begin
   ASSERT(ValidIdentifier(name),name+'is not a valid function name!');
   ASSERT(@f<>nil);
   name:=lowercase(name);
   EnterCriticalSection(crSection);
   try
    n:=length(functions);
    SetLength(functions,n+1);
    while (n>0) and (functions[n-1].name>name) do begin
     functions[n]:=functions[n-1];
     dec(n);
    end;
    functions[n].name:=name;
    functions[n].f:=f;
    functions[n].tag:=tag;
   finally
    LeaveCriticalSection(crSection);
   end;
  end;

 function NameHash(st:string):integer; inline;
  var
   l:integer;
  begin
   l:=length(st);
   result:=(byte(st[1])+l+byte(st[l])) and 63;
  end;

 procedure PublishVar(variable:pointer;name:string;vtype:TVarClass);
  var
   n,h,l:integer;
   lowname:string;
  begin
   ASSERT(variable<>nil);
   ASSERT(ValidIdentifier(name),name+' is not a valid identifier');
   lowname:=lowercase(name);
   h:=NameHash(lowname);
   EnterCriticalSection(crSection);
   try
    if lastFreeItem>=0 then begin
     n:=lastFreeItem;
     lastFreeItem:=publicVars[n].next;
    end else begin
     n:=length(publicVars);
     SetLength(publicVars,n+1);
    end;
    publicVars[n].name:=name;
    publicVars[n].lowname:=lowname;
    publicVars[n].varClass:=vtype;
    publicVars[n].addr:=variable;
    publicVars[n].next:=publicVarHash[h];
    publicVarHash[h]:=n;    
   finally
    LeaveCriticalSection(crSection);
   end;
  end;

 procedure UnpublishVar(variable:pointer);
  var
   i,n,h,m:integer;
  begin
   EnterCriticalSection(crSection);
   try
    n:=length(publicVars)-1;
    for i:=0 to n do
     if publicVars[i].addr=variable then begin
      // удаляем элемент
      h:=NameHash(publicVars[i].lowname);
      publicVars[i].addr:=nil;
      publicVars[i].varClass:=nil;
      if publicVarHash[h]=i then // удаление из начала списка
       publicVarHash[h]:=publicVars[i].next
      else begin // удаление из середины списка
       m:=publicVarHash[h];
       while publicVars[m].next<>i do m:=publicVars[m].next;
       publicVars[m].next:=publicVars[i].next;
      end;
      publicVars[i].next:=lastFreeitem;
      lastFreeItem:=i;
      break;
     end;
   finally
    LeaveCriticalSection(crSection);
   end;
  end;

 function FindConst(name:string):integer;
  var
   a,b,c:integer;
  begin
   result:=-1;
   if length(publicConsts)=0 then exit;
   name:=lowercase(name);
   a:=0; b:=length(publicConsts)-1;
   while a<b do begin
    c:=(a+b) div 2;
    if name>publicConsts[c].lowname then a:=c+1 else b:=c;
   end;
   if name=publicConsts[b].lowname then result:=b;
  end;

 function FindConstValue(name:string):string;
  var
   i:integer;
  begin
   EnterCriticalSection(crSection);
   try
    i:=FindConst(name);
    if i>=0 then result:=publicConsts[i].value
     else result:='';
   finally
    LeaveCriticalSection(crSection);
   end;
  end;

 procedure PublishConst(name:string;value:string);
  var
   i,j,n:integer;
   lowname:string;
  begin
   ASSERT(ValidIdentifier(name),name+' is not a valid name');
   EnterCriticalSection(crSection);
   try
    j:=FindConst(name);
    if j>=0 then
     publicConsts[j].value:=value
    else begin
     lowname:=lowercase(name);
     n:=length(publicConsts);
     SetLength(publicConsts,n+1);
     while (n>0) and (publicConsts[n-1].lowname>lowname) do begin
      publicConsts[n]:=publicConsts[n-1];
      dec(n);
     end;
     publicConsts[n].name:=name;
     publicConsts[n].lowname:=lowname;
     publicConsts[n].value:=value;
    end;
   finally
    LeaveCriticalSection(crSection);
   end;
  end;

 procedure UnpublishConst(name:string);
  var
   i,n:integer;
  begin
   EnterCriticalSection(crSection);
   try
    n:=length(publicConsts)-1;
    i:=FindConst(name);
    if i<0 then exit;
    while (i<n) do begin
     publicConsts[i]:=publicConsts[i+1]; inc(i);
    end;
    SetLength(publicConsts,n);
   finally
    LeaveCriticalSection(crSection);
   end;
  end;

 // Поиск только среди глобальных переменных (имя должно быть в нижнем регистре!)
 function FindGlobal(name:string;out varClass:TVarClass):pointer;
  var
   i:integer;
  begin
   result:=nil;
   varClass:=nil;
   EnterCriticalSection(crSection);
   try
    for i:=0 to high(publicVars) do
     if publicVars[i].lowname=name then begin
      result:=publicVars[i].addr;
      varClass:=publicVars[i].varClass;
      break;
     end;
   finally
    LeaveCriticalSection(crSection);
   end;
  end;

 // Рекурсивный поиск поля заданного объекта (имя должно быть в нижнем регистре!)
 function FindField(name:string;out varClass:TVarClass;context:pointer=nil;contextClass:TVarClassStruct=nil):pointer;
  var
   p:integer;
   fieldname:string;
   obj:pointer;
   objClass:TVarClass;
  begin
   p:=pos('.',name);
   result:=nil;
   varClass:=nil;
   if p>0 then begin
    fieldname:=copy(name,p+1,length(name)-p);
    SetLength(name,p-1);
    obj:=contextClass.GetField(context,name,objClass);
    if (obj<>nil) and objClass.InheritsFrom(TVarTypeStruct) then
     result:=FindField(fieldname,varClass,obj,TVarClassStruct(objClass));
   end else begin
    result:=contextClass.GetField(context,name,varClass)
   end;
  end;

 // Универсальный поиск
 function FindVar(name:string;out varClass:TVarClass;context:pointer=nil;contextClass:TVarClassStruct=nil):pointer;
  var
   i:integer;
   p:integer;
   field:string;
   objClass:TVarClass;
   obj:pointer;
  begin
   result:=nil;
   name:=lowercase(name);
   if context<>nil then begin
    // попытка получить поле текущего объекта
    result:=FindField(name,varClass,context,contextClass);
    if result<>nil then exit;
   end;
   p:=pos('.',name);
   if p>0 then begin // попытка получить поле указанного объекта
    field:=copy(name,p+1,length(name)-p);
    SetLength(name,p-1);
    obj:=FindGlobal(name,objClass);
    if (obj<>nil) and objClass.InheritsFrom(TVarTypeStruct) then
     result:=FindField(field,varClass,obj,TVarClassStruct(objClass));
   end else // поиск среди глобальных переменных
    result:=FindGlobal(name,varClass);
  end;

{ TVarTypeInteger }

class function TVarTypeInteger.GetValue(variable: pointer): string;
 begin
  result:=IntToStr(PInteger(variable)^);
 end;

class procedure TVarTypeInteger.SetValue(variable: pointer; v: string);
 begin
  PInteger(variable)^:=StrToInt(v);
 end;

{ TVarTypeCardinal }

class function TVarTypeCardinal.GetValue(variable: pointer): string;
 begin
  result:='$'+IntToHex(PCardinal(variable)^,8);
 end;

class procedure TVarTypeCardinal.SetValue(variable: pointer; v: string);
 begin
  PCardinal(variable)^:=StrToInt64(v);
 end;

{ TVarTypeBool }

class function TVarTypeBool.GetValue(variable: pointer): string;
begin
 if PBoolean(variable)^ then result:='true'
  else result:='false';
end;

class procedure TVarTypeBool.SetValue(variable: pointer; v: string);
begin
 v:=lowercase(v);
 if (v='on') or (v='true') or (v='1') or (v='yes') then PBoolean(variable)^:=true else
 if (v='off') or (v='false') or (v='0') or (v='no') then PBoolean(variable)^:=false else
 raise EWarning.Create(v+' is not a bool value');
end;


{ TVarTypeString }

class function TVarTypeString.GetValue(variable: pointer): string;
 begin
  result:=PString(variable)^;
 end;

class procedure TVarTypeString.SetValue(variable: pointer; v: string);
 begin
  PString(variable)^:=v;
 end;

{ TVarTypeWideString }

class function TVarTypeWideString.GetValue(variable: pointer): string;
 begin
  result:=EncodeUTF8(PWideString(variable)^);
 end;

class procedure TVarTypeWideString.SetValue(variable: pointer; v: string);
 begin
  PWideString(variable)^:=DecodeUTF8(v);
 end;


{ TVarType }

class function TVarTypeStruct.GetField(variable: pointer; fieldName: string;
  out varClass: TVarClass): pointer;
 begin
  result:=nil;
  varClass:=nil;
 end;

class function TVarTypeStruct.GetValue(variable: pointer): string;
 var
  sa:StringArr;
  i:integer;
  f:pointer;
  vc:TVarClass;
 begin
  sa:=split(',',ListFields);
  for i:=0 to length(sa)-1 do begin
   f:=GetField(variable,sa[i],vc);
   if f<>nil then
    sa[i]:=sa[i]+':'+vc.GetValue(f)
   else
    sa[i]:='<unknown>';
  end;
  result:='('+join(sa,', ')+')';
 end;

class function TVarType.GetValue(variable: pointer): string;
 begin
  result:='<unknown>';
 end;


class function TVarTypeStruct.ListFields: String;
 begin
  result:='';
 end;

var
 i:integer;

{ TVarTypeRect }

class function TVarTypeRect.GetField(variable: pointer; fieldName: string;
  out varClass: TVarClass): pointer;
begin
 varClass:=TVarTypeInteger;
 if fieldname='left' then result:=@(PRect(variable)^.left) else
 if fieldname='top' then result:=@(PRect(variable)^.top) else
 if fieldname='right' then result:=@(PRect(variable)^.right) else
 if fieldname='bottom' then result:=@(PRect(variable)^.bottom) else
 result:=nil;
end;

class function TVarTypeRect.ListFields: String;
begin
 result:='left,top,right,bottom';
end;

{ TVarTypeEnum }

class function TVarTypeEnum.ListValues: string;
begin
 result:='';
end;

{ TVarTypeSingle }

class function TVarTypeSingle.GetValue(variable: pointer): string;
begin
 result:=FloatToStr(PSingle(variable)^);
end;

class procedure TVarTypeSingle.SetValue(variable: pointer; v: string);
begin
 PSingle(variable)^:=ParseFloat(v);
end;

// Tag=1 - max, tag=2 - min
function fMinMax(params:string;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
var
 sa:StringArr;
 i:integer;
 v:double;
begin
 case tag of
  1:result:=-MaxDouble;
  2:result:=MaxDouble;
 end;
 sa:=split(',',params);   // проблема с min(3,max(2,1),3) - запятая в скобках!
 for i:=0 to length(sa)-1 do begin
  v:=Eval(sa[i],nil,context,contextClass);
  case tag of
   1:if v>result then result:=v;
   2:if v<result then result:=v;
  end;
 end;
end;

function fChoose(params:string;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
var
 sa:StringArr;
 v:double;
begin
 sa:=split(',',params); // проблема с запятыми в подфункциях
 if length(sa)<3 then raise EWarning.Create('Invalid parameters: '+params);
 v:=Eval(sa[0],nil,context,contextClass);
 if abs(v)>0.00000001 then result:=Eval(sa[1],nil,context,contextClass)
  else result:=Eval(sa[2],nil,context,contextClass);
end;

function fFunc(params:string;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
 begin
  result:=Eval(params,nil,context,contextClass);
  case tag of
   1:result:=round(result);
   2:result:=trunc(result);
   3:result:=frac(result);
   4:result:=sqr(result);
   5:result:=sqrt(result);
   6:result:=ln(result);
   11:result:=sin(result);
   12:result:=cos(result);
   13:result:=tan(result);
  end;
 end;

function FindContext(st:string):integer;
var
 i:integer;
begin
 result:=-1;
 for i:=0 to globalContextsCount-1 do begin
  if (st=globalContexts[i].defaultCmd) or
     ((st<>'') and (st=globalContexts[i].name)) or
     (st=globalContexts[i].name+': '+globalContexts[i].defaultCmd) then begin
   result:=i; exit;
  end;
 end;
end;

function ValidVarName(varName:string):integer;
begin
 result:=-1;
 if length(varName)<3 then exit;
 if not (varName[1] in ['g','G']) then exit;
 if not (varName[2] in ['f','F','i','I','c','C']) then exit;
 case varname[2] of
  'f','F':if varName[3] in ['0'..'7'] then result:=byte(varName[3])-$30;
  'i','I':if varName[3] in ['0'..'3'] then result:=8+byte(varName[3])-$30;
  'c','C':if varName[3] in ['0'..'3'] then result:=12+byte(varName[3])-$30;
 end;
end;

procedure ApplyContext(context:TGlobalContext);
var
 i,j,p:integer;
 sa:StringArr;
 name,value:string;
 vF:single;
 vI:integer;
 vC:cardinal;
begin
 try
 sa:=split(';',context.defaultCmd);
 for i:=0 to length(sa)-1 do begin
  p:=pos('=',sa[i]);
  if p=0 then continue;
  name:=chop(copy(sa[i],1,p-1));
  value:=chop(copy(sa[i],p+1,100));
  j:=ValidVarName(name);
  if j<0 then raise EWarning.Create('Invalid variable in '+sa[i]);
  // Float?
  if j in [0..7] then begin
   if context.ovrMask and (1 shl j)=0 then
    vF:=ParseFloat(value)
   else
    vF:=context.ovrValues[j].FloatValue;
   case j of
    0:gF0:=vF;
    1:gF1:=vF;
    2:gF2:=vF;
    3:gF3:=vF;
    4:gF4:=vF;
    5:gF5:=vF;                                                                            
    6:gF6:=vF;
    7:gF7:=vF;
   end;
   continue;
  end;
  // Integer
  if j in [8..11] then begin
   if context.ovrMask and (1 shl j)=0 then vI:=StrToInt(value)
    else vI:=context.ovrValues[j].IntValue;
   case j of
    8:gI0:=vI;
    9:gI1:=vI;                     
    10:gI2:=vI;
    11:gI3:=vI;                   
   end;
   continue;
  end;
  // Cardinal
  if j in [12..15] then begin
   if context.ovrMask and (1 shl j)=0 then vC:=StrToInt64(value)
     else vC:=context.ovrValues[j].DWordValue;
   case j of
    12:gC0:=vC;
    13:gC1:=vC;
    14:gC2:=vC;
    15:gC3:=vC;
   end;
  end;

 end; // for
 except
  on e:exception do begin
   LogError('Error in PB.ApplyC: '+e.message+' DecSep='+DecimalSeparator);
  end;
 end;
end;

var
 lastAssignCmd:string;

procedure SetGlobals(cmd:string;contextName:string);
var
 i:integer;
 contextIdx:integer;
 context:TGlobalContext;
begin
 // Всё тот же контекст? Ничего не менять...
 if lastAssignCmd=cmd then exit;

 EnterCriticalSection(crSection);
 try
  lastAssignCmd:=cmd;
  contextIdx:=FindContext(cmd);
  if contextIdx=-1 then begin // new context
   for i:=high(globalContexts) downto 1 do
    globalContexts[i]:=globalContexts[i-1];
{   ShiftArray(globalContexts,sizeof(globalContexts),sizeof(TGlobalContext));
   fillchar(globalContexts[0],sizeof(globalContexts[0]),0); // important to clear string pointers}
   if globalContextsCount<length(globalContexts) then inc(globalContextsCount);
   globalContexts[0].name:=contextName;
   globalContexts[0].defaultCmd:=cmd;
   globalContexts[0].ovrMask:=0;
   contextIdx:=0;                           
  end;
  ApplyContext(globalContexts[contextIdx]);
  lastContextIdx:=contextIdx;
 finally
  LeaveCriticalSection(crSection);
 end;
end;

procedure OverrideGlobal(varName:string;const value;forContext:string);
var
 contextID,j:integer;
 p:pointer;
begin
 EnterCriticalSection(crSection);
 try
  j:=ValidVarName(varName);
  if j<0 then exit;
  contextID:=FindContext(forContext);
  if contextID<0 then exit;
  lastAssignCmd:='';
  with globalContexts[contextID] do begin 
   p:=@value;
   if j in [0..7] then begin               
    ovrMask:=ovrMask or (1 shl j);
    ovrValues[j].floatValue:=PSingle(p)^;
   end;
   if j in [8..11] then begin
    ovrMask:=ovrMask or (1 shl j);
    ovrValues[j].IntValue:=PInteger(p)^;
   end;
   if j in [12..15] then begin
    ovrMask:=ovrMask or (1 shl j);
    ovrValues[j].DWordValue:=PCardinal(p)^;
   end;
  end;
 finally
  LeaveCriticalSection(crSection);
 end;
end;

function GetGlobalContexts(out lastContextIndex:integer):StringArr;
var
 i:integer;
begin
 lastContextIdx:=-1;                 
 EnterCriticalSection(crSection);
 try
  SetLength(result,globalContextsCount);
  for i:=0 to globalContextsCount-1 do
   if globalContexts[i].name<>'' then
    result[i]:=globalContexts[i].name+': '+globalContexts[i].defaultCmd
   else
    result[i]:=globalContexts[i].defaultCmd;
  lastContextIndex:=lastContextIdx;
 finally
  LeaveCriticalSection(crSection);
 end;
end;

function GetOverriddenValue(varName:string;forContext:string):string;
var
 context,i:integer;
begin
 result:='';
 EnterCriticalSection(crSection);
 try
  varName:=upperCase(varName);
  context:=FindContext(forContext);
  if context<0 then exit;
  i:=ValidVarName(varName);
  if i<0 then exit;
  if globalContexts[context].ovrMask and (1 shl i)=0 then exit;
  if i in [0..7] then result:=FloatToStrF(globalContexts[context].ovrValues[i].FloatValue,ffGeneral,5,0);
  if i in [8..11] then result:=IntToStr(globalContexts[context].ovrValues[i].IntValue);
  if i in [12..15] then result:='$'+IntToHex(globalContexts[context].ovrValues[i].DWordValue,8);
 finally
  LeaveCriticalSection(crSection);
 end;
end;

initialization
 InitCritSect(crSection,'Publics',300);
{ TVarType.IsStruct:=false;
 TVarTypeInteger.IsStruct:=false;
 TVarTypeString.IsStruct:=false;
 TVarTypeRect.IsStruct:=true;}
 for i:=0 to high(publicVarHash) do
  publicVarHash[i]:=-1;
 lastFreeItem:=-1;
 PublishFunction('max',fMinMax,1);
 PublishFunction('min',fMinMax,2);
 PublishFunction('if',fChoose,1);
 PublishFunction('round',fFunc,1);
 PublishFunction('trunc',fFunc,2);
 PublishFunction('frac',fFunc,3);
 PublishFunction('sqr',fFunc,4);
 PublishFunction('sqrt',fFunc,5);
 PublishFunction('ln',fFunc,6);
 PublishFunction('sin',fFunc,11);
 PublishFunction('cos',fFunc,12);
 PublishFunction('tan',fFunc,13);
 DecimalSeparator:='.';
finalization
 DeleteCritSect(crSection);
end.
