{$APPTYPE CONSOLE}
program OpenGL;

uses
  Apus.MyServis, Apus.CrossPlatform, SysUtils,
  dglOpenGL,
  {$IFDEF MSWINDOWS}
  Apus.Engine.WindowsPlatform,
  {$ENDIF}
  Apus.EventMan,
  Apus.Geom3D,
  Apus.Engine.API,
  Apus.Engine.SDLplatform,
  Apus.Engine.OpenGL;

var
 params:TGameSettings;
 sn:integer;
 shader:GLint;
 tex:GLint;
 shader1,shader2:GLint;

procedure EventHandler(event:TEventStr;tag:TTag);
begin
 {inc(sn);
 writeln(sn:4,' ',event,' ',IntToHex(tag));}
end;

var
 vShader:array[1..14] of String8=(
' #version 330                               ',
' uniform mat4 MVP;                         ',
' layout (location=0) in vec3 position;      ',
' layout (location=1) in vec4 color;         ',
' layout (location=2) in vec2 texCoord;      ',
' out vec4 vColor;                           ',
' out vec2 vTexCoord;                        ',
'                                            ',
' void main(void)                            ',
' {                                          ',
'   gl_Position = MVP * vec4(position, 1.0);',
'   vColor = color;                          ',
'   vTexCoord = texCoord;                    ',
' }                                          ');


 fShader:array[1..57] of String8=(
' #version 330                                                        ',
' uniform sampler2D tex;                                              ',
' uniform int colorOp;                                                ',
' uniform int alphaOp;                                                ',
' uniform float uFactor;                                              ',
' in vec4 vColor;                                                     ',
' in vec2 vTexCoord;                                                  ',
' out vec4 fragColor;                                                 ',
'                                                                     ',
' void main(void)                                                     ',
' {                                                                   ',
'   vec3 c = vec3(vColor.b, vColor.g, vColor.r);                      ',
'   float a = vColor.a;                                               ',
'   vec4 t = texture2D(tex,vTexCoord);                                ',
'   switch (colorOp) {                                                ',
'     case 3: // tblReplace                                           ',
'       c = vec3(t.r, t.g, t.b);                                      ',
'       break;                                                        ',
'     case 4: // tblModulate                                          ',
'       c = c*vec3(t.r, t.g, t.b);                                    ',
'       break;                                                        ',
'     case 5: // tblModulate2X                                        ',
'       c = 2.0*c*vec3(t.r, t.g, t.b);                                ',
'       break;                                                        ',
'     case 6: // tblAdd                                               ',
'       c = c+vec3(t.r, t.g, t.b);                                    ',
'       break;                                                        ',
'     case 7: // tblSub                                               ',
'       c = c-vec3(t.r, t.g, t.b);                                    ',
'       break;                                                        ',
'     case 8: // tblInterpolate                                       ',
'       c = mix(c, vec3(t.r, t.g, t.b), uFactor);                     ',
'       break;                                                        ',
'   }                                                                 ',
'   switch (alphaOp) {                                                ',
'     case 3: // tblReplace                                           ',
'       a = t.a;                                                      ',
'       break;                                                        ',
'     case 4: // tblModulate                                          ',
'       a = a*t.a;                                                    ',
'       break;                                                        ',
'     case 5: // tblModulate2X                                        ',
'       a = 2.0*a*t.a;                                                ',
'       break;                                                        ',
'     case 6: // tblAdd                                               ',
'       a = a+t.a;                                                    ',
'       break;                                                        ',
'     case 7: // tblSub                                               ',
'       a = a-t.a;                                                    ',
'       break;                                                        ',
'     case 8: // tblInterpolate                                       ',
'       a = mix(a, t.a, uFactor);                                     ',
'       break;                                                        ',
'   }                                                                 ',
'   fragColor = vec4(c.r, c.g, c.b, a);                               ',
'   //fragColor = vec4(1.0, 1.0, 0.5, 1.0);                               ',
' }                                                                   ');


procedure CreateShader;
 var
  vsh,fsh,len,i:integer;
  str:PAnsiChar;
  res:GLInt;
  code:String8;
 function GetShaderError(shader:GLuint):string;
  var
   maxlen:integer;
   errorLog:PAnsiChar;
  begin
   glGetShaderiv(shader,GL_INFO_LOG_LENGTH,@maxlen);
   errorLog:=AnsiStrAlloc(maxlen);
   glGetShaderInfoLog(shader,maxLen,@maxLen,errorLog);
   glDeleteShader(shader);
   result:=errorLog;
  end;
 begin
  vsh:=glCreateShader(GL_VERTEX_SHADER);
  code:='';
  for i:=1 to high(vShader) do code:=code+vShader[i]+#13#10;
  str:=PAnsiChar(code);
  len:=length(code);
  glShaderSource(vsh,1,@str,@len);
  glCompileShader(vsh);
  glGetShaderiv(vsh,GL_COMPILE_STATUS,@res);
  if res=0 then raise EError.Create('VShader compilation failed: '+GetShaderError(vsh));

  // Fragment shader
  fsh:=glCreateShader(GL_FRAGMENT_SHADER);
  code:='';
  for i:=1 to high(fShader) do code:=code+fShader[i]+#13#10;
  str:=PAnsiChar(code);
  len:=length(code);
  glShaderSource(fsh,1,@str,@len);
  glCompileShader(fsh);
  glGetShaderiv(fsh,GL_COMPILE_STATUS,@res);
  if res=0 then raise EError.Create('FShader compilation failed: '+GetShaderError(fsh));

  // Build program object
  shader:=glCreateProgram;
  glAttachShader(shader,vsh);
  glAttachShader(shader,fsh);
  glLinkProgram(shader);
  glGetProgramiv(shader,GL_LINK_STATUS,@res);
  if res=0 then raise EError.Create('Shader program not linked!');
 end;

