// OpenGL wrapper for the engine
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IF Defined(MSWINDOWS) or Defined(LINUX)} {$DEFINE DGL} {$ENDIF}
unit Apus.Engine.OpenGL;
interface
uses Apus.Core, Apus.Engine.API, Apus.Images;

type
 // Main graphics-system implementation for OpenGL.
 // Owns and wires all rendering subsystems (target, shaders, resman, text, draw).
 // Lifecycle is controlled via IGraphicsSystem (Init/Done).
 // Important: all GL-owning services must be released in Done BEFORE the platform
 // destroys the GL context, otherwise GPU resources cannot be deleted safely.
 TOpenGL=class(TInterfacedObject,IGraphicsSystem,IGraphicsSystemConfig)
  procedure Init(system:ISystemPlatform);
  procedure Done;
  function GetVersion:single;
  function GetName:string8;
  // IGraphicsSystemConfig
  procedure ChoosePixelFormats(out trueColor,trueColorAlpha,rtTrueColor,rtTrueColorAlpha:TImagePixelFormat;
    economyMode:boolean=false);
  function ShouldUseTextureAsDefaultRT:boolean;
  function SetVSyncDivider(n:integer):boolean; // 0 - unlimited FPS, 1 - use monitor refresh rate
  function QueryMaxRTSize:integer;
  // Core interfaces
  function config:IGraphicsSystemConfig;
  function resman:IResourceManager;
  function target:IRenderTarget;
  function shader:IShader; inline;
  function clip:IClipping; inline;
  function transform:ITransformation;
  function draw:IDrawer; inline;
  function txt:ITextDrawer;
  // Functions
  procedure PresentFrame;
  procedure CopyFromBackbuffer(srcX,srcY:integer;image:TRawImage);
  function GetPixelValue(X,Y:integer):cardinal;

  procedure BeginPaint(target:TTexture);
  procedure EndPaint;
  procedure SetCullMode(mode:TCullMode);
  procedure Restore;
  procedure DrawDebugOverlay(idx:integer);

  procedure PostDebugMsg(st:string8;id:integer=0);
  procedure Breakpoint;

  // For internal use
 protected
  glVersion,glRenderer:string8;
  glVersionNum:single;
  sysPlatform:ISystemPlatform;
  canPaint:integer;
  // Explicit owners for interfaced singletons created in Init.
  // They are released in Done via :=nil to trigger deterministic destruction.
  ownRenderTarget:IRenderTarget;
  ownTransformation:ITransformation;
  ownClipping:IClipping;
  ownShader:IShader;
  ownResMan:IResourceManager;
 end;

var
 debugGL:boolean = true;
 glDefaultVAO:cardinal = 0;

 procedure CheckForGLError(lab:integer=0); inline;

implementation
 uses
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  {$IFDEF DGL}dglOpenGL,{$ENDIF}
  SysUtils,
  Types,
  Apus.Engine.Types,
  Apus.Engine.Graphics,
  Apus.Engine.Draw,
  Apus.Engine.TextDraw,
  Apus.Engine.ResManGL,
  Apus.Engine.ShadersGL,
  Apus.Log;

type
 // Low-level bridge from engine vertex data to OpenGL draw calls.
 // Used by higher-level APIs (draw/text/shaders), does not own scene resources.
 TRenderDevice=class(TInterfacedObject,IRenderDevice)
  constructor Create;
  destructor Destroy; override;
  procedure Reset;

  procedure Draw(primType:TPrimitiveType;primCount:integer;vertices:pointer;
    vertexLayout:TVertexLayout);

  // Draw primitives using pre-configured attributes
  //procedure DrawBuffers(primType:TPrimitiveType;primCount:integer);

  // Draw indexed  primitives using in-memory buffers
  procedure DrawIndexed(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout; primCount:integer); overload;

  // Ranged version
  procedure DrawIndexed(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout; vrtStart,vrtCount:integer; indStart,primCount:integer); overload;

  procedure DrawInstanced(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;primCount,instances:integer); overload;

  procedure DrawInstanced(primType:TPrimitiveType;vertices:pointer;
     vertexLayout:TVertexLayout;primCount,instances:integer); overload;

  procedure UseExtraVertexData(vertices:pointer;vertexLayout:TVertexLayout);
  procedure SetVertexDataDivisors(baseDivisor,extraDivisor:integer);

