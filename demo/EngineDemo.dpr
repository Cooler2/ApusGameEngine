//{$DEFINE OPENGL}
program EngineDemo;

uses
  windows,
  sysutils,
  myservis,
  DirectXGraphics,
  geom2d,
  geom3d,
  images,
  Types,
  dglOpenGl,
  eventMan,
  FastGfx,
  DirectText,
  FreeTypeFont,
  EngineAPI in '..\EngineAPI.pas',
  UIClasses in '..\UIClasses.pas',
  PainterGL in '..\PainterGL.pas',
  ImageMan in '..\ImageMan.pas',
  UIScene in '..\UIScene.pas',
  UIRender in '..\UIRender.pas',
  engineTools in '..\engineTools.pas',
  console in '..\console.pas',
  conScene in '..\conScene.pas',
  stdEffects in '..\stdEffects.pas',
  SoundB in '..\SoundB.pas',
  UsableNetwork in '..\UsableNetwork.pas',
  BitmapStyle in '..\BitmapStyle.pas',
  Sound in '..\Sound.pas',
  UModes in '..\UModes.pas',
  networking2 in '..\networking2.pas',
  DxImages8 in '..\DxImages8.pas',
  IOSgame in '..\IOSgame.pas',
  Painter8 in '..\Painter8.pas',
  BasicGame in '..\BasicGame.pas',
  GLImages in '..\GLImages.pas',
  BasicPainter in '..\BasicPainter.pas',
  dxgame8 in '..\dxgame8.pas',
  GLgame in '..\GLgame.pas',
  TweakScene in '..\TweakScene.pas',
  networking3 in '..\networking3.pas',
  UDict in '..\UDict.pas',
  customstyle in '..\customstyle.pas',
  GameObjects in '..\GameObjects.pas',
  cmdproc in '..\cmdproc.pas',
  ComplexText in '..\ComplexText.pas',
  steamAPI in '..\steamAPI.pas',
  PainterGL2 in '..\PainterGL2.pas',
  GameApp in '..\GameApp.pas';

const
 wnd:boolean=true;
 makeScreenShot:boolean=false;
 virtualScreen:boolean=false;

 // Номер теста:
 testnum:integer = 11;
 // 1 - инициализация, очистка буфера разными цветами, рисование линий
 // 2 - рисование нетекстурированных примитивов
 // 3 - текстурированные примитивы, мультитекстурирование
 // 4 - мультитекстурирование
 // 5 - render to texture
 // 6 - вывод текста
 // 7 - отсечение
 // 8 - партиклы
 // 9 - загрузка картинок итд.
 // 10 - полоски
 // 11 - тест 3D
 // 12 - вывод текста FreeType
 // 13 - тест шейдеров OpenGL
 // 14 - тест видео

 TexVertFmt=D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR+D3DFVF_TEX1+D3DFVF_TEXTUREFORMAT2;
 ColVertFmt=D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR;

var
 savetime:cardinal;
 
type
{$IFDEF OPENGL}
 MyGame=class(TGLGame)
{$ELSE}
 MyGame=class(TDxGame8)
{$ENDIF}
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
  prog,uTex:integer;
  tex1,tex2,tex3,tex4,texA,tex5,tex6:TTextureImage;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TTex2Test=class(TTest)
  tex1,tex2,tex3:TTextureImage;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TR2TextureTest=class(TTest)
  tex1,tex2,tex3,tex4,tex0:TTextureImage;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TFontTest=class(TTest)
  fnt:integer;
  texA:TTextureImage;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TFontTest2=class(TTest)
  font:TFreeTypeFont;
  buf:TTextureImage;
  procedure Init; override;
  procedure RenderFrame; override;
 end;

 TToolsTest=class(TTest)
  tex1,tex2,tex3,tex4:TTexture;
  t1,t2,t3,t4:TTextureImage;
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
  tex,tex2:TTextureImage;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TBandTest=class(TTest)
  tex:TTextureImage;
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
  prog:integer;
  loc1:integer;
  tex:TTextureImage;
  procedure Init; override;
  procedure RenderFrame; override;
  procedure Done; override;
 end;

 TVideoTest=class(TTest)
  tex:TTextureImage;
  vlc,mp,media:pointer;
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
  if frame and 63=63 then
   SetWindowCaption('FPS: '+inttostr(round(game.fps))+
     '  Avg FPS: '+FloatToStrF(1000*frame/(getTickCount-SaveTime),ffFixed,6,1));
  result:=true;
//  sleep(0);
 end;

procedure MyGame.RenderFrame;
begin
 painter.ResetTarget;
 test.RenderFrame;
{ if makeScreenShot then begin
 end;}
end;

function HEvent(event:EventStr;tag:NativeInt):boolean;
 var
  i,x,y:integer;
  w:^cardinal;
  ptr:^TScrPoint;
 begin
  ForceLogMessage(inttostr(GetTickCount)+' '+event+' '+inttostr(tag));

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
 vrt:array[0..20] of TScrPoint;
