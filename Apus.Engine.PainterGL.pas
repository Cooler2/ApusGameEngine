// Class for painting routines using OpenGL: fixed-function pipeline (1.4+, GLES 1.1)
// For programmable-function pipeline (GLES 2.0+) use PainterGL2!
//
// Copyright (C) 2011-2014 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IFDEF IOS}{$DEFINE GLES} {$DEFINE GLES11} {$ENDIF}
{$IFDEF ANDROID}{$DEFINE GLES} {$DEFINE GLES20} {$ENDIF}
unit Apus.Engine.PainterGL;
interface
 uses Types, Apus.Engine.API;

type
 TMatrixType=(mtModelView,mtProjection);

 TGLPainter=class(TBasicPainter)
  constructor Create;
  destructor Destroy; override;

  // Setup render destination
  procedure SetDefaultRenderArea(oX,oY,VPwidth,VPheight,renderWidth,renderHeight:integer); override;
  procedure SetDefaultRenderTarget(rt:TTexture); override;

  procedure Restore; override;
  procedure RestoreClipping; override; // Установить параметры отсечения по текущему viewport'у

  // Установка RenderTarget'а (потомки класса могут иметь дополнительные методы,характерные для конкретного 3D API, например D3D)
  procedure ResetTarget; override; // Установить target в backbuffer
  procedure SetTargetToTexture(tex:TTexture); override; // Установить target в указанную текстуру

  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); override;
  {$IFNDEF GLES20}
  procedure DrawMultiTex(x1,y1,x2,y2:integer; layers:PMultiTexLayer; color:cardinal); override;

  // Режим работы
  procedure SetTexMode(stage:byte;colorMode,alphaMode:TTexBlendingMode;filter:TTexFilter=fltUndefined;intFactor:single=0.0); override; // Режим текстурирования
  procedure ResetTexMode; override; // возврат к стандартному режиму текстурирования (втч после использования своего шейдера)
  {$ENDIF}
  procedure SetMode(blend:TBlendingMode); override;

  procedure SetMask(rgb:boolean;alpha:boolean); override;
  procedure ResetMask; override; // вернуть маску на ту, которая была до предыдущего SetMask

  procedure UseDepthBuffer(test:TDepthBufferTest;writeEnable:boolean=true); override;

  // Set camera (view) matrix
  procedure Set3DView(view:T3DMatrix); override;
  // Set model matrix
  procedure Set3DTransform(mat:T3DMatrix); override;

  // Setup projection
  procedure SetPerspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); override;
  procedure SetOrthographic(scale,zMin,zMax:double); override;
  procedure SetDefaultView; override;

  procedure UseTexture(tex:TTexture;stage:integer=0); override;

  // Extended shader functionality
  // attribNames='aName1,aName2,...aNameN' - attribute names bound to indices 0..n-1
  function BuildShaderProgram(vSrc,fSrc:AnsiString;attribNames:AnsiString=''):integer;
  // Set predefined shader for color transformation (nil - go back to default shader)
  procedure SetColorTransform(const mat:T3DMatrix);
  procedure ResetColorTransform;

 protected
  curstate:byte; // Текущий режим (0 - не установлен, 1 - StateTextured и т.д.)
  // for texture stage 0:
  curColorMode,curAlphaMode:array[0..3] of TTexBlendingMode;
  curRGBScale:array[0..3] of integer;

  curblend:TBlendingMode;
  curFilters:array[0..3] of TTexFilter;
  curTextures:array[0..3] of TTexture;
  curmask:integer;
  oldmask:array[0..15] of integer;
  oldmaskpos:byte;

  actualClip:TRect; // реальные границы отсечения на данный момент (в рабочем пространстве)

  partBuf,txtBuf:array of TVertex;
  partInd,bandInd:array of word;

  // Text effect
  txttex:TTexture;

  chardrawer:integer;

  outputPos:TPoint; // output area in the default render target (bottom-left corner, relative to bottom-left RT corner)
  VPwidth,VPheight:integer; // viewport size for backbuffer
  targetScaleX,targetScaleY:single; // VPwidth/renderWidth

  defaultRenderTarget:TTexture; // Texture to render into
  defaultFramebuffer:cardinal;  // Default render target for OpenGL ES (GL resource)

  colorMatrixShader:cardinal;
  colorMatrixRed,colorMatrixGreen,colorMatrixBlue:cardinal;
  procedure Initialize; virtual; // инициализация (после потери девайса)
  // Установка вьюпорта (в координатах окна) и области отсечения
  procedure SetupViewport; virtual;

  {$IFNDEF GLES20}
  function SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean; override; // возвращает false если примитив полностью отсекается

  procedure renderDevice.Draw(primType,primCount:integer;vertices:pointer;stride:integer); override;
  procedure DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer); override;

  procedure DrawPrimitivesFromBuf(primType,primCount,vrtStart:integer;
    vertexBuf:TPainterBuffer;stride:integer); override;

  procedure DrawIndexedPrimitives(primType:integer;vertexBuf,indBuf:TPainterBuffer;
    stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); override;

  procedure DrawIndexedPrimitivesDirectly(primType:integer;vertexBuf:PVertex;indBuf:PWord;
    stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); override;
  {$ENDIF}

  function LockBuffer(buf:TPainterBuffer;offset,size:cardinal):pointer; override;
  procedure UnlockBuffer(buf:TPainterBuffer); override;
  procedure ResetTextures; virtual;
  procedure SetGLMatrix(mType:TMatrixType;mat:PDouble); virtual;
  procedure SwitchToDefaultFramebuffer; virtual;
 end;

