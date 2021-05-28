// Wrapper unit for platform-dependent functions
//
// Copyright (C) 2011 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$S-}
unit Apus.CrossPlatform;

interface
{$IFDEF MSWINDOWS}
 uses
  windows,
  SysUtils;
{$ENDIF}
{$IFDEF IOS}
 {$modeswitch ObjectiveC1}
{$ENDIF}
{$IFDEF UNIX}
 {$LINKLIB c}
 uses cthreads,types,SysUtils
  {$IFDEF IOS}, iPhoneAll{$ENDIF}
 ;
 var
  sdkVersion:integer=0;
 const
  libc = 'c';
{$ENDIF}

{$IFDEF FPC}
 type
  TSystemTimeHelper=record helper for TSystemTime
   function wDay:word;
   function wMonth:word;
   function wYear:word;
   function wHour:word;
   function wMinute:word;
   function wSecond:word;
   function wMilliSeconds:word;
  end;
{$ENDIF}


{$IFDEF MSWINDOWS}
 type
  TRect=windows.TRect;
  TPoint=windows.TPoint;
  HCursor=windows.HCURSOR;
  HWND=windows.HWND;
  {$IF not Declared(TThreadID)}
  TThreadID=cardinal;
  {$ENDIF}
  {$IF not Declared(UIntPtr)}
  UIntPtr=NativeUInt;
  {$ENDIF}
  PtrUInt=UIntPtr;
 const
  VK_SPACE=windows.VK_SPACE;
  VK_RETURN=windows.VK_RETURN;
  VK_ESCAPE=windows.VK_ESCAPE;
  VK_BACK=windows.VK_BACK;
  VK_INSERT=windows.VK_INSERT;
  VK_DELETE=windows.VK_DELETE;
  VK_UP=windows.VK_UP;
  VK_DOWN=windows.VK_DOWN;
  VK_F1=windows.VK_F1;
  VK_F2=windows.VK_F2;
  VK_F3=windows.VK_F3;
  VK_F4=windows.VK_F4;
  VK_F5=windows.VK_F5;
  VK_F6=windows.VK_F6;
  VK_F7=windows.VK_F7;
  VK_F8=windows.VK_F8;
  VK_F9=windows.VK_F9;
  VK_F10=windows.VK_F10;
  VK_F11=windows.VK_F11;
  VK_F12=windows.VK_F12;
  VK_TAB=windows.VK_TAB;
  VK_LEFT=windows.VK_LEFT;
  VK_RIGHT=windows.VK_RIGHT;
  VK_HOME=windows.VK_HOME;
  VK_END=windows.VK_END;
  VK_PAGEUP=windows.VK_PRIOR;
  VK_PAGEDOWN=windows.VK_NEXT;
  VK_SNAPSHOT=windows.VK_SNAPSHOT;
{$ELSE}
 const
  VK_SPACE=32;
  VK_RETURN=13;
  VK_ESCAPE=27;
  VK_TAB=9;
  VK_BACK=129;
  VK_INSERT=45;
  VK_DELETE=130;
  VK_UP=131;
  VK_DOWN=132;
  VK_LEFT=37;
  VK_RIGHT=39;
  VK_HOME=36;
  VK_END=35;
  VK_PAGEUP=33;
  VK_PAGEDOWN=34;
  VK_SNAPSHOT=44;
  VK_F1=112;
  VK_F2=113;
  VK_F3=114;
  VK_F4=115;
  VK_F5=116;
  VK_F6=117;
  VK_F7=118;
  VK_F8=119;
  VK_F9=120;
  VK_F10=121;
  VK_F11=122;
  VK_F12=123;

 type
  TThreadID=system.TThreadID;
  HCURSOR=cardinal;
  HWND=pointer;
  TRect=types.TRect;
  TPoint=types.TPoint;
{$ENDIF}
 const
  dummyConst = 0;
{$IF not Declared(INVALID_HANDLE_VALUE)}
  INVALID_HANDLE_VALUE = THandle(-1);
{$ENDIF}

  // Keyboard scancodes
  SCAN_ESC  = 1;
  SCAN_F1   = 59;
  SCAN_F2   = 60;
  SCAN_F3   = 61;
  SCAN_F4   = 62;
  SCAN_F5   = 63;
  SCAN_F6   = 64;
  SCAN_F7   = 65;
  SCAN_F8   = 66;
  SCAN_F9   = 67;
  SCAN_F10  = 68;
  SCAN_F11  = 87;
  SCAN_F12  = 88;
  SCAN_SPACE  = 57;
  SCAN_ENTER  = $1C;
  SCAN_LEFT   = $4B;
  SCAN_RIGHT  = $4D;
  SCAN_UP     = $48;
  SCAN_DOWN   = $50;
  SCAN_INS    = $52;
  SCAN_DEL    = $53;
  SCAN_HOME   = $47;
  SCAN_END    = $4F;
  SCAN_PAGEUP = $49;
  SCAN_PAGEDOWN =$51;
  SCAN_1 = 2;
  SCAN_2 = 3;
  SCAN_3 = 4;
  SCAN_4 = 5;
  SCAN_5 = 6;
  SCAN_6 = 7;
  SCAN_7 = 8;
  SCAN_8 = 9;
  SCAN_9 = 10;
  SCAN_0 = 11;
  SCAN_Q = 16;
  SCAN_W = 17;
  SCAN_E = 18;
  SCAN_R = 19;
  SCAN_T = 20;
  SCAN_Y = 21;
  SCAN_U = 22;
  SCAN_I = 23;
  SCAN_O = 24;
  SCAN_P = 25;
  SCAN_A = 30;
  SCAN_S = 31;
  SCAN_D = 32;
  SCAN_F = 33;
  SCAN_G = 34;
  SCAN_H = 35;
  SCAN_J = 36;
  SCAN_K = 37;
  SCAN_L = 38;
  SCAN_Z = 44;
  SCAN_X = 45;
  SCAN_C = 46;
  SCAN_V = 47;
  SCAN_B = 48;
  SCAN_N = 49;
  SCAN_M = 50;

 function GetTickCount:cardinal; inline;
 procedure QueryPerformanceCounter(out value:int64); inline;
 procedure QueryPerformanceFrequency(out value:int64);

 procedure Sleep(time:integer); inline;
 function BeginThread(ThreadFunction:TThreadFunc; p:pointer; var ThreadId:TThreadID; stackSize:integer=1024*1024):THandle; overload;
 function BeginThread(ThreadFunction:TThreadFunc):TThreadID; overload;

 function GetCurrentThreadID:TThreadId; inline;
 procedure TerminateThread(threadHandle:TThreadID;exitCode:cardinal);
 procedure ChangeThreadPriority(priority:integer); // -2..2 where 0 is Normal

 function GetSystemInfo:string;
 function GetLastErrorCode:cardinal;
 function GetLastErrorDesc:string;

 {$IFDEF IOS}
 function NSStrUTF8(st:string):NSString;
 {$ENDIF}
 procedure OpenURL(url:AnsiString);
 function LaunchProcess(fname:AnsiString;params:AnsiString=''):boolean;
 function IsDebuggerPresent:boolean; inline;

 {$IFDEF MSWINDOWS}
 function LoadCursorFromFile(fname:PChar):HCursor;
 function LoadCursor(instance:cardinal;name:PChar):HCursor;
 function GetCursor:HCursor;
 procedure SetCursor(cursor:HCursor);

 function GetWindowRect(window:HWND;out rect:TRect):boolean;
 function MoveWindow(window:HWND;x,y,w,h:integer;repaint:boolean):boolean;
 function ExecAndCapture(const ACmdLine: AnsiString; var AOutput: AnsiString): Integer;
 {$ENDIF}
 {$IFDEF UNIX}
 function ExecAndCapture(const ACmdLine: AnsiString; var AOutput: AnsiString): Integer;
 {$ENDIF}

 function GetDecimalSeparator:char; inline;
 procedure SetDecimalSeparator(c:char);

 {$IFNDEF UNICODE}
 function AnsiStrAlloc(size:integer):PAnsiChar;
 {$ENDIF}
 {$IF not DECLARED(MemoryBarrier)}
 {$DEFINE DECLARE_MEMORY_BARRIER}
 procedure MemoryBarrier; inline;
 {$ENDIF}