begin
 inc(frame);
 painter.Clear($FF000000+frame and 127,-1,-1);
 painter.BeginPaint(nil);

 painter.FillRect(410,10,500,100,$30908079);

 for i:=1 to 10 do begin
  painter.DrawLine(10,10*i,100,10*i,$FFFFFFFF-i*24);
  painter.DrawLine(10*i,10,10*i,100,$FFFFFFFF-(i*24) shl 16);
 end;
 painter.Rect(200-2,100-2,300+2,200+2,$FF00FF00);
 painter.DrawLine(200,100,300,200,$FFFF0000);
 for i:=1 to 4 do begin
  painter.DrawLine(200+i*20,100,300,100+i*20,$FF0000FF);
  painter.DrawLine(200,100+i*20,200+i*20,200,$FF00FFFF);
 end;
 for i:=1 to 5 do begin
  t:=frame/500+i*pi/2.5;
  painter.DrawLine(200+5*cos(t),300+5*sin(t),200+50*cos(t),300+50*sin(t),$FFC0FF00);
 end;
 for i:=1 to frame mod 4+1 do
  painter.DrawLine(i*3,1,i*3,5,$FFFFFFFF);

 for i:=0 to 200 do
  painter.DrawLine(i*4,500,i*4+2,510,$FF80FF00);
  
 painter.EndPaint;
end;

{ TTexturesTest }
procedure TTexturesTest.Done;
begin
 texman.FreeImage(tex1);
 texman.FreeImage(tex2);
end;

procedure TTexturesTest.Init;
var
 i,j,r:integer;
 pb:pbyte;
begin
 tex1:=texman.AllocImage(100,100,ipfARGB,0,'test1') as TTextureImage;
 tex2:=texman.AllocImage(64,64,ipf565,aiTexture,'test2') as TTextureImage;
 tex3:=texman.AllocImage(64,64,ipfARGB,aiTexture,'test3') as TTextureImage;
 tex4:=texman.AllocImage(128,128,ipfARGB,aiTexture,'test4') as TTextureImage;
 texA:=texman.AllocImage(100,100,ipfA8,aiTexture,'testA') as TTextureImage;
// tex1:=LoadImageFromFile('test1.tga') as TTExtureImage;
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

 try
 prog:=TGLPainter(painter).BuildShaderProgram(
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

procedure Shader1(var vertex:TScrPoint);
begin
 with vertex do begin
  x:=x+3*sin(globalS+y*0.18)-0.1*y;
  y:=y+3*cos(globalS+x*0.3);
 end; 
end;

procedure TTexturesTest.RenderFrame;
var
 vrt:array[0..3] of TScrPoint;
 tex:TTextureImage;
 l1,l2:TMultiTexLayer;
 v,s:single;
 x,y,i,t:integer;
 r:TRect;
 mesh:TMesh;
 vertices,transformed:TVertices;
 indices:TIndices;
 data:array of cardinal;
begin
// sleep(10);
 inc(frame);

 painter.Clear($FF000040,-1,-1);
 painter.BeginPaint(nil);
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

 painter.DrawImage(1,1,tex1,$FF808080);
 painter.DrawScaled(200,100,350,250,tex1,$FF808080);
 painter.DrawScaled(200,300,299,399,tex1,$FF808080);

 x:=frame mod 100;
 r:=Rect(x,10,x+10,20);
 tex4.Lock(0,lmReadWrite,@r);
 FilLRect(tex4.data,tex4.pitch,0,0,11,11,$FF0050C0+(frame mod 256) shl 16);
 tex4.Unlock;
 painter.DrawImage(800,10,tex4);

 painter.DrawImagePart90(200,50,tex1,$FF808080,Rect(2,2,20,10),-1);
 painter.DrawImagePart90(230,50,tex1,$FF808080,Rect(2,2,20,10),1);
 painter.DrawImagePart90(260,50,tex1,$FF808080,Rect(2,2,20,10),2);
 painter.DrawImagePart90(290,50,tex1,$FF808080,Rect(2,2,20,10),3);
 painter.DrawRotScaled(450,200,2,2,1,tex2,$FF808080);

 if (frame div 100) and 1=0 then
   painter.SetTexMode(0,tblNone,tblNone,fltNearest);
 painter.DrawRotScaled(750,300,4,4,1,tex2,$FF808080);
 painter.SetTexMode(0,tblNone,tblNone,fltBilinear);

 painter.Rect(200-1,100-1,350+1,250+1,$FFFFFF80);
 painter.Rect(100-2,200-2,107+2,207+2,$FFFFFFFF);
 painter.DrawImage(10,200,tex2,$FF808080);
 painter.DrawImagePart(100,200,tex2,$FF808080,Rect(8,8,15,15));
 v:=1+0.5*sin(frame/35);
 painter.DrawRotScaled(200,500,v,v,frame/100,tex1,$FF808080);
 painter.DrawImage(400,10,tex3);

 s:=(MyTickCount mod 100000)/2000;
 v:=2*frac(s);
 if v>1 then v:=1;
 s:=(2*s-v)*Pi/2;
 painter.FillRect(650-19,30-19,650+19,30+19,$FFC0A020);
 painter.FillRect(700-19,30-19,700+19,30+19,$FFC0A020);
 painter.DrawRotScaled(650,30,1,1,s,tex5,$FF808080);
 painter.DrawRotScaled(700,30,1,1,s,tex6,$FF808080);


 painter.DrawImage(800,160,texA,$FFFF6000);
 painter.DrawImage(900,160,texA,$FF008000);

 {$IFDEF DIRECTX}
// if frame=10 then d3d8.DumpD3D;
 {$ENDIF}

 with vrt[0] do begin
  x:=600; y:=10; z:=0; rhw:=1;
  diffuse:=$FF808080;
  u:=0; v:=0;
 end;
 with vrt[1] do begin
  x:=750; y:=20; z:=0; rhw:=1;
  diffuse:=$FF808080;
  u:=1; v:=0;
 end;
 with vrt[2] do begin
  x:=730; y:=250; z:=0; rhw:=1;
  diffuse:=$FF008000;
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
  painter.DrawImage(0,0,tex1)
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
 painter.SetTexMode(0,tblModulate2X,tblModulate,fltBilinear);
 painter.SetTexMode(1,tblModulate,tblKeep,fltUndefined);
 painter.DrawMultiTex(x,y,x+150,y+150,@l1,@l2,nil,$FF808080);

 painter.SetTexInterpolationMode(1,tintFactor,0.5+sin(gettickcount/300)/2);
 painter.SetTexMode(1,tblInterpolate,tblKeep,fltBilinear);
 x:=760;
 painter.DrawMultiTex(x,y,x+150,y+150,@l1,@l2,nil,$FF808080);  }

