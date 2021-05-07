//{$DEFINE OPENGL}
{$R-}
program EngineDemo;

uses
  Apus.MyServis,
  Apus.CrossPlatform,
  SysUtils,
  Math,
  Apus.Geom2D,
  Apus.Geom3D,
  Apus.Images,
  Types,
  {$IFDEF OPENGL}
  dglOpenGL,
  {$ENDIF }
  {$IFDEF DIRECTX}
  DirectXGraphics,
  {$ENDIF }
  Apus.EventMan,
  Apus.FastGFX,
  Apus.FreeTypeFont,
  Apus.Engine.API in '..\..\Apus.Engine.API.pas',
  Apus.Engine.UIClasses in '..\..\Apus.Engine.UIClasses.pas',
  Apus.Engine.UIScene in '..\..\Apus.Engine.UIScene.pas',
  Apus.Engine.UIRender in '..\..\Apus.Engine.UIRender.pas',
  Apus.Engine.Tools in '..\..\Apus.Engine.Tools.pas',
  Apus.Engine.Console in '..\..\Apus.Engine.Console.pas',
  Apus.Engine.ConsoleScene in '..\..\Apus.Engine.ConsoleScene.pas',
  Apus.Engine.BitmapStyle in '..\..\Apus.Engine.BitmapStyle.pas',
  Apus.Engine.Networking2 in '..\..\Apus.Engine.Networking2.pas',
  Apus.Engine.IOSgame in '..\..\Apus.Engine.IOSgame.pas',
  Apus.Engine.Game in '..\..\Apus.Engine.Game.pas',
  Apus.Engine.TweakScene in '..\..\Apus.Engine.TweakScene.pas',
  Apus.Engine.Networking3 in '..\..\Apus.Engine.Networking3.pas',
  Apus.Engine.UDict in '..\..\Apus.Engine.UDict.pas',
  Apus.Engine.CustomStyle in '..\..\Apus.Engine.CustomStyle.pas',
  Apus.Engine.Objects in '..\..\Apus.Engine.Objects.pas',
  Apus.Engine.CmdProc in '..\..\Apus.Engine.CmdProc.pas',
  Apus.Engine.ComplexText in '..\..\Apus.Engine.ComplexText.pas',
  {$IFDEF STEAM}
  Apus.Engine.SteamAPI in '..\..\Apus.Engine.SteamAPI.pas',
  {$ENDIF }
  {$IFDEF OPENGL}
  Apus.Engine.OpenGL in '..\..\Apus.Engine.OpenGL.pas',
  Apus.Engine.ResManGL in '..\..\Apus.Engine.ResManGL.pas',
  {$ENDIF }
  {$IFDEF MSWINDOWS}
  Apus.Engine.SoundBass in '..\..\Apus.Engine.SoundBass.pas',
  Apus.Engine.Sound in '..\..\Apus.Engine.Sound.pas',
  Apus.Engine.WindowsPlatform in '..\..\Apus.Engine.WindowsPlatform.pas',
  {$ENDIF }
  {$IFDEF SDL}
  Apus.Engine.SDLplatform in '..\..\Apus.Engine.SDLplatform.pas',
  {$ENDIF }
  Apus.Engine.GameApp in '..\..\Apus.Engine.GameApp.pas',
  Apus.Engine.Model3D in '..\..\Apus.Engine.Model3D.pas',
  Apus.Engine.OBJLoader in '..\..\Apus.Engine.OBJLoader.pas',
  Apus.Engine.SpritePacker in '..\..\Apus.Engine.SpritePacker.pas',
  Apus.Engine.IQMloader in '..\..\Apus.Engine.IQMloader.pas',
  Apus.Engine.ImgLoadQueue in '..\..\Apus.Engine.ImgLoadQueue.pas',
  Apus.Engine.UIScript in '..\..\Apus.Engine.UIScript.pas',
  Apus.Engine.GfxFormats3D in '..\..\Apus.Engine.GfxFormats3D.pas',
  Apus.Engine.ImageTools in '..\..\Apus.Engine.ImageTools.pas',
  Apus.Engine.Draw in '..\..\Apus.Engine.Draw.pas',
  Apus.Engine.Graphics in '..\..\Apus.Engine.Graphics.pas',
  Apus.Engine.TextDraw in '..\..\Apus.Engine.TextDraw.pas',
  Apus.Engine.ShadersGL in '..\..\Apus.Engine.ShadersGL.pas';

const
 wnd:boolean=true;
 makeScreenShot:boolean=false;
 virtualScreen:boolean=false;

 // Номер теста:
 testnum:integer = 3;
 // 1 - initialization, basic primitives
 // 2 - non-textured primitives
 // 3 - textured primitives
 // 4 - multitexturing
 // 5 - render to texture
 // 6 - text (deprecated text API, not compatible with the current "develop" branch!)
 // 7 - clipping
 // 8 - particles
 // 9 - image loading
 // 10 - band particles
 // 11 - basic 3D test
 // 12 - FreeType text (modern text API)
 // 13 - OpenGL shaders (НЕ ДЛЯ GLPAINTER2!)
 // 14 - Video
 // 15 - 3D models with animation

 {
 TexVertFmt=D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR+D3DFVF_TEX1+D3DFVF_TEXTUREFORMAT2;
 ColVertFmt=D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR;
 }

var
 savetime:int64;
 
type
 MyGame=class(TGame)
  function OnFrame:boolean; override;
  procedure RenderFrame; override;
 end;

{ ScrPoint=record
  x,y,z,rhw:single;
  diffuse,specular:cardinal;
  u,v:single;
 end;}
 ScrPoint2=record
  x,y,z,rhw:single;
  diffuse,specular:cardinal;
 end;

 TTest=class
  procedure Init; virtual; abstract;
  procedure RenderFrame; virtual; abstract;
  procedure Done; virtual;
 end;

 TLinesTest=class(TTest)
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TPrimTest=class(TTest)
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TTexturesTest=class(TTest)
  prog:TShader;
  uTex:integer;
  tex1,tex2,tex3,tex4,texA,tex5,tex6,texM,texDuo:TTexture;
  debug:ByteArray;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TTex2Test=class(TTest)
  tex1,tex2,tex3:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TR2TextureTest=class(TTest)
  tex1,tex2,tex3,tex4,tex0:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TFontTest=class(TTest)
  fnt:integer;
  texA:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TFontTest2=class(TTest)
  font:TFreeTypeFont;
  buf:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
 end;

 TToolsTest=class(TTest)
  tex1,tex2,tex3,tex4,tex5:TTexture;
  t1,t2,t3,t4:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TClipTest=class(TTest)
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TParticlesTest=class(TTest)
  tex,tex2:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TBandTest=class(TTest)
  tex:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 T3DTest=class(TTest)
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TShaderTest=class(TTest)
  prog:TShader;
  tex:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TVideoTest=class(TTest)
  tex:TTexture;
  vlc,mp,media:pointer;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 T3DCharacterTest=class(TTest)
  model,modelObj:TModel3D;
  vertices,vertices2:array of T3DModelVertex;
  indices,indices2:TIndices;
  shader,shader2:TShader;
  tex:TTexture;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;


var
 frame:integer;
 game:MyGame;
 s:TGameSettings;
 k:boolean;

 test:TTest;

 needBreak:boolean=false;

{ MyGame }

function MyGame.OnFrame;
 begin
  if frame mod 10=0 then
   SetWindowCaption('FPS: '+inttostr(round(game.fps))+
     '  Avg FPS: '+FloatToStrF(1000*frame/(MyTickCount-SaveTime),ffFixed,6,1));
  result:=true;
//  sleep(0);
 end;

procedure MyGame.RenderFrame;
begin
 //painter.ResetTarget;
 test.RenderFrame;
end;

procedure HEvent(event:TEventStr;tag:TTag);
 var
  i,x,y:integer;
  w:^cardinal;
  ptr:^TVertex;
 begin
  ForceLogMessage(inttostr(MyTickCount)+' '+event+' '+inttostr(tag));

  if event='Engine\AfterMainLoop' then begin
   test.done;
  end;

  if event='Engine\BeforeMainLoop' then begin
   // Здесь можно делать инициализацию, требующую наличия девайса и
   // жизненно необходимую ДО отрисовки первого кадра
   test.Init;
  end;

 end;

{ TLinesTest }
procedure TLinesTest.Done;
begin
end;

procedure TLinesTest.Init;
begin
end;

procedure TLinesTest.RenderFrame;
var
 i:integer;
 t:single;
 vrt:array[0..20] of TVertex;
begin
 inc(frame);
 gfx.target.Clear($FF000000+frame and 127,-1,-1);
 gfx.BeginPaint(nil);

 draw.FillRect(410,10,500,100,$40C08079);

 for i:=1 to 10 do begin
  draw.Line(10,10*i,100,10*i,$FFFFFFFF-i*24);
  draw.Line(10*i,10,10*i,100,$FFFFFFFF-(i*24) shl 16);
 end;
 draw.Rect(200-2,100-2,300+2,200+2,$FF00FF00);
 draw.Line(200,100,300,200,$FFFF0000);
 for i:=1 to 4 do begin
  draw.Line(200+i*20,100,300,100+i*20,$FF0000FF);
  draw.Line(200,100+i*20,200+i*20,200,$FF00FFFF);
 end;
 for i:=1 to 5 do begin
  t:=frame/500+i*pi/2.5;
  draw.Line(200+5*cos(t),300+5*sin(t),200+50*cos(t),300+50*sin(t),$FFC0FF00);
 end;
 for i:=1 to frame mod 4+1 do
  draw.Line(i*3,1,i*3,5,$FFFFFFFF);

 for i:=0 to 100 do
  draw.Line(i*4,500,i*4+2,510,$FF80FF00);

 gfx.EndPaint;
