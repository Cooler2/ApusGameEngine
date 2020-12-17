// Windows-specific functions used by Game object
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.WindowsPlatform;
interface
uses Apus.CrossPlatform, Apus.Engine.Internals;

type
 TWindowsPlatform=class(TInterfacedObject,ISystemPlatform)
  function CanChangeSettings:boolean;
  procedure GetScreenSize(out width,height:integer);
  function GetScreenDPI:integer;

  procedure CreateWindow(title:string);
  procedure SetupWindow;
  function GetWindowHandle:THandle;
  procedure DestroyWindow;

  procedure ShowWindow(show:boolean);
  procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0);
  procedure SetWindowCaption(text:string);
  procedure Minimize;
  procedure FlashWindow(count:integer);

  procedure ProcessSystemMessages;

  function GetMousePos:TPoint; // Get mouse position on screen
  function GetSystemCursor(cursorId:integer):THandle;
  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetShiftKeysState:cardinal;
  function GetMouseButtons:cardinal;

  procedure ScreenToClient(var p:TPoint);
  procedure ClientToScreen(var p:TPoint);

  procedure OGLSwapBuffers;
 private
  window:HWND;
 end;

implementation
uses Windows, Messages, Types, Apus.MyServis, Apus.Engine.API, SysUtils, Apus.EventMan, Apus.Engine.Game;

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

{$IF Declared(SetProcessDPIAware)} {$ELSE}
function SetProcessDPIAware:BOOL; external user32 name 'SetProcessDPIAware';
{$IFEND}

function WindowProc(Window:HWnd;Message,WParam:Longint;LParam:LongInt):LongInt; stdcall;
var
 i,c:integer;
 key:cardinal;
 wst:WideString;
 st:string;
 pnt:TPoint;
 scancode:word;
 scene:TGameScene;
 sysCursor:boolean;
begin
 if game=nil then
  Exit(DefWindowProcW(Window,Message,WParam,LParam));

 try
 game.EnterCritSect;

 result:=0;
 case Message of
  wm_Destroy: Signal('Engine\Cmd\Exit',0);

  WM_MOUSEMOVE:begin
    sysCursor:=game.GetSettings.showSystemCursor;
    if not sysCursor then SetCursor(0);
    pnt:=Point(SmallInt(LoWord(lParam)),SmallInt(HiWord(lParam)));
    ClientToScreen(window,pnt);
    game.ScreenToGame(pnt);
    game.MouseMovedTo(pnt.x,pnt.y);
  end;

  WM_MOUSELEAVE:game.MouseMovedTo(8191,8191);

  WM_UNICHAR:begin
//   LogMessage(inttostr(wparam)+' '+inttostr(lparam));
  end;

  WM_CHAR:game.CharEntered(wparam,lparam shr 16);

  WM_KEYDOWN,WM_SYSKEYDOWN:begin
    // wParam = Virtual Code lParam[23..16] = Scancode
    scancode:=(lParam shr 16) and $FF;
    game.KeyPressed(wParam,scanCode,true);
  end;

  WM_KEYUP,WM_SYSKEYUP:begin
    scancode:=(lParam shr 16) and $FF;
    game.KeyPressed(wParam,scancode,false);
    if message=WM_SYSKEYUP then exit(0);
  end;

  WM_SYSCHAR:begin
    result:=0; exit;
    scancode:=(lParam shr 16) and $FF;
//    Signal('KBD\KeyDown',wParam and $FFFF+game.shiftState shl 16+scancode shl 24);
  end;

  WM_LBUTTONDOWN,WM_RBUTTONDOWN,WM_MBUTTONDOWN:begin
    SetCapture(window);
    if not game.GetSettings.showSystemCursor then SetCursor(0);
    if message=wm_LButtonDown then game.MouseButtonPressed(1,true) else
    if message=wm_RButtonDown then game.MouseButtonPressed(2,true) else
    if message=wm_MButtonDown then game.MouseButtonPressed(3,true);
  end;

  WM_LBUTTONUP,WM_RBUTTONUP,WM_MBUTTONUP:begin
    ReleaseCapture;
    if not game.GetSettings.showSystemCursor then SetCursor(0);
    c:=0;
    if message=wm_LButtonUp then game.MouseButtonPressed(1,false) else
    if message=wm_RButtonUp then game.MouseButtonPressed(2,false) else
    if message=wm_MButtonUp then game.MouseButtonPressed(3,false);
  end;

  WM_MOUSEWHEEL:game.MouseWheelMoved(wParam div 65536);

  WM_SIZE:if game.active and (lParam>0) then
   game.SizeChanged(lParam and $FFFF,lParam shr 16);

  WM_ACTIVATE:game.Activate(loword(wparam)<>wa_inactive);

  WM_HOTKEY:if wparam=312 then game.RequestScreenshot(true); // ???
 end;

 result:=DefWindowProcW(Window,Message,WParam,LParam);
 finally
  game.LeaveCritSect;
 end;
end;

{ TWindowsPlatform }

function TWindowsPlatform.CanChangeSettings: boolean;
 begin
  result:=true;
 end;

procedure TWindowsPlatform.ClientToScreen;
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
  fillchar(fi,sizeof(fi),0);
  fi.cbSize:=sizeof(fi);
  fi.hwnd:=window;
  fi.dwTimeout:=400;
  if count=-1 then
   fi.dwFlags:=FLASHW_STOP
  else
   fi.dwFlags:=FLASHW_ALL+FLASHW_TIMERNOFG*byte(count=0);
  if count<=0 then count:=100;
  fi.uCount:=count;
  FlashWindowEx(fi);
 end;

procedure TWindowsPlatform.ScreenToClient;
 begin
  windows.ScreenToClient(window,p);
 end;