// painter.Update;
 painter.EndPaint;
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
 pnts:array[0..4] of TPoint2;
 i:integer;
 a:single;
begin
 inc(frame);
// if frame>3 then exit;
 painter.Clear($FF000000+(frame div 4) and 127,-1,-1);
 painter.BeginPaint(nil);
 painter.FillRect(1,1,30,30,$FF80FF00);
 painter.FillRect(40,1,70,30,$80FFFFFF);
 painter.FillGradrect(100,100,140,140,$FF0000FF,$FFFF0000,true);
 painter.FillGradrect(150,100,190,140,$FF0000FF,$FFFF0000,false);
 painter.FillGradrect(100,150,140,190,$FFFFFF00,$0FFFFF00,true);
 painter.FillGradrect(150,150,190,190,$FFFFFF00,$0FFFFF00,false);


 painter.ShadedRect(300,50,400,90,3,$FFC0C0C0,$FF808080);
 painter.ShadedRect(300,100,400,130,1,$FFC0C0C0,$FF808080);

 for i:=0 to 4 do begin
  a:=frame/50;
  pnts[i].x:=250+30*cos(a+i);
  pnts[i].y:=250+30*sin(a+i);
 end;
 painter.DrawPolygon(@pnts,5,$FFFF8000);

 painter.Rect(0,0,1023,767,$80FFFF30);
 painter.EndPaint;
end;

{ TFontTest }

procedure TFontTest.Done;
begin
 painter.FreeFont(fnt);
end;

procedure TFontTest.Init;
var
 font:cardinal;
begin
 painter.LoadFont('res\times1.fnt');
 painter.LoadFont('res\times2.fnt');
 painter.LoadFont('res\times3.fnt');
 painter.LoadFont('res\goodfish1.fnt');
 painter.LoadFont('res\goodfish2.fnt');
 //fnt:=painter.LoadFromFile('test');
 LoadRasterFont('res\test.fnt');
 fnt:=painter.PrepareFont(1);
 painter.MatchFont(1,painter.GetFont('Times New Roman',11));
 font:=painter.GetFont('Times New Roman',12);
 painter.SetFontOption(font,foDownscaleFactor,1);
 painter.SetFontOption(font,foUpscaleFactor,1);
 font:=painter.GetFont('Times New Roman',9);
 painter.SetFontOption(font,foDownscaleFactor,1);
 painter.SetFontOption(font,foUpscaleFactor,1);
end;

procedure TFontTest.RenderFrame;
var
 i:integer;
 handle,color:cardinal;
 size:single;
begin
// if frame>0 then exit;
 inc(frame);
 painter.Clear($FF000080 { $ FF000000+frame and 127},-1,-1);
 painter.BeginPaint(nil);
 // Unicode text output

 handle:=painter.GetFont('Times New Roman',10);
 painter.TextOut(handle,200+(getTickCount div 300) mod 40,60,$FFFFF0A0,'Water Elemental',taRight);
// color:=$FFF0A0A0+$100*round(40*sin(frame*0.01))+round(40*(frame*0.02));

 // Нагрузка на кэш
{ handle:=painter.GetFont('Times New Roman',20);
 painter.TextOut(handle,10,540,$FFE0E0FF,chr(33+frame mod 210));
 handle:=painter.GetFont('Times New Roman',15);
 painter.TextOut(handle,50,540,$FFE0E0FF,chr(33+frame mod 210));
 handle:=painter.GetFont('Goodfish',12);
 painter.TextOut(handle,90,540,$FFE0E0FF,chr(33+frame mod 100));}

 color:=$FFFFF0A0;
 painter.TextColorX2:=false;
 for i:=1 to 8 do begin
  painter.FillRect(580-round(19.7*(9+i*0.6)),72+i*68,
                   580+round(19.7*(9+i*0.6)),122+i*68,$FF404090);
  handle:=painter.GetFont('Times New Roman',9+i*0.6);
  painter.TextOut(handle,580,90+i*68,color,'Hello Kitty!® Première l''écriture! $27 = €34',taCenter);
  painter.TextOut(handle,580,115+i*68,color,'Нам не страшен враг любой, Лукашенко - наш герой! ©',taCenter);
 end;

 size:=Pike((frame div 10) mod 255,128,200,350,200)/200;
 size:=8*sqr(size);
 handle:=painter.GetFont('Times New Roman',size);
 painter.TextOut(handle,520,722,color,'Hello Kitty!® Première l''écriture! $27 = €34',taCenter);
 painter.TextOut(handle,520,750,color,'Нам не страшен враг любой, Лукашенко - наш герой! ©',taCenter);

 // Show text cache texture
