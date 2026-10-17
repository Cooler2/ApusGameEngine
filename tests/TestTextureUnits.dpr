// Texture unit layout checks: work on a texture (uploads, readback, parameters) never
// changes what a sampling unit holds, engine units above the user stages are sampled.
// Every check runs with the detected GL features and in the baseline mode.
// Requires a GL window: the smoke suites only compile it, run it locally.
{$APPTYPE CONSOLE}
program TestTextureUnits;
uses
 {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
 SysUtils,Types,Apus.Core,Apus.Images,Apus.EventMan,
 Apus.Engine.API,Apus.Engine.Types,Apus.Engine.Resources,Apus.Engine.GameApp,
 Apus.Engine.Scene,Apus.Engine.ResManGL;
{$I ..\Base\tests\Test.inc}
type
 TTestApp=class(TGameApplication)
  procedure SetupApplication;override;
  procedure CreateScenes;override;
 end;
 TTestScene=class(TGameScene)
  frame:integer;
  procedure Render;override;
  function GetArea:TRect;override;
 end;

const
 RT_SIZE=16;
 RED=$FFC81E0A;
 GREEN=$FF0AB432;
 BLUE=$FF1E3CC8;
 GRAY=$FF808080;
 YELLOW=$FFC8B40A;
 // which texture the custom shader shows
 SHOW_STAGE3=0;
 SHOW_NORMALMAP=1;
 SHOW_SHADOWMAP=2;
 VERTEX_SRC=
  '#version 330'#10+
  'uniform mat4 MVP;'#10+
  'layout (location=0) in vec3 position;'#10+
  'layout (location=1) in vec4 color;'#10+
  'layout (location=2) in vec2 texCoord;'#10+
  'out vec2 vTexCoord;'#10+
  'void main(void) { gl_Position = MVP*vec4(position,1.0); vTexCoord = texCoord; }'#10;
 // the samplers carry the names the shaders API binds: user stage 3 and the engine units
 FRAGMENT_SRC=
  '#version 330'#10+
  'uniform sampler2D tex3;'#10+
  'uniform sampler2D normalMap;'#10+
  'uniform sampler2D texShadowMap;'#10+
  'uniform int show;'#10+
  'in vec2 vTexCoord;'#10+
  'out vec4 fragColor;'#10+
  'void main(void) {'#10+
  '  if (show==0) fragColor = texture(tex3,vTexCoord);'#10+
  '  else if (show==1) fragColor = texture(normalMap,vTexCoord);'#10+
  '  else fragColor = texture(texShadowMap,vTexCoord);'#10+
  '}'#10;
var
 rt:TTexture;
 img:TBitmapImage;
 unitShader:TShader;

function SolidTexture(color:cardinal;const name:String8):TTexture;
var data:array[0..15] of cardinal;i:integer;
begin
 for i:=0 to high(data) do data[i]:=color;
 result:=AllocImage(4,4,ipfARGB,0,name);
 result.Upload(@data,16,ipfARGB);
end;
function Sample:cardinal;
begin
 gfx.CopyFromBackbuffer(0,0,img);
 result:=PCardinal(img.ScanLine(RT_SIZE div 2))^;
end;
function DrawnNow(tex:TTexture):cardinal;
begin
 draw.Scaled(0,0,RT_SIZE,RT_SIZE,tex);
 result:=Sample;
end;
function DrawnByShader(show:integer;tex:TTexture):cardinal;
begin
 shader.UseCustom(unitShader);
 shader.SetUniform('show',show);
 try
  result:=DrawnNow(tex);
 finally
  shader.Reset;
 end;
end;

// The same texture is drawn before and after each operation in one paint pass, so the
// shaders API has it cached for stage 0 and does not bind it again
procedure TestWorkOnTextures(const mode:String8);
var a,b,c:TTexture;data:array[0..15] of cardinal;i:integer;
 drawn,afterUpload,afterNew,afterRead,afterFilter,readBack:cardinal;
begin
 StartTest('Work on other textures keeps sampling units ('+mode+')');
 a:=SolidTexture(RED,'unitsA');b:=SolidTexture(GREEN,'unitsB');c:=nil;
 try
  gfx.BeginPaint(rt);
  try
   gfx.target.Clear($FF000000,-1,-1);
   drawn:=DrawnNow(a);
   for i:=0 to high(data) do data[i]:=BLUE;
   b.UploadPart(0,0,0,4,4,@data,16,ipfARGB);
   afterUpload:=DrawnNow(a);
   c:=AllocImage(4,4,ipfARGB,0,'unitsC');
   c.Lock;
   try for i:=0 to 15 do PCardinal(UIntPtr(c.data)+UIntPtr(i*4))^:=GRAY;finally c.Unlock;end;
   gfx.resman.MakeOnline(c); // the first upload creates the GL texture
   afterNew:=DrawnNow(a);
   b.Lock(0,lmReadOnly); // the partial upload made the CPU copy obsolete: read back from GL
   try readBack:=PCardinal(b.data)^;finally b.Unlock;end;
   afterRead:=DrawnNow(a);
   b.SetFilter(fltNearest);
   afterFilter:=DrawnNow(a);
  finally
   gfx.EndPaint;
  end;
  Check(drawn=RED,'texture drawn');
  Check(afterUpload=RED,'partial upload of another texture');
  Check(afterNew=RED,'first upload of a new texture');
  Check(readBack=BLUE,'readback returns the uploaded pixels');
  Check(afterRead=RED,'readback of another texture');
  Check(afterFilter=RED,'filter change of another texture');
 finally
  FreeImage(c);FreeImage(b);FreeImage(a);
 end;
 EndTest;
end;

procedure TestEngineUnits(const mode:String8);
var user,normal,shadowTex,dummy:TTexture;stage3,normalDrawn,shadowDrawn:cardinal;
begin
 StartTest('Engine units above the user stages ('+mode+')');
 user:=SolidTexture(YELLOW,'unitsUser');normal:=SolidTexture(BLUE,'unitsNormal');
 shadowTex:=SolidTexture(GREEN,'unitsShadow');dummy:=SolidTexture(RED,'unitsDummy');
 try
  gfx.BeginPaint(rt);
  try
   gfx.target.Clear($FF000000,-1,-1);
   shader.UseTexture(user,3);
   shader.NormalMap(normal);
   shader.Shadow(shadowMainPass,shadowTex);
   stage3:=DrawnByShader(SHOW_STAGE3,dummy);
   normalDrawn:=DrawnByShader(SHOW_NORMALMAP,dummy);
   shadowDrawn:=DrawnByShader(SHOW_SHADOWMAP,dummy);
  finally
   shader.Shadow(shadowDisabled);
   shader.NormalMapOff;
   shader.UseTexture(nil,3);
   gfx.EndPaint;
  end;
  Check(stage3=YELLOW,'user stage 3 keeps its texture with a normal map set');
  Check(normalDrawn=BLUE,'normal map sampled from its unit');
  Check(shadowDrawn=GREEN,'shadow map sampled from its unit');
 finally
  FreeImage(dummy);FreeImage(shadowTex);FreeImage(normal);FreeImage(user);
 end;
 EndTest;
end;

procedure TTestApp.SetupApplication;
begin
 inherited;appSetup.title:='TestTextureUnits';requestBackend.graphicsAPI:=gaOpenGL2;
 windowSetup.size:=MakeSize(320,200);
end;
procedure TTestApp.CreateScenes;
begin
 inherited;TTestScene.Create('Test',true,window);game.SwitchToScene('Test');
end;
function TTestScene.GetArea:TRect;
begin result:=Rect(0,0,window.canvasWidth,window.canvasHeight);end;
procedure TTestScene.Render;
var detected,baseline:TGLFeatures;features:String8;
begin
 gfx.target.Clear($FF202020,-1,-1);inc(frame);if frame<>3 then exit;
 rt:=AllocImage(RT_SIZE,RT_SIZE,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestTextureUnitsRT');
 img:=TBitmapImage.Create(RT_SIZE,RT_SIZE,ipfARGB);
 detected:=glFeatures;
 Mem.Clear(baseline,sizeof(baseline));
 if detected.dsa then features:='DSA' else features:='no DSA: baseline only';
 try
  try
   unitShader:=shader.Build(VERTEX_SRC,FRAGMENT_SRC);
   TestWorkOnTextures(features);
   TestEngineUnits(features);
   glFeatures:=baseline;
   TestWorkOnTextures('baseline');
   TestEngineUnits('baseline');
  finally
   glFeatures:=detected;
   FreeImage(rt);img.Free;
  end;
 except on e:Exception do begin writeln('EXCEPTION: ',e.Message);inc(testsFailed);end;end;
 Signal('Engine\Cmd\Exit');
end;

var app:TTestApp;
begin
 app:=TTestApp.Create;
 try app.Prepare;app.Run;finally app.Free;end;
 if testsFailed=0 then writeln('All tests passed ('+IntToStr(testsTotal)+')')
 else begin writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));ExitCode:=1;end;
 if IsDebuggerPresent then readln;
end.
