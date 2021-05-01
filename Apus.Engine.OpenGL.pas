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
  function target:IRenderTargets;
  function shader:IShaders;
  function clip:IClipping;
  function transform:ITransformation;
  function draw:IDrawer; inline;
  function txt:ITextDrawer;
  // Functions
  procedure PresentFrame;
  procedure CopyFromBackbuffer(srcX,srcY:integer;image:TRawImage);

  procedure BeginPaint(target:TTexture);
  procedure EndPaint;
  procedure SetCullMode(mode:TCullMode);
  procedure Restore;
  procedure DrawDebugOverlay(idx:integer);

  // For internal use
 protected
  glVersion,glRenderer:string;
  glVersionNum:single;
  sysPlatform:ISystemPlatform;
 end;

var
 debugGL:boolean = {$IFDEF MSWINDOWS} false {$ELSE} true {$ENDIF};

implementation
 uses Apus.MyServis, SysUtils,
  Apus.Geom3D,
  Apus.Engine.Graphics,
  Apus.Engine.Draw,
  Apus.Engine.TextDraw,
  Apus.Engine.ResManGL
  {$IFDEF MSWINDOWS},Windows{$ENDIF}
  {$IFDEF DGL},dglOpenGL{$ENDIF};

type
 TRenderDevice=class(TInterfacedObject,IRenderDevice)
  constructor Create;
  destructor Destroy; override;

  procedure Draw(primType,primCount:integer;vertices:pointer;
    vertexLayout:TVertexLayout;stride:integer);

  // Draw indexed  primitives using in-memory buffers
  procedure DrawIndexed(primType:integer;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;stride:integer;
     vrtStart,vrtCount:integer; indStart,primCount:integer);

(*  // Draw primitives using built-in buffer
  procedure DrawBuffer(primType,primCount,vrtStart:integer;
     vertexBuf:TPainterBuffer;stride:integer); overload;

  // Draw indexed primitives using built-in buffer
  procedure DrawBuffer(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); overload;

  function LockBuffer(buf:TPainterBuffer;offset,size:cardinal):pointer;
  procedure UnlockBuffer(buf:TPainterBuffer);   *)
 protected
  curTexMode:int64; // описание режима текстурирования, установленного клиентским кодом
  actualTexMode:int64; // фактически установленный режим текстурирования
  actualShader:byte; // тип текущего шейдера
  actualAttribArrays:shortint; // кол-во включенных аттрибутов (-1 - неизвестно, 2+кол-во текстур)
  procedure SetupAttributes(vertices:pointer;vertexLayout:TVertexLayout;stride:integer);
 end;

 TGLRenderTargetAPI=class(TRendertargetAPI)
  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); override;
  procedure UseAsDefault(rt:TTexture); override;
  procedure SetDefaultRenderArea(oX,oY,VPwidth,VPheight,renderWidth,renderHeight:integer); override;
  procedure UseDepthBuffer(test:TDepthBufferTest;writeEnable:boolean=true); override;
  procedure BlendMode(blend:TBlendingMode); override;
  procedure Mask(rgb:boolean;alpha:boolean); override;
  procedure UnMask; override;
  procedure Apply; override;
 end;

 TGLTransformationAPI=class(TTransformationAPI,ITransformation)
  // Switch to default 2D view (use screen coordinates)
  procedure DefaultView; override;
  procedure Update; override;
 end;

 TGLShaderHandle=integer;

 TGLShader=class(TShader)
  handle:TGLShaderHandle;
  procedure SetUniform(name:String8;value:integer); overload; override;
  procedure SetUniform(name:String8;value:single); overload; override;
  procedure SetUniform(name:String8;const value:TVector3s); overload; override;
  procedure SetUniform(name:String8;const value:T3DMatrix); overload; override;
 end;

 TGLShadersAPI=class(TShadersAPI,IShaders)
  constructor Create;
  procedure UseTexture(tex:TTexture;stage:integer=0); override;
 private
  curTextures:array[0..3] of TTexture;
 end;

 //textureManager:TResource;

procedure CheckForGLError(lab:integer=0); inline;
var
 error:cardinal;
begin
 if debugGL then begin
  error:=glGetError;
  if error<>GL_NO_ERROR then begin
    ForceLogMessage('PGL Error ('+inttostr(lab)+'): '+inttostr(error)+' '+GetCallStack);
  end;
 end;