// painter.TextOut(0,0,0,0,'');

 painter.TextOut(1,10,690,$FFFFFF40,'Hello World! Привет всем! Première tentative de l''écriture!');

 // Legacy text output
 painter.SetFont(fnt);
 painter.WriteSimple(10,10,$FFFFFFFF,'Hello');
 for i:=20 downto 4 do begin
  painter.FillRect(9,i*20+2,10+i*8,i*20+20,$C0404090);
  painter.WriteSimple(10,i*20,$FFFFFF00+i*12-(i*12) shl 16,copy('я 12345678901234567890',1,i));
 end;

 painter.FillRect(500,10,640,50,$FF8080F0);
 painter.FillRect(500,70,640,120,$FF000064);
 painter.DrawLine(500,30,640,30,$FF000000);
 painter.DrawLine(500,75,640,75,$50FFFFFF);
 painter.DrawLine(500,90,640,90,$80FFFFFF);
 painter.DrawLine(500,103,640,103,$50FFFFFF);
 painter.DrawLine(570,10,570,110,$50FFFFFF);
 painter.DrawLine(524,10,524,110,$50FFFFFF);
 painter.DrawLine(616,10,616,110,$50FFFFFF);
 fillchar(painter.textEffects,sizeof(painter.textEffects),0);
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
 end;

// painter.FillRect(0,0,511,511,$FFFFFFFF);
{ if frame mod 40<10 then
  painter.TextOut(MAGIC_TEXTCACHE,0,0,$FFFFFFFF,'');}

 painter.EndPaint;
end;

procedure TFontTest2.Init;
begin
 //font:=TFreeTypeFont.LoadFromFile('res\arial.ttf');
// font:=TFreeTypeFont.LoadFromFile('12460.ttf');
 buf:=texman.AllocImage(400,50,ipfARGB,0,'txtbuf') as TTextureImage;
 painter.LoadFont('res\arial.ttf');
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
 painter.Clear($FF000080 { $ FF000000+frame and 127},-1,-1);
 painter.BeginPaint(nil);
 // Unicode text output


 f:=painter.GetFont('Arial',30);
 painter.TextOutW(f,10,40,$FFFFA080,'Première tentative de l''écriture!',taLeft);
 f:=painter.GetFont('Arial',24);
 painter.TextOutW(f,10,80,$FFFFA080,'Кракозябры! אַﭠﮚﻼ№җ£©α²',taLeft);
 painter.TextOutW(f,10,115,$FFFFA080,'Кракозябры!',taLeft,toItalic);

 f:=painter.GetFont('Arial',14,toDontTranslate);
 w:=painter.TextWidthW(f,'1) AV Привет - Hello!');
 h:=painter.FontHeight(f);
 painter.FillRect(10,260-h-2,10+w,260+1,$FFC0C0C0);
 painter.TextOutW(f,10,200,$FFFFA080,'1) AV Привет - Hello!',taLeft);
 painter.TextOutW(f,10,230,$FFFFFFFF,'1) AV Привет - Hello!',taLeft);
 painter.TextOutW(f,10,260,$FF000000,'1) AV Привет - Hello!',taLeft);

 for i:=1 to 20 do
  painter.TextOut(f,10,270+i*20,$FFFFFFFF,'Line '+IntToStr(i),taLeft);

 f:=painter.GetFont('Arial',12,toDontTranslate);
 painter.TextOutW(f,220,160,$FFE0E0E0,'Hinting mode: DEFAULT');
 painter.TextOutW(f,220,180,$FFE0E0E0,'Hinting mode: OFF',taLeft,toNoHinting);
 painter.TextOutW(f,220,200,$FFE0E0E0,'Hinting mode: AUTO',taLeft,toAutoHinting);
 painter.TextOutW(f,220,220,$FFE0E0E0,'Hinting mode: AUTO',taLeft,toAutoHinting+toItalic);
 painter.TextOutW(f,220,240,$FFE0E0E0,'Text mode: BOLD',taLeft,toBold);
 painter.TextOutW(f,220,260,$FFE0E0E0,'Text mode: Bold Italic',taLeft,toItalic+toBold);
 painter.TextOutW(f,220,280,$FFE0E0F0,'Mode: underlined',taLeft,toUnderline);
 painter.TextOutW(f,220,300,$FFE0E0F0,'Measure {b}complex{/b} text',taLeft,toMeasure+toComplexText);
 for i:=0 to high(painter.textMetrics) do
  with painter.textMetrics[i] do
   painter.DrawLine(left,bottom,left,bottom+5,$90FFFFFF);
   
 curTextLink:=0;
 painter.TextOutW(f,220,330,$FFE0E0F0,'Text with a {L=01}link{/L}!',taLeft,toMeasure+toComplexText,0,
   game.mouseX and $FFFF+game.mouseY shl 16);

