// Windows-specific functions used by Game object
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$I defines.inc}
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
   procedure SamplePointer; override;
    // Graphics lifecycle (implemented via WGL)
  procedure InitGraph; override;
  procedure InitGraphShared(primary:TWindow;mainContextReleased:boolean=false); override;
  procedure DoneGraph; override;
  procedure ReleaseGraphContext; override;
  procedure ActivateGraphContext; override;
  procedure PresentFrame; override;
  function SetVSync(divider:integer):boolean; override;
 private
  window:HWND;
  context:UIntPtr;
  contextVAO:cardinal; // per-context VAO for shared secondary window
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
uses Messages, Types, SysUtils, Apus.Lib,
  Apus.EventMan, Apus.Strings, Apus.Engine.Types
  {$IFDEF MSWINDOWS},dglOpenGL{$ENDIF};

{$IFOPT R+} {$DEFINE RANGECHECK_ON} {$ENDIF}
type
 TwglCreateContextAttribsFn=function(hDC:HDC;hShareContext:HGLRC;const attribList:PInteger):HGLRC; stdcall;
const
  glcsReady=0;
  glcsReleaseRequested=1;
  glcsReleased=2;
  {$IF not Declared(XBUTTON1)}
  XBUTTON1 = $0001;
  XBUTTON2 = $0002;
  {$ENDIF}
  {$IF not Declared(VK_XBUTTON1)}
  VK_XBUTTON1 = $05;
  VK_XBUTTON2 = $06;
  {$ENDIF}
  {$IF not Declared(WM_DPICHANGED)}
  WM_DPICHANGED = $02E0;
  {$ENDIF}
var
 noPenAPI:boolean=false;
 classRegistered:boolean=false;
 // Last cursor handle applied via TWindowsPlatform.SetCursor. The window class has
 // no cursor (hCursor=0), so we re-assert this one on WM_SETCURSOR/HTCLIENT to undo
 // the sizing cursor that DefWindowProc sets while hovering a resize border.
 currentCursor:THandle=0;
 // WGL entry-point cache obtained on primary context and reused by secondary
 // windows when creating shared modern contexts in other threads.
 cachedWglCreateContextAttribs:TwglCreateContextAttribsFn=nil;
 // GL context handoff state for AddWindow startup.
 // Win32/WGL requires shareWith context to be non-current in all threads.
 glShareState:integer=glcsReady;

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
 ast:=AnsiString(wst); // conversion
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
 isExtended:boolean;
 vkCode:cardinal;
 rc:TRect;
 pt:TPoint;
begin
 try
 result:=0;

 case Message of
  wm_Destroy:begin
   Log.Msg('WM_Destroy hwnd=%d',[Window]);
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

  // WM_MOUSEMOVE / WM_MOUSELEAVE intentionally not handled here:
  // mouse position is sampled once per frame via TWindow.SamplePointer,
  // which avoids OS-rate event flood on high-polling-rate mice.

  WM_UNICHAR:begin