{  // Draw primitives using custom buffers
  procedure DrawBuffer(primType:TPrimitiveType;vb:TVertexBuffer;ib:TIndexBuffer); overload;

  // Draw indexed primitives using built-in buffer
  procedure DrawBuffer(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); overload;}

 protected
  actualAttribArrays:shortint; // number of enabled attrib arrays (-1 = unknown)
  lastVertices:pointer;
  lastLayout:TVertexLayout;
  lastStride:integer;
  lastArrayBuffer:GLint;
  boundArrayBuffer:GLint;
  boundElementArrayBuffer:GLint;
 baseDivisor,extraDivisor:integer;
 extraVertices:pointer;
 extraLayout:TVertexLayout;
 divisors:array[0..9] of integer;
  streamVB,streamIB:cardinal;
  streamVBSize,streamIBSize:integer;
  function PrimitiveVertexCount(primType:TPrimitiveType;primCount:integer):integer;
  function PrimitiveIndexCount(primType:TPrimitiveType;primCount:integer):integer;
  function IsCoreProfile:boolean;
  procedure EnsureStreamVB(requiredSize:integer);
  procedure EnsureStreamIB(requiredSize:integer);
  procedure UploadStreamVertices(vertices:pointer;vertexLayout:TVertexLayout;vertexCount:integer);
  procedure UploadStreamIndices(indices:pointer;indexCount:integer);
  procedure SetupAttributes(vertices:pointer;vertexLayout:TVertexLayout);
  procedure TrackArrayBufferBinding(buffer:cardinal);
  procedure TrackElementBufferBinding(buffer:cardinal);
 end;

 // OpenGL-specific render-target implementation.
 // Applies viewport/scissor/blend/depth states for backbuffer and texture RTs.
 TGLRenderTargetAPI=class(TRendertargetAPI)
  constructor Create;
  procedure Backbuffer; override;
  procedure Texture(tex:TTexture); override;
  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); override;
  procedure ClearDepth(zbuf:single=0;stencil:integer=-1); override;
  procedure Viewport(oX,oY,VPwidth,VPheight,renderWidth,renderHeight:integer); override;
  procedure UseDepthBuffer(test:TDepthBufferTest;writeEnable:boolean=true); override;
  procedure BlendMode(blend:TBlendingMode); override;
  procedure Clip(x,y,w,h:integer); override;
  procedure ApplyMask; override;
  procedure Resized(newWidth,newHeight:integer); override;
 protected
  scissor:boolean;
  backBufferWidth,backBufferHeight:integer;
  procedure ClearBuffers(fColor,fDepth,fStencil:boolean;color:cardinal;zbuf:single;stencil:integer);
 end;

 //textureManager:TResource;

procedure CheckForGLError(lab:integer=0); inline;
var
 error:cardinal;
begin
 if debugGL then begin
  error:=glGetError;
  if error<>GL_NO_ERROR then begin
    raise EError.Create('GL Error %d: code %d (%x)',[lab,error,error]);
  end;
 end;
end;

function GLProfileToString(profile:TOpenGLContextProfile):string;
 begin
  case profile of
   glcpCompatibility:result:='compatibility';
   glcpCore:result:='core';
   else result:='any';
  end;
 end;

function GLContextRequestToString(const request:TOpenGLContextRequest):string;
 begin
  result:='min='+IntToStr(request.minMajor)+'.'+IntToStr(request.minMinor)+
   ', preferHighest='+BoolToStr(request.preferHighest,true)+
   ', profile='+GLProfileToString(request.profile)+
   ', debug='+BoolToStr(request.debugContext,true)+
   ', forward='+BoolToStr(request.forwardCompatible,true);
 end;

function GLContextInfoToString(const info:TOpenGLContextInfo):string;
 begin
  result:='version='+IntToStr(info.major)+'.'+IntToStr(info.minor)+
   ', profile='+GLProfileToString(info.profile)+
   ', debug='+BoolToStr(info.debugContext,true)+
   ', forward='+BoolToStr(info.forwardCompatible,true)+
   ', accepted='+BoolToStr(info.requestAccepted,true);
 end;