{ buf.Lock;
 FillRect(buf.data,buf.pitch,0,0,buf.width-1,buf.height-1,$FFE0E0E0);
 FillRect(buf.data,buf.pitch,0,30,buf.width-1,30,$FFA0A0A0);
 font.RenderText(buf.data,buf.pitch,5,30,'1) AV Привет - Hello!',$FF400000,20+8*sin(frame/100));
 buf.Unlock;
 painter.DrawImage(10,10,buf);}

 f:=painter.GetFont('Arial',14,toDontTranslate);

 painter.TextOut(f,220,760,$FF6FF000,EncodeUTF8('Привет! @^#(!''"/n ( {C=FFE08080}1010{/C} / 700 )'),taLeft,toComplexText);

// painter.BeginTextBlock;
 for i:=1 to 10 do
  painter.TextOutW(f,220,760-i*25,$FF6FF000,
    '{u}This{!u} {I}is {!I}an{/i/i} {u}example {C=FF90E0C0}of {B}complex{/B/C/u} text',taLeft,toComplexText);
// painter.EndTextBlock; 
// painter.TextOutW(f,220,725,$FFFF0000,'This {B}is {!B}an{/b/b} example {C=FFC0E090}of complex{/C} text',taLeft);
// painter.TextOutW(f,220,750,$FFFF0000,'This {B}is {!B}an{/b/b} example {C=FFC0E090}of complex{/C} text',taLeft);

 painter.TextOutW(f,150,710,$FFC0C0C0,IntToStr(intervalHashMiss));
 painter.TextOutW(f,150,730,$FFC0C0C0,IntToStr(glyphWidthHashMiss));
 painter.TextOutW(f,150,750,$FFC0C0C0,IntToStr(frame));

 painter.DrawLine(700,672,700,730,$80FFFF50);
 painter.FillRect(700-22,700,700+22,725,$60000000);
 painter.TextOutW(f,700,690,$FFC0C0C0,'Center',taRight);
 painter.TextOutW(f,700,720,$FFC0C0C0,'Right',taCenter);
 painter.FillRect(600,732,600+290,757,$60000000);
 painter.TextOutW(f,600,750,$FFC0C0C0,'Justify {i}this{/i} {u}simple and small{/u} text',
   taJustify,toComplexText,290);

 i:=(MyTickCount div 1000);
 st:=words[i mod 3]+#13#10+words[(i+1) mod 3]+#13#10+words[(i+2) mod 3];
 w:=painter.TextWidth(f,st);
 painter.Rect(120,320,120+w,400,$60FFFFFF);
 painter.TextOutW(f,120,340,$FFC0C0C0,st);

 if getTickCount mod 1200<800 then begin
  painter.FillRect(512,0,1023,511,$FFFFFFFF);
  painter.TextOut(MAGIC_TEXTCACHE,512,0,$FFFFFFFF,'');
 end;
 painter.EndPaint;
end;


{ TR2TextureTest }

procedure TR2TextureTest.Done;
begin
 texman.FreeImage(tex1);
 texman.FreeImage(tex2);
end;

procedure TR2TextureTest.Init;
var
 i,j:integer;
 pb:PByte;
begin
 tex0:=texman.AllocImage(50,30,ipfARGB,0,'test0') as TTextureImage;
 tex1:=texman.AllocImage(100,100,ipfARGB,0,'test1') as TTextureImage;
 tex2:=texman.AllocImage(256,256,ipf565,aiTexture+aiRenderTarget,'test2') as TTextureImage;
 tex3:=texman.AllocImage(128,128,ipfARGB,aiTexture+aiRenderTarget,'test3') as TTextureImage;
 tex4:=texman.AllocImage(90,100,ipfARGB,aiTexture+aiRenderTarget,'test4') as TTextureImage;
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
 texman.MakeOnline(tex1);
end;

procedure TR2TextureTest.RenderFrame;
begin
// sleep(500);
 inc(frame);

 painter.BeginPaint(tex2);
 painter.Clear($80FF80,-1,-1);
 painter.FillGradrect(4,4,255-4,255-4,$FF000000+round(120+120*sin(frame/400)),$FF000000+round(120+120*sin(1+frame/300)),true);
 painter.DrawImage(20,20,tex1);

{ painter.SetTexMode(0,tblAdd,tblKeep);
 painter.DrawImage(140,30,tex0);}
 // Fixed! неправильный цвет при первой отрисовке!
{ painter.SetTexMode(1,tblReplace,tblReplace);
 painter.DrawDouble(140,30,tex1,tex0);}
 // Fixed! Прыгает в другое место со 2-го кадра
{ painter.SetTexMode(1,tblModulate2x,tblModulate,fltBilinear);
 painter.DrawDouble(140,30,tex1,tex0);}
 //
 painter.SetTexMode(1,tblInterpolate,tblInterpolate,fltBilinear,0.5);
 painter.DrawDouble(140,30,tex1,tex0);

 painter.EndPaint;

 painter.BeginPaint(tex3);
 painter.Clear(0,-1,-1);
 painter.FillRect(25,25,120,80,$FFE00000);
 painter.DrawImage(1,1,tex1,$FF808080);
 painter.DrawImage(50,50,tex1,$FF808080);
 painter.Rect(0,0,127,127,$FFFFFFFF);
 painter.EndPaint;

 painter.BeginPaint(tex4);
 painter.Clear(0,-1,-1);
 painter.FillRect(0,0,70,60,$FFFFFFE0);
{ device.SetRenderState(D3DRS_ZENABLE,0);
 device.SetRenderState(D3DRS_COLORWRITEENABLE,15);
 device.SetRenderState(D3DRS_ALPHABLENDENABLE,1);
 device.SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_ADD);
 device.SetRenderState(D3DRS_SRCBLEND,D3DBLEND_SRCALPHA);
 device.SetRenderState(D3DRS_DESTBLEND,D3DBLEND_INVSRCALPHA);}
 painter.DrawImage(40,40,tex1,$FF808080);