var
 glDebug:boolean = {$IFDEF MSWINDOWS} false {$ELSE} true {$ENDIF};

implementation
 uses Apus.CrossPlatform, Apus.MyServis, Apus.Geom2D, Apus.Geom3D, SysUtils,
    {$IFDEF GLES11}gles11,glext,{$ENDIF}
    {$IFDEF GLES20}gles20,{$ENDIF}
    {$IFNDEF GLES}dglOpenGl,{$ENDIF}
    Apus.Images, Apus.Engine.GLImages;

type
 TScrPoint8=record
  x,y,z,rhw:single;
  diffuse,specular:cardinal;
  uv:array[0..7,0..1] of single;
 end;

procedure CheckForGLError(lab:integer=0); inline;
var
 error:cardinal;
begin
 if glDebug then begin
  error:=glGetError;
  if error<>GL_NO_ERROR then begin
    ForceLogMessage('PGL Error ('+inttostr(lab)+'): '+inttostr(error)+' '+GetCallStack);
  end;
 end;
end;


function SwapColor(color:cardinal):cardinal; inline;
begin
 result:=color and $FF00FF00+(color and $FF) shl 16+(color and $FF0000) shr 16;
end;

function clRed(color:cardinal):single; inline;
begin
 result:=((color shr 16) and $FF)/255;
end;

function clGreen(color:cardinal):single; inline;
begin
 result:=((color shr 8) and $FF)/255;
end;

function clBlue(color:cardinal):single; inline;
begin
 result:=(color and $FF)/255;
end;

function clAlpha(color:cardinal):single; inline;
begin
 result:=((color shr 24) and $FF)/255;
end;

const
 vColorMatrix=
  'void main(void)'#13#10+
  '{'#13#10+
  '    gl_TexCoord[0] = gl_MultiTexCoord0;                           '#13#10+
  '    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;       '#13#10+
  '}';

 fColorMatrix=
  'uniform sampler2D tex1;    '#13#10+
  'uniform vec3 newRed;   '#13#10+
  'uniform vec3 newGreen;   '#13#10+
  'uniform vec3 newBlue;   '#13#10+
  'void main(void)                         '#13#10+
  '{                                       '#13#10+
  '    vec4 value = texture2D(tex1, vec2(gl_TexCoord[0]));  '#13#10+
   '    float red = dot(value, vec4(newRed, 0));     '#13#10+
   '    float green = dot(value, vec4(newGreen, 0)); '#13#10+
   '    float blue = dot(value, vec4(newBlue,0));    '#13#10+
   '    gl_FragColor = vec4(red,green,blue,value.a); '#13#10+
  '}';


constructor TGLPainter.Create;
var
 i:integer;
begin
 try
 // Adjust font cache
 if game.screenWidth*game.screenHeight>2500000 then textCacheHeight:=max2(textCacheHeight,1024);
 if game.screenWidth*game.screenHeight>3500000 then textCacheWidth:=max2(textCacheWidth,1024);
 texman:=TGLTextureMan.Create;
 inherited Create;
 defaultRenderTarget:=nil;
 Initialize;
 textcolorx2:=false;
 stackcnt:=0;
 curmask:=$F;
 canPaint:=0;
 efftex:=nil;
 txtTex:=nil;
 efftex:=texman.AllocImage(256,32,ipfARGB,aiTexture,'effectTex') as TGLtexture;
 txttex:=texman.AllocImage(1024,32,ipfARGB,aiTexture,'txtTex') as TGLtexture;
 textCache:=texman.AllocImage(textCacheWidth,textCacheHeight,ipfA8,aiTexture,'textCache');
 colorFormat:=1; // colors should be flipped
 supportARGB:=true; // always supported
 for i:=0 to 3 do begin
  curColorMode[i]:=tblNone;
  curAlphaMode[i]:=tblNone;
  curRGBScale[i]:=0;
 end;

 viewMatrix:=IdentMatrix4;
 objMatrix:=IdentMatrix4;

 try
  colorMatrixShader:=0;
  colorMatrixShader:=BuildShaderProgram(vColorMatrix,fColorMatrix);
  if colorMatrixShader>0 then begin
   colorMatrixRed:=glGetUniformLocation(colorMatrixShader,'newRed');
   colorMatrixGreen:=glGetUniformLocation(colorMatrixShader,'newGreen');
   colorMatrixBlue:=glGetUniformLocation(colorMatrixShader,'newBlue');
  end;
 except
 end;
 except
  on e:Exception do begin
   ForceLogMessage('Error in GLPainter constructor: '+e.message);
   raise EFatalError.Create('GLPainter: '+e.Message);
  end;
 end;
end;

destructor TGLPainter.Destroy;
begin
 // Здесь надо бы освободить шрифты и всё такое прочее
 LogMessage('Painter deleted');
 inherited;
end;