procedure CreateTexture;
 var
  data:array of cardinal;
  i,j:integer;
 begin
  SetLength(data,128*128);
  for i:=0 to 127 do
   for j:=0 to 127 do
    data[i*128+j]:=$000A000+((i*2) xor (j*2))+(i*2) shl 24;

  glGenTextures(1,@tex);
  glBindTexture(GL_TEXTURE_2D,tex);

  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,128,128,0,GL_BGRA,GL_UNSIGNED_BYTE,@data[0]);

 end;

procedure Prepare;
 begin
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
  glDisable(GL_SCISSOR_TEST);
  glDisable(GL_CULL_FACE);
  glDisable(GL_DEPTH_TEST);
  //glFrontFace(GL_CCW);

  CreateShader;
  CreateTexture;
 end;

procedure SetProjection;
 var
  m:T3DMatrix;
  ms:T3DMatrixS;
  loc:integer;
  w,h:integer;
 begin
  systemPlatform.GetWindowSize(w,h);
  //glViewport(0,0,w,h);
  //glScissor(0,0,w,h);

  m[0,0]:=2/w;  m[1,0]:=0; m[2,0]:=0; m[3,0]:=-1+1/w;
  m[0,1]:=0;  m[1,1]:=-2/h; m[2,1]:=0; m[3,1]:=(1-1/h);
  m[0,2]:=0;  m[1,2]:=0; m[2,2]:=-1; m[3,2]:=0;
  m[0,3]:=0;  m[1,3]:=0; m[2,3]:=0; m[3,3]:=1;
  loc:=glGetUniformLocation(shader,'MVP');
  ms:=Matrix4s(m);
  glUniformMatrix4fv(loc,1,false,@ms);
 end;

procedure DrawFrame;
 var
  m:T3DMatrix;
  loc:integer;
  vertices:array[0..5] of TVertex;
  i,j:integer;
 begin
  // Clear backbuffer
  glClearColor(0.1,0.2,0.3,1.0);
  glClearDepth(1.0);
  glClear(GL_COLOR_BUFFER_BIT+GL_DEPTH_BUFFER_BIT);

  // Setup
  glUseProgram(shader);
  SetProjection;

  loc:=glGetUniformLocation(shader,'colorOp');
  glUniform1i(loc,5);
  loc:=glGetUniformLocation(shader,'alphaOp');
  glUniform1i(loc,4);

  loc:=glGetUniformLocation(shader,'tex');
  glUniform1i(loc,0); // Map texture unit 0 to the texture sampler "tex"

  // Source
  vertices[0].Init( 10, 10,0, 0,0, $FEFF4040);
  vertices[1].Init(390, 10,0, 1,0, $FEFFFF40);
  vertices[2].Init(390,290,0, 1,1, $FEFF4040);
  vertices[3].Init( 10,290,0, 0,1, $FEFF4040);

  // Draw
  glEnableVertexAttribArray(0);
  glEnableVertexAttribArray(1);
  glEnableVertexAttribArray(2);

  glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,sizeof(TVertex),@vertices[0]); // position
  glVertexAttribPointer(1,4,GL_UNSIGNED_BYTE,GL_TRUE,sizeof(TVertex),@vertices[0].color); // color
  glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,sizeof(TVertex),@vertices[0].u); // texcoord

  glLineWidth(3);
  //glDrawArrays(GL_LINE_LOOP,0,4);
  for i:=0 to 249 do begin

   glDrawArrays(GL_TRIANGLE_FAN,0,4);
   for j:=0 to 3 do begin
    vertices[j].x:=vertices[j].x+random(5);
    vertices[j].y:=vertices[j].y+random(5);
    //inc(vertices[j].color,$20304);
   end;
  end;
 end;

begin
  UseLogFile('OpenGL.log');
  SetEventHandler('Engine,Mouse,Kbd,Joystick',EventHandler);
  {$IFDEF MSWINDOWS}
  systemPlatform:=TWindowsPlatform.Create;
  {$ELSE}
  systemPlatform:=TSdlPlatform.Create;
  {$ENDIF}
  gfx:=TOpenGL.Create;
  //game:=TGame.Create(plat,gfx);

  with params do begin
   width:=900;
   height:=700;
   colorDepth:=32;
   mode.displayMode:=dmWindow;
   mode.displayFitMode:=dfmFullSize;
   mode.displayScaleMode:=dsmDontScale;
  end;
  systemPlatform.CreateWindow('Platform Test: '+systemPlatform.GetPlatformName);
  systemPlatform.SetupWindow(params);

  gfx.Init(systemPlatform);

  Prepare;
  repeat
   systemPlatform.ProcessSystemMessages;
   DrawFrame;
   gfx.PresentFrame;
   //sleep(1);
  until systemPlatform.isTerminated;

  gfx.Done;
  systemPlatform.DestroyWindow;
end.