end;

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
  sysPlatform:=system;
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

  // Create API objects
  renderDevice:=TRenderDevice.Create;
  renderTargetAPI:=TGLRenderTargetAPI.Create;
  transformationAPI:=TGLTransformationAPI.Create;
  clippingAPI:=TClippingAPI.Create;
  shadersAPI:=TGLShadersAPI.Create;

  TGLResourceManager.Create;
  TDrawer.Create;
  TTextDrawer.Create;
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
(*  if (canPaint>0) and (target=curTarget) then
    raise EWarning.Create('BP: target already set');
  PushRenderTarget;
  if target<>curtarget then begin
   if target<>nil then SetTargetToTexture(target)
    else ResetTarget;
  end else begin
   RestoreClipping;
   inc(canPaint);
  end;
  {$IFNDEF GLES}
  glEnable(GL_TEXTURE_2D);
  {$ENDIF}
  glUseProgram(defaultShader);
  glActiveTexture(GL_TEXTURE0);
  glUniform1i(uTex1,0);
  CheckForGLError;  *)
 end;

procedure TOpenGL.EndPaint;
 begin
(*  if canPaint=0 then exit;
  // LogMessage('EP: '+inttohex(integer(curtarget),8));
  PopRenderTarget;
  dec(canPaint); *)
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
  result:=shadersAPI;
 end;
function TOpenGL.clip: IClipping;
 begin
  result:=clippingAPI;
 end;
function TOpenGL.target: IRenderTargets;
 begin
  result:=renderTargetAPI;
 end;
function TOpenGL.resman: IResourceManager;
 begin
  result:=resourceManagerGL;
 end;
function TOpenGL.transform: ITransformation;
 begin
  result:=transformationAPI;
 end;
function TOpenGL.txt: ITextDrawer;
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

{ TRenderDevice }
constructor TRenderDevice.Create;
 begin

 end;

destructor TRenderDevice.Destroy;
 begin

  inherited;
 end;

procedure TRenderDevice.Draw(primType, primCount: integer; vertices: pointer;
  vertexLayout:TVertexLayout; stride: integer);
 var
  vrt:PVertex;
 begin
  SetupAttributes(vertices,vertexLayout,stride);
  case primtype of
   LINE_LIST:glDrawArrays(GL_LINES,0,primCount*2);
   LINE_STRIP:glDrawArrays(GL_LINE_STRIP,0,primCount+1);
   TRG_LIST:glDrawArrays(GL_TRIANGLES,0,primCount*3);
   TRG_FAN:glDrawArrays(GL_TRIANGLE_FAN,0,primCount+2);
   TRG_STRIP:glDrawArrays(GL_TRIANGLE_STRIP,0,primCount+2);
  end;
 end;

procedure TRenderDevice.DrawIndexed(primType:integer;vertices:pointer;indices:pointer;
     vertexLayout:TVertexLayout;stride:integer;
     vrtStart,vrtCount:integer; indStart,primCount:integer);
 begin
  SetupAttributes(vertices,vertexLayout,stride);
  case primtype of
   LINE_LIST:glDrawElements(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,indices);
   LINE_STRIP:glDrawElements(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,indices);
   TRG_LIST:glDrawElements(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,indices);
   TRG_FAN:glDrawElements(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,indices);
   TRG_STRIP:glDrawElements(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,indices);
  end;
 end;

(*
procedure TRenderDevice.DrawBuffer(primType: integer; vertexBuf,
  indBuf: TPainterBuffer; stride, vrtStart, vrtCount, indStart,
  primCount: integer);
 var
  vrt:PVertex;
  ind:Pointer;
 begin
  case vertexBuf of
   vertBuf:vrt:=@partBuf[0];
   textVertBuf:vrt:=@txtBuf[0];
   else raise EWarning.Create('DIP: Wrong vertbuf');
  end;
  case indBuf of
   partIndBuf:ind:=@partind[indStart];
   bandIndBuf:ind:=@bandInd[indStart];
   else raise EWarning.Create('DIP: Wrong indbuf');
  end;
  glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,stride,@vrt.x);
  glVertexAttribPointer(1,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,@vrt.color);
  glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,stride,@vrt.u);

  case primtype of
   LINE_LIST:glDrawElements(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,ind);
   LINE_STRIP:glDrawElements(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,ind);
   TRG_LIST:glDrawElements(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,ind);
   TRG_FAN:glDrawElements(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,ind);
   TRG_STRIP:glDrawElements(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,ind);
  end;
 end;

