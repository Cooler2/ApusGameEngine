// Platform-independent implementation of the graphics APIs
//
// Copyright (C) 2021 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Graphics;
interface
 uses Types, Apus.Engine.Types, Apus.Engine.API;

type
 IRenderDevice=interface
  // Draw primitives
  procedure Draw(primType:TPrimitiveType;primCount:integer;vertices:pointer;
     vertexLayout:TVertexLayout);

  // Draw indexed primitives
  procedure DrawIndexed(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;primCount:integer); overload;

  // Ranged version
  procedure DrawIndexed(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout; vrtStart,vrtCount:integer; indStart,primCount:integer); overload;

  // Draw instanced indexed primitives
  procedure DrawInstanced(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;primCount,instances:integer);


  // Работу с буферами нужно организовать как-то иначе.
  // Нужен отдельный класс для буфера. Управлять ими должен resman.
(*  // Draw primitives using built-in buffers
  procedure DrawBuffer(primType,primCount,vrtStart:integer;
     vertexBuf:TPainterBuffer;stride:integer); overload;

  // Draw indexed primitives using built-in buffer
  procedure DrawBuffer(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); overload; *)

  procedure Reset; // Invalidate rendering settings
 end;

 TTransformationAPI=class(TInterfacedObject,ITransformation)
  viewMatrix:T3DMatrix; // current view (camera) matrix
  objMatrix:T3DMatrix; // current object (model) matrix
  projMatrix:T3DMatrix; // current projection matrix
  MVP:T3DMatrix; // combined matrix

  constructor Create;
  procedure DefaultView; virtual;
  procedure Perspective(fov:single;zMin,zMax:double); overload; virtual;
  procedure Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); overload; virtual;
  procedure Orthographic(scale,zMin,zMax:double); virtual;
  procedure SetView(view:T3DMatrix); virtual;
  procedure SetCamera(origin,target,up:TPoint3;turnCW:double=0); virtual;
  procedure SetObj(mat:T3DMatrix); overload; virtual;
  procedure SetObj(oX,oY,oZ:single;scale:single=1;yaw:single=0;roll:single=0;pitch:single=0); overload; virtual;
  procedure ResetObj; virtual;
  function Update:boolean; // Сalculate combined matrix (if needed), returns true if matrix was changed
  function GetMVPMatrix:T3DMatrix;
  function GetProjMatrix:T3DMatrix;
  function GetViewMatrix:T3DMatrix;
  function GetObjMatrix:T3DMatrix;
  function ITransformation.MVPMatrix = GetMVPMatrix;
  function ITransformation.ProjMatrix = GetProjMatrix;
  function ITransformation.ViewMatrix = GetViewMatrix;
  function ITransformation.ObjMatrix = GetObjMatrix;
  function Transform(source:TPoint3):TPoint3;
 type
  TMatrixType=(mtModelView,mtProjection);
 protected
  modified:boolean;
  procedure CalcMVP;
 end;

 TClippingAPI=class(TInterfacedObject,IClipping)
  constructor Create;
  procedure Rect(r:TRect;combine:boolean=true);  //< Set clipping rect (combine with previous or override), save previous
  procedure Nothing; //< don't clip anything, save previous (the same as Apply() for the whole render target area)
  procedure Restore; //< restore previous clipping rect
  function  Get:TRect; //< return current clipping rect
  procedure Prepare; overload; //<
  function Prepare(r:TRect):boolean; overload; //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
  function Prepare(x1,y1,x2,y2:NativeInt):boolean; overload;  //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
  function Prepare(x1,y1,x2,y2:single):boolean; overload;  //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)

  procedure AssignActual(r:TRect); // set actual clipping area (from gfx API)
 protected
  clipRect:TRect; //< current requested clipping area (in virtual pixels), might be different from actual clipping area}
  actualClip:TRect; //< real clipping area
  stack:array[0..49] of TRect;
  stackPos:integer;
 end;

 TRenderTargetAPI=class(TInterfacedObject,IRenderTarget)
  constructor Create;

  procedure Backbuffer; virtual;
  procedure Texture(tex:TTexture); virtual;
  procedure Push; virtual;
  procedure Pop; virtual;
  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); virtual; abstract;
  procedure Viewport(oX,oY,VPwidth,VPheight:integer;renderWidth:integer=0;renderHeight:integer=0); virtual;
  procedure UseDepthBuffer(test:TDepthBufferTest;writeEnable:boolean=true); virtual;
  procedure BlendMode(blend:TBlendingMode); virtual; abstract;
  procedure Mask(rgb:boolean;alpha:boolean); virtual;
  procedure UnMask; virtual;

  function width:integer; // width of the current render target in virtual pixels
  function height:integer; // height of the current render target in virtual pixels
  function aspect:single; // width/height

  procedure ClipVirtual(const r:TRect); //< Set clip rect in virtual pixels
  procedure Clip(x,y,w,h:integer); virtual; abstract; //< Set actual clip rect defined in real pixels
  procedure Resized(newWidth,newHeight:integer); virtual; abstract; // backbuffer size changed
 protected
  vPort:TRect;  //< part of the backbuffer used for output (backbuffer only, RT-textures always use full surface)
  renderWidth,renderHeight:integer; //< size in virtual pixels
  realWidth,realHeight:integer; //< size of the whole target surface in real pixels
  curBlend:TBlendingMode;
  curTarget:TTexture;
  // saved stack of render targets
  stack:array[1..10] of TTexture;
  stackVP:array[1..10] of TRect;
  stackRW,stackRH:array[1..10] of integer;
  stackCnt:integer;
  // stack of saved masks
  maskStack:array[0..9] of integer;
  maskStackPos:integer;
  curMask:integer;
  procedure ApplyMask; virtual; abstract; //< Apply curMask
 end;

