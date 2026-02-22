// Public variables
// Copyright (C) 2014 Apus Software. Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.Publics;
interface
 uses Apus.Core;
 type
  // Такой класс обслуживает все переменные одного конкретного типа
  // (один тип переменной не обязательно соответствует одному типу языка)
  TVarClass=class of TVarType;
  TVarClassStruct=class of TVarTypeStruct;
  // Простой тип данных (обычная переменная какого-либо типа)
  TVarType=class
   // Запись значения (из строки) в переменную
   class procedure SetValue(variable:pointer;v:String8); virtual; abstract;
   // Чтение значения переменной в виде строки
   class function GetValue(variable:pointer):String8; virtual;
  end;

  // Перечисляемый тип - принимает одно из нескольких возможных значений
  TVarTypeEnum=class(TVarType)
   // возвращает список возможных значений (через запятую)
   class function ListValues:String8; virtual;
  end;

  // Структурный тип данных - содержит поля
  TVarTypeStruct=class(TVarType)
   // Чтение значения переменной в виде строки
   class function GetValue(variable:pointer):String8; override;
   // Проверка наличия поля с заданным именем (возвращает класс типа и адрес собственно значения)
   class function GetField(variable:pointer;fieldName:String8;out varClass:TVarClass):pointer; virtual;
   // Возвращает список всех полей (через запятую)
   class function ListFields:String8; virtual;
  end;

  // List type, syntax: name[index] where index is string (may be integer)
  TVarTypeList=class(TVarType)
   // Чтение значения переменной в виде строки
   class function GetValue(variable:pointer):String8; override;
   // Проверка наличия поля с заданным именем (возвращает класс типа и адрес собственно значения)
   class function GetField(variable:pointer;index:String8;out varClass:TVarClass):pointer; virtual;
   // Returns list of indices (integer or strings, in any readable form)
   class function ListIndices:String8; virtual;
  end;

  TVarTypeInteger=class(TVarType)
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarTypeCardinal=class(TVarType)
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarTypeSingle=class(TVarType)
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarTypeBool=class(TVarType)
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarTypeString=class(TVarType)
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarTypeString8=class(TVarType)
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarTypeWideString=class(TVarType)
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarTypeARGB=class(TVarTypeCardinal)
  end;

  TVarTypeRect=class(TVarTypeStruct)
   class function GetField(variable:pointer;fieldName:String8;out varClass:TVarClass):pointer; override;
   class function ListFields:String8; override;
  end;

  TVarTypeRect2s=class(TVarTypeStruct)
   class function GetField(variable:pointer;fieldName:String8;out varClass:TVarClass):pointer; override;
   class function ListFields:String8; override;
   class procedure SetValue(variable:pointer;v:String8); override;
   class function GetValue(variable:pointer):String8; override;
  end;

  TVarFunc=function(name:String8):double; // ф-ция для получения значения переменной по имени (для Eval)
  TFunction=function(params:String8;tag:integer;context:pointer;contextClass:TVarClassStruct):double; // произвольная ф-ция (context is passed for use in Eval)

  // Опубликованная переменная
  TPublishedVariable=record
   addr:pointer;         // pointer to variable (nil - empty)
   name,lowname:String8; // variable name (original and lowercase)
   varClass:TVarClass;   // type class reference
   next:integer;         // index of the next variable with the same hash value, or next free item
  end;

  // Опубликованная константа
  TPublishedConstant=record
   name,lowname,value:String8;
  end;

 var
  // global array of publically available variables
  publicVars:array of TPublishedVariable;
  publicConsts:array of TPublishedConstant; // Sorted by name!

 // Main routines
 procedure PublishVar(variable:pointer;name:String8;vtype:TVarClass);
 procedure UnpublishVar(variable:pointer); // нужно при удалении объектов
 procedure PublishConst(name:String8;value:String8);
 procedure UnpublishConst(name:String8);
 procedure PublishFunction(name:String8;f:TFunction;tag:integer=0); // например f=sin(x): PublishFunction('sin',f);
 function FindVar(name:String8;out varClass:TVarClass;context:pointer=nil;contextClass:TVarClassStruct=nil):pointer;
 function FindConstValue(name:String8):String8;
 // Get index of a published constant (in publicConsts)
 function FindConst(name:String8):integer;

 // Вычисляет значение выражения (выражение состоит из арифметических операций, скобок, констант и переменных)
 // VarFunc используется для получения значений переменных, если nil - используется механизм опубликованных переменных
 function EvalFloat(expression:String8;VarFunc:TVarFunc=nil;context:pointer=nil;contextClass:TVarClassStruct=nil):double;

 // Get string value of a variable, constant or expression
 function EvalStr(expression:String8;VarFunc:TVarFunc=nil;context:pointer=nil;contextClass:TVarClassStruct=nil):String8;

 function IsStringExpression(expression:String8;context:pointer=nil;contextClass:TVarClassStruct=nil):boolean;

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
 procedure SetGlobals(cmd:String8;contextName:String8);

 // List of global contexts
 function GetGlobalContexts(out lastContextIndex:integer):Strings8;

 // Override a variable for given context
 procedure OverrideGlobal(varName:String8;const value;forContext:String8);

 // Get overridden value of a variable (in string representation, '' if not overridden)
 function GetOverriddenValue(varName:String8;forContext:String8):String8;

