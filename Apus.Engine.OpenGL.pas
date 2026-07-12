// OpenGL wrapper for the engine
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$I defines.inc}
unit Apus.Engine.OpenGL;
interface
uses Apus.Core, Apus.Engine.GpuLayout,
  {$IFDEF GLDESKTOP}dglOpenGL,{$ENDIF}
  {$IFDEF GLES}dglOpenGLES,{$ENDIF}
  // dglOpenGL pulls X11's Window/window symbols on Linux. Keep it before
  // Apus.Engine.API so the engine threadvar window remains the short name.
  Apus.Engine.API,
  Apus.Images;

type
 TOpenGLContextProfile=(oglpAny,
                       oglpCompatibility,
                       oglpCore,
                       oglpES); // OpenGL ES profile (GLES builds)

 TOpenGLContextDesc=record
  // request
  minMajor:byte;
  minMinor:byte;
  profile:TOpenGLContextProfile;
  debugContext:boolean;
  forwardCompatible:boolean;
  preferHighest:boolean;
  // actual
  actualMajor:byte;
  actualMinor:byte;
  requestAccepted:boolean;
 end;

 // Main graphics-system implementation for OpenGL.
 // Owns and wires all rendering subsystems (target, shaders, resman, text, draw).
 // Lifecycle is controlled via IGraphicsSystem (Init/Done).
 // Important: all GL-owning services must be released in Done BEFORE the platform
 // destroys the GL context, otherwise GPU resources cannot be deleted safely.
 TOpenGL=class(TInterfacedObject,IGraphicsSystem,IGraphicsSystemConfig)
  procedure Init(window:TWindow);
  procedure InitThreadContext(window:TWindow);
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
  wnd:TWindow;
  class threadvar
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
threadvar
 debugGroupDepth:integer;
var
 // OpenGL context request template and actual context info.
 // Template is configured by app-level code before game startup.
 oglContextTemplate:TOpenGLContextDesc;
 oglContextInfo:TOpenGLContextDesc;

 procedure SetupGLDebugOutputForCurrentContext(const actual:TOpenGLContextDesc; const tag:string8='');
 procedure CheckForGLError(lab:integer=0); inline;
 procedure PushDebugGroup(const st:String8;id:integer=0); inline;
 procedure PopDebugGroup; inline;

implementation
 uses
  SysUtils,
  Types,
  Apus.Engine.Types,
  Apus.Engine.Graphics,
  Apus.Engine.Draw,
  Apus.Engine.TextDraw,
  Apus.Engine.ResManGL,
  Apus.Engine.ShadersGL,
  Apus.Engine.Window,
  Apus.Log;

type
 // Low-level bridge from engine vertex data to OpenGL draw calls.
 // Used by higher-level APIs (draw/text/shaders), does not own scene resources.
 TRenderDevice=class(TInterfacedObject,IRenderDevice,IRenderDeviceBindTracking)
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

  // R-19: table-driven attribute binding for a GPU mesh (coexists with SetupAttributes).
  procedure BindMeshLayout(layout:TGpuLayout);
  procedure UnbindMeshLayout;
  procedure DrawMesh(layout:TGpuLayout;first,count,indexBytes:integer);

{  // Draw primitives using custom buffers
  procedure DrawBuffer(primType:TPrimitiveType;vb:TVertexBuffer;ib:TIndexBuffer); overload;

  // Draw indexed primitives using built-in buffer
  procedure DrawBuffer(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); overload;}

 protected
  class threadvar
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
   meshEnabledMask:cardinal; // R-19: bitmask of attrib locations enabled by BindMeshLayout
   streamVB,streamIB:cardinal;
   streamVBSize,streamIBSize:integer;
   threadReady:boolean;
  function PrimitiveVertexCount(primType:TPrimitiveType;primCount:integer):integer;
  function PrimitiveIndexCount(primType:TPrimitiveType;primCount:integer):integer;
  function IsCoreProfile:boolean;
  procedure EnsureThreadState;
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
  procedure SetDepthMode(test:TDepthTest=TDepthTest.Keep;write:TDepthWrite=TDepthWrite.Keep); override;
  procedure BlendMode(blend:TBlendingMode); override;
  procedure Clip(x,y,w,h:integer); override;
  procedure ApplyMask; override;
  procedure Resized(newWidth,newHeight:integer); override;
 protected
  class threadvar
   scissor:boolean;
   backBufferWidth,backBufferHeight:integer;
   threadReady:boolean;
   // Default framebuffer id: 0 on desktop/Android; iOS under SDL uses a
   // non-zero default FBO. Nothing sets this yet - plumbing only (R-30).
   defaultFramebuffer:cardinal;
  procedure EnsureThreadState;
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
   oglpCompatibility:result:='compatibility';
   oglpCore:result:='core';
   oglpES:result:='es';
   else result:='any';
  end;
 end;