var
 renderDevice:IRenderDevice;
 // APIs implementation
 transformationAPI:TTransformationAPI;
 clippingAPI:TClippingAPI;
 renderTargetAPI:TRenderTargetAPI;

 // Build vertex layout descriptor from fields offset (in bytes)
 // Pass 0 for unused (absent) fields (except position - it is always used)
 // Pass >=255 for position to use 2D position vectors
 //function BuildVertexLayout(position,normal,color,uv1,uv2:integer):TVertexLayout;

implementation
 uses Math, Apus.MyServis, Apus.Geom3D, Apus.Geom2D;

{ TTransformationsAPI }

procedure TTransformationAPI.CalcMVP;
 var
  tmp:T3DMatrix;
 begin
  MultMat4(objMatrix,viewMatrix,tmp);
  MultMat4(tmp,projMatrix,MVP);
 end;

constructor TTransformationAPI.Create;
 begin
  _AddRef;
  Apus.Engine.API.transform:=self;
  viewMatrix:=IdentMatrix4;
  objMatrix:=IdentMatrix4;
  projMatrix:=IdentMatrix4;
  modified:=true;
 end;

procedure TTransformationAPI.DefaultView;
 var
  w,h:integer;
 begin
  w:=renderTargetAPI.width;
  h:=renderTargetAPI.height;
  if (w=0) and (h=0) then exit;
  projMatrix[0,0]:=2/w;  projMatrix[1,0]:=0; projMatrix[2,0]:=0; projMatrix[3,0]:=-1+1/w;
  if renderTargetAPI.curTarget<>nil then begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=-(1-1/h);
  end else begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=-2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=1-1/h;
  end;
  projMatrix[0,2]:=0;  projMatrix[1,2]:=0; projMatrix[2,2]:=-1; projMatrix[3,2]:=0;
  projMatrix[0,3]:=0;  projMatrix[1,3]:=0; projMatrix[2,3]:=0; projMatrix[3,3]:=1;

  viewMatrix:=IdentMatrix4;
  objMatrix:=IdentMatrix4;

  modified:=true;
  //Update;
 end;

function TTransformationAPI.GetMVPMatrix:T3DMatrix;
 begin
  if modified then CalcMVP;  
  result:=MVP;
 end;