{ TOpenGL }
procedure TOpenGL.Init(system:ISystemPlatform);
 var
  i:integer;
  cnt:GLINT;
  rc:UIntPtr;
  request:TOpenGLContextRequest;
  actual:TOpenGLContextInfo;
  pName,exList:string;

 {$IFDEF SDL}
 procedure InitOnSDL(system:ISystemPlatform);
  begin
   rc:=system.CreateOpenGLContext(request,actual);
   if rc=0 then
    raise EError.Create('Can''t create OpenGL context');
   ReadImplementationProperties;
   ReadExtensions;
  end;
 {$ENDIF}

 {$IFDEF MSWINDOWS}
 procedure InitOnWindows(system:ISystemPlatform);
  var
   DC:HDC;
   winRC:HGLRC;
  begin
   DC:=GetDC(system.GetWindowHandle);
   winRC:=system.CreateOpenGLContext(request,actual); // Create basic GL context
   if winRC=0 then
    raise EError.Create('Can''t create OpenGL context');
   Log.Msg('Activate GL context');
   ActivateRenderingContext(DC,winRC); // Load all OpenGL functions and extensions
   // Now create main context

  end;
 {$ENDIF}

 begin
  Log.Msg('Init OpenGL');
  exList:='';
  sysPlatform:=system;
  request:=oglContextRequest;
  Mem.Clear(actual,sizeof(actual));
  actual.profile:=glcpAny;
  Log.Force('OpenGL context request: '+GLContextRequestToString(request));
  {$IFDEF DGL}
  InitOpenGL;
  {$ENDIF}
  pName:=system.GetPlatformName;
  if pName='SDL' then begin
   {$IFDEF SDL}
   InitOnSDL(system);
   {$ENDIF}
  end else
  if pName='WINDOWS' then begin
   {$IFDEF MSWINDOWS}
   InitOnWindows(system);
   {$ENDIF}
  end;
  CheckForGLError(011);

  glVersion:=glGetString(GL_VERSION);
  glRenderer:=glGetString(GL_RENDERER);
  if actual.major=0 then begin
   glVersionNum:=GetVersion;
   actual.major:=trunc(glVersionNum);
   actual.minor:=round((glVersionNum-actual.major)*10);
  end;
  oglContextInfo:=actual;
  Log.Force('OpenGL context actual: '+GLContextInfoToString(oglContextInfo));
  Log.Force('OpenGL version: '+glVersion);
  Log.Force('OpenGL vendor: '+PAnsiChar(glGetString(GL_VENDOR)));
  Log.Force('OpenGL renderer: '+glRenderer);
  if not GL_VERSION_3_0 then
   raise EFatalError.Create('OpenGL 3.0 or higher required!'#13#10'Please update your video drivers.');

  glGetIntegerv(GL_NUM_EXTENSIONS,@cnt);
  for i:=0 to cnt-1 do
   exList:=exList+#13#10+PAnsiChar(glGetStringi(GL_EXTENSIONS,i));
  Log.Force('OpenGL extensions: '+exList);
  CheckForGLError(012);

  glVersionNum:=GetVersion;
  // Core profile requires a bound VAO for attribute setup.
  if (oglContextInfo.profile=glcpCore) and GL_VERSION_3_0 then begin
   glGenVertexArrays(1,@glDefaultVAO);
   glBindVertexArray(glDefaultVAO);
   Log.Force('OpenGL default VAO created: '+IntToStr(glDefaultVAO));
  end;

  // Create API objects
  // TODO: add try/except with rollback — if a later constructor fails, earlier objects remain dangling
  renderDevice:=TRenderDevice.Create;
  renderTargetAPI:=TGLRenderTargetAPI.Create;
  transformationAPI:=TTransformationAPI.Create;
  clippingAPI:=TClippingAPI.Create;
  shadersAPI:=TGLShadersAPI.Create;
  ownRenderTarget:=renderTargetAPI;
  ownTransformation:=transformationAPI;
  ownClipping:=clippingAPI;
  ownShader:=shadersAPI;
  // API shortcut ownership rule:
  // these global interface refs are assigned and cleared only by TOpenGL (Init/Done).
  Apus.Engine.API.transform:=transformationAPI;
  Apus.Engine.API.shader:=shadersAPI;
  CheckForGLError(013);

  TGLResourceManager.Create;
  ownResMan:=resourceManagerGL;
  TDrawer.Create;
  TTextDrawer.Create;
  Apus.Engine.API.draw:=drawer;
  Apus.Engine.API.txt:=textDrawer;
  CheckForGLError(014);
 end;

procedure TOpenGL.Done;
 begin
  Log.Msg('OGL Done start');
  // Release objects in explicit order while GL context is still alive.
  // Required pre-context-loss cleanup:
  // 1) Text and drawing helpers: cached text texture, neutral texture, temp shader.
  // 2) Shader API: compiled GL programs/shaders.
  // 3) Resource manager: textures, FBO/RBO, vertex/index buffers.
  // 4) Core state APIs and render device.
  // This order ensures resource users die before resource owners.
  // 1) Text and drawing helpers own textures/shaders.
  Apus.Engine.API.txt:=nil;
  textDrawer:=nil;
  Apus.Engine.API.draw:=nil;
  drawer:=nil;

  // 2) Shader system can own GL programs.
  Apus.Engine.API.shader:=nil;
  ownShader:=nil;
  shadersAPI:=nil;

  // 3) Resource manager should go after all texture users.
  ownResMan:=nil;
  resourceManagerGL:=nil;

  // 4) Core render APIs.
  Apus.Engine.API.transform:=nil;
  ownTransformation:=nil;
  ownClipping:=nil;
  ownRenderTarget:=nil;
  transformationAPI:=nil;
  clippingAPI:=nil;
  renderTargetAPI:=nil;
  renderDevice:=nil;
  if glDefaultVAO<>0 then begin
   glDeleteVertexArrays(1,@glDefaultVAO);
   glDefaultVAO:=0;
  end;
  Log.Msg('OGL Done finished');
 end;

procedure TOpenGL.PostDebugMsg(st:string8;id:integer=0);
 begin
  if (length(st)=0) or (@glDebugMessageInsert=nil) then exit;
  glDebugMessageInsert(GL_DEBUG_SOURCE_APPLICATION,GL_DEBUG_TYPE_MARKER, id, GL_DEBUG_SEVERITY_LOW,
   length(st),@st[1]);
 end;

procedure TOpenGL.PresentFrame;
 begin
  sysPlatform.OGLSwapBuffers;
 end;

function TOpenGL.QueryMaxRTSize:integer;
 begin
  result:=resourceManagerGL.maxRTsize;
 end;

procedure TOpenGL.Restore;
 begin
  renderDevice.Reset;
  shader.Reset;
  transform.DefaultView;
  SetCullMode(cullNone);
 end;

procedure TOpenGL.SetCullMode(mode: TCullMode);
 begin
  case mode of
   cullCCW:begin
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
   end;
   cullCW:begin
    glEnable(GL_CULL_FACE);
    glCullFace(GL_FRONT);
   end;
   cullNone:glDisable(GL_CULL_FACE);
  end;
 end;

function TOpenGL.SetVSyncDivider(n: integer):boolean;
 begin
  result:=false;
  {$IFDEF MSWINDOWS}
  if WGL_EXT_swap_control then begin
   wglSwapIntervalEXT(n);
   Log.Msg('VSync: swap interval=%d',[n]);
   exit(true);
  end;
  {$ENDIF}
 end;

procedure TOpenGL.BeginPaint(target: TTexture);
 var
  rw,rh:integer;
 begin
  if target=nil then
   PostDebugMsg('BeginPaint')
  else
   PostDebugMsg('BeginPaint: '+target.name);

  {if (canPaint>0) and (target=curTarget) then
    raise EWarning.Create('BP: target already set');}
  if canPaint>0 then
   renderTargetAPI.Push;
  inc(canPaint);
  shader.Reset;
  drawer.Reset;
  renderTargetAPI.Texture(target);
  renderTargetAPI.Viewport(0,0,-1,-1);
  renderTargetAPI.BlendMode(blAlpha);
  transformationAPI.DefaultView;
  clip.Nothing;
  CheckForGLError;
 end;

procedure TOpenGL.EndPaint;
 begin
  if canPaint<=0 then begin
   Log.Warn('EndPaint called without matching BeginPaint');
   exit;
  end;
  /// TODO: flush any draw caches
  dec(canPaint);
  if canPaint>0 then begin
   renderTargetAPI.Pop;
   renderTargetAPI.BlendMode(blAlpha);
   transformationAPI.DefaultView;
  end;
  clippingAPI.Restore;
 end;

procedure TOpenGL.Breakpoint;
 begin
  glFlush;
 end;

procedure TOpenGL.ChoosePixelFormats(out trueColor, trueColorAlpha, rtTrueColor,
  rtTrueColorAlpha: TImagePixelFormat; economyMode: boolean);
 begin
  trueColor:=ipfXRGB;
  trueColorAlpha:=ipfARGB;
  rtTrueColor:=ipfXRGB;
  rtTrueColorAlpha:=ipfARGB;
 end;
procedure TOpenGL.CopyFromBackbuffer(srcX,srcY:integer;image:TRawImage);
 var
  fbo:gluint;
 begin
  ASSERT(image.pixelFormat in [ipfARGB,ipfXRGB]);
  glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,@fbo);
  glBindBuffer(GL_PIXEL_PACK_BUFFER,0);
  if fbo=0 then glReadBuffer(GL_BACK)
   else glReadBuffer(GL_COLOR_ATTACHMENT0);
  image.Lock;
  glReadPixels(srcX,srcY,image.Width,image.Height,GL_BGRA,GL_UNSIGNED_BYTE,image.data);
  if fbo<>0 then // flip vertically: FBO origin is bottom-left
   image.FlipVertical;
  image.Unlock;
  CheckForGLError(021);
 end;
