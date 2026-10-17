// File image reload (ImageTools.ReloadFileImages) checks. Requires a GL window: the
// smoke suites only compile it, run it locally.
{$APPTYPE CONSOLE}
program TestImageReload;
uses
 {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
 SysUtils,Types,Apus.Core,Apus.Types,Apus.Images,Apus.Files,Apus.GfxFormats,Apus.EventMan,
 Apus.Engine.API,Apus.Engine.Types,Apus.Engine.Resources,Apus.Engine.ImageTools,Apus.Engine.GameApp,
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
 // A "layered" provider: for the image 'choice' the file named by choiceFile wins,
 // whatever its extension or age; everything else goes to the wrapped provider
 TLayerProvider=class(TInterfacedObject,IFileProvider,IFileSelector)
  next:IFileProvider;
  function SelectFile(const names:array of String8):integer;
  function FileExists(const fname:String8):boolean;
  function GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
  procedure Delete(const fname:String8);
  procedure Rename(const curName,newName:String8);
  function ListFiles(const path:String8; const mask:String8='*'):Strings8;
  function Map(const fname:String8; readOnly:boolean):TBuffer;
  procedure UnMap(fileData:TBuffer);
  function OpenRead(const fname:String8):TFileHandle;
  function Open(const fname:String8):TFileHandle;
  function OpenNew(const fname:String8):TFileHandle;
  procedure Close(f:TFileHandle);
  function Read(f:TFileHandle; buf:pointer; size:integer):integer;
  function Seek(f:TFileHandle; offset:int64; origin:integer):int64;
  function Position(f:TFileHandle):int64;
  function FileSize(f:TFileHandle):int64;
  function Write(f:TFileHandle; buf:pointer; size:integer):integer;
  procedure SetSize(f:TFileHandle; newSize:int64);
 end;

const
 RT_SIZE=16;
var
 rt:TTexture;
 img:TBitmapImage;
 root,shared,privateCopy,fullView,partView,cornerView,badImage,choice,choiceView,other:TTexture;
 dir,choiceFile:String8;

function TLayerProvider.SelectFile(const names:array of String8):integer;
 var i:integer;
 begin
  for i:=0 to high(names) do
   if (choiceFile<>'') and (Files.FixName(names[i])=Files.FixName(choiceFile)) then exit(i);
  result:=Files.SelectFile(names,next);
 end;
function TLayerProvider.FileExists(const fname:String8):boolean;
 begin result:=next.FileExists(fname); end;
function TLayerProvider.GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
 begin result:=next.GetFileInfo(fname,info); end;
procedure TLayerProvider.Delete(const fname:String8);
 begin next.Delete(fname); end;
procedure TLayerProvider.Rename(const curName,newName:String8);
 begin next.Rename(curName,newName); end;
function TLayerProvider.ListFiles(const path:String8; const mask:String8='*'):Strings8;
 begin result:=next.ListFiles(path,mask); end;
function TLayerProvider.Map(const fname:String8; readOnly:boolean):TBuffer;
 begin result:=next.Map(fname,readOnly); end;
procedure TLayerProvider.UnMap(fileData:TBuffer);
 begin next.UnMap(fileData); end;
function TLayerProvider.OpenRead(const fname:String8):TFileHandle;
 begin result:=next.OpenRead(fname); end;
function TLayerProvider.Open(const fname:String8):TFileHandle;
 begin result:=next.Open(fname); end;
function TLayerProvider.OpenNew(const fname:String8):TFileHandle;
 begin result:=next.OpenNew(fname); end;
procedure TLayerProvider.Close(f:TFileHandle);
 begin next.Close(f); end;
function TLayerProvider.Read(f:TFileHandle; buf:pointer; size:integer):integer;
 begin result:=next.Read(f,buf,size); end;
function TLayerProvider.Seek(f:TFileHandle; offset:int64; origin:integer):int64;
 begin result:=next.Seek(f,offset,origin); end;
function TLayerProvider.Position(f:TFileHandle):int64;
 begin result:=next.Position(f); end;
function TLayerProvider.FileSize(f:TFileHandle):int64;
 begin result:=next.FileSize(f); end;
function TLayerProvider.Write(f:TFileHandle; buf:pointer; size:integer):integer;
 begin result:=next.Write(f,buf,size); end;
procedure TLayerProvider.SetSize(f:TFileHandle; newSize:int64);
 begin next.SetSize(f,newSize); end;

procedure WriteImage(const name:String8;w,h:integer;color:cardinal);
var img:TBitmapImage;x,y:integer;bytes:ByteArray;
begin
 img:=TBitmapImage.Create(w,h,ipfARGB);
 try
  for y:=0 to h-1 do for x:=0 to w-1 do PCardinal(UIntPtr(img.ScanLine(y))+UIntPtr(x*4))^:=color;
  bytes:=SavePNG(img);Files.Save(name,bytes);
 finally img.Free;end;
end;
function Pixel(tex:TTexture):cardinal;
begin
 gfx.resman.MakeOnline(tex);tex.Lock(0,lmReadOnly);
 try result:=PCardinal(tex.data)^;finally tex.Unlock;end;
end;
// What the GPU actually samples: the texture stretched over a render target, read back
function Drawn(tex:TTexture):cardinal;
begin
 gfx.BeginPaint(rt);
 try
  gfx.target.Clear($FF000000,-1,-1);
  draw.Scaled(0,0,RT_SIZE,RT_SIZE,tex);
  gfx.CopyFromBackbuffer(0,0,img);
  result:=PCardinal(img.ScanLine(RT_SIZE div 2))^;
 finally
  gfx.EndPaint;
 end;
end;
function Sample:cardinal;
begin
 gfx.CopyFromBackbuffer(0,0,img);
 result:=PCardinal(img.ScanLine(RT_SIZE div 2))^;
end;
// Draw a view, reload, draw it again in the same paint pass: no shader switch in between,
// so the shaders API still has the view as the cached texture of its unit
function DrawnAcrossReload(view:TTexture;out before:cardinal):cardinal;
begin
 gfx.BeginPaint(rt);
 try
  gfx.target.Clear($FF000000,-1,-1);
  draw.Scaled(0,0,RT_SIZE,RT_SIZE,view);
  before:=Sample;
  ReloadFileImages;
  draw.Scaled(0,0,RT_SIZE,RT_SIZE,view);
  result:=Sample;
 finally
  gfx.EndPaint;
 end;
end;
function ReloadFails(const prefix:String8=''):boolean;
begin
 result:=false;
 try ReloadFileImages(prefix);except on EWarning do result:=true;end;
end;

procedure TestReload;
var original,reloaded:TTexture;count:integer;before,after:cardinal;
begin
 StartTest('Reload keeps shared/private handles, sampler settings and view geometry');
 WriteImage(dir+'main.png',4,4,$FFC81E0A);
 WriteImage(dir+'bad.png',4,4,$FF123456);
 root:=LoadImageFromFile(dir+'main.png');
 shared:=LoadImageFromFile(dir+'main.png');
 privateCopy:=LoadImageFromFile(dir+'main.png',liffAllowChange);
 root.name:='ReloadRoot';root.SetFilter(fltNearest);
 fullView:=root.Clone;partView:=root.ClonePart(Rect(1,1,3,3));
 cornerView:=root.ClonePart(Rect(0,0,4,2)); // full width: still a cropped view
 badImage:=LoadImageFromFile(dir+'bad.png');
 original:=root;
 Check(shared=root,'immutable file is shared');
 WriteImage(dir+'main.png',8,6,$FF0AB432);
 after:=DrawnAcrossReload(partView,before);
 Check(before=$FFC81E0A,'original content drawn');
 Check(after=$FF0AB432,'a view cached by the shaders API draws the new content');
 Check(Drawn(root)=$FF0AB432,'reloaded root draws the new content');
 Check((root=original) and (shared=root) and (TTexture.FindByName('ReloadRoot')=root),'references survive');
 Check(Pixel(root)=$FF0AB432,'shared GPU storage reloaded');
 Check(Pixel(privateCopy)=$FF0AB432,'private GPU storage reloaded');
 Check(root.HasFlag(tfImmutable) and not privateCopy.HasFlag(tfImmutable),'mutability preserved');
 Check(TGLTexture(root).filter=fltNearest,'requested sampler mode retained');
 Check((root.width=8) and (root.height=6) and (fullView.width=8) and (fullView.height=6),'full view follows size');
 Check((partView.width=2) and (abs(partView.u2-0.375)<0.0001),'partial view keeps pixel bounds');
 Check((cornerView.width=4) and (cornerView.height=2),'cropped view at the corner keeps its bounds');
 Check(TTexture.FindByFile(dir+'main.png')=root,'source registry keeps the original owner');
 EndTest;

 StartTest('A layered provider reselects the extension, lookup and view sources follow');
 WriteImage(dir+'choice.png',4,4,$FF112233);
 WriteImage(dir+'choice.jpg',4,4,$FF445566); // the loader detects the actual PNG format from bytes
 choiceFile:=dir+'choice.png';
 choice:=LoadImageFromFile(dir+'choice');choiceView:=choice.Clone;
 Check(Pixel(choice)=$FF112233,'initial layer file');
 choiceFile:=dir+'choice.jpg';ReloadFileImages;
 Check(Pixel(choice)=$FF445566,'new layer/extension is read');
 Check(choice.src=TTexture.SourceKey(choiceFile),'source key updates');
 Check(choiceView.src=choice.src,'view source key follows');
 reloaded:=LoadImageFromFile(dir+'choice');
 Check(reloaded=choice,'extensionless lookup shares the reloaded handle');FreeImage(reloaded);
 choiceFile:=dir+'choice.png';ReloadFileImages;
 Check(Pixel(choice)=$FF112233,'original extension restores');
 Check(TTexture.FindByFile(choiceFile)=choice,'file lookup restores');
 EndTest;

 StartTest('Prefix limits the reload');
 WriteImage(dir+'sub/other.png',2,2,$FF010101);
 other:=LoadImageFromFile(dir+'sub/other.png');
 WriteImage(dir+'sub/other.png',2,2,$FF020202);
 WriteImage(dir+'main.png',8,6,$FF030303);
 Check(ReloadFileImages(dir+'sub/')=1,'one image under the prefix');
 Check(Pixel(other)=$FF020202,'image under the prefix reloaded');
 Check(Pixel(root)=$FF0AB432,'image outside the prefix untouched');
 EndTest;

 StartTest('Decode/preflight failures keep all live images and release staged donors');
 count:=length(TTexture.FileImages);
 WriteImage(dir+'main.png',4,4,$FF010203);
 Files.Save(dir+'bad.png','not an image');
 Check(ReloadFails,'corrupt later source rejected');
 Check((root.width=8) and (Pixel(root)=$FF0AB432),'earlier decoded source was not committed');
 Check(length(TTexture.FileImages)=count,'failed staging leaves no file images');
 WriteImage(dir+'bad.png',4,4,$FF123456);
 WriteImage(dir+'main.png',1,1,$FF010203);
 Check(ReloadFails,'replacement smaller than a cropped view rejected');
 Check((root.width=8) and (Pixel(root)=$FF0AB432),'preflight preserves content');
 WriteImage(dir+'main.png',4,4,$FFC81E0A);
 ReloadFileImages;
 Check((root.width=4) and (fullView.width=4),'size restores');
 Check(abs(partView.u2-0.75)<0.0001,'UVs restore');
 Check((cornerView.width=4) and (cornerView.height=2),'cropped view stays cropped after a round trip');
 Check(Pixel(root)=$FFC81E0A,'original GPU pixels restored');
 EndTest;
end;

procedure TTestApp.SetupApplication;
begin
 inherited;appSetup.title:='TestImageReload';requestBackend.graphicsAPI:=gaOpenGL2;
 windowSetup.size:=MakeSize(320,200);
end;
procedure TTestApp.CreateScenes;
begin
 inherited;TTestScene.Create('Test',true,window);game.SwitchToScene('Test');
end;
function TTestScene.GetArea:TRect;
begin result:=Rect(0,0,window.canvasWidth,window.canvasHeight);end;
procedure TTestScene.Render;
var provider:TLayerProvider;
begin
 gfx.target.Clear($FF202020,-1,-1);inc(frame);if frame<>3 then exit;
 dir:=String8(ExtractFilePath(ParamStr(0)))+'../tests/_fpc/image-reload-fixture/';
 ForceDirectories(string(dir+'sub'));
 rt:=AllocImage(RT_SIZE,RT_SIZE,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestImageReloadRT');
 img:=TBitmapImage.Create(RT_SIZE,RT_SIZE,ipfARGB);
 provider:=TLayerProvider.Create;provider.next:=Files.GetProvider;
 Files.SetProvider(provider);
 try
  try TestReload;
  finally
   FreeImage(cornerView);FreeImage(partView);FreeImage(fullView);FreeImage(shared);FreeImage(root);
   FreeImage(privateCopy);FreeImage(badImage);FreeImage(other);
   FreeImage(choiceView);FreeImage(choice);
   Files.SetProvider(provider.next);
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
