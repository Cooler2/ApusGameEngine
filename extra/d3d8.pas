// -----------------------------------------------------
// Direct3D-8 specific functionality
// Author: Ivan Polyacov (C) 2003, Apus Software
// Mail me: ivan@games4win.com or cooler@tut.by
// ------------------------------------------------------
unit d3d8;
interface
 uses DirectXGraphics,images;

const
 D3DIdentMat:TD3DMatrix=(_11:1;_12:0;_13:0;_14:0;
                         _21:0;_22:1;_23:0;_24:0;
                         _31:0;_32:0;_33:1;_34:0;
                         _41:0;_42:0;_43:0;_44:1);
 // Форматы вершин
 VertexFmt=D3DFVF_XYZ+D3DFVF_NORMAL+D3DFVF_DIFFUSE+D3DFVF_SPECULAR;
 VertexNFmt=D3DFVF_XYZ+D3DFVF_NORMAL;
 VertexFmt2=D3DFVF_XYZ+D3DFVF_NORMAL+D3DFVF_TEX1+D3DFVF_TEXTUREFORMAT2;
 VertexLitFmt=D3DFVF_XYZ+D3DFVF_DIFFUSE;
 VertexLitFmt2=D3DFVF_XYZ+D3DFVF_DIFFUSE+D3DFVF_TEX1+D3DFVF_TEXTUREFORMAT2;
 VertexScrFmt=D3DFVF_XYZRHW++D3DFVF_DIFFUSE+D3DFVF_SPECULAR+D3DFVF_TEX1+D3DFVF_TEXTUREFORMAT2;

type
 // Структуры вершин
 Vertex=record
  x,y,z:single;
  nx,ny,nz:single;
  color,specular:cardinal;
 end;
 VertexN=record
  x,y,z:single;
  nx,ny,nz:single;
 end;
 Vertex2=record
  x,y,z:single;
  nx,ny,nz:single;
  u,v:single;
 end;
 VertexLit=record
  x,y,z:single;
  color:cardinal;
 end;
 VertexLit2=record
  x,y,z:single;
  color:cardinal;
  u,v:single;
 end;
 VertexScr=record
  x,y,z,rhw:single;
  color,specular:cardinal;
  u,v:single;
 end;

 TResolution=record
  width,height:integer;
 end;

var
 // Underlying interfaces
 d3d:IDirect3d8;
 device:IDirect3dDevice8;
 line:integer;

 // Information
 primaryAdapter:TD3DAdapter_Identifier8;
 adapters:array[0..3] of TD3DAdapter_Identifier8;
 adaptersCnt:integer;
 useAdapter:cardinal=D3DADAPTER_DEFAULT; // какой адаптер использовать

 resolutions:array[1..50] of TResolution;


 // Current settings
 initialized:boolean;          // true - девайс создан и можно работать
 fullscreen:boolean;           // текущий режим - полноэкранный

 // Requested features
 multithreaded:boolean=false;

 CAPS:TD3DCaps8;                // фичи основной видеокарты - in only
 DisplayMode:TD3DDisplayMode;   // Текущий режим экрана (начальный) - in only
 params:TD3DPresent_Parameters; // параметры для девайса (in/out)
 zbuffer:boolean;               // используется ли zbuffer
 stencil:integer;               // глубина stencil-буфера
 // Поддерживаемые форматы пикселя для обычных текстур
 support8bit:boolean;           // после переключения режима - true = поддерживаются 8-битные текстуры
 supportA8:boolean;
 support4444:boolean;
 support565:boolean;
 support555:boolean;
 support1555:boolean;
 supportRGB:boolean;
 supportXRGB:boolean;
 supportARGB:boolean;
 supportDXT1:boolean;
 supportDXT2:boolean;
 supportDXT3:boolean;
 supportDXT4:boolean;
 supportDXT5:boolean;
 // Поддерживаемые форматы пикселя для текстур, в которые можно рендерить
 supportARGBrt:boolean;
 supportXRGBrt:boolean;
 supportRGBrt:boolean;
 support565rt:boolean;
 support555rt:boolean;
 support4444rt:boolean;

 // поддерживаемые разрешения
 support640x480:boolean;
 support800x600:boolean;
 support1024x768:boolean;
 support1024x600:boolean;
 support1280x800:boolean;
 support1280x960:boolean;
 support1280x1024:boolean;
 support1360x768:boolean;
 support1440x900:boolean;
 support1600x900:boolean;
 support1600x1200:boolean;
 support1680x1050:boolean;
 support1920x1080:boolean;
 support1920x1200:boolean;

 // Инициализация D3D: создание девайса
 procedure Init(hwnd:cardinal;mode:TD3DPresent_Parameters;PreferHW:boolean=true);
 // Изменение режима
 procedure ChangeMode(newmode:TD3DPresent_Parameters);
 // Завершение работы
 procedure Done;

 // Подготовка структуры для задания оконного режима
 // Обновление окна не чаще чем раз в vsync кадров (0..4, 0 -> немедленно)
 // zstencil = 0 если не нужен автосоздаваемый z-буфер
 function WindowedMode(hwnd,width,height:integer;
                       zstencil:TD3DFormat):TD3DPresent_Parameters;
 // То же самое для полноэкранного режима (если указанное разрешение не поддерживается - выберет наиболее близкое большее данного)
 // keepAspect - выбирать только режимы с пропорцией монитора
 function FullScreenMode(hwnd,width,height:integer;format,zstencil:TD3DFormat;
                         refresh,vsync:integer;keepAspect:boolean=false):TD3DPresent_Parameters;