function GLContextRequestToString(const request:TOpenGLContextDesc):string;
 begin
  result:='min='+IntToStr(request.minMajor)+'.'+IntToStr(request.minMinor)+
   ', preferHighest='+BoolToStr(request.preferHighest,true)+
   ', profile='+GLProfileToString(request.profile)+
   ', debug='+BoolToStr(request.debugContext,true)+
   ', forward='+BoolToStr(request.forwardCompatible,true);
 end;

function GLContextInfoToString(const info:TOpenGLContextDesc):string;
 begin
  result:='version='+IntToStr(info.actualMajor)+'.'+IntToStr(info.actualMinor)+
   ', profile='+GLProfileToString(info.profile)+
   ', debug='+BoolToStr(info.debugContext,true)+
   ', forward='+BoolToStr(info.forwardCompatible,true)+
   ', accepted='+BoolToStr(info.requestAccepted,true);
 end;

procedure HandleGLDebugMessage(source,typ,id,severity:GLenum;len:GLsizei;const message_:PGLchar;userParam:PGLvoid); {$IFDEF DGL_WIN}stdcall{$ELSE}cdecl{$ENDIF}; forward;

procedure SetupGLDebugOutputForCurrentContext(const actual:TOpenGLContextDesc; const tag:string8='');
 var
  where:string8;
 begin
  if not actual.debugContext then exit;
  if tag<>'' then
   where:=' ('+tag+')'
  else
   where:='';
  // Callback registration is per-context. Each shared context must set it explicitly.
  {$IFDEF GLES}
  // ES 3.0 only has the GL_KHR_debug extension form, no ARB/core variant.
  if @glDebugMessageCallbackKHR<>nil then begin
   glEnable(GL_DEBUG_OUTPUT_KHR);
   glDebugMessageCallbackKHR(TglDebugProcKHR(@HandleGLDebugMessage),nil);
   Log.Force('OpenGL debug callback enabled (KHR)'+where);
  end else
   Log.Warn('Debug context requested but debug callback API is not available'+where);
  {$ELSE}
  if @glDebugMessageCallback<>nil then begin
   glEnable(GL_DEBUG_OUTPUT);
   if @glDebugMessageControl<>nil then
    glDebugMessageControl(GL_DONT_CARE,GL_DONT_CARE,GL_DEBUG_SEVERITY_NOTIFICATION,0,nil,GL_FALSE);
   glDebugMessageCallback(TGLDEBUGPROC(@HandleGLDebugMessage),nil);
   Log.Force('OpenGL debug callback enabled (KHR)'+where);
  end else
  if @glDebugMessageCallbackARB<>nil then begin
   if @glDebugMessageControlARB<>nil then
    glDebugMessageControlARB(GL_DONT_CARE,GL_DONT_CARE,GL_DEBUG_SEVERITY_NOTIFICATION,0,nil,GL_FALSE);
   glDebugMessageCallbackARB(@HandleGLDebugMessage,nil);
   Log.Force('OpenGL debug callback enabled (ARB)'+where);
  end else
   Log.Warn('Debug context requested but debug callback API is not available'+where);
  {$ENDIF}
 end;

