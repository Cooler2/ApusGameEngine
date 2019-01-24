// Class for painting routines using OpenGL: programmable-function pipeline (GLES 2.0+)
//
// Copyright (C) 2011-2014 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
{$IFDEF IOS}{$DEFINE GLES} {$DEFINE GLES20} {$ENDIF}
{$IFDEF ANDROID}{$DEFINE GLES} {$DEFINE GLES20} {$ENDIF}
unit PainterGL2;
interface
 uses types,EngineCls,BasicPainter,PainterGL,geom3D;

type

 { TGLPainter2 }

 TGLPainter2=class(TGLPainter)
   constructor Create(textureMan:TTextureMan);
   destructor Destroy; override;

   procedure BeginPaint(target:TTexture); override;

   // Режим работы
   procedure SetMode(blend:TBlendingMode); override;
   procedure SetTexMode(stage:byte;colorMode,alphaMode:TTexBlendingMode;filter:
     TTexFilter=fltUndefined;intFactor:single=0.0); override; // Режим текстурирования
   procedure UseCustomShader; override;
   procedure ResetTexMode; override; 
   procedure Restore; override;

 protected
   defaultShader:integer;
   MVP:T3DMatrix;
   uMVP,uTex1,uTexmode:integer; // uniform locations

   curTexMode:int64; // описание режима текстурирования, установленного клиентским кодом
   actualTexMode:int64; // фактически установленный режим текстурирования
   actualShader:byte; // тип текущего шейдера
   actualAttribArrays:shortint; // кол-во включенных аттрибутов (-1 - неизвестно, 2+кол-во текстур)

   function SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean; override; // возвращает false если примитив полностью отсекается

   procedure DrawPrimitives(primType,primCount:integer;vertices:pointer;stride:integer); override;
   procedure DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer); override;

   procedure DrawPrimitivesFromBuf(primType,primCount,vrtStart:integer;
     vertexBuf:TPainterBuffer;stride:integer); override;

   procedure DrawIndexedPrimitives(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); override;

   procedure DrawIndexedPrimitivesDirectly(primType:integer;vertexBuf:PScrPoint;indBuf:PWord;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); override;

   procedure SetGLMatrix(mType:TMatrixType;mat:PDouble); override;

   function SetCustomProgram(mode:int64):integer;
 end;

implementation
 uses MyServis,SysUtils,structs,
    {$IFDEF GLES}gles20,
    {$ELSE}dglOpenGL,{$ENDIF}
    images,GLImages,geom2D;

{$IFNDEF GLES}
const
 GL_FALSE=false;
 GL_TRUE=true;
{$ENDIF}

const
 AS_DEFAULT = 0;       // Стандартный шейдер
 AS_CUSTOMIZED = 1;    // Специальный шейдер, созданный под выбранные параметры блендинга
 AS_OWN = 2;           // Внешний (клиентский) шейдер

 DEFAULT_TEX_MODE = ord(tblModulate2X)+ord(tblModulate) shl 4; // стандартный режим блендинга 

type
 TTexMode=array[0..3] of word;
 PTexMode=^TTexMode;

var
 customShaders:TSimpleHash;

procedure CheckForGLError; inline;
var
 error:cardinal;
begin
 error:=glGetError;
 if error<>GL_NO_ERROR then
   ForceLogMessage('PGL2 Error: '+inttostr(error)+' '+GetCallStack);
end;


 { TGLPainter2 }

procedure TGLPainter2.SetGLMatrix(mType: TMatrixType; mat: PDouble);
 var
  m:TMatrix4s;
 begin
  MultMat4(objMatrix,viewMatrix,MVP);
  MultMat4(MVP,projMatrix,MVP);
//  glUseProgram(actualShader);
  m:=Matrix4s(MVP);
  if actualShader<>AS_OWN then
   glUniformMatrix4fv(uMVP,1,GL_FALSE,@m);
 end;

procedure TGLPainter2.SetMode(blend: TBlendingMode);
 begin
  inherited;
 end;