implementation
 uses SysUtils, Math, Types,
  Apus.Geom2D,
  Apus.Conv,
  Apus.Log,
  Apus.Threads,
  Apus.Strings;
 type
  TPublicFunction=record
   name:String8;
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
   name,defaultCmd:String8;
   ovrMask:cardinal;
   ovrValues:array[0..15] of TGlobalOverride;
  end;

 var
  crSection:TLock; // используется для доступа к глобальным переменным

  publicVarHash:array[0..63] of integer;
  lastFreeItem:integer; // индекс последней "дырки" (-1 - нет)
  functions:array of TPublicFunction; // список поддерживается в отсортированном виде!

  // Контексты (наборы дефолтных присваиваний)
  globalContexts:array[0..5] of TGlobalContext;
  globalContextsCount:integer;
  lastContextIdx:integer;

 function ValidIdentifier(name:String8):boolean;
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
 function IsFunction(var expression:String8;out tag:integer):TFunction;
  var
   name:String8;
   i,p:integer;
  begin
   result:=nil;
   if expression[length(expression)]<>')' then exit;
   p:=pos('(',expression);
   if p=0 then exit;
   name:=copy(expression,1,p-1).ToLower;
   for i:=0 to high(functions) do
    if functions[i].name=name then begin
     result:=functions[i].f;
     tag:=functions[i].tag;
     expression:=copy(expression,p+1,length(expression)-p-1);
    end;
  end;

 function EvalFloat(expression:String8;VarFunc:TVarFunc=nil;context:pointer=nil;contextClass:TVarClassStruct=nil):double;
  var
   i,d,tag:integer;
   v1,v2:double;
   fl:boolean;
   v:pointer;
   vc:TVarClass;
   f:TFunction;
   st,right:String8;
   oper:AnsiChar;
  begin
   expression:=expression.Trim;
   if length(expression)=0 then begin
    result:=0; exit;
   end;
   // Сканирование на операции типа сравнения
   d:=0;
   for i:=length(expression) downto 2 do begin
    if expression[i]=')' then inc(d);
    if expression[i]='(' then dec(d);
    if (d=0) and (expression[i] in ['<','>','=']) then begin
     right:=copy(expression,i+1,length(expression));
     if IsStringExpression(right) then begin
      right:=EvalStr(right);
      if (expression[i]='>') and (expression[i-1]='<') then begin
       st:=copy(expression,1,i-2);
       oper:='!';
      end else begin
       st:=copy(expression,1,i-1);
       oper:=expression[i];
      end;
      st:=EvalStr(st,varFunc,context,contextClass);
      if oper='=' then result:=byte(st=right) else
      if oper='!' then result:=byte(st<>right) else
      if oper='<' then result:=byte(st<right) else
      if oper='>' then result:=byte(st>right);
      exit;
     end else begin
      v2:=EvalFloat(right,varFunc,context,contextClass);
      if (expression[i]='>') and (expression[i-1]='<') then begin
       v1:=EvalFloat(copy(expression,1,i-2),varFunc,context,contextClass);
       result:=byte(v1<>v2);
       exit;
      end else
       v1:=EvalFloat(copy(expression,1,i-1),varFunc,context,contextClass);
      if expression[i]='=' then result:=byte(v1=v2) else
      if expression[i]='<' then result:=byte(v1<v2) else
      if expression[i]='>' then result:=byte(v1>v2);
      exit;
     end;
    end;
   end;
   // Сканирование на операции типа сложения
   d:=0;
   for i:=length(expression) downto 2 do begin
    if expression[i]=')' then inc(d);
    if expression[i]='(' then dec(d);
    if (d=0) and (expression[i] in ['+','-']) then begin
     if (expression[i]='-') and (expression[i-1] in ['*','/']) then continue; // унарный минус, а не вычитание
     v1:=EvalFloat(copy(expression,1,i-1),varFunc,context,contextClass);
     v2:=EvalFloat(copy(expression,i+1,length(expression)),varFunc,context,contextClass);
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
     v1:=EvalFloat(copy(expression,1,i-1),varFunc,context,contextClass);
     v2:=EvalFloat(copy(expression,i+1,length(expression)),varFunc,context,contextClass);
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
    result:=EvalFloat(copy(expression,2,length(expression)-2),VarFunc,context,contextClass);
    exit;
   end;
   // Константа, переменная либо функция
   if expression[1]='$' then begin
    // Hex-константа
    result:=Conv.HexToInt(expression);
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
     result:=Conv.ToInt(expression);
    end else begin
     // ручной парсинг чтобы не иметь проблем с '.' в качестве разделителя
     v1:=Conv.ToInt(copy(expression,1,d-1));
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
    if st<>'' then result:=Conv.ToFloat(st)
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
         if st.StartsWith('$') then result:=StrToInt64(st)
          else result:=Conv.ToFloat(st);
        end;
       end;
      end;
     end;
    end;
    if fl and not Math.IsNaN(result) then result:=-result;
   end;
   if Math.IsNAN(result) then raise EWarning.Create('Invalid expression: '+expression);
  end;

 function IsStringConstant(expression:String8):boolean;
  begin
   if (length(expression)>=2) and
      (expression.StartsWith('"')) and (expression.EndsWith('"')) then exit(true);
   result:=false;
  end;

 function EvalStr(expression:String8;varFunc:TVarFunc=nil;context:pointer=nil;contextClass:TVarClassStruct=nil):String8;
  var
   n:integer;
   cls:TVarClass;
   v:pointer;
  begin
   try
    if IsStringConstant(expression) then exit(copy(expression,2,length(expression)-2));
    n:=FindConst(expression);
    if n>=0 then exit(publicConsts[n].value);

    v:=FindVar(expression,cls,context,contextClass);
    if v<>nil then exit(cls.GetValue(v));

    result:=FloatToStr(EvalFloat(expression,varFunc,context,contextClass));
   except
    on e:Exception do result:='Error evaluating '+expression+': '+ExceptionMsg(e);
   end;
  end;

 function IsStringExpression(expression:String8;context:pointer=nil;contextClass:TVarClassStruct=nil):boolean;
  var
   n:integer;
   cls:TVarClass;
   v:pointer;
  begin
   result:=false;
   if IsStringConstant(expression) then exit(true);
   n:=FindConst(expression);
   if n>=0 then exit(true);

   v:=FindVar(expression,cls,context,contextClass);
   if (v<>nil) and (cls.ClassNameIs('TVarTypeString') or
    cls.ClassNameIs('TVarTypeString8') or
    cls.ClassNameIs('TVarTypeWideString'))  then exit(true);
  end;

 procedure PublishFunction(name:String8;f:TFunction;tag:integer=0);
  var
   i,n:integer;
  begin
   ASSERT(ValidIdentifier(name),name+'is not a valid function name!');
   ASSERT(@f<>nil);
   name:=name.ToLower;
   crSection.Enter;
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
    crSection.Leave;
   end;
  end;

 function NameHash(st:String8):integer; inline;
  var
   l:integer;
  begin
   l:=length(st);
   result:=(byte(st[1])+l+byte(st[l])) and 63;
  end;

 procedure PublishVar(variable:pointer;name:String8;vtype:TVarClass);
  var
   n,h,l:integer;
   lowname:String8;
  begin
   ASSERT(variable<>nil);
   ASSERT(ValidIdentifier(name),name+' is not a valid identifier');
   lowname:=name.ToLower;
   h:=NameHash(lowname);
   crSection.Enter;
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
    crSection.Leave;
   end;
  end;

 procedure UnpublishVar(variable:pointer);
  var
   i,n,h,m:integer;
  begin
   crSection.Enter;
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
    crSection.Leave;
   end;
  end;

 function FindConst(name:String8):integer;
  var
   a,b,c:integer;
  begin
   result:=-1;
   if length(publicConsts)=0 then exit;
   name:=name.ToLower;
   a:=0; b:=length(publicConsts)-1;
   while a<b do begin
    c:=(a+b) div 2;
    if name>publicConsts[c].lowname then a:=c+1 else b:=c;
   end;
   if name=publicConsts[b].lowname then result:=b;
  end;

 function FindConstValue(name:String8):String8;
  var
   i:integer;
  begin
   crSection.Enter;
   try
    i:=FindConst(name);
    if i>=0 then result:=publicConsts[i].value
     else result:='';
   finally
    crSection.Leave;
   end;
  end;

 procedure PublishConst(name:String8;value:String8);
  var
   i,j,n:integer;
   lowname:String8;
  begin
   ASSERT(ValidIdentifier(name),name+' is not a valid name');
   crSection.Enter;
   try
    j:=FindConst(name);
    if j>=0 then
     publicConsts[j].value:=value
    else begin
     lowname:=name.ToLower;
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
    crSection.Leave;
   end;
  end;

 procedure UnpublishConst(name:String8);
  var
   i,n:integer;
  begin
   crSection.Enter;
   try
    n:=length(publicConsts)-1;
    i:=FindConst(name);
    if i<0 then exit;
    while (i<n) do begin
     publicConsts[i]:=publicConsts[i+1]; inc(i);
    end;
    SetLength(publicConsts,n);
   finally
    crSection.Leave;
   end;
  end;

 // Поиск только среди глобальных переменных (имя должно быть в нижнем регистре!)
 function FindGlobal(name:String8;out varClass:TVarClass):pointer;
  var
   i:integer;
  begin
   result:=nil;
   varClass:=nil;
   crSection.Enter;
   try
    for i:=0 to high(publicVars) do
     if publicVars[i].lowname=name then begin
      result:=publicVars[i].addr;
      varClass:=publicVars[i].varClass;
      break;
     end;
   finally
    crSection.Leave;
   end;
  end;

 // Рекурсивный поиск поля заданного объекта (имя должно быть в нижнем регистре!)
 function FindField(name:String8;out varClass:TVarClass;context:pointer=nil;contextClass:TVarClassStruct=nil):pointer;
  var
   p:integer;
   fieldname:String8;
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

 function FindListElement(index:String8;out varClass:TVarClass;context:pointer=nil;contextClass:TVarClassStruct=nil):pointer;
  var
   p:integer;
   fieldname:String8;
   obj:pointer;
   objClass:TVarClass;
  begin
   {p:=pos('.',index);
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
   end;}
  end;


 // Универсальный поиск
 function FindVar(name:String8;out varClass:TVarClass;context:pointer=nil;contextClass:TVarClassStruct=nil):pointer;
  var
   i:integer;
   p,p2:integer;
   field:String8;
   objClass:TVarClass;
   obj:pointer;
  begin
   result:=nil;
   name:=name.ToLower;
   if context<>nil then begin
    // попытка получить поле текущего объекта
    result:=FindField(name,varClass,context,contextClass);
    if result<>nil then exit;
   end;
   if name.EndsWith(']') then begin // element of array?
    p:=pos('[',name);
    if p>0 then begin
     field:=copy(name,p+1,length(name)-p-1);
     SetLength(name,p-1);
     obj:=FindGlobal(name,objClass);
     if (obj<>nil) and (objClass.InheritsFrom(TVarTypeList)) then
      result:=FindField(field,varClass,context,contextClass);
    end;
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

