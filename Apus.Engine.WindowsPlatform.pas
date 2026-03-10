// Windows-specific functions used by Game object
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.WindowsPlatform;
interface
uses Windows, Apus.Types, Apus.Core, Apus.Engine.API, Apus.Engine.Keys, Apus.Engine.OpenGL;

type
 { TWinGLWindow - Windows + WGL window implementation }

 TWinGLWindow=class(TWindow)
   constructor Create(hwnd:HWND;windowName:String8='MainWnd');
   destructor Destroy; override;
   // TWindow overrides
   procedure Close; override;
   procedure Configure(params:TGameSettings); override;
   procedure Show(show:boolean); override;
   function GetHandle:THandle; override;
   procedure GetSize(out width,height:integer); override;
   procedure MoveTo(x,y:integer;width:integer=0;height:integer=0); override;
   procedure SetCaption(text:string); override;
   procedure Minimize; override;
   procedure FlashWindow(count:integer); override;
   procedure ProcessMessages; override;
   function IsTerminated:boolean; override;
   procedure ScreenToClient(var p:TPoint); override;
   procedure ClientToScreen(var p:TPoint); override;
    // Graphics lifecycle (implemented via WGL)
   procedure InitGraph; override;
   procedure InitGraphShared(primary:TWindow); override;
   procedure DoneGraph; override;
   procedure PresentFrame; override;
   function SetVSync(divider:integer):boolean; override;
 private
  window:HWND;
  context:UIntPtr;
  terminated:boolean;
  graphInfo:TOpenGLContextDesc;
  function CreateOpenGLContext(var graph:TOpenGLContextDesc;shareWith:UIntPtr=0):UIntPtr;
 end;

 { TWindowsPlatform - system services + window factory }

 TWindowsPlatform=class(TInterfacedObject,ISystemPlatform)
  constructor Create;
  // System information
  function GetPlatformName:string;
  function CanChangeSettings:boolean;
  procedure GetScreenSize(out width,height:integer);
  procedure GetRealScreenSize(out width,height:integer);
  function GetScreenDPI:integer;
  // System functions
  function GetMousePos:TPoint;
  procedure SetMousePos(scrX,scrY:integer);
  function GetSystemCursor(cursorId:integer):THandle;
  function LoadCursor(filename:string):THandle;
  procedure SetCursor(cur:THandle);
  procedure FreeCursor(cur:THandle);
  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetShiftKeysState:cardinal;
  function GetMouseButtons:cardinal;
  // Window factory
 function CreateWindow(title:string):TWindow;
 end;

implementation
uses Messages, Types, SysUtils, Apus.EventMan,
  Apus.Log, Apus.Strings, Apus.Engine.Types
  {$IFDEF MSWINDOWS},dglOpenGL{$ENDIF};
{$IFOPT R+} {$DEFINE RANGECHECK_ON} {$ENDIF}
var
 noPenAPI:boolean=false;
 classRegistered:boolean=false;

{$IF Declared(FlashWindowEx)} {$ELSE}
const
  FLASHW_STOP = $0;
  FLASHW_CAPTION = $1;
  FLASHW_TRAY = $2;
  FLASHW_ALL = FLASHW_CAPTION or FLASHW_TRAY;
  FLASHW_TIMER = $4;
  FLASHW_TIMERNOFG = $C;
type
 TFlashWInfo = packed record
  cbSize: DWORD;
  hwnd: HWND;
  dwFlags: DWORD;
  uCount: DWORD;
  dwTimeout: DWORD;
 end;
function FlashWindowEx(var pfwi: TFlashWInfo): LongBool; stdcall; external 'user32' Name 'FlashWindowEx';
{$IFEND}

function AsciiCodeFromUnicode(unicode:integer):integer;
var
 wst:WideString;
 ast:AnsiString;
begin
 wst:=WideChar(unicode);
 ast:=wst; // conversion
 result:=byte(ast[1]);
end;

