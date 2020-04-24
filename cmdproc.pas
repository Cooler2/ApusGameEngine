{ Командный процессор - выполняет команды и командные файлы, имеет возможность
  расширения набора команд }

// Copyright (C) 2004-2014 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R+}
unit cmdproc;
interface
 uses publics;
 type
  { Процедура, исполняющая команду(ы). В случае ошибки создает исключение с текстом ошибки.
    В Engine3 не допускается несколько исполнителей одного оператора, т.е. если исполнитель
    команду не выполнил - значит все, она обломалась! }
  TCmdFunc=procedure(cmd:string);

  // Расположение оператора в команде
  TOperatorPos=(opFirst,   // оператор - первое слово (символ) в строке (например 'use ')
                opLast,    // оператор - последнее слово (символ) в строке (например '?')
                opMiddle); // оператор разделяет строку на две части (например '=')

  // Representation type
  TReprType=(rtDecimal,rtHex,rtBin);

 var
  LastCmdError:string; // текст ошибки (выводится если ни одна исполнительная ф-я не смогла выполнить команду)
  curObj:pointer; // адрес текущего объекта
  curObjClass:TVarClassStruct; // класс текущего объекта

 // Выполнить команду
 procedure ExecCmd(cmd:string);
 // Выполнить команды из текстового файла (выполнять ли эхо команд в консоль?)
 procedure ExecFile(fname:string;echo:boolean=false);

 // Установить функцию-исполнитель
 procedure SetCmdFunc(operatorName:string;posit:TOperatorPos;func:TCmdFunc);

 // представить число в заданном виде
 function RepresentInteger(n:integer;repr:TReprType):string;

implementation
 uses SysUtils,MyServis,eventman,console,math,colors;
 type
  TExecuter=class
   oper:string;
   operpos:TOperatorPos;
   operfunc:TCmdFunc;
   next:TExecuter;
  end;
  //
{  TVariableType=(vtInt,vtBool,vtStr,vtObj);
  TVariable=record
   name:string;
   address:pointer;
   vartype:TVariableType;
   cls:TPublishedClassRef;
  end;}
 var
  executers:TExecuter; // Список исполнителей (сперва самые удачливые)