{ procedure GetTexInfo(tex:IDirect3DTexture8;
                      var width,height:integer;var format:TD3DFormat;
                      var pool:d3dPool;var levels:integer);}

 // z=-1, stencil=-1 - не очищать
 procedure ClearViewPort(color:cardinal;z:single;stencilVal:integer);

 procedure StoreViewPort;    // Save viewport in stack
 procedure RestoreViewPort;  // Restore viewport from stack

 procedure SetDefaultRT; // Set render target to back buffer

 function AllocPalette:integer;
 procedure SetPersistentPalette(index:integer;var data);
 procedure FreePalette(index:integer);

 procedure DxCall(res:HResult;msg:string='');

 procedure DumpD3D(name:integer=1);

 function GetFormatName(format:TD3DFormat):string;
 function GetD3Dformat(pixfmt:ImagePixelFormat):integer;
 function GetIPF(pixfmt:integer):ImagePixelFormat;

implementation
 uses CrossPlatform,windows,MyServis,SysUtils;

type
 PalData=record
  index:integer;
  data:pointer;
 end;
var
 wnd:cardinal;

 palUsage:array[0..1023] of byte;

 palettes:array[0..255] of PalData;
 palcnt:integer;

 viewports:array[1..15] of TD3DViewport8;
 vpcount:integer;

function GetFormatName(format:TD3DFormat):string;
 begin
  case format of
   D3DFMT_A8R8G8B8:result:='A8R8G8B8';
   D3DFMT_X8R8G8B8:result:='X8R8G8B8';
   D3DFMT_R8G8B8:result:='R8G8B8';
   D3DFMT_R5G6B5:result:='R5G6B5';
   D3DFMT_A1R5G5B5:result:='A1R5G5B5';
   D3DFMT_X1R5G5B5:result:='X1R5G5B5';
   D3DFMT_A4R4G4B4:result:='A4R4G4B4';
   D3DFMT_DXT1:result:='DXT1';
   D3DFMT_DXT2:result:='DXT2';
   D3DFMT_DXT3:result:='DXT3';
   D3DFMT_DXT4:result:='DXT4';
   D3DFMT_DXT5:result:='DXT5';
   D3DFMT_A8:result:='A8';
   D3DFMT_A8P8:result:='A8P8';
   D3DFMT_P8:result:='P8';
   D3DFMT_L8:result:='L8';
   D3DFMT_A4L4:result:='A4L4';
   D3DFMT_V8U8:result:='V8U8';
   D3DFMT_L6V5U5:result:='L6V5U5';
   D3DFMT_X8L8V8U8:result:='X8L8V8U8';
   D3DFMT_V16U16:result:='V16U16';
   D3DFMT_W11V11U10:result:='W11V11U10';
   D3DFMT_Q8W8V8U8:result:='Q8W8V8U8';
   D3DFMT_UNKNOWN:result:='Unknown';
  end;
 end;