function TTransformationAPI.GetObjMatrix:T3DMatrix;
 begin
  result:=objMatrix;
 end;

function TTransformationAPI.GetProjMatrix: T3DMatrix;
 begin
  result:=projMatrix;
 end;

function TTransformationAPI.GetViewMatrix: T3DMatrix;
 begin
  result:=viewMatrix;
 end;

procedure TTransformationAPI.Orthographic(scale, zMin, zMax: double);
 var
  w,h:integer;
 begin
  w:=renderTargetAPI.width;
  h:=renderTargetAPI.height;

  projMatrix[0,0]:=scale*2/w;  projMatrix[1,0]:=0; projMatrix[2,0]:=0; projMatrix[3,0]:=0;
  if renderTargetAPI.curTarget=nil then begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=-scale*2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=0;
  end else begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=scale*2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=0;
  end;
  projMatrix[0,2]:=0;  projMatrix[1,2]:=0; projMatrix[2,2]:=2/(zMax-zMin); projMatrix[3,2]:=-(zMax+zMin)/(zMax-zMin);
  projMatrix[0,3]:=0;  projMatrix[1,3]:=0; projMatrix[2,3]:=0; projMatrix[3,3]:=1;

  modified:=true;
 end;

procedure TTransformationAPI.Perspective(xMin, xMax, yMin, yMax, zScreen, zMin,
  zMax: double);
 var
  A,B,C,D:single;
  i:integer;
 begin
  A:=(xMax+xMin)/(xMax-xMin);
  B:=(yMin+yMax)/(yMin-yMax);
  C:=zMax/(zMax-zMin);
  D:=zMax*zMin/(zMin-zMax);
  projMatrix[0,0]:=2*zScreen/(xMax-xMin);    projMatrix[1,0]:=0;    projMatrix[2,0]:=A;     projMatrix[3,0]:=0;
  projMatrix[0,1]:=0;      projMatrix[1,1]:=2*zScreen/(yMax-yMin);  projMatrix[2,1]:=B;     projMatrix[3,1]:=0;
  projMatrix[0,2]:=0;      projMatrix[1,2]:=0;                      projMatrix[2,2]:=C;     projMatrix[3,2]:=D;
  projMatrix[0,3]:=0;      projMatrix[1,3]:=0;                      projMatrix[2,3]:=1;     projMatrix[3,3]:=0;

  if renderTargetAPI.curTarget=nil then // нужно переворачивать ось Y если только не рисуем в текстуру
   for i:=0 to 3 do
    projMatrix[i,1]:=-projMatrix[i,1];

  modified:=true;
 end;

procedure TTransformationAPI.Perspective(fov: single; zMin, zMax: double);
 var
  x,y,aspect:single;
 begin
  x:=tan(fov/2);
  y:=x;
  aspect:=renderTargetAPI.aspect;
  if aspect>1 then y:=y/aspect
   else x:=x*aspect;
  Perspective(-x,x,-y,y,1,zMin,zMax);
 end;

procedure TTransformationAPI.SetCamera(origin, target, up: TPoint3;
  turnCW: double);
 var
  mat:TMatrix4;
  v1,v2,v3:TVector3;
 begin
  v1:=Vector3(origin,target); // front
  Normalize3(v1);
  v2:=Vector3(origin,up);
  v3:=CrossProduct3(v1,v2); // right
  Normalize3(v3); // Right vector
  v2:=CrossProduct3(v1,v3); // Down vector
  mat[0,0]:=v3.x; mat[0,1]:=v3.y; mat[0,2]:=v3.z; mat[0,3]:=0;
  mat[1,0]:=v2.x; mat[1,1]:=v2.y; mat[1,2]:=v2.z; mat[1,3]:=0;
  mat[2,0]:=v1.x; mat[2,1]:=v1.y; mat[2,2]:=v1.z; mat[2,3]:=0;
  mat[3,0]:=origin.x; mat[3,1]:=origin.y; mat[3,2]:=origin.z; mat[3,3]:=1;
  SetView(mat);
 end;

