// Platform-independent implementation of the graphics APIs
//
// Copyright (C) 2021 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Graphics;
interface
 uses Types,Apus.Engine.API;

type
 // Packed description of the vertex layout
 // [0:3] - position (vec3s)
 // [4:7] - normal (vec3s)
 // [8:11]  - color (vec4b)
 // [12:15] - uv1 (vec2s)
 TVertexLayout=cardinal;

 IRenderDevice=interface
  // Draw primitives
  procedure Draw(primType,primCount:integer;vertices:pointer;
     vertexLayout:TVertexLayout;stride:integer);

  // Draw indexed primitives
  procedure DrawIndexed(primType:integer;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;stride:integer;
     vrtStart,vrtCount:integer; indStart,primCount:integer);

  // Работу с буферами нужно организовать как-то иначе.
  // Нужен отдельный класс для буфера. Управлять ими должен resman.
(*  // Draw primitives using built-in buffers
  procedure DrawBuffer(primType,primCount,vrtStart:integer;
     vertexBuf:TPainterBuffer;stride:integer); overload;

  // Draw indexed primitives using built-in buffer
  procedure DrawBuffer(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); overload; *)
 end;

 TTransformationAPI=class(TInterfacedObject,ITransformation)
  viewMatrix:T3DMatrix; // current view (camera) matrix
  objMatrix:T3DMatrix; // current object (model) matrix
  projMatrix:T3DMatrix; // current projection matrix
  MVP:T3DMatrix; // combined matrix

  constructor Create;
  procedure DefaultView; virtual;
  procedure Perspective(fov:single;zMin,zMax:double); overload; virtual;
  procedure Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); overload;
  procedure Orthographic(scale,zMin,zMax:double);
  procedure SetView(view:T3DMatrix);
  procedure SetCamera(origin,target,up:TPoint3;turnCW:double=0);
  procedure SetObj(mat:T3DMatrix); overload;
  procedure SetObj(oX,oY,oZ:single;scale:single=1;yaw:single=0;roll:single=0;pitch:single=0); overload;
  procedure Update; virtual; abstract; // calculate combined matrix (if needed), pass data to the active shader
  function GetMVPMatrix:T3DMatrix;
  function GetObjMatrix:T3DMatrix;
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
  procedure Prepare; overload; inline; //<
  function Prepare(r:TRect):boolean; overload; //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
  function Prepare(x1,y1,x2,y2:integer):boolean; overload; inline; //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
  function Prepare(x1,y1,x2,y2:single):boolean; overload; inline; //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
 protected
  clipRect:TRect; //< current requested clipping area (in virtual pixels), might be different from actual clipping area}
  actualClip:TRect; //< real clipping area
  stack:array[1..50] of TRect;
  stackPos:integer;
 end;

 TRenderTargetAPI=class(TInterfacedObject,IRenderTargets)
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
  procedure Apply; virtual; abstract; //< Apply curTarget as actual render target

  function width:integer; // width of the current render target in virtual pixels
  function height:integer; // height of the current render target in virtual pixels
  function aspect:single; // width/height
  function IsDefault:boolean;

  procedure ClipVirtual(const r:TRect); //< Set clip rect in virtual pixels
  procedure Clip(x,y,w,h:integer); virtual; abstract; //< Set clip rect defined in real pixels
 protected
  viewPort:TRect;  //< part of the backbuffer used for output (backbuffer only, RT-textures always use full surface)
  renderWidth,renderHeight:integer; //< size in virtual pixels
  realWidth,realHeight:integer; //< size of the whole target surface in real pixels
  curBlend:TBlendingMode;
  defaultTarget:TTexture;
  curTarget:TTexture;
  // saved stack of render targets
  stack:array[1..10] of TTexture;
  stackCnt:integer;
 end;

 TShadersAPI=class(TInterfacedObject,IShaders)
  constructor Create;
  // Compile custom shader program from source
  function Build(vSrc,fSrc:String8;extra:String8=''):TShader; virtual; abstract;
  // Load and build shader from file(s)
  function Load(filename:String8;extra:String8=''):TShader; virtual;
  // Set custom shader (pass nil if it's already set - because the engine should know)
  procedure UseCustom(shader:TShader); virtual; abstract;
  // Switch back to the internal shader
  procedure UseDefault; virtual; abstract;
  // Default shader settings
  // ----
  // Set texture stage mode (for default shader)
  procedure TexMode(stage:byte;colorMode:TTexBlendingMode=tblModulate2X;alphaMode:TTexBlendingMode=tblModulate;
     filter:TTexFilter=fltUndefined;intFactor:single=0.0); virtual; abstract;
  // Restore default texturing mode: one stage with Modulate2X mode for color and Modulate mode for alpha
  procedure DefaultTexMode; virtual; abstract;
  // Upload texture to the Video RAM and make it active for the specified stage
  // (usually you don't need to call this manually unless you're using a custom shader)
  procedure UseTexture(tex:TTexture;stage:integer=0); virtual; abstract;
  // Update shader matrices
  procedure UpdateMatrices(const model,MVP:T3DMatrix); virtual;

  procedure AmbientLight(color:cardinal); virtual; abstract;
  // Set directional light (set power<=0 to disable)
  procedure DirectLight(direction:TVector3;power:single;color:cardinal); virtual; abstract;
  // Set point light source (set power<=0 to disable)
  procedure PointLight(position:TPoint3;power:single;color:cardinal); virtual; abstract;
  // Define material properties
  procedure Material(color:cardinal;shininess:single); virtual; abstract;

 protected
  curTexMode:int64; // encoded shader mode requested by the client code
  actualTexMode:int64; // actual shader mode

  activeShader:TShader;
  defaultShader:TShader;
 end;

