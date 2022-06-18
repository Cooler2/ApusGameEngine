// ShadersAPI implementation for OpenGL
//
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IF Defined(MSWINDOWS) or Defined(LINUX)} {$DEFINE DGL} {$ENDIF}
unit Apus.Engine.ShadersGL;
interface
uses Apus.MyServis, Apus.Geom3d,  Apus.Structs, Apus.Engine.API, Apus.Engine.Graphics;

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

 TGLShader=class(TShader)
  handle:TGLShaderHandle;
  texMode:cardinal;
  uMVP:integer;   // MVP matrix (named "MVP")
  uModelMat:integer; // model matrix as-is (named "ModelMatrix")
  uNormalMat:integer; // normalized model matrix (named "NormalMatrix")
  uShadowMapMat:integer; // light space matrix for shadow mapping
  uTex:array[0..15] of integer; // texture samplers (named "tex0".."texN")
  vSrc,fSrc:String8; // shader source code
  isCustom:boolean;
  matrixRevision:integer;
  constructor Create(h:TGLShaderHandle);
  destructor Destroy; override;
  procedure SetUniform(name:String8;value:integer); overload; override;
  procedure SetUniform(name:String8;value:single); overload; override;
  procedure SetUniform(name:String8;const value:TVector2s); overload; override;
  procedure SetUniform(name:String8;const value:TVector3s); overload; override;
  procedure SetUniform(name:String8;const value:T3DMatrix); overload; override;
  procedure SetUniform(name:String8;const value:TQuaternionS); overload; override;
  procedure UpdateMatrices(revision:integer;const shadowMapMatrix:T3DMatrixS); // Get transformation matrices and upload them to uniforms
 end;

 TGLShadersAPI=class(TInterfacedObject,IShader)
  constructor Create;
  function Build(vSrc,fSrc:String8;extra:string8=''):TShader; overload;
  function Load(filename:String8;extra:String8=''):TShader;

  // Use custom shader
  procedure UseCustom(shader:TShader);
  procedure UseCustomized(colorCalc:String8);
  // Switch back to a built-in shader
  procedure Reset;
  // Set uniform value
  procedure SetUniform(name:String8;value:integer); overload;
  procedure SetUniform(name:String8;value:single); overload;
  procedure SetUniform(name:String8;const value:TVector2s); overload;
  procedure SetUniform(name:String8;const value:TVector3s); overload;
  procedure SetUniform(name:String8;const value:TVector4s); overload;
  procedure SetUniform(name:String8;const value:T3DMatrix); overload;
  procedure SetUniform(name:String8;const value:T3DMatrixS); overload;

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
  procedure DirectLight(direction:TVector3;power:single;color:cardinal);
  // Set point light source (set power<=0 to disable)
  procedure PointLight(position:TPoint3;power:single;color:cardinal);
  // Disable lighting
  procedure LightOff;

  // Define material properties
  procedure Material(color:cardinal;shininess:single);

  procedure Shadow(mode:TShadowMapMode;shadowMap:TTexture=nil;depthBias:single=0.002);

  procedure Apply(vertexLayout:TVertexLayout);
 private
  // поддержка 16 текстурных юнитов
  curTextures:array[0..15] of TTexture;
  curTexChanged:array[0..15] of boolean;

  curTexMode:TTexMode; // encoded shader mode requested by the client code
  actualTexMode:TTexMode; // actual shader mode
  actualVertexLayout:cardinal; // vertex layout for the current shader
  customized:StringArray8;

  // Ambient light
  ambientLightColor:cardinal;
  ambientLightModified:boolean;

  // Current direct light
  directLightDir:TVector3s; //< direction * power
  directLightColor:cardinal;
  directLightModified:boolean;

  // Current point light
  pointLightPos:TPoint3s;
  pointLightColor:TVector3s; // light color multiplied by power
  pointLightModified:boolean;

  shaderCache:TSimpleHash;
  activeShader:TGLShader; // current OpenGL shader
  isCustom:boolean;
  lighting:boolean;

  matrixRevision:integer; // increments when transformation changed, so matrices can be uploaded to shaders
  //mvpMatrix,modelMatrix,
  viewProjMatrix:T3DMatrixS; // lightspace matrix used for shadowmap
  shadowMapMatrix:T3DMatrixS; // frustrum->viewport transformation matrix for the main shadow rendering phase

  // Switch to the specified shader and upload matrices (if applicable)
  procedure ActivateShader(shader:TShader);
  // Get/create shader for current render settings
  function GetShaderFor:TGLShader;
  function CreateShaderFor:TGLShader;
 end;