procedure ProcessPointerMessage(Message:cardinal;WParam:UIntPtr;LParam:IntPtr);
var
 id:cardinal;
 {$IFDEF DELPHI}
 pType:POINTER_INPUT_TYPE;
 penInfo:POINTER_PEN_INFO;
 {$ENDIF}
begin
 if noPenAPI then exit;
 {$IFDEF DELPHI}
 try
  id:=Word(wParam);
  GetPointerType(id,@pType);
  if pType=Word(tagPOINTER_INPUT_TYPE.PT_PEN) then begin
    GetPointerPenInfo(id,@penInfo);
    if Bits.HasAll(penInfo.penMask,PEN_MASK_PRESSURE) then
      Signal('PEN\PRESSURE',penInfo.pressure);
    if Bits.HasAll(penInfo.penMask,PEN_MASK_ROTATION) then
      Signal('PEN\ROTATION',penInfo.rotation);
  end;
 except
  noPenAPI:=true;
 end;
 {$ENDIF}
end;

function WindowProc(Window:HWnd;Message:cardinal;WParam:UIntPtr;LParam:IntPtr):LongInt; stdcall;
var
 i,charCode,scanCode,keyCode:integer;
begin
 try
 result:=0;
 //writeln('WinMSG: ',IntTOHex(message):10,'  W=',IntToHex(wParam),'  L=',IntToHex(lParam));
 case Message of
  wm_Destroy:begin
   Log.Msg('WM_Destroy hwnd='+IntToStr(Window));
   if (mainWindow<>nil) and (mainWindow.GetHandle=THandle(Window)) then begin
    (mainWindow as TWinGLWindow).terminated:=true;
    Signal('Engine\Cmd\Exit',0);
   end else begin
    // extra window closed — mark as terminated, don't exit app
    if (Apus.Engine.API.window<>nil) and (Apus.Engine.API.window.GetHandle=THandle(Window)) then
     (Apus.Engine.API.window as TWinGLWindow).terminated:=true;
   end;
  end;
  {$IFDEF DELPHI} // FPC currently has no declaration of MS Pointer Input API
  WM_POINTERUPDATE,WM_POINTERENTER,WM_POINTERLEAVE:ProcessPointerMessage(Message,WParam,LParam);
  {$ENDIF}

  WM_MOUSEMOVE:Signal('MOUSE\CLIENTMOVE',lParam);

  WM_MOUSELEAVE:Signal('MOUSE\CLIENTMOVE',$3FFF3FFF);

  WM_UNICHAR:begin
//   Log.Msg(inttostr(wparam)+' '+inttostr(lparam));
  end;

  WM_CHAR:begin
    charCode:=wParam and $FFFF;
    scanCode:=(lParam shr 16) and $FF;
    Signal('KBD\CHAR',AsciiCodeFromUnicode(charCode)+scanCode shl 16);
    Signal('KBD\UNICHAR',charCode+scanCode shl 16);
  end;

  WM_KEYDOWN,WM_SYSKEYDOWN:begin
    // wParam = Virtual Code; lParam[23..16] = Scancode
    scancode:=(lParam shr 16) and $FF;
    keyCode:=TKey.FromWindowsVK(cardinal(wParam)).Code;
    Signal('KBD\KEYDOWN',keyCode+scancode shl 16);
  end;

  WM_KEYUP,WM_SYSKEYUP:begin
    scancode:=(lParam shr 16) and $FF;
    keyCode:=TKey.FromWindowsVK(cardinal(wParam)).Code;
    Signal('KBD\KEYUP',keyCode+scancode shl 16);
    if message=WM_SYSKEYUP then exit(0);
  end;

