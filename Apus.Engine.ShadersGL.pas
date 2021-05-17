// ShadersAPI implementation for OpenGL
//
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IF Defined(MSWINDOWS) or Defined(LINUX)} {$DEFINE DGL} {$ENDIF}
unit Apus.Engine.ShadersGL;
interface
uses Apus.CrossPlatform, Apus.Geom3d,  Apus.Structs, Apus.Engine.API, Apus.Engine.Graphics;

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
  texMode:integer;
  uMVP:integer;   // MVP matrix (named "MVP")
  uModelMat:integer; // model matrix as-is (named "ModelMatrix")
  uNormalMat:integer; // normalized model matrix (named "NormalMatrix")
  uTex:array[0..2] of integer; // texture samplers (named "tex0".."tex2")
  vSrc,fSrc:String8; // shader source code

  constructor Create(h:TGLShaderHandle);
  destructor Destroy; override;
  procedure SetUniform(name:String8;value:integer); overload; override;
  procedure SetUniform(name:String8;value:single); overload; override;
  procedure SetUniform(name:String8;const value:TVector3s); overload; override;
  procedure SetUniform(name:String8;const value:T3DMatrix); overload; override;
  procedure SetUniform(name:String8;const value:TQuaternionS); overload; override;
 end;

 TGLShadersAPI=class(TInterfacedObject,IShader)
  constructor Create;
  function Build(vSrc,fSrc:String8;extra:string8=''):TShader;
  function Load(filename:String8;extra:String8=''):TShader;

  // Use custom shader
  procedure UseCustom(shader:TShader);
  // Switch back to a built-in shader
  procedure Reset;
  // Default shader settings
  // ----
  // Set texture stage mode (for default shader)
  procedure TexMode(stage:byte;colorMode:TTexBlendingMode=tblModulate2X;alphaMode:TTexBlendingMode=tblModulate;
     filter:TTexFilter=fltUndefined;intFactor:single=0.0);
  // Restore default texturing mode: one stage with Modulate2X mode for color and Modulate mode for alpha
  procedure DefaultTexMode;
  // Upload texture to the Video RAM and make it active for the specified stage
  // (usually you don't need to call this manually unless you're using a custom shader)
  procedure UseTexture(tex:TTexture;stage:integer=0);
  // Update shader matrices
  procedure UpdateMatrices(const model,MVP:T3DMatrix);

  procedure AmbientLight(color:cardinal);
  // Set directional light (set power<=0 to disable)
  procedure DirectLight(direction:TVector3;power:single;color:cardinal);
  // Set point light source (set power<=0 to disable)
  procedure PointLight(position:TPoint3;power:single;color:cardinal);
  // Define material properties
  procedure Material(color:cardinal;shininess:single);

  procedure LightOff;

  procedure Apply(vertexLayout:TVertexLayout=DEFAULT_VERTEX_LAYOUT);

 private
  curTextures:array[0..3] of TTexture;
  curTexChanged:array[0..3] of boolean;

  curTexMode:TTexMode; // encoded shader mode requested by the client code
  actualTexMode:TTexMode; // actual shader mode
  actualVertexLayout:TVertexLayout; // vertex layout for the current shader

  // Ambient light
  ambientLightColor:cardinal;
  ambientLightModified:boolean;

  // current direct light
  directLightDir:TVector3s;
  directLightPower:single;
  directLightColor:cardinal;
  directLightModified:boolean;

  shaderCache:TSimpleHash;
  activeShader:TGLShader; // current OpenGL shader
  isCustom:boolean;
  lighting:boolean;

  mvpMatrix,modelMatrix:T3DMatrixS;

  // Switch to the specified shader and upload matrices (if applicable)
  procedure ActivateShader(shader:TShader);
  // Get/create shader for current render settings
  function GetShaderFor:TGLShader;
  function CreateShaderFor:TGLShader;
  procedure SetShaderMatrices; // upload matrices to the shader uniforms
 end;

var
 shadersAPI:TGLShadersAPI;

implementation
uses
  Apus.MyServis,
  SysUtils,
  Apus.Engine.ResManGL
  {$IFDEF MSWINDOWS},Windows{$ENDIF}
  {$IFDEF DGL},dglOpenGL{$ENDIF};

