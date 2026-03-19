// ShadersAPI implementation for OpenGL
//
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IF Defined(MSWINDOWS) or Defined(LINUX)} {$DEFINE DGL} {$ENDIF}
unit Apus.Engine.ShadersGL;
interface
uses Apus.Core, Apus.Engine.Types, Apus.Engine.API, Apus.Engine.Graphics,
  Apus.Lib,
  Apus.Strings;

type
 TGLShaderHandle=integer;

 TTexMode=packed record
  case integer of
  0:( mode:cardinal;
      data:cardinal;
    );
  1:(
    stage:array[0..2] of byte;
    lighting:byte;
    factor:array[0..3] of byte;
    );
 end;

 // Compiled OpenGL shader program instance.
 // Stores uniform locations and per-program state caches.
 TGLShader=class(TShader)
  handle:TGLShaderHandle;
  texMode:cardinal; // low part of TTexMode
  uMVP:integer;   // MVP matrix (named "MVP")
  uModelMat:integer; // model matrix as-is (named "ModelMatrix")
  uNormalMat:integer; // normalized model matrix (named "NormalMatrix")
  uShadowMapMat:integer; // light space matrix for shadow mapping
  uTexShadowMap:integer; // shadow texture sampler
  uTex:array[0..15] of integer; // texture samplers (named "tex0".."texN")
  uLightDir,uLightColor,uAmbientColor:integer;
  vSrc,fSrc:String8; // shader source code
  isCustom:boolean;
  matrixRevision:integer; // used to determine if matrix uniforms should be updated
  constructor Create(h:TGLShaderHandle);
  destructor Destroy; override;
  procedure SetUniform(name:String8;value:integer); overload; override;
  procedure SetUniform(name:String8;value:single); overload; override;
  procedure SetUniform(name:String8;const value:TVec2); overload; override;
  procedure SetUniform(name:String8;const value:TVec3); overload; override;
  procedure SetUniform(name:String8;const value:TMat4d); overload; override;
  procedure SetUniform(name:String8;const value:TQuat); overload; override;
  procedure SetUniform(uniLoc:integer;const value:TVec3); overload;
  procedure UpdateMatrices(revision:integer;const shadowMapMatrix:TMat4); // Get transformation matrices and upload them to uniforms
 end;

 // Shader subsystem singleton for the engine.
 // Selects/builds programs, tracks active textures/lights, and applies uniforms.
 TGLShadersAPI=class(TInterfacedObject,IShader)
  constructor Create;
  destructor Destroy; override;
  function Build(vSrc,fSrc:String8;extra:string8=''):TShader; overload;
  function Load(filename:String8;extra:String8=''):TShader;

  // Use custom shader
  procedure UseCustom(shader:TShader);
  procedure UseCustomized(colorCalc:String8;numTextures:integer=1);
  // Switch back to a built-in shader
  procedure Reset;
  // Set uniform value
  procedure SetUniform(name:String8;value:integer); overload;
  procedure SetUniform(name:String8;value:single); overload;
  procedure SetUniform(name:String8;const value:TVec2); overload;
  procedure SetUniform(name:String8;const value:TVec3); overload;
  procedure SetUniform(name:String8;const value:TQuat); overload;
  procedure SetUniform(name:String8;const value:TMat4d); overload;
  procedure SetUniform(name:String8;const value:TMat4); overload;

  // Default shader settings
  // ----
  // Set texture stage mode (for default shader)
  procedure TexMode(stage:byte;colorMode:TTexBlendingMode=tblModulate2X;alphaMode:TTexBlendingMode=tblModulate;
     filter:TTexFilter=TTexFilter.fltUndefined;intFactor:single=0.0);
  // Restore default texturing mode: one stage with Modulate2X mode for color and Modulate mode for alpha
  procedure DefaultTexMode;
  // Upload texture to the Video RAM and make it active for the specified stage
  // (usually you don't need to call this manually unless you're using a custom shader)
  procedure UseTexture(tex:TTexture;stage:integer=0); overload;
  procedure UseTexture(tex:TTexture;uniformName:string8;stage:integer=0); overload; // use custom sampler name

  // Set ambient light
  procedure AmbientLight(color:cardinal);
  // Set directional light (set power<=0 to disable)
  procedure DirectLight(direction:TVec3;power:single;color:cardinal);
  // Set point light source (set power<=0 to disable)
  procedure PointLight(position:TVec3d;power:single;color:cardinal);
  // Disable lighting
  procedure LightOff;

  // Define material properties
  procedure Material(color:cardinal;shininess:single);

  procedure Shadow(mode:TShadowMapMode;shadowMap:TTexture=nil;depthBias:single=0.002);

 procedure Apply(vertexLayout:TVertexLayout);
 private
  class threadvar
   curTextures:array[0..15] of TTexture; // up to 16 texture units
   curTexChanged:cardinal; // bitmask of changed textures

   curTexMode:TTexMode; // encoded shader mode requested by the client code
   actualTexMode:TTexMode; // actual shader mode
   actualVertexLayout:cardinal; // vertex layout for the current shader

   // Ambient light
   ambientLightColor:cardinal;
   ambientLightModified:boolean;

   // Current direct light
   directLightDir:TVec3; //< direction * power
   directLightColor:cardinal;
   directLightModified:boolean;

   // Current point light
   pointLightPos:TVec3;
   pointLightColor:TVec3; // light color multiplied by power
   pointLightModified:boolean;

   activeShader:TGLShader; // current OpenGL shader
   isCustom:boolean;

   matrixRevision:integer; // increments when transformation changed, so matrices can be uploaded to shaders
   viewProjMatrix:TMat4; // lightspace matrix used for shadowmap
   shadowMapMatrix:TMat4; // frustrum->viewport transformation matrix for the main shadow rendering phase
   shadowMap:TTexture;

   // Pending uniforms (for customized shader)
   custUniforms:Strings8;
   threadStateReady:boolean;
   shaderCache:TSimpleHash;
   shaderCacheReady:boolean;

  customized:Strings8;

  // Switch to the specified shader and upload matrices (if applicable)
  procedure ActivateShader(shader:TShader);
  // Get/create shader for current render settings
  function GetShaderFor:TGLShader;
  function CreateShaderFor:TGLShader;
  function IsCustomized:boolean;
  procedure EnsureThreadState;
  procedure CustomizedUniform(name:string8;valueType:AnsiChar;const value);
  procedure ApplyCustomizedUniforms;
 end;

