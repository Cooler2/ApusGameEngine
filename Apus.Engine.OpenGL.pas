// OpenGL wrapper for the engine
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IF Defined(MSWINDOWS) or Defined(LINUX)} {$DEFINE DGL} {$ENDIF}
unit Apus.Engine.OpenGL;
interface
uses Apus.Crossplatform, Apus.Engine.API, Apus.Images;

type
 TOpenGL=class(TInterfacedObject,IGraphicsSystem,IGraphicsSystemConfig)
  procedure Init(system:ISystemPlatform);
  procedure Done;
  function GetVersion:single;
  function GetName:string;
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
  function shader:IShaders;
  function clip:IClipping;
  function transform:ITransformation;
  function light:ILighting;
  function draw:IDrawer;
  function txt:ITextDrawer;
  // Functions
  procedure PresentFrame(system:ISystemPlatform);
  procedure CopyFromBackbuffer(srcX,srcY:integer;image:TRawImage);

  procedure BeginPaint(target:TTexture);
  procedure EndPaint;
  procedure SetCullMode(mode:TCullMode);
  procedure Restore;
  procedure DrawDebugOverlay(idx:integer);

  // For internal use

 private
  glVersion,glRenderer:string;
  glVersionNum:single;
 end;

implementation
 uses Apus.MyServis,SysUtils,Apus.Engine.Drawing
  {$IFDEF MSWINDOWS},Windows{$ENDIF}
  {$IFDEF DGL},dglOpenGL{$ENDIF};

type
 TTransformationAPI=class(TInterfacedObject,ITransformation)
  // Switch to default 2D view (use screen coordinates)
  procedure DefaultView;

  // Set 3D view with given field of view (in radians) - set perspective projection matrix
  // using screen dimensions for FoV and aspect ratio
  procedure Perspective(fov:single;zMin,zMax:double); overload;

  // Switch to 3D view - set perspective projection (in camera space: camera pos = 0,0,0, Z-forward, X-right, Y-down)
  // zMin, zMax - near and far Z plane
  // xMin,xMax - x coordinate range on the zScreen Z plane
  // yMin,yMax - y coordinate range on the zScreen Z plane
  // Т.е. точки (x,y,zScreen), где xMin <= x <= xMax, yMin <= y <= yMax - покрывают всю область вывода и только её
  procedure Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); overload;
  // Set orthographic projection matrix
  // For example: scale=3 means that 1 unit in the world space is mapped to 3 pixels (in backbuffer)
  procedure Orthographic(scale,zMin,zMax:double);
  // Set view transformation matrix (camera position)
  // View matrix is (R - right, D - down, F - forward, O - origin):
  // Rx Ry Rz
  // Dx Dy Dz
  // Fx Fy Fz
  // Ox Oy Oz
  procedure SetView(view:T3DMatrix);
  // Alternate way to set camera position and orientation
  // (origin - camera center, target - point to look, up - any point ABOVE camera view line, so plane OTU is vertical),
  // turnCW - camera turn angle (along view axis, CW direction)
  procedure SetCamera(origin,target,up:TPoint3;turnCW:double=0);
  // Set Object (model to world) transformation matrix (must be used AFTER setting the view/camera)
  procedure SetObj(mat:T3DMatrix); overload;
  // Set object position/scale/rotate
  procedure SetObj(oX,oY,oZ:single;scale:single=1;yaw:single=0;roll:single=0;pitch:single=0); overload;
  // Get Model-View-Projection matrix (i.e. transformation from model space to screen space)
  function GetMVPMatrix:T3DMatrix;
 end;

var
 drawer:TDrawer;
 //textureManager:TResource;

{ TOpenGL }
procedure TOpenGL.Init(system:ISystemPlatform);
 var
  pName:string;

 {$IFDEF SDL}
 procedure InitOnSDL(system:ISystemPlatform);
  begin
   system.CreateOpenGLContext;
   ReadImplementationProperties;
   ReadExtensions;
  end;
 {$ENDIF}

 {$IFDEF MSWINDOWS}
 procedure InitOnWindows(system:ISystemPlatform);
  var
   DC:HDC;
   RC:HGLRC;
  begin
   DC:=GetDC(system.GetWindowHandle);
   RC:=system.CreateOpenGLContext;
   LogMessage('Activate GL context');
   ActivateRenderingContext(DC,RC); // ����� ���������� �������� �������� ������� OpenGL
  end;
 {$ENDIF}

 begin
  LogMessage('Init OpenGL');
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

  glVersion:=glGetString(GL_VERSION);
  glRenderer:=glGetString(GL_RENDERER);
  ForceLogMessage('OpenGL version: '+glVersion);
  ForceLogMessage('OpenGL vendor: '+PAnsiChar(glGetString(GL_VENDOR)));
  ForceLogMessage('OpenGL renderer: '+glRenderer);
  ForceLogMessage('OpenGL extensions: '+#13#10+StringReplace(PAnsiChar(glGetString(GL_EXTENSIONS)),' ',#13#10,[rfReplaceAll]));

  if not GL_VERSION_2_0 then
   raise Exception.Create('OpenGL 2.0 or higher required!'#13#10'Please update your video drivers.');
  glVersionNum:=GetVersion;

  drawer:=TDrawer.Create;
 end;

function TOpenGL.light: ILighting;
 begin

 end;

procedure TOpenGL.PresentFrame(system: ISystemPlatform);
 begin
  system.OGLSwapBuffers;
 end;

function TOpenGL.QueryMaxRTSize: integer;
 begin
  result:=texman.maxRTTextureSize;
 end;

procedure TOpenGL.Restore;
 begin

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
   exit(true);
  end;
  {$ENDIF}
 end;

procedure TOpenGL.BeginPaint(target: TTexture);
 begin

 end;

procedure TOpenGL.EndPaint;
 begin

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
 begin
  ASSERT(image.pixelFormat in [ipfARGB,ipfXRGB]);
  image.Lock;
  glReadPixels(srcX,srcY,image.Width,image.Height,GL_BGRA,GL_UNSIGNED_BYTE,image.data);
  image.Unlock;
 end;

procedure TOpenGL.Done;
 begin

 end;

function TOpenGL.ShouldUseTextureAsDefaultRT:boolean;
 begin
  result:=GL_VERSION_3_0;
 end;

function TOpenGL.config: IGraphicsSystemConfig;
 begin
  result:=self;
 end;
function TOpenGL.shader: IShaders;
 begin

 end;
function TOpenGL.clip: IClipping;
 begin

 end;
function TOpenGL.target: IRenderTarget;
 begin

 end;
function TOpenGL.resman: IResourceManager;
 begin

 end;
function TOpenGL.transform: ITransformation;
 begin

 end;
function TOpenGL.txt: ITextDrawer;
 begin

 end;
function TOpenGL.draw:IDrawer;
 begin
  result:=drawer;
 end;

procedure TOpenGL.DrawDebugOverlay(idx: integer);
 begin

 end;

function TOpenGL.GetName: string;
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



end.