const
 LIGHT_AMBIENT_ON = 1;
 LIGHT_DIRECT_ON  = 2;
 LIGHT_POINT_ON   = 4;

function VectorFromColor3(color:cardinal):TVector3s;
 var
  c:PARGBColor;
 begin
  c:=@color;
  result.x:=c.r/255;
  result.y:=c.g/255;
  result.z:=c.b/255;
 end;

function VectorFromColor(color:cardinal):TVector4s;
 var
  c:PARGBColor;
 begin
  c:=@color;
  result.x:=c.r/255;
  result.y:=c.g/255;
  result.z:=c.b/255;
  result.w:=c.a/255;
 end;


{ TGLShader }

procedure SetUniformInternal(handle:TGLShaderHandle;shaderName:string8; name:string8;mode:integer;const value); inline;
 var
  loc:GLint;
 begin
  loc:=glGetUniformLocation(handle,PAnsiChar(name));
  if loc<0 then exit;
  if loc<0 then raise EWarning.Create('Uniform "%s" not found in shader %s',[name,shaderName]);
  case mode of
   1:glUniform1i(loc,integer(value));
   2:glUniform1f(loc,single(value));
   20:glUniform3fv(loc,1,@value);
   21:glUniform4fv(loc,1,@value);
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

procedure TGLShader.SetUniform(name: String8; const value: TQuaternionS);
 begin
  SetUniformInternal(handle,self.name,name,21,value);
 end;

procedure TGLShader.SetUniform(name: String8; const value: T3DMatrix);
 var
  m:T3DMatrixS;
 begin
  m:=Matrix4s(value); // convert double to float
  SetUniformInternal(handle,self.name,name,30,m);
 end;

constructor TGLShader.Create(h: TGLShaderHandle);
 begin
  handle:=h;
  // predefined uniforms
  uMVP:=glGetUniformLocation(h,'MVP');
  uModelMat:=glGetUniformLocation(h,'ModelMatrix');
  uNormalMat:=glGetUniformLocation(h,'NormalMatrix');
  uTex[0]:=glGetUniformLocation(h,'tex0');
  uTex[1]:=glGetUniformLocation(h,'tex1');
  uTex[2]:=glGetUniformLocation(h,'tex2');
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

function BuildVertexShader(notes:String8;hasColor,hasNormal,hasUV:boolean):String8;
 var
  ch:AnsiChar;
 begin
  AddLine(result,'#version 330');
  AddLine(result,'// '+notes);
  AddLine(result,'uniform mat4 MVP;');
  AddLine(result,'uniform mat4 ModelMatrix;',hasNormal);
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
  AddLine(result);
  AddLine(result,'void main(void)');
  AddLine(result,' {');
  AddLine(result,'   gl_Position = MVP*vec4(position,1.0);');
  AddLine(result,'   vNormal = mat3(ModelMatrix)*normal;',hasNormal);
  AddLine(result,'   vColor = color;',hasColor);
  AddLine(result,'   vTexCoord = texCoord;',hasUV);
  AddLine(result,'}');
 end;