end;

{ TTexturesTest }
procedure TTexturesTest.Done;
begin
 FreeImage(tex1);
 FreeImage(tex2);
end;

procedure TTexturesTest.Init;
var
 i,j,r:integer;
 pb:pbyte;
begin
 tex1:=AllocImage(100,100,ipfARGB,0,'test1');
 tex2:=AllocImage(64,64,ipf565,aiTexture,'test2');
 tex3:=AllocImage(64,64,ipfARGB,aiTexture,'test3');
 tex4:=AllocImage(128,128,ipfARGB,aiTexture,'test4');
 texA:=AllocImage(100,100,ipfA8,aiTexture,'testA');
 texM:=AllocImage(128,128,ipfARGB,aiTexture+aiMipMapping,'testMipMap');
 texDuo:=AllocImage(32,32,ipfDuo8,aiTexture,'testDuo');
// tex1:=LoadImageFromFile('test1.tga') as TTexture;
 tex1.Lock;
 for i:=0 to tex1.height-1 do begin
  pb:=tex1.data;
  inc(pb,tex1.pitch*i);
  for j:=0 to tex1.width-1 do begin
{  pb^:=250-i*2; inc(pb);
   pb^:=i*2; inc(pb);
   pb^:=j+100; inc(pb);
   if (i and 7>3) and (j and 7>3) then pb^:=0 else pb^:=255; inc(pb);}
   pb^:=(j and 2)*127;  inc(pb);
   pb^:=(i and 2)*127;  {pb^:=i*2;} inc(pb);
   pb^:=0; inc(pb);
   if (i and 3=1) and (j and 3=1) then pb^:=0
    else pb^:=255;
   pb^:=255;
   inc(pb);
  end;
 end;
 tex1.Unlock;  

 tex2.Lock;
 for i:=0 to tex2.height-1 do begin
  pb:=tex2.data;
  inc(pb,tex2.pitch*i);
  for j:=0 to tex2.width-1 do begin
{   pb^:=i*4; inc(pb);
   pb^:=j; inc(pb);}
   pb^:=(i and 1)*31; inc(pb);
   pb^:=(j and 1)*255; inc(pb);
  end;
 end;
 tex2.Unlock;

 texM.Lock;
 for i:=0 to texM.height-1 do begin
  pb:=texM.data;
  inc(pb,texM.pitch*i);
  for j:=0 to texM.width-1 do begin
   r:=(j and 1)*180;
   pb^:=200; inc(pb);
   pb^:=r; inc(pb);
   pb^:=r; inc(pb);
   pb^:=255; inc(pb);
  end;
 end;
 texM.Unlock;

 tex3.Lock;
 for i:=0 to tex3.height-1 do begin
  pb:=tex3.data;
  inc(pb,tex3.pitch*i);
  for j:=0 to tex3.width-1 do begin
   pb^:=j*4; inc(pb);
   pb^:=128; inc(pb);
   pb^:=j*4; inc(pb);
   pb^:=i*4; inc(pb);
  end;
 end;
 tex3.Unlock;
// texman.MakeOnline(tex1);

// tex4.Lock(0,lmReadWrite,r);

 // Multipart upload
 tex4.Lock(0,lmCustomUpdate);
 for i:=1 to 10 do begin
  FillRect(tex4.data,tex4.pitch,i*10,30,i*10+7,100,$FF208000+i*20);
  tex4.AddDirtyRect(Rect(i*10,30,i*10+7,100));
 end;
 tex4.Unlock;

 texA.Lock;
 for i:=0 to 99 do begin
  pb:=texA.data;
  inc(pb,texA.pitch*i);
  for j:=0 to 99 do begin
   r:=round(sqrt(sqr(i-50)+sqr(j-50)));
   if r>48 then pb^:=0
    else pb^:=r*5;
   inc(pb);
  end;
 end;
 texA.Unlock;
 tex5:=CreateSubImage(tex1,0,0,35,36,0);
 tex6:=CreateSubImage(tex1,0,0,36,35,0);

 texDuo.Lock;
 for i:=0 to 31 do begin
  pb:=texDuo.data;
  inc(pb,texDuo.pitch*i);
  for j:=0 to 31 do begin
   pb^:=i*4;
   inc(pb);
   pb^:=j*4;
   inc(pb);
  end;
 end;
 texDuo.Unlock;

 try
 prog:=gfx.shader.Build(
  'attribute vec3 aPosition;                              '+
  'attribute vec2 aTexcoord;                              '+
  'varying vec2 vTexcoord;                                '+
  'void main()                                        '+
  '{                                                      '+
  '    vTexcoord = aTexcoord;                             '+
  '    gl_Position=vec4(aPosition,1.0);                   '+
  '}',

  'uniform sampler2D u_Texture;                           '+
  'varying vec2 vTexcoord;                                '+
  'void main()                                        '+
  '{                                                      '+
//  '    gl_FragColor = vec4(vTexcoord.s,vTexcoord.t,0.0,1.0);                   '+
  '    gl_FragColor =  texture2D(u_Texture, vTexcoord);                   '+
  '}',
  'aPosition,aTexcoord');

 except
  on e:exception do ErrorMessage(e.message);
 end;
end;

var
 globalS:double;

procedure Shader1(var vertex:TVertex);
begin
 with vertex do begin
  x:=x+3*sin(globalS+y*0.18)-0.1*y;
  y:=y+3*cos(globalS+x*0.3);
 end; 
end;

procedure TTexturesTest.RenderFrame;
var
 vrt:array[0..3] of TVertex;
 tex:TTexture;
 l1,l2:TMultiTexLayer;
 v,s:single;
 x,y,i,t:integer;
 r:TRect;
 mesh:TMesh;
 vertices,transformed:TVertices;
 indices:TIndices;
 data:array of cardinal;
 sub:TTexture;
begin
// sleep(10);
 inc(frame);
 gfx.target.Clear($FF000040,-1,-1);
 gfx.BeginPaint(nil);
// LogMessage('Frame '+inttostr(frame));
 tex:=tex1;

 // custom debug code
// texman.MakeOnline(tex);
(* glEnable(GL_TEXTURE_2D);
 glUseProgram(prog);
 glActiveTexture(GL_TEXTURE0);
 glBindTexture(GL_TEXTURE_2D,TGLTexture(tex).texname);
 glUniform1i(glGetUniformLocation(prog,'u_Texture'),0);
{ SetLength(data,1000);
 for i:=0 to high(data) do data[i]:=$FF000000+i*1829;
 glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,10,10,0,GL_RGBA,GL_UNSIGNED_BYTE,@data[0]);}

 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );

 glEnableVertexAttribArray(0);
 glEnableVertexAttribArray(1);
 glVertexAttribPointer(0,3,GL_FLOAT,false,SizeOf(vrt[0]),@vrt[0].x);
 glVertexAttribPointer(1,2,GL_FLOAT,false,SizeOf(vrt[0]),@vrt[0].u);
 glDisableVertexAttribArray(2);

 vrt[0].x:=0.1; vrt[0].y:=0.1; vrt[0].z:=0; 
 vrt[0].u:=0;  vrt[0].v:=0;

 vrt[1].x:=0.4; vrt[1].y:=0.1; vrt[1].z:=0;
 vrt[1].u:=1;   vrt[1].v:=0;

 vrt[2].x:=0.1; vrt[2].y:=0.5; vrt[2].z:=0;
 vrt[2].u:=0;   vrt[2].v:=1;

 glDrawArrays(GL_TRIANGLES,0,3);     *)

 draw.Image(1,1,tex1,$FF808080);
 draw.Scaled(200,100,350,250,tex1,$FF808080);
 draw.Scaled(200,300,299,399,tex1,$FF808080);

 x:=frame mod 100;
 r:=Rect(x,10,x+10,20);
 tex4.Lock(0,lmReadWrite,@r);
 FilLRect(tex4.data,tex4.pitch,0,0,11,11,$FF0050C0+(frame mod 256) shl 16);
 tex4.Unlock;
 draw.Image(800,10,tex4);

 sub:=tex1.ClonePart(Rect(2,0,12,10));
 tex1.SetFilter(false);
 draw.Scaled(200,0,260,40,sub);
 tex1.SetFilter(true);
 draw.Scaled(300,0,360,40,sub);
 sub.Free;

 draw.ImagePart90(200,60,tex1,$FF808080,Rect(2,2,20,10),-1);
 draw.ImagePart90(230,60,tex1,$FF808080,Rect(2,2,20,10),1);
 draw.ImagePart90(260,60,tex1,$FF808080,Rect(2,2,20,10),2);
 draw.ImagePart90(290,60,tex1,$FF808080,Rect(2,2,20,10),3);
 draw.RotScaled(450,200,2,2,1,tex2,$FF808080);


 s:=0.2+(MyTickCount mod 3000)/3000;
 texM.SetFilter(true);
 draw.RotScaled(450,420,s,s,0,texM);

 if (frame div 100) and 1=0 then
 tex2.SetFilter(false);
 draw.RotScaled(750,300,4,4,1,tex2,$FF808080);

 draw.Rect(200-1,100-1,350+1,250+1,$FFFFFF80);
 draw.Rect(100-2,200-2,107+2,207+2,$FFFFFFFF);
 draw.Image(10,200,tex2,$FF808080);
 draw.ImagePart(100,200,tex2,$FF808080,Rect(8,8,15,15));
 v:=1+0.5*sin(frame/35);
 draw.RotScaled(200,500,v,v,frame/100,tex1,$FF808080);
 draw.RotScaled(200,700,1,1,frame/300,tex1,$FF808080,0.2, 0);
 draw.Image(400,10,tex3);

 s:=(MyTickCount mod 100000)/2000;
 v:=2*frac(s);
 if v>1 then v:=1;
 s:=(2*s-v)*Pi/2;
 draw.FillRect(650-19,30-19,650+19,30+19,$FFC0A020);
 draw.FillRect(700-19,30-19,700+19,30+19,$FFC0A020);
 draw.RotScaled(650,30,1,1,s,tex5,$FF808080);
 draw.RotScaled(700,30,1,1,s,tex6,$FF808080);


 draw.Image(800,160,texA,$FFFF6000);
 draw.Image(900,160,texA,$FF008000);

 draw.Image(600,700,texDuo,$FF808080);

 with vrt[0] do begin
  x:=600; y:=10; z:=0;
  color:=$FF808080;
  u:=0; v:=0;
 end;
 with vrt[1] do begin
  x:=750; y:=20; z:=0;
  color:=$FF808080;
  u:=1; v:=0;
 end;
 with vrt[2] do begin
  x:=730; y:=250; z:=0;
  color:=$FF008000;
  u:=1; v:=1;
 end;

 mesh:=BuildMeshForImage(tex1,32,32);
 globalS:=MyTickCount/200;
 mesh.vertices:=TransformVertices(mesh.vertices,shader1);
{ for i:=0 to length(vertices)-1 do
  with vertices[i] do begin
   //ou:=x/tex1.width; ov:=y/tex1.height;
   x:=x+3*sin(s+y*0.18)-0.1*y;
   y:=y+3*cos(s+x*0.3);
  end;}