{ TOpenGL }
procedure TOpenGL.Init(window:TWindow);
 var
  i:integer;
  cnt:GLINT;
  request:TOpenGLContextDesc;
  actual:TOpenGLContextDesc;
  exList:string;
 begin
  Log.Msg('Init OpenGL');
  exList:='';
  wnd:=window;
  request:=oglContextTemplate;
  actual:=request;
  Log.Force('OpenGL context request: '+GLContextRequestToString(request));
  {$IFDEF GLDESKTOP}
  InitOpenGL;
  {$ENDIF}
  wnd.InitGraph;
  actual:=oglContextInfo;
  {$IFDEF GLDESKTOP}
  ReadImplementationProperties;
  ReadExtensions;
  {$ENDIF}
  CheckForGLError(011);

  glVersion:=PAnsiChar(glGetString(GL_VERSION));
  glRenderer:=PAnsiChar(glGetString(GL_RENDERER));
  if actual.actualMajor=0 then begin
   glVersionNum:=GetVersion;
   actual.actualMajor:=trunc(glVersionNum);
   actual.actualMinor:=round((glVersionNum-actual.actualMajor)*10);
  end;
  if (request.profile in [oglpCore,oglpES]) and ((not actual.requestAccepted) or (actual.profile<>request.profile)) then
   raise EFatalError.Create(GLProfileToString(request.profile)+' profile was requested but not created.'#13#10+
    'Requested: '+GLContextRequestToString(request)+#13#10+
    'Actual: '+GLContextInfoToString(actual));
  oglContextInfo:=actual;
  Log.Force('OpenGL context actual: '+GLContextInfoToString(oglContextInfo));
  // Stage 7 debug tooling:
  // callback is context-local, so it must be configured for every context.
  SetupGLDebugOutputForCurrentContext(actual,'main');
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
  if (oglContextInfo.profile=oglpCore) and GL_VERSION_3_0 then begin
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
  InitThreadContext(window);
  CheckForGLError(014);
 end;

procedure TOpenGL.InitThreadContext(window:TWindow);
begin
 wnd:=window;
 // Prime per-thread backend state for deterministic startup.
 // Keep lazy EnsureThreadState as fallback in all subsystems.
 target.Resized(window.windowWidth,window.windowHeight);
 target.Viewport(0,0,window.windowWidth,window.windowHeight,window.renderWidth,window.renderHeight);
 glFrontFace(GL_CCW); // anchor the front-face winding the cull-mode mapping relies on
 shader.Reset;
 clip.Nothing;
 clip.Restore;
 transform.DefaultView;
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
  if length(st)=0 then exit;
  {$IFDEF GLES}
  if @glDebugMessageInsertKHR=nil then exit;
  glDebugMessageInsertKHR(GL_DEBUG_SOURCE_APPLICATION,GL_DEBUG_TYPE_MARKER, id, GL_DEBUG_SEVERITY_LOW,
   length(st),@st[1]);
  {$ELSE}
  if @glDebugMessageInsert=nil then exit;
  glDebugMessageInsert(GL_DEBUG_SOURCE_APPLICATION,GL_DEBUG_TYPE_MARKER, id, GL_DEBUG_SEVERITY_LOW,
   length(st),@st[1]);
  {$ENDIF}
 end;

procedure TOpenGL.PresentFrame;
 begin
  PostDebugMsg('PresentFrame');
  wnd.PresentFrame;
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
  SetCullMode(TCullMode.DrawAll);
 end;

procedure TOpenGL.SetCullMode(mode: TCullMode);
 begin
  // front=CCW is fixed at context init (glFrontFace(GL_CCW)), so GL_BACK=CW, GL_FRONT=CCW
  case mode of
   TCullMode.DrawCCW:begin // keep CCW, cull CW (back)
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
   end;
   TCullMode.DrawCW:begin // keep CW, cull CCW (front)
    glEnable(GL_CULL_FACE);
    glCullFace(GL_FRONT);
   end;
   TCullMode.DrawAll:glDisable(GL_CULL_FACE);
  end;
 end;