//   Log.Msg('WM_UNICHAR wParam=%d lParam=%d',[wParam,lParam]);
  end;

  WM_CHAR:begin
    charCode:=wParam and $FFFF;
    scanCode:=(lParam shr 16) and $FF;
    Signal('KBD\CHAR',AsciiCodeFromUnicode(charCode)+scanCode shl 16);
    Signal('KBD\UNICHAR',charCode+scanCode shl 16);
  end;

  WM_KEYDOWN,WM_SYSKEYDOWN:begin
    // wParam = Virtual Code; lParam[23..16] = scan; lParam[24] = extended key flag
    scanCode:=(lParam shr 16) and $FF;
    isExtended:=Bits.HasAll(cardinal(lParam shr 24),1);
    vkCode:=wParam and $FFFF;
    if vkCode=VK_SHIFT then
      vkCode:=MapVirtualKey(scanCode,MAPVK_VSC_TO_VK_EX)
    else
    if vkCode=VK_CONTROL then begin
      if isExtended then vkCode:=VK_RCONTROL else vkCode:=VK_LCONTROL;
    end else
    if vkCode=VK_MENU then begin
      if isExtended then vkCode:=VK_RMENU else vkCode:=VK_LMENU;
    end;
    if isExtended then scanCode:=scanCode or $80;
    keyCode:=TKey.FromWindowsVK(vkCode).Code;
    Signal('KBD\KEYDOWN',keyCode+scancode shl 16);
  end;

  WM_KEYUP,WM_SYSKEYUP:begin
    scanCode:=(lParam shr 16) and $FF;
    isExtended:=Bits.HasAll(cardinal(lParam shr 24),1);
    vkCode:=wParam and $FFFF;
    if vkCode=VK_SHIFT then
      vkCode:=MapVirtualKey(scanCode,MAPVK_VSC_TO_VK_EX)
    else
    if vkCode=VK_CONTROL then begin
      if isExtended then vkCode:=VK_RCONTROL else vkCode:=VK_LCONTROL;
    end else
    if vkCode=VK_MENU then begin
      if isExtended then vkCode:=VK_RMENU else vkCode:=VK_LMENU;
    end;
    if isExtended then scanCode:=scanCode or $80;
    keyCode:=TKey.FromWindowsVK(vkCode).Code;
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
    Signal('MOUSE\BTNDOWN',i); // for external subscribers
    if Apus.Engine.API.window<>nil then begin
     Apus.Engine.API.window.SamplePointer; // fresh coords for hit-test at click moment
     Apus.Engine.API.window.NotifyScenesMouseBtn(i,true);
    end;
  end;
  WM_XBUTTONDOWN:begin
    SetCapture(window);
    i:=0;
    if HiWord(wParam)=XBUTTON1 then i:=4 else
    if HiWord(wParam)=XBUTTON2 then i:=5;
    if i>0 then begin
     Signal('MOUSE\BTNDOWN',i);
     if Apus.Engine.API.window<>nil then begin
      Apus.Engine.API.window.SamplePointer;
      Apus.Engine.API.window.NotifyScenesMouseBtn(i,true);
     end;
    end;
    exit(0);
  end;

  WM_LBUTTONUP,WM_RBUTTONUP,WM_MBUTTONUP:begin
    ReleaseCapture;
    i:=0;
    if message=wm_LButtonUp then i:=1 else
    if message=wm_RButtonUp then i:=2 else
    if message=wm_MButtonUp then i:=3;
    Signal('MOUSE\BTNUP',i); // for external subscribers
    if Apus.Engine.API.window<>nil then begin
     Apus.Engine.API.window.SamplePointer;
     Apus.Engine.API.window.NotifyScenesMouseBtn(i,false);
    end;
  end;
  WM_XBUTTONUP:begin
    ReleaseCapture;
    i:=0;
    if HiWord(wParam)=XBUTTON1 then i:=4 else
    if HiWord(wParam)=XBUTTON2 then i:=5;
    if i>0 then begin
     Signal('MOUSE\BTNUP',i);
     if Apus.Engine.API.window<>nil then begin
      Apus.Engine.API.window.SamplePointer;
      Apus.Engine.API.window.NotifyScenesMouseBtn(i,false);
     end;
    end;
    exit(0);
  end;

  WM_MOUSEWHEEL:begin
   Signal('MOUSE\SCROLL',smallint(wParam shr 16)); // for external subscribers
   if Apus.Engine.API.window<>nil then begin
    Apus.Engine.API.window.SamplePointer;
    Apus.Engine.API.window.NotifyScenesMouseWheel(smallint(wParam shr 16));
   end;
  end;

  WM_SIZE:if lParam<>0 then Signal('ENGINE\RESIZE',lParam);

  WM_DPICHANGED:begin
   // apply the suggested rect from Windows
   with PRect(lParam)^ do
    SetWindowPos(Window,0,Left,Top,Right-Left,Bottom-Top,
     SWP_NOZORDER or SWP_NOACTIVATE);
   if Apus.Engine.API.window<>nil then
    Apus.Engine.API.window.DPIChanged(loword(wParam));
  end;

  WM_NCHITTEST: begin
    // The OS sends WM_NCHITTEST at mouse-poll rate. Fast-path the common case —
    // cursor inside the client area — straight to HTCLIENT, skipping DefWindowProc's
    // non-client hit-test (this was the original FPS optimization). Only when the
    // cursor is over a border or the caption do we fall through to DefWindowProc, so
    // native resizing (WS_SIZEBOX) and window dragging still work there.
    pt.x:=smallint(loword(cardinal(lParam))); // screen coords, may be negative on multi-monitor
    pt.y:=smallint(hiword(cardinal(lParam)));
    ScreenToClient(Window,pt);
    GetClientRect(Window,rc);
    if (pt.x>=0) and (pt.y>=0) and (pt.x<rc.right) and (pt.y<rc.bottom) then begin
      result:=HTCLIENT;
      exit;
    end;
    // else fall through to DefWindowProc -> HTLEFT/HTCAPTION/HTBOTTOMRIGHT/...
  end;

  WM_SETCURSOR: begin
    // Class cursor is 0, so re-assert the engine's current cursor over the client
    // area (game cursor system: arrow/custom/hidden=0). This undoes the sizing
    // cursor DefWindowProc set on the resize border. Non-client (borders/caption)
    // falls through so native sizing cursors keep working.
    if word(lParam)=HTCLIENT then begin
      windows.SetCursor(currentCursor);
      exit(1);
    end;
  end;

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
  contextVAO:=0;
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

