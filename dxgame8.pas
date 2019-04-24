// DirectX version of the Game object
//
//
// Copyright (C) 2003-2011 Apus Software (www.games4win.com, www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by)
unit dxgame8;
interface
 uses EngineAPI,Images,engineTools,windows,classes,myservis,BasicGame;

type
 // Основной класс. Можно использовать его напрямую, но лучше унаследовать
 // от него свой собственный и определить для него события
 TDXGame8=class(TBasicGame)
 protected
  // Эти методы используются при смене режима работы (вызов только из главного потока)
  procedure InitGraph; override; // Инициализация графической части (переключить режим и все такое прочее)
  procedure DoneGraph; override; // Финализация графической части
  procedure ApplySettings; override;
  procedure SetupRenderArea; override;

  procedure PresentFrame; override;
  procedure ChoosePixelFormats(needMem:integer); override;
  function OnRestore:boolean; virtual; // Этот метод должен восстановить девайс и вернуть true если это удалось
  procedure InitObjects; override;
  {$IFDEF MSWINDOWS}
  procedure CaptureFrame; override;
  procedure ReleaseFrameData(obj:TRAWImage); override;
  {$ENDIF}
 public
  function GetStatus(n:integer):string; override;
 end;

implementation
 uses CrossPlatform,messages,SysUtils,DirectXGraphics,D3d8,cmdproc{$IFDEF DELPHI},graphics{$ENDIF},
     DxImages8,Painter8,EventMan,ImageMan,UIClasses,UIScene,gfxformats,Console;

{ TDXGame8 }

procedure TDXGame8.DoneGraph;
begin
 inherited;
 Done;
end;

function TDXGame8.GetStatus(n: integer): string;
begin
 case n of
  1:result:=inttostr(device.GetAvailableTextureMem div 1024);
  else result:='';
 end;
end;

// Эта процедура пытается установить запрошенный видеорежим
// В случае ошибки она просто бросит исключение
procedure TDXGame8.InitGraph;
var
 pparam:TD3DPresent_Parameters;
 mode,mode2:TD3DFormat;
 res:integer;