function TOpenGL.SetVSyncDivider(n: integer):boolean;
 begin
  result:=false;
  {$IF DEFINED(MSWINDOWS) AND DEFINED(GLDESKTOP)}
  // WGL_EXT_swap_control is a desktop WGL extension; GLES (e.g. ANGLE) uses EGL's
  // eglSwapInterval instead - not wired up yet (R-24/R-30 mobile work).
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
  grp:String8;
 begin
  if target=nil then
   PostDebugMsg('BeginPaint')
  else
   PostDebugMsg('BeginPaint: '+target.name);
  if target=nil then
   grp:='Frame'
  else
   grp:='RenderTarget:'+target.name;
  // Stage 7: balanced debug groups are required for stable NSight event tree.
  // Group depth is guarded in PopDebugGroup to survive unmatched EndPaint calls.
  PushDebugGroup(grp);

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
  PopDebugGroup;
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
  {$IFDEF GLES}
  // GLES has no GL_BGRA readback format: read RGBA, then swap R/B on CPU.
  glReadPixels(srcX,srcY,image.Width,image.Height,GL_RGBA,GL_UNSIGNED_BYTE,image.data);
  SwapRedBlue8888(image.data,image.Width*image.Height);
  {$ELSE}
  glReadPixels(srcX,srcY,image.Width,image.Height,GL_BGRA,GL_UNSIGNED_BYTE,image.data);
  {$ENDIF}
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
  {$IFDEF GLES}
  glReadPixels(x,target.height-y-1,1,1,GL_RGBA,GL_UNSIGNED_BYTE,@result);
  SwapRedBlue8888(@result,1);
  {$ELSE}
  glReadPixels(x,target.height-y-1,1,1,GL_BGRA,GL_UNSIGNED_BYTE,@result);
  {$ENDIF}
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
  {$IFDEF GLES}
  // ES 3.0 baseline for this slice; dglOpenGLES only exposes a GL_VERSION_3_0 flag.
  result:=3.0;
  {$ELSE}
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
  {$ENDIF}
 end;

{ TRenderDevice }
constructor TRenderDevice.Create;
 begin
  EnsureThreadState;
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
  EnsureThreadState;
  // ES follows the same strict path: buffer-backed draws only, no client-memory pointers
  result:=oglContextInfo.profile in [oglpCore,oglpES];
 end;

procedure TRenderDevice.EnsureThreadState;
 var
  i:integer;
 begin
  if threadReady then exit;
  streamVB:=0;
  streamIB:=0;
  streamVBSize:=0;
  streamIBSize:=0;
  lastVertices:=nil;
  lastLayout.stride:=0;
  lastStride:=0;
  lastArrayBuffer:=-1;
  boundArrayBuffer:=0;
  boundElementArrayBuffer:=0;
  baseDivisor:=0;
  extraDivisor:=0;
  extraVertices:=nil;
  extraLayout.stride:=0;
  actualAttribArrays:=-1;
  for i:=0 to high(divisors) do
   divisors[i]:=-1;
  threadReady:=true;
 end;

procedure TRenderDevice.TrackArrayBufferBinding(buffer:cardinal);
begin
 EnsureThreadState;
 boundArrayBuffer:=buffer;
end;

procedure PushDebugGroup(const st:String8;id:integer=0);
 begin
  // Functions may be absent on old drivers even with debug context requested.
  if length(st)=0 then exit;
  {$IFDEF GLES}
  if @glPushDebugGroupKHR=nil then exit;
  glPushDebugGroupKHR(GL_DEBUG_SOURCE_APPLICATION,id,length(st),@st[1]);
  {$ELSE}
  if @glPushDebugGroup=nil then exit;
  glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION,id,length(st),@st[1]);
  {$ENDIF}
  inc(debugGroupDepth);
 end;

procedure PopDebugGroup;
 begin
  // Keep this safe for error paths: never pop below zero.
  if debugGroupDepth<=0 then exit;
  {$IFDEF GLES}
  if @glPopDebugGroupKHR=nil then exit;
  glPopDebugGroupKHR;
  {$ELSE}
  if @glPopDebugGroup=nil then exit;
  glPopDebugGroup;
  {$ENDIF}
  dec(debugGroupDepth);
 end;