function BuildFragmentShader(notes:String8;hasColor,hasNormal,hasUV:boolean;texMode:TTexMode):String8;
 var
  i:integer;
  m,colorMode,alphaMode:byte;
 begin
  AddLine(result,'#version 330');
  AddLine(result,'// '+notes);
  AddLine(result,'uniform sampler2D tex0;');
  AddLine(result,'uniform sampler2D tex1;',texMode.stage[1]>0);
  AddLine(result,'uniform sampler2D tex2;',texMode.stage[2]>0);
  AddLine(result,'uniform float uFactor;');
  AddLine(result,'uniform vec3 ambientColor;',HasFlag(texMode.lighting,LIGHT_AMBIENT_ON));
  if HasFlag(texMode.lighting,LIGHT_DIRECT_ON) then begin
   AddLine(result,'uniform vec3 lightDir;');
   AddLine(result,'uniform vec3 lightColor;');
   AddLine(result,'uniform float lightPower;');
  end;
  AddLine(result,'in vec3 vNormal;',hasNormal);
  AddLine(result,'in vec4 vColor;',hasColor);
  AddLine(result,'in vec2 vTexCoord;',hasUV);
  AddLine(result,'out vec4 fragColor;');
  AddLine(result);
  AddLine(result,'void main(void)');
  AddLine(result,'{');
  AddLine(result,'  vec3 c = vec3(vColor.b,vColor.g,vColor.r);',hasColor);
  AddLine(result,'  float a = vColor.a;',hasColor);
  AddLine(result,'  vec3 c = vec3(1.0,1.0,1.0); float a = 1.0;',not hasColor);
  AddLine(result,'  vec4 t;');
  if HasFlag(texMode.lighting,LIGHT_DIRECT_ON) then begin
   AddLine(result,'  vec3 normal = normalize(vNormal);',hasNormal); // use attribute normal if present
   AddLine(result,'  vec3 normal = vec3(0.0,0.0,-1.0);',not hasNormal); // default normal in 2D mode (if no attribute)
   AddLine(result,'  float diff = lightPower*max(dot(normal,lightDir),0.0);');
   AddLine(result,'  vec3 ambientColor = vec3(0,0,0);',not HasFlag(texMode.lighting,LIGHT_AMBIENT_ON));
   AddLine(result,'  c = c*lightColor*diff+ambientColor;');
  end;
  // Blending
  for i:=0 to 2 do begin
   m:=texMode.stage[i];
   if m<>0 then begin
    colorMode:=m and $0F;
    alphaMode:=m shr 4;
    if (colorMode>=3) or (alphaMode>=3) then
     AddLine(result,'  t = texture2D(tex'+intToStr(i)+',vTexCoord);');
    case colorMode of
     3:AddLine(result,'   c = vec3(t.r, t.g, t.b);'); // replace
     4:AddLine(result,'   c = c*vec3(t.r, t.g, t.b);'); // modulate
     5:AddLine(result,'   c = 2.0*c*vec3(t.r, t.g, t.b);');
     6:AddLine(result,'   c = c+vec3(t.r, t.g, t.b);');
     7:AddLine(result,'   c = c-vec3(t.r, t.g, t.b);');
     8:AddLine(result,'   c = mix(c, vec3(t.r, t.g, t.b), uFactor); ');
    end;
    case alphaMode of
     3:AddLine(result,'   a = t.a; '); //
     4:AddLine(result,'   a = a*t.a; '); //
     5:AddLine(result,'   a = 2.0*a*t.a;  '); //
     6:AddLine(result,'   a = a+t.a;  '); //
     7:AddLine(result,'   a = a-t.a;  '); //
     8:AddLine(result,'   a = mix(a, t.a, uFactor);  '); //
    end;
   end;
  end;
  AddLine(result,'  fragColor = vec4(c.r, c.g, c.b, a);');
  AddLine(result,'}');
 end;

function TGLShadersAPI.CreateShaderFor:TGLShader;
 var
  vSrc,fSrc,notes:String8;
  hasNormal,hasColor,hasUV:boolean;
 begin
  hasNormal:=actualVertexLayout and $F0>0;
  hasColor:=actualVertexLayout and $F00>0;
  hasUV:=actualVertexLayout and $F000>0;
  notes:='Std shader for mode '+IntToHex(curTexMode.mode)+' layout='+IntToHex(actualVertexLayout);
  vSrc:=BuildVertexShader(notes,hasColor,hasNormal,hasUV);
  fSrc:=BuildFragmentShader(notes,hasColor,hasNormal,hasUV,curTexMode);
  result:=Build(vSrc,fSrc) as TGLShader;
  result.name:=notes;
  result.texMode:=curTexMode.mode;
 end;

function TGLShadersAPI.GetShaderFor:TGLShader;
 var
  mode:int64;
  v:int64;
 begin
  mode:=curTexMode.mode+actualVertexLayout shl 32;
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
  directLightPower:=power;
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

procedure TGLShadersAPI.Material(color: cardinal; shininess: single);
 begin

 end;