// device.SetRenderState(D3DRS_COLORWRITEENABLE,15);
// painter.DrawImage(-20,15,tex1,$FF808080);
 painter.EndPaint;
 painter.Restore;

 painter.BeginPaint(nil);
 painter.Clear($FF000000+(frame div 2) and 127,-1,-1);
 painter.Rect(10,10,450,350,$FF00C000);
 painter.DrawImage(140,400,tex0,$FF808080);
 painter.DrawImage(4,300,tex3,$FF808080);
 painter.DrawImage(4,4,tex2,$FF808080);
 painter.DrawImage(10,500,tex4,$FF808080);
 painter.DrawScaled(400+round(80*sin(1+frame/200)),200+round(80*sin(frame/300)),
                    600+round(80*sin(frame/240)),400+round(2+80*sin(frame/250)),tex2,$FF808080);
 painter.EndPaint;
end;

{ TToolsTest }

procedure TToolsTest.Done;
begin
 texman.FreeImage(tex1);
end;

procedure TToolsTest.Init;
var
 f:single;
 c:cardinal absolute f;
 i:integer;
begin
// LoadRasterFont('test.fnt');
// SetTXTFonts(1,1);
 tex1:=LoadImageFromFile('res\image.tga',liffMH256);
 tex2:=LoadImageFromFile('res\image.dds');
 tex3:=LoadImageFromFile('res\test3');
 tex4:=LoadImageFromFile('res\logo');
 //tex1:=LoadTexture('circle',0);
{ painter.SetTexMode(fltTrilinear);
 f:=0.5;
 device.SetTextureStageState(0,D3DTSS_MIPMAPLODBIAS,c);}
 t1:=texman.AllocImage(40,40,ipfARGB,0,'t1') as TTExtureImage;
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
 painter.Clear($FF000000+frame and 127,-1,-1);
 painter.BeginPaint(nil);
 painter.DrawImage(0,0,tex4);
// painter.DrawScaled(10,10,50+100+100*sin(frame/100),50+100+100*sin(frame/100),tex1,$FF808080);
 painter.DrawImage(10{+frame mod 200},10{+frame mod 200},tex1,$FF808080);
 painter.DrawImage(200,20,tex2,$FF808080);
 painter.DrawImage(400,20,tex3);
 painter.DrawImage(200,200,t1);
 painter.DrawImage(300,200,t2);
 painter.DrawImage(200,300,t3);
 painter.DrawImage(300,300,t4);
 painter.EndPaint;
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
 tex1:=texman.AllocImage(100,100,ipfARGB,0,'test1') as TTextureImage;
 tex2:=texman.AllocImage(113,113,ipfARGB,aiTexture,'test2') as TTextureImage;
 tex3:=texman.AllocImage(64,64,ipfARGB,aiTexture,'test3') as TTextureImage;
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
 painter.BeginPaint(nil);
 painter.Clear($FF000040);


 v:=t div 2000;
// if v mod 3=0 then painter.DrawImage(40,40,tex1);
 if true or (v mod 3=1) then begin
  painter.SetTexMode(1,tblInterpolate,tblModulate,fltBilinear,(t mod 2000)/2000);
  // плавный переход между двумя текстурами (в две стороны)
  painter.DrawDouble(40,40,tex2,tex1);
  painter.DrawDouble(150,40,tex1,tex2);
  // перемножение двух текстур
  painter.SetTexMode(1,tblModulate2X,tblModulate,fltBilinear);
  painter.DrawDouble(300,40,tex1,tex2);
 end;
// if v mod 3=2 then painter.DrawImage(40,40,tex2);

