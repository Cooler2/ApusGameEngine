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
 uses Apus.Core;
 type
  TConsoleSettings=record
   saveMessages:boolean;          // Сохранять сообщения во внутренней структуре
   logMessages:boolean;           // Записывать в лог-файл (sysUtils)
   writeMessages:boolean;         // Выводить в обычное окно консоли
   popupCriticalMessages:boolean; // Выводить messagebox с критическими сообщениями
   handleDebugSignals:boolean;    // Перехватывать отладочные сигналы
   handleErrorSignals:boolean;    // Перехватывать сигналы об ошибках
  end;
 var
  consoleSettings:TConsoleSettings=
    (saveMessages:false;
     logMessages:true;
     writeMessages:false;
     popupCriticalMessages:false;
     handleDebugSignals:true;
     handleErrorSignals:true);

 // logfile='' - не создавать лог-файл, иначе создавать
 procedure SetupConsole(saveMsg,writeMsg,showCritMsg,handleDebug,handleError:boolean;logFile:string8);
 // Писать в консоль сигналы указанного типа
 procedure SignalsToConsole(eventClass:string8;critical:boolean=false);

 // Поместить сообщение
 procedure PutMsg(st:string8;critical:boolean=false;cls:integer=0);
 // Поместить критическое сообщение (просто более яркое название)
 procedure CritMsg(st:string8;cls:integer=-1);

 // Index of the last saved message
 function GetLastMsgNum:integer;
 // Number of saved messages
 function GetMsgCount:integer;
 // Get a saved message by its index
 function GetSavedMsg(msgnum:integer;var cls:integer):string8;

implementation
 uses SysUtils, Apus.Lib, Apus.EventMan;

 var
  crSect:TLock; // protects shared console state

  lastMsgNum,msgCount:integer;

  // Saved message ring buffer
  queue:array[0..511] of string8;
  clsqueue:array[0..511] of integer;
  firstUsed,firstFree:integer;

 function GetLastMsgNum:integer;
  begin
   crSect.Enter;
   try
    result:=LastMsgNum;
   finally
    crSect.Leave;
   end;
  end;
 function GetMsgCount:integer;
  begin
   crSect.Enter;
   try
    result:=msgCount;
   finally
    crSect.Leave;
   end;
  end;
 function GetSavedMsg(msgnum:integer;var cls:integer):string8;
  begin
   crSect.Enter;
   try
    if (msgnum>lastMsgNum) or (msgnum<=lastMsgNum-MsgCount) then begin
     result:='';
     exit;
    end;
    result:=queue[(FirstFree-(LastMsgNum-msgnum+1)) and 511];
    cls:=clsqueue[(FirstFree-(LastMsgNum-msgnum+1)) and 511];
   finally
    crSect.Leave;
   end;
  end;

 procedure SaveMsg(st:string8;cls:integer);
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

 procedure SetupConsole(saveMsg,writeMsg,showCritMsg,handleDebug,handleError:boolean;logFile:string8);
  begin
   with consoleSettings do begin
    saveMessages:=saveMsg;
    if logfile<>'' then begin
     logMessages:=true;
 //    Logger.UseLogFile(logfile);
    end;
    WriteMessages:=writeMsg;
    popupCriticalMessages:=showCritMsg;
    HandleDebugSignals:=handleDebug;
    HandleErrorSignals:=handleError;
   end;
  end;

 procedure NormalEvent(event:TEventStr;tag:TTag);
  begin
   if consoleSettings.handleDebugSignals then
    PutMsg(CoreTime.Stamp+' Evt: '+event+' - '+inttostr(tag));
  end;

 procedure CriticalEvent(event:TEventStr;tag:TTag);
  begin
   if consoleSettings.handleErrorSignals then
    PutMsg(CoreTime.Stamp+' Evt: '+event+' - '+inttostr(tag),true,-1);
  end;

 procedure SignalsToConsole(eventClass:string8;critical:boolean=false);
  begin
   if critical then
    SetEventHandler(eventClass,@CriticalEvent)
   else
    SetEventHandler(eventClass,@NormalEvent)
  end;

  procedure PutMsg(st:string8;critical:boolean=false;cls:integer=0);
  var
   st1,st2:string8;
  begin
   crSect.Enter;
   try
    st1:=st;
    if consoleSettings.saveMessages then begin
     while pos(#10,st)>0 do begin
      st2:=copy(st,1,pos(#10,st)-1);
      if (length(st2)>0) and (st2[length(st2)]<' ') then
       setLength(st2,length(st2)-1);
      delete(st,1,pos(#10,st));
      SaveMsg(st2,cls);
     end;
     SaveMsg(st,cls);
    end;
    if consoleSettings.LogMessages then
     if critical then
      Log.Force(st1)
     else
      Log.Msg(st1);
    if consoleSettings.writeMessages then
     writeln(st1);
    if critical and consoleSettings.popupCriticalMessages then
     SystemMessage(st1);
   finally
    crSect.Leave;
   end;
  end;

 procedure CritMsg(st:string8;cls:integer=-1);
  begin
   PutMsg(st,true,cls);
  end;

initialization
 crSect.Init('Console');
// InitializeCriticalSection(crSect);
 SetEventHandler('DEBUG',@NormalEvent);
 SetEventHandler('ERROR',@CriticalEvent);
finalization
 crSect.Cleanup;
end.