begin
 inherited;
 if params.mode.displayMode=dmFullScreen then begin
  params.width:=DisplayMode.Width;
  params.height:=displayMode.Height;
 end;
 // Заполним структуру параметров презентации
 if params.mode.displayMode<>dmSwitchResolution then begin
  pparam:=WindowedMode(window,params.width,params.height,0);
  pparam.SwapEffect:=D3DSWAPEFFECT_COPY;
{  pparam.SwapEffect:=D3DSWAPEFFECT_DISCARD;}
  mode:=pparam.BackBufferFormat;
 end else begin
  case params.colorDepth of
   15:mode:=D3DFMT_X1R5G5B5;
   16:mode:=D3DFMT_R5G6B5;
   24:mode:=D3DFMT_R8G8B8;
   32:mode:=D3DFMT_X8R8G8B8;
   else
    raise EError.Create('Invalid current video mode: this color depth not supported!');
  end;
  pparam:=FullScreenMode(window,params.width,params.height,mode,0,
     params.refresh,D3DPRESENT_INTERVAL_ONE,true);
 end;
 // Отдельная обработка Z/Stencil буфера
 if params.zbuffer>0 then begin
  if params.stencil then mode2:=D3DFMT_D24S8
    else begin
     if params.zbuffer=32 then
      mode2:=D3DFMT_D32;
     if params.zbuffer=24 then
      mode2:=D3DFMT_D24X8;
     if params.zbuffer=16 then
      mode2:=D3DFMT_D16;
    end;
  res:=d3d.CheckDeviceFormat(D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,mode,
       D3DUSAGE_DEPTHSTENCIL,D3DRTYPE_SURFACE,mode2);
  if res<0 then begin
   if params.stencil then mode2:=D3DFMT_D15S1
     else mode2:=D3DFMT_D16;
   res:=d3d.CheckDeviceFormat(D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,mode,
       D3DUSAGE_DEPTHSTENCIL,D3DRTYPE_SURFACE,mode2);
   if res<0 then
    raise EError.Create('ZBuffer/stencil format is not supported by HW');
  end;
  pparam.EnableAutoDepthStencil:=true;
  pparam.AutoDepthStencilFormat:=mode2;
 end;

 multithreaded:=true;
 // Debug useAdapter:=1;
 if device=nil then
  Init(window,pparam)
 else
  ChangeMode(pparam);

 ConfigureMainWindow;

 if device=nil then
  raise EError.Create('InitGraph: Invalid parameters! Try something else...');
 device.Clear(0,nil,D3DCLEAR_TARGET,$0,0.0,0);

 LogMessage('Screen mode: '+inttostr(pparam.BackBufferFormat));
 LogMessage(' ZBuffer: '+inttostr(pparam.AutoDepthStencilFormat));
 
 LogMessage('Supported pixel formats:');
 LogMessage(' 8bit: '+BoolToStr(support8bit,true));
 LogMessage('   A8: '+BoolToStr(supportA8,true));
 LogMessage(' ARGB: '+BoolToStr(supportARGB,true));
 LogMessage(' XRGB: '+BoolToStr(supportXRGB,true));
 LogMessage('  RGB: '+BoolToStr(supportRGB,true));
 LogMessage('  565: '+BoolToStr(support565,true));
 LogMessage('  555: '+BoolToStr(support555,true));
 LogMessage(' 1555: '+BoolToStr(support1555,true));
 LogMessage(' 4444: '+BoolToStr(support4444,true));
 LogMessage(' DXT1: '+BoolToStr(supportDXT1,true));
 LogMessage(' DXT2: '+BoolToStr(supportDXT2,true));
 LogMessage(' DXT3: '+BoolToStr(supportDXT3,true));
 LogMessage(' as render target:');
 LogMessage(' ARGB: '+BoolToStr(supportARGBrt,true));
 LogMessage(' XRGB: '+BoolToStr(supportXRGBrt,true));
 LogMessage('  RGB: '+BoolToStr(supportRGBrt,true));
 LogMessage('  565: '+BoolToStr(support565rt,true));
 LogMessage('  555: '+BoolToStr(support555rt,true));
 LogMessage(' 4444: '+BoolToStr(support4444rt,true));
 
 AfterInitGraph;
end;

procedure TDXGame8.ApplySettings;
var
 i:integer;
begin
 if running then begin // смена параметров во время работы
  if texman<>nil then (texman as TDXTextureMan).releaseAll;
  Signal('Debug\Settings Changing');
 end;
 if running then begin
  InitGraph;
  if texman<>nil then (texman as TDXTextureMan).ReCreateAll;
  if painter<>nil then (painter as TDXPainter8).Reset;
  for i:=low(scenes) to high(scenes) do
   scenes[i].ModeChanged;
 end;
end;


function TDXGame8.OnRestore:boolean;
begin
 result:=true;
 Signal('Engine\BeforeRestore');
 if texman<>nil then (texman as TDxTextureMan).ReleaseAll;
 // Reset device
 ChangeMode(d3d8.params);
 if texman<>nil then (texman as TDxTextureMan).ReCreateAll;
 if painter<>nil then (painter as TDXPainter8).Reset;
 Signal('Engine\AfterRestore');
end;

procedure TDXGame8.PresentFrame;
 var
  adr:pointer;
 begin
  if device=nil then exit;
  if params.mode.displayMode<>dmSwitchResolution then begin
   adr:=@displayRect;
   //SetWindowArea(params.width,params.height);
  end else adr:=nil;
  FLog('Present');
  StartMeasure(1);
  if device.Present(nil,adr,0,nil)<>0 then begin
   // Проверка на "потерянный" device
   if device.TestCooperativeLevel=D3DERR_DEVICENOTRESET then OnRestore;
  end else begin
   Flog('End');
   changed:=false; // перерисовка прошла успешно
   inc(FrameNum);
   // захват кадра
  end;
  EndMeasure2(1);
 end;