{  WM_SYSCHAR:begin
    result:=0; exit;
    scancode:=(lParam shr 16) and $FF;
//    Signal('KBD\KeyDown',wParam and $FFFF+game.shiftState shl 16+scancode shl 24);
  end;}

  WM_LBUTTONDOWN,WM_RBUTTONDOWN,WM_MBUTTONDOWN:begin
    SetCapture(window);
    i:=0;
    if message=wm_LButtonDown then i:=1 else
    if message=wm_RButtonDown then i:=2 else
    if message=wm_MButtonDown then i:=3;
    Signal('MOUSE\BTNDOWN',i);
  end;

  WM_LBUTTONUP,WM_RBUTTONUP,WM_MBUTTONUP:begin
    ReleaseCapture;
    i:=0;
    if message=wm_LButtonUp then i:=1 else
    if message=wm_RButtonUp then i:=2 else
    if message=wm_MButtonUp then i:=3;
    Signal('MOUSE\BTNUP',i);
  end;

  WM_MOUSEWHEEL:Signal('MOUSE\SCROLL',smallint(wParam shr 16));

  WM_SIZE:if lParam<>0 then Signal('ENGINE\RESIZE',lParam);

  WM_PAINT:begin
    Signal('ENGINE\REDRAW');
  end;

  WM_ACTIVATE:begin
   //Log.Msg('WM_ACTIVATE: %x %x',[wparam,lparam]);
   if loword(wparam)<>wa_inactive then i:=1
    else i:=0;
   Signal('ENGINE\SETACTIVE',i);
  end;
 end;

 {$R-}
 result:=Longint(DefWindowProcW(Window,Message,WParam,LParam));
 {$IFDEF RANGECHECK_ON} {$R+} {$ENDIF}
 except
  on e:Exception do Log.Force('WindowProc error: '+ExceptionMsg(e));
 end;
end;

{ TWinGLWindow }

constructor TWinGLWindow.Create(hwnd:HWND;windowName:String8='MainWnd');
begin
  inherited Create(windowName);
  window:=hwnd;
end;

destructor TWinGLWindow.Destroy;
begin
  inherited;
end;

{ TWindowsPlatform }

constructor TWindowsPlatform.Create;
 var
  ver:DWord;
 begin
  ver:=GetVersion;
  Log.Msg('Windows platform: %d.%d',[ver and $FF,(ver shr 8) and $FF]);
 end;

function TWindowsPlatform.CanChangeSettings: boolean;
 begin
  result:=true;
 end;

procedure TWinGLWindow.ClientToScreen(var p: TPoint);
 begin
  windows.ClientToScreen(window,p);
 end;

procedure TWinGLWindow.Close;
 begin
  windows.ShowWindow(window,SW_HIDE);
  windows.DestroyWindow(window);
 end;

procedure TWinGLWindow.FlashWindow(count: integer);
 var
  fi:TFlashWInfo;
 begin
  Mem.Fill(fi,sizeof(fi),0);
  fi.cbSize:=sizeof(fi);
  fi.hwnd:=window;
  fi.dwTimeout:=400;
  if count=-1 then
   fi.dwFlags:=FLASHW_STOP
  else
   fi.dwFlags:=FLASHW_ALL+FLASHW_TIMERNOFG*byte(count=0);
  if count<=0 then count:=100;
  fi.uCount:=count;
  {$IFDEF FPC}
  FlashWindowEx(@fi);
  {$ELSE}
  FlashWindowEx(fi);
  {$ENDIF}
 end;

procedure TWinGLWindow.ScreenToClient(var p: TPoint);
 begin
  windows.ScreenToClient(window,p);
 end;

function TWindowsPlatform.GetMousePos: TPoint;
 begin
  GetCursorPos(result);
 end;

procedure TWindowsPlatform.SetMousePos(scrX,scrY:integer);
 begin
  SetCursorPos(scrX,scrY);
 end;

function TWindowsPlatform.GetPlatformName: string;
 begin
  result:='WINDOWS';
 end;

function TWindowsPlatform.GetScreenDPI:integer;
 var
  dc:HDC;
 begin
  dc:=GetDC(0);
  ASSERT(dc<>0);
  result:=(GetDeviceCaps(dc,LOGPIXELSX)+GetDeviceCaps(dc,LOGPIXELSY)) div 2;
  ReleaseDC(0,dc);
 end;