function TGLPainter.BuildShaderProgram(vSrc,fSrc:AnsiString;attribNames:AnsiString=''):integer;
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
 if not GL_VERSION_2_0 then begin
  result:=0; exit;
 end;
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
 if attribNames>'' then begin
  sa:=splitA(',',attribNames);
  for i:=0 to high(sa) do
   glBindAttribLocation(prog,i,PAnsiChar(sa[i])); // Link attribute index i to attribute named sa[i]
 end;
 glLinkProgram(prog);
 glGetProgramiv(prog,GL_LINK_STATUS,@res);
 if res=0 then raise EError.Create('Shader program not linked!');
 result:=prog;
end;

function TGLPainter.LockBuffer(buf: TPainterBuffer; offset,
  size: cardinal): pointer;
begin
 case buf of
  vertBuf:begin result:=@partbuf[offset];end;
  bandIndBuf:begin result:=@bandInd[offset]; end;
  textVertBuf:begin result:=@txtBuf[offset]; end;
  else raise EWarning.Create('Invalid buffer type');
 end;
end;

procedure TGLPainter.UnlockBuffer(buf: TPainterBuffer);
begin
end;

{$IFNDEF GLES20}
procedure TGLPainter.DrawIndexedPrimitives(primType: integer; vertexBuf,
  indBuf: TPainterBuffer; stride:integer; vrtStart, vrtCount, indStart, primCount: integer);
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
 glVertexPointer(3,GL_FLOAT,stride,@vrt.x);
 glColorPointer(4,GL_UNSIGNED_BYTE,stride,@vrt.color);
 glTexCoordPointer(2,GL_FLOAT,stride,@vrt.u);
 case primtype of
  LINE_LIST:glDrawElements(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,ind);
  LINE_STRIP:glDrawElements(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,ind);
  TRG_LIST:glDrawElements(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,ind);
  TRG_FAN:glDrawElements(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,ind);
  TRG_STRIP:glDrawElements(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,ind);
 end;
end;

procedure TGLPainter.DrawIndexedPrimitivesDirectly(primType: integer;
  vertexBuf: PVertex; indBuf: PWord; stride, vrtStart, vrtCount, indStart,
  primCount: integer);
begin
 glVertexPointer(3,GL_FLOAT,stride,@vertexBuf.x);
 glColorPointer(4,GL_UNSIGNED_BYTE,stride,@vertexBuf.color);
 glTexCoordPointer(2,GL_FLOAT,stride,@vertexBuf.u);
 case primtype of
  LINE_LIST:glDrawElements(GL_LINES,primCount*2,GL_UNSIGNED_SHORT,indBuf);
  LINE_STRIP:glDrawElements(GL_LINE_STRIP,primCount+1,GL_UNSIGNED_SHORT,indBuf);
  TRG_LIST:glDrawElements(GL_TRIANGLES,primCount*3,GL_UNSIGNED_SHORT,indBuf);
  TRG_FAN:glDrawElements(GL_TRIANGLE_FAN,primCount+2,GL_UNSIGNED_SHORT,indBuf);
  TRG_STRIP:glDrawElements(GL_TRIANGLE_STRIP,primCount+2,GL_UNSIGNED_SHORT,indBuf);
 end;
end;

procedure TGLPainter.renderDevice.Draw(primType, primCount: integer;
  vertices: pointer; stride: integer);
var
 vrt:PVertex;
begin
 vrt:=vertices;
 glVertexPointer(3,GL_FLOAT,stride,@vrt.x);
 glColorPointer(4,GL_UNSIGNED_BYTE,stride,@vrt.color);
 glTexCoordPointer(2,GL_FLOAT,stride,@vrt.u);
 case primtype of
  LINE_LIST:glDrawArrays(GL_LINES,0,primCount*2);
  LINE_STRIP:glDrawArrays(GL_LINE_STRIP,0,primCount+1);
  TRG_LIST:glDrawArrays(GL_TRIANGLES,0,primCount*3);
  TRG_FAN:glDrawArrays(GL_TRIANGLE_FAN,0,primCount+2);
  TRG_STRIP:glDrawArrays(GL_TRIANGLE_STRIP,0,primCount+2);
 end;
end;

procedure TGLPainter.DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer);
var
 vrt:PScrPoint3;
 i:integer;
begin
 vrt:=vertices;
 glVertexPointer(3,GL_FLOAT,stride,@vrt.x);
 glColorPointer(4,GL_UNSIGNED_BYTE,stride,@vrt.color);
 glTexCoordPointer(2,GL_FLOAT,stride,@vrt.u);
 // Texture 2
 if stages>1 then begin
  glClientActiveTexture(GL_TEXTURE1);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2,GL_FLOAT,stride,@vrt.u2);
 end;
 if stages>2 then begin
  glClientActiveTexture(GL_TEXTURE2);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2,GL_FLOAT,stride,@vrt.u3);
 end;
 case primtype of
  LINE_LIST:glDrawArrays(GL_LINES,0,primCount*2);
  LINE_STRIP:glDrawArrays(GL_LINE_STRIP,0,primCount+1);
  TRG_LIST:glDrawArrays(GL_TRIANGLES,0,primCount*3);
  TRG_FAN:glDrawArrays(GL_TRIANGLE_FAN,0,primCount+2);
  TRG_STRIP:glDrawArrays(GL_TRIANGLE_STRIP,0,primCount+2);
 end;
 for i:=1 to stages-1 do begin
  glClientActiveTexture(GL_TEXTURE0+i);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
 end;
 glClientActiveTexture(GL_TEXTURE0);