function TRenderDevice.LockBuffer(buf: TPainterBuffer; offset,
  size: cardinal): pointer;
 begin
  case buf of
   vertBuf:begin result:=@partbuf[offset];end;
   bandIndBuf:begin result:=@bandInd[offset]; end;
   textVertBuf:begin result:=@txtBuf[offset]; end;
   else raise EWarning.Create('Invalid buffer type');
  end;
 end;

procedure TRenderDevice.UnlockBuffer(buf: TPainterBuffer);
 begin
 end;
*)

procedure TRenderDevice.SetupAttributes(vertices:pointer;vertexLayout:TVertexLayout;stride:integer);
 var
  i,v,n:integer;
  p:pointer;
 begin
  for i:=0 to 4 do begin
   v:=(vertexLayout and $F)*4;
   vertexLayout:=vertexLayout shr 4;
   p:=pointer(UIntPtr(vertices)+v);
   if (v=0) and (i>0) then continue;
   case i of
    0:glVertexAttribPointer(n,3,GL_FLOAT,GL_FALSE,stride,p); // position
    1:glVertexAttribPointer(n,3,GL_FLOAT,GL_FALSE,stride,p); // normal
    2:glVertexAttribPointer(n,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,p); // color
    3:glVertexAttribPointer(n,2,GL_FLOAT,GL_FALSE,stride,p); // uv1
    4:glVertexAttribPointer(n,2,GL_FLOAT,GL_FALSE,stride,p); // uv2
   end;
   inc(n);
   if vertexLayout=0 then break;
  end;
  // adjust number of vertex attrib arrays
  if actualAttribArrays<0 then begin
   for i:=0 to 4 do
    if i<n then glEnableVertexAttribArray(i)
     else glDisableVertexAttribArray(i);
   actualAttribArrays:=n;
  end;
  while n>actualAttribArrays do begin
   glEnableVertexAttribArray(actualAttribArrays);
   inc(actualAttribArrays);
  end;
  while n<actualAttribArrays do begin
   dec(actualAttribArrays);
   glDisableVertexAttribArray(actualAttribArrays);
  end;
 end;

{ TGLRenderTargetAPI }

procedure TGLRenderTargetAPI.Apply;
 begin
  if curTarget=nil then begin

  end else begin

  end;
 end;

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
 CheckForGLError(31);
end;

function ColorComponent(color:cardinal;idx:integer):single;
 begin
  result:=((color shr (idx*8)) and $FF)/255;
 end;

procedure TGLRenderTargetAPI.Clear(color:cardinal; zbuf:single;  stencil:integer);
 var
  mask:cardinal;
 begin
  mask:=GL_COLOR_BUFFER_BIT;
  glDisable(GL_SCISSOR_TEST);
  glClearColor(
    ColorComponent(color,2),
    ColorComponent(color,2),
    ColorComponent(color,0),
    ColorComponent(color,3));
  if zBuf>=0 then begin
   mask:=mask+GL_DEPTH_BUFFER_BIT;
   {$IFDEF GLES}
   glClearDepthf(zbuf);
   {$ELSE}
   glClearDepth(zbuf);
   {$ENDIF}
  end;
  if stencil>=0 then begin
   mask:=mask+GL_STENCIL_BUFFER_BIT;
   glClearStencil(stencil);
  end;
  glClear(mask);
  glEnable(GL_SCISSOR_TEST);
 end;

procedure TGLRenderTargetAPI.Mask(rgb, alpha: boolean);
 begin
  inherited;

 end;

procedure TGLRenderTargetAPI.SetDefaultRenderArea(oX, oY, VPwidth, VPheight,
  renderWidth, renderHeight: integer);
 begin
  inherited;

 end;

procedure TGLRenderTargetAPI.UnMask;
 begin
  inherited;

 end;

procedure TGLRenderTargetAPI.UseAsDefault(rt: TTexture);
 begin
  inherited;

 end;

procedure TGLRenderTargetAPI.UseDepthBuffer(test: TDepthBufferTest;
  writeEnable: boolean);
 begin
  inherited;

 end;