class function TVarTypeInteger.GetValue(variable:pointer):String8;
 begin
  result:=Conv.ToStr(PInteger(variable)^);
 end;

class procedure TVarTypeInteger.SetValue(variable:pointer;v:String8);
 begin
  PInteger(variable)^:=Conv.ToInt(v);
 end;

{ TVarTypeCardinal }

class function TVarTypeCardinal.GetValue(variable:pointer):String8;
 begin
  result:='$'+IntToHex(PCardinal(variable)^,8);
 end;

class procedure TVarTypeCardinal.SetValue(variable:pointer;v:String8);
 begin
  PCardinal(variable)^:=StrToInt64(string(v));
 end;

{ TVarTypeBool }

class function TVarTypeBool.GetValue(variable:pointer):String8;
begin
 if PBoolean(variable)^ then result:='true'
  else result:='false';
end;

class procedure TVarTypeBool.SetValue(variable:pointer;v:String8);
begin
 v:=v.ToLower;
 if (v='on') or (v='true') or (v='1') or (v='yes') then PBoolean(variable)^:=true else
 if (v='off') or (v='false') or (v='0') or (v='no') then PBoolean(variable)^:=false else
 raise EWarning.Create(v+' is not a bool value');
end;


{ TVarTypeString }

class function TVarTypeString.GetValue(variable:pointer):String8;
 begin
  result:='"'+String8(PString(variable)^)+'"';
 end;

