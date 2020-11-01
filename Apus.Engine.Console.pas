{ Консоль представляет собой центр обработки текстовых сообщений, которые
  могут генерироваться различными частями игры. Это могут быть отладочные
  сообщения в лог, команды, сообщения для визуальной отладки и т.д. Консоль
  не интерпретирует сообщения, а лишь решает что с ними делать и куда направлять.
  Консоль может:
  - записывать сообщения в лог-файл
  - выводить сообщения в консольное окно (если оно есть!)
  - сохранять сообщения в своем буфере (откуда их потом можно читать)
  - реагировать на отладочные сигналы и воспринимать их как сообщения
}

// Copyright (C) 2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.Console;
interface
 uses Apus.MyServis;

 var
  SaveMessages:boolean=false;        // Сохранять сообщения во внутренней структуре
  LogMessages:boolean=true;          // Записывать в лог-файл (sysUtils)
  WriteMessages:boolean=false;       // Выводить в обычное окно консоли
  ShowMessages:boolean=false;        // Выводить messagebox с критическими сообщениями
  HandleDebugSignals:boolean=true;   // Перехватывать отладочные сигналы
  HandleErrorSignals:boolean=true;   // Перехватывать сигналы об ошибках

 // logfile='' - не создавать лог-файл, иначе создавать
 procedure SetupConsole(saveMsg,writeMsg,showCritMsg,handleDebug,handleError:boolean;logFile:string);
 // Писать в консоль сигналы указанного типа
 procedure SignalsToConsole(eventClass:string;critical:boolean=false);

 // Поместить сообщение
 procedure PutMsg(st:string;critical:boolean=false;cls:integer=0);
 // Поместить критическое сообщение (просто более яркое название)
 procedure CritMsg(st:string;cls:integer=-1);

 // Номер последнего сохраненного сообщения
 function GetLastMsgNum:integer;
 // Кол-во сохраненных сообщений
 function GetMsgCount:integer;
 // ПОлучить сохраненное сообщение по его номеру
 function GetSavedMsg(msgnum:integer;var cls:integer):string;

implementation
 uses SysUtils, Apus.EventMan;
 var
  crSect:TMyCriticalSection; // используется для доступа к глобальным переменным

  lastMsgNum,msgCount:integer;

  // очередь сохраняемых сообщений (если 256 - будет мало, сделаем больше ;)
  queue:array[0..511] of string;
  clsqueue:array[0..511] of integer;
  firstUsed,firstFree:integer;

 function GetLastMsgNum:integer;
  begin
   result:=LastMsgNum;
  end;
 function GetMsgCount:integer;
  begin
   result:=msgCount;
  end;
 function GetSavedMsg(msgnum:integer;var cls:integer):string;
  begin
   if (msgnum>lastMsgNum) or (msgnum<=lastMsgNum-MsgCount) then begin
    result:=''; exit;
   end;
   result:=queue[(FirstFree-(LastMsgNum-msgnum+1)) and 511];
   cls:=clsqueue[(FirstFree-(LastMsgNum-msgnum+1)) and 511];
  end;

 procedure SaveMsg(st:string;cls:integer);
  begin
   if length(st)>255 then exit;
   inc(LastMsgNum);
   if MsgCount=512 then
    FirstUsed:=(firstUsed+1) and 511
   else inc(MsgCount);
   queue[FirstFree]:=st;
   clsqueue[FirstFree]:=cls;
   FirstFree:=(firstFree+1) and 511;
  end;

 procedure SetupConsole(saveMsg,writeMsg,showCritMsg,handleDebug,handleError:boolean;logFile:string);
  begin
   SaveMessages:=saveMsg;
   if logfile<>'' then begin
    logMessages:=true;
//    UseLogFile(logfile);
   end;
   WriteMessages:=writeMsg;
   ShowMessages:=showCritMsg;
   HandleDebugSignals:=handleDebug;
   HandleErrorSignals:=handleError;
  end;

 procedure NormalEvent(event:eventstr;tag:integer);
  begin
   if handleDebugSignals then
    PutMsg(timestamp+' Evt: '+event+' - '+inttostr(tag));
  end;
 procedure CriticalEvent(event:eventstr;tag:integer);
  begin
   if handleErrorSignals then
    PutMsg(timestamp+' Evt: '+event+' - '+inttostr(tag),true,-1);
  end;

 procedure SignalsToConsole(eventClass:string;critical:boolean=false);
  begin
   if critical then
    SetEventHandler(eventClass,@CriticalEvent)
   else
    SetEventHandler(eventClass,@NormalEvent)
  end;

 procedure PutMsg(st:string;critical:boolean=false;cls:integer=0);
  var
   st2,st1:string;
  begin
   EnterCriticalSection(crSect);
   try
    st1:=st;
    if SaveMessages then begin
     while pos(#10,st)>0 do begin
      st2:=copy(st,1,pos(#10,st)-1);
      if st2[length(st2)]<' ' then setLength(st2,length(st2)-1);
      delete(st,1,pos(#10,st));
      SaveMsg(st2,cls);
     end;
     SaveMsg(st,cls);
    end;
    if LogMessages then
     if critical then
      ForceLogMessage(st1)
     else
      LogMessage(st1);
    if WriteMessages then
     writeln(st1);
    if critical and ShowMessages then
     ErrorMessage(st1);
   finally
    LeaveCriticalSection(crSect);
   end;
  end;

 procedure CritMsg(st:string;cls:integer=-1);
  begin
   PutMsg(st,true,cls);
   ErrorMessage(st);
  end;

initialization
 InitCritSect(crSect,'Console');
// InitializeCriticalSection(crSect);
 SetEventHandler('DEBUG',@NormalEvent);
 SetEventHandler('ERROR',@CriticalEvent);
finalization
 DeleteCritSect(crSect);
end.