procedure HandleGLDebugMessage(source,typ,id,severity:GLenum;len:GLsizei;const message_:PGLchar;userParam:PGLvoid); {$IFDEF DGL_WIN}stdcall{$ELSE}cdecl{$ENDIF};
 var
  st:string8;
  srcName,typeName,severityName:string8;
 function DebugSourceName(v:GLenum):string8; inline;
  begin
   case v of
    GL_DEBUG_SOURCE_API:result:='API';
    GL_DEBUG_SOURCE_WINDOW_SYSTEM:result:='WIN';
    GL_DEBUG_SOURCE_SHADER_COMPILER:result:='SHDR';
    GL_DEBUG_SOURCE_THIRD_PARTY:result:='3RD';
    GL_DEBUG_SOURCE_APPLICATION:result:='APP';
    GL_DEBUG_SOURCE_OTHER:result:='OTHER';
    else result:='SRC'+IntToHex(v,4);
   end;
  end;
 function DebugTypeName(v:GLenum):string8; inline;
  begin
   case v of
    GL_DEBUG_TYPE_ERROR:result:='ERROR';
    GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:result:='DEPR';
    GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:result:='UNDEF';
    GL_DEBUG_TYPE_PORTABILITY:result:='PORT';
    GL_DEBUG_TYPE_PERFORMANCE:result:='PERF';
    GL_DEBUG_TYPE_OTHER:result:='OTHER';
    {$IFDEF GLDESKTOP}
    GL_DEBUG_TYPE_MARKER:result:='MARK';
    {$ENDIF}
    else result:='TYPE'+IntToHex(v,4);
   end;
  end;
 function DebugSeverityName(v:GLenum):string8; inline;
  begin
   case v of
    GL_DEBUG_SEVERITY_HIGH:result:='HIGH';
    GL_DEBUG_SEVERITY_MEDIUM:result:='MED';
    GL_DEBUG_SEVERITY_LOW:result:='LOW';
    GL_DEBUG_SEVERITY_NOTIFICATION:result:='NOTE';
    else result:='SEV'+IntToHex(v,4);
   end;
  end;
 begin
  // Driver callback for runtime GL diagnostics.
  // We keep source/type/id/severity in raw form so logs are easy to compare
  // against vendor docs and NSight event metadata.
  if message_=nil then exit;
  if severity=GL_DEBUG_SEVERITY_NOTIFICATION then exit;
  if id=131154 then exit; // pixel transfer sync warning (expected during robot API readback)
  // Stage 7: leave message mapping simple and log raw enums for cross-driver diagnostics.
  st:=PAnsiChar(message_);
  srcName:=DebugSourceName(source);
  typeName:=DebugTypeName(typ);
  severityName:=DebugSeverityName(severity);
  // SystemMessage routes to log + debugger console, and can be configured
  // by SystemMessageFlags to escalate into EFatalError (smRaise) for strict runs.
  SystemMessage(Format('[GLDBG][%s][%s][%s] id=%d: %s',[srcName,typeName,severityName,id,st]));
 end;

procedure TRenderDevice.TrackElementBufferBinding(buffer:cardinal);
begin
 EnsureThreadState;
 boundElementArrayBuffer:=buffer;
end;

procedure TRenderDevice.EnsureStreamVB(requiredSize:integer);
 begin
  EnsureThreadState;
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
  EnsureThreadState;
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
  EnsureThreadState;
  ASSERT(vertices<>nil);
  bytes:=vertexCount*vertexLayout.stride;
  EnsureStreamVB(bytes);
  if boundArrayBuffer<>streamVB then begin
   glBindBuffer(GL_ARRAY_BUFFER,streamVB);
   TrackArrayBufferBinding(streamVB);
  end;
  glBufferSubData(GL_ARRAY_BUFFER,0,bytes,vertices);
 end;

procedure TRenderDevice.UploadStreamIndices(indices:pointer;indexCount:integer);
 var
  bytes:integer;
 begin
  EnsureThreadState;
  ASSERT(indices<>nil);
  bytes:=indexCount*2;
  EnsureStreamIB(bytes);
  if boundElementArrayBuffer<>streamIB then begin
   glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,streamIB);
   TrackElementBufferBinding(streamIB);
  end;
  glBufferSubData(GL_ELEMENT_ARRAY_BUFFER,0,bytes,indices);
 end;