function GetD3Dformat(pixfmt:ImagePixelFormat):integer;
begin
 case PixFmt of
  ipf555:result:=D3DFMT_X1R5G5B5;
  ipf1555:result:=D3DFMT_A1R5G5B5;
  ipf565:result:=D3DFMT_R5G6B5;
  ipf4444:result:=D3DFMT_A4R4G4B4;
  ipfRGB:result:=D3DFMT_R8G8B8;
  ipfARGB:result:=D3DFMT_A8R8G8B8;
  ipfXRGB:result:=D3DFMT_X8R8G8B8;
  ipfDXT1:result:=D3DFMT_DXT1;
  ipfDXT2:result:=D3DFMT_DXT2;
  ipfDXT3:result:=D3DFMT_DXT3;
  ipfDXT5:result:=D3DFMT_DXT5;
  ipf8Bit:result:=D3DFMT_P8;
  ipfA8:result:=D3DFMT_A8;
  else raise EError.Create('GetD3Dfmt: unsupported format '+inttostr(ord(pixfmt)));
 end;
end;

function GetIPF(pixfmt:integer):ImagePixelFormat;
begin
 case PixFmt of
  D3DFMT_X1R5G5B5:result:=ipf555;
  D3DFMT_A1R5G5B5:result:=ipf1555;
  D3DFMT_R5G6B5:result:=ipf565;
  D3DFMT_A4R4G4B4:result:=ipf4444;
  D3DFMT_R8G8B8:result:=ipfRGB;
  D3DFMT_A8R8G8B8:result:=ipfARGB;
  D3DFMT_X8R8G8B8:result:=ipfXRGB;
  D3DFMT_DXT1:result:=ipfDXT1;
  D3DFMT_DXT2:result:=ipfDXT2;
  D3DFMT_DXT3:result:=ipfDXT3;
  D3DFMT_DXT5:result:=ipfDXT5;
  D3DFMT_P8:result:=ipf8Bit;
  D3DFMT_A8:result:=ipfA8;
  else raise EError.Create('GetIPF: pixel format not supported '+inttostr(pixfmt));
 end;
end;



function AllocPalette:integer;
 var
  i,j:integer;
 begin
  for i:=0 to 1023 do
   if PalUsage[i]<>255 then begin
    for j:=0 to 7 do
     if (PalUsage[i] and (1 shl j)=0) then begin
      PalUsage[i]:=PalUsage[i] or (1 shl j);
      result:=i*8+j; exit;
     end;
   end;
  raise EError.Create('Cannot allocate palette - no available slots');
 end;

procedure FreePalette(index:integer);
 begin
  if (index<0) or (index>=8192) then exit;
  PalUsage[index shr 3]:=PalUsage[index shr 3] and (255 xor (1 shl (index and 7)));
 end;

procedure SetPersistentPalette(index:integer;var data);
 var
  i:integer;
  fl:boolean;
 begin
  if (palcnt>255) or (device=nil) then exit;
  fl:=false;
  for i:=0 to palcnt-1 do
   if palettes[i].index=index then begin
    fl:=true; break;
   end;
  if not fl then begin
   i:=palcnt;
   palettes[i].index:=index;
  end;
  getmem(palettes[i].data,1024);
  move(data,palettes[i].data^,1024);
  if i=palcnt then inc(palcnt);
  device.SetPaletteEntries(palettes[i].index,TPaletteEntry(palettes[i].data^));
 end;

// После переключения ражима заполняет глобальные переменные
procedure DetermineFeatures;
 var
  i,j,count,rcnt:integer;
  newflag:boolean;
  mode:TD3DDisplayMode;

 function IsSupported(usage,format:cardinal):boolean;
  begin
   result:=
    (d3d.CheckDeviceFormat(useAdapter,D3DDEVTYPE_HAL,params.BackBufferFormat,usage,D3DRTYPE_TEXTURE,format)=D3D_OK)
  end;