var
 shadersAPI:TGLShadersAPI;

implementation
uses
  SysUtils,
  StrUtils,
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

{ TGLShader }

procedure SetUniformInternal(shader:TGLShader; name:string8;mode:integer;const value); // inline;
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
   2:if @glProgramUniform1f<>nil then
      glProgramUniform1f(shader.handle,loc,single(value))
     else
      glUniform1f(loc,single(value));
   22:glUniform2fv(loc,1,@value);
   23:glUniform3fv(loc,1,@value);
   24:glUniform4fv(loc,1,@value);
   30:glUniformMatrix4fv(loc,1,GL_FALSE,@value);
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

procedure TGLShader.SetUniform(name:String8;const value:TVector2s);
 begin
  SetUniformInternal(self,name,22,value);
 end;

procedure TGLShader.SetUniform(name: String8;const value:TVector3s);
 begin
  SetUniformInternal(self,name,23,value);
 end;

procedure TGLShader.SetUniform(name: String8;const value:TQuaternionS);
 begin
  SetUniformInternal(self,name,24,value);
 end;

procedure TGLShader.UpdateMatrices(revision:integer;const shadowMapMatrix:T3DMatrixS);
 var
  mat:T3DMatrixS;
 begin
  matrixRevision:=revision;
  if uMVP>=0 then begin
   mat:=Matrix4s(transformationAPI.MVP);
   glUniformMatrix4fv(uMVP,1,GL_FALSE,@mat);
  end;
  if uModelMat>=0 then begin
   mat:=Matrix4s(transformationAPI.objMatrix);
   glUniformMatrix4fv(uModelMat,1,GL_FALSE,@mat);
  end;
  if uShadowMapMat>=0 then begin
   glUniformMatrix4fv(uShadowMapMat,1,GL_FALSE,@shadowMapMatrix);
  end;
 end;

procedure TGLShader.SetUniform(name: String8; const value: T3DMatrix);
 var
  m:T3DMatrixS;
 begin
  m:=Matrix4s(value); // convert double to float
  SetUniformInternal(self,name,30,m);
 end;

constructor TGLShader.Create(h: TGLShaderHandle);
 begin
  inherited Create;
  handle:=h;
  isCustom:=true;
  // predefined uniforms
  uMVP:=glGetUniformLocation(h,'MVP');
  uModelMat:=glGetUniformLocation(h,'ModelMatrix');
  uNormalMat:=glGetUniformLocation(h,'NormalMatrix');
  uShadowMapMat:=glGetUniformLocation(h,'ShadowMapMatrix');
  uTex[0]:=glGetUniformLocation(h,'tex0');
  uTex[1]:=glGetUniformLocation(h,'tex1');
  uTex[2]:=glGetUniformLocation(h,'tex2');
  uTex[3]:=glGetUniformLocation(h,'texShadowMap'); // used for shadowmap
 end;