procedure TRenderDevice.Draw(primType:TPrimitiveType; primCount: integer; vertices: pointer;
  vertexLayout:TVertexLayout);
 var
  vertexCount:integer;
  useStream:boolean;
 begin
  EnsureThreadState;
  shader.Apply(vertexLayout);
  vertexCount:=PrimitiveVertexCount(primType,primCount);
  useStream:=vertices<>nil;
  if useStream then begin
   UploadStreamVertices(vertices,vertexLayout,vertexCount);
   vertices:=nil; // attributes are offsets in bound stream VBO
  end;
  SetupAttributes(vertices,vertexLayout);
  if window<>nil then begin
   inc(window.stats.drawCalls);
   inc(window.stats.verticesDrawn,vertexCount);
  end;
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
  EnsureThreadState;
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
    if (vertices<>nil) and (boundArrayBuffer<>0) then begin
     glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
     TrackArrayBufferBinding(0);
    end;
    if (indices<>nil) and (boundElementArrayBuffer<>0) then begin
     glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0); // client index pointers require unbound EBO
     TrackElementBufferBinding(0);
    end;
   end;
  end;
  SetupAttributes(vertices,vertexLayout);
  if window<>nil then begin
   inc(window.stats.drawCalls);
   inc(window.stats.verticesDrawn,indexCount);
  end;
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
  EnsureThreadState;
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
   if (vertices<>nil) and (boundArrayBuffer<>0) then begin
    glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
    TrackArrayBufferBinding(0);
   end;
   if (indices<>nil) and (boundElementArrayBuffer<>0) then begin
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0); // client index pointers require unbound EBO
    TrackElementBufferBinding(0);
   end;
  end;
  SetupAttributes(vertices,vertexLayout);
  if window<>nil then begin
   inc(window.stats.drawCalls);
   inc(window.stats.verticesDrawn,vrtCount);
  end;
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
  EnsureThreadState;
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
    if (vertices<>nil) and (boundArrayBuffer<>0) then begin
     glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
     TrackArrayBufferBinding(0);
    end;
    if (indices<>nil) and (boundElementArrayBuffer<>0) then begin
     glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0); // client index pointers require unbound EBO
     TrackElementBufferBinding(0);
    end;
   end;
  end;
  SetupAttributes(vertices,vertexLayout);
  if window<>nil then begin
   inc(window.stats.drawCalls);
   inc(window.stats.verticesDrawn,indexCount*instances);
  end;
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
  EnsureThreadState;
  shader.Apply(vertexLayout);
  vertexCount:=PrimitiveVertexCount(primType,primCount);
  useStream:=vertices<>nil;
  if useStream then begin
   UploadStreamVertices(vertices,vertexLayout,vertexCount);
   vertices:=nil;
  end else
  if (vertices<>nil) and (not IsCoreProfile) and (boundArrayBuffer<>0) then begin
   glBindBuffer(GL_ARRAY_BUFFER,0); // client memory pointers require unbound VBO in compatibility mode
   TrackArrayBufferBinding(0);
  end;
  SetupAttributes(vertices,vertexLayout);
  if window<>nil then begin
   inc(window.stats.drawCalls);
   inc(window.stats.verticesDrawn,vertexCount*instances);
  end;
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
  EnsureThreadState;
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
      0:glVertexAttribPointer(n,dim,GL_FLOAT,GLboolean(GL_FALSE),stride,p); // position
      1,5:glVertexAttribPointer(n,3,GL_FLOAT,GLboolean(GL_FALSE),stride,p); // normal
      2:glVertexAttribPointer(n,4,GL_UNSIGNED_BYTE,GLboolean(GL_TRUE),stride,p); // color
      3,4:glVertexAttribPointer(n,2,GL_FLOAT,GLboolean(GL_FALSE),stride,p); // uv1
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
 EnsureThreadState;
 if IsCoreProfile then begin
  // In core profile attribute pointers are interpreted as offsets in a bound ARRAY_BUFFER.
  // We track this binding locally via TrackArrayBufferBinding/stream uploads.
  // VAO must already be created and bound for the current context during context init.
  ASSERT(boundArrayBuffer<>0,'Core profile requires GL_ARRAY_BUFFER during attribute setup');
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

// Map a TGpuLayout vertex format to GL attribute parameters.
// isInt selects glVertexAttribIPointer (integer attributes fed to int/uint shader inputs).
procedure MeshFormatToGL(format:TVertexFormat;out comps:integer;out glType:cardinal;
   out normalized:GLboolean;out isInt:boolean);
 begin
  normalized:=GLboolean(GL_FALSE);
  isInt:=false;
  comps:=VertexFormatComponents(format);
  case format of
   TVertexFormat.Float1,TVertexFormat.Float2,
   TVertexFormat.Float3,TVertexFormat.Float4: glType:=GL_FLOAT;
   TVertexFormat.UByte4Norm:begin glType:=GL_UNSIGNED_BYTE; normalized:=GLboolean(GL_TRUE); end;
   TVertexFormat.UByte4:    begin glType:=GL_UNSIGNED_BYTE; isInt:=true; end;
   TVertexFormat.UInt16x4:  begin glType:=GL_UNSIGNED_SHORT; isInt:=true; end;
   TVertexFormat.UInt32:    begin glType:=GL_UNSIGNED_INT; isInt:=true; end;
   else begin glType:=GL_FLOAT; end;
  end;
 end;

