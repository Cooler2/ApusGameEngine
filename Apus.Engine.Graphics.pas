// Platform-independent implementation of the graphics APIs
//
// Copyright (C) 2021 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Graphics;
interface
 uses Types, Apus.Engine.Types, Apus.Engine.GpuLayout, Apus.Engine.API;

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
     vertexLayout:TVertexLayout;primCount,instances:integer); overload;

  procedure DrawInstanced(primType:TPrimitiveType;vertices:pointer;
     vertexLayout:TVertexLayout;primCount,instances:integer); overload;

  // Use additional vertex buffer (and set attrib divisors for instanced rendering)
  procedure UseExtraVertexData(vertices:pointer;vertexLayout:TVertexLayout);

  // Set vertex attribute array divisors (for instanced rendering)
  procedure SetVertexDataDivisors(baseDivisor,extraDivisor:integer);

  // R-19: table-driven attribute binding for a GPU mesh. Enables exactly the
  // sparse locations described by the layout from the currently bound ARRAY_BUFFER
  // (stream 0). Coexists with SetupAttributes(TVertexLayout) used by the 2D painter.
  // Call UnbindMeshLayout after the draw to hand state back to the painter path.
  procedure BindMeshLayout(layout:TGpuLayout);
  procedure UnbindMeshLayout;
  // R-19: draw a triangle-list GPU mesh range. Buffers must be bound (resman.Use*Buffer)
  // and the shader applied (shader.ApplyMeshLayout) by the caller. indexBytes: 0 =
  // non-indexed (first/count are vertices), 2 = uint16 IBO, 4 = uint32 IBO.
  // Binds attributes per layout, issues the draw, then unbinds.
  procedure DrawMesh(layout:TGpuLayout;first,count,indexBytes:integer);
  // Buffer handling should be organized differently.
  // A dedicated buffer class is needed, managed by the resource manager.