end;


procedure TGLPainter.DrawPrimitivesFromBuf(primType, primCount,
  vrtStart: integer; vertexBuf: TPainterBuffer; stride:integer);
var
 vrt:PVertex;
begin
 case vertexBuf of
  vertBuf:vrt:=@partBuf[0];
  textVertBuf:vrt:=@txtBuf[0];
 end;
 glVertexPointer(3,GL_FLOAT,stride,@vrt.x);
 glColorPointer(4,GL_UNSIGNED_BYTE,stride,@vrt.color);
 glTexCoordPointer(2,GL_FLOAT,stride,@vrt.u);
 case primtype of
  LINE_LIST:glDrawArrays(GL_LINES,vrtStart,primCount*2);
  LINE_STRIP:glDrawArrays(GL_LINE_STRIP,vrtStart,primCount+1);
  TRG_LIST:glDrawArrays(GL_TRIANGLES,vrtStart,primCount*3);
  TRG_FAN:glDrawArrays(GL_TRIANGLE_FAN,vrtStart,primCount+2);
  TRG_STRIP:glDrawArrays(GL_TRIANGLE_STRIP,vrtStart,primCount+2);
 end;
end;

procedure TGLPainter.DrawMultiTex(x1, y1, x2, y2: integer;  layers:PMultiTexLayer; color: cardinal);
var
 vrt:array[0..3] of TScrPoint8;
 lr:array[0..7] of TMultiTexLayer;
 i,lMax:integer;
// cnt:integer;
 // ïåðåâåñòè ìàòðèöó èç ïîëíîãî ìàñøòàáà ê ìàñøòàáó èçîáðàæåíèÿ â ìåòàòåêñòóðå
 procedure AdjustMatrix(const texture:TTexture;var matrix:TMatrix32s);
  var
   sx,sy,dx,dy:single;
   i:integer;
  begin
   with texture do begin
    sx:=u2-u1; sy:=v2-v1;
    dx:=u1; dy:=v1;
   end;
   for i:=0 to 2 do begin
    matrix[i,0]:=matrix[i,0]*sx;
    matrix[i,1]:=matrix[i,1]*sy;
   end;
   matrix[2,0]:=matrix[2,0]+dx;
   matrix[2,1]:=matrix[2,1]+dy;
  end;
begin
 if not SetStates(1,types.Rect(x1,y1,x2+1,y2+1)) then exit;

 // Copy layers data to modify later
 for i:=0 to High(lr) do begin
  lMax:=i;
  lr[i]:=layers^;
  layers:=layers.next;
  if layers=nil then break;
 end;

// fillchar(vrt,sizeof(vrt),0);
 with vrt[0] do begin
  x:=x1-0.5; y:=y1-0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=0; uv[i,1]:=0;
  end;
 end;
 with vrt[1] do begin
  x:=x2+0.5; y:=y1-0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=1; uv[i,1]:=0;
  end;
 end;
 with vrt[2] do begin
  x:=x2+0.5; y:=y2+0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=1; uv[i,1]:=1;
  end;
 end;
 with vrt[3] do begin
  x:=x1-0.5; y:=y2+0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=0; uv[i,1]:=1;
  end;
 end;

 for i:=0 to lMax do
  with lr[i] do begin
   if texture=nil then break;
   UseTexture(texture,i);
   if texture.caps and tfTexture=0 then AdjustMatrix(texture,matrix);
   MultPnts(matrix,PPoint2s(@vrt[0].uv[i,0]),4,sizeof(TScrPoint8));
   MultPnts(matrix,PPoint2s(@vrt[0].uv[i,1]),4,sizeof(TScrPoint8));
   if i>0 then begin
    glClientActiveTexture(GL_TEXTURE0+i);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
   end;
   glTexCoordPointer(2,GL_FLOAT,sizeof(TScrPoint8),@vrt[0].uv[i]);
  end;

 glClientActiveTexture(GL_TEXTURE0);

 glVertexPointer(3,GL_FLOAT,sizeof(TScrPoint3),@vrt);
 glColorPointer(4,GL_UNSIGNED_BYTE,sizeof(TScrPoint3),@vrt[0].color);
// glTexCoordPointer(2,GL_FLOAT,sizeof(TScrPoint3),@vrt[0].u);
 glDrawArrays(GL_TRIANGLE_FAN,0,4);

 for i:=1 to lMax do begin
  glClientActiveTexture(GL_TEXTURE0+i);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
 end;

 // Вообще-то это должен делать вызывающий код
 glActiveTexture(GL_TEXTURE1);
 glDisable(GL_TEXTURE_2D);
 glActiveTexture(GL_TEXTURE0);
 glClientActiveTexture(GL_TEXTURE0);
end;

procedure TGLPainter.SetTexMode;
var
 scale:integer;
 color:array[0..3] of single;