procedure TGLPainter2.BeginPaint(target:TTexture);
 begin
  {$IFNDEF GLES}
  glEnable(GL_TEXTURE_2D);
  {$ENDIF}
  glUseProgram(defaultShader);
  glActiveTexture(GL_TEXTURE0);
  glUniform1i(uTex1,0);
  CheckForGLError;
  inherited;
 end;


procedure TGLPainter2.SetTexMode(stage: byte; colorMode, alphaMode: TTexBlendingMode;
  filter: TTexFilter=fltUndefined; intFactor:single=0.0);
 var
  i:integer;
  tm:PTexMode;
  b:byte;
 begin
  ASSERT(stage in [0..3]);
  if filter<>fltUndefined then curFilters[stage]:=filter;
  tm:=@curTexMode;
  if colorMode=tblDisable then begin
   for i:=stage to 3 do tm[i]:=0;
   exit;
  end;
  b:=byte(tm[stage]);
  if colorMode<>tblNone then b:=(b and $F0)+ord(colorMode);
  if alphaMode<>tblNone then b:=(b and $0F)+ord(alphaMode) shl 4;
  tm[stage]:=word(b)+round(intFactor*255) shl 8;
 end;

procedure TGLPainter2.UseCustomShader;
begin
 actualShader:=AS_OWN;
end;

// Возвращает шейдер для заданного режима текстурирования (из кэша либо формирует новый)
function TGLPainter2.SetCustomProgram(mode:int64):integer;
var
 vs,fs:string;
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
end;

function TGLPainter2.SetStates(state: byte; primRect: TRect; tex: TTexture): boolean;
var
 f1,f2:byte;
 r:TRect;
 op:TPoint;
 i,n,prog:integer;
 tm:int64;
 m:TMatrix4s;
begin
 // Check visibility
 f1:=geom2d.IntersectRects(primRect,clipRect,r);
 if f1=0 then begin
  // Primitive is outside the clipping area -> do nothing
  result:=false;
  exit;
 end else
  result:=true;

 // Override color blending mode for alpha only textures
 if (tex<>nil) and (state=STATE_TEXTURED2X) then
  if (tex.PixelFormat in [ipfA8,ipfA4]) then state:=STATE_COLORED2X;

 // Setup shader
 if (actualShader<>AS_OWN) and (curTexMode<>actualTexMode) then begin
  actualTexMode:=curTexMode;
  if curTexMode=DEFAULT_TEX_MODE then begin
   glUseProgram(defaultShader);
   actualShader:=AS_DEFAULT;
  end else begin
   prog:=SetCustomProgram(curTexMode);
   actualShader:=AS_CUSTOMIZED;
   // Interpolation factors and MVP matrix
   m:=Matrix4s(MVP);
   glUniformMatrix4fv(glGetUniformLocation(prog,'uMVP'),1,GL_FALSE,@m);

   tm:=actualTexMode;
   for i:=1 to 4 do begin
    if (tm and $0f=ord(tblInterpolate)) or
       (tm and $f0=ord(tblInterpolate) shl 4) then
     glUniform1f(glGetUniformLocation(prog,PAnsiChar(AnsiString('uFactor'+inttostr(i)))),1-1/255*((tm shr 8) and $FF));
    tm:=tm shr 16;
   end;
  end;
 end;

 // Blending settings
 if curstate<>state then begin // Update 1) number of vertex arrays, 2) texMode for defaultShader
  // number of vertex attrib arrays
  case state of
   STATE_TEXTURED2X,STATE_COLORED2X: n:=3;
   STATE_COLORED: n:=2;
   STATE_MULTITEX: begin
    n:=3;
    if actualTexMode and $FF0000>0 then inc(n);
    if actualTexMode and $FF00000000>0 then inc(n);
    if actualTexMode and $FF000000000000>0 then inc(n);
   end;
  end;
  if n<>actualAttribArrays then begin
   if actualAttribArrays>n then
    while actualAttribArrays>n do begin
     dec(actualAttribArrays);
     glDisableVertexAttribArray(actualAttribArrays);
    end else
    while actualAttribArrays<n do begin
     glEnableVertexAttribArray(actualAttribArrays);
     inc(actualAttribArrays);
    end;
  end;

  // Set blending mode for default shader
  if actualShader=AS_DEFAULT then glUniform1i(uTexmode,state);
  curstate:=state;
 end;

 // Adjust the clipping area if primitive can be partially clipped
 if not EqualRect(clipRect,actualClip) then begin
  f2:=geom2d.IntersectRects(primRect,actualClip,r);
  if (f1<>f2) or (f1>1) then begin
   if curtarget=defaultRenderTarget then begin
    if curtarget=nil then op:=outputPos else op:=Point(0,0);
    glScissor(oP.x+round(clipRect.Left*targetScaleX),
              oP.Y+round((screenRect.Bottom-clipRect.Bottom)*targetScaleY),
              round((clipRect.Right-clipRect.left)*targetScaleX),
              round((clipRect.Bottom-clipRect.Top)*targetScaleY));
   end else
     glScissor(clipRect.Left,
               clipRect.Top,
               clipRect.Right-clipRect.left,
               clipRect.Bottom-clipRect.Top);
   actualClip:=ClipRect;
  end;
 end;