procedure TWindowsPlatform.GetScreenSize(out width,height:integer);
 begin
  width:=GetSystemMetrics(SM_CXSCREEN);
  height:=GetSystemMetrics(SM_CYSCREEN);
 end;

procedure TWindowsPlatform.GetRealScreenSize(out width,height:integer);
 const
  ENUM_CURRENT_SETTINGS = DWORD(-1);
 var
  devMode:TDeviceModeA;
 begin
  EnumDisplaySettingsA(nil,ENUM_CURRENT_SETTINGS,devMode);
  width:=devMode.dmPelsWidth;
  height:=devMode.dmPelsHeight;
 end;

function TWindowsPlatform.GetShiftKeysState: cardinal;
 begin
  result:=0;
  if GetAsyncKeyState(VK_SHIFT)<0 then inc(result,sscShift);
  if GetAsyncKeyState(VK_CONTROL)<0 then inc(result,sscCtrl);
  if GetAsyncKeyState(VK_MENU)<0 then inc(result,sscAlt);
  if (GetAsyncKeyState(VK_LWIN)<0) or
     (GetAsyncKeyState(VK_RWIN)<0) then inc(result,sscWin);
 end;

function TWindowsPlatform.GetMouseButtons: cardinal;
 begin
  result:=0;
  if GetAsyncKeyState(VK_LBUTTON)<0 then inc(result,mbLeft);
  if GetAsyncKeyState(VK_RBUTTON)<0 then inc(result,mbRight);
  if GetAsyncKeyState(VK_MBUTTON)<0 then inc(result,mbMiddle);
 end;

function TWindowsPlatform.GetSystemCursor(cursorId: integer): THandle;
 var
  name:PChar;
 begin
  case cursorID of
   Apus.Engine.API.CursorID.Default:name:=IDC_ARROW;
   Apus.Engine.API.CursorID.Link:name:=IDC_HAND;
   Apus.Engine.API.CursorID.Wait:name:=IDC_WAIT;
   Apus.Engine.API.CursorID.Input:name:=IDC_IBEAM;
   Apus.Engine.API.CursorID.Help:name:=IDC_HELP;
   Apus.Engine.API.CursorID.ResizeH:name:=IDC_SIZENS;
   Apus.Engine.API.CursorID.ResizeW:name:=IDC_SIZEWE;
   Apus.Engine.API.CursorID.ResizeHW:name:=IDC_SIZEALL;
   Apus.Engine.API.CursorID.Cross:name:=IDC_CROSS;
  end;
  result:=Windows.LoadCursor(0,name);
 end;

function TWindowsPlatform.LoadCursor(filename:string):THandle;
 begin
  filename:=ChangeFileExt(filename,'.cur');
  result:=LoadCursorFromFileW(PWideChar(filename));
 end;

procedure TWindowsPlatform.SetCursor(cur:THandle);
 begin
  windows.SetCursor(cur);
 end;

procedure TWindowsPlatform.FreeCursor(cur:THandle);
 begin
  FreeCursor(cur);
 end;

function TWinGLWindow.GetHandle:THandle;
 begin
  result:=window;
 end;

procedure TWinGLWindow.GetSize(out width,height:integer);
 var
  r:TRect;
 begin
  GetClientRect(window,r);
  width:=r.Width; height:=r.Height;
 end;