procedure TDXGame8.SetupRenderArea;
begin
  inherited;
  if painter<>nil then
   TDXPainter8(painter).Reset;
end;

procedure TDXGame8.ChoosePixelFormats(needMem:integer);
var
 list:array[1..10] of ImagePixelFormat;
 i,n:integer;
 memsize:integer;
begin
 memsize:=device.GetAvailableTextureMem div (1024*1024);
 n:=0;
 if supportARGB then begin inc(n); list[n]:=ipfARGB; end;
 if support4444 then begin inc(n); list[n]:=ipf4444; end;
 if n=0 then raise EError.Create('No available pixel formats with alpha!');
 if needMem>memsize then begin
  pfTrueColorAlpha:=list[n];
  pfTrueColorAlphaLow:=list[n];
 end else begin
  pfTrueColorAlpha:=list[1];
  pfTrueColorAlphaLow:=list[n];
 end;

 if support8bit and (caps.TextureCaps and D3DPTEXTURECAPS_ALPHAPALETTE>0) then begin
  // Поддержка есть
  PfIndexedAlpha:=ipf8Bit;
 end else begin
  // используем другие форматы
  if needmem<=1+memsize div 2 then
   PfIndexedAlpha:=list[1]
  else
   PfIndexedAlpha:=list[n];
 end;

 n:=0;
 if supportXRGB then begin inc(n); list[n]:=ipfXRGB; end;
 if supportARGB then begin inc(n); list[n]:=ipfARGB; end;
 if supportRGB then begin inc(n); list[n]:=ipfRGB; end;
 if support565 then begin inc(n); list[n]:=ipf565; end;
 if support555 then begin inc(n); list[n]:=ipf555; end;
 if support1555 then begin inc(n); list[n]:=ipf1555; end;
 if support4444 then begin inc(n); list[n]:=ipf4444; end;
 i:=1;
 while list[i] in [ipfXRGB,ipfARGB,ipfRGB] do inc(i);
 if i>n then i:=n;
 if needMem>memsize then begin
  pfTrueColor:=list[i];
  pfTrueColorLow:=list[i];
 end else begin
  pfTrueColor:=list[1];
  pfTrueColorLow:=list[i];
 end;

 if support8bit then
  pfIndexed:=ipf8bit
 else begin
  if needmem<=1+memsize div 2 then
   pfIndexed:=list[1]
  else
   pfIndexed:=list[i];
 end;

 pfRTAlphaNorm:=ipfNone;
 if support4444rt then pfRTAlphaNorm:=ipf4444;
 if supportARGBrt then pfRTAlphaNorm:=ipfARGB;
 if supportARGBrt then pfRTAlphaHigh:=ipfARGB else pfRTAlphaHigh:=pfRTAlphaNorm;
 if support4444rt then pfRTAlphaLow:=ipf4444 else pfRTAlphaLow:=pfRTAlphaNorm;
 pfRTnorm:=ipfNone;
 if supportRGBrt then pfRTnorm:=ipfRGB;
 if supportXRGBrt then pfRTnorm:=ipfXRGB;
 if support555rt then pfRTnorm:=ipf555;
 if support565rt then pfRTnorm:=ipf565;
 if support565rt then pfRTlow:=ipf565 else
  if support555rt then pfRTlow:=ipf555 else pfRTlow:=pfRTnorm;
 if supportRGBrt then pfRThigh:=ipfRGB else
  if supportXRGB then pfRThigh:=ipfXRGB else pfRThigh:=pfRTnorm;

end;

procedure TDXGame8.InitObjects;
var
 i:integer;
begin
  // Эвристическая формула
  i:=device.GetAvailableTextureMem div (1024*1024);
  if i>BestVidMem then i:=(i+BestVidMem*2) div 3 else
   if i>32 then i:=i-(i div 3);

  texman:=TDxTextureMan.Create(1024*i);
  painter:=TDxPainter8.Create(texman);
end;