(*  // Draw primitives using built-in buffers
  procedure DrawBuffer(primType,primCount,vrtStart:integer;
     vertexBuf:TPainterBuffer;stride:integer); overload;

  // Draw indexed primitives using built-in buffer
  procedure DrawBuffer(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); overload; *)

  procedure Reset; // Invalidate rendering settings
 end;

 // Internal backend extension for GL bind-state tracking.
 // Kept separate from IRenderDevice to avoid leaking GL-specific details
 // into the backend-agnostic rendering interface.
 IRenderDeviceBindTracking=interface
  ['{8D97D98F-7B14-4E98-9F39-96A880C379F6}']
  procedure TrackArrayBufferBinding(buffer:cardinal);
  procedure TrackElementBufferBinding(buffer:cardinal);
 end;

 // Shared transformation state (model/view/projection) for current render context.
 // Backend-specific renderer reads matrices from here, game code writes camera/object transforms.
 TTransformationAPI=class(TInterfacedObject,ITransformation)
  class threadvar
   viewMatrix:TMat4d; // current view (camera) matrix
   invViewMatrix:TMat4d; // inverted view matrix
   invVPMatrix:TMat4d; // inverted view-Projection matrix
   objMatrix:TMat4d; // current object (model) matrix
   projMatrix:TMat4d; // current projection matrix
   MVP:TMat4d; // combined matrix
   modified,modifiedVP:boolean;
   zMin,zMax,xMax,xMin,yMax,yMin:single;

  constructor Create;
  procedure DefaultView; virtual;
  procedure Perspective(fov:single;zMin,zMax:double); overload; virtual; // FOV in radians - on larger screen axis
  procedure Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); overload; virtual;
  procedure Orthographic(scale,zMin,zMax:double); virtual;
  procedure SetProjection(proj:TMat4d); virtual;
  procedure SetView(view:TMat4d); virtual;
  procedure SetCamera(origin,target,upPoint:TVec3d;turnCW:double=0); overload; virtual;
  procedure SetCamera(origin,target,upPoint:TVec3;turnCW:single=0); overload; virtual;
  procedure SetObj(mat:TMat4d); overload; virtual;
  procedure SetObj(mat:TMat4); overload; virtual;
  procedure SetObj(oX,oY,oZ:single;scale:single=1;yaw:single=0;roll:single=0;pitch:single=0); overload; virtual;
  procedure ResetObj; virtual;
  function Update:boolean; // Calculate combined matrix (if needed), returns true if matrix was changed
  function GetMVPMatrix:TMat4d;
  function GetProjMatrix:TMat4d;
  function GetViewMatrix:TMat4d;
  function GetObjMatrix:TMat4d;
  function ITransformation.MVPMatrix = GetMVPMatrix;
  function ITransformation.ProjMatrix = GetProjMatrix;
  function ITransformation.ViewMatrix = GetViewMatrix;
  function ITransformation.ObjMatrix = GetObjMatrix;
  function Transform(source:TVec3d):TVec3d; overload;
  function Transform(source:TVec3):TVec3; overload;
  function ProjectPoint(source:TVec3):TVec3;

  // Unit vector from the camera towards the screen pixel
  function ViewDir(scrX,scrY:integer):TVec3; overload; // unit vector to pixel (scrX,scrY)
  function ViewDir(viewPos:TVec2):TVec3; overload; // viewPos in range of -1..1 (y axis is up)
  function ViewVec:TVec3; inline; // camera front unit vector
  function RightVec:TVec3; inline; // camera right unit vector
  function DownVec:TVec3; inline; // camera down unit vector
  function ProjWidth:single; inline; // screen projection width in camera view (xMax-xMin)
  function ProjHeight:single; inline; // screen projection height in camera view (yMax-yMin)
  function CameraPos:TVec3; inline; // get current camera position
  function Depth(pnt:TVec3):single; overload; // get point depth (i.e. distance along camera view vector)
  function MinDepth:single; inline; // get minimal depth value (zMin)
  function MaxDepth:single; inline; // get maximal depth value (zMax)
 type
  TMatrixType=(mtModelView,mtProjection);
 protected
  procedure CalcMVP;
  procedure CalcInvVP;
 end;

 // Logical clip-rect stack in virtual coordinates.
 // Converts UI/scene clipping requests into backend clip operations.
 TClippingAPI=class(TInterfacedObject,IClipping)
  constructor Create;
  procedure Rect(r:TRect;combine:boolean=true);  //< Set clipping rect (combine with previous or override), save previous
  procedure Nothing; //< don't clip anything, save previous (the same as Apply() for the whole render target area)
  procedure Restore; //< restore previous clipping rect
  procedure Reject(rejectPrimitives:boolean);
  function  Get:TRect; //< return current clipping rect
  procedure Prepare; overload; //<
  function Prepare(r:TRect):boolean; overload; //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
  function Prepare(x1,y1,x2,y2:NativeInt):boolean; overload;  //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
  function Prepare(x1,y1,x2,y2:single):boolean; overload;  //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)

  procedure AssignActual(r:TRect); // set actual clipping area (from gfx API)
 protected
  class threadvar
   clipRect:TRect; //< current requested clipping area (in virtual pixels), might be different from actual clipping area}
   actualClip:TRect; //< real clipping area
   stack:array[0..49] of TRect;
   stackPos:integer;
   rejectMode:boolean;
   threadReady:boolean;
  procedure EnsureThreadState;
 end;

 // Backend-agnostic render-target state and stack.
 // Concrete backends implement actual API calls (viewport, clear, blend, depth, mask).
 TRenderTargetAPI=class(TInterfacedObject,IRenderTarget)
  constructor Create;

  procedure Backbuffer; virtual;
  procedure Texture(tex:TTexture); virtual;
  procedure Push; virtual;
  procedure Pop; virtual;
  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); virtual; abstract;
  procedure ClearDepth(zbuf:single=0;stencil:integer=-1); virtual; abstract;
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
  class threadvar
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
   threadReady:boolean;
  procedure EnsureThreadState;
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
 uses Math, Apus.Geom2D, Apus.Geom3D;

{ TTransformationsAPI }

procedure TTransformationAPI.CalcMVP;
 var
  tmp:TMat4d;
 begin
  tmp:=objMatrix*viewMatrix;
  MVP:=tmp*projMatrix;
 end;

procedure TTransformationAPI.CalcInvVP;
 var
  tmp:TMat4d;
 begin
  tmp:=viewMatrix*projMatrix;
  invVPMatrix:=tmp.Inverted;
  modifiedVP:=false;
 end;

constructor TTransformationAPI.Create;
 begin
  viewMatrix:=identMat4d;
  objMatrix:=identMat4d;
  projMatrix:=identMat4d;
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

  viewMatrix:=identMat4d;
  invViewMatrix:=identMat4d;
  objMatrix:=identMat4d;

  modified:=true;
  //Update;
 end;

