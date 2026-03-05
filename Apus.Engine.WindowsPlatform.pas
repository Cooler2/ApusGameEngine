// Windows-specific functions used by Game object
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.WindowsPlatform;
interface
uses Windows, Apus.Types, Apus.Core, Apus.Engine.API, Apus.Engine.Keys;

type
 
 { TWindowsPlatform }

 TWindowsPlatform=class(TInterfacedObject,ISystemPlatform)
  constructor Create;
  function GetPlatformName:string;
  function CanChangeSettings:boolean;
  procedure GetScreenSize(out width,height:integer);
  procedure GetRealScreenSize(out width,height:integer);
  function GetScreenDPI:integer;

  procedure CreateWindow(title:string);
  procedure SetupWindow(params:TGameSettings);
  function GetWindowHandle:THandle;
  procedure GetWindowSize(out width,height:integer);
  procedure DestroyWindow;

  procedure ShowWindow(show:boolean);
  procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0);
  procedure SetWindowCaption(text:string);
  procedure Minimize;
  procedure FlashWindow(count:integer);

  procedure ProcessSystemMessages;
  function IsTerminated:boolean;

  function GetMousePos:TPoint; // Get mouse position on screen
  procedure SetMousePos(scrX,scrY:integer); // Move mouse cursor (screen coordinates)
  function GetSystemCursor(cursorId:integer):THandle;
  function LoadCursor(filename:string):THandle;
  procedure SetCursor(cur:THandle);
  procedure FreeCursor(cur:THandle);
  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetShiftKeysState:cardinal;
  function GetMouseButtons:cardinal;

  procedure ScreenToClient(var p:TPoint);
  procedure ClientToScreen(var p:TPoint);

  function CreateOpenGLContext(const request:TOpenGLContextRequest;out actual:TOpenGLContextInfo):UIntPtr;
  procedure OGLSwapBuffers;
  function SetSwapInterval(divider:integer):boolean;
  procedure DeleteOpenGLContext;
 private
  window:HWND;
  context:UIntPtr;
 end;

implementation
uses Messages, Types, SysUtils, Apus.EventMan,
  Apus.Log, Apus.Strings
  {$IFDEF MSWINDOWS},dglOpenGL{$ENDIF};
{$IFOPT R+} {$DEFINE RANGECHECK_ON} {$ENDIF}
var
 terminated:boolean;
 noPenAPI:boolean=false;

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
   Log.Msg('WM_Destroy');
   terminated:=true;
   Signal('Engine\Cmd\Exit',0);
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

procedure TWindowsPlatform.ClientToScreen(var p: TPoint);
 begin
  windows.ClientToScreen(window,p);
 end;

procedure TWindowsPlatform.DestroyWindow;
 begin
  windows.ShowWindow(window,SW_HIDE);
  windows.DestroyWindow(window);
  UnregisterClassA('GameWindowClass',0);
 end;

procedure TWindowsPlatform.FlashWindow(count: integer);
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

procedure TWindowsPlatform.ScreenToClient(var p: TPoint);
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

function TWindowsPlatform.GetWindowHandle: THandle;
 begin
  result:=window;
 end;

procedure TWindowsPlatform.GetWindowSize(out width, height: integer);
 var
  r:TRect;
 begin
  GetClientRect(window,r);
  width:=r.Width; height:=r.Height;
 end;

procedure TWindowsPlatform.CreateWindow(title: string);
 var
  WindowClass:TWndClassW;
  style:cardinal;
  i:integer;
 begin
   Log.Msg('CreateMainWindow');
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
   If windows.RegisterClassW(WindowClass)=0 then
    raise EFatalError.Create('Cannot register window class');

   style:=0;
   Window:=windows.CreateWindowW('GameWindowClass', PWideChar(WideString(title)),
    style, 0, 0, 100, 100, 0, 0, HInstance, nil);
   //SetWindowLong(window,GWL_WNDPROC,longint(@WindowProc));
   //SetWindowCaption(title);
  end;

procedure TWindowsPlatform.ProcessSystemMessages;
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

function TWindowsPlatform.IsTerminated:boolean;
 begin
  result:=terminated;
 end;

procedure TWindowsPlatform.Minimize;
 begin
  windows.ShowWindow(window,SW_MINIMIZE);
 end;

