// -----------------------------------------------------
// Apus.Engine.CmdProc — command processor.
//
// Executes text commands and command files. Supports
// extensible operator registration (prefix, postfix, infix)
// with pluggable handler functions.
//
// Copyright (C) 2004-2014 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// -----------------------------------------------------

{$R+}
unit Apus.Engine.CmdProc;
interface
 uses Apus.Core, Apus.Publics;
 type
  { Command handler. On error it raises an exception with a readable message.
    Engine3 expects a single handler per operator, so a matched handler must
    fully process the command or report a failure. }
  TCmdFunc=procedure(cmd:string8);

  // Operator placement in a command
  TOperatorPos=(opFirst,   // оператор - первое слово (символ) в строке (например 'use ')
                opLast,    // оператор - последнее слово (символ) в строке (например '?')
                opMiddle); // оператор разделяет строку на две части (например '=')

  // Representation type
  TReprType=(rtDecimal,rtHex,rtBin);

 var
  LastCmdError:string8; // error text when no handler can process the command
  curObj:pointer; // current object pointer
  curObjClass:TVarClassStruct; // current object class

 // Execute a single command line
 procedure ExecCmd(cmd:string8);
 // Execute commands from a text file (optionally echo them to console)
 procedure ExecFile(fname:string8;echo:boolean=false);

 // Register command handler
 procedure SetCmdFunc(operatorName:string8;posit:TOperatorPos;func:TCmdFunc);

 // Format integer in requested representation
 function RepresentInteger(n:integer;repr:TReprType):string8;

implementation
 uses SysUtils, Math, Apus.Lib, Apus.Strings, Apus.EventMan, Apus.Colors, Apus.Engine.Console,
  Apus.Engine.RobotAPI,
  Apus.Files,
  Apus.Log;
 type
  TExecuter=class
   oper:string8;
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
  executers:TExecuter; // registered handlers (most recently added first)