begin
 if (stage=0) and (filter<>fltUndefined) then curFilters[0]:=filter;
 if (stage>0) or (colorMode<>tblNone) or (alphaMode<>tblNone) then begin
  glActiveTexture(GL_TEXTURE0+stage);
  if stage>0 then
   glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);

  if colorMode<>curColorMode[stage] then
   if colorMode<>tblDisable then begin
    glEnable(GL_TEXTURE_2D);
   end else
    glDisable(GL_TEXTURE_2D);

  if filter<>fltUndefined then curFilters[stage]:=filter;

  if colorMode<>curColorMode[stage] then begin
   case colorMode of
    tblKeep:begin
     glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_RGB, GL_PREVIOUS);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
     scale:=1;
    end;
    tblReplace:begin
     glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_RGB, GL_TEXTURE);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
     scale:=1;
    end;
    tblModulate:begin
     glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE); // функция - умножение (Arg0 * Arg1)
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_RGB, GL_PREVIOUS);    // Указывает что Arg0 берётся из предыдущей стадии
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR); // Указывает какие именно данные берутся в качестве Arg0
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_RGB, GL_TEXTURE);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
     scale:=1;
    end;
    tblModulate2X:begin
     glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_RGB, GL_PREVIOUS);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_RGB, GL_TEXTURE);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
     scale:=2;
    end;
    tblAdd:begin
     glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_ADD);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_RGB, GL_PREVIOUS);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_RGB, GL_TEXTURE);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
     scale:=1;
    end;
    tblInterpolate:begin
     glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_INTERPOLATE);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_RGB, GL_PREVIOUS);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
     glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_RGB, GL_TEXTURE);
     glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
     scale:=1;
    end;
    else scale:=1;
   end;
   curColorMode[stage]:=colorMode;
   if scale<>curRGBScale[stage] then begin
    glTexEnvi(GL_TEXTURE_ENV, GL_RGB_SCALE, scale);
    curRGBScale[stage]:=scale;
   end;
  end;

  if alphaMode<>curAlphaMode[stage] then
  case alphaMode of
   tblKeep:begin
    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, GL_REPLACE);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_ALPHA, GL_PREVIOUS);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, GL_SRC_ALPHA);
   end;
   tblReplace:begin
    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, GL_REPLACE);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_ALPHA, GL_TEXTURE);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, GL_SRC_ALPHA);
   end;
   tblModulate:begin
    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, GL_MODULATE);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_ALPHA, GL_PREVIOUS);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, GL_SRC_ALPHA);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_ALPHA, GL_TEXTURE);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA, GL_SRC_ALPHA);
   end;
   tblModulate2X:begin
    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, GL_MODULATE);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_ALPHA, GL_PREVIOUS);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, GL_SRC_ALPHA);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_ALPHA, GL_TEXTURE);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA, GL_SRC_ALPHA);
   end;
   tblAdd:begin
    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, GL_ADD);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_ALPHA, GL_PREVIOUS);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, GL_SRC_ALPHA);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_ALPHA, GL_TEXTURE);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA, GL_SRC_ALPHA);
   end;
   tblInterpolate:begin
    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, GL_INTERPOLATE);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC0_ALPHA, GL_PREVIOUS);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, GL_SRC_ALPHA);
    glTexEnvi(GL_TEXTURE_ENV, GL_SRC1_ALPHA, GL_TEXTURE);
    glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA, GL_SRC_ALPHA);
   end;
  end;

  // Interpolation mode set and factor changed?
  if (alphaMode=tblInterpolate) or (colorMode=tblInterpolate) then
   if (intFactor<>texIntFactor[stage]) then begin
    color[0]:=intFactor; color[1]:=intFactor; color[2]:=intFactor; color[3]:=intFactor;
    glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR, @color);
    texIntFactor[stage]:=intFactor;
   end;

  glActiveTexture(GL_TEXTURE0);
 end;
 curAlphaMode[stage]:=alphaMode;
end;

function TGLPainter.SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean;
var
 f1,f2:byte;
 r:TRect;
 op:TPoint;
begin
 f1:=IntersectRects(primRect,clipRect,r);
 if f1=0 then begin
  result:=false;
  exit;
 end else result:=true;

 if tex<>nil then begin
  if (state=STATE_TEXTURED2X) and
     (tex.PixelFormat in [ipfA8,ipfA4]) then state:=STATE_COLORED2X; // override color blending mode for alpha only textures
 end;
 if curstate<>state then begin
  ASSERT(state in [0..4]);
  case state of
   STATE_TEXTURED2X,STATE_MULTITEX:begin
      //SetTexMode(0,tblModulate2X,tblModulate,fltBilinear);
      case curstate of
       STATE_COLORED:glEnable(GL_TEXTURE_2D); // Colored -> Textured
       STATE_MULTITEX:UseTexture(nil,1); // Multitex->SingleTex: Disable multi-texturing
      end;
      SetTexMode(0,tblModulate2X,tblModulate,fltBilinear);
      glEnableClientState(GL_VERTEX_ARRAY);
      glEnableClientState(GL_COLOR_ARRAY);
      glEnableClientState(GL_TEXTURE_COORD_ARRAY);
     end;
   STATE_COLORED:begin
      SetTexMode(0,tblKeep,tblKeep,fltUndefined);
//      glTexEnvi(GL_TEXTURE_ENV, GL_RGB_SCALE, 1);
      glDisable(GL_TEXTURE_2D);
      glEnableClientState(GL_VERTEX_ARRAY);
      glEnableClientState(GL_COLOR_ARRAY);
      glDisableClientState(GL_TEXTURE_COORD_ARRAY);