destructor TGLShader.Destroy;
 var
  count:GLint;
  shaders:array[0..3] of GLint;
 begin
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
  depthPass:=HasFlag(lighting,LIGHT_DEPTHPASS);
  if depthPass then begin
   hasNormal:=false; hasColor:=false; hasUV:=false;
  end;
  shadowMap:=HasFlag(lighting,LIGHT_SHADOWMAP);
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
 begin
  customized:=HasFlag(texMode.lighting,LIGHT_CUSTOMIZED);
  lighting:=HasFlag(texMode.lighting,LIGHT_AMBIENT_ON+LIGHT_DIRECT_ON) and not customized;
  shadowMap:=HasFlag(texMode.lighting,LIGHT_SHADOWMAP) and not customized;

  AddLine(result,'#version 330');
  if customized then notes:='[Customized] '+notes;
  AddLine(result,'// '+notes);
  if HasFlag(texMode.lighting,LIGHT_DEPTHPASS) then begin
   AddLine(result,'void main(void) {} ');
   exit;
  end;
  AddLine(result,'uniform sampler2D tex0;');
  AddLine(result,'uniform sampler2D tex1;',texMode.stage[1]>0);
  AddLine(result,'uniform sampler2D tex2;',texMode.stage[2]>0);
  AddLine(result,'uniform sampler2DShadow texShadowMap;',shadowMap);
  AddLine(result,'uniform float uFactor;');
  AddLine(result,'uniform vec3 ambientColor;',HasFlag(texMode.lighting,LIGHT_AMBIENT_ON));
  if HasFlag(texMode.lighting,LIGHT_DIRECT_ON) then begin
   AddLine(result,'uniform vec3 lightDir;');
   AddLine(result,'uniform vec3 lightColor;');
  end;
  AddLine(result,'in vec3 vNormal;',hasNormal);
  AddLine(result,'in vec4 vColor;',hasColor);
  AddLine(result,'in vec2 vTexCoord;',hasUV);
  AddLine(result,'in vec3 vLightPos;',shadowMap);
  AddLine(result,'out vec4 fragColor;');
  AddLine(result);
  AddLine(result,'void main(void)');
  AddLine(result,'{');
  if customized then begin
   AddLine(result,' '+shadersAPI.customized[texMode.lighting and $F]);
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
   AddLine(result,'   vec3 ambientColor = vec3(0,0,0);',not HasFlag(texMode.lighting,LIGHT_AMBIENT_ON));
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
  notes:='Std shader for mode '+FormatHex(curTexMode.mode)+' layout='+FormatHex(actualVertexLayout);
  LogMessage('Building: '+notes);
  vSrc:=BuildVertexShader(notes,hasColor,hasNormal,hasUV,curTexMode.lighting);
  fSrc:=BuildFragmentShader(notes,hasColor,hasNormal,hasUV,curTexMode);
  result:=Build(vSrc,fSrc) as TGLShader;
  result.name:=notes;
  result.texMode:=curTexMode.mode;
  result.isCustom:=false;
 end;

// Get shader for the current TexMode and current vertex layout
function TGLShadersAPI.GetShaderFor:TGLShader;
 var
  mode:int64;
  v:int64;
 begin
  if HasFlag(curTexMode.lighting,LIGHT_DEPTHPASS) then
   actualVertexLayout:=actualVertexLayout and $F; // use only position when rendering to the shadowmap
  mode:=curTexMode.mode+UInt64(actualVertexLayout) shl 32;
  v:=shaderCache.Get(mode);
  if v<>-1 then exit(TGLShader(v));
  result:=CreateShaderFor;
  shaderCache.Put(mode,UIntPtr(result));
 end;

constructor TGLShadersAPI.Create;
 var
  i:integer;
 begin
  _AddRef;
  shadersAPI:=self;
  shader:=self;
  shaderCache.Init(32);
  curTexChanged[0]:=true;
 end;

procedure TGLShadersAPI.DirectLight(direction:TVector3; power:single; color:cardinal);
 begin
  directLightDir:=Vector3s(direction);
  directLightDir.Normalize;
  VectMult(directLightDir,power);
  directLightColor:=color;
  SetFlag(curTexMode.lighting,LIGHT_DIRECT_ON,power>0);
  directLightModified:=true;
 end;

procedure TGLShadersAPI.AmbientLight(color:cardinal);
 begin
  ambientLightColor:=color;
  SetFlag(curTexMode.lighting,LIGHT_AMBIENT_ON,color<>0);
  ambientLightModified:=true;
 end;

procedure TGLShadersAPI.Material(color:cardinal;shininess:single);
 begin

 end;