function TWindowsPlatform.CreateWindow(title:string):TWindow;
 var
  WindowClass:TWndClassW;
  style:cardinal;
  wndHandle:HWND;
 begin
   Log.Msg('CreateWindow: '+title);
   if not classRegistered then begin
    with WindowClass do begin
     Style:=cs_HRedraw or cs_VRedraw;
     lpfnWndProc:=@WindowProc;
     cbClsExtra:=0;
     cbWndExtra:=0;
     hInstance:=0;
     hIcon:=LoadIcon(MainInstance,'MAINICON');
     hCursor:=0;
     hbrBackground:=GetStockObject(Black_Brush);
     lpszMenuName:='';
     lpszClassName:='GameWindowClass';
    end;
    if windows.RegisterClassW(WindowClass)=0 then
     raise EFatalError.Create('Cannot register window class');
    classRegistered:=true;
   end;

   style:=0;
   wndHandle:=windows.CreateWindowW('GameWindowClass', PWideChar(WideString(title)),
    style, 0, 0, 100, 100, 0, 0, HInstance, nil);
   result:=TWinGLWindow.Create(wndHandle,title);
  end;

procedure TWinGLWindow.ProcessMessages;
 var
  mes:TagMSG;
 begin
  while PeekMessageW(mes,0,0,0,pm_NoRemove) do begin
    if not GetMessageW(mes,0,0,0) then
     raise EWarning.Create('Failed to get message');

    if mes.message=wm_quit then // ���� ������� ������� �� �����
     Signal('Engine\Cmd\Exit',0);

    TranslateMessage(Mes);
    DispatchMessageW(Mes);
   end;
 end;

function TWinGLWindow.IsTerminated:boolean;
 begin
  result:=terminated;
 end;

procedure TWinGLWindow.Minimize;
 begin
  windows.ShowWindow(window,SW_MINIMIZE);
 end;

procedure TWinGLWindow.MoveTo(x,y:integer;width:integer;
  height: integer);
 var
  r:TRect;
  dx,dy:integer;
 begin
  getWindowRect(window,r);
  dx:=x-r.left; dy:=y-r.top;
  inc(r.left,dx); inc(r.right,dx);
  inc(r.top,dy); inc(r.Bottom,dy);
  if (width>0) and (height>0) then begin
   r.Right:=r.left+width;
   r.Bottom:=r.top+height;
  end;
  if not MoveWindow(window,r.left,r.top,r.right-r.left,r.Bottom-r.top,true) then
   Log.Force('MoveWindow error: '+inttostr(GetLastError));
 end;