// v:=1.1+0.3*sin(getTickCount/200);
 v:=1.5;
 Set2DTransform(800,600,v,v);
{ if getTickCount mod 1000<500 then
  draw.Image(0,0,tex1)
 else}
 DrawIndexedMesh(mesh.vertices,mesh.indices,tex1);
 Reset2DTransform;
 //(painter as TDXPainter8).DrawTrgListTex(@vrt,1,tex2);

{ l1.texture:=tex1;
 l2.texture:=tex3;
 l1.matrix[0,0]:=1; l1.matrix[0,1]:=0;
 l1.matrix[1,0]:=0; l1.matrix[1,1]:=1;
 l1.matrix[2,0]:=0; l1.matrix[2,1]:=0;
 l2.matrix:=l1.matrix;
 x:=600; y:=400;
 gfx.shader.TexMode(0,tblModulate2X,tblModulate,fltBilinear);
 gfx.shader.TexMode(1,tblModulate,tblKeep,fltUndefined);
 draw.MultiTex(x,y,x+150,y+150,@l1,@l2,nil,$FF808080);

 draw.SetTexInterpolationMode(1,tintFactor,0.5+sin(gettickcount/300)/2);
 gfx.shader.TexMode(1,tblInterpolate,tblKeep,fltBilinear);
 x:=760;
 draw.MultiTex(x,y,x+150,y+150,@l1,@l2,nil,$FF808080);  }

// draw.Update;
 gfx.EndPaint;
end;

{ TPrimTest }

procedure TPrimTest.Done;
begin
end;

procedure TPrimTest.Init;
begin
end;

procedure TPrimTest.RenderFrame;
var
 pnts:array[0..40] of TPoint2;
 i:integer;
 a,r:single;
begin
 inc(frame);
// if frame>3 then exit;
 gfx.target.Clear($FF000000+(frame div 4) and 127,-1,-1);
 gfx.BeginPaint(nil);
 draw.FillRect(1,1,30,30,$FF80FF00);
 draw.FillRect(40,1,70,30,$80FFFFFF);
 draw.FillGradrect(100,100,140,140,$FF0000FF,$FFFF0000,true);
 draw.FillGradrect(150,100,190,140,$FF0000FF,$FFFF0000,false);
 draw.FillGradrect(100,150,140,190,$FFFFFF00,$0FFFFF00,true);
 draw.FillGradrect(150,150,190,190,$FFFFFF00,$0FFFFF00,false);

 draw.ShadedRect(300,50,400,90,3,$FFC0C0C0,$FF808080);
 draw.ShadedRect(300,100,400,130,1,$FFC0C0C0,$FF808080);

 for i:=0 to 4 do begin
  a:=frame/50;
  pnts[i].x:=250+30*cos(a+i);
  pnts[i].y:=250+30*sin(a+i);
 end;
 draw.Polygon(@pnts,5,$FFFF8000);

 for i:=0 to 14 do begin
  a:=i*0.42;
  r:=40+20*sin(i*1.7)+10*sin(4+i*0.6);
  pnts[i].x:=450+r*cos(a);
  pnts[i].y:=250+r*sin(a);
 end;
 draw.Polygon(@pnts,15,$FF0080C0);

 draw.RRect(50,250,100,270,$FFF0C0A0,3);
 draw.FillTriangle(50,320,100,300,80,380,$10FF3030,$FF30FF30,$FF3030FF);


 draw.Rect(0,0,1023,767,$FFFFFF30);
 gfx.EndPaint;
end;

{ TFontTest }

procedure TFontTest.Done;
begin
// draw.FreeFont(fnt);
end;

procedure TFontTest.Init;
var
 font:cardinal;
begin
{ draw.LoadFont('res\times1.fnt');
 draw.LoadFont('res\times2.fnt');
 draw.LoadFont('res\times3.fnt');
 draw.LoadFont('res\goodfish1.fnt');
 draw.LoadFont('res\goodfish2.fnt');
 //fnt:=draw.LoadFromFile('test');
 LoadRasterFont('res\test.fnt');
 fnt:=draw.PrepareFont(1);}
 font:=txt.GetFont('Times New Roman',12);
 txt.SetFontOption(font,foDownscaleFactor,1);
 txt.SetFontOption(font,foUpscaleFactor,1);
 font:=txt.GetFont('Times New Roman',9);
 txt.SetFontOption(font,foDownscaleFactor,1);
 txt.SetFontOption(font,foUpscaleFactor,1);
end;

procedure TFontTest.RenderFrame;
var
 i:integer;
 handle,color:cardinal;
 size:single;
begin
// if frame>0 then exit;
 inc(frame);
 gfx.target.Clear($FF000080 { $ FF000000+frame and 127},-1,-1);
 gfx.BeginPaint(nil);
 // Unicode text output

 handle:=txt.GetFont('Times New Roman',10);
 txt.Write(handle,200+(getTickCount div 300) mod 40,60,$FFFFF0A0,'Water Elemental',taRight);
// color:=$FFF0A0A0+$100*round(40*sin(frame*0.01))+round(40*(frame*0.02));

 // Нагрузка на кэш
{ handle:=txt.GetFont('Times New Roman',20);
 txt.Write(handle,10,540,$FFE0E0FF,chr(33+frame mod 210));
 handle:=txt.GetFont('Times New Roman',15);
 txt.Write(handle,50,540,$FFE0E0FF,chr(33+frame mod 210));
 handle:=txt.GetFont('Goodfish',12);
 txt.Write(handle,90,540,$FFE0E0FF,chr(33+frame mod 100));}

 color:=$FFFFF0A0;
 for i:=1 to 8 do begin
  draw.FillRect(580-round(19.7*(9+i*0.6)),72+i*68,
                   580+round(19.7*(9+i*0.6)),122+i*68,$FF404090);
  handle:=txt.GetFont('Times New Roman',9+i*0.6);
  txt.Write(handle,580,90+i*68,color,'Hello Kitty!® Première l''écriture! $27 = €34',taCenter);
  txt.Write(handle,580,115+i*68,color,'Нам не страшен враг любой, Лукашенко - наш герой! ©',taCenter);
 end;

 size:=Pike((frame div 10) mod 255,128,200,350,200)/200;
 size:=8*sqr(size);
 handle:=txt.GetFont('Times New Roman',size);
 txt.Write(handle,520,722,color,'Hello Kitty!® Première l''écriture! $27 = €34',taCenter);
 txt.Write(handle,520,750,color,'Нам не страшен враг любой, Лукашенко - наш герой! ©',taCenter);

 // Show text cache texture
// txt.Write(0,0,0,0,'');

 txt.Write(1,10,690,$FFFFFF40,'Hello World! Привет всем! Première tentative de l''écriture!');

 // Legacy text output
{ draw.SetFont(fnt);
 draw.WriteSimple(10,10,$FFFFFFFF,'Hello');
 for i:=20 downto 4 do begin
  draw.FillRect(9,i*20+2,10+i*8,i*20+20,$C0404090);
  draw.WriteSimple(10,i*20,$FFFFFF00+i*12-(i*12) shl 16,copy('я 12345678901234567890',1,i));
 end;

 draw.FillRect(500,10,640,50,$FF8080F0);
 draw.FillRect(500,70,640,120,$FF000064);
 draw.Line(500,30,640,30,$FF000000);
 draw.Line(500,75,640,75,$50FFFFFF);
 draw.Line(500,90,640,90,$80FFFFFF);
 draw.Line(500,103,640,103,$50FFFFFF);
 draw.Line(570,10,570,110,$50FFFFFF);
 draw.Line(524,10,524,110,$50FFFFFF);
 draw.Line(616,10,616,110,$50FFFFFF);
 fillchar(draw.textEffects,sizeof(draw.textEffects),0);
 with painter do begin
  textEffects[1].enabled:=true;
  textEffects[1].blur:=1;
  textEffects[1].color:=$F0000000;
  textEffects[1].dx:=0;
  textEffects[1].dy:=2;
//  WriteEx(510,16,$FFF0C020,'Hello WORLD');
  WriteEx(570,16,$FFF0C020,'Hello Привет',taCenter);

  textEffects[1].enabled:=true;
  textEffects[1].blur:=1.5;
  textEffects[1].fastblurX:=0;
  textEffects[1].fastblurY:=4;
  textEffects[1].color:=$FFFFFF00;
  textEffects[1].dx:=0;
  textEffects[1].dy:=0;
  textEffects[1].power:=3;
  WriteEx(570,80,$FF500000,'Тест блура!',taCenter);
 end; }