procedure TTransformationAPI.SetObj(oX, oY, oZ, scale, yaw, roll,
  pitch: single);
 var
  m,m2:T3DMatrix;
  i,j:integer;
 begin
  // rotation
  if (yaw<>0) or (roll<>0) or (pitch<>0) then
   m:=MatrixFromYawRollPitch4(yaw,roll,pitch)
  else begin
   if scale=1 then begin
    // translation only
    SetObj(TranslationMat4(ox,oy,oz));
    exit;
   end;
   m:=IdentMatrix4;
  end;
  // scale
  if scale<>1 then
   for i:=0 to 2 do
    for j:=0 to 2 do
     m[i,j]:=m[i,j]*scale;
  // position
  MultMat4(m,TranslationMat4(ox,oy,oz),m2);

  SetObj(m2);
 end;

procedure TTransformationAPI.ResetObj;
 begin
  SetObj(IdentMatrix4);
 end;

procedure TTransformationAPI.SetObj(mat: T3DMatrix);
 begin
  objMatrix:=mat;
  modified:=true;
 end;

procedure TTransformationAPI.SetView(view: T3DMatrix);
 begin
  // Original matrix is "Camera space->World space" but we need reverse transformation: "World->Camera"
  Invert4Full(view,viewMatrix);
  modified:=true;
 end;

function TTransformationAPI.Transform(source: TPoint3): TPoint3;
 var
  x,y,z,t:double;
 begin
  CalcMVP;
  x:=source.x*mvp[0,0]+source.y*mvp[1,0]+source.z*mvp[2,0]+mvp[3,0];
  y:=source.x*mvp[0,1]+source.y*mvp[1,1]+source.z*mvp[2,1]+mvp[3,1];
  z:=source.x*mvp[0,2]+source.y*mvp[1,2]+source.z*mvp[2,2]+mvp[3,2];
  t:=source.x*mvp[0,3]+source.y*mvp[1,3]+source.z*mvp[2,3]+mvp[3,3];
  if (t<>1) and (t<>0) then begin
   x:=x/t; y:=y/t; z:=z/t;
  end;
  result.x:=x;
  result.y:=y;
  result.z:=z;
 end;

function TTransformationAPI.Update:boolean;
 begin
  if not modified then exit(false);
  CalcMVP;
  modified:=false;
  result:=true;
 end;

{ TRenderTargetAPI }

function TRenderTargetAPI.aspect: single;
 begin
  if renderHeight>0 then result:=renderWidth/renderHeight
   else result:=0;
 end;

procedure TRenderTargetAPI.ClipVirtual(const r: TRect);
 var
  x,y,w,h:integer;
  scaleX,scaleY:single;
 begin
  x:=vPort.Left;
  y:=vPort.Top;
  w:=vPort.Width;
  h:=vPort.Height;
  scaleX:=w/renderWidth;
  scaleY:=h/renderHeight;
  Clip(x+round(r.Left*scaleX),y+round(r.top*scaleY),
    round(r.Width*scaleX),round(r.height*scaleY));
 end;

constructor TRenderTargetAPI.Create;
 begin
  _AddRef;
  curBlend:=blNone;
  curTarget:=nil;
  curMask:=15;
 end;

procedure TRenderTargetAPI.Push;
 begin
  ASSERT(stackCnt<10);
  inc(stackCnt);
  stack[stackcnt]:=curTarget;
  stackVP[stackCnt]:=vPort;
  stackRW[stackCnt]:=renderWidth;
  stackRH[stackCnt]:=renderHeight;
 end;

procedure TRenderTargetAPI.Pop;
 begin
  ASSERT(stackCnt>0);
  Texture(stack[stackcnt]);
  with stackVP[stackCnt] do
   Viewport(left,top,width,height,stackRW[stackCnt],stackRH[stackCnt]);
  dec(stackCnt);
 end;

function TRenderTargetAPI.height: integer;
 begin
  result:=renderHeight;
 end;

function TRenderTargetAPI.width: integer;
 begin
  result:=renderWidth;
 end;