procedure TRenderDevice.BindMeshLayout(layout:TGpuLayout);
 var
  i,loc,comps,stride:integer;
  glType:cardinal;
  normalized:GLboolean;
  isInt:boolean;
  newMask,bit:cardinal;
 begin
  EnsureThreadState;
  if IsCoreProfile then
   ASSERT(boundArrayBuffer<>0,'BindMeshLayout requires a bound GL_ARRAY_BUFFER (the mesh stream VBO)');
  newMask:=0;
  for i:=0 to high(layout.attributes) do with layout.attributes[i] do begin
   loc:=MeshSemanticLocation(semantic,semanticIndex);
   if loc<0 then continue;
   MeshFormatToGL(format,comps,glType,normalized,isInt);
   stride:=layout.StreamStride(stream);
   // Single-stream assumption: every attribute reads from the currently bound
   // ARRAY_BUFFER. Multi-stream (static/dynamic split, instance) needs per-stream
   // binding before its attributes — deferred to C3.
   if isInt then
    glVertexAttribIPointer(loc,comps,glType,stride,pointer(UIntPtr(offset)))
   else
    glVertexAttribPointer(loc,comps,glType,normalized,stride,pointer(UIntPtr(offset)));
   glEnableVertexAttribArray(loc);
   if (loc<=high(divisors)) and (divisors[loc]<>0) then begin
    glVertexAttribDivisor(loc,0); // per-vertex (instance streams wired in C3)
    divisors[loc]:=0;
   end;
   newMask:=newMask or (cardinal(1) shl loc);
  end;
  // disable locations a previous mesh bind left enabled but this one doesn't use
  bit:=meshEnabledMask and not newMask;
  for loc:=0 to 31 do
   if bit and (cardinal(1) shl loc)<>0 then glDisableVertexAttribArray(loc);
  meshEnabledMask:=newMask;
  CheckForGLError(115);
 end;

procedure TRenderDevice.UnbindMeshLayout;
 var
  loc,i:integer;
 begin
  EnsureThreadState;
  for loc:=0 to 31 do
   if meshEnabledMask and (cardinal(1) shl loc)<>0 then glDisableVertexAttribArray(loc);
  meshEnabledMask:=0;
  // Hand attribute state back to the 2D painter path: force a full re-sync on the
  // next SetupAttributes (sparse mesh locations don't match the painter's prefix model).
  lastVertices:=nil;
  lastLayout.stride:=0;
  lastArrayBuffer:=-1;
  actualAttribArrays:=-1;
  for i:=0 to high(divisors) do divisors[i]:=-1;
 end;

procedure TRenderDevice.DrawMesh(layout:TGpuLayout;first,count,indexBytes:integer);
 var
  glType:cardinal;
 begin
  EnsureThreadState;
  BindMeshLayout(layout);
  if window<>nil then begin
   inc(window.stats.drawCalls);
   inc(window.stats.verticesDrawn,count);
  end;
  if indexBytes=0 then
   glDrawArrays(GL_TRIANGLES,first,count)
  else begin
   if indexBytes=2 then glType:=GL_UNSIGNED_SHORT
    else glType:=GL_UNSIGNED_INT;
   glDrawElements(GL_TRIANGLES,count,glType,pointer(UIntPtr(first*indexBytes)));
  end;
  CheckForGLError(116);
  UnbindMeshLayout;
 end;

procedure TRenderDevice.SetVertexDataDivisors(baseDivisor,extraDivisor:integer);
 begin
  EnsureThreadState;
  self.baseDivisor:=baseDivisor;
  self.extraDivisor:=extraDivisor;
 end;

procedure TRenderDevice.UseExtraVertexData(vertices:pointer;vertexLayout:TVertexLayout);
 begin
  EnsureThreadState;
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
  EnsureThreadState;
  ClearBuffers(true,zBuf>=0,stencil>=0,color,zBuf,stencil);
 end;

procedure TGLRenderTargetAPI.ClearDepth(zbuf:single;stencil:integer);
 begin
  EnsureThreadState;
  ClearBuffers(false,zBuf>=0,stencil>=0,0,zBuf,stencil);
 end;

procedure TGLRenderTargetAPI.Clip(x,y,w,h: integer);
 begin
  EnsureThreadState;
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
  if window<>nil then inc(window.stats.clipChanges);
  glScissor(x,y,w,h);
 end;