{  intVars:array of integer;
  dwordVars:array of cardinal;
  floatVars:array of single;
  boolVars:array of boolean;}

  // Режим условного исполнения (true - текущая ветвь исполняется, false - пропускается)
  condStack:array[0..10] of boolean;
  condPos:integer;

 threadvar
  curFile:string;
  curLine:integer;

 procedure SetCmdFunc(operatorName:string;posit:TOperatorPos;func:TCmdFunc);
  var
   e:TExecuter;
  begin
   operatorName:=UpperCase(operatorName);
   e:=executers;
   while e<>nil do begin
    if e.oper=operatorName then raise EError.Create('Operator '+operatorName+' is already defined!');
    e:=e.next;
   end;
   e:=TExecuter.Create;
   with e do begin
    oper:=operatorName;
    operpos:=posit;
    operfunc:=func;
    next:=executers;
   end;
   executers:=e;
  end;

 // Внутренняя процедура, исполняющая одну команду
 procedure ExecSingleCmd(cmd:string);
  var
   fl:boolean;
   st,location:string;
   exe:TExecuter;
   v:double;
  begin
   cmd:=chop(cmd);
   if cmd='' then exit;
   st:=UpperCase(cmd);
   if (condPos>0) and not condStack[condPos] then
    if (st<>'ENDIF') and (st<>'ELSE') then exit;
   // Обработка команды HELP
    { может, когда-нибудь будет... }

   // Обработка прочих команд
   LastCmdError:='';
   exe:=Executers;
   // нужно пройти всю цепочку!
   while exe<>nil do with exe do begin
    fl:=false;
    case operpos of
     opFirst:if copy(st,1,length(oper))=oper then fl:=true;
     opLast:if copy(st,length(st)-length(oper)+1,length(oper))=oper then fl:=true;
     opMiddle:if pos(oper,st)>0 then fl:=true;
    end;
    if fl then begin // исполнитель соответствует выражению
     try
      exe.operfunc(cmd);
     except
      on e:Exception do begin
       if curFile<>'' then
        location:=' in '+curFile+' line '+IntToStr(curLine)
       else
        location:='';
       PutMsg('Command failed: '+cmd+location,false,41001);
       PutMsg('  reason: '+ExceptionMsg(e),false,41001);
      end;
     end;
     exit;
    end;
    exe:=exe.next;
   end;
   // Default action - evaluation
   try

    PutMsg(EvalStr(cmd,nil,curObj,curObjClass),false,41000);
{    if IsNAN(v) then PutMsg('Invalid expression - '+cmd,false,41001)
     else PutMsg(FloatToStrF(v,ffGeneral,10,0),false,41000);}
   except
    on e:exception do PutMsg('Evaluation error '+ExceptionMsg(e),false,41001)
   end;
  end;

 procedure ExecCmd(cmd:string);
  begin
   if length(cmd)=0 then exit; // empty string
   if cmd[1] in ['#',';'] then exit;   // comments
   if cmd.StartsWith('//') then exit;
   while pos(';',cmd)>0 do begin
    ExecSingleCmd(copy(cmd,1,pos(';',cmd)-1));
    delete(cmd,1,pos(';',cmd));
   end;
   ExecSingleCmd(cmd);
  end;

 procedure ExecFile(fname:string;echo:boolean=false);
  var
   st:string;
   sa:StringArr;
  begin
   try
    DebugMessage('Run file script: '+FileName(fname));
    st:=LoadFileAsString(FileName(fname));
    sa:=split(#13#10,st);
    curFile:=ExtractFileName(fname);
    curLine:=1;
    for st in sa do begin
     if echo then PutMsg(st,false,41000);
     ExecCmd(st);
     inc(curLine);
    end;
   except
    on e:exception do raise EError.Create('error executing file script '+fname+' - '+ExceptionMsg(e));
   end;
   curFile:='';
  end;

 procedure SignalCmd(cmd:string);
  var
   st:string;
   sa:StringArr;
  begin
    st:=copy(cmd,8,length(cmd)-7);
    sa:=split(' ',st,'"');
    if length(sa)>1 then
     Signal(sa[0],strtoint(sa[1]))
    else
     Signal(sa[0],0);
  end;

 procedure LinkCmd(cmd:string);
  var
   st:string;
   sa:StringArr;
   redirect:boolean;
  begin
    redirect:=(cmd[1] in ['R','r']);
    st:=copy(cmd,pos(' ',cmd)+1,length(cmd));
    sa:=split(' ',st,'"');
    if (length(sa)=3) then begin
     if lowercase(sa[2])='keep' then
      Link(sa[0],sa[1],-1,redirect)
     else
      Link(sa[0],sa[1],strtoint(sa[2]),redirect)
    end else
     Link(sa[0],sa[1],0,redirect);
  end;

 procedure UnlinkCmd(cmd:string);
  var
   st:string;
   sa:StringArr;
  begin
    st:=copy(cmd,8,length(cmd)-7);
    sa:=split(' ',st,'"');
    UnLink(sa[0],sa[1]);
  end;

 // Operator '='
 // Вычисляет правую часть и пытается присвоить её опубликованной переменной в левой части (с конверсией типа, если надо)
 procedure AssignCmd(cmd:string);
  var
   sa:StringArr;
   leftVar:pointer;
   leftClass:TVarClass;
   v:double;
  begin
   sa:=split('=',cmd,'"');
   sa[0]:=Chop(sa[0]);
   if (length(sa)<>2) or (length(sa[0])=0) then
    raise EWarning.Create('Syntax error: must be name=value or name=expression');
   // Определимся с левой частью
   leftVar:=FindVar(sa[0],leftClass,curObj,curObjClass);
   if leftVar=nil then raise EWarning.Create(sa[0]+' is not defined');
   // Если левая часть:
   // - целое число - вычислить правую и округлить
   // - действительное число - вычислить и присвоить
   // - прочее - просто присвоить
   if (leftClass.InheritsFrom(TVarTypeInteger)) or
      (leftClass.InheritsFrom(TVarTypeCardinal)) or
      (leftClass.InheritsFrom(TVarTypeSingle)) then begin
    v:=EvalFloat(sa[1],nil,curObj,curObjClass);
    if IsNAN(v) then raise EWarning.Create('Invalid expression: '+sa[1]);
    if not leftClass.InheritsFrom(TVarTypeSingle) then v:=round(v);
    sa[1]:=FloatToStr(v);
   end;
   if leftClass=nil then
    raise EWarning.Create('Invalid type for '+cmd);
   leftClass.SetValue(leftVar,sa[1]);
  end;

 // Operator '?'
 procedure AskCmd(cmd:string);
  var
   repr:TReprType;
   v:pointer;
   vc:TVarClass;
   st:string;
  begin
   SetLength(cmd,length(cmd)-1);
   if length(cmd)=0 then
    raise EWarning.Create('Syntax error');
   cmd:=LowerCase(cmd);
   if (cmd='self') and (curObj<>nil) then begin
    st:=curObjClass.GetValue(curObj);
    st:=StringReplace(st,', ',','#13#10,[rfReplaceAll]);
    PutMsg(curObjClass.ClassName+': '+st,false,41000);
    exit;
   end;
   repr:=rtDecimal;
   if cmd[1]='$' then begin repr:=rtHex; delete(cmd,1,1); end;
   if cmd[1]='%' then begin repr:=rtBin; delete(cmd,1,1); end;
   v:=FindVar(cmd,vc,curObj,curObjClass);
   if v<>nil then begin
    if vc=TVarTypeInteger then
     st:=RepresentInteger(PInteger(v)^,repr)
    else
     st:=vc.GetValue(v);
   end else
    st:='<undefined>';

   PutMsg(st,false,41000);
  end;

 // operator IF
 procedure IfCmd(cmd:string);
  var
   v:double;
  begin
   if cmd[1] in ['e','E'] then begin
    ASSERT(condPos>0);
    if cmd[2] in ['n','N'] then begin
     // ENDIF statement
     dec(condPos);
    end else begin
     // ELSE statement
     condStack[condPos]:=not condStack[condPos];
    end;
   end else begin
    // IF statement
    delete(cmd,1,3);
    v:=EvalFloat(cmd,nil,curObj,curObjClass);
    inc(condPos);
    condStack[condPos]:=(v<>0);
   end;
  end;

 procedure ConstCmd(cmd:string);
  var
   sa:StringArr;
   p:integer;
   t:string;
   v:double;
  begin
   p:=pos(' ',cmd);
   t:=UpperCase(copy(cmd,1,p-1));
   delete(cmd,1,p);
   sa:=split('=',cmd);
   sa[0]:=Chop(sa[0]);
   try
    v:=EvalFloat(sa[1],nil,curObj,curObjClass);
    sa[1]:=FloatToStr(v);
   finally
   end;
   PublishConst(sa[0],sa[1]);
  end;

 // operator INT, DWORD etc...
 procedure VarCmd(cmd:string);
  var
   sa:stringArr;
   p:integer;
   t:string;
   ptr:pointer;
   vc:TVarClass;
   int:PInteger;
   dword:PCardinal;
   float:PSingle;
   bool:PBoolean;
  begin
   p:=pos(' ',cmd);
   t:=UpperCase(copy(cmd,1,p-1));
   delete(cmd,1,p);
   sa:=split('=',cmd);
   sa[0]:=Chop(sa[0]);
   ptr:=FindVar(sa[0],vc);
   if ptr=nil then begin
    if t='INT' then begin
     new(int);
     PublishVar(int,sa[0],TVarTypeInteger);
    end else
    if t='DWORD' then begin
     new(dword);
     PublishVar(dword,sa[0],TVarTypeCardinal);
    end else
    if t='FLOAT' then begin
     new(float);
     PublishVar(float,sa[0],TVarTypeSingle);
    end else
    if t='BOOL' then begin
     new(bool);
     PublishVar(bool,sa[0],TVarTypeBool);
    end;
   end;
   if length(sa)>1 then AssignCmd(cmd);
  end;

 // operator USE
 procedure UseCmd(cmd:string);
  begin
   delete(cmd,1,4);
   cmd:=LowerCase(cmd);
   if cmd='none' then begin
    curObj:=nil; curObjClass:=nil; exit;
   end;
   curObj:=FindVar(cmd,TVarClass(curObjClass));
   if curObj=nil then raise EWarning.Create(cmd+' is not defined');
   if not curObjClass.InheritsFrom(TVarTypeStruct) then begin
    curObj:=nil; curObjClass:=nil;
    raise EWarning.Create(cmd+' is not a struct/object');
   end;
  end;

 // Operator 'RUN'
 procedure RunCmd(cmd:string);
  begin
   delete(cmd,1,4);
   ExecFile(cmd);
  end;

function RepresentInteger(n:integer;repr:TReprType):string;
 var
  i:integer;
 begin
  case repr of
   rtDecimal:result:=IntToStr(n);
   rtHex:result:=IntToHex(n,8);
   rtBin:begin
    result:='00000000 00000000 00000000 00000000';
    for i:=31 downto 0 do
     if n and (1 shl i)>0 then result[32-i+((31-i) div 8)]:='1';
   end;
  end;
 end;

function fColorFunc(params:string;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
var
 sa:StringArr;
 color1,color2:cardinal;
begin
 sa:=split(',',params);
 if length(sa)<>2 then raise EWarning.Create('Invalid parameters');
 color1:=round(EvalFloat(sa[0],nil,context,contextClass));
 color2:=round(EvalFloat(sa[0],nil,context,contextClass));
 case tag of
  1:result:=ColorAdd(color1,color2);
  2:result:=ColorSub(color1,color2);
 end;
end;

initialization
 PublishFunction('ColorAdd',fColorFunc,1);
 PublishFunction('ColorSub',fColorFunc,2);
 SetCmdFunc('SIGNAL ',opFirst,SignalCmd);
 SetCmdFunc('LINK ',opFirst,LinkCmd);
 SetCmdFunc('REDIRECT ',opFirst,LinkCmd);
 SetCmdFunc('UNLINK ',opFirst,UnlinkCmd);
 SetCmdFunc('RUN ',opFirst,RunCmd);
 SetCmdFunc('?',opLast,AskCmd);
 SetCmdFunc('=',opMiddle,AssignCmd);
 SetCmdFunc('USE ',opFirst,UseCmd);

 SetCmdFunc('CONST ',opFirst,ConstCmd); // Must me AFTER the assignment operator
 SetCmdFunc('DEFINE ',opFirst,ConstCmd); // Must me AFTER the assignment operator
 SetCmdFunc('INT ',opFirst,VarCmd); // Must me AFTER the assignment operator
 SetCmdFunc('DWORD ',opFirst,VarCmd);
 SetCmdFunc('FLOAT ',opFirst,VarCmd);
 SetCmdFunc('BOOL ',opFirst,VarCmd);
 SetCmdFunc('IF ',opFirst,IfCmd);  // Conditional operator
 SetCmdFunc('ELSE',opFirst,IfCmd);
 SetCmdFunc('ENDIF',opFirst,IfCmd);
 condPos:=0;
 condStack[0]:=true;
end.
