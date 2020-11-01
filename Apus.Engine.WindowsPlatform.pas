unit Apus.Engine.WindowsPlatform;
interface
uses Apus.Engine.Internals;

type
 TWindowsPlatform=class(TSystemPlatform)
  class function CanChangeSettings:boolean; override;
  class procedure GetScreenSize(out width,height:integer); override;
  class function GetScreenDPI:integer; override;

  class procedure InitWindow; override;
  class procedure ShowWindow(show:boolean); override;
  class procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0); override;
  class procedure SetWindowCaption(text:string); override;
  class procedure Minimize; override;

  class function GetSystemCursor(cursorId:integer):THandle; override;
 end;

implementation
uses Windows, Apus.Engine.API;

var
  window:HWND;

  layoutList:array[1..10] of HKL; // Keyboard layouts (workaround to fix windows freeze)
  layouts:integer;

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


{ TWindowsPlatform }

class function TWindowsPlatform.CanChangeSettings: boolean;
 begin
  result:=true;
 end;

class function TWindowsPlatform.GetScreenDPI: integer;
 var
  dc:HDC;
 begin
  dc:=GetDC(0);
  ASSERT(dc<>0);
  result:=GetDeviceCaps(dc,LOGPIXELSX);
  ReleaseDC(0,dc);
 end;

class procedure TWindowsPlatform.GetScreenSize(out width, height: integer);
 begin
  width:=GetSystemMetrics(SM_CXSCREEN);
  height:=GetSystemMetrics(SM_CYSCREEN);
 end;

class function TWindowsPlatform.GetSystemCursor(cursorId: integer): THandle;
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

class procedure TWindowsPlatform.InitWindow;
 begin

 end;

class procedure TWindowsPlatform.Minimize;
 begin
  ShowWindow(window,SW_MINIMIZE);
 end;

class procedure TWindowsPlatform.MoveWindowTo(x, y, width, height: integer);
 begin

 end;

class procedure TWindowsPlatform.SetWindowCaption(text: string);
 begin

 end;

class procedure TWindowsPlatform.ShowWindow(show: boolean);
 begin
 LoadCursor(0,IDC_ARROW)
  if show then
   ShowWindow(window,SW_SHOWNORMAL)
  else
   ShowWindow(window,SW_HIDE);
 end;

end.