class procedure TVarTypeString.SetValue(variable:pointer;v:String8);
 begin
  PString(variable)^:=string(v);
 end;

{ TVarTypeString8 }
class function TVarTypeString8.GetValue(variable:pointer):String8;
begin
  result:=PString8(variable)^;
end;

class procedure TVarTypeString8.SetValue(variable:pointer;v:String8);
begin
  PString8(variable)^:=v;
end;


{ TVarTypeWideString }

class function TVarTypeWideString.GetValue(variable:pointer):String8;
 begin
  result:=UTF8.Encode(PWideString(variable)^);
 end;

class procedure TVarTypeWideString.SetValue(variable:pointer;v:String8);
 begin
  PWideString(variable)^:=UTF8.ToWide(v);
 end;


{ TVarType }

class function TVarTypeStruct.GetField(variable:pointer;fieldName:String8;
  out varClass:TVarClass):pointer;
 begin
  result:=nil;
  varClass:=nil;
 end;

class function TVarTypeStruct.GetValue(variable:pointer):String8;
 var
  sa:Strings8;
  i:integer;
  f:pointer;
  vc:TVarClass;
 begin
  sa:=ListFields.Split(',');
  for i:=0 to length(sa)-1 do begin
   f:=GetField(variable,sa[i],vc);
   if f<>nil then
    sa[i]:=sa[i]+':'+vc.GetValue(f)
   else
    sa[i]:='<unknown>';
  end;
  result:='('+String8.Join(sa,', ')+')';
 end;