// draw.FillRect(0,0,511,511,$FFFFFFFF);
{ if frame mod 40<10 then
  txt.Write(MAGIC_TEXTCACHE,0,0,$FFFFFFFF,'');}

 gfx.EndPaint;
end;

procedure TFontTest2.Init;
begin
 //font:=TFreeTypeFont.LoadFromFile('res\arial.ttf');
// font:=TFreeTypeFont.LoadFromFile('12460.ttf');
 buf:=AllocImage(400,50,ipfARGB,0,'txtbuf');
 txt.LoadFont('res\arial.ttf');
end;

procedure TFontTest2.RenderFrame;
const
 words:array[0..2] of string=('Alpha','beta','gamma');
var
 i,w,h:integer;
 f,handle,color:cardinal;
 size:single;
 st:string;
begin
// if frame>0 then exit;
 inc(frame);
 gfx.target.Clear($FF000080 { $ FF000000+frame and 127},-1,-1);
 gfx.BeginPaint(nil);
 // Unicode text output

 f:=txt.GetFont('Arial',30);
 txt.WriteW(f,10,40,$FFFFA080,'Première tentative de l''écriture!',taLeft);
 f:=txt.GetFont('Arial',24);
 txt.WriteW(f,10,80,$FFFFA080,'Кракозябры! אַﭠﮚﻼ№җ£©α²',taLeft);
 txt.WriteW(f,10,115,$FFFFA080,'Кракозябры!',taLeft,toItalic);

 f:=txt.GetFont('Arial',14,toDontTranslate);
 w:=txt.WidthW(f,'1) AV Привет - Hello!');
 h:=txt.Height(f);
 draw.FillRect(10,260-h-2,10+w,260+1,$FFC0C0C0);
 txt.BeginBlock;
 txt.WriteW(f,10,200,$FFFFA080,'1) AV Привет - Hello!',taLeft);
 txt.WriteW(f,10,230,$FFFFFFFF,'1) AV Привет - Hello!',taLeft);
 txt.WriteW(f,10,260,$FF000000,'1) AV Привет - Hello!',taLeft);
 txt.EndBlock;

 for i:=1 to 20 do
  txt.Write(f,10,270+i*20,$FFFFFFFF,'Line '+IntToStr(i),taLeft);

 f:=txt.GetFont('Arial',12,toDontTranslate);
 txt.WriteW(f,220,160,$FFE0E0E0,'Hinting mode: DEFAULT');
 txt.WriteW(f,220,180,$FFE0E0E0,'Hinting mode: OFF',taLeft,toNoHinting);
 txt.WriteW(f,220,200,$FFE0E0E0,'Hinting mode: AUTO',taLeft,toAutoHinting);
 txt.WriteW(f,220,220,$FFE0E0E0,'Hinting mode: AUTO',taLeft,toAutoHinting+toItalic);
 txt.WriteW(f,220,240,$FFE0E0E0,'Text mode: BOLD',taLeft,toBold);
 txt.WriteW(f,220,260,$FFE0E0E0,'Text mode: Bold Italic',taLeft,toItalic+toBold);
 txt.WriteW(f,220,280,$FFE0E0F0,'Mode: underlined',taLeft,toUnderline);
 txt.WriteW(f,220,300,$FFE0E0F0,'Measure {b}complex{/b} text',taLeft,toMeasure+toComplexText);
 for i:=0 to txt.MeasuredCnt do
  with txt.MeasuredRect(i) do
   draw.Line(left,bottom,left,bottom+5,$90FFFFFF);
   
 curTextLink:=0;
 txt.WriteW(f,220,330,$FFE0E0F0,'Text with a {L=01}link{/L}!',taLeft,toMeasure+toComplexText,0,
   game.mouseX and $FFFF+game.mouseY shl 16);

{ buf.Lock;
 FillRect(buf.data,buf.pitch,0,0,buf.width-1,buf.height-1,$FFE0E0E0);
 FillRect(buf.data,buf.pitch,0,30,buf.width-1,30,$FFA0A0A0);
 font.RenderText(buf.data,buf.pitch,5,30,'1) AV Привет - Hello!',$FF400000,20+8*sin(frame/100));
 buf.Unlock;
 draw.Image(10,10,buf);}

 f:=txt.GetFont('Arial',14,toDontTranslate);

 txt.Write(f,220,760,$FF6FF000,EncodeUTF8('Привет! @^#(!''"/n ( {C=FFE08080}1010{/C} / 700 )'),taLeft,toComplexText);

// draw.BeginTextBlock;
 for i:=1 to 10 do
  txt.WriteW(f,220,760-i*25,$FF6FF000,
    '{u}This{!u} {I}is {!I}an{/i/i} {u}example {C=FF90E0C0}of {B}complex{/B/C/u} text',taLeft,toComplexText);
// draw.EndTextBlock;
// txt.WriteW(f,220,725,$FFFF0000,'This {B}is {!B}an{/b/b} example {C=FFC0E090}of complex{/C} text',taLeft);
// txt.WriteW(f,220,750,$FFFF0000,'This {B}is {!B}an{/b/b} example {C=FFC0E090}of complex{/C} text',taLeft);

 txt.WriteW(f,150,710,$FFC0C0C0,IntToStr(intervalHashMiss));
 txt.WriteW(f,150,730,$FFC0C0C0,IntToStr(glyphWidthHashMiss));
 txt.WriteW(f,150,750,$FFC0C0C0,IntToStr(frame));

 draw.Line(700,672,700,730,$80FFFF50);
 draw.FillRect(700-28,670,700+28,690,$60000000);
 txt.WriteW(f,700,690,$FFC0C0C0,'Center',taCenter);
 txt.WriteW(f,700,720,$FFC0C0C0,'Right',taRight);
 draw.FillRect(600,732,600+290,757,$60000000);
 txt.WriteW(f,600,750,$FFC0C0C0,'Justify {i}this{/i} {u}simple and small{/u} text',
   taJustify,toComplexText,290);

 i:=(MyTickCount div 1000);
 st:=words[i mod 3]+#13#10+words[(i+1) mod 3]+#13#10+words[(i+2) mod 3];
 w:=txt.Width(f,st);
 draw.Rect(120,320,120+w,400,$60FFFFFF);
 txt.WriteW(f,120,340,$FFC0C0C0,st);

 if getTickCount mod 1200<800 then begin
  draw.FillRect(512,0,1023,511,$FFFFFFFF);
  txt.Write(MAGIC_TEXTCACHE,512,0,$FFFFFFFF,'');
 end;
 gfx.EndPaint;
end;


{ TR2TextureTest }

procedure TR2TextureTest.Done;
begin
 FreeImage(tex1);
 FreeImage(tex2);
end;

procedure TR2TextureTest.Init;
var
 i,j:integer;
 pb:PByte;
begin
 tex0:=AllocImage(50,30,ipfARGB,0,'test0');
 tex1:=AllocImage(100,100,ipfARGB,0,'test1');
 tex2:=AllocImage(256,256,ipf565,aiTexture+aiRenderTarget,'test2');
 tex3:=AllocImage(128,128,ipfARGB,aiTexture+aiRenderTarget,'test3');
 tex4:=AllocImage(90,100,ipfARGB,aiTexture+aiRenderTarget,'test4');
 tex0.Lock;
 for i:=0 to tex0.height-1 do begin
  pb:=tex0.data;
  inc(pb,tex0.pitch*i);
  for j:=0 to tex0.width-1 do begin
   pb^:=0; inc(pb);
   pb^:=i*30 mod 200; inc(pb);
   pb^:=180-abs((j-25)*6); inc(pb);
   pb^:=255; inc(pb);
  end;
 end;
 tex0.Unlock;

 tex1.Lock;
 for i:=0 to tex1.height-1 do begin
  pb:=tex1.data;
  inc(pb,tex1.pitch*i);
  for j:=0 to tex1.width-1 do begin
   pb^:=250-i*2; inc(pb);
   pb^:=i*2; inc(pb);
   pb^:=j+100; inc(pb);
   if (i and 7>2) and (j and 7>2) then pb^:=0 else pb^:=255; inc(pb);
  end;
 end;
 tex1.Unlock;
end;

procedure TR2TextureTest.RenderFrame;
begin
// sleep(500);
 inc(frame);

 gfx.BeginPaint(tex2);
 gfx.target.Clear($80FF80,-1,-1);
 draw.FillGradrect(4,4,255-4,255-4,$FF000000+round(120+120*sin(frame/400)),$FF000000+round(120+120*sin(1+frame/300)),true);
 draw.Image(20,20,tex1);