begin
  count:=d3d.GetAdapterModeCount(useAdapter);
  line:=101;
  rcnt:=0;
  for i:=0 to count-1 do begin
   fillchar(mode,sizeof(mode),0);
   d3d.EnumAdapterModes(useAdapter,i,mode);
   line:=102;
   newflag:=true;
   for j:=1 to rcnt do
    if (resolutions[j].width=mode.width) and (resolutions[j].height=mode.Height) then newflag:=false;
   line:=103;
   if newflag then begin
    inc(rcnt);
    resolutions[rcnt].width:=mode.Width;
    resolutions[rcnt].height:=mode.Height;
   end;
   line:=104;
   if (mode.Width=640) and (mode.height=480) then support640x480:=true;
   if (mode.Width=800) and (mode.height=600) then support800x600:=true;
   if (mode.Width=1024) and (mode.height=600) then support1024x600:=true;
   if (mode.Width=1024) and (mode.height=768) then support1024x768:=true;
   if (mode.Width=1280) and (mode.height=800) then support1280x800:=true;
   if (mode.Width=1280) and (mode.height=960) then support1280x960:=true;
   if (mode.Width=1280) and (mode.height=1024) then support1280x1024:=true;
   if (mode.Width=1360) and (mode.height=768) then support1360x768:=true;
   if (mode.Width=1440) and (mode.height=900) then support1440x900:=true;
   if (mode.Width=1600) and (mode.height=900) then support1600x900:=true;
   if (mode.Width=1600) and (mode.height=1200) then support1600x1200:=true;
   if (mode.Width=1680) and (mode.height=1050) then support1680x1050:=true;
   if (mode.Width=1920) and (mode.height=1080) then support1920x1080:=true;
   if (mode.Width=1920) and (mode.height=1200) then support1920x1200:=true;
  end;
  line:=110;
  support8bit:=IsSupported(0,D3DFMT_P8);
  supportA8:=IsSupported(0,D3DFMT_A8);
  support4444:=IsSupported(0,D3DFMT_A4R4G4B4);
  support565:=IsSupported(0,D3DFMT_R5G6B5);
  support555:=IsSupported(0,D3DFMT_X1R5G5B5);
  support1555:=IsSupported(0,D3DFMT_A1R5G5B5);
  supportRGB:=IsSupported(0,D3DFMT_R8G8B8);
  supportXRGB:=IsSupported(0,D3DFMT_X8R8G8B8);
  supportARGB:=IsSupported(0,D3DFMT_A8R8G8B8);
  supportDXT1:=IsSupported(0,D3DFMT_DXT1);
  supportDXT2:=IsSupported(0,D3DFMT_DXT2);
  supportDXT3:=IsSupported(0,D3DFMT_DXT3);
  supportDXT4:=IsSupported(0,D3DFMT_DXT4);
  supportDXT5:=IsSupported(0,D3DFMT_DXT5);
  line:=111;


  supportARGBrt:=IsSupported(D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8);
  supportXRGBrt:=IsSupported(D3DUSAGE_RENDERTARGET,D3DFMT_X8R8G8B8);
  supportRGBrt:=IsSupported(D3DUSAGE_RENDERTARGET,D3DFMT_R8G8B8);
  support565rt:=IsSupported(D3DUSAGE_RENDERTARGET,D3DFMT_R5G6B5);
  support555rt:=IsSupported(D3DUSAGE_RENDERTARGET,D3DFMT_X1R5G5B5);
  support4444rt:=IsSupported(D3DUSAGE_RENDERTARGET,D3DFMT_A4R4G4B4);
  line:=112;

  zbuffer:=params.AutoDepthStencilFormat<>0;
  case params.AutoDepthStencilFormat of
   D3DFMT_D15S1:stencil:=1;
   D3DFMT_D24S8:stencil:=8;
   else stencil:=0;
  end;
end;