{  intVars:array of integer;
  dwordVars:array of cardinal;
  floatVars:array of single;
  boolVars:array of boolean;}

  // Conditional execution state: true means current branch is active.
  condStack:array[0..10] of boolean;
  condPos:integer;

 threadvar
  curFile:string8;
  curLine:integer;

 procedure SetCmdFunc(operatorName:string8;posit:TOperatorPos;func:TCmdFunc);
  var
   e:TExecuter;
  begin
   operatorName:=operatorName.ToUpper;
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

 // Execute one already separated command.
 procedure ExecSingleCmd(cmd:string8);
  var
   fl:boolean;
   st,location:string8;
   exe:TExecuter;
  begin
   cmd:=cmd.Trim;
   if cmd='' then exit;
   st:=cmd.ToUpper;
   if (condPos>0) and not condStack[condPos] then
    if (st<>'ENDIF') and (st<>'ELSE') then exit;
   // HELP command can be added later if needed.

   // Handle all other commands.
   LastCmdError:='';
   exe:=Executers;
   // Need to scan the whole handler chain.
   while exe<>nil do with exe do begin
    fl:=false;
    case operpos of
     opFirst:if copy(st,1,length(oper))=oper then fl:=true;
     opLast:if copy(st,length(st)-length(oper)+1,length(oper))=oper then fl:=true;
     opMiddle:if pos(oper,st)>0 then fl:=true;
    end;
    if fl then begin // handler matches the expression
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
   // Default action: evaluate the expression.
   try

    PutMsg(EvalStr(cmd,nil,curObj,curObjClass),false,41000);
{    if IsNAN(v) then PutMsg('Invalid expression - '+cmd,false,41001)
     else PutMsg(FloatToStrF(v,ffGeneral,10,0),false,41000);}
   except
    on e:exception do PutMsg('Evaluation error '+ExceptionMsg(e),false,41001)
   end;
  end;

 procedure ExecCmd(cmd:string8);
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

 procedure ExecFile(fname:string8;echo:boolean=false);
  var
   st:string8;
   sa:Strings8;
  begin
   try
    Log.Force('Run file script: '+Files.FixName(fname));
    st:=Files.LoadAsString(Files.FixName(fname));
    sa:=st.SplitLines;
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

 procedure SignalCmd(cmd:string8);
  var
   st:string8;
   sa:Strings8;
  begin
    st:=copy(cmd,8,length(cmd)-7);
    sa:=st.Split(' ','"');
    if length(sa)>1 then
     Signal(sa[0],strtoint(sa[1]))
    else
     Signal(sa[0],0);
  end;

 procedure LinkCmd(cmd:string8);
  var
   st:string8;
   sa:Strings8;
   redirect:boolean;
  begin
    redirect:=(cmd[1] in ['R','r']);
    st:=copy(cmd,pos(' ',cmd)+1,length(cmd));
    sa:=st.Split(' ','"');
    if (length(sa)=3) then begin
     if sa[2].ToLower='keep' then
      Link(sa[0],sa[1],-1,redirect)
     else
      Link(sa[0],sa[1],strtoint(sa[2]),redirect)
    end else
     Link(sa[0],sa[1],0,redirect);
  end;

 procedure UnlinkCmd(cmd:string8);
  var
   st:string8;
   sa:Strings8;
  begin
    st:=copy(cmd,8,length(cmd)-7);
    sa:=st.Split(' ','"');
    UnLink(sa[0],sa[1]);
  end;

 // Operator '='
  // Evaluate the right side and assign it to the published variable on the
  // left, converting the type when needed.
 procedure AssignCmd(cmd:string8);
  var
   sa:Strings8;
   leftVar:pointer;
   leftClass:TVarClass;
   v:double;
  begin
   sa:=cmd.Split('=','"');
   sa[0]:=sa[0].Trim;
   if (length(sa)<>2) or (length(sa[0])=0) then
    raise EWarning.Create('Syntax error: must be name=value or name=expression');
   // Resolve the left side first.
   leftVar:=FindVar(sa[0],leftClass,curObj,curObjClass);
   if leftVar=nil then raise EWarning.Create(sa[0]+' is not defined');
   // For numeric targets evaluate the expression first.
   if (leftClass.InheritsFrom(TVarTypeInteger)) or
      (leftClass.InheritsFrom(TVarTypeCardinal)) or
      (leftClass.InheritsFrom(TVarTypeSingle)) then begin
    v:=EvalFloat(sa[1],nil,curObj,curObjClass);
    if Math.IsNAN(v) then raise EWarning.Create('Invalid expression: '+sa[1]);
    if not leftClass.InheritsFrom(TVarTypeSingle) then v:=round(v);
    sa[1]:=FloatToStr(v);
   end;
   if leftClass=nil then
    raise EWarning.Create('Invalid type for '+cmd);
   leftClass.SetValue(leftVar,sa[1]);
  end;

 // Operator '?'
 procedure AskCmd(cmd:string8);
  var
   repr:TReprType;
   v:pointer;
   vc:TVarClass;
   st:string8;
  begin
   SetLength(cmd,length(cmd)-1);
   if length(cmd)=0 then
    raise EWarning.Create('Syntax error');
   cmd:=cmd.ToLower;
   if (cmd='self') and (curObj<>nil) then begin
    st:=curObjClass.GetValue(curObj);
    //st:=StringReplace(st,', ',','#13#10,[rfReplaceAll]);
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
 procedure IfCmd(cmd:string8);
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
     if condPos>=High(condStack) then
      raise EWarning.Create('Conditional nesting is too deep (max '+IntToStr(High(condStack))+')');
     inc(condPos);
     condStack[condPos]:=(v<>0);
   end;
  end;

 procedure ConstCmd(cmd:string8);
  var
   sa:Strings8;
   p:integer;
   v:double;
  begin
   p:=pos(' ',cmd);
   delete(cmd,1,p);
   sa:=cmd.Split('=');
   sa[0]:=sa[0].Trim;
   try
    v:=EvalFloat(sa[1],nil,curObj,curObjClass);
    sa[1]:=FloatToStr(v);
   finally
   end;
   PublishConst(sa[0],sa[1]);
  end;

 // operator INT, DWORD etc...
 procedure VarCmd(cmd:string8);
  var
   sa:Strings8;
   p:integer;
   t:string8;
   ptr:pointer;
   vc:TVarClass;
   int:PInteger;
   dword:PCardinal;
   float:PSingle;
   bool:PBoolean;
  begin
   p:=pos(' ',cmd);
   t:=copy(cmd,1,p-1).ToUpper;
   delete(cmd,1,p);
   sa:=cmd.Split('=');
   sa[0]:=sa[0].Trim;
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
 procedure UseCmd(cmd:string8);
  begin
   delete(cmd,1,4);
   cmd:=cmd.ToLower;
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
 procedure RunCmd(cmd:string8);
  begin
   delete(cmd,1,4);
   ExecFile(cmd);
  end;

function RepresentInteger(n:integer;repr:TReprType):string8;
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

function fColorFunc(params:string8;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
var
 sa:Strings8;
 color1,color2:cardinal;
begin
 sa:=params.Split(',');
 if length(sa)<>2 then raise EWarning.Create('Invalid parameters');
  color1:=round(EvalFloat(sa[0],nil,context,contextClass));
  color2:=round(EvalFloat(sa[1],nil,context,contextClass));
 case tag of
  1:result:=ColorAdd(color1,color2);
  2:result:=ColorSub(color1,color2);
 end;
end;

procedure EventHandler(event:TEventStr;tag:TTag);
 begin
  delete(event,1,8);
  if event.StartsWith('Exec\',true) then begin
   delete(event,1,5);
   ExecCmd(event);
  end else
  if event.StartsWith('ExecFile\',true) then begin
   delete(event,1,9);
   ExecFile(Files.FixName(event));
  end;
 end;

// --- Robot API command handler ---

function RobotCmdExec(const req:TRobotRequest; out body:String8):boolean;
var
  text:String8;
begin
  text:=req.Param('TEXT');
  if text='' then begin body:='TEXT parameter required'; exit(false) end;
  try
    ExecCmd(text);
    body:='';
    result:=true;
  except
    on e:Exception do begin
      body:=String8(e.Message);
      result:=false;
    end;
  end;
end;

initialization
 RegisterRobotCommand('cmd',@RobotCmdExec);
 SetEventHandler('CMDPROC',EventHandler,emInstant);
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