(* --==  DEFAULT SHADER TEMPLATE ==--
  Actual shaders are made from this template for each combination of
  1) number of textures (0-1, 2, 3)
  2) texturing mode

 === Vertex shader ===
 #version 330
 uniform mat4 uMVP;
 layout (location=0) in vec3 position;
 layout (location=1) in vec4 color;
 layout (location=2) in vec2 texCoord;
 out vec4 vColor;
 out vec2 vTexCoord;

 void main(void)
 {
   gl_Position = uMVP * vec4(position, 1.0);
   vColor = color;
   vTexCoord = texCoord;
 }

 === Fragment shader ===
 #version 330
 uniform sampler2D tex;
 uniform int colorOp;
 uniform int alphaOp;
 uniform float uFactor;
 in vec4 vColor;
 in vec2 vTexCoord;
 out vec4 fragColor;

 void main(void)
 {
   vec3 c = vec3(vColor.r, vColor.g, vColor.b);
   float a = vColor.a;
   vec4 t = texture2D(tex,vTexCoord);
   switch (colorOp) {
     case 3: // tblReplace
       c = vec3(t.r, t.g, t.b);
       break;
     case 4: // tblModulate
       c = c*vec3(t.r, t.g, t.b);
       break;
     case 5: // tblModulate2X
       c = 2.0*c*vec3(t.r, t.g, t.b);
       break;
     case 6: // tblAdd
       c = c+vec3(t.r, t.g, t.b);
       break;
     case 7: // tblSub
       c = c-vec3(t.r, t.g, t.b);
       break;
     case 8: // tblInterpolate
       c = mix(c, vec3(t.r, t.g, t.b), uFactor);
       break;
   }
   switch (alphaOp) {
     case 3: // tblReplace
       a = t.a;
       break;
     case 4: // tblModulate
       a = a*t.a;
       break;
     case 5: // tblModulate2X
       a = 2.0*a*t.a;
       break;
     case 6: // tblAdd
       a = a+t.a;
       break;
     case 7: // tblSub
       a = a-t.a;
       break;
     case 8: // tblInterpolate
       a = mix(a, t.a, uFactor);
       break;
   }
   fragColor = vec4(c.r, c.g, c.b, a);
 }

 === end ===
*)