procedure Init;
 var
  res:integer;
  bf:cardinal;
 begin
  if d3d=nil then raise EError.Create('D3D not initialized');
  wnd:=hwnd;
  if PreferHW then
   bf:=D3DCREATE_MIXED_VERTEXPROCESSING
  else
   bf:=D3DCREATE_SOFTWARE_VERTEXPROCESSING;
  if multithreaded then bf:=bf or D3DCREATE_MULTITHREADED;
  // проверка мультисэмплинга
  repeat
   res:=d3d.CheckDeviceMultiSampleType(useAdapter,D3DDEVTYPE_HAL,mode.BackBufferFormat,mode.Windowed,mode.MultiSampleType);
   if res<>0 then begin
    if mode.MultiSampleType=D3DMULTISAMPLE_NONE then raise EError.Create('D3D8: No supported multisample format found!'); 
    if mode.MultiSampleType=D3DMULTISAMPLE_2_SAMPLES then mode.MultiSampleType:=D3DMULTISAMPLE_NONE;
    if mode.MultiSampleType=D3DMULTISAMPLE_3_SAMPLES then mode.MultiSampleType:=D3DMULTISAMPLE_2_SAMPLES;
    if mode.MultiSampleType=D3DMULTISAMPLE_4_SAMPLES then mode.MultiSampleType:=D3DMULTISAMPLE_3_SAMPLES;
    if mode.MultiSampleType=D3DMULTISAMPLE_6_SAMPLES then mode.MultiSampleType:=D3DMULTISAMPLE_4_SAMPLES;
   end;
  until res=0;

  res:=d3d.CreateDevice(useAdapter,D3DDEVTYPE_HAL,hwnd,bf,mode,device);
{  if res<0 then
   raise EError.Create('Cannot create Direct3DDevice: '+DXGErrorString(res));}

  if device=nil then begin // Вторая попытка
   LogMessage('Warning: Failed to create requested device, trying safe settings');
   bf:=D3DCREATE_SOFTWARE_VERTEXPROCESSING;
   res:=d3d.CreateDevice(useAdapter,D3DDEVTYPE_HAL,hwnd,bf,mode,device);
   if (res<0) or (device=nil) then
    raise EError.Create('Cannot create Direct3DDevice: '+DXGErrorString(res));
  end;
  device.GetDeviceCaps(CAPS);
  params:=mode;
  DetermineFeatures;
 end;

procedure ChangeMode;
 var
  res:cardinal;
  i:integer;
 begin
  if (d3d=nil) or (device=nil) then raise EError.Create('D3D not initialized');
  res:=device.Reset(newmode);
  if res<0 then raise EWarning.Create('Error during mode change: '+DXGErrorString(res));
  params:=newmode;
  DetermineFeatures;
  for i:=0 to palcnt-1 do begin
   DxCall(device.SetPaletteEntries(palettes[i].index,TPaletteEntry(palettes[i].data^)));
  end;
 end;

procedure Done;
 begin
  device:=nil;
  LogMessage('D3DDevice deleted');
 end;

function WindowedMode;
 var
  mode:TD3DDisplayMode;
 begin
  if d3d=nil then raise EError.Create('D3D not initialized');
  d3d.GetAdapterDisplayMode(useAdapter,mode);
  with result do begin
   BackBufferWidth:=width;
   BackBufferHeight:=height;
   BackBufferFormat:=mode.Format;
   BackBufferCount:=1;
   MultiSampleType:=D3DMultisample_None;
   SwapEffect:=D3DSwapEffect_COPY_VSync;
   hDeviceWindow:=hwnd;
   Windowed:=true;
   EnableAutoDepthStencil:=zstencil<>0;
   AutoDepthStencilFormat:=zstencil;
   Flags:=0;
   FullScreen_RefreshRateInHz:=0;
   FullScreen_PresentationInterval:=0;
  end;
 end;

function FullScreenMode;
 var
  i,j,best,mode:integer;
  a:single;
 begin
  best:=5000;  mode:=0;
  a:=displayMode.Height/displayMode.width;
  for i:=1 to Length(resolutions) do begin
   if (resolutions[i].width<width) or
      (resolutions[i].height<height) then continue;
   if keepAspect and (abs(a-resolutions[i].height/resolutions[i].width)>0.05) then continue;
   j:=resolutions[i].width+resolutions[i].height-width-height;
   if j<best then begin
    best:=j; mode:=i;
   end;
  end;
  if mode=0 then raise EError.Create('No suitable screen resolution supported!');
  with result do begin
   BackBufferWidth:=resolutions[mode].width;
   BackBufferHeight:=resolutions[mode].height;
   BackBufferFormat:=format;
   BackBufferCount:=1;
   MultiSampleType:=D3DMultisample_None;
   SwapEffect:=D3DSwapEffect_DISCARD;
   hDeviceWindow:=hwnd;
   Windowed:=false;
   EnableAutoDepthStencil:=zstencil<>0;
   AutoDepthStencilFormat:=zstencil;
   Flags:=0;
   FullScreen_RefreshRateInHz:=refresh;
   FullScreen_PresentationInterval:=vsync;
  end;
 end;