//      SetTexMode(0,tblKeep,tblKeep,fltUndefined);
      curTextures[0]:=nil;
     end;
   STATE_COLORED2X:begin
      if curState=STATE_COLORED then
       glEnable(GL_TEXTURE_2D);
      SetTexMode(0,tblKeep,tblModulate,fltBilinear);
      glEnableClientState(GL_VERTEX_ARRAY);
      glEnableClientState(GL_COLOR_ARRAY);
      glEnableClientState(GL_TEXTURE_COORD_ARRAY);
     end;
  end;
  curstate:=state;
 end;
 if not EqualRect(clipRect,actualClip) then begin
  f2:=IntersectRects(primRect,actualClip,r);
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
{$ENDIF}

procedure TGLPainter.SetMode;
begin
 if blend=curblend then exit;
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
 curblend:=blend;
 CheckForGLError(31);
end;

procedure TGLPainter.SetupViewport;
var
 w,h:integer;
begin
 SetDefaultView;
 if curtarget<>nil then
  glViewport(0,0,curTarget.width,curTarget.height)
 else
  glViewport(outputPos.X,outputPos.Y,VPwidth,VPheight);
 CheckForGLError(1);
end;

procedure TGLPainter.Set3DView(view:T3DMatrix);
var
 x,y,z:double;
begin
 Invert4Full(view,viewMatrix);
 Set3DTransform(objMatrix);
end;

procedure TGlPainter.SetGLMatrix(mType:TMatrixType;mat:PDouble);
begin
 {$IFNDEF GLES20}
 case mType of
  mtModelView:glMatrixMode(GL_MODELVIEW);
  mtProjection:glMatrixMode(GL_PROJECTION);
 end;
 if mat<>nil then glLoadMatrixd(PGLDouble(mat))
  else glLoadIdentity;
 CheckForGLError;
 {$ENDIF}
end;

procedure TGLPainter.Set3DTransform(mat:T3DMatrix);
var
 m:array[0..15] of double;
 ms:T3DMatrix;
begin
 objMatrix:=mat;
 MultMat4(mat,viewMatrix,ms);
 SetGLMatrix(mtModelView,@ms);
end;

procedure TGLPainter.SetDefaultRenderArea(oX, oY, VPwidth, VPheight,
  renderWidth, renderHeight: integer);
begin
 defaultRenderTarget:=nil;
 outputPos:=Point(oX,oY);
 outputPos:=Point(oX,oY);
 self.renderWidth:=renderWidth;
 self.renderHeight:=renderHeight;
 self.VPwidth:=VPwidth;
 self.VPheight:=VPheight;
 ResetTarget;
end;

procedure TGLPainter.SetDefaultRenderTarget(rt: TTexture);
begin
 defaultRenderTarget:=rt;
end;

procedure TGLPainter.SetDefaultView;
var
 w,h:integer;
begin
 w:=screenRect.Right-screenRect.Left;
 h:=screenRect.Bottom-screenRect.top;
 if (w=0) and (h=0) then exit;
 projMatrix[0,0]:=2/w;  projMatrix[1,0]:=0; projMatrix[2,0]:=0; projMatrix[3,0]:=-1+1/w;
 if (curtarget<>defaultRenderTarget) then begin
  projMatrix[0,1]:=0;  projMatrix[1,1]:=2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=-(1-1/h);
 end else begin
  projMatrix[0,1]:=0;  projMatrix[1,1]:=-2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=1-1/h;
 end;
 projMatrix[0,2]:=0;  projMatrix[1,2]:=0; projMatrix[2,2]:=-1; projMatrix[3,2]:=0;
 projMatrix[0,3]:=0;  projMatrix[1,3]:=0; projMatrix[2,3]:=0; projMatrix[3,3]:=1;

{ m[0]:=2/w;    m[4]:=0;     m[8]:=0;        m[12]:=-1+1/w;
 // в текстурах ось Y направлена сверху-вниз, а в defaultRT (даже если это тоже текстура) - снизу вверх
 if (curtarget<>defaultRenderTarget) then begin
  m[1]:=0;      m[5]:=2/h;  m[9]:=0;        m[13]:=-(1-1/h);
 end else begin
  m[1]:=0;      m[5]:=-2/h;  m[9]:=0;       m[13]:=1-1/h;
 end;
 m[2]:=0;      m[6]:=0;     m[10]:=-1;      m[14]:=0;
 m[3]:=0;      m[7]:=0;     m[11]:=0;       m[15]:=1;}

 viewMatrix:=IdentMatrix4;
 objMatrix:=IdentMatrix4;
 SetGLMatrix(mtProjection,@projMatrix);
 SetGLMatrix(mtModelView,nil);
end;

procedure TGlPainter.SetOrthographic(scale,zMin,zMax:double);
var
 w,h:integer;