{ painter.DrawRotScaled(450,240,1,1,0,tex2);
 painter.DrawRotScaled(580.5,240,1,1,0,tex2);
 painter.DrawRotScaled(450,370.5,1,1,0,tex2);
 painter.DrawRotScaled(580.5,370.5,1,1,0,tex2);}

 // цвет от первой текстуры, альфа - пофигу
 painter.SetTexMode(1,tblKeep,tblKeep,fltUndefined);
 painter.DrawDoubleRotScaled(470,100,1,1,1,1,0,tex1,tex2);
 // цвет от второй текстуры, альфа - пофигу
 painter.SetTexMode(1,tblReplace,tblNone,fltUndefined);
 painter.DrawDoubleRotScaled(600,100,1,1,1,1,0,tex1,tex2);

 // цвет от первой текстуры, альфа - от третьей (вырезание круга из первой)
 painter.SetTexMode(1,tblKeep,tblReplace);
 painter.DrawDouble(20,190,tex1,tex3);
 // цвет - градиент, альфа - сплошная
 painter.SetTexMode(1,tblReplace,tblKeep);
 painter.DrawDouble(100,190,tex1,tex3);
 // цвет - сумма, альфа - круг
 painter.SetTexMode(1,tblAdd,tblModulate);
 painter.DrawDouble(180,190,tex1,tex3);
 // интерполяция цвета и альфы
 painter.SetTexMode(1,tblInterpolate,tblInterpolate,fltUndefined,0);
 painter.DrawDouble(180+80,190,tex1,tex3);
 painter.SetTexMode(1,tblInterpolate,tblInterpolate,fltUndefined,1);
 painter.DrawDouble(180+80*2,190,tex1,tex3);
 painter.SetTexMode(1,tblInterpolate,tblReplace,fltUndefined,0.5);
 painter.DrawDouble(180+80*3,190,tex1,tex3);

 painter.SetTexMode(1,tblDisable,tblDisable);

 // Текстурирование 1-й текстурой
 // ----------------------------------

 // цвет - фиксированный, альфа - из текстуры
 painter.SetTexMode(0,tblKeep,tblModulate);
 // Не работает! Потому что DrawXXX сама вызывает SetTexMode исходя из своих представлений, но только если тип отрисовки изменился с предыдущего вызова 
 painter.DrawImage(20,270,tex3,$FF30A040);
 // цвет из текстуры, альфа - сплошная
 painter.SetTexMode(0,tblReplace,tblKeep);
 painter.DrawImage(20+80,270,tex3,$C0202020);
 // цвет и альфа - суммируются
 painter.SetTexMode(0,tblAdd,tblAdd);
 painter.DrawImage(20+80*2,270,tex3,$50000080);

 // Возврат стандартного значения
 painter.ResetTexMode;

 // Original images
 painter.DrawImage(40,440,tex1);
 painter.DrawImage(210,440,tex2);
 painter.DrawImage(390,440,tex3); 

 painter.EndPaint;
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
 tex:=texman.AllocImage(19*2,19,ipfARGB,0,'particles') as TTextureImage;
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

 tex2:=texman.AllocImage(16,16,ipfARGB,0,'particles2') as TTextureImage;
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
// sleep(5);
 inc(frame);
 painter.Clear($FF000000,-1,-1);
 painter.BeginPaint(nil);
 painter.DrawImage(10,10,tex,$FF808080);
 painter.DrawImage(50,10,tex2,$FF808080);
 for i:=1 to 500 do with particles[i] do begin
  x:=120*cos(frame/100+i/9);
  y:=120*sin(frame/100+i/9);
  z:=sqr(1+i/200)/2-1.5+1.4*sin(frame/80);
  color:=$FF808080;
  scale:=1;
  angle:=0;
  index:=i mod 2;
 end;
 painter.DrawParticles(500,400,@particles,500,tex,19,3);
 for i:=1 to 50 do with particles[i] do begin
  x:=20*sin(frame/100+i*1.2)+25*cos(frame/130+i*1.04+2);
  y:=20*cos(frame/110+i*1.93)+25*sin(frame/120-i*1.56+4);
  z:=0;
  color:=$FF808080;
  scale:=3.5;
  angle:=0;
  index:=0;
 end;
 painter.SetMode(blAdd);
 painter.DrawParticles(100,100,@particles,50,tex2,19,1);
 painter.SetMode(blAlpha);
 painter.EndPaint;
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
 tex:=texman.AllocImage(19*2,19,ipfARGB,0,'particles') as TTextureImage;
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
 t:=gettickcount/1000;
 painter.Clear($FF000000,-1,-1);
 painter.BeginPaint(nil);
 painter.DrawImage(10,10,tex,$FF808080);
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

 painter.DrawBand(0,0,@p,n,tex,rect(0,0,19,1));
 painter.EndPaint;
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
 painter.Clear($FF000000+frame and 127,-1,-1);
 painter.BeginPaint(nil);

 painter.Rect(99,99,200,200,$FFF0C080);
 painter.SetClipping(rect(100,100,200,200));
 t:=frame/150;
 x:=150+round(50*cos(t));
 y:=150-round(50*sin(t));
 painter.FillRect(x-20,y-20,x+20,y+20,$FF3080C0);
 painter.ResetClipping;

 painter.Rect(299,99,400,200,$FF30C080);
 painter.SetClipping(rect(300,100,400,200));
 t:=frame/300;
 x:=350+round(50*cos(t));
 y:=150-round(50*sin(t));
 painter.FillRect(x-20,y-20,x+20,y+20,$FFD0A040);
 painter.ResetClipping;


 painter.EndPaint;
end;

{ T3DTest }

procedure T3DTest.Done;
begin

end;

procedure T3DTest.Init;
begin

end;

function MakeVertex(x,y,z:single;color:cardinal):TScrPoint;
begin
 fillchar(result,sizeof(result),0);
 result.x:=x; result.y:=y; result.z:=z; result.rhw:=1;
 result.diffuse:=color;
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
 painter.Clear($FF000000+frame and 127,1,-1);
 painter.BeginPaint(nil);
// painter.FillRect(10,10,20,20,$FF709090);

// painter.SetDefaultView;
 x:=1024/2; y:=768/2; z:=500;
 t:=frame/100;

 painter.SetPerspective(-30,30,-20,20,40,1,100);
// painter.SetOrthographic(30,0,100);

// painter.SetupCamera(Point3(20*sin(frame/100),-10,20*cos(frame/100)),Point3(0,0,0),Point3(0,1000,0));
// t:=1;
 painter.SetupCamera(Point3(20*cos(t),7,20*sin(t)),Point3(0,3,0),Point3(0,1000,00));