function TOpenGL.GetPixelValue(x,y:integer):cardinal;
 var
  fbo:gluint;
 begin
  glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,@fbo);
  if fbo<>0 then exit(0);
  glBindBuffer(GL_PIXEL_PACK_BUFFER,0);
  glReadBuffer(GL_BACK);
  glReadPixels(x,target.height-y-1,1,1,GL_BGRA,GL_UNSIGNED_BYTE,@result);
  CheckForGLError(022);
 end;

function TOpenGL.ShouldUseTextureAsDefaultRT:boolean;
 begin
  result:=GL_VERSION_3_0;
 end;

function TOpenGL.config:IGraphicsSystemConfig;
 begin
  result:=self;
 end;
function TOpenGL.shader:IShader;
 begin
  result:=shadersAPI;
 end;
function TOpenGL.clip:IClipping;
 begin
  result:=clippingAPI;
 end;
function TOpenGL.target:IRenderTarget;
 begin
  result:=renderTargetAPI;
 end;
function TOpenGL.resman:IResourceManager;
 begin
  result:=resourceManagerGL;
 end;
function TOpenGL.transform:ITransformation;
 begin
  result:=transformationAPI;
 end;
function TOpenGL.txt:ITextDrawer;
 begin
  result:=textDrawer;
 end;
function TOpenGL.draw:IDrawer;
 begin
  result:=drawer;
 end;

procedure TOpenGL.DrawDebugOverlay(idx: integer);
 begin

 end;

function TOpenGL.GetName: string8;
 begin
  result:=className;
 end;

function TOpenGL.GetVersion: single;
 begin
  result:=1.4;
  if GL_VERSION_1_5 then result:=1.5;
  if GL_VERSION_2_0 then result:=2.0;
  if GL_VERSION_2_1 then result:=2.1;
  if GL_VERSION_3_0 then result:=3.0;
  if GL_VERSION_3_1 then result:=3.1;
  if GL_VERSION_3_2 then result:=3.2;
  if GL_VERSION_3_3 then result:=3.3;
  if GL_VERSION_4_0 then result:=4.0;
  if GL_VERSION_4_1 then result:=4.1;
  if GL_VERSION_4_2 then result:=4.2;
  if GL_VERSION_4_3 then result:=4.3;
  if GL_VERSION_4_4 then result:=4.4;
  if GL_VERSION_4_5 then result:=4.5;
  if GL_VERSION_4_6 then result:=4.6;
 end;

{ TRenderDevice }
constructor TRenderDevice.Create;
 var
  i:integer;
 begin
  streamVB:=0;
  streamIB:=0;
  streamVBSize:=0;
  streamIBSize:=0;
  lastArrayBuffer:=-1;
  boundArrayBuffer:=0;
  boundElementArrayBuffer:=0;
  actualAttribArrays:=-1;
  for i:=0 to high(divisors) do
   divisors[i]:=-1;
 end;

destructor TRenderDevice.Destroy;
 begin
  if streamVB<>0 then glDeleteBuffers(1,@streamVB);
  if streamIB<>0 then glDeleteBuffers(1,@streamIB);
  inherited;
 end;

function TRenderDevice.PrimitiveVertexCount(primType:TPrimitiveType;primCount:integer):integer;
 begin
  case primtype of
   LINE_LIST:result:=primCount*2;
   LINE_STRIP:result:=primCount+1;
   TRG_LIST:result:=primCount*3;
   TRG_FAN,TRG_STRIP:result:=primCount+2;
   else result:=0;
  end;
 end;