var
 renderDevice:IRenderDevice;
 // APIs implementation
 transformationAPI:TTransformationAPI;
 clippingAPI:TClippingAPI;
 renderTargetAPI:TRenderTargetAPI;
 shadersAPI:TShadersAPI;

 // Build vertex layout descriptor from fields offset (in bytes)
 // Pass 0 for unused (absent) fields (except position - it is always used)
 function BuildVertexLayout(position,normal,color,uv1,uv2:integer):TVertexLayout;

implementation
 uses Math, Apus.MyServis, Apus.Geom3D, Apus.Geom2D;

 function BuildVertexLayout(position,normal,color,uv1,uv2:integer):TVertexLayout;
  function Field(idx,value:integer):cardinal;
   begin
    ASSERT(value and 3=0);
    ASSERT(value<64);
    result:=(value shr 2) shl (idx*4);
   end;
  begin
   result:=
     Field(0,position)+
     Field(1,normal)+
     Field(2,color)+
     Field(3,uv1)+
     Field(4,uv2);
  end;

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
  viewMatrix:=IdentMatrix4;
  objMatrix:=IdentMatrix4;
  projMatrix:=IdentMatrix4;
  modified:=true;
 end;

procedure TTransformationAPI.DefaultView;
 var
  w,h:integer;
 begin
  w:=renderTargetAPI.viewPort.width;
  h:=renderTargetAPI.viewPort.height;
  if (w=0) and (h=0) then exit;
  projMatrix[0,0]:=2/w;  projMatrix[1,0]:=0; projMatrix[2,0]:=0; projMatrix[3,0]:=-1+1/w;
  if renderTargetAPI.isDefault then begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=-(1-1/h);
  end else begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=-2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=1-1/h;
  end;
  projMatrix[0,2]:=0;  projMatrix[1,2]:=0; projMatrix[2,2]:=-1; projMatrix[3,2]:=0;
  projMatrix[0,3]:=0;  projMatrix[1,3]:=0; projMatrix[2,3]:=0; projMatrix[3,3]:=1;

  modified:=true;
 end;

function TTransformationAPI.GetMVPMatrix:T3DMatrix;
 begin
  result:=MVP;
 end;

function TTransformationAPI.GetObjMatrix:T3DMatrix;
 begin
  result:=objMatrix;
 end;

procedure TTransformationAPI.Orthographic(scale, zMin, zMax: double);
 var
  w,h:integer;
 begin
  w:=renderTargetAPI.width;
  h:=renderTargetAPI.height;

  projMatrix[0,0]:=scale*2/w;  projMatrix[1,0]:=0; projMatrix[2,0]:=0; projMatrix[3,0]:=0;
  if renderTargetAPI.IsDefault then begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=scale*2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=0;
  end else begin
   projMatrix[0,1]:=0;  projMatrix[1,1]:=-scale*2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=0;
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

  if renderTargetAPI.IsDefault then // нужно переворачивать ось Y если только не рисуем в текстуру
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