end;

procedure TGLPainter2.DrawPrimitives(primType, primCount: integer;
   vertices: pointer; stride: integer);
 var
  vrt:PScrPoint;
 begin
  vrt:=vertices;
  glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,stride,@vrt.x);
  glVertexAttribPointer(1,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,@vrt.diffuse);
  glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,stride,@vrt.u);

  case primtype of
   LINE_LIST:glDrawArrays(GL_LINES,0,primCount*2);
   LINE_STRIP:glDrawArrays(GL_LINE_STRIP,0,primCount+1);
   TRG_LIST:glDrawArrays(GL_TRIANGLES,0,primCount*3);
   TRG_FAN:glDrawArrays(GL_TRIANGLE_FAN,0,primCount+2);
   TRG_STRIP:glDrawArrays(GL_TRIANGLE_STRIP,0,primCount+2);
  end;
 end;

procedure TGLPainter2.DrawPrimitivesMulti(primType, primCount: integer;
   vertices: pointer; stride: integer; stages: integer);
var
 vrt:PScrPoint3;
 i:integer;
begin
 vrt:=vertices;
 glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,stride,@vrt.x);
 glVertexAttribPointer(1,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,@vrt.diffuse);
 glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,stride,@vrt.u);
 if actualAttribArrays>3 then
  glVertexAttribPointer(3,2,GL_FLOAT,GL_FALSE,stride,@vrt.u2);
 if actualAttribArrays>4 then
  glVertexAttribPointer(4,2,GL_FLOAT,GL_FALSE,stride,@vrt.u3);

 case primtype of
  LINE_LIST:glDrawArrays(GL_LINES,0,primCount*2);
  LINE_STRIP:glDrawArrays(GL_LINE_STRIP,0,primCount+1);
  TRG_LIST:glDrawArrays(GL_TRIANGLES,0,primCount*3);
  TRG_FAN:glDrawArrays(GL_TRIANGLE_FAN,0,primCount+2);
  TRG_STRIP:glDrawArrays(GL_TRIANGLE_STRIP,0,primCount+2);
 end;
end;

procedure TGLPainter2.ResetTexMode;
begin
 actualShader:=AS_DEFAULT;
 glUseProgram(defaultShader);
 glEnableVertexAttribArray(0);
 glEnableVertexAttribArray(1);
 glEnableVertexAttribArray(2);
 glDisableVertexAttribArray(3);
 SetTexMode(0,tblModulate2X,tblModulate);
 SetTexMode(1,tblDisable,tblDisable);
 curState:=0;
end;

procedure TGLPainter2.Restore;
begin
 inherited;
 ResetTexMode;
end;

procedure TGLPainter2.DrawPrimitivesFromBuf(primType, primCount,
   vrtStart: integer; vertexBuf: TPainterBuffer; stride: integer);
 begin

 end;