function TWindowsPlatform.GetMousePos: TPoint;
 begin
  GetCursorPos(result);
  ScreenToClient(result);
 end;

function TWindowsPlatform.GetScreenDPI: integer;
 var
  dc:HDC;
 begin
  dc:=GetDC(0);
  ASSERT(dc<>0);
  result:=GetDeviceCaps(dc,LOGPIXELSX);
  ReleaseDC(0,dc);
 end;

procedure TWindowsPlatform.GetScreenSize(out width, height: integer);
 begin
  width:=GetSystemMetrics(SM_CXSCREEN);
  height:=GetSystemMetrics(SM_CYSCREEN);
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
   crDefault:name:=IDC_ARROW;
   crLink:name:=IDC_HAND;
   crWait:name:=IDC_WAIT;
   crInput:name:=IDC_IBEAM;
   crHelp:name:=IDC_HELP;
   crResizeH:name:=IDC_SIZENS;
   crResizeW:name:=IDC_SIZEWE;
   crResizeHW:name:=IDC_SIZEALL;
   crCross:name:=IDC_CROSS;
  end;
  result:=LoadCursor(0,name);
 end;

function TWindowsPlatform.GetWindowHandle: THandle;
 begin
  result:=window;
 end;

procedure TWindowsPlatform.CreateWindow;
 var
  WindowClass:TWndClass;
  style:cardinal;
  i:integer;
 begin
   LogMessage('CreateMainWindow');
   with WindowClass do begin
    Style:=cs_HRedraw or cs_VRedraw;
    lpfnWndProc:=@WindowProc;
    cbClsExtra:=0;
    cbWndExtra:=0;
    hInstance:=0;
    hIcon:=LoadIcon(MainInstance,'MAINICON');
    hCursor:=0;
    hbrBackground:=GetStockObject (Black_Brush);
    lpszMenuName:='';
    lpszClassName:='GameWindowClass';
   end;
   If windows.RegisterClass(WindowClass)=0 then
    raise EFatalError.Create('Cannot register window class');

   style:=0;
   Window:=windows.CreateWindow('GameWindowClass', PChar(title),
    style, 0, 0, 100, 100, 0, 0, HInstance, nil);
   SetWindowLongW(window,GWL_WNDPROC,cardinal(@WindowProc));
   SetWindowCaption(title);
  end;

procedure TWindowsPlatform.ProcessSystemMessages;
 var
  mes:TagMSG;
 begin
  while PeekMessageW(mes,0,0,0,pm_NoRemove) do begin
    if not GetMessageW(mes,0,0,0) then
     raise EWarning.Create('Failed to get message');

    if mes.message=wm_quit then // Если послана команда на выход
     Signal('Engine\Cmd\Exit',0);

    TranslateMessage(Mes);
    DispatchMessageW(Mes);
   end;
 end;

procedure TWindowsPlatform.Minimize;
 begin
  windows.ShowWindow(window,SW_MINIMIZE);
 end;

procedure TWindowsPlatform.MoveWindowTo(x, y, width, height: integer);
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
   ForceLogMessage('MoveWindow error: '+inttostr(GetLastError));
 end;

procedure TWindowsPlatform.OGLSwapBuffers;
 var
  DC:HDC;
 begin
   DC:=getDC(window);
   if not SwapBuffers(DC) then
    LogMessage('Swap error: '+IntToStr(GetLastError));
   ReleaseDC(window,DC);
 end;

procedure TWindowsPlatform.SetupWindow;
 var
  r,r2:TRect;
  style:cardinal;
  w,h:integer;
  params:TGameSettings;
 begin
   LogMessage('Configure main window');
   params:=game.GetSettings;
   style:=ws_popup;
   if params.mode.displayMode=dmWindow then inc(style,WS_SIZEBOX+WS_MAXIMIZEBOX);
   if params.mode.displayMode in [dmWindow,dmFixedWindow] then
    inc(style,ws_Caption+WS_MINIMIZEBOX+WS_SYSMENU);

   SystemParametersInfo(SPI_GETWORKAREA,0,@r2,0);
   w:=params.width;
   h:=params.height;

   case params.mode.displayMode of
    dmWindow,dmFixedWindow:begin
      r:=Rect(0,0,w,h);
      AdjustWindowRect(r,style,false);
      r.Offset(-r.left,-r.top);
      // If window is too large
      r.Right:=Clamp(r.Right,0,r2.Width);
      r.Bottom:=Clamp(r.Bottom,0,r2.Height);
      // Center window
      r.Offset((r2.Width-r.Width) div 2,(r2.Height-r.Height) div 2);
      SetWindowLong(window,GWL_STYLE,style);
      MoveWindowTo(r.left,r.top, r.width,r.height);
    end;
    dmSwitchResolution,dmFullScreen:begin
      SetWindowLong(window,GWL_STYLE,integer(ws_popup));
      MoveWindowTo(0,0,game.screenWidth,game.screenHeight);
    end;
   end;

   windows.ShowWindow(Window, SW_SHOW);
   UpdateWindow(Window);

   GetWindowRect(window,r);
   LogMessage('WindowRect: '+inttostr(r.Right-r.Left)+':'+inttostr(r.Bottom-r.top));
   GetClientRect(window,r);
   LogMessage('ClientRect: '+inttostr(r.Right-r.Left)+':'+inttostr(r.Bottom-r.top));
   game.SizeChanged(r.Width,r.Height);
   game.screenChanged:=true;
 end;

procedure TWindowsPlatform.SetWindowCaption(text: string);
 var
  wst:WideString;
 begin
  wst:=text;
  SetWindowTextW(window,PWideChar(wst))
 end;

procedure TWindowsPlatform.ShowWindow(show: boolean);
 begin
  LoadCursor(0,IDC_ARROW);
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