procedure TTransformationAPI.SetObj(oX, oY, oZ, scale, yaw, roll,
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

procedure TTransformationAPI.SetObj(mat: T3DMatrix);
 begin
  objMatrix:=mat;
  modified:=true;
 end;

procedure TTransformationAPI.SetView(view: T3DMatrix);
 begin
  viewMatrix:=view;
  modified:=true;
 end;

function TTransformationAPI.Transform(source: TPoint3): TPoint3;
 begin

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
  if curTarget=nil then begin
    x:=viewPort.Left;
    y:=viewPort.Top;
    w:=viewPort.Width;
    h:=viewPort.Height;
    scaleX:=w/renderWidth;
    scaleY:=h/renderHeight;
    Clip(x+round(r.Left*scaleX),realHeight-y-round(h*scaleY),
      round(r.Width*scaleX),round(r.height*scaleY));
  end else begin
    Clip(r.Left,r.Top,r.Width,r.Height);
  end;
 end;

constructor TRenderTargetAPI.Create;
 begin
  _AddRef;
  curBlend:=blAlpha;
  defaultTarget:=nil; // backbuffer
  curTarget:=nil;
  /// TODO: get backbuffer dimensions screenRect:=
 end;

function TRenderTargetAPI.IsDefault: boolean;
 begin
  result:=curTarget=defaultTarget;
 end;

procedure TRenderTargetAPI.Push;
 begin
  ASSERT(stackCnt<10);
  inc(stackCnt);
  stack[stackcnt]:=curTarget;
  clippingAPI.Rect(Rect(0,0,width,height),false);
 end;

procedure TRenderTargetAPI.Pop;
 begin
  ASSERT(stackCnt>0);
  if stack[stackCnt]=nil then UseBackbuffer
   else UseTexture(stack[stackcnt]);
  dec(stackCnt);
  clippingAPI.Restore;
 end;

function TRenderTargetAPI.height: integer;
 begin
  result:=renderHeight;
 end;

function TRenderTargetAPI.width: integer;
 begin
  result:=renderWidth;
 end;

procedure TRenderTargetAPI.SetDefaultRenderArea(oX, oY, VPwidth, VPheight,
  renderWidth, renderHeight: integer);
 begin

 end;

procedure TRenderTargetAPI.Mask(rgb, alpha: boolean);
 begin

 end;

procedure TRenderTargetAPI.UnMask;
 begin

 end;

procedure TRenderTargetAPI.UseAsDefault(rt: TTexture);
 begin
  ASSERT(rt.HasFlag(tfRenderTarget));
  defaultTarget:=rt;
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
  ASSERT(tex.HasFlag(tfRenderTarget));
  //Use(tex);
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

function TClippingAPI.Prepare(x1,y1,x2,y2:integer):boolean;
 begin
  result:=Prepare(Types.Rect(x1,y1,x2,y2));
 end;

function TClippingAPI.Prepare(x1,y1,x2,y2:single):boolean;
 begin
  result:=Prepare(Types.Rect(trunc(x1),trunc(y1),trunc(x2)+1,trunc(y2)+1));
 end;

constructor TClippingAPI.Create;
 begin
  _AddRef;
  /// TODO: restore actual clipping
  //clipRect:=Types.Rect(0,0,0,0);
 end;

function TClippingAPI.Get: TRect;
 begin
  result:=clipRect;
 end;

procedure TClippingAPI.Nothing;
 begin
  Rect(types.Rect(0,0,renderTargetAPI.width,renderTargetAPI.height),false);
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

{ TShadersAPI }

constructor TShadersAPI.Create;
 begin
  _AddRef;
  curTexMode:=0;
  actualTexMode:=-1;
 end;

function TShadersAPI.Load(filename, extra: String8): TShader;
 var
  vShader,fShader:String8;
 begin
  vShader:=LoadFileAsString(filename);
  result:=Build(vShader,fShader,extra);
 end;

procedure TShadersAPI.UpdateMatrices(const model, MVP: T3DMatrix);
 begin
  activeShader.SetUniform('uMVP',MVP);
  activeShader.SetUniform('uModel',model);
 end;

end.