function TRenderDevice.PrimitiveIndexCount(primType:TPrimitiveType;primCount:integer):integer;
 begin
  result:=PrimitiveVertexCount(primType,primCount);
 end;

function TRenderDevice.IsCoreProfile:boolean;
 begin
  result:=oglContextInfo.profile=glcpCore;
 end;

procedure TRenderDevice.TrackArrayBufferBinding(buffer:cardinal);
begin
 boundArrayBuffer:=buffer;
end;

procedure TRenderDevice.TrackElementBufferBinding(buffer:cardinal);
begin
 boundElementArrayBuffer:=buffer;
end;

procedure TRenderDevice.EnsureStreamVB(requiredSize:integer);
 begin
  if streamVB=0 then begin
   glGenBuffers(1,@streamVB);
   ASSERT(streamVB<>0);
  end;
  if requiredSize<=streamVBSize then exit;
  if streamVBSize=0 then
   streamVBSize:=1024;
  while streamVBSize<requiredSize do
   streamVBSize:=streamVBSize*2;
  glBindBuffer(GL_ARRAY_BUFFER,streamVB);
  TrackArrayBufferBinding(streamVB);
  // TODO(low): reduce bind churn around stream buffer growth/upload path (keep one bind when possible).
  glBufferData(GL_ARRAY_BUFFER,streamVBSize,nil,GL_STREAM_DRAW);
 end;

procedure TRenderDevice.EnsureStreamIB(requiredSize:integer);
 begin
  if streamIB=0 then begin
   glGenBuffers(1,@streamIB);
   ASSERT(streamIB<>0);
  end;
  if requiredSize<=streamIBSize then exit;
  if streamIBSize=0 then
   streamIBSize:=1024;
  while streamIBSize<requiredSize do
   streamIBSize:=streamIBSize*2;
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,streamIB);
  TrackElementBufferBinding(streamIB);
  // TODO(low): reduce bind churn around stream buffer growth/upload path (keep one bind when possible).
  glBufferData(GL_ELEMENT_ARRAY_BUFFER,streamIBSize,nil,GL_STREAM_DRAW);
 end;

procedure TRenderDevice.UploadStreamVertices(vertices:pointer;vertexLayout:TVertexLayout;vertexCount:integer);
 var
  bytes:integer;
 begin
  ASSERT(vertices<>nil);
  bytes:=vertexCount*vertexLayout.stride;
  EnsureStreamVB(bytes);
  glBindBuffer(GL_ARRAY_BUFFER,streamVB);
  TrackArrayBufferBinding(streamVB);
  glBufferSubData(GL_ARRAY_BUFFER,0,bytes,vertices);
 end;

procedure TRenderDevice.UploadStreamIndices(indices:pointer;indexCount:integer);
 var
  bytes:integer;
 begin
  ASSERT(indices<>nil);
  bytes:=indexCount*2;
  EnsureStreamIB(bytes);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,streamIB);
  TrackElementBufferBinding(streamIB);
  glBufferSubData(GL_ELEMENT_ARRAY_BUFFER,0,bytes,indices);
 end;

procedure TRenderDevice.Draw(primType:TPrimitiveType; primCount: integer; vertices: pointer;
  vertexLayout:TVertexLayout);
 var
  vertexCount:integer;
  useStream:boolean;
 begin
  shader.Apply(vertexLayout);
  vertexCount:=PrimitiveVertexCount(primType,primCount);
  useStream:=vertices<>nil;
  if useStream then begin
   UploadStreamVertices(vertices,vertexLayout,vertexCount);
   vertices:=nil; // attributes are offsets in bound stream VBO
  end;
  SetupAttributes(vertices,vertexLayout);
  case primtype of
   LINE_LIST:glDrawArrays(GL_LINES,0,primCount*2);
   LINE_STRIP:glDrawArrays(GL_LINE_STRIP,0,primCount+1);
   TRG_LIST:glDrawArrays(GL_TRIANGLES,0,primCount*3);
   TRG_FAN:glDrawArrays(GL_TRIANGLE_FAN,0,primCount+2);
   TRG_STRIP:glDrawArrays(GL_TRIANGLE_STRIP,0,primCount+2);
  end;
  CheckForGLError(111);
 end;

procedure TRenderDevice.DrawIndexed(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;primCount:integer);
 var
  indexCount,vertexCount:integer;
  useStream:boolean;
 begin
  shader.Apply(vertexLayout);
  indexCount:=PrimitiveIndexCount(primType,primCount);
  // TODO(low): consider removing this overload or extending it with vrtCount; stream upload without vertex count is unsafe.
  useStream:=false;
  if useStream then begin
   vertexCount:=indexCount;
   UploadStreamVertices(vertices,vertexLayout,vertexCount);
   UploadStreamIndices(indices,indexCount);
   vertices:=nil;
   indices:=nil;
  end else begin
   if IsCoreProfile and ((vertices<>nil) or (indices<>nil)) then
    ASSERT(false,'Use ranged DrawIndexed(...) with vrtCount for core-profile RAM-backed indexed draws');
   if not IsCoreProfile then begin
    if vertices<>nil then begin
     glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
     TrackArrayBufferBinding(0);
    end;
    if indices<>nil then begin
     glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0); // client index pointers require unbound EBO
     TrackElementBufferBinding(0);
    end;
   end;
  end;
  SetupAttributes(vertices,vertexLayout);
  case primtype of
   LINE_LIST:glDrawElements(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,indices);
   LINE_STRIP:glDrawElements(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,indices);
   TRG_LIST:glDrawElements(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,indices);
   TRG_FAN:glDrawElements(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,indices);
   TRG_STRIP:glDrawElements(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,indices);
  end;
  CheckForGLError(112);
 end;