{ gfx.shader.TexMode(0,tblAdd,tblKeep);
 draw.Image(140,30,tex0);}
 // Fixed! неправильный цвет при первой отрисовке!
{ gfx.shader.TexMode(1,tblReplace,tblReplace);
 draw.Double(140,30,tex1,tex0);}
 // Fixed! Прыгает в другое место со 2-го кадра
{ gfx.shader.TexMode(1,tblModulate2x,tblModulate,fltBilinear);
 draw.Double(140,30,tex1,tex0);}
 //
 gfx.shader.TexMode(1,tblInterpolate,tblInterpolate,fltUndefined,0.5);
 draw.DoubleTex(140,30,tex1,tex0);

 gfx.EndPaint;

 gfx.BeginPaint(tex3);
 gfx.target.Clear(0,-1,-1);
 draw.FillRect(25,25,120,80,$FFE00000);
 draw.Image(1,1,tex1,$FF808080);
 draw.Image(50,50,tex1,$FF808080);
 draw.Rect(0,0,127,127,$FFFFFFFF);
 gfx.EndPaint;

 gfx.BeginPaint(tex4);
 gfx.target.Clear(0,-1,-1);
 draw.FillRect(0,0,70,60,$FFFFFFE0);
{ device.SetRenderState(D3DRS_ZENABLE,0);
 device.SetRenderState(D3DRS_COLORWRITEENABLE,15);
 device.SetRenderState(D3DRS_ALPHABLENDENABLE,1);
 device.SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_ADD);
 device.SetRenderState(D3DRS_SRCBLEND,D3DBLEND_SRCALPHA);
 device.SetRenderState(D3DRS_DESTBLEND,D3DBLEND_INVSRCALPHA);}
 draw.Image(40,40,tex1,$FF808080);
// device.SetRenderState(D3DRS_COLORWRITEENABLE,15);
// draw.Image(-20,15,tex1,$FF808080);
 gfx.EndPaint;
 gfx.Restore;

 gfx.BeginPaint(nil);
 gfx.target.Clear($FF000000+(frame div 2) and 127,-1,-1);
 draw.Rect(10,10,450,350,$FF00C000);
 draw.Image(140,400,tex0,$FF808080);
 draw.Image(4,300,tex3,$FF808080);
 draw.Image(4,4,tex2,$FF808080);
 draw.Image(10,500,tex4,$FF808080);
 draw.Scaled(400+round(80*sin(1+frame/200)),200+round(80*sin(frame/300)),
                    600+round(80*sin(frame/240)),400+round(2+80*sin(frame/250)),tex2,$FF808080);
 gfx.EndPaint;
end;

{ TToolsTest }

procedure TToolsTest.Done;
begin
 FreeImage(tex1);
end;

procedure TToolsTest.Init;
var
 f:single;
 c:cardinal absolute f;
 i:integer;
begin
// LoadRasterFont('test.fnt');
// SetTXTFonts(1,1);
 tex5:=LoadImageFromFile('res\testA');
 tex1:=LoadImageFromFile('res\image.tga',liffMH256);
 tex2:=LoadImageFromFile('res\image.dds');
 tex3:=LoadImageFromFile('res\test3');
 tex4:=LoadImageFromFile('res\logo');
 //tex1:=LoadTexture('circle',0);
{ gfx.shader.TexMode(fltTrilinear);
 f:=0.5;
 device.SetTextureStageState(0,D3DTSS_MIPMAPLODBIAS,c);}
 t1:=AllocImage(40,40,ipfARGB,0,'t1');
 t1.Lock;
 FillRect(t1.data,t1.pitch,0,0,39,39,$FF502060);
 for i:=0 to 9 do begin
  FillRect(t1.data,t1.pitch,i*4,0,i*4,39,$FFC0FF00);
  FillRect(t1.data,t1.pitch,0,i*4,39,i*4,$FFFF3000);
 end;
 t1.Unlock;
 t2:=ResampleImage(t1,80,80);
 t3:=ResampleImage(t1,39,39);
 t4:=ResampleImage(t1,-40,-40);
end;

procedure TToolsTest.RenderFrame;
begin
// sleep(10);
 inc(frame);
 gfx.target.Clear($FF000000+frame and 127,-1,-1);
 gfx.BeginPaint(nil);
 draw.Image(0,0,tex4);
// draw.Scaled(10,10,50+100+100*sin(frame/100),50+100+100*sin(frame/100),tex1,$FF808080);
 draw.Image(10{+frame mod 200},10{+frame mod 200},tex1,$FF808080);
 draw.Image(200,20,tex2,$FF808080);
 draw.Image(400,20,tex3);
 draw.Image(200,200,t1);
 draw.Image(300,200,t2);
 draw.Image(200,300,t3);
 draw.Image(300,300,t4);
 draw.Image(100,500,tex5);
 gfx.EndPaint;
end;


{ TTex2Test }

procedure TTex2Test.Done;
begin

end;

procedure TTex2Test.Init;
var
 x,y:integer;
 pc:PCardinal;
 c:cardinal;
 r:single;
begin
 tex1:=AllocImage(100,100,ipfARGB,0,'test1');
 tex2:=AllocImage(113,113,ipfARGB,aiTexture,'test2');
 tex3:=AllocImage(64,64,ipfARGB,aiTexture,'test3');
 // Tex1
 tex1.Lock;
 for y:=0 to tex1.height-1 do begin
  pc:=tex1.data; inc(pc,y*tex1.pitch div 4);
  for x:=0 to tex1.width-1 do begin
   pc^:=$FF000000+(x and 3)*60+(y and 3)*60 shl 8;
   if (x+y) and 15>11 then pc^:=pc^ xor $80000000; // прозрачные полосы
//   pc^:=$FFC08040;
   inc(pc);
  end;
 end;
 tex1.Unlock;

 // Tex2
 tex2.Lock;
 for y:=0 to tex2.height-1 do begin
  pc:=tex2.data; inc(pc,y*tex2.pitch div 4);
  for x:=0 to tex2.width-1 do begin
   c:=$FF505050;
   if x and 7=0 then inc(c,$800000);
   if y and 7=0 then inc(c,$8080);
   pc^:=c;
   inc(pc);
  end;
 end;
 tex2.Unlock;

 // Tex3
 tex3.Lock;
 for y:=0 to tex3.height-1 do begin
  pc:=tex3.data; inc(pc,y*tex3.pitch div 4);
  for x:=0 to tex3.width-1 do begin
   c:=x*4 shl 16+y*4 shl 8;
   r:=14-0.5*sqrt(sqr(x-32)+sqr(y-32));
   c:=c+sat(round(r*255),0,255) shl 24;
   pc^:=c;
   inc(pc);
  end;
 end;
 tex3.Unlock;
end;

procedure TTex2Test.RenderFrame;
var
 s:single;
 t,v:cardinal;
begin
 inc(frame);
 t:=GetTickCount;
 gfx.BeginPaint(nil);
 gfx.target.Clear($FF000040);


 v:=t div 2000;
// if v mod 3=0 then draw.Image(40,40,tex1);
 if true or (v mod 3=1) then begin
  gfx.shader.TexMode(1,tblInterpolate,tblModulate,fltUndefined,(t mod 2000)/2000);
  // плавный переход между двумя текстурами (в две стороны)
  draw.DoubleTex(40,40,tex2,tex1);
  draw.DoubleTex(150,40,tex1,tex2);
  // перемножение двух текстур
  gfx.shader.TexMode(1,tblModulate2X,tblModulate);
  draw.DoubleTex(300,40,tex1,tex2);
 end;
// if v mod 3=2 then draw.Image(40,40,tex2);

{ draw.RotScaled(450,240,1,1,0,tex2);
 draw.RotScaled(580.5,240,1,1,0,tex2);
 draw.RotScaled(450,370.5,1,1,0,tex2);
 draw.RotScaled(580.5,370.5,1,1,0,tex2);}

 // цвет от первой текстуры, альфа - пофигу
 gfx.shader.TexMode(1,tblKeep,tblKeep);
 draw.DoubleRotScaled(470,100,1,1,1,1,0,tex1,tex2);
 // цвет от второй текстуры, альфа - пофигу
 gfx.shader.TexMode(1,tblReplace,tblNone);
 draw.DoubleRotScaled(600,100,1,1,1,1,0,tex1,tex2);

 // цвет от первой текстуры, альфа - от третьей (вырезание круга из первой)
 gfx.shader.TexMode(1,tblKeep,tblReplace);
 draw.DoubleTex(20,190,tex1,tex3);
 // цвет - градиент, альфа - сплошная
 gfx.shader.TexMode(1,tblReplace,tblKeep);
 draw.DoubleTex(100,190,tex1,tex3);
 // цвет - сумма, альфа - круг
 gfx.shader.TexMode(1,tblAdd,tblModulate);
 draw.DoubleTex(180,190,tex1,tex3);
 // интерполяция цвета и альфы
 gfx.shader.TexMode(1,tblInterpolate,tblInterpolate,fltUndefined,0);
 draw.DoubleTex(180+80,190,tex1,tex3);
 gfx.shader.TexMode(1,tblInterpolate,tblInterpolate,fltUndefined,1);
 draw.DoubleTex(180+80*2,190,tex1,tex3);
 gfx.shader.TexMode(1,tblInterpolate,tblReplace,fltUndefined,0.5);
 draw.DoubleTex(180+80*3,190,tex1,tex3);

 gfx.shader.TexMode(1,tblDisable,tblDisable);

 // Текстурирование 1-й текстурой
 // ----------------------------------

 // цвет - фиксированный, альфа - из текстуры
 gfx.shader.TexMode(0,tblKeep,tblModulate);
 // Не работает! Потому что DrawXXX сама вызывает SetTexMode исходя из своих представлений, но только если тип отрисовки изменился с предыдущего вызова 
 draw.Image(20,270,tex3,$FF30A040);
 // цвет из текстуры, альфа - сплошная
 gfx.shader.TexMode(0,tblReplace,tblKeep);
 draw.Image(20+80,270,tex3,$C0202020);
 // цвет и альфа - суммируются
 gfx.shader.TexMode(0,tblAdd,tblAdd);
 draw.Image(20+80*2,270,tex3,$50000080);

 // Возврат стандартного значения
 gfx.shader.DefaultTexMode;

 // Original images
 draw.Image(40,440,tex1);
 draw.Image(210,440,tex2);
 draw.Image(390,440,tex3);

 gfx.EndPaint;
end;