class function TVarType.GetValue(variable:pointer):String8;
 begin
  result:='<unknown>';
 end;


class function TVarTypeStruct.ListFields:String8;
 begin
  result:='';
 end;

{ TVarTypeArray }
class function TVarTypeList.GetField(variable:pointer;index:String8;
  out varClass:TVarClass):pointer;
 begin
  result:=nil;
  varClass:=nil;
 end;

class function TVarTypeList.GetValue(variable:pointer):String8;
 begin
  result:='['+listIndices+']';
 end;

class function TVarTypeList.ListIndices:String8;
 begin
  result:='';
 end;


var
 i:integer;

{ TVarTypeRect }

class function TVarTypeRect.GetField(variable:pointer;fieldName:String8;
  out varClass:TVarClass):pointer;
begin
 varClass:=TVarTypeInteger;
 if fieldname='left' then result:=@(PRect(variable)^.left) else
 if fieldname='top' then result:=@(PRect(variable)^.top) else
 if fieldname='right' then result:=@(PRect(variable)^.right) else
 if fieldname='bottom' then result:=@(PRect(variable)^.bottom) else
 result:=nil;
end;

class function TVarTypeRect.ListFields:String8;
begin
 result:='left,top,right,bottom';
end;

{ TVarTypeRect2s }