implementation

uses
{$IFDEF MSWINDOWS}
  ShellAPI,
{$ENDIF}
{$IFDEF UNIX}
 unixtype,BaseUnix,Process,
{$ENDIF}
{$IFDEF LINUX}
 Linux,
{$ENDIF}
  Apus.MyServis;

{$IFDEF DECLARE_MEMORY_BARRIER}
 procedure MemoryBarrier; inline; assembler;
 asm
   mfence
 end;
{$ENDIF}

 function GetLastErrorCode:cardinal;
  begin
   {$IF declared(GetLastError)}
    result:=GetLastError;
   {$ELSE}
    {$IF Declared(fpGetErrno)}
     result:=fpGetErrno;
    {$ENDIF}
   {$ENDIF}
  end;

 function GetLastErrorDesc:string;
  var
   code:cardinal;
  begin
   code:=GetLastErrorCode;
   {$IF Declared(SysErrorMessage)}
    result:=SysErrorMessage(code)+Format(' (%d)',[code]);
   {$ELSE}
    if code=0 then result:='NO ERROR'
     else result:=Format('CODE %d (%8x)',[code,code]);
   {$ENDIF}
  end;


 {$IFDEF IOS}
 // IOS threads
{ constructor TThread.Create(suspended:boolean);
  begin
   running:=false;
   id:=nil;
   terminated:=false;
   finished:=false;
   handle:=0;
   if not suspended then Resume;
  end;

 function trProc(p:pointer):pointer; cdecl;
  var
   thread:TThread;
   old:integer;
  begin
   if p=nil then exit;
   pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS,@old);
   thread:=p;
   thread.Execute;
   result:=@thread.returnValue;
   thread.finished:=true;
   thread.running:=false;
  end;

 procedure TThread.Resume;
  var
   attr:TThreadAttr;
   thread_id:TThreadID;
   rval:integer;
  begin
   if running then exit;
   pthread_attr_init(@attr);
   pthread_attr_setdetachstate(@attr,PTHREAD_CREATE_DETACHED);
   pthread_attr_setstacksize(@attr,65536);
   rval:=pthread_create(@thread_id,@attr,@trProc,self);
   if rval<>0 then raise Exception.Create('Failed to create PThread: '+inttostr(rval));
   running:=true;
   id:=thread_id;
   handle:=cardinal(id);
   pthread_attr_destroy(@attr);
  end;

 destructor TThread.Destroy;
  begin
   if running then begin
    pthread_cancel(id);
   end;
  end;

 procedure TThread.Execute;
  begin
  end;

 procedure TThread.Terminate;
  begin
   terminated:=true;
  end;    }

 procedure OpenURL(url:AnsiString);
  var
   u:NSURL;
  begin
   u:=NSURL.UrlWithString(NSSTR(PAnsiChar(url)));
   UIApplication.sharedApplication.OpenURL(u);
  end;

 function NSStrUTF8(st:string):NSString;
  begin
   if st<>'' then
    Result := NSString(CFStringCreateWithBytes(nil,@st[1],length(st),kCFStringEncodingUTF8,false))
   else
    result:=NSString(CFSTR(''));
  end;
 {$ENDIF}

 {$IFDEF UNIX}
 const
  PTRACE_TRACEME = 0;
  PTRACE_DETACH = 17;

 function ptrace(__request:integer; PID: pid_t; Address: Pointer; Data: Longint): longint; cdecl; external libc name 'ptrace';
 {$ENDIF}

 function IsDebuggerPresent:boolean;
  begin
   result:=false;
   {$IFDEF MSWINDOWS}
   result:=windows.IsDebuggerPresent;
   {$ENDIF}
   {$IFDEF UNIX}
   if (ptrace(PTRACE_TRACEME, 0, nil, 0) < 0) then
    result:=true
   else begin
    ptrace(PTRACE_DETACH, 0, nil, 0);
    result:=false;
   end;
   {$ENDIF}
  end;

 function BeginThread(threadFunction:TThreadFunc; p:pointer; var threadId:TThreadID; stackSize:integer=1024*1024):THandle;
  begin
   {$IFDEF FPC}
   result:=system.BeginThread(ThreadFunction,p,ThreadID,stackSize);
   {$ENDIF}
   {$IFDEF DELPHI}
   result:=system.BeginThread(nil,stackSize,ThreadFunction,p,
    {$IF DECLARED(STACK_SIZE_PARAM_IS_A_RESERVATION)}STACK_SIZE_PARAM_IS_A_RESERVATION{$ELSE}0{$IFEND},threadID);
   {$ENDIF}
   if result=0 then raise Exception.Create('Failed to start a thread: '+IntToHex(UInt64(@threadFunction),12));
  end;

 function BeginThread(ThreadFunction:TThreadFunc):TThreadID; overload;
  begin
   BeginThread(threadFunction,nil,result);
  end;