var
 shadersAPI:TGLShadersAPI;

implementation
uses
  SysUtils,
  StrUtils,
  Apus.Geom3D,
  Apus.Engine.ResManGL,
  Apus.Engine.OpenGL
  {$IFDEF MSWINDOWS},Windows{$ENDIF}
  {$IFDEF DGL},dglOpenGL{$ENDIF};

const
 // Flags for the lighting mode
 LIGHT_AMBIENT_ON = 1;
 LIGHT_DIRECT_ON  = 2;
 LIGHT_POINT_ON   = 4;
 LIGHT_SPECULAR   = 16; // add specular calculation
 LIGHT_SHADOWMAP  = 32; // use shadowmap for light calculations (use ambient light only for pixels in shadow)
 LIGHT_DEPTHPASS  = 64; // use empty shader for rendering into a depth texture
 LIGHT_CUSTOMIZED = 128; // customized color calculation (low 4 bits contain index of customized shader code)

procedure SetGLProgramLabel(handle:GLuint;const labelText:String8); inline;
 begin
  if (handle<>0) and (@glObjectLabel<>nil) and (labelText<>'') then
   glObjectLabel(GL_PROGRAM,handle,length(labelText),@labelText[1]);
 end;

function ShortProgramLabel(const labelText:String8;handle:GLuint):String8; inline;
 begin
  if labelText<>'' then
   result:=labelText
  else
   result:='sh'+IntToHex(handle and $FFFF,4);
  if length(result)>12 then
   result:=copy(result,1,12);
 end;

procedure UpdateShaderProgramLabel(shader:TGLShader); inline;
 var
  st:String8;
 begin
  if shader=nil then exit;
  st:=ShortProgramLabel(shader.name,shader.handle);
  SetGLProgramLabel(shader.handle,st);
 end;

{ TGLShader }

procedure SetUniformInternal(shader:TGLShader;name:string8;mode:integer;const value); // inline;
 var
  loc:GLint;
 begin
  loc:=glGetUniformLocation(shader.handle,PAnsiChar(name));
  if (loc<0) then exit;
{  if (loc<0) then begin
   if not shader.isCustom then exit;
   raise EWarning.Create('Uniform "%s" not found in shader %s',[name,shader.Name]);
  end;}
  case mode of
   1:glUniform1i(loc,integer(value));
   2:{if @glProgramUniform1f<>nil then
      glProgramUniform1f(shader.handle,loc,single(value))   /// WHAT FOR?
     else}
      glUniform1f(loc,single(value));
   22:glUniform2fv(loc,1,@value);
   23:glUniform3fv(loc,1,@value);
   24:glUniform4fv(loc,1,@value);
   30:glUniformMatrix4fv(loc,1,GL_FALSE,@value);
   31:glUniformMatrix4dv(loc,1,GL_FALSE,@value);
  end;
  CheckForGLError(401);
 end;

procedure TGLShader.SetUniform(name:String8;value:integer);
 begin
  SetUniformInternal(self,name,1,value);
 end;

procedure TGLShader.SetUniform(name:String8;value:single);
 begin
  SetUniformInternal(self,name,2,value);
 end;

procedure TGLShader.SetUniform(name:String8;const value:TVec2);
 begin
  SetUniformInternal(self,name,22,value);
 end;

procedure TGLShader.SetUniform(name:String8;const value:TVec3);
 begin
  SetUniformInternal(self,name,23,value);
 end;

procedure TGLShader.SetUniform(name:String8;const value:TQuat);
 begin
  SetUniformInternal(self,name,24,value);
 end;

procedure TGLShader.SetUniform(uniLoc:integer;const value:TVec3);
 begin
  if uniLoc>=0 then
   glUniform3fv(uniLoc,1,@value);
 end;