function TWinGLWindow.CreateOpenGLContext(var graph:TOpenGLContextDesc;shareWith:UIntPtr=0):UIntPtr;
 type
  TglGetStringFn=function(name:cardinal):PAnsiChar; stdcall;
  TwglGetProcAddressFn=function(procName:PAnsiChar):Pointer; stdcall;
  TwglCreateContextAttribsFn=function(hDC:HDC;hShareContext:HGLRC;const attribList:PInteger):HGLRC; stdcall;
 var
  DC:HDC;
  RC,legacyRC:HGLRC;
  PFD:TPixelFormatDescriptor;
  pf:integer;
  requestedMajor,requestedMinor:integer;
  availMajor,availMinor:integer;
  attribs:array[0..15] of integer;
 n,flags,profileMask:integer;
  modernCreated:boolean;
  requestedProfile,actualProfile:TOpenGLContextProfile;
  requestedDebug,requestedForward:boolean;
  glVer:string;
  glVerRaw:PAnsiChar;
  openglLib:HMODULE;
  glGetStringFn:TglGetStringFn;
  wglGetProcAddressFn:TwglGetProcAddressFn;
  wglCreateContextAttribsARB:TwglCreateContextAttribsFn;
 function ParseGLVersion(const st:string;out major,minor:integer):boolean;
  var
   i,start:integer;
   s:string;
  begin
   result:=false;
   major:=0; minor:=0;
   s:=st;
   start:=0;
   for i:=1 to length(s)-2 do
    if (s[i] in ['0'..'9']) and (s[i+1] in ['0'..'9','.']) then begin
     start:=i; break;
    end;
   if start=0 then exit;
    i:=start;
   while (i<=length(s)) and (s[i] in ['0'..'9']) do inc(i);
   if (i>length(s)) or (s[i]<>'.') then exit;
   major:=strtointdef(copy(s,start,i-start),0);
   inc(i); start:=i;
   while (i<=length(s)) and (s[i] in ['0'..'9']) do inc(i);
    if start=i then exit;
   minor:=strtointdef(copy(s,start,i-start),0);
   result:=major>0;
  end;
 begin
   requestedProfile:=graph.profile;
   requestedDebug:=graph.debugContext;
   requestedForward:=graph.forwardCompatible;
   Log.Msg('Prepare GL context');
   Mem.Clear(pfd,sizeof(PFD));
   with PFD do begin
    nSize:=sizeof(PFD);
    nVersion:=1;
    dwFlags:=PFD_SUPPORT_OPENGL+PFD_DRAW_TO_WINDOW+PFD_DOUBLEBUFFER;
    iPixelType:=PFD_TYPE_RGBA;
    cDepthBits:=16;
   end;
   DC:=GetDC(window);
   Log.Msg('ChoosePixelFormat');
   pf:=ChoosePixelFormat(DC,@PFD);
   Log.Msg('Pixel format: '+IntToStr(pf));
   if not SetPixelFormat(DC,pf,@PFD) then
    Log.Error('Failed to set pixel format!');

   Log.Msg('Create GL context');
   legacyRC:=wglCreateContext(DC);
   if legacyRC=0 then
     raise EError.Create('Can''t create RC!');
   wglMakeCurrent(DC,legacyRC);

   glVerRaw:=nil;
   openglLib:=GetModuleHandle('opengl32.dll');
   if openglLib<>0 then begin
    // dglOpenGL may not expose glGetString yet at this point; resolve it directly from opengl32.
    glGetStringFn:=TglGetStringFn(GetProcAddress(openglLib,'glGetString'));
    if assigned(glGetStringFn) then
     glVerRaw:=glGetStringFn($1F02); // GL_VERSION
   end;
   if glVerRaw<>nil then
    glVer:=glVerRaw
   else
    glVer:='unknown';
   if not ParseGLVersion(glVer,availMajor,availMinor) then begin
    availMajor:=2;
    availMinor:=1;
   end;
   Log.Msg('Available GL version on temporary context: '+IntToStr(availMajor)+'.'+IntToStr(availMinor)+' ('+glVer+')');

   RC:=legacyRC;
   requestedMajor:=graph.minMajor;
   requestedMinor:=graph.minMinor;
   if graph.preferHighest then begin
    // Agreed policy: request one modern context using negotiated highest version,
    // do not brute-force all version pairs.
    requestedMajor:=availMajor;
    requestedMinor:=availMinor;
   end;

   if (requestedProfile<>oglpCompatibility) or requestedDebug or requestedForward then begin
    if (availMajor>graph.minMajor) or ((availMajor=graph.minMajor) and (availMinor>=graph.minMinor)) then begin
     if openglLib<>0 then
      wglGetProcAddressFn:=TwglGetProcAddressFn(GetProcAddress(openglLib,'wglGetProcAddress'))
     else
      wglGetProcAddressFn:=nil;
     if assigned(wglGetProcAddressFn) then
      wglCreateContextAttribsARB:=TwglCreateContextAttribsFn(wglGetProcAddressFn('wglCreateContextAttribsARB'))
     else
      wglCreateContextAttribsARB:=nil;
     if assigned(wglCreateContextAttribsARB) then begin
      n:=0;
      attribs[n]:=WGL_CONTEXT_MAJOR_VERSION_ARB; inc(n);
      attribs[n]:=requestedMajor; inc(n);
      attribs[n]:=WGL_CONTEXT_MINOR_VERSION_ARB; inc(n);
      attribs[n]:=requestedMinor; inc(n);
      profileMask:=0;
      case requestedProfile of
       oglpCore:profileMask:=WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
       oglpCompatibility:profileMask:=WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;
      end;
      if profileMask<>0 then begin
       attribs[n]:=WGL_CONTEXT_PROFILE_MASK_ARB; inc(n);
       attribs[n]:=profileMask; inc(n);
      end;
      flags:=0;
      if requestedDebug then flags:=flags or WGL_CONTEXT_DEBUG_BIT_ARB;
      if requestedForward then flags:=flags or WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB;
      if flags<>0 then begin
       attribs[n]:=WGL_CONTEXT_FLAGS_ARB; inc(n);
       attribs[n]:=flags; inc(n);
      end;
      attribs[n]:=0;
      RC:=wglCreateContextAttribsARB(DC,shareWith,@attribs[0]);
      if RC<>0 then begin
       wglMakeCurrent(0,0);
       wglDeleteContext(legacyRC);
      end else begin
       RC:=legacyRC;
       Log.Warn('Failed to create requested modern GL context, keeping legacy context');
      end;
     end else
      Log.Warn('wglCreateContextAttribsARB not available, keeping legacy context');
    end else
     Log.Error('Requested minimal GL version is higher than available; modern context cannot be created');
   end;
   if (requestedProfile=oglpCore) and (RC=legacyRC) then begin
    // Hard requirement for core request: never silently continue on legacy context.
    wglMakeCurrent(0,0);
    wglDeleteContext(legacyRC);
    RC:=0;
   end;
   modernCreated:=(RC<>0) and (RC<>legacyRC);
   if RC<>0 then
    wglMakeCurrent(DC,RC)
   else
    wglMakeCurrent(0,0);
   graph.actualMajor:=0;
   graph.actualMinor:=0;
   if modernCreated then begin
    if requestedProfile=oglpCore then
     actualProfile:=oglpCore
    else
    if requestedProfile=oglpCompatibility then
     actualProfile:=oglpCompatibility
    else
     actualProfile:=oglpAny;
    graph.debugContext:=requestedDebug;
    graph.forwardCompatible:=requestedForward;
   end else begin
    // Legacy context path cannot guarantee debug/forward flags.
    actualProfile:=oglpCompatibility;
    graph.debugContext:=false;
    graph.forwardCompatible:=false;
   end;
   graph.profile:=actualProfile;
   graph.requestAccepted:=RC<>0;
   // requestAccepted means "all explicitly requested capabilities are present".
   if requestedProfile=oglpCore then
    graph.requestAccepted:=graph.requestAccepted and (graph.profile=oglpCore);
   if requestedDebug then
    graph.requestAccepted:=graph.requestAccepted and graph.debugContext;
   if requestedForward then
    graph.requestAccepted:=graph.requestAccepted and graph.forwardCompatible;
   context:=RC;
   result:=context;
  end;