procedure TWindowsPlatform.MoveWindowTo(x, y: integer; width: integer;
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

function TWindowsPlatform.CreateOpenGLContext(const request:TOpenGLContextRequest;out actual:TOpenGLContextInfo):UIntPtr;
 type
  TglGetStringFn=function(name:cardinal):PAnsiChar; stdcall;
 var
  DC:HDC;
  RC,legacyRC:HGLRC;
  PFD:TPixelFormatDescriptor;
  pf:integer;
  requestedMajor,requestedMinor:integer;
  availMajor,availMinor:integer;
  attribs:array[0..15] of integer;
  n,flags,profileMask:integer;
  glVer:string;
  glVerRaw:PAnsiChar;
  openglLib:HMODULE;
  glGetStringFn:TglGetStringFn;
  wglCreateContextAttribsARB:function(hDC:HDC;hShareContext:HGLRC;const attribList:PInteger):HGLRC; stdcall;
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
   requestedMajor:=request.minMajor;
   requestedMinor:=request.minMinor;
   if request.preferHighest then begin
    requestedMajor:=availMajor;
    requestedMinor:=availMinor;
   end;

   if (request.profile<>glcpCompatibility) or request.debugContext or request.forwardCompatible then begin
    if (availMajor>request.minMajor) or ((availMajor=request.minMajor) and (availMinor>=request.minMinor)) then begin
     @wglCreateContextAttribsARB:=wglGetProcAddress('wglCreateContextAttribsARB');
     if assigned(wglCreateContextAttribsARB) then begin
      n:=0;
      attribs[n]:=WGL_CONTEXT_MAJOR_VERSION_ARB; inc(n);
      attribs[n]:=requestedMajor; inc(n);
      attribs[n]:=WGL_CONTEXT_MINOR_VERSION_ARB; inc(n);
      attribs[n]:=requestedMinor; inc(n);
      profileMask:=0;
      case request.profile of
       glcpCore:profileMask:=WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
       glcpCompatibility:profileMask:=WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;
      end;
      if profileMask<>0 then begin
       attribs[n]:=WGL_CONTEXT_PROFILE_MASK_ARB; inc(n);
       attribs[n]:=profileMask; inc(n);
      end;
      flags:=0;
      if request.debugContext then flags:=flags or WGL_CONTEXT_DEBUG_BIT_ARB;
      if request.forwardCompatible then flags:=flags or WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB;
      if flags<>0 then begin
       attribs[n]:=WGL_CONTEXT_FLAGS_ARB; inc(n);
       attribs[n]:=flags; inc(n);
      end;
      attribs[n]:=0;
      RC:=wglCreateContextAttribsARB(DC,0,@attribs[0]);
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
   if (request.profile=glcpCore) and (RC=legacyRC) then begin
    wglMakeCurrent(0,0);
    wglDeleteContext(legacyRC);
    RC:=0;
   end;
   actual.major:=0;
   actual.minor:=0;
   if request.profile=glcpCore then
    actual.profile:=glcpCore
   else
    actual.profile:=glcpCompatibility;
   actual.debugContext:=false;
   actual.forwardCompatible:=false;
   actual.requestAccepted:=RC<>0;
   context:=RC;
   result:=context;
  end;

procedure TWindowsPlatform.OGLSwapBuffers;
 var
  DC:HDC;
 begin
   DC:=getDC(window);
   if not SwapBuffers(DC) then
    Log.Msg('Swap error: '+IntToStr(GetLastError));
   ReleaseDC(window,DC);
 end;

function TWindowsPlatform.SetSwapInterval(divider: integer): boolean;
 begin
  result:=false;
 end;

procedure TWindowsPlatform.DeleteOpenGLContext;
 begin
  if context<>0 then
   wglDeleteContext(context);
 end;

procedure TWindowsPlatform.SetupWindow(params:TGameSettings);
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
      MoveWindowTo(r.left,r.top, r.width,r.height);
    end;
    dmSwitchResolution,dmFullScreen:begin
      SetWindowLong(window,GWL_STYLE,longint(ws_popup));
      MoveWindowTo(0,0,game.screenWidth,game.screenHeight);
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

procedure TWindowsPlatform.SetWindowCaption(text: string);
 var
  wst:String16;
  t:PWideChar;
 begin
  wst:=Str16(text);
  t:=@wst[1];
  SetWindowTextW(window,t);
 end;

procedure TWindowsPlatform.ShowWindow(show: boolean);
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