procedure TGLShader.UpdateMatrices(revision:integer;const shadowMapMatrix:TMat4);
 var
  mat:TMat4;
 begin
  matrixRevision:=revision;
  if uMVP>=0 then begin
   mat.Init(transformationAPI.MVP);
   glUniformMatrix4fv(uMVP,1,GL_FALSE,@mat);
  end;
  if uModelMat>=0 then begin
   mat.Init(transformationAPI.objMatrix);
   glUniformMatrix4fv(uModelMat,1,GL_FALSE,@mat);
  end;
  if uShadowMapMat>=0 then begin
   glUniformMatrix4fv(uShadowMapMat,1,GL_FALSE,@shadowMapMatrix);
  end;
 end;

procedure TGLShader.SetUniform(name:String8;const value:TMat4d);
 var
  m:TMat4;
 begin
  m.Init(value); // convert double to float
  SetUniformInternal(self,name,30,m);
 end;

constructor TGLShader.Create(h:TGLShaderHandle);
 var
  i:integer;
  st:string8;
 begin
  inherited Create;
  handle:=h;
  isCustom:=true;
  // predefined uniforms
  uMVP:=glGetUniformLocation(h,'MVP');
  uModelMat:=glGetUniformLocation(h,'ModelMatrix');
  uNormalMat:=glGetUniformLocation(h,'NormalMatrix');
  uShadowMapMat:=glGetUniformLocation(h,'ShadowMapMatrix');
  for i:=0 to 7 do begin
   st:='tex'+inttostr(i);
   uTex[i]:=glGetUniformLocation(h,PAnsiChar(st));
  end;
  uTexShadowMap:=glGetUniformLocation(h,'texShadowMap'); // used for shadowmap
  uLightDir:=glGetUniformLocation(h,'lightDir');
  uLightColor:=glGetUniformLocation(h,'lightColor');
  uAmbientColor:=glGetUniformLocation(h,'ambientColor');
 end;

destructor TGLShader.Destroy;
 var
  count:GLint;
  shaders:array[0..3] of GLint;
 begin
  // Requires a valid current GL context.
  // Called from TGLShadersAPI.Destroy during graphics shutdown.
  glGetAttachedShaders(handle,length(shaders),count,@shaders[0]);
  while count>0 do begin
   dec(count);
   glDeleteShader(shaders[count]);
  end;
  glDeleteProgram(handle);
  inherited;
 end;

{ TGLShadersAPI }

procedure AddLine(var st:String8;const line:String8='';condition:boolean=true);
 begin
  if condition then st:=st+line+#13#10;
 end;

function BuildVertexShader(notes:String8;hasColor,hasNormal,hasUV:boolean;lighting:cardinal):String8;
 var
  ch:AnsiChar;
  depthPass,shadowMap:boolean;
 begin
  depthPass:=Bits.HasAll(lighting,LIGHT_DEPTHPASS);
  if depthPass then begin
   hasNormal:=false; hasColor:=false; hasUV:=false;
  end;
  shadowMap:=Bits.HasAll(lighting,LIGHT_SHADOWMAP);
  // Now build shader source
  AddLine(result,'#version 330');
  AddLine(result,'// '+notes);
  AddLine(result,'uniform mat4 MVP;');
  AddLine(result,'uniform mat4 ModelMatrix;',hasNormal or shadowMap);
  AddLine(result,'uniform mat4 ShadowMapMatrix;',shadowMap);
  AddLine(result,'layout (location=0) in vec3 position;');
  ch:='0';
  if hasNormal then begin
   inc(ch);
   AddLine(result,'layout (location='+ch+') in vec3 normal;');
   AddLine(result,'out vec3 vNormal;');
  end;
  if hasColor then begin
   inc(ch);
   AddLine(result,'layout (location='+ch+') in vec4 color;');
   AddLine(result,'out vec4 vColor;');
  end;
  if hasUV then begin
   inc(ch);
   AddLine(result,'layout (location='+ch+') in vec2 texCoord;');
   AddLine(result,'out vec2 vTexCoord;');
  end;
  AddLine(result,'out vec3 vLightPos;',shadowMap);

  AddLine(result);
  AddLine(result,'void main(void)');
  AddLine(result,' {');
  AddLine(result,'   gl_Position = MVP*vec4(position,1.0);');
  AddLine(result,'   vNormal = mat3(ModelMatrix)*normal;',hasNormal);
  AddLine(result,'   vColor = color;',hasColor);
  AddLine(result,'   vTexCoord = texCoord;',hasUV);
  AddLine(result,'   vLightPos = vec3(ShadowMapMatrix * ModelMatrix * vec4(position,1.0));',shadowMap);
  AddLine(result,'}');
 end;

