// Platform-independent implementation of the graphics APIs
//
// Copyright (C) 2021 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Graphics;
interface
 uses Types,Apus.Engine.API;

type
 // For internal use only - built-in buffers
 TPainterBuffer=(noBuf,
                 vertBuf,       // буфер вершин для отрисовки партиклов
                 partIndBuf,    // буфер индексов для отрисовки прямоугольников (партиклов, символов текста и т.п)
                 bandIndBuf,    // буфер индексов для отрисовки полос/колец
                 textVertBuf);  // буфер вершин для вывода текста

 IRenderDevice=interface
  // Draw primitives using in-memory buffers
  procedure Draw(primType,primCount:integer;vertices:pointer;stride:integer); overload;
  // Draw primitives using built-in buffer
  procedure Draw(primType,primCount,vrtStart:integer;
     vertexBuf:TPainterBuffer;stride:integer); overload;

  // Draw indexed  primitives using in-memory buffers
  procedure DrawIndexed(primType:integer;vertexBuf:PVertex;indBuf:PWord;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer);  overload;
  // Draw indexed  primitives using built-in buffer
  procedure DrawIndexed(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer);  overload;

  // Access to the built-in buffers
  // !!! Offset is measured in buffer units, not bytes! size - in bytes!  TODO: заменить байты на юниты
  function LockBuffer(buf:TPainterBuffer;offset,size:cardinal):pointer;
  procedure UnlockBuffer(buf:TPainterBuffer);
 end;

 TTransformationAPI=class(TInterfacedObject,ITransformation)
  viewMatrix:T3DMatrix; // current view (camera) matrix
  objMatrix:T3DMatrix; // current object (model) matrix
  projMatrix:T3DMatrix; // current projection matrix

  constructor Create;
  procedure DefaultView; virtual;
  procedure Perspective(fov:single;zMin,zMax:double); overload; virtual;
  procedure Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); overload;
  procedure Orthographic(scale,zMin,zMax:double);
  procedure SetView(view:T3DMatrix);
  procedure SetCamera(origin,target,up:TPoint3;turnCW:double=0);
  procedure SetObj(mat:T3DMatrix); overload;
  procedure SetObj(oX,oY,oZ:single;scale:single=1;yaw:single=0;roll:single=0;pitch:single=0); overload;
  function GetMVPMatrix:T3DMatrix;
 type
  TMatrixType=(mtModelView,mtProjection);
 protected
  procedure SetMatrix(mType:TMatrixType;const mat:T3DMatrix); virtual;
 end;

 TClipping=class(TInterfacedObject,IClipping)
  procedure Rect(r:TRect;combine:boolean=true);  //< Set clipping rect (combine with previous or override), save previous
  procedure Nothing; //< don't clip anything, save previous (the same as Apply() for the whole render target area)
  procedure Restore; //< restore previous clipping rect
  function  Get:TRect; //< return current clipping rect
 end;

 TRenderTargetAPI=class(TInterfacedObject,IRenderTarget)
  constructor Create;

  procedure UseBackbuffer; virtual;
  procedure UseTexture(tex:TTexture); virtual;
  procedure Push; virtual;
  procedure Pop; virtual;
  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); virtual; abstract;
  procedure UseAsDefault(rt:TTexture); virtual;
  procedure SetDefaultRenderArea(oX,oY,VPwidth,VPheight,renderWidth,renderHeight:integer); virtual;
  procedure UseDepthBuffer(test:TDepthBufferTest;writeEnable:boolean=true); virtual;
  procedure BlendMode(blend:TBlendingMode); virtual; abstract;
  procedure Mask(rgb:boolean;alpha:boolean); virtual;
  procedure UnMask; virtual;

  function renderWidth:integer;
  function renderHeight:integer;
 private
  screenRect:TRect;
 end;

var
 renderDevice:IRenderDevice;
 renderTargetAPI:TRenderTargetAPI;

implementation
 uses Math, Apus.Geom3D;

{ TTransformationsAPI }

constructor TTransformationAPI.Create;
 begin
  viewMatrix:=IdentMatrix4;
  objMatrix:=IdentMatrix4;
  projMatrix:=IdentMatrix4;
 end;

procedure TTransformations.DefaultView;
 begin

 end;

function TTransformations.GetMVPMatrix: T3DMatrix;
 begin

 end;

procedure TTransformations.Orthographic(scale, zMin, zMax: double);
 begin

 end;