procedure TGLShadersAPI.PointLight(position: TPoint3; power: single;
  color: cardinal);
 begin
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
  ASSERT(filter=fltUndefined,'Texture filter per stage not supported, use per texture filter instead');
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
  fname:string;
 begin
  fname:=ChangeFileExt(filename,'.vsh');
  vSrc:=LoadFileAsString(fName);
  fname:=ChangeFileExt(filename,'.fsh');
  fSrc:=LoadFileAsString(fName);
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
 function GetShaderError(shader:GLuint):string;
  var
   maxlen:integer;
   errorLog:PAnsiChar;
  begin
   glGetShaderiv(shader,GL_INFO_LOG_LENGTH,@maxlen);
   errorLog:=AnsiStrAlloc(maxlen);
   {$IFDEF GLES}
   glGetShaderInfoLog(shader,maxLen,@maxLen,errorLog);
   {$ELSE}
   glGetShaderInfoLog(shader,maxLen,@maxLen,errorLog);
   {$ENDIF}
   glDeleteShader(shader);
   result:=errorLog;
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
   raise EError.Create('VShader compilation failed: '+GetShaderError(vsh));


  // Fragment shader
  fsh:=glCreateShader(GL_FRAGMENT_SHADER);
  str:=PAnsiChar(fSrc);
  len:=length(fSrc);
  glShaderSource(fsh,1,@str,@len);
  glCompileShader(fsh);
  glGetShaderiv(fsh,GL_COMPILE_STATUS,@res);
  if res=0 then
   raise EError.Create('FShader compilation failed: '+GetShaderError(fsh));

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

procedure TGLShadersAPI.UpdateMatrices(const model, MVP: T3DMatrix);
 begin
  modelMatrix:=Matrix4s(model);
  mvpMatrix:=Matrix4s(mvp);
  SetShaderMatrices;
 end;

procedure TGLShadersAPI.UseCustom(shader: TShader);
 begin
  isCustom:=true;
  ActivateShader(shader);
 end;

procedure TGLShadersAPI.Reset;
 begin
  isCustom:=false;
  actualTexMode.mode:=0;
  lighting:=false;
  TexMode(0);
  TexMode(1,tblDisable,tblDisable);
  Apply;
 end;

procedure TGLShadersAPI.SetShaderMatrices;
 begin
  if activeShader=nil then exit;
   with activeShader do begin
   if uMVP>=0 then glUniformMatrix4fv(uMVP,1,GL_FALSE,@mvpMatrix);
   if uModelMat>=0 then glUniformMatrix4fv(uModelMat,1,GL_FALSE,@modelMatrix);
  end;
 end;

procedure TGLShadersAPI.UseTexture(tex: TTexture; stage: integer);
 begin
  if curTextures[stage]=tex then exit;
  curTextures[stage]:=tex;
  curTexChanged[stage]:=true;
 end;

procedure TGLShadersAPI.Apply(vertexLayout:TVertexLayout=DEFAULT_VERTEX_LAYOUT);
 var
  shader:TGLShader;
  i:integer;
  tex:TTexture;
 begin
  if not isCustom then
   if (actualTexMode.mode<>curTexMode.mode) or (actualVertexLayout<>vertexLayout) then begin
    actualVertexLayout:=vertexLayout;
    shader:=GetShaderFor;
    ActivateShader(shader);
    actualTexMode:=curtexMode;
   end;
  // set uniforms (if modified)
  for i:=0 to 2 do
   if curTexChanged[i] then begin
    curTexChanged[i]:=false;
    tex:=curTextures[i];
    while tex.parent<>nil do tex:=tex.parent;
    resourceManagerGL.MakeOnline(tex,i);
    if activeShader.uTex[i]>=0 then glUniform1i(activeShader.uTex[i],i);
   end;
  if directLightModified then begin
   activeShader.SetUniform('lightDir',directLightDir);
   activeShader.SetUniform('lightPower',directLightPower);
   activeShader.SetUniform('lightColor',VectorFromColor3(directLightColor));
   directLightModified:=false;
  end;
  if ambientLightModified then begin
   activeShader.SetUniform('ambientColor',VectorFromColor3(ambientLightColor));
   ambientLightModified:=false;
  end;
 end;

procedure TGLShadersAPI.ActivateShader(shader:TShader);
 begin
  activeShader:=shader as TGLShader;
  glUseProgram(activeShader.handle);
  SetShaderMatrices;
 end;

end.