// if frame mod 200<100 then
// painter.SetupCamera(Point3(20,5,0),Point3(0,0,0),Point3(0,-1000,0));

 painter.Set3DTransform(IdentMatrix4); // вызывать обязательно!
 glDisable(GL_CULL_FACE);

 glEnable(GL_DEPTH_TEST);
 glDepthFunc(GL_LESS);

 pnt[1]:=TGLPainter2(painter).TestTransformation(Point3(0,3,0));
 pnt[2]:=TGLPainter2(painter).TestTransformation(Point3(0,10,0));
 pnt[3]:=TGLPainter2(painter).TestTransformation(Point3(0,0,10));

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

// painter.Set3DTransform(Matrix4(MultMat4(RotationYMat(frame/150),TranslationMat(490+20*sin(frame/500),390,350))));

{ vertices[0]:=MakeVertex(-10,-10,0,$FF00C000);
 vertices[1]:=MakeVertex(30,-10,0,$FF00C080);
 vertices[2]:=MakeVertex(30,30,0,$FFC0C000);
 vertices[3]:=MakeVertex(-10,30,0,$FF0000F0);
 painter.DrawIndexedMesh(@vertices[0],@indices[0],2,4,nil);


 painter.Set3DTransform(IdentMatrix4); // вызывать обязательно!

// painter.Set3DTransform();
 vertices[0]:=MakeVertex(100,100,0,$FF00C000);
 vertices[1]:=MakeVertex(200,100,0,$FF00C080);
 vertices[2]:=MakeVertex(200,200,0,$FFC0C000);
 vertices[3]:=MakeVertex(100,200,0,$FFC0C0C0);
 painter.DrawIndexedMesh(@vertices[0],@indices[0],2,4,nil);

 painter.FillRect(500,200,700,250,$FFC0B020);    }

{ painter.SetupCamera(Point3(0,0,0),
    Point3(x,y,0),
    Point3(x,y-1000,z));}

 glDisable(GL_DEPTH_TEST);

 painter.EndPaint;
end;

{ TTest }

procedure TTest.Done;
begin

end;

procedure TestSharpen;
var
 img:TTextureImage;
begin
 img:=LoadImageFromFile('e:\apus\projects\ah\images\cards\unicorn') as TTExtureImage;
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
 prog:=TGLPainter(painter).BuildShaderProgram(LoadFileAsString('shader.vert'),LoadFileAsString('shader.frag'));
 loc1:=glGetUniformLocation(prog,'offset');

 tex:=texman.AllocImage(256,256,ipfARGB,0,'tex') as TTextureImage;
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
    MyServis.ErrorMessage(e.message);
    halt;
  end;
 end;
end;

procedure TShaderTest.RenderFrame;
var
 d:double;
begin
 inc(frame);
 painter.BeginPaint(nil);
 painter.Clear($FF000040);
 painter.DrawImage(600,10,tex);
 glUseProgram(prog);
 d:=1+sin(0.003*(myTickCount mod $FFFFFF));
 glUniform1f(loc1,0.003*d);
 painter.DrawImage(600,300,tex);
 painter.Restore;
 //glUseProgram(0);
 painter.FillGradrect(50,50,300,200,$FFF04000,$FF60C000,false);
 painter.FillRect(30,100,500,120,$FF000000);
 painter.EndPaint;
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
 painter.Clear($FF000040);
 painter.BeginPaint(nil);
 painter.FillRect(30,100,500,120,$FFFFFF00);
 painter.EndPaint;
end;


begin

 if HasParam('-wnd') then wnd:=true;
 if HasParam('-fullscreen') then wnd:=false;
 testNum:=StrToIntDef(GetParam('test'),testNum);

// sleep(20000);
{ EncodeTime(1,2,3,0);
 FileDateToDateTime($11111111);
 FileDateToDateTime(1246734709);
 FileDateToDateTime(1246734709);}
 UseLogFile('log.txt');
 SetLogMode(lmVerbose);
// ShowMessage('OK!','');

{ GetMemoryManagerState(state);
 GetMem(p,1000);
 GetMemoryManagerState(state2);
 state.AllocatedMediumBlockCount:=1;
 state2.AllocatedMediumBlockCount:=1;}

// LoadRasterFont('e:\apus\projects\AstralMasters\fonts\astral24.fnt');

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
 end;

 {$IFDEF OPENGL}
 game:=MyGame.Create(true); // Создаем объект
 {$ELSE}
 game:=MyGame.Create(0); // Создаем объект
 {$ENDIF}
 game.showFPS:=true;

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
  VSync:=0;
 end;
 game.Settings:=s; // Задать установки

 game.Run; // Запустить движок

 InitUI;
 // А можно и не делать - можно это сделать в обработчике события

 savetime:=GetTickCount;
 repeat
  delay(50);
  // F12 - переключение режима
{  if (kbd.keys[68]<>0) and k then begin
   s.windowed:=not s.windowed;

   s.showSystemCursor:=s.windowed;
   game.settings:=s;
//   needBreak:=true;
  end;}
 until (GetAsyncKeyState(VK_ESCAPE)<>0) or (game.terminated);
 game.Stop;
// ShowMessage('Average FPS: '+FloatToStrF(1000*frame/(getTickCount-SaveTime),ffGeneral,6,1),'FPS');
end.