procedure TTransformations.Perspective(xMin, xMax, yMin, yMax, zScreen, zMin,
  zMax: double);
 var
  A,B,C,D:single;
 begin
  A:=(xMax+xMin)/(xMax-xMin);
  B:=(yMin+yMax)/(yMin-yMax);
  C:=zMax/(zMax-zMin);
  D:=zMax*zMin/(zMin-zMax);
  projMatrix[0,0]:=2*zScreen/(xMax-xMin);    projMatrix[1,0]:=0;    projMatrix[2,0]:=A;     projMatrix[3,0]:=0;
  projMatrix[0,1]:=0;      projMatrix[1,1]:=2*zScreen/(yMax-yMin);  projMatrix[2,1]:=B;     projMatrix[3,1]:=0;
  projMatrix[0,2]:=0;      projMatrix[1,2]:=0;                      projMatrix[2,2]:=C;     projMatrix[3,2]:=D;
  projMatrix[0,3]:=0;      projMatrix[1,3]:=0;                      projMatrix[2,3]:=1;     projMatrix[3,3]:=0;
 end;

procedure TTransformations.Perspective(fov: single; zMin, zMax: double);
 var
  x,y,aspect:single;
 begin
  x:=tan(fov/2);
  y:=x;
  aspect:=renderWidth/renderHeight;
  if aspect>1 then y:=y/aspect
   else x:=x*aspect;
  Perspective(-x,x,-y,y,1,zMin,zMax);
 end;

procedure TTransformations.SetCamera(origin, target, up: TPoint3;
  turnCW: double);
 var
  mat:TMatrix4;
  v1,v2,v3:TVector3;
 begin
  v1:=Vector3(origin,target);
  Normalize3(v1);
  v2:=Vector3(origin,up);
  v3:=CrossProduct3(v2,v1);
  Normalize3(v3); // Right vector
  v2:=CrossProduct3(v3,v1); // Down vector
  mat[0,0]:=v3.x; mat[0,1]:=v3.y; mat[0,2]:=v3.z; mat[0,3]:=0;
  mat[1,0]:=v2.x; mat[1,1]:=v2.y; mat[1,2]:=v2.z; mat[1,3]:=0;
  mat[2,0]:=v1.x; mat[2,1]:=v1.y; mat[2,2]:=v1.z; mat[2,3]:=0;
  mat[3,0]:=origin.x; mat[3,1]:=origin.y; mat[3,2]:=origin.z; mat[3,3]:=1;
  SetView(mat);
 end;

procedure TTransformations.SetObj(oX, oY, oZ, scale, yaw, roll,
  pitch: single);
 var
  m,m2:T3DMatrix;
  i,j:integer;
 begin
  // rotation
  if (yaw<>0) or (roll<>0) or (pitch<>0) then
   m:=MatrixFromYawRollPitch4(yaw,roll,pitch)
  else
   m:=IdentMatrix4;
  // scale
  if scale<>1 then
   for i:=0 to 2 do
    for j:=0 to 2 do
     m[i,j]:=m[i,j]*scale;
  // position
  MultMat4(TranslationMat4(ox,oy,oz),m,m2);

  SetObj(m2);
 end;

procedure TTransformations.SetObj(mat: T3DMatrix);
 begin
  objMatrix:=mat;
 end;

procedure TTransformations.SetView(view: T3DMatrix);
 begin

 end;

{ TRenderTargetAPI }

constructor TRenderTargetAPI.Create;
 begin

 end;

procedure TRenderTargetAPI.Mask(rgb, alpha: boolean);
 begin

 end;

procedure TRenderTargetAPI.Pop;
 begin

 end;

procedure TRenderTargetAPI.Push;
 begin

 end;

function TRenderTargetAPI.renderHeight: integer;
 begin

 end;

function TRenderTargetAPI.renderWidth: integer;
 begin

 end;

procedure TRenderTargetAPI.SetDefaultRenderArea(oX, oY, VPwidth, VPheight,
  renderWidth, renderHeight: integer);
 begin

 end;

procedure TRenderTargetAPI.UnMask;
 begin

 end;

procedure TRenderTargetAPI.UseAsDefault(rt: TTexture);
 begin

 end;

procedure TRenderTargetAPI.UseBackbuffer;
 begin

 end;

procedure TRenderTargetAPI.UseDepthBuffer(test: TDepthBufferTest;
  writeEnable: boolean);
 begin

 end;

procedure TRenderTargetAPI.UseTexture(tex: TTexture);
 begin

 end;

end.