procedure TWinGLWindow.InitGraph;
 begin
  graphInfo.minMajor:=oglContextTemplate.minMajor;
  graphInfo.minMinor:=oglContextTemplate.minMinor;
  graphInfo.profile:=oglContextTemplate.profile;
  graphInfo.debugContext:=oglContextTemplate.debugContext;
  graphInfo.forwardCompatible:=oglContextTemplate.forwardCompatible;
  graphInfo.preferHighest:=oglContextTemplate.preferHighest;
  graphInfo.actualMajor:=0;
  graphInfo.actualMinor:=0;
  graphInfo.requestAccepted:=false;
  if CreateOpenGLContext(graphInfo)=0 then
   raise EError.Create('Can''t create OpenGL context');
  oglContextInfo:=graphInfo;
 end;

procedure TWinGLWindow.InitGraphShared(primary:TWindow);
 var
  src:TWinGLWindow;
  vao:cardinal;
 begin
  ASSERT(primary<>nil);
  ASSERT(primary is TWinGLWindow,'Primary must be TWinGLWindow');
  src:=TWinGLWindow(primary);
  ASSERT(src.context<>0,'Primary window has no GL context');
  graphInfo:=src.graphInfo; // inherit context description
  graphInfo.actualMajor:=0;
  graphInfo.actualMinor:=0;
  graphInfo.requestAccepted:=false;
  if CreateOpenGLContext(graphInfo,src.context)=0 then
   raise EError.Create('Can''t create shared OpenGL context');
  oglContextInfo:=graphInfo;
  // core profile requires a bound VAO before any draw call
  if graphInfo.profile=oglpCore then begin
   vao:=0;
   glGenVertexArrays(1,@vao);
   glBindVertexArray(vao);
   Log.Msg('Extra window VAO created: '+IntToStr(vao));
  end;
 end;

