// Interfaces and types for internal use
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
unit Apus.Engine.Internals;
interface
uses Types, Apus.Geom2D, Apus.Geom3D;

type
 // 2D points
 TPoint2 = Apus.Geom2D.TPoint2;
 PPoint2 = ^TPoint2;
 TPoint2s = Apus.Geom2D.TPoint2s;
 PPoint2s = ^TPoint2s;
 // 3D Points
 TPoint3 = Apus.Geom3D.TPoint3;
 PPoint3 = ^TPoint3;
 TPoint3s = Apus.Geom3D.TPoint3s;
 PPoint3s = ^TPoint3s;
 // Matrices
 T3DMatrix = TMatrix4;
 T2DMatrix = TMatrix32s;

 TRect2s = Apus.Geom2D.TRect2s;

 TSystemPlatform=class
  // System information
  class function CanChangeSettings:boolean; virtual;
  class procedure GetScreenSize(out width,height:integer); virtual; abstract;
  class function GetScreenDPI:integer; virtual; abstract;
  // Window management
  class procedure InitWindow; virtual; abstract;
  class procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0); virtual; abstract;
  class procedure SetWindowCaption(text:string); virtual; abstract;
  class procedure Minimize; virtual; abstract;
  class procedure ShowWindow(show:boolean); virtual; abstract;
  class procedure FlashWindow(count:integer); virtual;
  // System
  class function GetSystemCursor(cursorId:integer):THandle; virtual; abstract;
 end;

implementation
uses Apus.EventMan;

class function TSystemPlatform.CanChangeSettings:boolean;
 begin
  result:=false;
 end;

class procedure TSystemPlatform.FlashWindow(count:integer);
 begin
  Signal('Engine\Cmd\Flash',count);
 end;

end.