procedure TRenderDevice.DrawIndexed(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout; vrtStart,vrtCount:integer; indStart,primCount:integer);
 var
  indexCount,vertexCount:integer;
  useStream:boolean;
 begin
  shader.Apply(vertexLayout);
  indexCount:=PrimitiveIndexCount(primType,primCount);
  useStream:=vertices<>nil;
  if useStream then begin
   // Keep original index values by uploading vertices up to the range end.
   vertexCount:=vrtStart+vrtCount;
   UploadStreamVertices(vertices,vertexLayout,vertexCount);
   UploadStreamIndices(indices,indexCount);
   vertices:=nil;
   indices:=nil;
  end else
  if not IsCoreProfile then begin
   if vertices<>nil then begin
    glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
    TrackArrayBufferBinding(0);
   end;
   if indices<>nil then begin
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0); // client index pointers require unbound EBO
    TrackElementBufferBinding(0);
   end;
  end;
  SetupAttributes(vertices,vertexLayout);
  case primtype of
   LINE_LIST:glDrawRangeElements(GL_LINES,vrtStart,vrtStart+vrtCount-1,primCount*2,GL_UNSIGNED_SHORT,indices);
   LINE_STRIP:glDrawRangeElements(GL_LINE_STRIP,vrtStart,vrtStart+vrtCount-1,primCount+1,GL_UNSIGNED_SHORT,indices);
   TRG_LIST:glDrawRangeElements(GL_TRIANGLES,vrtStart,vrtStart+vrtCount-1,primCount*3,GL_UNSIGNED_SHORT,indices);
   TRG_FAN:glDrawRangeElements(GL_TRIANGLE_FAN,vrtStart,vrtStart+vrtCount-1,primCount+2,GL_UNSIGNED_SHORT,indices);
   TRG_STRIP:glDrawRangeElements(GL_TRIANGLE_STRIP,vrtStart,vrtStart+vrtCount-1,primCount+2,GL_UNSIGNED_SHORT,indices);
  end;
  CheckForGLError(112);
 end;

procedure TRenderDevice.DrawInstanced(primType:TPrimitiveType;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;primCount,instances:integer);
 var
  indexCount,vertexCount:integer;
  useStream:boolean;
 begin
  shader.Apply(vertexLayout);
  indexCount:=PrimitiveIndexCount(primType,primCount);
  // TODO(low): consider removing this overload or extending it with vrtCount; stream upload without vertex count is unsafe.
  useStream:=false;
  if useStream then begin
   vertexCount:=indexCount;
   UploadStreamVertices(vertices,vertexLayout,vertexCount);
   UploadStreamIndices(indices,indexCount);
   vertices:=nil;
   indices:=nil;
  end else begin
   if IsCoreProfile and ((vertices<>nil) or (indices<>nil)) then
    ASSERT(false,'Use ranged DrawIndexed(...) with vrtCount for core-profile RAM-backed indexed draws');
   if not IsCoreProfile then begin
    if vertices<>nil then begin
     glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
     TrackArrayBufferBinding(0);
    end;
    if indices<>nil then begin
     glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0); // client index pointers require unbound EBO
     TrackElementBufferBinding(0);
    end;
   end;
  end;
  SetupAttributes(vertices,vertexLayout);
  case primtype of
   LINE_LIST:glDrawElementsInstanced(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,indices,instances);
   LINE_STRIP:glDrawElementsInstanced(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,indices,instances);
   TRG_LIST:glDrawElementsInstanced(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,indices,instances);
   TRG_FAN:glDrawElementsInstanced(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,indices,instances);
   TRG_STRIP:glDrawElementsInstanced(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,indices,instances);
  end;
  CheckForGLError(113);
 end;

procedure TRenderDevice.DrawInstanced(primType:TPrimitiveType;vertices:pointer;
     vertexLayout:TVertexLayout;primCount,instances:integer);
 var
  vertexCount:integer;
  useStream:boolean;
 begin
  shader.Apply(vertexLayout);
  vertexCount:=PrimitiveVertexCount(primType,primCount);
  useStream:=vertices<>nil;
  if useStream then begin
   UploadStreamVertices(vertices,vertexLayout,vertexCount);
   vertices:=nil;
  end else
  if (vertices<>nil) and (not IsCoreProfile) then begin
   glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
   TrackArrayBufferBinding(0);
  end;
  SetupAttributes(vertices,vertexLayout);
  case primtype of
   LINE_LIST:glDrawArraysInstanced(GL_LINES,0,primCount*2,instances);
   LINE_STRIP:glDrawArraysInstanced(GL_LINE_STRIP,0,primCount+1,instances);
   TRG_LIST:glDrawArraysInstanced(GL_TRIANGLES,0,primCount*3,instances);
   TRG_FAN:glDrawArraysInstanced(GL_TRIANGLE_FAN,0,primCount+2,instances);
   TRG_STRIP:glDrawArraysInstanced(GL_TRIANGLE_STRIP,0,primCount+2,instances);
  end;
  CheckForGLError(113);
 end;