function BuildFragmentShader(notes:String8;hasColor,hasNormal,hasUV:boolean;texMode:TTexMode):String8;
 var
  i:integer;
  m,colorMode,alphaMode:byte;
  shadowMap,lighting,customized:boolean;
  custUniforms,custCode:string8;
 begin
  customized:=Bits.HasAll(texMode.lighting,LIGHT_CUSTOMIZED);
  if customized then begin
   custCode:=shadersAPI.customized[texMode.lighting and $F];
   i:=pos(#0,custCode);
   if i>0 then begin
    custUniforms:=copy(custCode,1,i-1);
    custCode:=copy(custCode,i+1,length(custCode));
   end;
  end;
  lighting:=Bits.HasAll(texMode.lighting,LIGHT_AMBIENT_ON+LIGHT_DIRECT_ON) and not customized;
  shadowMap:=Bits.HasAll(texMode.lighting,LIGHT_SHADOWMAP) and not customized;

  AddLine(result,'#version 330');
  if customized then notes:='[Customized] '+notes;
  AddLine(result,'// '+notes);
  if Bits.HasAll(texMode.lighting,LIGHT_DEPTHPASS) then begin
   AddLine(result,'void main(void) {} ');
   exit;
  end;
  AddLine(result,'uniform sampler2D tex0;');
  if not customized then begin
   AddLine(result,'uniform sampler2D tex1;',texMode.stage[1]>0);
   AddLine(result,'uniform sampler2D tex2;',texMode.stage[2]>0);
  end else
   for i:=1 to texMode.stage[2]-1 do
    AddLine(result,'uniform sampler2D tex'+inttostr(i)+';');
  AddLine(result,'uniform sampler2DShadow texShadowMap;',shadowMap);
  AddLine(result,'uniform float uFactor;');
  AddLine(result,'uniform vec3 ambientColor;',Bits.HasAll(texMode.lighting,LIGHT_AMBIENT_ON));
  if Bits.HasAll(texMode.lighting,LIGHT_DIRECT_ON) then begin
   AddLine(result,'uniform vec3 lightDir;');
   AddLine(result,'uniform vec3 lightColor;');
  end;
  if customized then
   AddLine(result,custUniforms);
  AddLine(result,'in vec3 vNormal;',hasNormal);
  AddLine(result,'in vec4 vColor;',hasColor);
  AddLine(result,'in vec2 vTexCoord;',hasUV);
  AddLine(result,'in vec3 vLightPos;',shadowMap);
  AddLine(result,'out vec4 fragColor;');
  AddLine(result);
  AddLine(result,'void main(void)');
  AddLine(result,'{');
  if customized then begin
   AddLine(result,' '+custCode);
   AddLine(result,'}');
   exit;
  end;
  AddLine(result,'  vec3 c = vColor.bgr;',hasColor);
  AddLine(result,'  float a = vColor.a;',hasColor);
  AddLine(result,'  vec3 c = vec3(1.0,1.0,1.0); float a = 1.0;',not hasColor);
  AddLine(result,'  float shadow = texture(texShadowMap, vLightPos);',shadowMap);
  AddLine(result,'  vec4 t;');
  if lighting then begin
   AddLine(result,'  float diff = 0.0;');
   AddLine(result,'  if (shadow>0) {',shadowMap);
   AddLine(result,'   vec3 normal = normalize(vNormal);',hasNormal); // use attribute normal if present
   AddLine(result,'   vec3 normal = vec3(0.0,0.0,-1.0);',not hasNormal); // default normal in 2D mode (if no attribute)
   AddLine(result,'   diff = '+IfThen(shadowMap,'shadow*','')+'max(dot(normal,lightDir),0.0);');
   AddLine(result,'   vec3 ambientColor = vec3(0,0,0);',not Bits.HasAll(texMode.lighting,LIGHT_AMBIENT_ON));
   AddLine(result,'  }',shadowMap);
  end else begin
   AddLine(result,'  c = c*(0.7+0.3*shadow); ',shadowMap); // 30% shadow if no lighting enabled
  end;
  // Texture blending stages
  if hasUV then
   for i:=0 to 2 do begin
    m:=texMode.stage[i];
    if m<>0 then begin
     colorMode:=m and $0F; // blending function for color component
     alphaMode:=m shr 4; // blending function for alpha component
     if (colorMode>=ord(tblReplace)) or (alphaMode>=ord(tblReplace)) then // texture is used in blending stage
       AddLine(result,'  t = texture(tex'+intToStr(i)+',vTexCoord);');
     case colorMode of
      ord(tblReplace)    : AddLine(result,'   c = vec3(t.r, t.g, t.b);');
      ord(tblModulate)   : AddLine(result,'   c = c*vec3(t.r, t.g, t.b);');
      ord(tblModulate2x) : AddLine(result,'   c = 2.0*c*vec3(t.r, t.g, t.b);');
      ord(tblAdd)        : AddLine(result,'   c = c+vec3(t.r, t.g, t.b);');
      ord(tblSub)        : AddLine(result,'   c = c-vec3(t.r, t.g, t.b);');
      ord(tblInterpolate): AddLine(result,'   c = mix(c, vec3(t.r, t.g, t.b), uFactor); ');
     end;
     case alphaMode of
      ord(tblReplace)    : AddLine(result,'   a = t.a; ');
      ord(tblModulate)   : AddLine(result,'   a = a*t.a; ');
      ord(tblModulate2x) : AddLine(result,'   a = 2.0*a*t.a; ');
      ord(tblAdd)        : AddLine(result,'   a = a+t.a; ');
      ord(tblSub)        : AddLine(result,'   a = a-t.a; ');
      ord(tblInterpolate): AddLine(result,'   a = mix(a, t.a, uFactor); ');
     end;
    end;
   end;
  // Lighting
  AddLine(result,'  c = c*(lightColor*diff+ambientColor);',lighting);
  AddLine(result,'  if (a<0.01) discard;'); // don't dirty depth buffer with transparent pixels
  AddLine(result,'  fragColor = vec4(c.r, c.g, c.b, a);');
//  AddLine(result,'  fragColor = vec4(vLightPos.xyz, vColor.a);',shadowMap); // for debug output
  AddLine(result,'}');
 end;

// Build shader for the current TexMode and current vertex layout
function TGLShadersAPI.CreateShaderFor:TGLShader;
 var
  vSrc,fSrc,notes:String8;
  hasNormal,hasColor,hasUV:boolean;
 begin
  hasNormal:=actualVertexLayout and $F0>0;
  hasColor:=actualVertexLayout and $F00>0;
  hasUV:=actualVertexLayout and $F000>0;
  if Bits.HasAll(curTexMode.lighting,LIGHT_CUSTOMIZED) then notes:='Cust '
   else notes:='Std ';
  notes:=notes+'shader for mode '+Conv.ToHex(curTexMode.mode)+' layout='+Conv.ToHex(actualVertexLayout);
  Log.Msg('Building: '+notes);
  vSrc:=BuildVertexShader(notes,hasColor,hasNormal,hasUV,curTexMode.lighting);
  fSrc:=BuildFragmentShader(notes,hasColor,hasNormal,hasUV,curTexMode);
  result:=Build(vSrc,fSrc) as TGLShader;
  // TNamedObject names are global; include GL handle to avoid cross-thread duplicates.
  result.name:=notes+' h'+Conv.ToHex(result.handle);
  UpdateShaderProgramLabel(result);
  result.texMode:=curTexMode.mode;
  result.isCustom:=false;
  result.vSrc:=vSrc;
  result.fSrc:=fSrc;
 end;

// Get shader for the current TexMode and current vertex layout
function TGLShadersAPI.GetShaderFor:TGLShader;
 var
  mode:int64;
  v:int64;
 begin
  EnsureThreadState;
  if Bits.HasAll(curTexMode.lighting,LIGHT_DEPTHPASS) then
   actualVertexLayout:=actualVertexLayout and $F; // use only position when rendering to the shadowmap
  mode:=curTexMode.mode+UInt64(actualVertexLayout) shl 32;
  v:=shaderCache.Get(mode);
  if v<>-1 then exit(TGLShader(v));
  result:=CreateShaderFor;
  shaderCache.Put(mode,UIntPtr(result));
 end;

function TGLShadersAPI.IsCustomized:boolean;
 begin
  result:=not isCustom and (Bits.HasAll(curTexMode.lighting,LIGHT_CUSTOMIZED));
 end;

procedure TGLShadersAPI.EnsureThreadState;
 begin
  if threadStateReady then exit;
  if not shaderCacheReady then begin
   shaderCache.Init(32);
   shaderCacheReady:=true;
  end;
  curTexChanged:=0;
  Bits.SetBit(curTexChanged,0); // invalidate primary texture binding
  threadStateReady:=true;
 end;

constructor TGLShadersAPI.Create;
 begin
 shadersAPI:=self;
 end;

destructor TGLShadersAPI.Destroy;
 var
  i:integer;
 begin
  // Requires a valid GL context: frees cached shader programs for this thread.
  // Must run before GL context destruction.
  DebugMsg('[LIFECYCLE] Destroy %s',[ClassName]);
  Log.Msg('[LIFECYCLE] Destroy '+ClassName);
  if shaderCacheReady then begin
   for i:=0 to shaderCache.count-1 do
    if shaderCache.values[i]<>-1 then
     TGLShader(UIntPtr(shaderCache.values[i])).Free;
   shaderCache.Clear;
   shaderCacheReady:=false;
  end;
  inherited;
 end;

procedure TGLShadersAPI.DirectLight(direction:TVec3; power:single; color:cardinal);
 begin
  EnsureThreadState;
  directLightDir:=direction;
  directLightDir.Normalize;
  directLightDir.Multiply(power);
  directLightColor:=color;
  Bits.Modify(curTexMode.lighting,LIGHT_DIRECT_ON,power>0);
  directLightModified:=true;
 end;

procedure TGLShadersAPI.AmbientLight(color:cardinal);
 begin
  EnsureThreadState;
  ambientLightColor:=color;
  Bits.Modify(curTexMode.lighting,LIGHT_AMBIENT_ON,color<>0);
  ambientLightModified:=true;
 end;

procedure TGLShadersAPI.Material(color:cardinal;shininess:single);
 begin
  // TODO: implement material properties upload to shader
 end;

procedure TGLShadersAPI.CustomizedUniform(name:string8;valueType:AnsiChar;const value);
 var
  l,size:integer;
 begin
  case valueType of
   'f','i':size:=4;
   '2':size:=8;
   '3':size:=12;
   '4':size:=16;
   'm':size:=sizeof(TMat4);
   'M':size:=sizeof(TMat4d);
   else raise EError.Create('CustomizedUniform: unknown valueType: '+valueType);
  end;
  l:=length(name);
  SetLength(name,l+2+size);
  name[l+1]:=#0;
  name[l+2]:=valueType;
  move(value,name[l+3],size);
  custUniforms.Add(name);
 end;

procedure TGLShadersAPI.ApplyCustomizedUniforms;
 var
  i:integer;
  s:string8;
  p:integer;
  valueType:AnsiChar;
 begin
  ASSERT(activeShader<>nil);
  for i:=0 to high(custUniforms) do begin
   s:=custUniforms[i];
   p:=pos(#0,s);
   ASSERT(p>0);
   valueType:=s[p+1];
   case valueType of
    'i':SetUniformInternal(activeShader,s,1,s[p+2]);
    'f':SetUniformInternal(activeShader,s,2,s[p+2]);
    '2':SetUniformInternal(activeShader,s,22,s[p+2]);
    '3':SetUniformInternal(activeShader,s,23,s[p+2]);
    '4':SetUniformInternal(activeShader,s,24,s[p+2]);
    'm':SetUniformInternal(activeShader,s,30,s[p+2]);
    'M':SetUniformInternal(activeShader,s,31,s[p+2]);
   end;
  end;
 end;

procedure TGLShadersAPI.PointLight(position:TVec3d;power:single;color:cardinal);
 begin
  EnsureThreadState;
  // TODO: store position, power, color and upload to shader — currently only toggles the flag bit
  Bits.Modify(curTexMode.lighting,LIGHT_POINT_ON,power>0);
 end;

procedure TGLShadersAPI.LightOff;
 begin
  EnsureThreadState;
  Bits.Clear(curTexMode.lighting,LIGHT_DIRECT_ON+LIGHT_AMBIENT_ON+LIGHT_POINT_ON);
 end;

procedure TGLShadersAPI.DefaultTexMode;
 begin
  EnsureThreadState;
  TexMode(0,tblModulate2X,tblModulate);
  TexMode(1,tblDisable,tblDisable);
 end;

procedure TGLShadersAPI.TexMode(stage:byte; colorMode,
  alphaMode:TTexBlendingMode; filter:TTexFilter; intFactor:single);
 begin
  EnsureThreadState;
  ASSERT(stage in [0..2]);
  ASSERT(filter=TTexFilter.fltUndefined,'Texture filter per stage not supported, use per texture filter instead');
  if colorMode=tblNone then colorMode:=TTexBlendingMode(curTexMode.stage[stage] and $0F);
  if alphaMode=tblNone then alphaMode:=TTexBlendingMode(curTexMode.stage[stage] shr 4);
  curTexMode.stage[stage]:=ord(colorMode)+ord(alphaMode) shl 4;
  if colorMode=tblDisable then
   while stage<3 do begin
    curTexMode.stage[stage]:=0;
    inc(stage);
   end;
 end;

function TGLShadersAPI.Load(filename,extra:String8):TShader;
 var
  vSrc,fSrc:String8;
  lines:Strings8;
  fname:String8;
  i,mode:integer;
 begin
  fName:=fileName+'.glsl';
  if not FileExists(fName) then
   fName:=fileName+'.shader';
  if not FileExists(fName) then begin
   // load separate shader files
   fname:=ChangeFileExt(filename,'.vsh');
   vSrc:=Files.LoadAsString(fName);
   fname:=ChangeFileExt(filename,'.fsh');
   fSrc:=Files.LoadAsString(fName);
  end else begin
   // Load combined shader file
   vSrc:=Files.LoadAsString(fName);
   lines:=vSrc.SplitLines;
   vSrc:=''; mode:=0;
   for i:=0 to high(lines) do begin
    if pos('[VERTEX]',lines[i])>0 then begin
     mode:=1; continue;
    end;
    if pos('[FRAGMENT]',lines[i])>0 then begin
     mode:=2; continue;
    end;
    if pos('[COMMON]',lines[i])>0 then begin
     mode:=0; continue;
    end;
    if mode in [0,1] then vSrc:=vSrc+lines[i]+#13#10;
    if mode in [0,2] then fSrc:=fSrc+lines[i]+#13#10;
   end;
  end;
  result:=Build(vSrc,fSrc,extra);
  result.name:=filename;
  UpdateShaderProgramLabel(result as TGLShader);
 end;

function TGLShadersAPI.Build(vSrc,fSrc,extra:string8): TShader;
 var
  vsh,fsh:GLuint;
  str:PAnsiChar;
  i,len,res:integer;
  prog:integer;
  sa:Strings8;
 function GetShaderError(shader:GLuint;source:string):string;
  var
   i,j,nearLine:integer;
   maxlen:integer;
   errorLog:AnsiString;
   lines:Strings8;
  begin
   glGetShaderiv(shader,GL_INFO_LOG_LENGTH,@maxlen);
   SetLength(errorLog,maxLen);
   {$IFDEF GLES}
   glGetShaderInfoLog(shader,maxLen,@maxLen,PGLChar(errorLog));
   {$ELSE}
   glGetShaderInfoLog(shader,maxLen,@maxLen,PGLChar(errorLog));
   {$ENDIF}
   glDeleteShader(shader);
   result:=PAnsiChar(errorLog);
   nearLine:=0;
   for i:=1 to length(result)-6 do
    if (result[i]='(') then begin
     j:=result.IndexOf(')',i+1);
     if (j>i) and (j<i+4) then begin
      nearLine:=Conv.ToInt(copy(result,i+1,j-i-1));
      break;
     end;
    end;

   if source<>'' then
    result:=result+#13#10'Source code:';

   lines:=String8(source).SplitLines;
   if nearLine>=high(lines) then nearLine:=high(lines)-25;
   nearLine:=Max(nearLine-15,0);
   for i:=1 to 25 do begin
    if nearLine<=high(lines) then
     result:=result+Format(#13#10'%3d %s',[nearline+1,lines[nearLine]]);
    inc(nearLine);
   end;
  end;
 begin
  if not GL_VERSION_2_0 then exit(nil);

  vsh:=glCreateShader(GL_VERTEX_SHADER);
  str:=PAnsiChar(vSrc);
  len:=length(vSrc);
  glShaderSource(vsh,1,@str,@len);
  glCompileShader(vsh);
  glGetShaderiv(vsh,GL_COMPILE_STATUS,@res);
  if res=0 then
   raise EError.Create('VShader compilation failed: '+GetShaderError(vsh,vSrc));

  // Fragment shader
  fsh:=glCreateShader(GL_FRAGMENT_SHADER);
  str:=PAnsiChar(fSrc);
  len:=length(fSrc);
  glShaderSource(fsh,1,@str,@len);
  glCompileShader(fsh);
  glGetShaderiv(fsh,GL_COMPILE_STATUS,@res);
  if res=0 then
   raise EError.Create('FShader compilation failed: '+GetShaderError(fsh,fSrc));

  // Build program object
  prog:=glCreateProgram;
  glAttachShader(prog,vsh);
  glAttachShader(prog,fsh);
  // TODO: support custom attribute bindings from `extra`, or remove the parameter
  // from the public API if this path stays unsupported.
 { if extra>'' then begin
   sa:=splitA(',',extra);
   for i:=0 to high(sa) do
    glBindAttribLocation(prog,i,PAnsiChar(sa[i])); // Link attribute index i to attribute named sa[i]
  end;}
  glLinkProgram(prog);
  glGetProgramiv(prog,GL_LINK_STATUS,@res);
  if res=0 then raise EError.Create('Shader program not linked!');
  result:=TGLShader.Create(prog);
  UpdateShaderProgramLabel(result as TGLShader);
 end;

procedure TGLShadersAPI.UseCustom(shader:TShader);
 var
  stage:integer;
 begin
  EnsureThreadState;
  isCustom:=true;
  ActivateShader(shader);
 end;

procedure TGLShadersAPI.UseCustomized(colorCalc:String8;numTextures:integer=1);
 var
  idx:integer;
 begin
  EnsureThreadState;
  idx:=customized.IndexOf(colorCalc);
  if idx<0 then begin
   customized.Add(colorCalc);
   idx:=high(customized);
  end;
  ASSERT((idx>=0) and (idx<16));
  curTexMode.lighting:=idx+LIGHT_CUSTOMIZED;
  curTexmode.stage[2]:=numTextures; // for customized shader this is a placeholder for texture samplers number
  isCustom:=false;
  // At this stage it's not possible to activate shader because we don't know vertex format
  // (actually, customized shader is not a single shader - for each vertex format there will be a separate shader)
  // So it's not possible to set any uniforms until shader is constructed
  SetLength(custUniforms,0);
 end;

procedure TGLShadersAPI.UseTexture(tex:TTexture;uniformName:string8;stage:integer);
 begin
  EnsureThreadState;
  UseTexture(tex,stage);
  SetUniform(uniformName,stage);
  //curTexChanged[stage]:=false; // prevent further processing
 end;

procedure TGLShadersAPI.Reset;
 begin
  EnsureThreadState;
  isCustom:=false;
  actualTexMode.mode:=0;
  if Bits.HasAll(curTexMode.lighting,LIGHT_CUSTOMIZED) then
   curTexMode.lighting:=curTexMode.lighting and $70;
  TexMode(0);
  TexMode(1,tblDisable,tblDisable);
  //Apply;
 end;

procedure TGLShadersAPI.SetUniform(name:String8;value:single);
 begin
  if IsCustomized then begin
   CustomizedUniform(name,'f',value); exit;
  end;
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;value:integer);
 begin
  if IsCustomized then begin
   CustomizedUniform(name,'i',value); exit;
  end;
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TVec2);
 begin
  if IsCustomized then begin
   CustomizedUniform(name,'2',value); exit;
  end;
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TVec3);
 begin
  if IsCustomized then begin
   CustomizedUniform(name,'3',value); exit;
  end;
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TMat4);
 begin
  if IsCustomized then begin
   CustomizedUniform(name,'m',value); exit;
  end;
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TMat4d);
 begin
  if IsCustomized then begin
   CustomizedUniform(name,'M',value); exit;
  end;
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TQuat);
 begin
  if IsCustomized then begin
   CustomizedUniform(name,'4',value); exit;
  end;
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.Shadow(mode:TShadowMapMode;shadowMap:TTexture;depthBias:single);
 function CalcShadowMapMatrix:TMat4;
  var
   frustum:TMat4;
  begin
    Mem.Clear(frustum,sizeof(frustum));
    frustum[0,0]:=0.5; frustum[3,0]:=0.5;
    frustum[1,1]:=0.5; frustum[3,1]:=0.5;
    frustum[2,2]:=0.5; frustum[3,2]:=0.5-depthBias;
    frustum[3,3]:=1;
    shadowMapMatrix:=viewProjMatrix*frustum;
  end;
 begin
  EnsureThreadState;
  Bits.Modify(curTexMode.lighting,LIGHT_SHADOWMAP,mode=shadowMainPass);
  Bits.Modify(curTexMode.lighting,LIGHT_DEPTHPASS,mode=shadowDepthPass);
  case mode of
   shadowDisabled:self.shadowMap:=nil;
   shadowDepthPass:Mem.Clear(viewProjMatrix,sizeof(viewProjMatrix)); // Invalidate viewProjMatrix
   shadowMainPass:begin
    CalcShadowMapMatrix;
    self.shadowMap:=shadowMap;
   end;
  end;
 end;