function TTransformationAPI.Depth(pnt:TVec3):single;
 begin
  pnt:=Vec3(CameraPos,pnt);
  result:=pnt.Dot(ViewVec);
 end;

function TTransformationAPI.GetMVPMatrix:TMat4d;
 begin
  if modified then begin
   CalcMVP;
   modified:=false;
  end;
  result:=MVP;
 end;

function TTransformationAPI.GetObjMatrix:TMat4d;
 begin
  result:=objMatrix;
 end;

function TTransformationAPI.GetProjMatrix:TMat4d;
 begin
  result:=projMatrix;
 end;

function TTransformationAPI.GetViewMatrix:TMat4d;
 begin
  result:=viewMatrix;
 end;

function TTransformationAPI.MaxDepth:single;
 begin
  result:=zMax;
 end;

function TTransformationAPI.MinDepth:single;
 begin
  result:=zMin;
 end;

procedure TTransformationAPI.Orthographic(scale,zMin,zMax:double);
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

  self.zMin:=zMin;
  self.zMax:=zMax;
  modified:=true;
 end;

procedure TTransformationAPI.Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,
  zMax:double);
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

  if renderTargetAPI.curTarget=nil then // flip Y axis when rendering to backbuffer (not to texture)
   for i:=0 to 3 do
    projMatrix[i,1]:=-projMatrix[i,1];

  self.zMin:=zMin;
  self.zMax:=zMax;
  self.xMin:=xMin;
  self.xMax:=xMax;
  self.yMin:=yMin;
  self.yMax:=yMax;
  modified:=true;
 end;

function TTransformationAPI.ProjectPoint(source:TVec3):TVec3;
 begin
  result:=Transform(source);
  result.x:=renderTargetAPI.width*(1+result.x)*0.5;
  result.y:=renderTargetAPI.height*(1-result.y)*0.5;
 end;

function TTransformationAPI.ProjHeight:single;
 begin
  result:=yMax-yMin;
 end;

function TTransformationAPI.ProjWidth:single;
 begin
  result:=xMax-xMin;
 end;

procedure TTransformationAPI.Perspective(fov:single;zMin,zMax:double);
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

procedure TTransformationAPI.SetCamera(origin,target,upPoint:TVec3d;
  turnCW: double);
 var
  mat:TMat4d;
  v1,v2,v3:TVec3d;
  c,s:double;
  downX,downY,downZ:double;
  rightX,rightY,rightZ:double;
 begin
  v1:=TVec3d.Init(target.x-origin.x,target.y-origin.y,target.z-origin.z); // front
  v1.Normalize;
  v2:=TVec3d.Init(upPoint.x-origin.x,upPoint.y-origin.y,upPoint.z-origin.z);
  v3:=v1.Cross(v2); // right
  v3.Normalize;
  v2:=v1.Cross(v3); // down
  v2.Normalize;
  if turnCW<>0 then begin
   c:=cos(turnCW);
   s:=sin(turnCW);
   downX:=v2.x; downY:=v2.y; downZ:=v2.z;
   rightX:=v3.x; rightY:=v3.y; rightZ:=v3.z;
   v2.x:=downX*c-rightX*s;
   v2.y:=downY*c-rightY*s;
   v2.z:=downZ*c-rightZ*s;
   v3.x:=rightX*c+downX*s;
   v3.y:=rightY*c+downY*s;
   v3.z:=rightZ*c+downZ*s;
  end;
  mat[0,0]:=v3.x; mat[0,1]:=v3.y; mat[0,2]:=v3.z; mat[0,3]:=0;
  mat[1,0]:=v2.x; mat[1,1]:=v2.y; mat[1,2]:=v2.z; mat[1,3]:=0;
  mat[2,0]:=v1.x; mat[2,1]:=v1.y; mat[2,2]:=v1.z; mat[2,3]:=0;
  mat[3,0]:=origin.x; mat[3,1]:=origin.y; mat[3,2]:=origin.z; mat[3,3]:=1;
  SetView(mat);
 end;

procedure TTransformationAPI.SetCamera(origin,target,upPoint:TVec3;turnCW:single);
 begin
  SetCamera(Vec3d(origin),Vec3d(target),Vec3d(upPoint),turnCW);
 end;