// Видеозахват
{$IFDEF MSWINDOWS}
procedure TDxGame8.CaptureFrame;
var
 y,w,h:integer;
 surf,bbuf:IDirect3DSurface8;
 r:TD3DLocked_Rect;
 desc:TD3DSurfaceDesc;
 sour,dest:PByte;
 ipf:ImagePixelFormat;
 bmp:TBitmap;
 img:TRAWimage;
 needBMP:boolean;
begin
  device.GetBackBuffer(0,D3DBACKBUFFER_TYPE_MONO,bbuf);
  bbuf.GetDesc(desc);
  w:=desc.width;
  h:=desc.height;
  device.CreateImageSurface(w,h,desc.Format,surf);
  DxCall(device.CopyRects(bbuf,nil,0,surf,nil));
  ipf:=getIPF(desc.Format);
  img:=nil;
  surf.LockRect(r,nil,D3DLOCK_READONLY+D3DLOCK_NOSYSLOCK);
  img:=TRAWImage.Create;
  img.width:=w;
  img.height:=h;
  img.PixelFormat:=ipf;
  img.paletteFormat:=palNone;
  img.data:=r.pBits;
  img.pitch:=r.Pitch;
  img.tag:=UIntPtr(pointer(surf));
  surf._AddRef;
  screenshotDataRAW:=img;
  inherited;
end;

procedure TDXGame8.ReleaseFrameData(obj:TRAWImage);
var
 surf:IDirect3DSurface8;
begin
 if obj.tag<>0 then surf:=IDirect3DSurface8(pointer(obj.tag));
 obj.Free;
 surf.UnlockRect;
 surf._Release;
end;