(*
// Возвращает шейдер для заданного режима текстурирования (из кэша либо формирует новый)
function TGLPainter2.SetCustomProgram(mode:int64):integer;
var
 vs,fs:AnsiString;
 i,n:integer;
 tm:PTexMode;
begin
 mode:=mode and $FF00FF00FF00FF;
 result:=customShaders.Get(mode);
 if result<0 then begin
  tm:=@mode;
  n:=0;
  for i:=0 to 3 do
   if (tm^[i] and $0f>2) or (tm^[i] and $f0>$20) then n:=i+1;

  // Vertex shader
  vs:=
  'uniform mat4 uMVP;'#13#10+
  'attribute vec3 aPosition;  '#13#10+
  'attribute vec4 aColor;   '#13#10+
  'varying vec4 vColor;     '#13#10;
  for i:=1 to n do vs:=vs+
    'attribute vec2 aTexcoord'+inttostr(i)+';'#13#10+
    'varying vec2 vTexcoord'+inttostr(i)+';'#13#10;
  vs:=vs+
  'void main() '#13#10+
  '{          '#13#10+
  '    vColor = aColor;   '#13#10;
  for i:=1 to n do vs:=vs+
    '    vTexcoord'+inttostr(i)+' = aTexcoord'+inttostr(i)+'; '#13#10;
  vs:=vs+
  '    gl_Position = uMVP * vec4(aPosition, 1.0);  '#13#10+
  '}';

  // Fragment shader
  fs:='varying vec4 vColor;   '#13#10;
  for i:=1 to n do begin fs:=fs+
    'uniform sampler2D tex'+inttostr(i)+'; '#13#10+
    'varying vec2 vTexcoord'+inttostr(i)+'; '#13#10;
   if ((tm[i-1] and $f)=ord(tblInterpolate)) or
      ((tm[i-1] shr 4 and $f)=ord(tblInterpolate)) then
    fs:=fs+'uniform float uFactor'+inttostr(i)+';'#13#10;
  end;
  fs:=fs+
  'void main() '#13#10+
  '{     '#13#10+
  '  vec3 c = vec3(vColor.r,vColor.g,vColor.b); '#13#10+
  '  float a = vColor.a; '#13#10+
  '  vec4 t; '#13#10;
  for i:=1 to n do begin
   fs:=fs+'  t = texture2D(tex'+inttostr(i)+', vTexcoord'+inttostr(i)+'); '#13#10;
   case (tm[i-1] and $f) of
    ord(tblReplace):fs:=fs+'  c = vec3(t.r, t.g, t.b); '#13#10;
    ord(tblModulate):fs:=fs+'  c = c * vec3(t.r, t.g, t.b); '#13#10;
    ord(tblModulate2x):fs:=fs+'  c = 2.0 * c * vec3(t.r, t.g, t.b); '#13#10;
    ord(tblAdd):fs:=fs+'  c = c + vec3(t.r, t.g, t.b); '#13#10;
    ord(tblInterpolate):fs:=fs+'  c = mix(c, vec3(t.r, t.g, t.b), uFactor'+inttostr(i)+'); '#13#10;
   end;
   case ((tm[i-1] shr 4) and $f) of
    ord(tblReplace):fs:=fs+'  a = t.a; '#13#10;
    ord(tblModulate):fs:=fs+'  a = a * t.a; '#13#10;
    ord(tblModulate2X):fs:=fs+'  a = 2.0 * a * t.a; '#13#10;
    ord(tblAdd):fs:=fs+'  a = a + t.a; '#13#10;
    ord(tblInterpolate):fs:=fs+'  a = mix(a, t.a, uFactor'+inttostr(i)+'); '#13#10;
   end;
  end;
  fs:=fs+
  '    gl_FragColor = vec4(c.r, c.g, c.b, a); '#13#10+
  '}';

  result:=BuildShaderProgram(vs,fs);
  if result>0 then begin
   customShaders.Put(mode,result);
   glUseProgram(result);
   // Set uniforms: texture indices
   for i:=1 to n do
    glUniform1i(glGetUniformLocation(result,PAnsiChar(AnsiString('tex'+inttostr(i)))),i-1);
  end else begin
   result:=defaultShader;
   glUseProgram(result);
  end;
 end else
  glUseProgram(result);
end; *)


{ TGLTransformationAPI }

procedure TGLTransformationAPI.DefaultView;
 begin
  inherited;
 end;

procedure TGLTransformationAPI.Update;
 begin
  if modified then begin
   CalcMVP;

   modified:=false;
  end;
 end;

{ TGLShader }

procedure SetUniformInternal(handle:TGLShaderHandle;shaderName:string8; name:string8;mode:integer;const value); inline;
 var
  loc:glint;
 begin
  loc:=glGetUniformLocation(handle,PAnsiChar(name));
  if loc<0 then raise EWarning.Create('Uniform "%s" not found in shader %s',[name,shaderName]);
  case mode of
   1:glUniform1i(loc,integer(value));
   2:glUniform1f(loc,single(value));
   20:glUniform3fv(loc,1,@value);
   30:glUniformMatrix4fv(loc,1,GL_FALSE,@value);
  end;
 end;


procedure TGLShader.SetUniform(name: String8; value: integer);
 begin
  SetUniformInternal(handle,self.name,name,1,value);
 end;

procedure TGLShader.SetUniform(name: String8; value: single);
 begin
  SetUniformInternal(handle,self.name,name,2,value);
 end;


procedure TGLShader.SetUniform(name: String8; const value: TVector3s);
 begin
  SetUniformInternal(handle,self.name,name,20,value);
 end;

procedure TGLShader.SetUniform(name: String8; const value: T3DMatrix);
 begin
  SetUniformInternal(handle,self.name,name,30,value);
 end;

{ TGLShadersAPI }

constructor TGLShadersAPI.Create;
 begin
  inherited Create;
 end;

procedure TGLShadersAPI.UseTexture(tex: TTexture; stage: integer);
 begin
  if tex<>nil then begin
   if tex.parent<>nil then tex:=tex.parent;
   resourceManagerGL.MakeOnline(tex,stage);
  end else begin
   /// TODO: wtf?
   glActiveTexture(GL_TEXTURE0+stage);
   glBindTexture(GL_TEXTURE_2D,0);
  end;
  curTextures[stage]:=tex;
 end;

end.