constructor TGLRenderTargetAPI.Create;
 begin
  inherited;
  EnsureThreadState;
 end;

procedure TGLRenderTargetAPI.EnsureThreadState;
 var
  data:array[0..3] of GLInt;
  fb:GLInt;
 begin
  if threadReady then exit;
  glGetIntegerv(GL_VIEWPORT,@data[0]);
  backBufferWidth:=data[2];
  backBufferHeight:=data[3];
  // Capture the context's default framebuffer. On desktop/Android this is 0,
  // but iOS under SDL renders to a system-owned FBO with a non-zero name, so
  // binding 0 there raises GL_INVALID_FRAMEBUFFER_OPERATION. SDL has its own
  // FBO bound as we enter the first frame, so read it now.
  fb:=0;
  glGetIntegerv(GL_FRAMEBUFFER_BINDING,@fb);
  defaultFramebuffer:=cardinal(fb);
  scissor:=false;
  threadReady:=true;
 end;

procedure TGLRenderTargetAPI.Resized(newWidth, newHeight: integer);
 begin
  EnsureThreadState;
  backbufferWidth:=newWidth;
  backbufferHeight:=newHeight;
 end;

procedure TGLRenderTargetAPI.ApplyMask;
 begin
   EnsureThreadState;
   glColorMask((curmask and 4)>0,
               (curmask and 2)>0,
               (curmask and 1)>0,
               (curmask and 8)>0);
 end;

procedure TGLRenderTargetAPI.Backbuffer;
 begin
  EnsureThreadState;
  inherited;
  {$IFDEF GLES}
  glBindFramebuffer(GL_FRAMEBUFFER,defaultFramebuffer); // core in ES 3.0
  {$ELSE}
  if GL_VERSION_3_0 or GL_ARB_framebuffer_object then
    glBindFramebuffer(GL_FRAMEBUFFER,defaultFramebuffer);
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
  EnsureThreadState;
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

procedure TGLRenderTargetAPI.SetDepthMode(test:TDepthTest;write:TDepthWrite);
 begin
  EnsureThreadState;
  inherited; // resolve keep-current into curDepth
  if curDepth.test=TDepthTest.Disabled then begin
   glDisable(GL_DEPTH_TEST)
  end else begin
   glEnable(GL_DEPTH_TEST);
   case curDepth.test of
    TDepthTest.Pass:glDepthFunc(GL_ALWAYS);
    TDepthTest.Less:glDepthFunc(GL_LESS);
    TDepthTest.LessEqual:glDepthFunc(GL_LEQUAL);
    TDepthTest.Greater:glDepthFunc(GL_GREATER);
    TDepthTest.Never:glDepthFunc(GL_NEVER);
   end;
  end;
  glDepthMask(curDepth.write=TDepthWrite.On); // mask is independent of the test; always reflect tracked state
 end;

procedure TGLRenderTargetAPI.Viewport(oX,oY,VPwidth,VPheight,renderWidth,renderHeight:integer);
 begin
  EnsureThreadState;
  inherited; // adjust viewport here
  if curTarget<>nil then
   glViewport(vPort.Left,vPort.Top,vPort.Width,vPort.Height)
  else
   glViewport(vPort.Left,realHeight-vPort.Top-vPort.Height,vPort.Width,vPort.Height);
 end;

initialization
 {$IFDEF GLES}
 oglContextTemplate.minMajor:=3;
 oglContextTemplate.minMinor:=0;
 oglContextTemplate.profile:=oglpES;
 {$ELSE}
 oglContextTemplate.minMajor:=3;
 oglContextTemplate.minMinor:=3;
 oglContextTemplate.profile:=oglpCore;
 {$ENDIF}
 {$IFDEF DEBUG}
 oglContextTemplate.debugContext:=true;
 {$ELSE}
 oglContextTemplate.debugContext:=false;
 {$ENDIF}
 oglContextTemplate.forwardCompatible:=false;
 oglContextTemplate.preferHighest:=true;
 oglContextTemplate.actualMajor:=0;
 oglContextTemplate.actualMinor:=0;
 oglContextTemplate.requestAccepted:=false;
 Mem.Clear(oglContextInfo,SizeOf(oglContextInfo));
 oglContextInfo.profile:=oglpAny;

end.