begin
 w:=(screenRect.Right-screenRect.Left);
 h:=(screenRect.Bottom-screenRect.top);

 projMatrix[0,0]:=scale*2/w;  projMatrix[1,0]:=0; projMatrix[2,0]:=0; projMatrix[3,0]:=0;
 if (curtarget<>defaultRenderTarget) then begin
  projMatrix[0,1]:=0;  projMatrix[1,1]:=scale*2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=0;
 end else begin
  projMatrix[0,1]:=0;  projMatrix[1,1]:=-scale*2/h; projMatrix[2,1]:=0; projMatrix[3,1]:=0;
 end;
 projMatrix[0,2]:=0;  projMatrix[1,2]:=0; projMatrix[2,2]:=2/(zMax-zMin); projMatrix[3,2]:=-(zMax+zMin)/(zMax-zMin);
 projMatrix[0,3]:=0;  projMatrix[1,3]:=0; projMatrix[2,3]:=0; projMatrix[3,3]:=1;

 SetGLMatrix(mtProjection,@projMatrix);
end;

procedure TGlPainter.SetPerspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double);
var
 i:integer;
begin
 inherited;
 if curtarget=defaultRenderTarget then // нужно переворачивать ось Y если только не рисуем в текстуру
  for i:=0 to 3 do
   projMatrix[i,1]:=-projMatrix[i,1];

 SetGLMatrix(mtProjection,@projMatrix);
end;

procedure TGlPainter.ResetColorTransform;
begin
 glUseProgram(0);
end;

procedure TGLPainter.SetColorTransform(const mat:T3DMatrix);
begin
 if colorMatrixShader=0 then exit;
 glUseProgram(colorMatrixShader);
 glUniform3f(colorMatrixRed,  mat[0,0],mat[0,1],mat[0,2]);
 glUniform3f(colorMatrixGreen,mat[1,0],mat[1,1],mat[1,2]);
 glUniform3f(colorMatrixBlue, mat[2,0],mat[2,1],mat[2,2]);
end;

procedure TGLPainter.SetMask(rgb:boolean;alpha:boolean);
var
 mask:integer;
begin
 ASSERT(oldmaskpos<15);
 mask:=0;
 oldmask[oldmaskpos]:=curmask;
 oldmaskpos:=(oldmaskpos+1) and 15;
// DebugMessage('SetMask -> '+inttostr(oldmaskpos));
 if rgb then mask:=mask+7;
 if alpha then mask:=mask+8;
 if curmask<>mask then begin
  {$IFDEF GLES}
  glColorMask((mask and 4),
              (mask and 2),
              (mask and 1),
              (mask and 8));
  {$ELSE}
  glColorMask((mask and 4)>0,
              (mask and 2)>0,
              (mask and 1)>0,
              (mask and 8)>0);
  {$ENDIF}
  curmask:=mask;
 end;
end;

procedure TGLPainter.ResetMask;
 var
  mask:integer;
 begin
//  DebugMessage('ResetMask -> '+inttostr(oldmaskpos));
  ASSERT(oldmaskpos>0);
  oldmaskpos:=(oldmaskpos-1) and 15;
  mask:=oldmask[oldmaskpos];
  if curmask<>mask then begin
   {$IFDEF GLES}
   glColorMask((mask and 4),
               (mask and 2),
               (mask and 1),
               (mask and 8));
   {$ELSE}
   glColorMask((mask and 4)>0,
               (mask and 2)>0,
               (mask and 1)>0,
               (mask and 8)>0);
   {$ENDIF}
   curmask:=mask;
  end;
 end;

procedure TGLPainter.Restore;
var
 bl:TBlendingMode;
begin
 bl:=curblend;
 inc(curblend);
 SetMode(bl);
 CheckForGLError(10);
 SetTexMode(0,tblNone,tblNone,fltUndefined);
 CheckForGLError(11);
 curmask:=-1;
 curTextures[0]:=nil;
 curTextures[1]:=nil;
 curTextures[2]:=nil;
 curTextures[3]:=nil;
 curstate:=0;
 RestoreClipping;
 viewMatrix:=IdentMatrix4;
 objMatrix:=IdentMatrix4;
end;

{$IFNDEF GLES20}
procedure TGLPainter.ResetTexMode;
begin
 if GL_VERSION_2_0 then glUseProgram(0);
 SetTexMode(0,tblModulate2X,tblModulate);
 SetTexMode(1,tblDisable,tblDisable);
end;
{$ENDIF}

procedure TGLPainter.ResetTextures;
begin
 with texman as TGLTextureMan do begin
  MakeOnline(nil,0);
  MakeOnline(nil,1);
  MakeOnline(nil,2);
 end;
end;

procedure TGLPainter.SwitchToDefaultFramebuffer;
begin
 {$IFDEF GLES11}
 glBindFramebufferOES(GL_FRAMEBUFFER_OES,defaultFramebuffer);
 {$ENDIF}
 {$IFDEF GLES20}
 glBindFramebuffer(GL_FRAMEBUFFER,0);
 {$ENDIF}
 {$IFNDEF GLES}
 if GL_ARB_framebuffer_object then
   glBindFramebuffer(GL_DRAW_FRAMEBUFFER,0);
 {$ENDIF}
 CheckForGLError(3);
end;

procedure TGLPainter.ResetTarget;
var
 stage:integer;