procedure TWinGLWindow.PresentFrame;
 var
  DC:HDC;
 begin
   DC:=getDC(window);
   if not SwapBuffers(DC) then
    Log.Msg('Swap error: '+IntToStr(GetLastError));
   ReleaseDC(window,DC);
 end;

function TWinGLWindow.SetVSync(divider: integer): boolean;
 begin
  result:=false;
 end;

procedure TWinGLWindow.DoneGraph;
 begin
  if context<>0 then begin
   wglMakeCurrent(0,0);
   wglDeleteContext(context);
  end;
  context:=0;
 end;

procedure TWinGLWindow.Configure(params:TGameSettings);
 var
  r,r2:TRect;
  style:cardinal;
  w,h:integer;
 begin
   Log.Msg('Configure main window');
   style:=ws_popup;
   //if params.mode.displayMode=dmBorderless then style:=
   if params.mode.displayMode=dmWindow then inc(style,WS_SIZEBOX+WS_MAXIMIZEBOX);
   if params.mode.displayMode in [dmWindow,dmFixedWindow] then
    inc(style,WS_CAPTION+WS_MINIMIZEBOX+WS_SYSMENU);

   // Get desktop area size
   SystemParametersInfo(SPI_GETWORKAREA,0,@r2,0);

   w:=params.width;
   h:=params.height;
   case params.mode.displayMode of
    dmWindow,dmFixedWindow,dmBorderless:begin
      r:=Rect(0,0,w,h);
      AdjustWindowRect(r,style,false);
      r.Offset(-r.left,-r.top);
      // If window is too large
      r.Right:=Clamp(r.Right,0,r2.Width);
      r.Bottom:=Clamp(r.Bottom,0,r2.Height);
      // Center window
      r.Offset((r2.Width-r.Width) div 2,(r2.Height-r.Height) div 2);
      SetWindowLong(window,GWL_STYLE,longint(style));
      MoveTo(r.left,r.top,r.width,r.height);
    end;
    dmSwitchResolution,dmFullScreen:begin
      SetWindowLong(window,GWL_STYLE,longint(ws_popup));
      MoveTo(0,0,game.screenWidth,game.screenHeight);
    end;
   end;

   windows.ShowWindow(Window, SW_SHOW);
   UpdateWindow(Window);

   GetWindowRect(window,r);
   Log.Msg('WindowRect: '+inttostr(r.Right-r.Left)+':'+inttostr(r.Bottom-r.top));
   GetClientRect(window,r);
   Log.Msg('ClientRect: '+inttostr(r.Right-r.Left)+':'+inttostr(r.Bottom-r.top));
   Signal('ENGINE\RESIZE',r.Width+r.height shl 16);
 end;

procedure TWinGLWindow.SetCaption(text:string);
 var
  wst:String16;
  t:PWideChar;
 begin
  wst:=Str16(text);
  t:=@wst[1];
  SetWindowTextW(window,t);
 end;

procedure TWinGLWindow.Show(show:boolean);
 begin
  //LoadCursor(0,IDC_ARROW);
  if show then
   windows.ShowWindow(window,SW_SHOWNORMAL)
  else
   windows.ShowWindow(window,SW_HIDE);
 end;

function TWindowsPlatform.MapScanCodeToVirtualKey(key:integer):integer;
 begin
  result:=MapVirtualKey(key,MAPVK_VSC_TO_VK);
 end;


end.