procedure TWinGLWindow.SamplePointer;
 var
  pnt:TPoint;
 begin
  Windows.GetCursorPos(pnt);
  Windows.ScreenToClient(self.window,pnt);
  // pointer outside client area → use off-screen sentinel
  if (pnt.x<0) or (pnt.y<0) or
     (pnt.x>=windowWidth) or (pnt.y>=windowHeight) then begin
   mousePos:=Types.Point($3FFF,$3FFF);
   exit;
  end;
  ClientToGame(pnt);
  mousePos:=pnt;
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
  if (GetAsyncKeyState(VK_LSHIFT)<0) or (GetAsyncKeyState(VK_RSHIFT)<0) then result:=result or sscShift;
  if (GetAsyncKeyState(VK_LCONTROL)<0) or (GetAsyncKeyState(VK_RCONTROL)<0) then result:=result or sscCtrl;
  if (GetAsyncKeyState(VK_LMENU)<0) or (GetAsyncKeyState(VK_RMENU)<0) then result:=result or sscAlt;
  if (GetAsyncKeyState(VK_LWIN)<0) or (GetAsyncKeyState(VK_RWIN)<0) then result:=result or sscWin;

  if GetAsyncKeyState(VK_RSHIFT)<0 then result:=result or sscRShift;
  if GetAsyncKeyState(VK_RCONTROL)<0 then result:=result or sscRCtrl;
  if GetAsyncKeyState(VK_RMENU)<0 then result:=result or sscRAlt;
  if GetAsyncKeyState(VK_RWIN)<0 then result:=result or sscRWin;
 end;

function TWindowsPlatform.GetMouseButtons: cardinal;
 begin
  result:=0;
  if GetAsyncKeyState(VK_LBUTTON)<0 then inc(result,mbLeft);
  if GetAsyncKeyState(VK_RBUTTON)<0 then inc(result,mbRight);
  if GetAsyncKeyState(VK_MBUTTON)<0 then inc(result,mbMiddle);
  if GetAsyncKeyState(VK_XBUTTON1)<0 then result:=result or (1 shl 3);
  if GetAsyncKeyState(VK_XBUTTON2)<0 then result:=result or (1 shl 4);
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
  currentCursor:=cur; // remembered so WM_SETCURSOR can re-assert the engine's choice
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
  e:cardinal;
 begin
   Log.Msg('CreateWindow: '+title);
   if not classRegistered then begin
    with WindowClass do begin
     // OpenGL windows should use own DC to keep stable WGL behavior across threads/windows.
     Style:=cs_HRedraw or cs_VRedraw or CS_OWNDC;
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
    if windows.RegisterClassW(WindowClass)=0 then begin
     e:=GetLastError;
     if e<>ERROR_CLASS_ALREADY_EXISTS then
      raise EFatalError.Create('Cannot register window class');
    end;
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
  while PeekMessageW(mes,0,0,0,PM_REMOVE) do begin
    if mes.message=WM_QUIT then begin
      if self=mainWindow then
        Signal('Engine\Cmd\Exit',0)
      else
        terminated:=true;
      break;
    end;
    TranslateMessage(mes);
    DispatchMessageW(mes);
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
   Log.Force('MoveWindow error: %d',[GetLastError]);
 end;