begin
 try
 stage:=0;
 if defaultRenderTarget<>nil then begin
  if curtarget<>defaultRenderTarget then
   SetTargetToTexture(defaultRenderTarget);
  CheckForGLError(4);
  exit;
 end;
 stage:=1;
 FlushTextCache;
 //glFlush;
 CheckForGLError(5);
 stage:=2;
 SwitchToDefaultFramebuffer;
 curtarget:=nil;
 stage:=3;
 CheckForGLError(12);
 RestoreClipping;
 screenRect:=ActualClip;
 clipRect:=ActualClip;
 stage:=4;
 SetupViewport;
 stage:=5;
 ResetTextures;
 CheckForGLError(6);
 except
  on e:exception do ForceLogMessage('Error in ResetTarget '+inttostr(stage)+': '+ExceptionMsg(e));
 end;
end;

procedure TGLPainter.SetTargetToTexture(tex: TTexture);
var
 rt:TGLTexture;
 stage:integer;
begin
 try
 stage:=0;
 rt:=tex as TGLTexture;
 FlushTextCache;
 stage:=1;
 //glFlush;
 stage:=2;

 rt.SetAsRenderTarget;
 stage:=3;

// texman.MakeOnline(tex);
 ScreenRect.Left:=0;
 ScreenRect.Top:=0;
 ScreenRect.right:=tex.width;
 ScreenRect.bottom:=tex.height;
 curtarget:=tex;
 SetupViewport;
 stage:=4;
 CheckForGLError(13);
 RestoreClipping;
 stage:=5;
 clipRect:=actualClip;
 ResetTextures;
 except
  on e:exception do ForceLogMessage('Error in STTT '+inttostr(stage)+':('+rt.Describe+'): '+ExceptionMsg(e));
 end;
end;

procedure TGLPainter.UseDepthBuffer(test:TDepthBufferTest; writeEnable:boolean);
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

procedure TGLPainter.UseTexture(tex: TTexture;stage:integer=0);
begin
 //if tex=curTextures[stage] then exit;
 if tex<>nil then begin
//  glActiveTexture(GL_TEXTURE0+stage);
  if tex.parent<>nil then tex:=tex.parent;
  //TGLTexture(tex).filter:=curFilters[stage];
  texman.MakeOnline(tex,stage);
  if curFilters[stage]<>TGLTexture(tex).filter then
   (texman as TGLTextureMan).SetTexFilter(tex,curFilters[stage]);

 end else begin
  glActiveTexture(GL_TEXTURE0+stage);
  glBindTexture(GL_TEXTURE_2D,0);
 end;
 curTextures[stage]:=tex;
end;

procedure TGLPainter.RestoreClipping;
begin
 CheckForGLError(71);
 if curtarget<>nil then begin
  screenRect:=types.Rect(0,0,curTarget.width,curTarget.height);
  glScissor(0,0,screenRect.right,screenrect.bottom);
  targetScaleX:=1; targetScaleY:=1;
 end else begin
  screenRect:=types.Rect(0,0,renderWidth,renderHeight);
  glScissor(outputPos.x,outputPos.y,outputPos.x+VPwidth,outputPos.y+VPheight);
  if renderWidth*renderHeight>0 then begin
   targetScaleX:=VPwidth/renderWidth;
   targetScaleY:=VPheight/renderheight;
  end;
 end;
 actualClip:=screenRect;
 CheckForGLError(7);
end;

procedure TGLPainter.Initialize;
var
 i:integer;
 pw:^word;
begin
 ForceLogMessage('(re)Initializing Painter');
 curblend:=blNone;
 SetMode(blAlpha);
 SetTexMode(0,tblModulate2X,tblModulate,fltBilinear);
 for i:=1 to 3 do
  SetTexMode(i,tblDisable,tblDisable,fltBilinear);
 glEnable(GL_SCISSOR_TEST);
 glFrontFace(GL_CW);

 {$IFNDEF GLES20}
 glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
 glTexEnvi(GL_TEXTURE_ENV, GL_RGB_SCALE, 2);
 {$ENDIF}
 curRGBScale[0]:=2;

 setLength(partBuf,4*MaxParticleCount);
 setLength(partInd,6*MaxParticleCount);
 setLength(txtBuf,4*MaxGlyphBufferCount);
 pw:=@partInd[0];
 for i:=0 to MaxParticleCount-1 do begin
  pw^:=i*4; inc(pw);
  pw^:=i*4+1; inc(pw);
  pw^:=i*4+2; inc(pw);
  pw^:=i*4; inc(pw);
  pw^:=i*4+2; inc(pw);
  pw^:=i*4+3; inc(pw);
 end;
 setLength(bandInd,4*MaxParticleCount);

 ResetTarget;
{ RestoreClipping;
 ScreenRect:=ActualClip;
 ClipRect:=ActualCLip;}

 curState:=0;
 curTextures[0]:=nil;
 curTextures[1]:=nil;
 curTextures[2]:=nil;
 curTextures[3]:=nil;
 curTarget:=nil;
 stackcnt:=0;
 vertBufUsage:=0;
 textBufUsage:=0;
 textCaching:=false;
 CheckForGLError(8);
end;

procedure TGLPainter.Clear(color: cardinal; zbuf: single=0;
  stencil: integer=-1);
var
 mask:cardinal;
begin
 mask:=GL_COLOR_BUFFER_BIT;
 glDisable(GL_SCISSOR_TEST);
 glClearColor(clRed(color),clGreen(color),clBlue(color),clAlpha(color));
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

end.
