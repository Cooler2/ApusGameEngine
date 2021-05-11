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
  texMode:integer;
  handle:TGLShaderHandle;
  uMVP:integer;   // MVP matrix (named "MVP")
  uModelMat:integer; // model matrix as-is (named "ModelMatrix")
  uNormalMat:integer; // normalized model matrix (named "NormalMatrix")
  uTex:array[0..2] of integer;
  vSrc,fSrc:String8;

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

  procedure AmbientLight(color:cardinal); virtual; abstract;
  // Set directional light (set power<=0 to disable)
  procedure DirectLight(direction:TVector3;power:single;color:cardinal); virtual; abstract;
  // Set point light source (set power<=0 to disable)
  procedure PointLight(position:TPoint3;power:single;color:cardinal); virtual; abstract;
  // Define material properties
  procedure Material(color:cardinal;shininess:single); virtual; abstract;

  procedure Apply;

 private
  curTextures:array[0..3] of TTexture;
  curTexChanged:array[0..3] of boolean;

  curTexMode:TTexMode; // encoded shader mode requested by the client code
  actualTexMode:TTexMode; // actual shader mode

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

{ TGLShader }

procedure SetUniformInternal(handle:TGLShaderHandle;shaderName:string8; name:string8;mode:integer;const value); inline;
 var
  loc:GLint;
 begin
  loc:=glGetUniformLocation(handle,PAnsiChar(name));
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

(* --==  DEFAULT SHADER TEMPLATE ==--
  Actual shaders are made from this template for each combination of
  1) number of textures (0-1, 2, 3)
  2) texturing mode

 === Vertex shader ===    *)
 const
  vShader:array[1..14] of string8=(
' #version 330',
' uniform mat4 MVP;',
' layout (location=0) in vec3 position;',
' layout (location=1) in vec4 color;',
' layout (location=2) in vec2 texCoord;',
' out vec4 vColor;',
' out vec2 vTexCoord;',
'',
' void main(void)',
' {',
'   gl_Position = MVP * vec4(position, 1.0);',
'   vColor = color;',
'   vTexCoord = texCoord;',
' }');

// === Fragment shader ===
 fShader:array[1..28] of string8=(
 '#version 330',
 'uniform sampler2D tex0;',
 'uniform sampler2D tex1;',
 'uniform sampler2D tex2;',
 'uniform float uFactor;',
 'in vec4 vColor;',
 'in vec2 vTexCoord;',
 'out vec4 fragColor;',
 '',
 'void main(void)',
 '{',
 '  vec3 c = vec3(vColor.b, vColor.g, vColor.r);',
 '  float a = vColor.a;',
 '  vec4 t;',
 '      c = vec3(t.r, t.g, t.b); // replace',
 '      c = c*vec3(t.r, t.g, t.b); // modulate',
 '      c = 2.0*c*vec3(t.r, t.g, t.b); // modulate2x',
 '      c = c+vec3(t.r, t.g, t.b); // add',
 '      c = c-vec3(t.r, t.g, t.b); // sub',
 '      c = mix(c, vec3(t.r, t.g, t.b), uFactor); // interpolate',
 '      a = t.a; // replace',
 '      a = a*t.a; // modulate',
 '      a = 2.0*a*t.a; // modulate2x',
 '      a = a+t.a; // add',
 '      a = a-t.a; // sub',
 '      a = mix(a, t.a, uFactor); // interpolate',
 '  fragColor = vec4(c.r, c.g, c.b, a);',
 '}');

function TGLShadersAPI.CreateShaderFor:TGLShader;
 var
  vSrc,fSrc:String8;
  i:integer;
  m:byte;
 begin
  for i:=1 to high(vShader) do vSrc:=vSrc+vShader[i]+#13#10;
  fSrc:=fShader[1]+#13#10+'// Std shader for mode '+IntToHex(curTexMode.mode)+#13#10;
  for i:=2 to 14 do fSrc:=fSrc+fShader[i]+#13#10;
  for i:=0 to 2 do begin
   m:=curTexMode.stage[i];
   if m<>0 then begin
    fSrc:=fSrc+'   t = texture2D(tex'+intToStr(i)+',vTexCoord);'#13#10;
    case m and $0F of
     3:fSrc:=fSrc+'   c = vec3(t.r, t.g, t.b);'; // replace
     4:fSrc:=fSrc+'   c = c*vec3(t.r, t.g, t.b);'; //
     5:fSrc:=fSrc+'   c = 2.0*c*vec3(t.r, t.g, t.b);';
     6:fSrc:=fSrc+'   c = c+vec3(t.r, t.g, t.b);';
     7:fSrc:=fSrc+'   c = c-vec3(t.r, t.g, t.b);'; //
     8:fSrc:=fSrc+'   c = mix(c, vec3(t.r, t.g, t.b), uFactor); '; //
    end;
    fSrc:=fSrc+#13#10;
    m:=m shr 4;
    case m of
     3:fSrc:=fSrc+'   a = t.a; '; //
     4:fSrc:=fSrc+'   a = a*t.a; '; //
     5:fSrc:=fSrc+'   a = 2.0*a*t.a;  '; //
     6:fSrc:=fSrc+'   a = a+t.a;  '; //
     7:fSrc:=fSrc+'   a = a-t.a;  '; //
     8:fSrc:=fSrc+'   a = mix(a, t.a, uFactor);  '; //
    end;
    fSrc:=fSrc+#13#10;
   end;
  end;

  for i:=high(fShader)-1 to high(fShader) do fSrc:=fSrc+fShader[i]+#13#10;
  result:=Build(vSrc,fSrc) as TGLShader;
  result.texMode:=curTexMode.mode;
 end;

function TGLShadersAPI.GetShaderFor:TGLShader;
 var
  mode:cardinal;
  v:int64;
 begin
  mode:=curTexMode.mode;
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

procedure TGLShadersAPI.DefaultTexMode;
 begin
  TexMode(0,tblModulate2X,tblModulate);
  TexMode(1,tblDisable,tblDisable);
  Apply;
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
  if res=0 then raise EError.Create('VShader compilation failed: '+GetShaderError(vsh));

  // Fragment shader
  fsh:=glCreateShader(GL_FRAGMENT_SHADER);
  str:=PAnsiChar(fSrc);
  len:=length(fSrc);
  glShaderSource(fsh,1,@str,@len);
  glCompileShader(fsh);
  glGetShaderiv(fsh,GL_COMPILE_STATUS,@res);
  if res=0 then raise EError.Create('FShader compilation failed: '+GetShaderError(fsh));

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

procedure TGLShadersAPI.Apply;
 var
  shader:TGLShader;
  i:integer;
  tex:TTexture;
 begin
  if not isCustom then
   if actualTexMode.mode<>curTexMode.mode then begin
    shader:=GetShaderFor;
    ActivateShader(shader);
    actualTexMode:=curtexMode;
   end;

  for i:=0 to 2 do
   if curTexChanged[i] then begin
    curTexChanged[i]:=false;
    tex:=curTextures[i];
    while tex.parent<>nil do tex:=tex.parent;
    resourceManagerGL.MakeOnline(tex,i);
    if activeShader.uTex[i]>=0 then glUniform1i(activeShader.uTex[i],i);
   end;
 end;

procedure TGLShadersAPI.ActivateShader(shader:TShader);
 begin
  activeShader:=shader as TGLShader;
  glUseProgram(activeShader.handle);
  SetShaderMatrices;
 end;

end.