{ TParticlesTest }

procedure TParticlesTest.Done;
begin

end;

procedure TParticlesTest.Init;
var
 i,j,n,x,y,v:integer;
 pb:PByte;
 pc:PCardinal;
begin
 tex:=AllocImage(19*2,19,ipfARGB,0,'particles');
 tex.Lock;
 for i:=0 to tex.height-1 do begin
  pb:=tex.data;
  inc(pb,tex.pitch*i);
  for j:=0 to tex.width-1 do begin
   n:=j div 19;
   x:=(j mod 19-9);
   y:=i-9;
   case n of
    0:begin
       pb^:=50; inc(pb);
       pb^:=130+y*15; inc(pb);
       pb^:=250; inc(pb);
       pb^:=Sat(350-4*(sqr(x)+sqr(y)),0,255); inc(pb);
    end;
    1:begin
       pb^:=100+x*10; inc(pb);
       pb^:=150+x*10; inc(pb);
       pb^:=100+x*10; inc(pb);
       pb^:=Sat(350-4*(sqr(x)+sqr(y)),0,255); inc(pb);
    end;
   end;
  end;
 end;
 tex.Unlock;

 tex2:=AllocImage(16,16,ipfARGB,0,'particles2');
 EditImage(tex2);
 for y:=0 to tex2.height-1 do
  for x:=0 to tex2.width-1 do begin
   pc:=GetPixelAddr(tex2.data,tex2.pitch,x,y);
   v:=round(24*sqrt(sqr(y-8)+sqr(x-8)));
   pc^:=$F08050+Sat(150-v,0,255) shl 24;
  end;
 tex2.Unlock;
end;

procedure TParticlesTest.RenderFrame;
var
 particles:array[1..500] of TParticle;
 i:integer;
begin
 inc(frame);
 gfx.target.Clear($FF000000,-1,-1);
 gfx.BeginPaint(nil);
 draw.Image(10,10,tex,$FF808080);
 draw.Image(50,10,tex2,$FF808080);
 for i:=1 to 500 do with particles[i] do begin
  x:=120*cos(frame/100+i/9);
  y:=120*sin(frame/100+i/9);
  z:=sqr(1+i/200)/2-1.5+1.4*sin(frame/80);
  color:=$FF808080;
  scale:=1;
  angle:=0;
  index:=i mod 2;
 end;
 draw.Particles(500,400,@particles,500,tex,19,3);
 for i:=1 to 50 do with particles[i] do begin
  x:=20*sin(frame/100+i*1.2)+25*cos(frame/130+i*1.04+2);
  y:=20*cos(frame/110+i*1.93)+25*sin(frame/120-i*1.56+4);
  z:=0;
  color:=$FF808080;
  scale:=3.5;
  angle:=0;
  index:=0;
 end;
 gfx.target.BlendMode(blAdd);
 draw.Particles(100,100,@particles,50,tex2,19,1);
 gfx.target.BlendMode(blAlpha);
 gfx.EndPaint;
end;

{ TBandTest }

procedure TBandTest.Done;
begin

end;

procedure TBandTest.Init;
var
 i,j,n,x,y:integer;
 pb:PByte;
begin
 tex:=AllocImage(19*2,19,ipfARGB,0,'particles');
 tex.Lock;
 for i:=0 to tex.height-1 do begin
  pb:=tex.data;
  inc(pb,tex.pitch*i);
  for j:=0 to tex.width-1 do begin
   n:=j div 19;
   x:=(j mod 19-9);
   y:=i-9;
   case n of
    0:begin
       pb^:=100+i*8; inc(pb);
       pb^:=250; inc(pb);
       pb^:=250-i*8; inc(pb);
       pb^:=Sat(Pike(j*14,128,-i*10,200+i*20,-i*10),0,255); inc(pb);
    end;
    1:begin
       pb^:=100+x*10; inc(pb);
       pb^:=150+x*10; inc(pb);
       pb^:=100+x*10; inc(pb);
       pb^:=Sat(350-4*(sqr(x)+sqr(y)),0,255); inc(pb);
    end;
   end;
  end;
 end;
 tex.Unlock;
end;

procedure TBandTest.RenderFrame;
var
 p:array[1..1000] of TParticle;
 i,j,n,c:integer;
 t,r,a:double;
begin
 inc(frame);
 t:=MyTickCount/1000;
 gfx.target.Clear($FF000000,-1,-1);
 gfx.BeginPaint(nil);
 draw.Image(10,10,tex,$FF808080);
 n:=0;
 // Линии
 for i:=1 to 5 do
  for j:=1 to 50 do begin
   inc(n);
   p[n].x:=100+(i*50)+round(20*sin(t*0.6+j/5+i)+10*sin(t*2-j/3));
   p[n].y:=j*10;
   p[n].z:=0;
   p[n].color:=$FF808080;
   p[n].scale:=3+2*sin(t/2+i);
   p[n].angle:=0;
   p[n].index:=(i*3+j div 2) and 15+byte(j=50)*partEndpoint;
  end;
 // кольца
 for i:=1 to 5 do
  for j:=1 to 80 do begin
   inc(n);
   a:=3.1416*j/40;
   r:=100+5*sin(a*7+t+i)-6*sin(a*4-t-i*2);
   p[n].x:=700+r*cos(a);
   p[n].y:=i*150-0.6*r*sin(a)-70;
   p[n].z:=0;
   p[n].color:=$FF808080;
   p[n].scale:=3+2*sin(t/2+i);
   p[n].angle:=0;
   p[n].index:=i*3+byte(j=80)*partLoop;
  end;              
 // окружности
 for i:=1 to 3 do begin
  r:=20+i*20+30*sin(t);
  c:=8+2*round(r/3);
  for j:=1 to c do begin
   inc(n);
   a:=3.1416*2*j/c;
   p[n].x:=220+r*cos(a);
   p[n].y:=640+r*sin(a);
   p[n].z:=0;
   p[n].color:=$FF808080;
   p[n].scale:=2.5;
   p[n].index:=10+partLoop*byte(j=c);
  end;
 end;
 // Квадрат
 inc(n);
 p[n].x:=450; p[n].y:=600; p[n].color:=$FF808080; p[n].scale:=5; p[n].index:=5+partLoop;
 inc(n);
 p[n].x:=520; p[n].y:=600; p[n].color:=$FF808080; p[n].scale:=5; p[n].index:=5;
 inc(n);
 p[n].x:=520; p[n].y:=680; p[n].color:=$FF808080; p[n].scale:=5; p[n].index:=5;
 inc(n);
 p[n].x:=450; p[n].y:=680; p[n].color:=$FF808080; p[n].scale:=5; p[n].index:=5+partLoop;   

 draw.Band(0,0,@p,n,tex,rect(0,0,19,1));
 gfx.EndPaint;
end;

{ TClipTest }

procedure TClipTest.Done;
begin

end;

procedure TClipTest.Init;
begin

end;

procedure TClipTest.RenderFrame;
var
 i,x,y:integer;
 t:single;
begin
 inc(frame);
 gfx.target.Clear($FF000000+frame and 127,-1,-1);
 gfx.BeginPaint(nil);

 draw.Rect(99,99,200,200,$FFF0C080);
 gfx.clip.Rect(Rect(100,100,200,200));
 t:=frame/150;
 x:=150+round(50*cos(t));
 y:=150-round(50*sin(t));
 draw.FillRect(x-20,y-20,x+20,y+20,$FF3080C0);
 gfx.clip.Restore;

 draw.Rect(299,99,400,200,$FF30C080);
 gfx.clip.Rect(Rect(300,100,400,200));
 t:=frame/300;
 x:=350+round(50*cos(t));
 y:=150-round(50*sin(t));
 draw.FillRect(x-20,y-20,x+20,y+20,$FFD0A040);
 gfx.clip.Restore;

 gfx.EndPaint;
end;

{ T3DTest }

procedure T3DTest.Done;
begin

end;

procedure T3DTest.Init;
begin

end;

function MakeVertex(x,y,z:single;color:cardinal):TVertex;
begin
 fillchar(result,sizeof(result),0);
 result.x:=x; result.y:=y; result.z:=z;
 result.color:=color;
end;

procedure T3DTest.RenderFrame;
const
 indices:array[0..71] of word=(0,1,2,0,2,3, 4,5,6,4,6,7, 8,9,10,8,10,11, 12,13,14,12,14,15,
    16,17,18,16,18,19, 20,21,22,20,22,23, 24,25,26,24,26,27, 28,29,30,28,30,31,
    32,33,34,32,34,35, 36,37,38,36,38,39, 40,41,42,40,42,43, 44,45,46,44,46,47);
var
// mat:TMatrix4f;
 t:single;
 vertices:TVertices;
 i:integer;
 x,y,z:double;
 pnt:array[1..3] of TPoint3;
begin
 inc(frame);
 sleep(1);
 gfx.target.Clear($FF000000+frame and 127,1,-1);
 gfx.BeginPaint(nil);
// draw.FillRect(10,10,20,20,$FF709090);

// draw.SetDefaultView;
 x:=1024/2; y:=768/2; z:=500;
 t:=frame/100;

 gfx.transform.Perspective(-30,30,-20,20,40,1,100);
// draw.SetOrthographic(30,0,100);

// draw.SetupCamera(Point3(20*sin(frame/100),-10,20*cos(frame/100)),Point3(0,0,0),Point3(0,1000,0));
// t:=1;
 gfx.transform.SetCamera(Point3(20*cos(t),7,20*sin(t)),Point3(0,3,0),Point3(0,1000,00));
