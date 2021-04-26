// Class for painting routines using OpenGL: programmable-function pipeline (GLES 2.0+)
//
// Copyright (C) 2011-2014 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IFDEF IOS}{$DEFINE GLES} {$DEFINE GLES20} {$ENDIF}
{$IFDEF ANDROID}{$DEFINE GLES} {$DEFINE GLES20} {$ENDIF}
unit Apus.Engine.PainterGL2;
interface
 uses Types, Apus.Engine.API, Apus.Engine.PainterBase, Apus.Engine.PainterGL;
type

 { TGLPainter2 }

 TGLPainter2=class(TGLPainter)
   constructor Create;
   destructor Destroy; override;

   procedure BeginPaint(target:TTexture); override;

   // Режим работы
   procedure SetMode(blend:TBlendingMode); override;
   procedure SetTexMode(stage:byte;colorMode,alphaMode:TTexBlendingMode;filter:
     TTexFilter=fltUndefined;intFactor:single=0.0); override; // Режим текстурирования
   procedure UseCustomShader; override;
   procedure ResetTexMode; override;
   procedure Restore; override;
   function TestTransformation(source:TPoint3):TPoint3;
   function GetMVPMatrix:T3DMatrix; override;

 protected
   defaultShader:integer;
   MVP:T3DMatrix;
   uMVP,uTex1,uTexmode:integer; // uniform locations

   curTexMode:int64; // описание режима текстурирования, установленного клиентским кодом
   actualTexMode:int64; // фактически установленный режим текстурирования
   actualShader:byte; // тип текущего шейдера
   actualAttribArrays:shortint; // кол-во включенных аттрибутов (-1 - неизвестно, 2+кол-во текстур)

   function SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean; override; // возвращает false если примитив полностью отсекается

   procedure renderDevice.Draw(primType,primCount:integer;vertices:pointer;stride:integer); override;
   procedure DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer); override;

   procedure DrawPrimitivesFromBuf(primType,primCount,vrtStart:integer;
     vertexBuf:TPainterBuffer;stride:integer); override;

   procedure DrawIndexedPrimitives(primType:integer;vertexBuf,indBuf:TPainterBuffer;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); override;

   procedure DrawIndexedPrimitivesDirectly(primType:integer;vertexBuf:PVertex;indBuf:PWord;
     stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); override;

   procedure SetGLMatrix(mType:TMatrixType;mat:PDouble); override;

   function SetCustomProgram(mode:int64):integer;
 end;

implementation
 uses Apus.MyServis, SysUtils, Apus.Structs,
    {$IFDEF GLES}gles20,
    {$ELSE}dglOpenGL,{$ENDIF}
    Apus.Images, Apus.Engine.GLImages, Apus.Geom2D, Apus.Geom3D;

{$IFNDEF GLES}
const
 GL_FALSE=false;
 GL_TRUE=true;
{$ENDIF}

const
 AS_DEFAULT = 0;       // Стандартный шейдер (для основных режимов блендинга)
 AS_CUSTOMIZED = 1;    // Специальный шейдер, созданный под выбранные параметры блендинга
 AS_OWN = 2;           // Внешний (клиентский) шейдер

 DEFAULT_TEX_MODE = ord(tblModulate2X)+ord(tblModulate) shl 4; // стандартный режим блендинга

type
 TTexMode=array[0..3] of word;
 PTexMode=^TTexMode;

var
 customShaders:TSimpleHash;

 { TGLPainter2 }

procedure TGLPainter2.SetGLMatrix(mType: TMatrixType; mat: PDouble);
 var
  tmp:T3DMatrix;
  m:T3DMatrixS;
 begin
  MultMat4(objMatrix,viewMatrix,tmp);
  MultMat4(tmp,projMatrix,MVP);
  m:=Matrix4s(MVP);
  if actualShader<>AS_OWN then
   glUniformMatrix4fv(uMVP,1,GL_FALSE,@m);
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

function TGLPainter2.SetStates(state: byte; primRect: TRect; tex: TTexture): boolean;
var
 op:TPoint;
 i,n,prog:integer;
 tm:int64;
 m:TMatrix4s;
begin
 // Override color blending mode for alpha only textures
 if (tex<>nil) and (state=STATE_TEXTURED2X) then
  if (tex.PixelFormat in [ipfA8,ipfA4]) then state:=STATE_COLORED2X;

 // Setup shader
 if (actualShader<>AS_OWN) and (curTexMode<>actualTexMode) then begin
  actualTexMode:=curTexMode;
  if curTexMode=DEFAULT_TEX_MODE then begin
   glUseProgram(defaultShader);
   m:=Matrix4s(MVP);
   glUniformMatrix4fv(uMVP,1,GL_FALSE,@m);
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

procedure TGLPainter2.DrawIndexedPrimitivesDirectly(primType: integer;
   vertexBuf: PVertex; indBuf: PWord; stride: integer; vrtStart,
   vrtCount: integer; indStart, primCount: integer);
 begin
 glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,stride,@vertexbuf.x);
 glVertexAttribPointer(1,4,GL_UNSIGNED_BYTE,GL_TRUE,stride,@vertexbuf.color);
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
  '#version 130'#13#10+
  'precision mediump float;           '#13#10+
  'uniform sampler2D tex1;   '#13#10+
  'uniform int texmode;      '#13#10+
  'varying vec2 vTexcoord;   '#13#10+
  'varying vec4 vColor;      '#13#10+
  'void main()           '#13#10+
  '{                      '#13#10+
  '  if (texmode==1) { gl_FragColor = vec4(2.0, 2.0, 2.0, 1.0)*vColor*texture2D(tex1,vTexcoord); } else      '#13#10+
  '  if (texmode==2) { gl_FragColor = vColor; } else      '#13#10+
  '  if (texmode==4) { vec4 value=vColor; value.a=value.a*texture2D(tex1,vTexcoord).a; gl_FragColor = value; };      '#13#10+
  '}';

constructor TGLPainter2.Create;
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