procedure TRenderDevice.Reset;
 var
  i: Integer;
 begin
  lastVertices:=nil;
  lastLayout.stride:=0;
  lastArrayBuffer:=-1;
  for i:=0 to 9 do glDisableVertexAttribArray(i);
  actualAttribArrays:=0;
 end;

procedure TRenderDevice.SetupAttributes(vertices:pointer;vertexLayout:TVertexLayout);
 var
  n,baseN:integer;
 procedure ProcessLayout(vertices:pointer;vLayout:TVertexLayout);
  var
   i,v,dim:integer;
   p:pointer;
  begin
   with vLayout do
    for i:=0 to 5 do begin
     v:=(layout and $F)*4;
     layout:=layout shr 4;
     p:=pointer(UIntPtr(vertices)+v);
     if (v=0) and (i>0) then continue;
     if (i=0) and (v=15*4) then begin // position is 2D
      dim:=2; p:=vertices;
     end else
      dim:=3;
     case i of
      0:glVertexAttribPointer(n,dim,GL_FLOAT,GL_FALSE,stride,p); // position
      1,5:glVertexAttribPointer(n,3,GL_FLOAT,GL_FALSE,stride,p); // normal
      2:glVertexAttribPointer(n,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,p); // color
      3,4:glVertexAttribPointer(n,2,GL_FLOAT,GL_FALSE,stride,p); // uv1
     end;
     inc(n);
     if layout=0 then break;
    end;
  end;
 procedure EnableDisableArrays;
  var
   i:integer;
  begin
   // adjust number of vertex attrib arrays
   if actualAttribArrays<0 then begin // unknown
    for i:=0 to High(divisors) do
     if i<n then glEnableVertexAttribArray(i)
      else glDisableVertexAttribArray(i);
    actualAttribArrays:=n;
   end;
   // enable more if used
   while n>actualAttribArrays do begin
    glEnableVertexAttribArray(actualAttribArrays);
    inc(actualAttribArrays);
   end;
   // disable unused
   while n<actualAttribArrays do begin
    dec(actualAttribArrays);
    glDisableVertexAttribArray(actualAttribArrays);
   end;
  end;
 procedure SetArrayDivisors;
  var
   i,d:integer;
  begin
   // set divisors
   for i:=0 to n-1 do begin
    if i<baseN then d:=baseDivisor
     else d:=extraDivisor;
    if divisors[i]<>d then begin
     glVertexAttribDivisor(i,d);
     divisors[i]:=d;
    end;
   end;
  end;
 begin
  if IsCoreProfile then begin
   // In core profile attribute pointers are interpreted as offsets in a bound ARRAY_BUFFER.
   // We track this binding locally via TrackArrayBufferBinding/stream uploads.
   ASSERT(boundArrayBuffer<>0,'Core profile requires GL_ARRAY_BUFFER during attribute setup');
   if glDefaultVAO<>0 then
    glBindVertexArray(glDefaultVAO);
  end;
  if (lastVertices=vertices) and (lastArrayBuffer=boundArrayBuffer) and (vertexLayout.Equals(lastLayout)) then exit;
  lastVertices:=vertices;
  lastLayout:=vertexLayout;
  lastArrayBuffer:=boundArrayBuffer;
  n:=0;
  ProcessLayout(vertices,vertexLayout);
  baseN:=n;
  if extraVertices<>nil then  // additional vertex buffer
   ProcessLayout(extraVertices,extraLayout);

  EnableDisableArrays;
  SetArrayDivisors;
 end;

procedure TRenderDevice.SetVertexDataDivisors(baseDivisor,extraDivisor:integer);
 begin
  self.baseDivisor:=baseDivisor;
  self.extraDivisor:=extraDivisor;
 end;

procedure TRenderDevice.UseExtraVertexData(vertices:pointer;vertexLayout:TVertexLayout);
 begin
  extraVertices:=vertices;
  extraLayout:=vertexLayout;
 end;

{ TGLRenderTargetAPI }

