// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit ShadersMain;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses Apus.CrossPlatform,Apus.EventMan,Apus.Colors,
   Apus.Engine.Types, Apus.Engine.Graphics;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Initialize; override;
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;
  img:TTexture;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  useRealDPI:=false;
  //usedPlatform:=spSDL;   // alternative cross-platform solution
  //directRenderOnly:=true; // draw to backbuffer (instead of a screen-size RT-texture for post-processing)
  //windowedMode:=false;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  // (this will wait in a separate thread until scene's Load() is executed
  game.SwitchToScene('Main');  
 end;

const
 TICK_IMAGE = '20 1F ((((~SSS(SSS^SSSESSSDSSS_SSSBSSS &A(*-+&@(*+$&>(%$)*&=(*-$)*&=(*+$+*&=(*+$+*&=(*$)+*&<(%&()*'+
   '&<(*-&()*&<(*,&()/*&;(*-&(),*&<(*&()-*&<(*&().*&<(*+&()*&<(*+&()*&1(&(*&+(*.&(),*&0(*/++,*&)(*,&()+*&0(*-&().*'+
   '&((*&))*&1(.&*)/*#*+&(),*&1(*+&))+*(*-&().*&3(*+&)),%&))*&5(*&*)*&)),*&5(*,&))+&()+*&7(*&.)/*&7(*,&,).*&9(*&,)*'+
   '&:(*,&*)!\SSS*&;(*&))+*&<(*.$)-*&>(*$-*&?(*.%&:(';

{ TMainScene }
procedure TMainScene.Initialize;
 begin
  img:=CreateImageFrom(TICK_IMAGE);
 end;

const
 rShader=
   ' uniform vec4 bColor;'#13#10+
   ' uniform vec4 fillColor;'#13#10+
   ' uniform vec2 offset;'#13#10+
   ' uniform vec4 tresh;'#0+
   ' vec2 rr = max(abs(vTexCoord)-offset,0.0);'#13#10+
   ' float r = dot(rr,rr);'#13#10+
   ' if (r>tresh.y) discard;'#13#10+
   ' float alpha=1.0-smoothstep(tresh.x, tresh.y, r);'#13#10+
   ' vec4 color = mix(fillColor,bColor,smoothstep(tresh.z,tresh.w,r)); '#13#10+
   ' fragColor = vec4(color.rgb, color.a*alpha); ';

procedure DrawRRect(x0,y0,width,height:single;r,borderWidth:single;color:cardinal);
 var
  vrt:array[0..3] of TVertex;
  sx1,sy1,sx2,sy2,w,h:single;
 begin
  w:=width/2; h:=height/2;
  shader.UseCustomized(rShader,0);
  shader.SetUniform('bColor',TShader.VectorFromColor($FF00D0F0));
  shader.SetUniform('fillColor',TShader.VectorFromColor($FF405030));
  shader.SetUniform('offset',TVec2.Init(w-r,h-r));
  shader.SetUniform('tresh',TQuat.Init(sqr(r-1),sqr(r),sqr(r-borderWidth-1),sqr(r-borderWidth)));
  sx1:=x0-w; sx2:=x0+w;
  sy1:=y0-h; sy2:=y0+h;
  vrt[0].Init(sx1,sy1,0,-w,-h,color);
  vrt[1].Init(sx2,sy1,0,w,-h,color);
  vrt[2].Init(sx2,sy2,0,w,h,color);
  vrt[3].Init(sx1,sy2,0,-w,h,color);
  renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.layoutTex);
  shader.Reset;
 end;

procedure TMainScene.Render;
 var
  i,j,x,y:integer;
  t:double;
 begin
  gfx.target.Clear($406080); // clear with blue
  t:=window.frameStartMs*0.002;

  draw.RoundRect(TVec2.Init(150.5,20.5),16,16,8,1,$FFC0A030,$FF101010);

  //DrawRRect(250,100,150,60,10,1,$FFC0A030);
  draw.FillRRect(100,100,250,160,$FFC0A030,10);
  draw.RoundRect(TVec2.Init(150,200),151,61,10,1,$FFC0A030,$FF101010);
  draw.RoundRect(TVec2.Init(150,300),151,61,6,2,$FFC0A030,0);
  draw.FillRect(100,400,150,440,clBlack);
  draw.RoundRect(100,400,150,440,2,2,$FFC0A030,$FF305080);

  draw.RoundRect(300,100,360,140,8,2+2*sin(t),$FFC0A030,$FF305080);
  draw.RoundRect(300,150,360,190,15+14*sin(t),2,$FFC0A030,$FF305080);
  draw.RoundRect(TVec2.Init(340,250),40+10*sin(t),30+6*sin(t+1),10,1.5,$FFC0A030,$FF305080);

  draw.Image(10,10,img,clBlack);
  draw.Image(10,50,img,clWhite);
  draw.Scaled(60,20,0.5,img,clBlack);
  draw.Scaled(60,60,0.5,img,clWhite);

{  for i:=1 to 10 do
   for j:=0 to 28 do begin
    x:=j*80+5;
    y:=i*18;
    draw.RoundRect(TVec2.Init(400+i*45,20+j*25),41,21,5,1,clWhite,0);
    //txt.WriteW(0,400+i*45,25+j*25,clWhite,'Hello',taCenter);
   end;}

{ for i:=1 to 40 do
   for j:=0 to 11 do begin
    x:=j*80+5;
    y:=i*18;
//    draw.FillRect(x,y-10,x+10,y,clWhite);
    txt.WriteW(0,x+15,y,clWhite,'Hello');
   end;}


  inherited; // this will draw the UI elements
 end;

end.