class function TVarTypeRect2s.GetField(variable:pointer;fieldName:String8;
  out varClass:TVarClass):pointer;
begin
 varClass:=TVarTypeInteger;
 with PRect2s(variable)^ do
  if fieldname='x1' then result:=@(x1) else
  if fieldname='y1' then result:=@(y1) else
  if fieldname='x2' then result:=@(x2) else
  if fieldname='y2' then result:=@(y2) else
  result:=nil;
end;

class function TVarTypeRect2s.GetValue(variable:pointer):String8;
begin
 with PRect2s(variable)^ do
  result:=Format('(%f,%f,%f,%f)',[x1,y1,x2,y2]);
end;

class function TVarTypeRect2s.ListFields:String8;
begin
 result:='x1,y1,x2,y2';
end;

class procedure TVarTypeRect2s.SetValue(variable:pointer;v:String8);
var
 r:PRect2s;
 sa:Strings8;
begin
 r:=variable;
 if v.EqualsText('TopLeft') then r^:=Rect2s(0,0,0,0) else
 if v.EqualsText('TopRight') then r^:=Rect2s(1,0,1,0) else
 if v.EqualsText('BottomLeft') then r^:=Rect2s(0,1,0,1) else
 if v.EqualsText('BottomRight') then r^:=Rect2s(1,1,1,1) else
 if v.EqualsText('Center') then r^:=Rect2s(0.5,0.5,0.5,0.5) else
 with r^ do begin
  sa:=v.Split(',');
  if length(sa)>0 then x1:=Conv.ToFloat(sa[0]);
  if length(sa)>1 then y1:=Conv.ToFloat(sa[1]);
  if length(sa)>2 then x2:=Conv.ToFloat(sa[2]);
  if length(sa)>3 then y2:=Conv.ToFloat(sa[3]);
 end;
end;

{ TVarTypeEnum }

class function TVarTypeEnum.ListValues:String8;
begin
 result:='';
end;

{ TVarTypeSingle }

class function TVarTypeSingle.GetValue(variable:pointer):String8;
begin
 result:=FloatToStr(PSingle(variable)^);
end;

class procedure TVarTypeSingle.SetValue(variable:pointer;v:String8);
begin
 PSingle(variable)^:=Conv.ToFloat(v);
end;