// if frame mod 200<100 then
// draw.SetupCamera(Point3(20,5,0),Point3(0,0,0),Point3(0,-1000,0));

 gfx.transform.SetObj(IdentMatrix4);
 glDisable(GL_CULL_FACE);

 glEnable(GL_DEPTH_TEST);
 glDepthFunc(GL_LESS);

 pnt[1]:=gfx.transform.Transform(Point3(0,3,0));
 pnt[2]:=gfx.transform.Transform(Point3(0,10,0));
 pnt[3]:=gfx.transform.Transform(Point3(0,0,10));

 // X axis
 AddVertex(vertices,0,-1,0,0,0,$FF0000C0);
 AddVertex(vertices,0,1,0,0,0,$FF0000C0);
 AddVertex(vertices,10,0,0,0,0,$FF0000C0);
 AddVertex(vertices,0,0,-1,0,0,$FF0000C0);
 AddVertex(vertices,0,0,1,0,0,$FF0000C0);
 AddVertex(vertices,10,0,0,0,0,$FF0000C0);

 // Y axis
 AddVertex(vertices,-1, 0, 0,0,0,$FF00C000);
 AddVertex(vertices, 1, 0, 0,0,0,$FF00C000);
 AddVertex(vertices, 0,10, 0,0,0,$FF00C000);
 AddVertex(vertices, 0, 0,-1,0,0,$FF00C000);
 AddVertex(vertices, 0, 0, 1,0,0,$FF00C000);
 AddVertex(vertices, 0,10, 0,0,0,$FF00C000);

 // Z axis
 AddVertex(vertices,-1, 0, 0,0,0,$FFC00000);
 AddVertex(vertices, 1, 0, 0,0,0,$FFC00000);
 AddVertex(vertices, 0, 0,10,0,0,$FFC00000);
 AddVertex(vertices, 0,-1, 0,0,0,$FFC00000);
 AddVertex(vertices, 0, 1, 0,0,0,$FFC00000);
 AddVertex(vertices, 0, 0,10,0,0,$FFC00000);

 // Cube
 AddVertex(vertices, -1, -1, 1, 0,0,$FF400000);
 AddVertex(vertices,  1, -1, 1, 0,0,$FF400000);
 AddVertex(vertices,  1,  1, 1, 0,0,$FF400000);
 AddVertex(vertices, -1, -1, 1, 0,0,$FF400000);
 AddVertex(vertices,  1,  1, 1, 0,0,$FF400000);
 AddVertex(vertices, -1,  1, 1, 0,0,$FF400000);

 AddVertex(vertices, -1, -1,-1, 0,0,$FF600000);
 AddVertex(vertices,  1, -1,-1, 0,0,$FF600000);
 AddVertex(vertices,  1,  1,-1, 0,0,$FF600000);
 AddVertex(vertices, -1, -1,-1, 0,0,$FF600000);
 AddVertex(vertices,  1,  1,-1, 0,0,$FF600000);
 AddVertex(vertices, -1,  1,-1, 0,0,$FF600000);

 AddVertex(vertices, 1,-1, -1,  0,0,$FF000040);
 AddVertex(vertices, 1, 1, -1,  0,0,$FF000040);
 AddVertex(vertices, 1, 1,  1,  0,0,$FF000040);
 AddVertex(vertices, 1,-1, -1,  0,0,$FF000040);
 AddVertex(vertices, 1, 1,  1,  0,0,$FF000040);
 AddVertex(vertices, 1,-1,  1,  0,0,$FF000040);

 AddVertex(vertices,-1, -1, -1, 0,0,$FF000060);
 AddVertex(vertices,-1,  1, -1, 0,0,$FF000060);
 AddVertex(vertices,-1,  1,  1, 0,0,$FF000060);
 AddVertex(vertices,-1, -1, -1, 0,0,$FF000060);
 AddVertex(vertices,-1,  1,  1, 0,0,$FF000060);
 AddVertex(vertices,-1, -1,  1, 0,0,$FF000060);

 AddVertex(vertices, -1, 1, -1,  0,0,$FF004000);
 AddVertex(vertices,  1, 1, -1,  0,0,$FF004000);
 AddVertex(vertices,  1, 1,  1,  0,0,$FF004000);
 AddVertex(vertices, -1, 1, -1,  0,0,$FF004000);
 AddVertex(vertices,  1, 1,  1,  0,0,$FF004000);
 AddVertex(vertices, -1, 1,  1,  0,0,$FF004000);

 AddVertex(vertices, -1,-1, -1, 0,0,$FF006000);
 AddVertex(vertices,  1,-1, -1, 0,0,$FF006000);
 AddVertex(vertices,  1,-1,  1, 0,0,$FF006000);
 AddVertex(vertices, -1,-1, -1, 0,0,$FF006000);
 AddVertex(vertices,  1,-1,  1, 0,0,$FF006000);
 AddVertex(vertices, -1,-1,  1, 0,0,$FF006000);

 // Ground
 AddVertex(vertices, -4, -4,-4, 0,0,$4F603060);
 AddVertex(vertices,  4, -4,-4, 0,0,$4F603060);
 AddVertex(vertices,  4,  4,-4, 0,0,$4F603060);
 AddVertex(vertices, -4, -4,-4, 0,0,$4F603060);
 AddVertex(vertices,  4,  4,-4, 0,0,$4F603060);
 AddVertex(vertices, -4,  4,-4, 0,0,$4F603060);

 AddVertex(vertices, 10, 5, 5, 0,0,$FFFFFFFF);
 AddVertex(vertices, 10, 6, 5, 0,0,$FFFFFFFF);
 AddVertex(vertices, 11, 5, 5, 0,0,$FFFFFFFF);


 DrawMesh(vertices,nil);

// draw.Set3DTransform(Matrix4(MultMat4(RotationYMat(frame/150),TranslationMat(490+20*sin(frame/500),390,350))));

{ vertices[0]:=MakeVertex(-10,-10,0,$FF00C000);
 vertices[1]:=MakeVertex(30,-10,0,$FF00C080);
 vertices[2]:=MakeVertex(30,30,0,$FFC0C000);
 vertices[3]:=MakeVertex(-10,30,0,$FF0000F0);
 draw.IndexedMesh(@vertices[0],@indices[0],2,4,nil);


 draw.Set3DTransform(IdentMatrix4); // вызывать обязательно!

// draw.Set3DTransform();
 vertices[0]:=MakeVertex(100,100,0,$FF00C000);
 vertices[1]:=MakeVertex(200,100,0,$FF00C080);
 vertices[2]:=MakeVertex(200,200,0,$FFC0C000);
 vertices[3]:=MakeVertex(100,200,0,$FFC0C0C0);
 draw.IndexedMesh(@vertices[0],@indices[0],2,4,nil);

 draw.FillRect(500,200,700,250,$FFC0B020);    }

{ draw.SetupCamera(Point3(0,0,0),
    Point3(x,y,0),
    Point3(x,y-1000,z));}

 glDisable(GL_DEPTH_TEST);

 gfx.EndPaint;
end;

{ TTest }

procedure TTest.Done;
begin

end;

procedure TestSharpen;
var
 img:TTexture;
begin
 img:=LoadImageFromFile('e:\apus\projects\ah\images\cards\unicorn') as TTexture;
 SharpenImage(img,120);
 SaveImage(img,'test.tga');
end;

{ TShaderTest }

procedure TShaderTest.Done;
begin
  inherited;

end;

procedure TShaderTest.Init;
var
// vsh,fsh:GLHandle;
// str:PChar;
// len,res:integer;
 pc:PCardinal;
 x,y:integer;
begin
 try
 prog:=gfx.shader.Build(
   LoadFileAsString('res\shader.vert'),
   LoadFileAsString('res\shader.frag'));
 //loc1:=glGetUniformLocation(prog,'offset');

 tex:=AllocImage(256,256,ipfARGB,0,'tex');
 tex.Lock;
 for y:=0 to 255 do begin
  pc:=tex.data; inc(pc,y*tex.pitch div 4);
  for x:=0 to 255 do begin
   pc^:=$FF404040;
   if x mod 7 in [2,3] then inc(pc^,$B0);
   if x mod 13=5 then inc(pc^,$B000);
   if (y mod 11 in [4..6]) or ((x div 2+y) mod 9=7) then inc(pc^,$B00000);
   inc(pc);
  end;
 end;
 tex.Unlock;
 except
  on e:exception do begin
    ErrorMessage(e.message);
    halt;
  end;
 end;
end;

procedure TShaderTest.RenderFrame;
var
 d:double;
begin
 inc(frame);
 gfx.BeginPaint(nil);
 gfx.target.Clear($FF000040);
 draw.Image(600,10,tex);
 gfx.shader.UseCustom(prog);
 d:=1+sin(0.003*(myTickCount mod $FFFFFF));
 prog.SetUniform('offset',0.003*d);
 draw.Image(600,300,tex);
 // Switch back to the default shader
 gfx.shader.Reset;
 draw.FillGradrect(50,50,300,200,$FFF04000,$FF60C000,false);
 draw.FillRect(30,100,500,120,$FF000000);
 gfx.EndPaint;
end;

{ TVideoTest }

procedure TVideoTest.Done;
begin

end;

procedure TVideoTest.Init;
begin
{ libvlc_dynamic_dll_init;
 if (libvlc_dynamic_dll_error <> '') then begin
    ShowMessage(libvlc_dynamic_dll_error,'Error');
    exit;
 end;

 vlc:=libvlc_new(0,nil);
 if vlc=nil then
  ShowMessage(libvlc_errmsg,'ERROR');
// mp:=libvlc_media_player_new(vlc);
 media := libvlc_media_new_path(vlc, 'video.avi');
 mp := libvlc_media_player_new_from_media(media);    }
end;