procedure TTransformationAPI.SetObj(oX,oY,oZ,scale,yaw,roll,pitch:single);
 var
  m,m2:TMat4d;
  i,j:integer;
 begin
  // rotation
  if (yaw<>0) or (roll<>0) or (pitch<>0) then
   m:=TMat4d.Init(TMat34d.FromYRP(yaw,roll,pitch))
  else begin
   if scale=1 then begin
    // translation only
    SetObj(TMat4d.Translation(ox,oy,oz));
    exit;
   end;
   m:=identMat4d;
  end;
  // scale
  if scale<>1 then
   for i:=0 to 2 do
    for j:=0 to 2 do
     m[i,j]:=m[i,j]*scale;
  // position
  m2:=m*TMat4d.Translation(ox,oy,oz);

  SetObj(m2);
 end;

procedure TTransformationAPI.SetProjection(proj:TMat4d);
 begin
  projMatrix:=proj;
  modified:=true;
  modifiedVP:=true;
 end;

procedure TTransformationAPI.ResetObj;
 begin
  SetObj(identMat4d);
 end;

procedure TTransformationAPI.SetObj(mat:TMat4d);
 begin
  objMatrix:=mat;
  modified:=true;
 end;

procedure TTransformationAPI.SetObj(mat:TMat4);
 begin
  objMatrix:=mat.ToMat4d;
  modified:=true;
 end;

procedure TTransformationAPI.SetView(view:TMat4d);
 begin
  // Original matrix is "Camera space->World space" but we need reverse transformation: "World->Camera"
  invViewMatrix:=view;
  viewMatrix:=view.Inverted;
  modified:=true;
  modifiedVP:=true;
 end;

function TTransformationAPI.Transform(source:TVec3d):TVec3d;
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
  end else
  if t=0 then begin
   // TODO: Decide how callers should handle points at infinity here.
   // Returning the raw coordinates avoids division by zero but silently
   // propagates values that are not valid clip-space positions.
  end;
  result.x:=x;
  result.y:=y;
  result.z:=z;
 end;

function TTransformationAPI.Transform(source:TVec3):TVec3;
 begin
  result:=TVec3.Init(Transform(Vec3d(source)));
 end;

function TTransformationAPI.Update:boolean;
 begin
  if not modified then exit(false);
  CalcMVP;
  modified:=false;
  result:=true;
 end;

function TTransformationAPI.ViewDir(scrX,scrY:integer):TVec3;
 var
  scr:TVec2;
 begin
  scr.x:=scrX/renderTargetAPI.width*2-1;
  scr.y:=-(scrY/renderTargetAPI.height*2-1);
  result:=ViewDir(scr);
 end;

function TTransformationAPI.ViewDir(viewPos:TVec2):TVec3;
 var
  v,cameraPos:TVec3d;
 begin
  if modifiedVP then CalcInvVP;
  v:=invVPMatrix.TransformPoint(TVec3d.Init(viewPos.x,viewPos.y,1));
  cameraPos:=invViewMatrix.Row(3).xyz;
  v:=TVec3d.Init(v.x-cameraPos.x,v.y-cameraPos.y,v.z-cameraPos.z); // vector from camera position
  v.Normalize;
  result.Init(v);
 end;

function TTransformationAPI.ViewVec:TVec3;
 begin
  result:=Vec3(invViewMatrix.Row(2).xyz);
 end;

function TTransformationAPI.DownVec:TVec3;
 begin
  result:=Vec3(invViewMatrix.Row(1).xyz);
 end;

function TTransformationAPI.RightVec:TVec3;
 begin
  result:=Vec3(invViewMatrix.Row(0).xyz);
 end;

function TTransformationAPI.CameraPos:TVec3;
 begin
  result:=Vec3(invViewMatrix.Row(3).xyz);
 end;

{ TRenderTargetAPI }

function TRenderTargetAPI.aspect:single;
 begin
  EnsureThreadState;
  if renderHeight>0 then result:=renderWidth/renderHeight
   else result:=0;
 end;

procedure TRenderTargetAPI.ClipVirtual(const r: TRect);
 var
  x,y,w,h:integer;
  scaleX,scaleY:single;
 begin
  EnsureThreadState;
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
  EnsureThreadState;
 end;

