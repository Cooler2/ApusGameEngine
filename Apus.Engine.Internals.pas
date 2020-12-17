// Interfaces and types for internal use
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
unit Apus.Engine.Internals;
interface
uses Apus.CrossPlatform, Apus.Geom2D, Apus.Geom3D, Apus.Images;

type
 // 2D points
 TPoint2 = Apus.Geom2D.TPoint2;
 PPoint2 = Apus.Geom2D.PPoint2;
 TPoint2s = Apus.Geom2D.TPoint2s;
 PPoint2s = ^TPoint2s;
 // 3D Points
 TPoint3 = Apus.Geom3D.TPoint3;
 PPoint3 = ^TPoint3;
 TPoint3s = Apus.Geom3D.TPoint3s;
 PPoint3s = ^TPoint3s;
 // Matrices
 T3DMatrix = TMatrix4;
 T3DMatrixS = TMatrix4s;
 T2DMatrix = TMatrix32s;

 TRect2s = Apus.Geom2D.TRect2s;

 ISystemPlatform=interface
  // System information
  function CanChangeSettings:boolean;
  procedure GetScreenSize(out width,height:integer);
  function GetScreenDPI:integer;
  // Window management
  procedure CreateWindow(title:string); // Create main window
  procedure DestroyWindow;
  procedure SetupWindow; // Configure/update window properties
  procedure ShowWindow(show:boolean);
  function GetWindowHandle:THandle;
  procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0);
  procedure SetWindowCaption(text:string);
  procedure Minimize;
  procedure FlashWindow(count:integer);
  // Event management
  procedure ProcessSystemMessages;

  // System functions
  function GetSystemCursor(cursorId:integer):THandle;
  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetMousePos:TPoint; // Get mouse position on screen (screen may mean client when platform doesn't support real screen space)
  function GetMouseButtons:cardinal;
  function GetShiftKeysState:cardinal;

  // Translate coordinates between screen and window client area
  procedure ScreenToClient(var p:TPoint);
  procedure ClientToScreen(var p:TPoint);

  // OpenGL support
  procedure OGLSwapBuffers;
 end;

 IGraphicsSystem=interface
  procedure Init(system:ISystemPlatform);
  function GetVersion:single; // like 3.1 for OpenGL 3.1
  procedure ChoosePixelFormats(out trueColor,trueColorAlpha,rtTrueColor,rtTrueColorAlpha:TImagePixelFormat;
    economyMode:boolean=false);

  function CreatePainter:TObject;
  function ShouldUseTextureAsDefaultRT:boolean;
  function SetVSyncDivider(n:integer):boolean; // 0 - unlimited FPS, 1 - use monitor refresh rate
  procedure CopyFromBackbuffer(srcX,srcY:integer;image:TRawImage);

  procedure PresentFrame(system:ISystemPlatform);
 end;


implementation

end.