function TWinGLWindow.CreateOpenGLContext(var graph:TOpenGLContextDesc;shareWith:UIntPtr=0):UIntPtr;
 type
  TglGetStringFn=function(name:cardinal):PAnsiChar; stdcall;
  TwglGetProcAddressFn=function(procName:PAnsiChar):Pointer; stdcall;
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
  effectiveDebug:boolean;
  errCode:cardinal;
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
 procedure BuildAttribs(major,minor,profile:integer;debug,fwd:boolean);
  begin
   // WGL attributes are passed as key/value pairs terminated by 0.
   n:=0;
   attribs[n]:=WGL_CONTEXT_MAJOR_VERSION_ARB; inc(n);
   attribs[n]:=major; inc(n);
   attribs[n]:=WGL_CONTEXT_MINOR_VERSION_ARB; inc(n);
   attribs[n]:=minor; inc(n);
   if profile<>0 then begin
    attribs[n]:=WGL_CONTEXT_PROFILE_MASK_ARB; inc(n);
    attribs[n]:=profile; inc(n);
   end;
   flags:=0;
   if debug then flags:=flags or WGL_CONTEXT_DEBUG_BIT_ARB;
   if fwd then flags:=flags or WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB;
   if flags<>0 then begin
    attribs[n]:=WGL_CONTEXT_FLAGS_ARB; inc(n);
    attribs[n]:=flags; inc(n);
   end;
   attribs[n]:=0;
  end;
 procedure SetupPixelFormat;
  begin
   Log.Msg('Prepare GL context (shareWith=%d)',[shareWith]);
   // Pixel format is immutable per-window DC, so we set it once before any RC creation.
   Mem.Clear(pfd,sizeof(PFD));
   with PFD do begin
    nSize:=sizeof(PFD);
    nVersion:=1;
    dwFlags:=PFD_SUPPORT_OPENGL+PFD_DRAW_TO_WINDOW+PFD_DOUBLEBUFFER;
    iPixelType:=PFD_TYPE_RGBA;
    cDepthBits:=16;
   end;
   DC:=GetDC(window);
   pf:=ChoosePixelFormat(DC,@PFD);
   Log.Msg('Pixel format: %d',[pf]);
   if not SetPixelFormat(DC,pf,@PFD) then
    Log.Error('Failed to set pixel format!');
  end;
 procedure ProbePrimaryContext;
  begin
   // Primary window path:
   // create temporary legacy context to probe available version and load WGL entry points.
   Log.Msg('Create GL context');
   legacyRC:=wglCreateContext(DC);
   if legacyRC=0 then
    raise EError.Create('Can''t create RC!');
   wglMakeCurrent(DC,legacyRC);

   glVerRaw:=nil;
   openglLib:=GetModuleHandle('opengl32.dll');
   if openglLib<>0 then begin
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
   Log.Msg('Available GL version on temporary context: %d.%d (%s)',[availMajor,availMinor,glVer]);

   // Resolve wglCreateContextAttribsARB via opengl32->wglGetProcAddress.
   wglCreateContextAttribsARB:=nil;
   openglLib:=GetModuleHandle('opengl32.dll');
   if openglLib<>0 then begin
    wglGetProcAddressFn:=TwglGetProcAddressFn(GetProcAddress(openglLib,'wglGetProcAddress'));
    if assigned(wglGetProcAddressFn) then
     wglCreateContextAttribsARB:=TwglCreateContextAttribsFn(wglGetProcAddressFn('wglCreateContextAttribsARB'));
   end;
   // Cache proc address for future shared-context creation in secondary threads.
   if assigned(wglCreateContextAttribsARB) and (shareWith=0) then
    cachedWglCreateContextAttribs:=wglCreateContextAttribsARB;
   // Legacy context is no longer needed for probing.
   // Release current binding before attempting modern context creation.
   wglMakeCurrent(0,0);

   requestedMajor:=graph.minMajor;
   requestedMinor:=graph.minMinor;
   if graph.preferHighest then begin
    requestedMajor:=availMajor;
    requestedMinor:=availMinor;
   end;
  end;
 procedure PrepareContextCreationPath;
  begin
   // Shared secondary window:
   // use function pointer cached on primary context and request same baseline version.
   if (shareWith<>0) and assigned(cachedWglCreateContextAttribs) then begin
    legacyRC:=0;
    wglCreateContextAttribsARB:=cachedWglCreateContextAttribs;
    availMajor:=graph.minMajor;
    availMinor:=graph.minMinor;
    requestedMajor:=graph.minMajor;
    requestedMinor:=graph.minMinor;
    if graph.preferHighest then begin
     // use values from graphInfo inherited from primary
     requestedMajor:=graph.minMajor;
     requestedMinor:=graph.minMinor;
    end;
    Log.Msg('Creating shared context via cached wglCreateContextAttribsARB');
   end else
    ProbePrimaryContext;
  end;
 procedure TryCreateModernContext;
  begin
   RC:=0;
   profileMask:=0;
   case requestedProfile of
    oglpCore:profileMask:=WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
    oglpCompatibility:profileMask:=WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;
   end;
   // If special features are requested, try modern context path first.
   if (requestedProfile<>oglpCompatibility) or requestedDebug or requestedForward then begin
    if assigned(wglCreateContextAttribsARB) then begin
     BuildAttribs(requestedMajor,requestedMinor,profileMask,effectiveDebug,requestedForward);
     Log.Msg('wglCreateContextAttribsARB: DC=%d share=%d ver=%d.%d profile=%d flags=%d',
       [DC,shareWith,requestedMajor,requestedMinor,profileMask,flags]);
     RC:=wglCreateContextAttribsARB(DC,shareWith,@attribs[0]);
     if RC=0 then begin
      errCode:=GetLastError;
      Log.Warn('Failed to create modern GL context (err=%d / 0x%.8x)',[errCode,errCode]);
      // Some drivers reject debug+shared combination; retry without debug flag.
      if effectiveDebug and (shareWith<>0) then begin
       Log.Warn('Retry shared modern context without debug flag');
       effectiveDebug:=false;
       BuildAttribs(requestedMajor,requestedMinor,profileMask,false,requestedForward);
       RC:=wglCreateContextAttribsARB(DC,shareWith,@attribs[0]);
       if RC<>0 then
        Log.Warn('Shared modern context created without debug flag')
       else begin
        errCode:=GetLastError;
        Log.Warn('Retry failed (err=%d)',[errCode]);
       end;
      end;
     end;
    end else
     Log.Warn('wglCreateContextAttribsARB not available');
   end;
  end;
 procedure FinalizeContextSelection;
  begin
   // Finalize legacy/modern selection:
   // - modern created: drop legacy
   // - modern failed and non-core requested: fallback to legacy
   if legacyRC<>0 then begin
    if RC<>0 then
     wglDeleteContext(legacyRC)
    else if requestedProfile<>oglpCore then
     RC:=legacyRC; // fall back to legacy for non-core requests
   end;

   modernCreated:=(RC<>0) and (RC<>legacyRC);
   // Make resulting context current so caller can immediately initialize GL state.
   if RC<>0 then
    wglMakeCurrent(DC,RC)
   else
    wglMakeCurrent(0,0);
  end;
 procedure ApplyActualGraphInfo;
  begin
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
    graph.debugContext:=effectiveDebug;
    graph.forwardCompatible:=requestedForward;
   end else begin
    actualProfile:=oglpCompatibility;
    graph.debugContext:=false;
    graph.forwardCompatible:=false;
   end;
   graph.profile:=actualProfile;
   graph.requestAccepted:=RC<>0;
   if requestedProfile=oglpCore then
    graph.requestAccepted:=graph.requestAccepted and (graph.profile=oglpCore);
   if requestedDebug then
    graph.requestAccepted:=graph.requestAccepted and graph.debugContext;
   if requestedForward then
    graph.requestAccepted:=graph.requestAccepted and graph.forwardCompatible;
  end;
 begin
   result:=0;
   requestedProfile:=graph.profile;
   requestedDebug:=graph.debugContext;
   effectiveDebug:=requestedDebug;
   requestedForward:=graph.forwardCompatible;
   SetupPixelFormat;
   PrepareContextCreationPath;
   TryCreateModernContext;
   FinalizeContextSelection;
   ApplyActualGraphInfo;
   // Keep graph flags consistent with actual created context.
   if RC=0 then
    raise EError.Create('Can''t create OpenGL context (shared=%d, min=%d.%d, profile=%d, debug=%d, forward=%d)',
      [integer(shareWith<>0),graph.minMajor,graph.minMinor,integer(requestedProfile),ord(requestedDebug),ord(requestedForward)]);
   context:=RC;
   result:=context;
  end;