// WINDOWS SET ===========================
{$IFDEF MSWINDOWS}
 procedure OpenURL(url:AnsiString);
  begin
   ShellExecuteA(0,'open',PAnsiChar(url),'','',SW_SHOW);
  end;

 function GetSystemInfo:string;
  var
   info:TSystemInfo;
   ver:cardinal;
  begin
   windows.GetSystemInfo(info);
   ver:=GetVersion;
   result:=Format('CPU: type=%d level=%d rev=%d count=%d Arch=%d;  Windows: %d.%d',
    [info.dwProcessorType,info.wProcessorLevel,info.wProcessorRevision,
     info.dwNumberOfProcessors,info.wProcessorArchitecture,
     ver and $FF,(ver shr 8) and $FF]);
  end;

 function LaunchProcess(fname,params:AnsiString):boolean;
 {$IFDEF MSWINDOWS}
  var
   startupInfo:TStartupInfoA;
   processInfo:TProcessInformation;
  begin
   fillchar(startupinfo,sizeof(startupinfo),0);
   startupInfo.cb:=sizeof(startupinfo);
   result:=CreateProcessA(nil,PAnsiChar(fname+' '+params),nil,nil,false,0,nil,nil,startupInfo,processInfo);
  end;
 {$ELSE}
  begin
  end;
 {$ENDIF}

