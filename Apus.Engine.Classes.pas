// Platform-independent implementation of the engine APIs
//
// Copyright (C) 2021 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Classes;
interface
 uses Types,Apus.Engine.API;

type
 TTransformationsAPI=class(TInterfacedObject,ITransformation)
  viewMatrix:T3DMatrix; // current view (camera) matrix
  objMatrix:T3DMatrix; // current object (model) matrix
  projMatrix:T3DMatrix; // current projection matrix

  constructor Create;
  procedure DefaultView;
  procedure Perspective(fov:single;zMin,zMax:double); overload;
  procedure Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); overload;
  procedure Orthographic(scale,zMin,zMax:double);
  procedure SetView(view:T3DMatrix);
  procedure SetCamera(origin,target,up:TPoint3;turnCW:double=0);
  procedure SetObj(mat:T3DMatrix); overload;
  procedure SetObj(oX,oY,oZ:single;scale:single=1;yaw:single=0;roll:single=0;pitch:single=0); overload;
  function GetMVPMatrix:T3DMatrix;
 end;

 TClippingAPI=class(TInterfacedObject,IClipping)
  procedure Rect(r:TRect;combine:boolean=true);  //< Set clipping rect (combine with previous or override), save previous
  procedure Nothing; //< don't clip anything, save previous (the same as Apply() for the whole render target area)
  procedure Restore; //< restore previous clipping rect
  function  Get:TRect; //< return current clipping rect
 end;

implementation
 uses Apus.Geom3D;

{ TTransformationsAPI }

constructor TTransformationsAPI.Create;
 begin
  viewMatrix:=IdentMatrix4;
  objMatrix:=IdentMatrix4;
  projMatrix:=IdentMatrix4;
 end;

procedure TTransformationsAPI.DefaultView;
 begin

 end;

function TTransformationsAPI.GetMVPMatrix: T3DMatrix;
 begin

 end;

procedure TTransformationsAPI.Orthographic(scale, zMin, zMax: double);
 begin

 end;

procedure TTransformationsAPI.Perspective(xMin, xMax, yMin, yMax, zScreen, zMin,
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

procedure TTransformationsAPI.Perspective(fov: single; zMin, zMax: double);
 var
  x,y,aspect:single;
 begin
  x:=tan(fov/2);
  y:=x;
  aspect:=renderWidth/renderHeight;
  if aspect>1 then y:=y/aspect
   else x:=x*aspect;
  SetPerspective(-x,x,-y,y,1,zMin,zMax);
 end;

procedure TTransformationsAPI.SetCamera(origin, target, up: TPoint3;
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

procedure TTransformationsAPI.SetObj(oX, oY, oZ, scale, yaw, roll,
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

procedure TTransformationsAPI.SetObj(mat: T3DMatrix);
 begin

 end;

procedure TTransformationsAPI.SetView(view: T3DMatrix);
 begin

 end;

end.