procedure TWinGLWindow.InitGraph;
begin
  with graphInfo do begin
    minMajor:=oglContextTemplate.minMajor;
    minMinor:=oglContextTemplate.minMinor;
    profile:=oglContextTemplate.profile;
    debugContext:=oglContextTemplate.debugContext;
    forwardCompatible:=oglContextTemplate.forwardCompatible;
    preferHighest:=oglContextTemplate.preferHighest;
    actualMajor:=0;
    actualMinor:=0;
    requestAccepted:=false;
  end;
  CreateOpenGLContext(graphInfo);
  oglContextInfo:=graphInfo;
end;

procedure TWinGLWindow.InitGraphShared(primary:TWindow;mainContextReleased:boolean=false);
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
  if not mainContextReleased then begin
   Atomic.Exchange(glShareState,glcsReleaseRequested);
   Log.Msg('AddWindow: requesting GL context release from main thread');
   while glShareState<>glcsReleased do
    CoreTime.Sleep(1);
   Log.Msg('AddWindow: main thread released GL context');
  end else
   Log.Msg('AddWindow: main thread context already released by caller');
  try
   CreateOpenGLContext(graphInfo,src.context);
   oglContextInfo:=graphInfo;
   SetupGLDebugOutputForCurrentContext(graphInfo,'secondary:'+name);
   // core profile requires a bound VAO before any draw call
   if graphInfo.profile=oglpCore then begin
    vao:=0;
    glGenVertexArrays(1,@vao);
    glBindVertexArray(vao);
    contextVAO:=vao;
    Log.Msg('Extra window VAO created: %d',[vao]);
   end;
  finally
   if not mainContextReleased then
    Atomic.Exchange(glShareState,glcsReady); // signal main thread to reacquire
  end;
 end;