{procedure TDXGame8.CaptureFrame;
var
 dc:HDC;
 w,h,n:integer;
 surf,bbuf:IDirect3DSurface8;
 r:TD3DLocked_Rect;
 desc:TD3DSurfaceDesc;
 f:file;
 st:string;
 img:TRAWimage;
begin
 w:=params.width;
 h:=params.height;
 if SingleFrameCapture then begin
  device.GetBackBuffer(0,D3DBACKBUFFER_TYPE_MONO,bbuf);
  bbuf.GetDesc(desc);
  device.CreateImageSurface(w,h,desc.Format,surf);
  DxCall(device.CopyRects(bbuf,nil,0,surf,nil));
  if jpegscreenmode then begin
   n:=1;
   if not DirectoryExists('screenshots') then
    CreateDir('screenshots');
   while (n<100) and (FileExists('screenshots\scr'+inttostr(n div 10)+inttostr(n mod 10)+'.jpg')) do inc(n);
   st:='screenshots\scr'+inttostr(n div 10)+inttostr(n mod 10)+'.jpg';
   surf.LockRect(r,nil,D3DLOCK_READONLY+D3DLock_NOSYSLOCK);
   img:=TRawImage.Create;
   img.width:=w;
   img.height:=h;
   img.data:=r.pBits;
   img.pitch:=r.Pitch;
   img.PixelFormat:=GetIPF(desc.Format);
   WriteJpeg(img,st,95);
   surf.UnlockRect;
   img.Free;
   capturedName:=st;
   capturedTime:=GetTickCount;
  end else begin
   device.GetFrontBuffer(surf);
   assign(f,'scrshot.raw');
   rewrite(f,1);
   surf.LockRect(r,nil,D3DLOCK_READONLY+D3DLock_NOSYSLOCK);
   blockwrite(f,r.pBits^,r.Pitch*h);
   surf.UnlockRect;
   close(f);
  end;
  singleFrameCapture:=false;
  exit;
 end;
 while (GetTickCount<CapTime) or (flag<>0) do sleep(0);
 capTime:=GetTickCount+35;
 dc:=CreateDC('DISPLAY','',nil,nil);
 BitBlt(bmp.canvas.handle,0,0,w,h,dc,0,0,SRCCOPY);
 deleteDC(dc);
 flag:=1; // сигнал о том, что можно начинать упаковку кадра в потоке паковщика
end;   }
{
procedure SaveFrame;
var
 f:file;
 st:string;
 i,j,size:integer;
 pb:PByte;
begin
 st:='0000';
 j:=screenN;
 for i:=4 downto 1 do begin
  st[i]:=chr(ord('0')+j mod 10);
  j:=j div 10;
 end;
 assign(f,'capture\frame'+st+'.raw');
 rewrite(f,1);
 blockwrite(f,capBuffer^,saveValue);
 close(f);
 size:=capWidth*capHeight*2;
 getmem(frames[screenN],size-savevalue);
 pb:=capBuffer;
 inc(pb,saveValue);
 move(pb^,frames[screenN]^,size-saveValue);
end;

procedure TCapThread.execute;
var
 i,j,k,y,size:integer;
 pb:PByte;
 p1,p2:pointer;
 f:file;
 st:string;
begin
 saveValue:=1024*256; // сохранять столько на диск, остальное - в памяти
 // расчет таблиц
 for i:=0 to 255 do begin
  enTab[i]:=round((i*i+i*256-1500)/4150);
  enTab[i+256]:=round((i*i+i*256-800)/2054);
 end;
 repeat
  while flag<1 do sleep(0);
  if flag=1 then begin
   // упаковка кадра
   if ScreenN>=2000 then continue;
   inc(screenN);
   pb:=capBuffer;
   // уменьшение картинки в 2 раза
   for y:=0 to capHeight-1 do begin
    p1:=bmp.ScanLine[y*2];
    p2:=bmp.ScanLine[y*2+1];
    asm
     pushad
     mov esi,p1
     mov ebx,p2
     mov edi,pb
     mov ecx,512
     pxor mm0,mm0
@01: movq mm1,[esi]
     movq mm2,[ebx]
     add esi,8
     movq mm3,mm1
     add ebx,8
     movq mm4,mm2
     punpcklbw mm1,mm0
     punpckhbw mm3,mm0
     punpcklbw mm2,mm0
     punpckhbw mm4,mm0
     paddusw mm1,mm3
     paddusw mm2,mm4
     paddusw mm1,mm2
     psrlw mm1,2
     packuswb mm1,mm0
     push ebx
     movd eax,mm1
     // конвертация в формат 5-6-5 с табличной трансформацией
     movzx edx,al
     add edx,offset EnTab
     mov bl,[edx]
     shr eax,8
     movzx edx,ah
     add edx,offset EnTab
     mov bh,[edx]
     shl bh,3
     movzx edx,al
     add edx,offset EnTab
     movzx edx,[edx+256]
     shl edx,5
     or ebx,edx
     mov word ptr [edi],bx
     pop ebx
     add edi,2
     dec ecx
     jnz @01
     popad
     emms
    end;
    inc(pb,capWidth*2);
   end;

   SaveFrame;

   flag:=0; // упаковка закончена
  end;
 until terminated or (flag=2);
 // сохранение оставшихся кусков данных
 for k:=1 to screenN do begin
  st:='0000';
  j:=k;
  for i:=4 downto 1 do begin
   st[i]:=chr(ord('0')+j mod 10);
   j:=j div 10;
  end;
  assign(f,'capture\frame'+st+'.raw');
  reset(f,1);
  seek(f,filesize(f));
  size:=capWidth*capheight*2;
  blockwrite(f,frames[k]^,size-saveValue);
  close(f);
  freemem(frames[k]);
  if k mod 2=0 then sleep(0);
 end;
end;

procedure StartCapture(game:TDXGame8);
var
 h,w:integer;
begin
 createDir('capture');
 bmp:=TBitmap.Create;
 bmp.PixelFormat:=pf32bit;
 w:=game.params.width;
 h:=game.params.height;
 capWidth:=w div 2;
 capHeight:=h div 2;
 bmp.Width:=w; bmp.Height:=h;
 getmem(capBuffer,capWidth*capHeight*2);
 capThread:=TCapThread.Create(false);
end;

procedure FinishCapture;
begin
 while flag<>0 do sleep(0);
 flag:=2;
 bmp.Free;
 FreeMem(capBuffer);
end;    }

{$ENDIF}


end.