procedure TGLRenderTargetAPI.BlendMode(blend: TBlendingMode);
begin
 if blend=curBlend then exit;
 case blend of
  blNone:begin
   glDisable(GL_BLEND);
  end;
  blAlpha:begin
   glEnable(GL_BLEND);
   if GL_VERSION_2_0 then
    glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
   else
    glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
  end;
  blAdd:begin
   glEnable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA,GL_ONE);
  end;
  blSub:begin
   raise EError.Create('blSub not supported');
  end;
  blModulate:begin
   glEnable(GL_BLEND);
   glBlendFuncSeparate(GL_ZERO,GL_SRC_COLOR,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
  end;
  blModulate2X:begin
   glEnable(GL_BLEND);
   glBlendFuncSeparate(GL_DST_COLOR,GL_SRC_COLOR,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
  end;
  blMove:begin
   glEnable(GL_BLEND);
   glBlendFunc(GL_ONE,GL_ZERO);
  end
 else
  raise EWarning.Create('Blending mode not supported');
 end;
 curBlend:=blend;
 CheckForGLError(103);
end;

function ColorComponent(color:cardinal;idx:integer):single;
 begin
  result:=((color shr (idx*8)) and $FF)/255;
 end;

procedure TGLRenderTargetAPI.ClearBuffers(fColor,fDepth,fStencil:boolean; color:cardinal;zbuf:single;stencil:integer);
 var
  mask:cardinal;
  val:GLboolean;
 begin
  mask:=0;
  if fColor then begin
   mask:=GL_COLOR_BUFFER_BIT;
   glClearColor(
     ColorComponent(color,2),
     ColorComponent(color,1),
     ColorComponent(color,0),
     ColorComponent(color,3));
  end;
  if fDepth then begin
   mask:=mask+GL_DEPTH_BUFFER_BIT;
   {$IFDEF GLES}
   glClearDepthf(zbuf);
   {$ELSE}
   glClearDepth(zbuf);
   {$ENDIF}
  end;
  if fStencil then begin
   mask:=mask+GL_STENCIL_BUFFER_BIT;
   glClearStencil(stencil);
  end;
  glGetBooleanv(GL_SCISSOR_TEST,@val);
  CheckForGLError(101);
  if val then glDisable(GL_SCISSOR_TEST);
  glClear(mask);
  CheckForGLError(101);
  if val then glEnable(GL_SCISSOR_TEST);
 end;

procedure TGLRenderTargetAPI.Clear(color:cardinal;zbuf:single;stencil:integer);
 begin
  ClearBuffers(true,zBuf>=0,stencil>=0,color,zBuf,stencil);
 end;

procedure TGLRenderTargetAPI.ClearDepth(zbuf:single;stencil:integer);
 begin
  ClearBuffers(false,zBuf>=0,stencil>=0,0,zBuf,stencil);
 end;

procedure TGLRenderTargetAPI.Clip(x,y,w,h: integer);
 begin
  if (x<=0) and (y<=0) and (x+w>=realWidth) and (y+h>=realHeight) then begin
   if scissor then begin
    glDisable(GL_SCISSOR_TEST);
    scissor:=false;
   end;
   exit;
  end;
  if not scissor then begin
   glEnable(GL_SCISSOR_TEST);
   scissor:=true;
  end;
  if curTarget=nil then begin // invert Y-axis
   y:=realHeight-y-h;
  end;
  glScissor(x,y,w,h);
 end;

constructor TGLRenderTargetAPI.Create;
 var
  data:array[0..3] of GLInt;
 begin
  inherited;
  glGetIntegerv(GL_VIEWPORT,@data[0]);
  backBufferWidth:=data[2];
  backBufferHeight:=data[3];
 end;

procedure TGLRenderTargetAPI.Resized(newWidth, newHeight: integer);
 begin
  backbufferWidth:=newWidth;
  backbufferHeight:=newHeight;
 end;

procedure TGLRenderTargetAPI.ApplyMask;
 begin
   {$IFDEF GLES}
   glColorMask((curmask and 4),
               (curmask and 2),
               (curmask and 1),
               (curmask and 8));
   {$ELSE}
   glColorMask((curmask and 4)>0,
               (curmask and 2)>0,
               (curmask and 1)>0,
               (curmask and 8)>0);
   {$ENDIF}
 end;

procedure TGLRenderTargetAPI.Backbuffer;
 begin
  inherited;
  {$IFDEF GLES11}
  glBindFramebufferOES(GL_FRAMEBUFFER_OES,0);
  {$ENDIF}
  {$IFDEF GLES20}
  glBindFramebuffer(GL_FRAMEBUFFER,0);
  {$ENDIF}
  {$IFNDEF GLES}
  if GL_ARB_framebuffer_object then
    glBindFramebuffer(GL_FRAMEBUFFER,0);
  {$ENDIF}
  realWidth:=backBufferWidth;
  realHeight:=backBufferHeight;
  CheckForGLError(100);
  glScissor(0,0,realWidth,realHeight);
  clippingAPI.AssignActual(Rect(0,0,realWidth,realHeight));
  glDisable(GL_SCISSOR_TEST);
  scissor:=false;
 end;

procedure TGLRenderTargetAPI.Texture(tex:TTexture);
 begin
  if tex=nil then begin
   Backbuffer;
   exit;
  end;
  inherited;
  ASSERT(tex is TGLTexture);
  TGLTexture(tex).SetAsRenderTarget;
  realWidth:=tex.width;
  realHeight:=tex.height;
  renderWidth:=realWidth;
  renderHeight:=realHeight;
  clippingAPI.AssignActual(Rect(0,0,realWidth,realHeight));
  glDisable(GL_SCISSOR_TEST);
  scissor:=false;
 end;

procedure TGLRenderTargetAPI.UseDepthBuffer(test:TDepthBufferTest;writeEnable:boolean);
 begin
  if test=dbDisabled then begin
   glDisable(GL_DEPTH_TEST)
  end else begin
   glEnable(GL_DEPTH_TEST);
   case test of
    dbPass:glDepthFunc(GL_ALWAYS);
    dbPassLess:glDepthFunc(GL_LESS);
    dbPassLessEqual:glDepthFunc(GL_LEQUAL);
    dbPassGreater:glDepthFunc(GL_GREATER);
    dbNever:glDepthFunc(GL_NEVER);
   end;
   glDepthMask(writeEnable);
  end;
 end;

procedure TGLRenderTargetAPI.Viewport(oX,oY,VPwidth,VPheight,renderWidth,renderHeight:integer);
 begin
  inherited; // adjust viewport here
  if curTarget<>nil then
   glViewport(vPort.Left,vPort.Top,vPort.Width,vPort.Height)
  else
   glViewport(vPort.Left,realHeight-vPort.Top-vPort.Height,vPort.Width,vPort.Height);
 end;

end.