procedure TRenderTargetAPI.EnsureThreadState;
 begin
  if threadReady then exit;
  vPort:=Types.Rect(0,0,0,0);
  renderWidth:=0;
  renderHeight:=0;
  realWidth:=0;
  realHeight:=0;
  curBlend:=blNone;
  curTarget:=nil;
  stackCnt:=0;
  maskStackPos:=0;
  curMask:=15;
  threadReady:=true;
 end;

procedure TRenderTargetAPI.Push;
 begin
  EnsureThreadState;
  ASSERT(stackCnt<10);
  inc(stackCnt);
  stack[stackcnt]:=curTarget;
  stackVP[stackCnt]:=vPort;
  stackRW[stackCnt]:=renderWidth;
  stackRH[stackCnt]:=renderHeight;
 end;

procedure TRenderTargetAPI.Pop;
 begin
  EnsureThreadState;
  ASSERT(stackCnt>0);
  if stack[stackCnt]<>nil then
   Texture(stack[stackCnt])
  else
   Backbuffer;
  with stackVP[stackCnt] do
   Viewport(left,top,width,height,stackRW[stackCnt],stackRH[stackCnt]);
  dec(stackCnt);
 end;

function TRenderTargetAPI.height: integer;
 begin
  EnsureThreadState;
  result:=renderHeight;
 end;

function TRenderTargetAPI.width: integer;
 begin
  EnsureThreadState;
  result:=renderWidth;
 end;

procedure TRenderTargetAPI.Viewport(oX, oY, VPwidth, VPheight,
  renderWidth, renderHeight: integer);
 begin
  EnsureThreadState;
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
  EnsureThreadState;
  ASSERT(maskStackPos<=High(maskStack));
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
  EnsureThreadState;
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
  EnsureThreadState;
  curTarget:=nil;
 end;

procedure TRenderTargetAPI.UseDepthBuffer(test: TDepthBufferTest;
  writeEnable: boolean);
 begin
 end;

procedure TRenderTargetAPI.Texture(tex: TTexture);
 begin
  EnsureThreadState;
  ASSERT(tex.HasFlag(tfRenderTarget));
  curTarget:=tex;
 end;

{ TClippingAPI }

procedure TClippingAPI.Prepare;
 begin
  EnsureThreadState;
  renderTargetAPI.ClipVirtual(clipRect);
  actualClip:=clipRect;
 end;

function TClippingAPI.Prepare(r:TRect):boolean;
 var
  outRect,outRect2:TRect;
 begin
  EnsureThreadState;
  if not rejectMode then exit(true);
  if not Types.IntersectRect(outRect,r,clipRect) then exit(false);
  result:=true;
  // Adjust the clipping area if primitive can be partially clipped
  if not EqualRect(clipRect,actualClip) then begin
   if (not Types.IntersectRect(outRect2,r,actualClip)) or (not EqualRect(outRect,outRect2)) then begin
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

procedure TClippingAPI.AssignActual(r:TRect);
 begin
  EnsureThreadState;
  actualClip:=r;
 end;

constructor TClippingAPI.Create;
 begin
  EnsureThreadState;
 end;

procedure TClippingAPI.EnsureThreadState;
 begin
  if threadReady then exit;
  rejectMode:=true;
  stackPos:=0;
  clipRect:=Types.Rect(-100000,-100000,100000,100000);
  actualClip:=clipRect;
  threadReady:=true;
 end;

function TClippingAPI.Get: TRect;
 begin
  EnsureThreadState;
  result:=clipRect;
 end;

procedure TClippingAPI.Nothing;
 begin
  EnsureThreadState;
  Rect(types.Rect(-100000,-100000,100000,100000),false);
 end;

procedure TClippingAPI.Rect(r:TRect;combine:boolean);
 begin
  EnsureThreadState;
  ASSERT(stackPos<high(stack));
  inc(stackPos);
  stack[stackPos]:=clipRect;
  if combine then begin
   if not Types.IntersectRect(cliprect,cliprect,r) then  // no intersection
    cliprect:=types.Rect(-1,-1,-1,-1);
  end else
   clipRect:=r;
 end;

procedure TClippingAPI.Reject(rejectPrimitives:boolean);
 begin
  EnsureThreadState;
  rejectMode:=rejectPrimitives;
 end;

procedure TClippingAPI.Restore;
 begin
  EnsureThreadState;
  ASSERT(stackPos>0);
  clipRect:=stack[stackPos];
  dec(stackPos);
 end;

end.