procedure TVideoTest.RenderFrame;
begin
 if frame=1 then begin
{  libvlc_video_set_key_input(vlc, 1);
  libvlc_video_set_mouse_input(vlc, 1);
  libvlc_media_player_set_display_window(mp, game.window);

  libvlc_media_player_play(mp);
  libvlc_media_release(media);         }
 end;
 inc(frame);
 gfx.target.Clear($FF000040);
 gfx.BeginPaint(nil);
 draw.FillRect(30,100,500,120,$FFFFFF00);
 gfx.EndPaint;
end;


{ T3DCharacterTest }

procedure T3DCharacterTest.Done;
begin

end;

procedure T3DCharacterTest.Init;
var
 modelAnim:TModel3D;
 count:integer;
 vSrc,fSrc:AnsiString;
 pnt:TPoint3s;
 b1,b2,b:TMatrix43s;
begin
 modelObj:=Load3DModelOBJ('res\test.obj');
 tex:=LoadImageFromFile('res\texTest.png',liffTexture+liffMipMaps);

 model:=Load3DModelIQM('res\test2.iqm');
// model:=LoadIQM('res\knight.iqm');
// model.FlipX;
// model.UpdateBoneMatrices; // Prepare

 pnt:=Point3s(10,0,0);
 b1:=IdentMatrix43s;
 b2:=IdentMatrix43s;
 b1[3,0]:=3;
 b2[3,1]:=2;
 MultMat4(b1,b2,b);
 MultPnt4(b,@pnt,1,0);

 // Prepare buffers
 count:=length(model.vp);
 SetLength(vertices,count);
 model.FillVertexBuffer(@vertices[0],count,sizeof(vertices[0]),true, 0,32,-1,16,12);
 model.animations[0].loop:=true;
 model.PlayAnimation;
 SetLength(indices,length(model.trgList));
 move(model.trgList[0],indices[0],length(indices)*2);

 // Second model
 count:=length(modelObj.vp);
 SetLength(vertices2,count);
 modelObj.FillVertexBuffer(@vertices2[0],count,sizeof(vertices2[0]),false, 0,32,-1,16,12);
 SetLength(indices2,length(modelObj.trgList));
 move(modelObj.trgList[0],indices2[0],length(indices2)*2);


 // Prepare shaders
 vSrc:=LoadFileAsString(FileName('res\knight.vsh'));
 fSrc:=LoadFileAsString(FileName('res\knight.fsh'));
 shader:=gfx.shader.Build(vSrc,fSrc);

 vSrc:=LoadFileAsString(FileName('res\tex.vsh'));
 fSrc:=LoadFileAsString(FileName('res\tex.fsh'));
 shader2:=gfx.shader.Build(vSrc,fSrc);
end;

procedure T3DCharacterTest.RenderFrame;
var
 pnt:TPoint3;
 time:double;
 objMat:TMatrix43;
 loc:integer;
 MVP,uModel:TMatrix4s;
begin
 time:=MyTickCount/1200;
 gfx.target.Clear($FF101020,1);
 // Setup camera and projection
 gfx.transform.Perspective(-10,10,-7,7,10,5,1000);
 gfx.transform.SetCamera(Point3(30,0,15),Point3(0,0,8),Vector3(0,0,1000));
 gfx.transform.SetObj(IdentMatrix4);

 // Make sure everything is OK (just for debug)
 pnt:=gfx.transform.Transform(Point3(0,0,0));
 pnt:=gfx.transform.Transform(Point3(1,1,1));

 // Make animation
 model.AnimateBones;
 model.FillVertexBuffer(@vertices[0],length(model.vp),sizeof(vertices[0]),true, 0,32,-1,16,12);

 // Setup rendering mode
 glEnable(GL_DEPTH_TEST);
 glDepthFunc(GL_LEQUAL);
 draw.FillRect(-15,-15,15,15,$C000A030);

 // Set model position
 MultMat4(ScaleMat(2,2,2),RotationZMat(time),objMat);
 objMat[3,2]:=3;
 gfx.transform.SetObj(Matrix4(objMat));

 // Switch to our custom shader
 gfx.shader.UseCustom(shader);

 // After shader changing we MUST set uniforms
 shader.SetUniform('uMVP',gfx.transform.GetMVPMatrix);
 // model matrix
 shader.SetUniform('uModel',gfx.transform.GetObjMatrix);

 // Setup mesh data source arrays
 glEnableVertexAttribArray(0);
 glVertexAttribPointer(0,3,GL_FLOAT,false,sizeof(vertices[0]),@vertices[0]);
 glEnableVertexAttribArray(1);
 glVertexAttribPointer(1,3,GL_FLOAT,false,sizeof(vertices[0]),@vertices[0].nX);
 glEnableVertexAttribArray(2);
 glVertexAttribPointer(2,2,GL_FLOAT,false,sizeof(vertices[0]),@vertices[0].u);

 // DRAW IT!
 gfx.SetCullMode(cullCW);
 glDrawElements(GL_TRIANGLES,length(indices),GL_UNSIGNED_SHORT,@indices[0]);

 // SECOND MODEL (OBJ)

 // Textured shader
 gfx.shader.UseCustom(shader2);

 // Set model position
 MultMat4(ScaleMat(4,4,4),RotationZMat(time),objMat);
 objMat[3,1]:=16;
 objMat[3,0]:=5;
 objMat[3,2]:=1.5;
 gfx.transform.SetObj(Matrix4(objMat));
 // Upload matrices
 shader2.SetUniform('uMVP',gfx.transform.GetMVPMatrix);
 // model matrix
 shader2.SetUniform('uModel',gfx.transform.GetObjMatrix);
 // Setup mesh data arrays
 glVertexAttribPointer(0,3,GL_FLOAT,false,sizeof(vertices2[0]),@vertices2[0]);
 glVertexAttribPointer(1,3,GL_FLOAT,false,sizeof(vertices2[0]),@vertices2[0].nX);
 glVertexAttribPointer(2,2,GL_FLOAT,false,sizeof(vertices2[0]),@vertices2[0].u);

 // Setup texture
 gfx.resMan.MakeOnline(tex,0);
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
 shader2.SetUniform('tex',0);

 // Draw IT
 glDrawElements(GL_TRIANGLES,length(indices2),GL_UNSIGNED_SHORT,@indices2[0]);


 // Reset everything back
 glDisable(GL_DEPTH_TEST);
 gfx.shader.DefaultTexMode;
 gfx.transform.DefaultView;
 gfx.SetCullMode(cullNone);
end;

function MyRound(v:single):integer; inline;
 const
  epsilon = 0.000001;
 begin
  result:=PRound(v);
  //result:=round(SimpleRoundTo(v,0));
 end;

var
 v:single;
 i,n,key:integer;
 time:int64;
begin
 time:=MyTickCount;
 v:=10.6;
 for i:=0 to 10000000 do begin
  n:=MyRound(v);
  n:=MyRound(v);
  n:=MyRound(v);
  n:=MyRound(v);
 end;
 time:=MyTickCOunt-time;

 if HasParam('-wnd') then wnd:=true;
 if HasParam('-fullscreen') then wnd:=false;
 testNum:=StrToIntDef(GetParam('test'),testNum);

 UseLogFile('log.txt');
 SetLogMode(lmVerbose);
 SetEventHandler('Error',HEvent);
 SetEventHandler('Engine',HEvent);
 SetEventHandler('Debug',HEvent);

 case testnum of
  1:test:=TLinesTest.Create;
  2:test:=TPrimTest.Create;
  3:test:=TTexturesTest.Create;
  4:test:=TTex2Test.Create;
  5:test:=TR2TextureTest.Create;
  6:test:=TFontTest.Create;
  7:test:=TClipTest.Create;
  8:test:=TParticlesTest.Create;
  9:test:=TToolsTest.Create;
  10:test:=TBandTest.Create;
  11:test:=T3DTest.Create;
  12:test:=TFontTest2.Create;
  13:test:=TShaderTest.Create;
  14:test:=TVideoTest.Create;
  15:test:=T3DCharacterTest.Create;
 end;

 game:=MyGame.Create(TWindowsPlatform.Create, TOpenGL.Create); // Создаем объект
 //game:=MyGame.Create(TSDLPlatform.Create, TOpenGL.Create); // Создаем объект
 game.showFPS:=true;
 disableDRT:=true;

 // Начальные установки игры
 with s do begin
  title:='Test Game';
  width:=1024;
  height:=768;
  colorDepth:=32;
  refresh:=0;
  if wnd then begin
   mode.displayMode:=dmWindow;
   altMode.displayMode:=dmSwitchResolution;
  end else begin
   mode.displayMode:=dmSwitchResolution;
   altMode.displayMode:=dmFixedWindow;
  end;
//  mode:=dmFullScreen;
  mode.displayFitMode:=dfmCenter;
  showsystemcursor:=true;
  zbuffer:=16;
  stencil:=false;
  multisampling:=0;
  slowmotion:=false;
//  customCursor:=false;
  VSync:=1;
 end;
 game.SetSettings(s); // Задать установки

 game.Run; // Запустить движок

 InitUI;
 // А можно и не делать - можно это сделать в обработчике события
 savetime:=MyTickCount;
 key:=0;
 repeat
  delay(5);
  if (game.keyState[59]>0) and (key=0) then begin // [F1]
   s.VSync:=s.VSync xor 1;
   game.SetVSync(s.VSync);
   key:=1;
   saveTime:=MyTickCount;
   frame:=0;
  end;
  if game.keyState[59]=0 then key:=0;
 until (game.keyState[1]<>0) or (game.terminated);
 game.Stop;
// ShowMessage('Average FPS: '+FloatToStrF(1000*frame/(getTickCount-SaveTime),ffGeneral,6,1),'FPS');
end.