procedure TGLShadersAPI.UseTexture(tex:TTexture;stage:integer);
 begin
  EnsureThreadState;
  if curTextures[stage]=tex then begin
   // This texture already used, but maybe it needs update?
   if (tex<>nil) and tex.HasFlag(tfDirty) then
    resourceManagerGL.MakeOnline(tex,stage);
   exit;
  end;
  curTextures[stage]:=tex;
  Bits.SetBit(curTexChanged,stage);
 end;

procedure TGLShadersAPI.Apply(vertexLayout:TVertexLayout);
 var
  shader:TGLShader;
  i:integer;
  tex:TTexture;
  mat:TMat4d;
  shaderChanged:boolean;
 begin
  EnsureThreadState;
  shaderChanged:=false;
  if not isCustom then
   if (actualTexMode.mode<>curTexMode.mode) or (actualVertexLayout<>vertexLayout.layout) then begin
    actualVertexLayout:=vertexLayout.layout;
    shader:=GetShaderFor;
    if shader<>activeShader then shaderChanged:=true;
    ActivateShader(shader);
    actualTexMode:=curtexMode;
    if Bits.HasAll(curTexMode.lighting,LIGHT_DEPTHPASS) and
     Mem.IsZero(viewProjMatrix,sizeof(viewProjMatrix)) then begin
      // Save view-projection matrix used during depth rendering phase for later use
      mat:=transformationAPI.GetViewMatrix*transformationAPI.GetProjMatrix;
      viewProjMatrix.Init(mat);
    end;
   end;
  // Set uniforms (if modified)
  // Transformations
  if transformationAPI.Update then
   inc(matrixRevision);
  ASSERT(activeShader<>nil,'Apply called before any shader was activated');
  if activeShader.matrixRevision<>matrixRevision then begin
   activeShader.UpdateMatrices(matrixRevision,shadowMapMatrix);
  end;
  if IsCustomized then ApplyCustomizedUniforms;
  // Textures (may have issues if shader changes but texture does not)
  curTexChanged:=curTexChanged and $FFFF;
  for i:=0 to high(curTextures) do begin
   if Bits.Get(curTexChanged,i) then begin
    Bits.Clear(curTexChanged,i);
    tex:=curTextures[i];
    if tex<>nil then begin
     while tex.parent<>nil do tex:=tex.parent;
     resourceManagerGL.MakeOnline(tex,i);
     if activeShader.uTex[i]>=0 then begin
      glUniform1i(activeShader.uTex[i],i);
      CheckForGLError(421);
     end;
    end;
   end;
  end;
  if (activeShader.uTexShadowMap>=0) and (shadowMap<>nil) then begin
   UseTexture(shadowMap,9);
   glUniform1i(activeShader.uTexShadowMap,9);
  end;

  if shaderChanged or directLightModified then begin
   activeShader.SetUniform(activeShader.uLightDir,directLightDir);
   activeShader.SetUniform(activeShader.uLightColor,TShader.VectorFromColor3(directLightColor));
   directLightModified:=false;
  end;
  if shaderChanged or ambientLightModified then begin
   activeShader.SetUniform(activeShader.uAmbientColor,TShader.VectorFromColor3(ambientLightColor));
   ambientLightModified:=false;
  end;
 end;

procedure TGLShadersAPI.ActivateShader(shader:TShader);
 var
  stage:integer;
 begin
  activeShader:=shader as TGLShader;
  glUseProgram(activeShader.handle);
  // Mark textures as changed to force update
  for stage:=0 to high(curTextures) do
   if curTextures[stage]<>nil then
    Bits.SetBit(curTexChanged,stage);
 end;

end.