procedure ClearViewPort;
 var
  f:cardinal;
 begin
  f:=D3DCLEAR_TARGET;
  if (z>=0) and (zbuffer) then inc(f,D3DCLEAR_ZBUFFER)
   else device.SetRenderState(D3DRS_ZENABLE,0);
  if (stencil>0) and (stencilVal>=0) then inc(f,D3DCLEAR_STENCIL);
  DxCall(device.Clear(0,nil,f,color,z,stencil));
 end;

procedure DxCall(res:HResult;msg:string='');
 begin
  if res<0 then begin
   raise EError.Create(msg+' DX method returned error: '+DXGErrorString(res));
  end;
 end;

procedure StoreViewPort;
 begin
  ASSERT(device<>nil);
  if vpcount=15 then begin
   raise EWarning.Create('Error\d3d8\OutOfVP - 0');
   exit;
  end;
  inc(vpcount);
  DxCall(device.GetViewport(viewports[vpcount]));
 end;

procedure RestoreViewPort;
 begin
  ASSERT(device<>nil);
  if vpcount=0 then begin
   raise EWarning.Create('Error\d3d8\OutOfVP - 0');
   exit;
  end;
  DxCall(device.SetViewport(viewports[vpcount]));
  dec(vpcount);
 end;

procedure SetDefaultRT;
 var
  backbuf,zbuf:IDirect3DSurface8;
 begin
  ASSERT(device<>nil);
  DxCall(device.GetBackBuffer(0,D3DBACKBUFFER_TYPE_MONO,backbuf));
  device.GetDepthStencilSurface(zbuf);
  DxCall(device.SetRenderTarget(backbuf,zbuf));
 end;