procedure TGLShadersAPI.PointLight(position:TPoint3;power:single;color:cardinal);
 begin
  SetFlag(curTexMode.lighting,LIGHT_POINT_ON,power>0);
 end;

procedure TGLShadersAPI.LightOff;
 begin
  ClearFlag(curTexMode.lighting,LIGHT_DIRECT_ON+LIGHT_AMBIENT_ON+LIGHT_POINT_ON);
 end;

procedure TGLShadersAPI.DefaultTexMode;
 begin
  TexMode(0,tblModulate2X,tblModulate);
  TexMode(1,tblDisable,tblDisable);
 end;

procedure TGLShadersAPI.TexMode(stage:byte; colorMode,
  alphaMode:TTexBlendingMode; filter:TTexFilter; intFactor:single);
 begin
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
  lines:StringArray8;
  fname:string;
  i,mode:integer;
 begin
  fName:=fileName+'.glsl';
  if not FileExists(fName) then
   fName:=fileName+'.shader';
  if not FileExists(fName) then begin
   // load separate shader files
   fname:=ChangeFileExt(filename,'.vsh');
   vSrc:=LoadFileAsString(fName);
   fname:=ChangeFileExt(filename,'.fsh');
   fSrc:=LoadFileAsString(fName);
  end else begin
   // Load combined shader file
   vSrc:=LoadFileAsString(fName);
   lines:=SplitA(#13#10,vSrc);
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
 end;

function TGLShadersAPI.Build(vSrc,fSrc,extra:string8): TShader;
 var
  vsh,fsh:GLuint;
  str:PAnsiChar;
  i,len,res:integer;
  prog:integer;
  sa:AStringArr;
 function GetShaderError(shader:GLuint;source:string):string;
  var
   i,j,nearLine:integer;
   maxlen:integer;
   errorLog:AnsiString;
   lines:StringArray8;
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
     j:=PosFrom(')',result,i+1);
     if (j>i) and (j<i+4) then begin
      nearLine:=ParseInt(copy(result,i+1,j-i-1));
      break;
     end;
    end;

   if source<>'' then
    result:=result+#13#10'Source code:';

   lines:=SplitA(#13#10,source);
   if nearLine>=high(lines) then nearLine:=high(lines)-25;
   nearLine:=max2(nearLine-15,0);
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
  /// Extra parameters not supported
 { if extra>'' then begin
   sa:=splitA(',',extra);
   for i:=0 to high(sa) do
    glBindAttribLocation(prog,i,PAnsiChar(sa[i])); // Link attribute index i to attribute named sa[i]
  end;}
  glLinkProgram(prog);
  glGetProgramiv(prog,GL_LINK_STATUS,@res);
  if res=0 then raise EError.Create('Shader program not linked!');
  result:=TGLShader.Create(prog);
 end;

procedure TGLShadersAPI.UseCustom(shader: TShader);
 var
  stage:integer;
 begin
  isCustom:=true;
  ActivateShader(shader);
 end;

procedure TGLShadersAPI.UseCustomized(colorCalc:String8);
 var
  idx:integer;
 begin
  idx:=FindString(customized,colorCalc);
  if idx<0 then idx:=AddString(customized,colorCalc);
  ASSERT((idx>=0) and (idx<16));
  curTexMode.lighting:=idx+LIGHT_CUSTOMIZED;
  isCustom:=false;
 end;

procedure TGLShadersAPI.UseTexture(tex:TTexture;uniformName:string8;stage:integer);
 begin
  UseTexture(tex,stage);
  SetUniform(uniformName,stage);
  //curTexChanged[stage]:=false; // prevent further processing
 end;

procedure TGLShadersAPI.Reset;
 begin
  isCustom:=false;
  actualTexMode.mode:=0;
  ClearFlag(curTexMode.lighting,LIGHT_CUSTOMIZED);
  lighting:=false;
  TexMode(0);
  TexMode(1,tblDisable,tblDisable);
  //Apply;
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TVector2s);
 begin
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;value:single);
 begin
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;value:integer);
 begin
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TVector3s);
 begin
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:T3DMatrixS);
 begin
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:T3DMatrix);
 begin
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.SetUniform(name:String8;const value:TVector4s);
 begin
  ASSERT(activeShader<>nil);
  activeShader.SetUniform(name,value);
 end;