procedure TRenderTargetAPI.Viewport(oX, oY, VPwidth, VPheight,
  renderWidth, renderHeight: integer);
 begin
  if vpWidth<=0 then vpWidth:=realWidth;
  if vpHeight<=0 then vpHeight:=realHeight;
  vPort:=Rect(oX,oY,ox+vpWidth,oY+vpHeight);
  if renderWidth<=0 then renderWidth:=vpWidth;
  if renderHeight<=0 then renderHeight:=vpHeight;
  self.renderWidth:=renderWidth;
  self.renderHeight:=renderHeight;
  transformationAPI.DefaultView;
 end;

procedure TRenderTargetAPI.Mask(rgb, alpha: boolean);
 var
  mask:integer;
 begin
  ASSERT(maskStackPos<15);
  mask:=0;
  maskStack[maskStackPos]:=curmask;
  inc(maskStackPos);
  if rgb then mask:=mask+7;
  if alpha then mask:=mask+8;
  if curmask<>mask then begin
   curMask:=mask;
   ApplyMask;
  end;
 end;

procedure TRenderTargetAPI.UnMask;
 var
  mask:integer;
 begin
  ASSERT(maskStackPos>0);
  dec(maskStackPos);
  mask:=maskStack[maskStackPos];
  if curmask<>mask then begin
   curMask:=mask;
   ApplyMask;
  end;
 end;

procedure TRenderTargetAPI.Backbuffer;
 begin
  curTarget:=nil;
 end;

procedure TRenderTargetAPI.UseDepthBuffer(test: TDepthBufferTest;
  writeEnable: boolean);
 begin
 end;

procedure TRenderTargetAPI.Texture(tex: TTexture);
 begin
  ASSERT(tex.HasFlag(tfRenderTarget));
  curTarget:=tex;
 end;

{ TClipping }

procedure TClippingAPI.Prepare;
 begin
  renderTargetAPI.ClipVirtual(clipRect);
  actualClip:=clipRect;
 end;

function TClippingAPI.Prepare(r:TRect):boolean;
 var
  outRect:TRect;
  f1,f2:integer;
 begin
  f1:=IntersectRects(r,clipRect,outRect);
  if f1=0 then exit(false);
  result:=true;
  // Adjust the clipping area if primitive can be partially clipped
  if not EqualRect(clipRect,actualClip) then begin
   f2:=IntersectRects(r,actualClip,outRect);
   if (f1<>f2) or (f1>1) then begin
    renderTargetAPI.ClipVirtual(clipRect);
    actualClip:=clipRect;
   end;
  end;
 end;

function TClippingAPI.Prepare(x1,y1,x2,y2:NativeInt):boolean;
 begin
  result:=Prepare(Types.Rect(x1,y1,x2,y2));
 end;

function TClippingAPI.Prepare(x1,y1,x2,y2:single):boolean;
 begin
  result:=Prepare(Types.Rect(trunc(x1),trunc(y1),trunc(x2)+1,trunc(y2)+1));
 end;

procedure TClippingAPI.AssignActual(r: TRect);
 begin
  actualClip:=r;
 end;

constructor TClippingAPI.Create;
 begin
  _AddRef;
  stackPos:=0;
  clipRect:=types.Rect(-100000,-100000,100000,100000);
  actualClip:=clipRect;
 end;

function TClippingAPI.Get: TRect;
 begin
  result:=clipRect;
 end;

procedure TClippingAPI.Nothing;
 begin
  Rect(types.Rect(-100000,-100000,100000,100000),false);
 end;

procedure TClippingAPI.Rect(r: TRect; combine: boolean);
 begin
  ASSERT(stackPos<high(stack));
  inc(stackPos);
  stack[stackPos]:=clipRect;
  if combine then begin
   if IntersectRects(cliprect,r,cliprect)=0 then  // no intersection
    cliprect:=types.Rect(-1,-1,-1,-1);
  end else
   clipRect:=r;
 end;

procedure TClippingAPI.Restore;
 begin
  ASSERT(stackPos>0);
  clipRect:=stack[stackPos];
  dec(stackPos);
 end;

end.