// Tag=1 - max, tag=2 - min
function fMinMax(params:String8;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
var
 sa:Strings8;
 i:integer;
 v:double;
begin
 case tag of
  1:result:=-MaxDouble;
  2:result:=MaxDouble;
 end;
 sa:=params.Split(',');   // проблема с min(3,max(2,1),3) - запятая в скобках!
 for i:=0 to length(sa)-1 do begin
  v:=EvalFloat(sa[i],nil,context,contextClass);
  case tag of
   1:if v>result then result:=v;
   2:if v<result then result:=v;
  end;
 end;
end;

function fChoose(params:String8;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
var
 sa:Strings8;
 v:double;
begin
 sa:=params.Split(','); // проблема с запятыми в подфункциях
 if length(sa)<3 then raise EWarning.Create('Invalid parameters: '+params);
 v:=EvalFloat(sa[0],nil,context,contextClass);
 if abs(v)>0.00000001 then result:=EvalFloat(sa[1],nil,context,contextClass)
  else result:=EvalFloat(sa[2],nil,context,contextClass);
end;

function fFunc(params:String8;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
 begin
  result:=EvalFloat(params,nil,context,contextClass);
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

function FindContext(st:String8):integer;
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

function ValidVarName(varName:String8):integer;
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
 sa:Strings8;
 name,value:String8;
 vF:single;
 vI:integer;
 vC:cardinal;
begin
 try
 sa:=context.defaultCmd.Split(';');
 for i:=0 to length(sa)-1 do begin
  p:=pos('=',sa[i]);
  if p=0 then continue;
  name:=copy(sa[i],1,p-1).Trim;
  value:=copy(sa[i],p+1,100).Trim;
  j:=ValidVarName(name);
  if j<0 then raise EWarning.Create('Invalid variable in '+sa[i]);
  // Float?
  if j in [0..7] then begin
   if context.ovrMask and (1 shl j)=0 then
    vF:=Conv.ToFloat(value)
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
   if context.ovrMask and (1 shl j)=0 then vI:=Conv.ToInt(value)
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
   Log.Error('Error in PB.ApplyC: '+e.message+' DecSep='+{$IFDEF FPC}DefaultFormatSettings.{$ELSE}FormatSettings.{$ENDIF}DecimalSeparator);
  end;
 end;
end;

var
 lastAssignCmd:String8;

procedure SetGlobals(cmd:String8;contextName:String8);
var
 i:integer;
 contextIdx:integer;
 context:TGlobalContext;
begin
 // Всё тот же контекст? Ничего не менять...
 if lastAssignCmd=cmd then exit;

 crSection.Enter;
 try
  lastAssignCmd:=cmd;
  contextIdx:=FindContext(cmd);
  if contextIdx=-1 then begin // new context
   for i:=high(globalContexts) downto 1 do
    globalContexts[i]:=globalContexts[i-1];
{   ShiftArray(globalContexts,sizeof(globalContexts),sizeof(TGlobalContext));
   Mem.Fill(globalContexts[0],sizeof(globalContexts[0]),0); // important to clear string pointers}
   if globalContextsCount<length(globalContexts) then inc(globalContextsCount);
   globalContexts[0].name:=contextName;
   globalContexts[0].defaultCmd:=cmd;
   globalContexts[0].ovrMask:=0;
   contextIdx:=0;
  end;
  ApplyContext(globalContexts[contextIdx]);
  lastContextIdx:=contextIdx;
 finally
  crSection.Leave;
 end;
end;

procedure OverrideGlobal(varName:String8;const value;forContext:String8);
var
 contextID,j:integer;
 p:pointer;
begin
 crSection.Enter;
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
  crSection.Leave;
 end;
end;

function GetGlobalContexts(out lastContextIndex:integer):Strings8;
var
 i:integer;
begin
 lastContextIdx:=-1;
 crSection.Enter;
 try
  SetLength(result,globalContextsCount);
  for i:=0 to globalContextsCount-1 do
   if globalContexts[i].name<>'' then
    result[i]:=globalContexts[i].name+': '+globalContexts[i].defaultCmd
   else
    result[i]:=globalContexts[i].defaultCmd;
  lastContextIndex:=lastContextIdx;
 finally
  crSection.Leave;
 end;
end;

function GetOverriddenValue(varName:String8;forContext:String8):String8;
var
 context,i:integer;
begin
 result:='';
 crSection.Enter;
 try
  varName:=varName.ToUpper;
  context:=FindContext(forContext);
  if context<0 then exit;
  i:=ValidVarName(varName);
  if i<0 then exit;
  if globalContexts[context].ovrMask and (1 shl i)=0 then exit;
  if i in [0..7] then result:=FloatToStrF(globalContexts[context].ovrValues[i].FloatValue,ffGeneral,5,0);
  if i in [8..11] then result:=Conv.ToStr(globalContexts[context].ovrValues[i].IntValue);
  if i in [12..15] then result:='$'+IntToHex(globalContexts[context].ovrValues[i].DWordValue,8);
 finally
  crSection.Leave;
 end;
end;

initialization
 try
  crSection.Init('Publics',300);
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
  {$IFDEF FPC}DefaultFormatSettings.{$ELSE}FormatSettings.{$ENDIF}DecimalSeparator:='.';
 except
  on e:Exception do Log.Error('Publics: '+ExceptionMsg(e));
 end;
finalization
  crSection.Cleanup;
end.