procedure TGLShadersAPI.Shadow(mode:TShadowMapMode;shadowMap:TTexture;depthBias:single);
 function CalcShadowMapMatrix:TMatrix4s;
  var
   frustum:T3DMatrixS;
  begin
    ZeroMem(frustum,sizeof(frustum));
    frustum[0,0]:=0.5; frustum[3,0]:=0.5;
    frustum[1,1]:=0.5; frustum[3,1]:=0.5;
    frustum[2,2]:=0.5; frustum[3,2]:=0.5-depthBias;
    frustum[3,3]:=1;
    MultMat(viewProjMatrix,frustum,shadowMapMatrix);
  end;
 begin
  SetFlag(curTexMode.lighting,LIGHT_SHADOWMAP,mode=shadowMainPass);
  SetFlag(curTexMode.lighting,LIGHT_DEPTHPASS,mode=shadowDepthPass);
  UseTexture(shadowMap,3);
  case mode of
   shadowDepthPass:ZeroMem(viewProjMatrix,sizeof(viewProjMatrix)); // Invalidate viewProjMatrix
   shadowMainPass:CalcShadowMapMatrix;
  end;
 end;

procedure TGLShadersAPI.UseTexture(tex: TTexture; stage: integer);
 begin
  if curTextures[stage]=tex then exit;
  curTextures[stage]:=tex;
  curTexChanged[stage]:=true;
 end;

procedure TGLShadersAPI.Apply(vertexLayout:TVertexLayout);
 var
  shader:TGLShader;
  i:integer;
  tex:TTexture;
  mat:T3DMatrix;
 begin
  if not isCustom then
   if (actualTexMode.mode<>curTexMode.mode) or (actualVertexLayout<>vertexLayout.layout) then begin
    actualVertexLayout:=vertexLayout.layout;
    shader:=GetShaderFor;
    ActivateShader(shader);
    actualTexMode:=curtexMode;
    if HasFlag(curTexMode.lighting,LIGHT_DEPTHPASS) and
     IsZeroMem(viewProjMatrix,sizeof(viewProjMatrix)) then begin
      // Save view-projection matrix used during depth rendering phase for later use
      MultMat(transformationAPI.GetViewMatrix,transformationAPI.GetProjMatrix,mat);
      viewProjMatrix:=Matrix4s(mat);
    end;
   end;
  // Set uniforms (if modified)
  // Transformations
  if transformationAPI.Update then
   inc(matrixRevision);
  if activeShader.matrixRevision<>matrixRevision then begin
   activeShader.UpdateMatrices(matrixRevision,shadowMapMatrix);
  end;
  // Textures
  for i:=0 to high(curTexChanged) do
   if curTexChanged[i] then begin
    curTexChanged[i]:=false;
    tex:=curTextures[i];
    if tex<>nil then begin
     while tex.parent<>nil do tex:=tex.parent;
     resourceManagerGL.MakeOnline(tex,i);
     if activeShader.uTex[i]>0 then begin
      glUniform1i(activeShader.uTex[i],i);
      CheckForGLError(421);
     end;
    end;
   end;
  if directLightModified then begin
   activeShader.SetUniform('lightDir',directLightDir);
   activeShader.SetUniform('lightColor',TShader.VectorFromColor3(directLightColor));
   directLightModified:=false;
  end;
  if ambientLightModified then begin
   activeShader.SetUniform('ambientColor',TShader.VectorFromColor3(ambientLightColor));
   ambientLightModified:=false;
  end;
 end;

procedure TGLShadersAPI.ActivateShader(shader:TShader);
 var
  stage:integer;
 begin
  activeShader:=shader as TGLShader;
  glUseProgram(activeShader.handle);
  // mark textures as changed to force update
  for stage:=0 to high(curTextures) do
   if curTextures[stage]<>nil then
    curTexChanged[stage]:=true;
 end;

end.