procedure TWinGLWindow.PresentFrame;
 var
  DC:HDC;
 begin
   // Service deferred handoff request on the main window thread.
   if self=mainWindow then
    if Atomic.CmpExchange(glShareState,glcsReleased,glcsReleaseRequested)=glcsReleaseRequested then begin
     ReleaseGraphContext;
     Log.Msg('Main thread released GL context for AddWindow');
     while glShareState<>glcsReady do
      CoreTime.Sleep(1);
     ActivateGraphContext;
     Log.Msg('Main thread reacquired GL context');
    end;
   DC:=getDC(window);
   if not SwapBuffers(DC) then
    Log.Msg('Swap error: %d',[GetLastError]);
   ReleaseDC(window,DC);
 end;

function TWinGLWindow.SetVSync(divider: integer): boolean;
 begin
  result:=WGL_EXT_swap_control;
  if result then wglSwapIntervalEXT(divider);
  if result then
   Log.Msg('VSync (window): swap interval=%d',[divider]);
 end;

procedure TWinGLWindow.DoneGraph;
 begin
  if contextVAO<>0 then begin
   glDeleteVertexArrays(1,@contextVAO);
   Log.Msg('Extra window VAO deleted: %d',[contextVAO]);
   contextVAO:=0;
  end;
  if context<>0 then begin
   wglMakeCurrent(0,0);
   wglDeleteContext(context);
  end;
  context:=0;
 end;

procedure TWinGLWindow.ReleaseGraphContext;
 begin
  wglMakeCurrent(0,0);
 end;

procedure TWinGLWindow.ActivateGraphContext;
 var
  dc:HDC;
 begin
  if context=0 then exit;
  dc:=GetDC(window);
  if not wglMakeCurrent(dc,context) then
   Log.Warn('Failed to activate GL context: %d',[GetLastError]);
  ReleaseDC(window,dc);
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
   Log.Msg('WindowRect: %d:%d',[r.Right-r.Left,r.Bottom-r.top]);
   GetClientRect(window,r);
   Log.Msg('ClientRect: %d:%d',[r.Right-r.Left,r.Bottom-r.top]);
   // Eagerly initialize displayRect so ClientToGame is safe before SetupRenderArea runs.
   if (displayRect.Width=0) or (displayRect.Height=0) then begin
    windowWidth:=r.Width; windowHeight:=r.Height;
    displayRect:=r;
    renderWidth:=r.Width; renderHeight:=r.Height;
   end;
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