// This function taken from http://forum.codecall.net/topic/72472-execute-a-console-program-and-capture-its-output/
// Author: Luthfi
function ExecAndCapture(const ACmdLine: AnsiString; var AOutput: AnsiString): Integer;
const
  cBufferSize = 2048;
type
  TAnoPipe=record
    Input : THandle; // Handle to send data to the pipe
    Output: THandle; // Handle to read data from the pipe
  end;
var
  vBuffer: Pointer;
  vStartupInfo: TStartUpInfoA;
  vSecurityAttributes: TSecurityAttributes;
  vReadBytes: DWord;
  vProcessInfo: TProcessInformation;
  vStdInPipe : TAnoPipe;
  vStdOutPipe: TAnoPipe;
  str:AnsiString;
begin
  LogMessage('Exec: '+ACmdLine);

  with vSecurityAttributes do
  begin
    nlength := SizeOf(vSecurityAttributes);
    binherithandle := True;
    lpsecuritydescriptor := nil;
  end;

  // Create anonymous pipe for standard input
  if not CreatePipe(vStdInPipe.Output, vStdInPipe.Input, @vSecurityAttributes, 0) then
    raise Exception.Create('Failed to create pipe for standard input. System error message: ' + SysErrorMessage(GetLastError));

  try
    // Create anonymous pipe for standard output (and also for standard error)
    if not CreatePipe(vStdOutPipe.Output, vStdOutPipe.Input, @vSecurityAttributes, 0) then
      raise Exception.Create('Failed to create pipe for standard output. System error message: ' + SysErrorMessage(GetLastError));

    try
      GetMem(vBuffer, cBufferSize);
      try
        // initialize the startup info to match our purpose
        FillChar(vStartupInfo, Sizeof(vStartUpInfo), #0);
        vStartupInfo.cb         := SizeOf(vStartUpInfo);
        vStartupInfo.wShowWindow:= SW_HIDE;  // we don't want to show the process
        // assign our pipe for the process' standard input
        vStartupInfo.hStdInput  := vStdInPipe.Output;
        // assign our pipe for the process' standard output
        vStartupInfo.hStdOutput := vStdOutPipe.Input;
        vStartupInfo.dwFlags    := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;

        if not CreateProcessA(nil
                             , PAnsiChar(ACmdLine)
                             , @vSecurityAttributes
                             , @vSecurityAttributes
                             , True
                             , NORMAL_PRIORITY_CLASS
                             , nil
                             , nil
                             , vStartupInfo
                             , vProcessInfo) then
          raise Exception.Create('Failed creating the console process. System error msg: ' + SysErrorMessage(GetLastError));

        try
          // wait until the console program terminated
          while WaitForSingleObject(vProcessInfo.hProcess, 10)=WAIT_TIMEOUT do
            Sleep(0);

          // clear the output storage
          AOutput := '';
          result:=0;
          // Read text returned by the console program in its StdOut channel
          repeat
            if not PeekNamedPipe(vStdOutPipe.Output,vBuffer,cBufferSize,@vReadBytes,nil,nil) then break;
            if vReadBytes=0 then break;
            windows.ReadFile(vStdOutPipe.Output, vBuffer^, cBufferSize, vReadBytes, nil);
            if vReadBytes > 0 then
            begin
              SetLength(str,vReadBytes);
              move(vBuffer^,str[1],vReadBytes);
              AOutput := AOutput + str;
              Inc(Result, vReadBytes);
            end;
          until (vReadBytes < cBufferSize);
        finally
          FileClose(vProcessInfo.hProcess); { *Converted from CloseHandle* }
          FileClose(vProcessInfo.hThread); { *Converted from CloseHandle* }
        end;
      finally
        FreeMem(vBuffer);
      end;
    finally
      FileClose(vStdOutPipe.Input); { *Converted from CloseHandle* }
      FileClose(vStdOutPipe.Output); { *Converted from CloseHandle* }
    end;
  finally
    FileClose(vStdInPipe.Input); { *Converted from CloseHandle* }
    FileClose(vStdInPipe.Output); { *Converted from CloseHandle* }
  end;
end;

 function GetCurrentThreadID:TThreadID;
  begin
   result:=windows.GetCurrentThreadId;
  end;

 procedure Sleep;
  begin
   windows.Sleep(time);
  end;

 procedure TerminateThread;
  begin
   windows.TerminateThread(threadHandle,exitCode);
  end;

 procedure ChangeThreadPriority(priority:integer); // -2..2 where 0 is Normal
  begin
   SetThreadPriority(GetCurrentThread,priority);
  end;

 function LoadCursorFromFile(fname:PChar):HCursor;
  begin
   result:=windows.LoadCursorFromFile(fname);
  end;

 function LoadCursor(instance:cardinal;name:PChar):HCursor;
  begin
   result:=windows.LoadCursor(instance,name);
  end;
 function GetCursor:HCursor;
  begin
   result:=windows.GetCursor;
  end;
 procedure SetCursor(cursor:HCursor);
  begin
   windows.SetCursor(cursor);
  end;
 function GetTickCount:cardinal;
  begin
   result:=windows.getTickCount;
  end;
 procedure QueryPerformanceCounter;
  begin
   windows.QueryPerformanceCounter(value);
  end;
 procedure QueryPerformanceFrequency;
  begin
   windows.QueryPerformanceFrequency(value);
  end;
 function GetWindowRect(window:HWND;out rect:TRect):boolean;
  begin
   result:=windows.GetWindowRect(window,rect);
  end;
 function MoveWindow(window:HWND;x,y,w,h:integer;repaint:boolean):boolean;
  begin
   result:=windows.MoveWindow(window,x,y,w,h,repaint);
  end;
{$ENDIF}

{$IFDEF UNIX}
 function ExecAndCapture(const ACmdLine: AnsiString; var AOutput: AnsiString): Integer;
  var
   output:string;
  begin
   if RunCommand(aCmdLine,output) then begin
    aOutput:=output;
    result:=length(output);
   end else
    result:=0;
  end;

{$ENDIF}

// iOS SET ===========================================================
{$IFDEF IOS}
var
  startTime:NSDate;
  lastInterval:NSTimeInterval=0;
  startTime2:double;

 procedure Sleep(time:integer);
  begin
   NSThread.sleepForTimeInterval(time/1000);
   //Sleep(time);
  end;

 function GetCurrentThreadID;
  begin
   result:=system.getCurrentThreadID;
  end;

 procedure TerminateThread(threadHandle:system.TThreadID;exitCode:cardinal);
  begin
   CloseThread(threadHandle);
  end;

 function GetTickCount:cardinal;
  var
   interval:NSTimeInterval;
  begin
   if startTime=nil then begin
     startTime:=NSDate.date;
     startTime.retain;
   end;
   interval:=-startTime.timeIntervalSinceNow;
   if interval<lastInterval then interval:=lastInterval
    else lastInterval:=interval;
   result:=round(interval*1000)+100000; // bias
  end;

 procedure QueryPerformanceCounter;
  var
    time:double;
  begin
   time:=CACurrentMediaTime;
   if startTime2=0 then startTime2:=time;
   value:=round((time-startTime2)*1000000);
  end;

 procedure QueryPerformanceFrequency;
  begin
   value:=1000000;
  end;
{$ENDIF}

// LINUX/ANDROID SET ===========================================================
{$IFDEF UNIX}
procedure Sleep(time:integer);
 begin
  SysUtils.Sleep(time);
 end;

function GetCurrentThreadID;
 begin
  result:=system.getCurrentThreadID;
 end;

procedure TerminateThread(threadHandle:system.TThreadID;exitCode:cardinal);
 begin
  CloseThread(threadHandle);
 end;

procedure ChangeThreadPriority(priority:integer);
 begin
  // Not implemented
 end;


function GetTickCount:cardinal;
 var
  tp:TTimeSpec;
 begin
  clock_gettime(CLOCK_MONOTONIC,@tp);
  result:=tp.tv_sec*1000+tp.tv_nsec div 1000000;
 end;

procedure QueryPerformanceCounter(out value:int64);
  var
   tp:TTimeSpec;
  begin
   clock_gettime(CLOCK_MONOTONIC,@tp);
   value:=tp.tv_sec*1000000+tp.tv_nsec div 1000;
//  DebugMessage('WARN! QPF not implemented!');
  //raise Exception.Create('QPF not implemented!');
 end;

procedure QueryPerformanceFrequency;
 begin
  value:=1000000;
 end;

procedure OpenURL(url:string);
 begin
//  ShellExecute(0,'open',PChar(url),'','',SW_SHOW);
 end;

function GetSystemInfo:string;
 begin
  result:='';
 end;

function LaunchProcess(fname,params:string):boolean;
 begin
  result:=false;
 end;
{$ENDIF}

 function GetDecimalSeparator:char;
  begin
   result:=
   {$IF Declared(FormatSettings)}
   FormatSettings.
   {$IFEND}
   DecimalSeparator;
  end;

 procedure SetDecimalSeparator(c:char);
  begin
   {$IF Declared(FormatSettings)}
   FormatSettings.
   {$IFEND}
   DecimalSeparator:=c;
  end;

 {$IFNDEF UNICODE}
 function AnsiStrAlloc(size:integer):PAnsiChar;
  begin
   result:=StrAlloc(size);
  end;
 {$ENDIF}

 {$IFDEF FPC}
 function TSystemTimeHelper.wDay:word;
  begin
   result:=Day;
  end;
 function TSystemTimeHelper.wMonth:word;
  begin
   result:=Month;
  end;
 function TSystemTimeHelper.wYear:word;
  begin
   result:=Year;
  end;
 function TSystemTimeHelper.wHour:word;
  begin
   result:=Hour;
  end;
 function TSystemTimeHelper.wMinute:word;
  begin
   result:=Minute;
  end;
 function TSystemTimeHelper.wSecond:word;
  begin
   result:=Second;
  end;
 function TSystemTimeHelper.wMilliseconds:word;
  begin
   result:=Millisecond;
  end;
 {$ENDIF}

end.