procedure DumpD3D(name:integer=1);
 var
  f:text;
  i:integer;
  c:cardinal;
  mat:TD3DMatrix;
  tex:IDirect3DBaseTexture8;
  vp:TD3DViewport8;
 procedure WriteMat;
  begin
   writeln(f,mat._11:12:3,mat._12:9:3,mat._13:9:3,mat._14:9:3);
   writeln(f,mat._21:12:3,mat._22:9:3,mat._23:9:3,mat._24:9:3);
   writeln(f,mat._31:12:3,mat._32:9:3,mat._33:9:3,mat._34:9:3);
   writeln(f,mat._41:12:3,mat._42:9:3,mat._43:9:3,mat._44:9:3);
  end;
 begin
  assign(f,'D3D8-'+inttostr(name)+'.log');
  rewrite(f);

  device.GetViewport(vp);
  writeln(f,'Viewport:');
  writeln(f,vp.x:10,vp.y:6,vp.Width:6,vp.Height:6,vp.minz:8:3,vp.maxZ:8:3);
  writeln(f);

  device.GetVertexShader(c);
  writeln(f,'Vertex shader: ',c);
  writeln(f);
  writeln(f,'Transforms:');
  device.GetTransform(D3DTS_WORLD,mat);
  writeln(f, 'WORLD:'); WriteMat;  writeln(f);
  device.GetTransform(D3DTS_VIEW,mat);
  writeln(f, 'WIEW:'); WriteMat;  writeln(f);
  device.GetTransform(D3DTS_PROJECTION,mat);
  writeln(f, 'PROJECTION:'); WriteMat;  writeln(f);

  writeln(f,'Render states:');
  device.GetRenderState(D3DRS_ZENABLE,c);
  writeln(f,' ZENABLE:         ',c);
  device.GetRenderState(D3DRS_FILLMODE,c);
  writeln(f,' FILLMODE:        ',c);
  device.GetRenderState(D3DRS_SHADEMODE,c);
  writeln(f,' SHADEMODE:       ',c);
  device.GetRenderState(D3DRS_ZWRITEENABLE,c);
  writeln(f,' ZWRITEENABLE:    ',c);
  device.GetRenderState(D3DRS_ALPHATESTENABLE,c);
  writeln(f,' ALPHATESTENABLE: ',c);
  device.GetRenderState(D3DRS_LASTPIXEL,c);
  writeln(f,' LASTPIXEL:       ',c);
  device.GetRenderState(D3DRS_SRCBLEND,c);
  writeln(f,' SRCBLEND:        ',c);
  device.GetRenderState(D3DRS_DESTBLEND,c);
  writeln(f,' DESTBLEND:       ',c);
  device.GetRenderState(D3DRS_BLENDOP,c);
  writeln(f,' BLENDOP:         ',c);
  device.GetRenderState(D3DRS_CULLMODE,c);
  writeln(f,' CULLMODE:        ',c);
  device.GetRenderState(D3DRS_ZFUNC,c);
  writeln(f,' ZFUNC:           ',c);
  device.GetRenderState(D3DRS_ALPHAREF,c);
  writeln(f,' ALPHAREF:        ',c);
  device.GetRenderState(D3DRS_ALPHAFUNC,c);
  writeln(f,' ALPHAFUNC:       ',c);
  device.GetRenderState(D3DRS_ALPHABLENDENABLE,c);
  writeln(f,' ALPHABLENDENABLE: ',c);
  device.GetRenderState(D3DRS_LIGHTING,c);
  writeln(f,' LIGHTNING:       ',c);
  device.GetRenderState(D3DRS_CLIPPING,c);
  writeln(f,' CLIPPING:        ',c);
  writeln(f);

  writeln(f,'Texture stages:');
  for i:=0 to 3 do begin
   writeln(f);
   writeln(f,' Stage ',i);
   device.GetTexture(i,tex);
   writeln(f,'  Texture:   ',UIntPtr(pointer(tex)));
   device.GetTextureStageState(i,D3DTSS_COLOROP,c);
   writeln(f,'  ColorOP:   ',c);
   device.GetTextureStageState(i,D3DTSS_COLORARG1,c);
   writeln(f,'  ColorARG1: ',c);
   device.GetTextureStageState(i,D3DTSS_COLORARG2,c);
   writeln(f,'  ColorARG2: ',c);
   device.GetTextureStageState(i,D3DTSS_ALPHAOP,c);
   writeln(f,'  AplhaOP:   ',c);
   device.GetTextureStageState(i,D3DTSS_ALPHAARG1,c);
   writeln(f,'  AlphaARG1: ',c);
   device.GetTextureStageState(i,D3DTSS_ALPHAARG2,c);
   writeln(f,'  AlphaARG2: ',c);
   device.GetTextureStageState(i,D3DTSS_MAGFILTER,c);
   writeln(f,'  MAGFILTER: ',c);
   device.GetTextureStageState(i,D3DTSS_MINFILTER,c);
   writeln(f,'  MINFILTER: ',c);
   device.GetTextureStageState(i,D3DTSS_MIPFILTER,c);
   writeln(f,'  MIPFILTER: ',c);
  end;

  close(f);
 end;


var
 i:integer;
initialization
 try
  line:=1;
  d3d:=Direct3DCreate8(D3D_SDK_VERSION);
  if d3d=nil then raise EFatalError.Create('Can''t create Direct3D oblect!');
  line:=2;
  d3d.GetDeviceCaps(D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,CAPS);
  line:=3;
  d3d.GetAdapterDisplayMode(D3DADAPTER_DEFAULT,DisplayMode);
  line:=4;
  adaptersCnt:=d3d.GetAdapterCount;
  for i:=0 to adaptersCnt-1 do
   d3d.GetAdapterIdentifier(i,D3DENUM_NO_WHQL_LEVEL,adapters[i]);
  line:=5;
  d3d.GetAdapterIdentifier(D3DADAPTER_DEFAULT,D3DENUM_NO_WHQL_LEVEL,PrimaryAdapter);
  line:=6;
  DetermineFeatures;
  line:=7;
 except
  on e:Exception do begin
   MessageBox(0,PChar('Failed to init D3D8 object!: '#13#10+e.message+#13#10+'L='+IntToStr(line)),'Failure',0);
   halt;
  end;
 end;
finalization
  if device<>nil then device:=nil;
  d3d:=nil;
end.