procedure TGLPainter2.DrawIndexedPrimitives(primType: integer; vertexBuf,
   indBuf: TPainterBuffer; stride: integer; vrtStart, vrtCount: integer;
   indStart, primCount: integer);
var
 vrt:PScrPoint;
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
 glVertexAttribPointer(1,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,@vrt.diffuse);
 glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,stride,@vrt.u);

 case primtype of
  LINE_LIST:glDrawElements(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,ind);
  LINE_STRIP:glDrawElements(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,ind);
  TRG_LIST:glDrawElements(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,ind);
  TRG_FAN:glDrawElements(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,ind);
  TRG_STRIP:glDrawElements(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,ind);
 end;
end;

procedure TGLPainter2.DrawIndexedPrimitivesDirectly(primType: integer;
   vertexBuf: PScrPoint; indBuf: PWord; stride: integer; vrtStart,
   vrtCount: integer; indStart, primCount: integer);
 begin
 glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,stride,@vertexbuf.x);
 glVertexAttribPointer(1,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,@vertexbuf.diffuse);
 glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,stride,@vertexbuf.u);
 case primtype of
  LINE_LIST:glDrawElements(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,indBuf);
  LINE_STRIP:glDrawElements(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,indBuf);
  TRG_LIST:glDrawElements(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,indBuf);
  TRG_FAN:glDrawElements(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,indBuf);
  TRG_STRIP:glDrawElements(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,indBuf);
 end;
 end;
 

const
 mainVertexShader=
  'uniform mat4 uMVP;          '#13#10+
  'attribute vec3 aPosition;   '#13#10+
  'attribute vec4 aColor;      '#13#10+
  'attribute vec2 aTexcoord;   '#13#10+
  'varying vec2 vTexcoord;     '#13#10+
  'varying vec4 vColor;        '#13#10+
  'void main()                 '#13#10+
  '{    '#13#10+
  '    vTexcoord = aTexcoord;  '#13#10+
  '    vColor = aColor;        '#13#10+
  '    gl_Position = uMVP * vec4(aPosition, 1.0);     '#13#10+
  '}';

 mainFragmentShader=
  'precision mediump float;           '+
  'uniform sampler2D tex1;   '#13#10+
  'uniform int texmode;      '#13#10+
  'varying vec2 vTexcoord;   '#13#10+
  'varying vec4 vColor;      '#13#10+
  'void main()           '#13#10+
  '{                      '#13#10+
  '  if (texmode==1) { gl_FragColor = vec4(2.0, 2.0, 2.0, 1.0)*vColor*texture2D(tex1,vTexcoord); } else      '#13#10+
  '  if (texmode==2) { gl_FragColor = vColor; } else      '#13#10+
  '  if (texmode==4) { vec4 value=vColor; value.a=value.a*texture2D(tex1,vTexcoord).a; gl_FragColor = value; };      '#13#10+
//  '    gl_FragColor = vColor;                   '+
  '}';

constructor TGLPainter2.Create(textureMan: TTextureMan);
 begin
  inherited;
  customShaders.Init(20);
  defaultShader:=BuildShaderProgram(mainVertexShader,mainFragmentShader,'aPosition,aColor,aTexcoord');
  if defaultShader>0 then begin
   uMVP:=glGetUniformLocation(defaultShader,'uMVP');
   uTex1:=glGetUniformLocation(defaultShader,'tex1');
   uTexMode:=glGetUniformLocation(defaultShader,'texmode');
  end;
  CheckForGLError;

  actualTexMode:=0;
  SetTexMode(0,tblModulate2X,tblModulate,fltBilinear);
  glUseProgram(defaultShader);
  glEnableVertexAttribArray(0);
  glEnableVertexAttribArray(1);
  glEnableVertexAttribArray(2);
  actualAttribArrays:=3;
  CheckForGLError;
  ForceLogMessage('PainterGL2 created, DSh='+inttostr(defaultShader));
 end;

destructor TGLPainter2.Destroy;
 begin
  glDeleteProgram(defaultShader);
  inherited;
 end;


end.
