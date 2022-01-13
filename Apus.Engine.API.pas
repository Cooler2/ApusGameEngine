// Definition of engine's abstract classes structure
//
// Copyright (C) 2003 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.API;
interface
 uses Apus.CrossPlatform, Types, Apus.Engine.Types, Apus.MyServis, Apus.Images, Apus.Geom2D, Apus.Geom3D,
   Apus.Colors, Apus.EventMan, Apus.VertexLayout, Apus.Engine.Resources;

const
 // Image allocation flags (ai - AllocImage)
 aiAutoMipmap     =  1; // Automatically generate mip-map levels (number of levels is implementation-dependent)
 aiTexture        =  2; // Allocate full texture object of the underlying API (no texture sharing, no dynamic atlas)
 aiRenderTarget   =  4; // Image can be used as Render Target for GPU (no CPU access)
 aiSysMem         =  8; // Image will have its buffer in system RAM, so can be accessed by CPU
 aiPow2           = 16; // Enlarge dimensions to be PoT
// aiWriteOnly      = 32; // Can be locked, but for write only operation
 aiDontScale      = 64; // Use exact width/height for render target allocation (otherwise they're scaled using current scale factor)
 aiClampUV        = 128; // clamp texture coordinates instead of wrapping them (for aiTexture only)
 aiDepthBuffer    = 256; // allocate a Depth Buffer for this image (for aiRenderTarget only)
 aiPixelated      = 8192; // disable tri/bilinear filtering for this image

 // DynamicAtlas dimension flags
 aiMW256   = $010000;
 aiMW512   = $020000;
 aiMW1024  = $030000;
 aiMW2048  = $040000;
 aiMW4096  = $050000;
 aiMH256   = $100000;
 aiMH512   = $200000;
 aiMH1024  = $300000;
 aiMH2048  = $400000;
 aiMH4096  = $500000;

 // LoadImageFromFile flags
 liffSysMem  = aiSysMem; // Image will be allocated in system memory only and can't be used for accelerated rendering!
 liffTexture = aiTexture; // Image will be allocated as a whole texture (wrap UV enabled, otherwise - disabled!)
 liffPow2    = aiPow2; // Image dimensions will be increased to the nearest pow2
 liffMipMaps = aiAutoMipmap; // Image will be loaded with mip-maps (auto-generated if no mips in the file)
 liffAllowChange = $100;    // Ensure that image won't be read-only
 liffDefault = $FFFFFFFF;   // Use defaultLoadImageFlags for default flag values

 // width and height of atlas-texture
 liffMW256   = aiMW256;
 liffMW512   = aiMW512;
 liffMW1024  = aiMW1024;
 liffMW2048  = aiMW2048;
 liffMW4096  = aiMW4096;

 liffMH256   = aiMH256;
 liffMH512   = aiMH512;
 liffMH1024  = aiMH1024;
 liffMH2048  = aiMH2048;
 liffMH4096  = aiMH4096;

 // Some texture flags (not all)
 tfRenderTarget = Apus.Engine.Resources.tfRenderTarget;
 tfScaled       = Apus.Engine.Resources.tfScaled;
 tfTexture      = Apus.Engine.Resources.tfTexture;

 // Special flags for the "index" field of particles
 partPosU  = $00000001; // horizontal position in the atlas (in cells)
 partPosV  = $00000100; // vertical position in the atlas (in cells)
 partSizeU = $00010000; // particle width (in cells)
 partSizeV = $00100000; // particle height (in cells)
 partFlip  = $01000000; // mirror
 partEndpoint = $02000000; // indicate that particle is a free end of a polyline (draw.Band)
 partLoop = $04000000; // indicate end of a polyline loop (draw.Band)

 // txt.Write() options flags (overrides font handle flags)
 toDontTranslate  =  1; // Don't use UDict to translate
 toDrawToBitmap   =  2; // Draw to bitmap buffer instead of current render target
 toDontCache      =  4; // Text attributes are dynamic, so no need to cache glyphs for any long period (temp cache is used)
 toWithShadow     =  8; // Draw twice with 1,1 offset shadow
 toComplexText    =  16; // String is complex - parse it
 toMeasure        =  32; // Fill measurement data, if query<>0 - check point and set current link
 toDontDraw       =  64; // Just measure - don't draw anything
 toBold           =      $100;  // Overrides font style flag
 toAddBaseline    =    $10000;  // y-coordinate passed is not for baseline, but for top line, so need to be corrected
 toNoHinting      =    $20000; // Disable hinting for vector fonts (good for large text)
 toAutoHinting    =    $40000; // Force use of FT-autohinting (may produce better or more uniform results)
 toItalic         =  $2000000; // Overrides font style flag
 toUnderline      =  $4000000; // Overrides font style flag
 toLetterSpacing  = $10000000; // Additional spacing between letters

 // GetFont() style flags
 fsDontTranslate = 1; // Don't use UDict to translate strings
 fsNoHinting     = 2; // Disable hinting for vector fonts (good for large text)
 fsAutoHinting   = 4; // Force use of FT-autohinting (may produce better or more uniform results)
 fsStrictMatch = 128; // strict match for font name
 fsBold        =         $100;
 fsItalic      =     $2000000;
 fsUnderline   =     $4000000;
 fsLetterSpacing  = $10000000;

 // Font options (for SetFontOption)
 foDownscaleFactor = 1;
 foUpscaleFactor   = 2;
 foGlobalScale     = 3;

 // Keyboard shift state codes
 sscShift = 1;
 sscCtrl  = 2;
 sscAlt   = 4;
 sscWin   = 8;

 // Mouse buttons
 mbLeft   = 1;
 mbRight  = 2;
 mbMiddle = 4;

 // Predefined cursor IDs
 crDefault        =  0;  // Default arrow
 crLink           =  1;  // Link-over (hand/finger)
 crWait           =  2;  // Курсор в режиме ожидания (часы)
 crInput          =  3;  // Text input cursor (beam)
 crHelp           =  4;  // Arrow with question mark
 crResizeH        = 10;  // E-W arrows
 crResizeW        = 11;  // N-S arrows
 crResizeHW       = 12;  // N-S-E-W arrows
 crCross          = 13;  //
 crNone           = 99;  // No cursor (hidden)

type
 // Strings
 String8 = Apus.MyServis.String8;
 String16 = Apus.MyServis.String16;

 // 2D Vector
 TPoint2   = Apus.Engine.Types.TPoint2;
 PPoint2   = Apus.Engine.Types.PPoint2;
 TPoint2s  = Apus.Engine.Types.TPoint2s;
 TVector2s = Apus.Engine.Types.TVector2s;
 PPoint2s  = Apus.Engine.Types.PPoint2s;
 // 3D Vector
 TPoint3   = Apus.Engine.Types.TPoint3;
 TVector3  = Apus.Engine.Types.TVector3;
 PPoint3   = Apus.Engine.Types.PPoint3;
 TPoint3s  = Apus.Engine.Types.TPoint3s;
 PPoint3s  = Apus.Engine.Types.PPoint3s;
 TVector3s = Apus.Engine.Types.TVector3s;
 TVector4  = Apus.Engine.Types.TVector4;
 TVector4s = Apus.Engine.Types.TVector4s;
 // Matrices
 T3DMatrix  = Apus.Engine.Types.T3DMatrix;
 T3DMatrixS = Apus.Engine.Types.T3DMatrixS;
 T2DMatrix  = Apus.Engine.Types.T2DMatrix;

 // Other types
 TRect2s = Apus.Engine.Types.TRect2s;
 TVertexLayout = Apus.Engine.Types.TVertexLayout;
 TPrimitiveType = Apus.Engine.Types.TPrimitiveType;

 // Packed ARGB color
 TARGBColor = Apus.Engine.Types.TARGBColor;
 PARGBColor = Apus.Engine.Types.PARGBColor;


const
 // Vertex layout with 3 attributes: position[3] (location=0), color[3] (location=1) and uv[2] (location=2)
 DEFAULT_VERTEX_LAYOUT : TVertexLayout = (layout: $4300; stride: 6*4;);

type
 TImagePixelFormat = Apus.Images.TImagePixelFormat;

 // Which API use for rendering
 TGraphicsAPI=(gaAuto,     // Check one considering defined symbols
               gaDirectX,  // Currently Direct3D8 (deprecated)
               gaOpenGL,   // OpenGL 1.4 or higher with fixed function pipeline (deprecated)
               gaOpenGL2); // OpenGL 2.0 or higher with shaders

 TSystemPlatform=(spDefault, // OS default
                  spWindows, // Native Windows
                  spSDL);    // SDL-2 library (cross-platform)

 // Режим блендинга (действие, применяемое к фону)
 TBlendingMode=(blNone,   // background not modified
                blAlpha,  // regular alpha blending
                blAdd,    // additive mode ("Screen"
                blSub,    // subtractive mode
                blModulate,   // "Multiply" mode
                blModulate2X,  // "Multiply" mode with 2x factor
                blMove     // Direct move
                );
 // Режим блендинга текстуры (действие, применяемое к отдельной стадии текстурирования, к альфе либо цвету отдельно)
 TTexBlendingMode=(tblNone,  // undefined (don't change current value)
                   tblDisable, // disable texture stage
                   tblKeep,  // keep previous pixel value (previous=diffuse for stage 0)
                   tblReplace, // use texture value
                   tblModulate, // previous*texture
                   tblModulate2X, // previous*texture*2
                   tblAdd,     // previous+texture
                   tblSub,     // previous-texture
                   tblInterpolate // previous*factor+texture*(1-factor) текстурные стадии смешиваются между собой
                   );
{ TTexInterpolateMode=(tintFactor, // factor=constant
                      tintDiffuse, // factor=diffuse alpha
                      tintTexture, // factor=texture alpha
                      tintCurrent); // factor=previous stage alpha}

 // Режим интерполяции текстур
 TTexFilter = Apus.Engine.Resources.TTexFilter;

 // Access mode for locked resources
 TLockMode = Apus.Engine.Resources.TLockMode;

 // Base texture class
 TTexture = Apus.Engine.Resources.TTexture;

 // Text alignment
 TTextAlignment=(taLeft,      // обычный вывод
                 taCenter,    // точка вывода указывает на центр надписи
                 taRight,     // точка вывода указывает на правую границу
                 taJustify);  // точка вывода указывает на левую границу, а spacing - ширина строки
                              // (вывод превращается в левый если реальная ширина строки слишком мала или строка заканчивается на #10 или #13)

 // Display mode
 TDisplayMode=(dmNone,             //< not specified
               dmSwitchResolution, //< Fullscreen: switch to desired display mode (change screen resolution)
               dmFullScreen,       //< Use current resolution with fullscreen window
               dmFixedWindow,      //< Use fixed-size window
               dmWindow);          //< Use resizeable window

 // How the rendered image should appear in the output window (display)
 TDisplayFitMode=(dfmCenter,           //< image is centered in the output window rect (1:1) (DisplayScaleMode is ignored)
                  dfmFullSize,         //< image is stretched to fill the whole output window
                  dfmKeepAspectRatio); //< image is stretched to fill the output window while keeping it's original aspect ratio (black padding)

 // How rendering is processed if the backbuffer size doesn't match the output area
 TDisplayScaleMode=(dsmDontScale,   //< Backbuffer size is updated to match the output area
                    dsmStretch,     //< Stretch rendered image to the output rect
                    dsmScale);      //< Use scale transformation matrix to map render area to the output rect (scaled rendering)
                                    // Note that scaled rendering produces error in clipping due to rounding
 // Display settings
 TDisplaySettings=record
  displayMode:TDisplayMode;
  displayFitMode:TDisplayFitMode;
  displayScaleMode:TDisplayScaleMode;
 end;

 // Это важная структура, задающая параметры работы движка
 // На ее основе движок будет конфигурировать другие объекты, например device
 // Важно понимать смысл каждого ее поля, хотя не обязательно каждое из них будет учтено
 TGameSettings=record
  title:string;  // Заголовок окна/программы
  width,height:integer; // Размер BackBuffer'а и (вероятно) области вывода (окна/экрана), фактический размер окна может отличаться от запрошенного
                        // если mode=dmFullScreen, то эти параметры игнорируются и устанавливаются в текущее разрешение
                        // В процессе работы область вывода может меняться (например при изменении размеров окна или переключении режима)
                        // В данной версии размер backBuffer всегда равен размеру области вывода (нет масштабирования), но в принципе
                        // они могут и отличаться
  colorDepth:integer; // Желаемый формат бэкбуфера (16/24/32)
  refresh:integer;   // Частота регенерации экрана (0 - default)
  VSync:integer;     // Синхронизация с обновлением монитора (0 - максимальный FPS, N - FPS = refresh/N
  mode,altMode:TDisplaySettings; // Основной режим запуска и альтернативный режим (для переключения по Alt+Enter)
  showSystemCursor:boolean; // Показывать ли системный курсор? если false - курсор рисуется движком программно
  zbuffer:byte; // желательная глубина z-буфера (0 - не нужен)
  stencil:boolean; // нужен ли stencil-буфер (8-bit)
  multisampling:byte; // включить мультисэмплинг (fs-антиалиасинг) - кол-во сэмплов (<2 - отключен)
  slowmotion:boolean; // true - если преобладают медленные сцены или если есть большой разброс
                      // в скорости - тогда возможна (но не гарантируется) оптимизация перерисовки
 end;

 // Nine Patch: resizable image
 TNinePatch=class(TNamedObject)
  minWidth,minHeight:integer; // minimal possible dimension (in pixels, when scale=1.0)
  baseWidth,baseHeight:integer; // dimension without any stretching (in pixels, when scale=1.0)
  scaleFactor:single; // scale modifier: for example, use 0.5 for images with double resolution
  procedure Draw(x,y,width,height:single;scale:single=1.0); virtual; abstract;
 protected
  class function ClassHash:pointer; override; // override this to provide a separate hash for object instances
 end;

 // Interface to the native OS function or underlying library
 ISystemPlatform=interface
  // System information
  function GetPlatformName:string;
  function CanChangeSettings:boolean;
  procedure GetScreenSize(out width,height:integer);
  function GetScreenDPI:integer;
  // Window management
  procedure CreateWindow(title:string); // Create main window
  procedure DestroyWindow;
  procedure SetupWindow(params:TGameSettings); // Configure/update window properties
  procedure ShowWindow(show:boolean);
  function GetWindowHandle:THandle;
  procedure GetWindowSize(out width,height:integer);
  procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0);
  procedure SetWindowCaption(text:string);
  procedure Minimize;
  procedure FlashWindow(count:integer);
  // Event management
  procedure ProcessSystemMessages;
  function IsTerminated:boolean;

  // System functions
  function GetSystemCursor(cursorId:integer):THandle;
  function LoadCursor(filename:string):THandle;
  procedure SetCursor(cur:THandle);
  procedure FreeCursor(cur:THandle);
  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetMousePos:TPoint; // Get mouse position on screen (screen may mean client when platform doesn't support real screen space)
  procedure SetMousePos(scrX,scrY:integer); // Move mouse cursor (screen coordinates)
  function GetMouseButtons:cardinal;
  function GetShiftKeysState:cardinal;

  // Translate coordinates between screen and window client area
  procedure ScreenToClient(var p:TPoint);
  procedure ClientToScreen(var p:TPoint);

  // OpenGL support
  function CreateOpenGLContext:UIntPtr;
  procedure OGLSwapBuffers;
  function SetSwapInterval(divider:integer):boolean;
  procedure DeleteOpenGLContext;
 end;

 // Depth buffer mode
 TDepthBufferTest=(
   dbDisabled, // disable depth test
   dbPass,       // always pass depth test
   dbPassLess,   // pass lesser values
   dbPassLessEqual,  // pass lesser or equal values
   dbPassGreater, // pass greater values
   dbNever); // never pass depth test

 TCullMode=(cullNone, // Display both sides
   cullCW,    // Omit CW faces. This engine uses CW faces for 2D drawing
   cullCCW);  // Omit CCW faces. in OpenGL CCW-faces are considered front by default

 // Shader mode for shadow mapping
 TShadowMapMode=(shadowDisabled,  // No shadow mapping (default, no shadows)
                 shadowDepthPass, // Render shadowmap (depth-only, no color output)
                 shadowMainPass); // Render using shadowmap (enable shadows)

 TShader = Apus.Engine.Resources.TShader;

 // Control render target
 IRenderTarget=interface
  // Clear whole render target (not only the viewport): fill colorbuffer and optionally depth buffer and stencil buffer
  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1);
  // Setup viewport (output position) for the current render target
  // After viewport change don't forget to update projection and clipping
  procedure Viewport(oX,oY,VPwidth,VPheight:integer;renderWidth:integer=0;renderHeight:integer=0);
  // Enable/setup depth test
  procedure UseDepthBuffer(test:TDepthBufferTest;writeEnable:boolean=true);
  // Set blending mode
  procedure BlendMode(blend:TBlendingMode);
  // Set write mask (push previous mask)
  procedure Mask(rgb:boolean;alpha:boolean);
  // Restore (pop) previous mask
  procedure UnMask;

  function width:integer;  //< width of the render area in virtual pixels
  function height:integer; //< height of the render area in virtual pixels
  function aspect:single; // width/height

  procedure Backbuffer; //< Render to the backbuffer
  procedure Texture(tex:TTexture); //< render to the texture (nil - render to the Backbuffer)
  procedure Push;  //< Save (push) current target in stack (including viewport)
  procedure Pop; //< Restore target from stack

  procedure Resized(newWidth,newHeight:integer); // backbuffer size changed
 end;

 // Control clipping
 IClipping=interface
  procedure Rect(r:TRect;combine:boolean=true);  //< Set clipping rect (combine with previous or override), save previous
  procedure Nothing; //< don't clip anything, save previous (the same as Rect() for the whole render target area)
  procedure Restore; //< restore previous clipping rect
  function  Get:TRect; //< return current clipping rect
  // Call this before draw something within R.
  // It sets actual clipping if needed.
  // Returns false if R doesn't intersect the current clipping rect (so no need to draw anything inside R)
  function Prepare(r:TRect):boolean; overload;
  function Prepare(x1,y1,x2,y2:NativeInt):boolean; overload;
  function Prepare(x1,y1,x2,y2:single):boolean; overload;  //< return false if r doesn't intersect the current clipping rect (so no need to draw anything inside r)
 end;

 // Control transformation and projection
 ITransformation=interface
  // Switch to default 2D view (use screen coordinates)
  procedure DefaultView;

  // Set 3D view with given field of view (in radians) - set perspective projection matrix
  // using screen dimensions for FoV and aspect ratio
  // Use big enough zMin and zMax since z-range is not linear and precision near zMax is much lower than near zMin.
  // So use values where main visible geometry is at least in the near 10% Z-range
  procedure Perspective(fov:single;zMin,zMax:double); overload;

  // Switch to 3D view - set perspective projection (in camera space: camera pos = 0,0,0, Z-forward, X-right, Y-down)
  // zMin, zMax - near and far Z plane
  // xMin,xMax - x coordinate range on the zScreen Z plane
  // yMin,yMax - y coordinate range on the zScreen Z plane
  // Т.е. точки (x,y,zScreen), где xMin <= x <= xMax, yMin <= y <= yMax - покрывают всю область вывода и только её
  procedure Perspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); overload;
  // Set orthographic projection matrix
  // For example: scale=3 means that 1 unit in the world space is mapped to 3 pixels (in backbuffer)
  procedure Orthographic(scale,zMin,zMax:double);
  // Set arbitrary projection matrix
  procedure SetProjection(proj:T3DMatrix);
  // Set view transformation matrix (camera position)
  // View matrix is (R - right, D - down, F - forward, O - origin):
  // Rx Ry Rz
  // Dx Dy Dz
  // Fx Fy Fz
  // Ox Oy Oz
  procedure SetView(view:T3DMatrix);
  // Alternate way to set camera position and orientation
  // (origin - camera center, target - point to look, up - any point ABOVE camera view line, so plane OTU is vertical),
  // turnCW - camera turn angle (along view axis, CW direction)
  procedure SetCamera(origin,target,up:TPoint3;turnCW:double=0);
  // Set Object (model to world) transformation matrix (must be used AFTER setting the view/camera)
  procedure SetObj(mat:T3DMatrix); overload;
  // Set object position/scale/rotate
  procedure SetObj(oX,oY,oZ:single;scale:single=1;yaw:single=0;roll:single=0;pitch:single=0); overload;
  // Reset object matrix to default
  procedure ResetObj;
  // Get Model-View-Projection matrix (i.e. transformation from model space to screen space)
  function MVPMatrix:T3DMatrix;
  function ProjMatrix:T3DMatrix;
  function ViewMatrix:T3DMatrix;
  function ObjMatrix:T3DMatrix;
  // Transform point using combined MVP matrix
  function Transform(source:TPoint3):TPoint3;
 end;

 // Shaders-related API
 IShader=interface
  // Compile custom shader program from source
  function Build(vSrc,fSrc:String8;extra:String8=''):TShader;
  // Load and build shader from file(s)
  function Load(filename:String8;extra:String8=''):TShader;

  // Set custom shader (pass nil if it's already set or there is no object - because the engine should know)
  procedure UseCustom(shader:TShader);
  // Use customized shader: where just the pixel (fragment) color calculation is modified
  procedure UseCustomized(colorCalc:String8);
  // Switch back to the internal shader
  procedure Reset;
  // Set uniform value for the current shader
  procedure SetUniform(name:String8;value:integer); overload;
  procedure SetUniform(name:String8;value:single); overload;
  procedure SetUniform(name:String8;const value:TVector2s); overload;
  procedure SetUniform(name:String8;const value:TVector3s); overload;
  procedure SetUniform(name:String8;const value:TVector4s); overload;
  procedure SetUniform(name:String8;const value:T3DMatrix); overload;
  procedure SetUniform(name:String8;const value:T3DMatrixS); overload;

  // Built-in shader settings
  // ----
  // Set custom texturing mode
  procedure TexMode(stage:byte;colorMode:TTexBlendingMode=tblModulate2X;alphaMode:TTexBlendingMode=tblModulate;
     filter:TTexFilter=fltUndefined;intFactor:single=0.0);
  // Restore default texturing mode: one stage with Modulate2X mode for color and Modulate mode for alpha
  procedure DefaultTexMode;
  // Upload texture to the Video RAM and make it active for the specified stage
  // (usually you don't need to call this manually unless you're using a custom shader)
  procedure UseTexture(tex:TTexture;stage:integer=0); overload;
  procedure UseTexture(tex:TTexture;uniformName:string8;stage:integer=0); overload; // use custom sampler name

  // Lighting and material
  // ----
  // Ambient color is added to any pixels (set 0 to disable)
  procedure AmbientLight(color:cardinal);
  // Set direction TO the light source (sun) (set power<=0 to disable)
  procedure DirectLight(direction:TVector3;power:single;color:cardinal);
  // Set point light source (set power<=0 to disable)
  procedure PointLight(position:TPoint3;power:single;color:cardinal);
  // Disable lighting
  procedure LightOff;
  // Define material properties
  procedure Material(color:cardinal;shininess:single);
  // Shadow mapping
  procedure Shadow(mode:TShadowMapMode;shadowMap:TTexture=nil;depthBias:single=0.002);

  // Apply shader configuration (build/set proper shader). Must be called after any mode changes before actual draw calls
  procedure Apply(vertexLayout:TVertexLayout);
 end;

 // Configuration
 IGraphicsSystemConfig=interface
  procedure ChoosePixelFormats(out trueColor,trueColorAlpha,rtTrueColor,rtTrueColorAlpha:TImagePixelFormat;
    economyMode:boolean=false);
  function SetVSyncDivider(n:integer):boolean; //< 0 - unlimited FPS, 1 - use monitor refresh rate
  // Query options
  function QueryMaxRTSize:integer; //< get max allowed dimension for RT textures
  function ShouldUseTextureAsDefaultRT:boolean;
 end;

 // -------------------------------------------------------------------
 // ResourceManager - менеджер изображений (фактически, менеджер текстурной памяти)
 // -------------------------------------------------------------------
 IResourceManager=interface
  // Создать изображение (в случае ошибки будет исключение)
  function AllocImage(width,height:integer;PixFmt:TImagePixelFormat;
     flags:cardinal;name:String8):TTexture;
  // Change size of texture if it supports it (render target etc)
  procedure ResizeImage(var img:TTexture;newWidth,newHeight:integer);
  function Clone(img:TTexture):TTexture;
  // Освободить изображение
  procedure FreeImage(var image:TTexture); overload;
  // Сделать текстуру доступной для использования (может использоваться для менеджмента текстур)
  // необходимо вызывать всякий раз перед переключением на текстуру (обычно это делает код рисовалки)
  procedure MakeOnline(img:TTexture;stage:integer=0);
  // Проверить возможность выделения текстуры в заданном формате с заданными флагами
  // Возвращает true если такую текстуру принципиально можно создать
  function QueryParams(width,height:integer;format:TImagePixelFormat;aiFlags:integer):boolean;
  // Формирует строки статуса
  function GetStatus(line:byte):string;
  // Создает дамп использования и распределения видеопамяти
  procedure Dump(st:string='');
 end;

 // Particle atributes
 TParticle=record
  x,y,z:single;       // center position (z+ = forward direction)
  color:cardinal;
  scale,angle:single;
  index:integer;      // position in the texture atlas (use partXXX flags)
  custom:integer;     // custom data, not used
 end;
 PParticle=^TParticle;

 // Text character attributes
 TCharAttr=record
  font:cardinal;
  color:cardinal;
 end;
 PCharAttr=^TCharAttr;

 TTextEffectLayer=record
  enabled:boolean; // включение эффекта
  blur:single;  // Размытие альфаканала надписи в пикселях (не более 1.9)
  fastblurX,fastblurY:integer; // быстрое сильное размытие
  color:cardinal; // заполнение данным цветом
  emboss,embossX,embossY:single; // Выдавливание (в цвете) на основе альфаканала
  dx,dy:single; // сдвиг эффекта
  power:single; // Усиление эффекта
 end;

 // Basic vertex format for regular primitives
 PVertex=^TVertex;
 TVertex=packed record
  x,y,z:single;
  color:cardinal;
  u,v:single;
  procedure Init(x,y,z,u,v:single;color:cardinal); overload; inline;
  procedure Init(x,y,z:single;color:cardinal); overload;
  class var layoutTex,layoutNoTex:TVertexLayout;
 end;

 // Vertex format for double textured primitives
 PVertex2t=^TVertex2t;
 TVertex2t=packed record
  x,y,z:single;
  color:cardinal;
  u,v:single;
  u2,v2:single;
  procedure Init(x,y,z,u,v,u2,v2:single;color:cardinal); inline;
  class function Layout:TVertexLayout; static;
 end;

 // Vertex format for 3D objects with lighting
 PVertex3D=^TVertex3D;
 TVertex3D=packed record
  x,y,z:single;
  color:cardinal;
  nx,ny,nz:single;
  extra:single;
  u,v:single;
  class function Layout:TVertexLayout; static;
 end;

 // vertex and index arrays
 TVertices=array of TVertex;
 TVertices3D=array of TVertex3D;
 TIndices=array of word;
 TTexCoords=array of TPoint2s;

 // Simple mesh
 TMesh=class
  layout:TVertexLayout;
  vertices:pointer;
  indices:TIndices; // Optional, can be empty
  vCount:integer; // Number of vertices allocated
  constructor Create(vertexLayout:TVertexLayout;vertCount,indCount:integer);
  procedure SetVertices(data:pointer;sizeInBytes:integer);
  procedure AddVertex(var vertexData);
  procedure AddTrg(v0,v1,v2:integer);
  procedure Draw(tex:TTexture=nil); // draw whole mesh
  destructor Destroy; override;
  function DumpVertex(n:cardinal):String8;
  function vPos:integer; // Returns number of vertices stored via AddVertex (current write position)
 private
  vData:PByte;
  idx:integer;
 end;

 PMultiTexLayer=^TMultiTexLayer;
 TMultiTexLayer=record
  texture:TTexture;
  matrix:T2DMatrix;  // матрица трансформации текстурных к-т
  next:PMultiTexLayer;
 end;

 // font handle structure: xxxxxxxx ssssssss yyyyyyyy 00ffffff (f - font object index, s - scale (percents), x - realtime effects, y - renderable effects and styles)
 TFontHandle=cardinal;

 // Text output, fonts (text protocol 2011)
 ITextDrawer=interface
  // Load font data
  function LoadFont(fname:string;asName:string=''):string; overload; // Returns name of the loaded font
  function LoadFont(font:array of byte;asName:string=''):string; overload; // Returns name of the loaded font
  // Get font handle (size=0 - default font size)
  function GetFont(name:string;size:single;flags:integer=0;effects:byte=0):TFontHandle;
  // Change option on a font handle
  procedure SetFontOption(handle:TFontHandle;option:cardinal;value:single);
  // Text output (use handle 0 for default font)
  procedure Write(font:TFontHandle;x,y:single;color:cardinal;st:String8;align:TTextAlignment=taLeft;
     options:integer=0;targetWidth:integer=0;query:cardinal=0);
  procedure WriteW(font:TFontHandle;x,y:single;color:cardinal;st:String16;align:TTextAlignment=taLeft;
     options:integer=0;targetWidth:integer=0;query:cardinal=0);
  // Measure text dimensions
  function Width(font:TFontHandle;st:String8):integer; // text width in pixels
  function WidthW(font:TFontHandle;st:String16):integer; // text width in pixels
  function Height(font:TFontHandle):integer; // Height of capital letters (like 'A'..'Z','0'..'9') in pixels
  function MeasuredCnt:integer; // length of the measured rects array
  function MeasuredRect(idx:integer):TRect; // rect[idx] of text measurement command
  // Hyperlinks
  procedure ClearLink; // Clear current link (call before text render)
  function Link:integer; // get hyperlink under mouse (filled during text render)
  function LinkRect:TRect; // get active hyperlink rect
  // Cache text output
  procedure BeginBlock(addOptions:cardinal=0); // optimize performance when drawing multiple text entries
  procedure EndBlock;   // finish buffering and perform actual render
  // Text render target
  procedure SetTarget(buf:pointer;pitch:integer); // set system memory target for text rendering (no clipping!)
 end;

 // Drawing interface
 IDrawer=interface
  // Basic primitives -----------------
  procedure Line(x1,y1,x2,y2:single;color:cardinal);
  procedure Polyline(points:PPoint2;cnt:integer;color:cardinal;closed:boolean=false);
  procedure Polygon(points:PPoint2;cnt:integer;color:cardinal);
  procedure Rect(x1,y1,x2,y2:NativeInt;color:cardinal); overload;
  procedure Rect(x1,y1,x2,y2:single;color:cardinal); overload;
  procedure RRect(x1,y1,x2,y2:single;color:cardinal;r:single=2);
  procedure FillRect(x1,y1,x2,y2:NativeInt;color:cardinal); overload;
  procedure FillRect(x1,y1,x2,y2:single;color:cardinal); overload;
  procedure ShadedRect(x1,y1,x2,y2,depth:integer;light,dark:cardinal);
  procedure FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal);
  procedure FillGradrect(x1,y1,x2,y2:integer;color1,color2:cardinal;vertical:boolean);

  // Textured primitives ---------------
  // Указываются к-ты тех пикселей, которые будут зарисованы (без границы)
  procedure Image(x_,y_:NativeInt;tex:TTexture;color:cardinal=$FF808080); overload;
  procedure Image(x,y,scale:single;tex:TTexture;color:cardinal=$FF808080;pivotX:single=0;pivotY:single=0); overload;
  procedure ImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080);
  procedure Centered(x,y:NativeInt;tex:TTexture;color:cardinal=$FF808080); overload;
  procedure Centered(x,y,scale:single;tex:TTexture;color:cardinal=$FF808080); overload;
  procedure ImagePart(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect);
  // Рисовать часть картинки с поворотом ang раз на 90 град по часовой стрелке
  procedure ImagePart90(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect;ang:integer);
  procedure TexturedRect(x1,y1,x2,y2:integer;texture:TTexture;u1,v1,u2,v2,u3,v3:single;color:cardinal);
  procedure Scaled(x1,y1,x2,y2:single;image:TTexture;color:cardinal=$FF808080); overload;
  procedure Scaled(x,y,scale:single;image:TTexture;color:cardinal=$FF808080); overload;
  procedure RotScaled(x,y,scaleX,scaleY,angle:double;image:TTexture;color:cardinal=$FF808080;pivotX:single=0.5;pivotY:single=0.5);

  // Returns scale
  function Cover(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single;
  function Inside(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single;

  // Meshes ------------------
  // Draw textured tri-mesh (tex=nil -> colored mode)
  procedure TrgList(vertices:PVertex;trgCount:integer;tex:TTexture); overload;
  procedure TrgList(vertices:pointer;layout:TVertexLayout;trgCount:integer;tex:TTexture); overload;
  procedure TrgList3D(vertices:PVertex3D;trgCount:integer;tex:TTexture); overload;
  // Draw indexed tri-mesh (tex=nil -> colored mode)
  procedure IndexedMesh(vertices:PVertex3D;indices:PWord;trgCount,vrtCount:integer;tex:TTexture); overload;
  procedure IndexedMesh(vertices:pointer;layout:TVertexLayout;indices:PWord;trgCount,vrtCount:integer;tex:TTexture); overload;

  // Multitexturing functions ------------------
  // Режим мультитекстурирования должен быть предварительно настроен с помощью SetTexMode / SetTexInterpolationMode
  // а затем сброшен с помощью SetTexMode(1,tblDisable)
  // Рисует два изображения, наложенных друг на друга, за один проход (если размер отличается, будет видна лишь общая часть)
  procedure DoubleTex(x,y:integer;image1,image2:TTexture;color:cardinal=$FF808080);
  // Рисует два изображения (каждое - с индвидуальным масштабом), повёрнутых на одинаковый угол. ЯЕсли итоговый размер отличается - будет видна лишь общая часть)
  procedure DoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
      image1,image2:TTexture;color:cardinal=$FF808080);
  // Заполнение прямоугольника несколькими текстурами (из списка)
  //procedure MultiTex(x1,y1,x2,y2:integer;layers:PMultiTexLayer;color:cardinal=$FF808080);

  // Particles ------------------------------------------
  procedure Particles(x,y:integer;data:PParticle;count:integer;tex:TTexture;size:integer;zDist:single=0);
  procedure Band(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect);
 end;

 // Interface to the graphics subsystem: OpenGL, Vulkan or Direct3D
 IGraphicsSystem=interface
  // Init subsystem and create all interface objects
  procedure Init(system:ISystemPlatform);
  procedure Done;
  function GetVersion:single; // like 3.1 for OpenGL 3.1
  function GetName:string; // get implementation class name

  // APIs
  function config:IGraphicsSystemConfig;
  function resman:IResourceManager;
  function target:IRenderTarget;
  function shader:IShader;
  function clip:IClipping;
  function transform:ITransformation;
  function draw:IDrawer;
  function txt:ITextDrawer;

  // Start drawing block using the specified render target (nil - use default target)
  procedure BeginPaint(target:TTexture=nil);
  // Finish drawing block
  procedure EndPaint;
  // Set cull mode
  procedure SetCullMode(mode:TCullMode);

  // Get image from Backbuffer (screenshot etc)
  procedure CopyFromBackbuffer(srcX,srcY:integer;image:TRawImage);
  // Present backbuffer to the screen
  procedure PresentFrame;
  // Restore (invalidate) gfx settings
  procedure Restore;
  // show additional info
  procedure DrawDebugOverlay(idx:integer);
  // Do something meaningless (like glFlush) that can be detected by an external gfx debugger
  procedure Breakpoint;
 end;

 TGameScene=class;

 // Базовый эффект для background-сцены
 TSceneEffect=class
  timer:integer; // время (в тысячных секунды), прошедшее с момента начала эффекта
  duration:integer;  // время, за которое эффект должен выполнится
  done:boolean;  // Флаг, сигнализирующий о том, что эффект завершен
  target:TGameScene;
  name:string; // description for debug reasons
  constructor Create(scene:TGameScene;TotalTime:integer); // создать эффект на заданное время (в мс.)
  procedure DrawScene; virtual; abstract; // Процедура должна полностью выполнить отрисовку сцены с эффектом (в текущий RT)
  destructor Destroy; override;
 end;

 // -------------------------------------------------------------------
 // TGameScene - произвольная сцена
 // -------------------------------------------------------------------
 TSceneStatus=(ssFrozen,     // сцена полностью "заморожена"
               ssBackground, // сцена обрабатывается, но не рисуется
                             // (живет где-то в фоновом режиме и не влияет на экран)
               ssActive);    // сцена активна, т.е. обрабатывается и рисуется

 TGameScene=class
  status:TSceneStatus;
  name:string;
  fullscreen:boolean; // true - opaque scene, no any underlying scenes can be seen, false - scene layer is drawn above underlying image
  frequency:integer; // Сколько раз в секунду нужно вызывать обработчик сцены (0 - каждый кадр)
  effect:TSceneEffect; // Эффект, применяемый при выводе сцены
  zOrder:integer; // Определяет порядок отрисовки сцен
  activated:boolean; // true если сцена уже начала показываться или показалась, но еще не имеет эффекта закрытия
  shadowColor:cardinal; // если не 0, то рисуется перед отрисовкой сцены
  ignoreKeyboardEvents:boolean; // если true - такая сцена не будет получать сигналы о клавиатурном вводе, даже будучи верхней
  initialized:boolean;

  // Внутренние величины
  accumTime:integer; // накопленное время (в мс)

  constructor Create(fullscreen:boolean=true);
  destructor Destroy; override;

  // Вызывается из конструктора, можно переопределить для инициализации без влезания в конструктор
  // !!! Call this manually from constructor!
  procedure onCreate; virtual;

  // Для изменения статуса использовать только это!
  procedure SetStatus(st:TSceneStatus); virtual;

  // Called only once from the main thread before first Render() call
  procedure Initialize; virtual;

  // Обработка сцены, вызывается с заданной частотой если только сцена не заморожена
  // Этот метод может выполнять логику сцены, движение/изменение объектов и т.п.
  function Process:boolean; virtual;

  // Рисование сцены. Вызывается каждый кадр только если сцена активна и изменилась
  // На момент вызова установлен RenderTarget и все готово к рисованию
  // Если сцена соержит свой слой UI, то этот метод должен вызвать
  // рисовалку UI для его отображения
  procedure Render; virtual;

  // Определить есть ли нажатия клавиш в буфере
  function KeyPressed:boolean; virtual;
  // Прочитать клавишу из буфера: 0xAAAABBCC
  // AAAA - unicode char, BB - scancode, CC - ansi char
  function ReadKey:cardinal; virtual;
  // Записать клавишу в буфер
  procedure WriteKey(key:cardinal); virtual;
  // Очистить буфер нажатий
  procedure ClearKeyBuf; virtual;

  // Смена режима (что именно изменилось - можно узнать косвенно)
  procedure ModeChanged; virtual;

  // Сообщение о том, что область отрисовки (она может быть частью окна) изменила размер, сцена может отреагировать на это
  procedure onResize; virtual;
  // События мыши
  procedure onMouseMove(x,y:integer); virtual;
  procedure onMouseBtn(btn:byte;pressed:boolean); virtual;
  procedure onMouseWheel(delta:integer); virtual;

  // For non-fullscreen scenes return occupied area
  function GetArea:TRect; virtual; abstract;
 private
  // Ввод
  KeyBuffer:array[0..63] of cardinal;
  first,last:byte;
 end;

 // Enable built-in gamepad navigation with DPad and X/Y buttons
 TGamepadNavigationMode=(
   gnmDisabled,  // no gamepad navigation
   gnmCustom,    // enable navigation over manually specified points
   gnmAuto);     // enable navigation over manual points and clickable UI elements

 TDebugFeature=(
   dfShowFPS,                 // Display frame rate
   dfShowMagnifier,           // Magnifier (Alt+F3)
   dfShowGlyphCache,          // Display glyphs cache
   dfShowNavigationPoints     // Display gamepad navigation points
 );

 // Hotkey used to toggle debug overlay mode
 TDebugHotkey=(dhAltFx, dhCtrlAltFx);

  // Main game interface
 TGameBase=class
  // Global variables
  running:boolean;     // true when main loop is running
  renderWidth,renderHeight:integer; // Size of render area in virtual pixels (primitive of this size fills the whole renderRect)
  displayRect:TRect;     // render area (inside window's client area) in screen pixels (default - full client area)
  screenWidth,screenHeight:integer; // real full screen size in pixels
  windowWidth,windowHeight:integer; // window client size in pixels
  screenDPI:integer;    // DPI according to system settings
  active:boolean;       // true when window is visible and updated; when active is false frame is not rendered
  paused:boolean;       // pause rendering regardless if window is active
  terminated:boolean;   // true when main loop is finished
  screenChanged:boolean;  // set this to true to request frame rendering regardless of scenes processing
  frameNum:integer;     // increments every frame
  frameStartTime:int64; // MyTickCount when frame started
  FPS,smoothFPS:single; // current and smoothed FPS

  // Default (built-in) font handles (for debug overlays etc)
  smallFont,defaultFont,largerFont:TFontHandle; // font sizes are selected according to the screen DPI
  defaultLineHeight:integer; // line height (in pixels) for the default font
  screenScale:single; // screen scale factor (depends on DPI, rounded) like 1.0, 1.5 etc

  // Input state:
  // Mouse
  mouseX,mouseY:integer; // положение мыши внутри окна/экрана
  oldMouseX,oldMouseY:integer; // предыдущее положение мыши (не на предыдущем кадре, а вообще!)
  mouseMovedTime:int64; // Момент времени, когда положение мыши изменилось
  mouseButtons:byte;     // Флаги "нажатости" кнопок мыши (0-левая, 1-правая, 2-средняя)
  oldMouseButtons:byte;  // предыдущее (отличающееся) значение mouseButtons

  // Keyboard
  shiftState:byte; // состояние клавиш сдвига (1-shift, 2-ctrl, 4-alt, 8-win)
  // bit 0 - pressed, bit 1 - was pressed last frame. So 01 means key was just pressed, 10 - just released
  // indexed by scancode (NOT virtual key code!)
  keyState:array[0..255] of byte;

  debugHotkey:TDebugHotkey; // Hotkey used to toggle debug overlays (default - Alt+F1)

  gamepadNavigationMode:TGamepadNavigationMode; // used to enable gamepad (DPad) navigation over UI elements and user-defined objects

  // Text link (TODO: move out)
  textLink:cardinal; // Вычисленный на предыдущем кадре номер ссылки под мышью записывается здесь (сам по себе он не вычисляется, для этого надо запускать отрисовку текста особым образом)
                     // TODO: плохо, что этот параметр глобальный, надо сделать его свойством сцен либо элементов UI, чтобы можно было проверять объект под мышью с учётом наложений
  textLinkRect:TRect; // область ссылки, по номеру textLink

  topmostScene:TGameScene; // last topmost scene
  globalTintColor:cardinal; // multiplier (2X) for whole backbuffer ($FF808080 - neutral value)

  constructor Create(sysPlatform:ISystemPlatform;gfxSystem:IGraphicsSystem);

  // Settings
  procedure SetSettings(s:TGameSettings); virtual; abstract;
  function GetSettings:TGameSettings; virtual; abstract;

  // Start/stop game
  // ---------------
  procedure Run; virtual; abstract; // запустить движок (создание окна, переключение режима и пр.)
  procedure Stop; virtual; abstract; // остановить и освободить все ресурсы (требуется повторный запуск через Run)
  // Change mode (Alt+Enter)
  procedure SwitchToAltSettings; virtual; abstract;

  // Frame events
  // ------------
  // Called before each frame. Returns true if something was changed and screen should be redrawn. False - nothing changed, no redraw.
  function OnFrame:boolean; virtual; abstract;
  // Renders frame to the backbuffer
  procedure RenderFrame; virtual; abstract;

  // Scenes
  // ------
  procedure AddScene(scene:TGameScene); virtual; abstract;
  procedure RemoveScene(scene:TGameScene); virtual; abstract;
  function TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene; virtual; abstract;
  function GetScene(name:string):TGameScene; virtual; abstract;

  // Cursors
  // -------
  // Assign a cursor handle (system or cursom) to a cursor ID
  procedure RegisterCursor(CursorID,priority:integer;cursorHandle:THandle); virtual; abstract;
  // Get cursor handle assigned for given ID
  function GetCursorForID(cursorID:integer):THandle; virtual; abstract;
  // Toggle cursor on or off
  procedure ToggleCursor(CursorID:integer;state:boolean=true); virtual; abstract;
  // Toggle all cursors off
  procedure HideAllCursors; virtual; abstract;

  // Screen coordinates
  // ------------------
  procedure ClientToGame(var p:TPoint); virtual; abstract;
  procedure GameToClient(var p:TPoint); virtual; abstract;

  // Threads and async jobs
  // ----------------------
  // Запустить функцию на параллельное выполнение (ttl - лимит времени в секундах, если есть)
  // По завершению будет выдано событие engine\thread\done с кодом, возвращенным ф-цией, либо -1 если завершится по таймауту
  function RunAsync(threadFunc:pointer;param:cardinal=0;ttl:single=0;name:string=''):THandle; virtual; abstract;
  // Функция все еще выполняется? если да - вернет 0,
  // если прервана по таймауту - -1, если неверный хэндл - -2, иначе - результат функции
  function GetThreadResult(h:THandle):integer; virtual; abstract;

  // Debug tools
  // -----------
  // Добавляет строку в "кадровый лог" - невидимый лог, который обнуляется каждый кадр, но может быть сохранен в случае какой-либо аварийной ситуации
  procedure FLog(st:string); virtual; abstract;
  function GetStatus(n:integer):string; virtual; abstract;
  // Show message in engine-driven pop-up (3 sec)
  procedure FireMessage(st:String8); virtual; abstract;
  // Enable/disable debug overlays
  procedure DebugFeature(feature:TDebugFeature;enabled:boolean); virtual; abstract;

  // Synchronization (access to the internal critical section)
  // ---------------
  procedure EnterCritSect; virtual; abstract;
  procedure LeaveCritSect; virtual; abstract;

  // Screen capturing
  // ----------------
  // Устанавливает флаги о необходимости сделать скриншот (JPEG или TGA)
  procedure RequestScreenshot(saveAsJpeg:boolean=true); virtual; abstract;
  procedure RequestFrameCapture(obj:TObject=nil); virtual; abstract;
  procedure StartVideoCap(filename:string); virtual; abstract;
  procedure FinishVideoCap; virtual; abstract;
  // При включенной видеозаписи вызывается видеокодером для освобождения памяти кадра
  procedure ReleaseFrameData(obj:TObject); virtual; abstract;

  // Utility functions
  // -----------------
  function MouseInRect(r:TRect):boolean; overload; virtual; abstract;
  function MouseInRect(r:TRect2s):boolean; overload; virtual; abstract;
  function MouseInRect(x,y,width,height:single):boolean; overload; virtual; abstract;
  function MouseIsNear(x,y,radius:single):boolean; virtual; abstract;

  function MouseWasInRect(r:TRect):boolean;overload; virtual; abstract;
  function MouseWasInRect(r:TRect2s):boolean; overload; virtual; abstract;

  function RenderSize:TSize; // returns (renderWidth,renderHeight)

  // Wait until pb^ is not false (not zero), toggle crWait cursor during waiting
  procedure WaitFor(pb:PBoolean;msg:string=''); virtual; abstract;

  // Keyboard events utility functions
  procedure SuppressKbdEvent; virtual; abstract; // Suppress handling of the related keyboard event(s)

  // Window control functions
  // -----------------
  procedure Minimize; virtual; abstract;
  procedure MoveWindowTo(x, y, width, height: integer); virtual; abstract;
  procedure SetWindowCaption(text: string); virtual; abstract;

  // Gamepad navigation
  // This should be called every frame for each point that should be available for navigation
  // during the next frame
  procedure DPadCustomPoint(x,y:single); virtual; abstract;
 end;

 TDisplayModeHelper = record helper for TDisplayMode
  function ToString:string;
 end;
 TDisplayFitModeHelper = record helper for TDisplayFitMode
  function ToString:string;
 end;
 TDisplayScaleModeHelper = record helper for TDisplayScaleMode
  function ToString:string;
 end;

var
 // Global shortcuts to the key interfaces
 // ---------------------------------------
 systemPlatform:ISystemPlatform;
 gfx:IGraphicsSystem;
 game:TGameBase;

 shader:IShader; //< shortcut for gfx.shader
 draw:IDrawer;    //< shortcut for gfx.draw
 txt:ITextDrawer; //< shortcut for gfx.txt
 transform:ITransformation; //< Shortcut for gfx.transform

 // Selected pixel formats for different tasks
 // Используемые форматы пикселя (в какие форматы грузить графику)
 pfTrueColorAlpha:TImagePixelFormat; // Формат для загрузки true-color изображений с прозрачностью
 pfTrueColor:TImagePixelFormat; // то же самое, но без прозрачности
 pfTrueColorAlphaLow:TImagePixelFormat; // То же самое, но для картинок, качеством которых можно пожертвовать
 pfTrueColorLow:TImagePixelFormat; // То же самое, но для картинок, качеством которых можно пожертвовать
 // форматы для отрисовки в текстуру
 pfRenderTarget:TImagePixelFormat;       // обычное изображение
 pfRenderTargetAlpha:TImagePixelFormat;  // вариант с альфаканалом

 // Shortcuts to the most used functions
 // ------------------------------------

 // Load image from a file. In case of failure throws an exception!
 // fname is handled by FileName()
 function LoadImageFromFile(fname:string;flags:cardinal=0;ForceFormat:TImagePixelFormat=ipfNone):TTexture;

 // (Re)load texture from an image file. defaultImagesDir is used if path is relative
 // Default flags can be used from defaultLoadImageFlags
 procedure LoadImage(var img:TTexture;fName:string;flags:cardinal=liffDefault);

 // Load a texture atlas.
 // Then if you try to load an image from a file - it is cloned from the atlas.
 // Not thread-safe! Don't load atlases in one thread and create images in other thread
 procedure LoadAtlas(fname:string;scale:single=1.0);

 // Load image from the specified file and create a Nine Patch object from it (image must be marked)
 // Set scale factor to 2 if image has double resolution
 function LoadNinePatch(fName:string;scale2x:boolean=false):TNinePatch;
 function CreateNinePatch(image:TTexture;scale2x:boolean=false):TNinePatch;

 // Shortcuts to the texture manager
 function AllocImage(width,height:integer;pixFmt:TImagePixelFormat=ipfARGB;
                flags:integer=0;name:String8=''):TTexture;
 procedure FreeImage(var img:TTexture);

 // Lock the texture (if not yet locked) and set it as draw target for FastGFX unit (don't forget to unlock)
 procedure DrawToTexture(tex:TTexture;mipLevel:integer=0);

 // Translate string using localization dictionary (UDict)
 function Translate(st:string8):string8; overload; inline;
 function Translate(st:string16):string16; overload; inline;

 // Process events/system messages and wait at least time ms
 procedure Delay(time:integer);

 // Utility functions
 function GetKeyEventScanCode(tag:TTag):cardinal; // Extract scancode form KBD\KeyXXX event
 function GetKeyEventVirtualCode(tag:TTag):cardinal; // Extract virtual key code form KBD\KeyXXX event

 // Is mouse button pressed?
 function IsMouseBtn(btn:integer):boolean;
 // Is key down?
 function IsKeyDown(scanCode:integer):boolean;
 // Was key pressed since last frame?
 function IsKeyPressed(scanCode:integer):boolean;
 // Was key released since last frame?
 function IsKeyReleased(scanCode:integer):boolean;

implementation
 uses SysUtils, Apus.Publics, Apus.Engine.ImageTools, Apus.Engine.UDict, Apus.Engine.Game,
   TypInfo, Apus.Engine.Tools, Apus.Engine.Graphics, Apus.FastGFX, Apus.Engine.NinePatch, Apus.Structs;

 var
  ninePatchHash:TObjectHash;

 function GetKeyEventScanCode(tag: TTag): cardinal;
  begin
   result:=(tag shr 24) and $FF;
  end;

 function GetKeyEventVirtualCode(tag: TTag): cardinal;
  begin
   result:=tag and $FFFF;
  end;

 constructor TGameBase.Create;
  begin
   game:=self;
   systemPlatform:=sysPlatform;
   gfx:=gfxSystem;
   debugHotkey:=dhAltFx;
  end;

{ TGameScene }

procedure TGameScene.ClearKeyBuf;
begin
 first:=0; last:=0;
end;

constructor TGameScene.Create(fullScreen:boolean=true);
begin
 status:=ssFrozen;
 self.fullscreen:=fullscreen;
 frequency:=60;
 first:=0; last:=0;
 zorder:=0;
 activated:=false;
 effect:=nil;
 name:=ClassName;
 ignoreKeyboardEvents:=false;
 if classType=TGameScene then onCreate; // each generic child class must call this in the constructors last string
end;

destructor TGameScene.Destroy;
begin
 if status<>ssFrozen then raise EError.Create('Scene must be frozen before deletion: '+name+' ('+ClassName+')');
end;

procedure TGameScene.Initialize;
begin
end;

function TGameScene.KeyPressed: boolean;
begin
 result:=first<>last;
end;

procedure TGameScene.ModeChanged;
begin
end;

procedure TGameScene.onMouseBtn(btn: byte; pressed: boolean);
begin
end;

procedure TGameScene.onMouseMove(x, y: integer);
begin
end;

procedure TGameScene.onMouseWheel(delta:integer);
begin
end;

procedure TGameScene.onResize;
begin
end;

function TGameScene.Process: boolean;
begin
 result:=true;
end;

procedure TGameScene.onCreate;
begin
end;

function TGameScene.ReadKey: cardinal;
begin
 if first<>last then begin
  result:=KeyBuffer[first];
  first:=(first+1) and 63;
 end else result:=0;
end;

procedure TGameScene.Render;
begin
end;

procedure TGameScene.SetStatus(st: TSceneStatus);
begin
 status:=st;
 if status=ssActive then activated:=true
  else activated:=false;
end;

procedure TGameScene.WriteKey(key: cardinal);
begin
 KeyBuffer[last]:=key;
 last:=(last+1) and 63;
 if last=first then
 first:=(first+1) and 63;
end;

{ TSceneEffect }

constructor TSceneEffect.Create(scene:TGameScene;TotalTime:integer);
begin
 done:=false;
 duration:=TotalTime;
 if duration=0 then duration:=10;
 timer:=0;
 if scene.effect<>nil then begin
  ForceLogMessage('New scene effect replaces old one! '+scene.name+' previous='+scene.effect.name);
  scene.effect.Free;
 end;
 scene.effect:=self;
 target:=scene;
 name:=self.ClassName+' for '+scene.name+' created '+FormatDateTime('nn:ss.zzz',Now);
 LogMessage('Effect %s: %s',[PtrToStr(self),name]);
end;

destructor TSceneEffect.Destroy;
begin
  LogMessage('Scene effect %s deleted: %s',[PtrToStr(self),name]);
  inherited;
end;

// Utils
function fGetFontHandle(params:string;tag:integer;context:pointer;contextClass:TVarClassStruct):double;
 var
  sa:StringArr;
  style,effects:byte;
  size:double;
 begin
  if txt=nil then raise EWarning.Create('TextDrawer is not ready');
  sa:=split(',',params);
  if length(sa)<2 then raise EWarning.Create('Invalid parameters');
  size:=EvalFloat(sa[1],nil,context,contextClass);
  style:=0; effects:=0;
  if length(sa)>2 then style:=round(EvalFloat(sa[2],nil,context,contextClass));
  if length(sa)>3 then effects:=round(EvalFloat(sa[3],nil,context,contextClass));
  result:=txt.GetFont(sa[0],size,style,effects);
 end;

function LoadImageFromFile(fname:string;flags:cardinal=0;ForceFormat:TImagePixelFormat=ipfNone):TTexture;
 begin
   result:=Apus.Engine.ImageTools.LoadImageFromFile(fname,flags,forceFormat);
 end;

procedure LoadImage(var img:TTexture;fName:string;flags:cardinal=liffDefault);
 begin
   Apus.Engine.ImageTools.LoadImage(img,fname,flags);
 end;

procedure LoadAtlas(fname:string;scale:single=1.0);
 begin
   Apus.Engine.ImageTools.LoadAtlas(fname,scale);
 end;

function LoadNinePatch(fName:string;scale2x:boolean=false):TNinePatch;
 var
  img:TTexture;
 begin
  img:=LoadImageFromFile(fName,liffAllowChange);
  result:=CreateNinePatch(img,scale2x);
 end;

function CreateNinePatch(image:TTexture;scale2x:boolean=false):TNinePatch;
 begin
  result:=TCustomNinePatch.Create(image);
  if scale2x then result.scaleFactor:=0.5;
 end;

function AllocImage(width,height:integer;pixFmt:TImagePixelFormat=ipfARGB;
                flags:integer=0;name:String8=''):TTexture;
 begin
  if gfx.resman<>nil then
   result:=gfx.resman.AllocImage(width,height,pixFmt,flags,name)
  else
   raise EWarning.Create('Failed to alloc texture: no texture manager');
 end;

procedure FreeImage(var img:TTexture);
 begin
  if img<>nil then
   gfx.resman.FreeImage(img);
 end;

function Translate(st:string8):string8; overload;
 begin
  result:=Apus.Engine.UDict.Translate(st);
 end;

function Translate(st:string16):string16; overload;
 begin
  result:=Apus.Engine.UDict.Translate(st);
 end;

procedure Delay(time:integer);
 begin
  Apus.Engine.Game.Delay(time);
 end;

function TDisplayModeHelper.ToString:string;
 begin
  result:=GetEnumNameSafe(TypeInfo(TDisplayMode),ord(self));
 end;
function TDisplayFitModeHelper.ToString: string;
 begin
  result:=GetEnumNameSafe(TypeInfo(TDisplayFitMode),ord(self));
 end;
function TDisplayScaleModeHelper.ToString: string;
 begin
  result:=GetEnumNameSafe(TypeInfo(TDisplayScaleMode),ord(self));
 end;

function IsMouseBtn(btn:integer):boolean;
 begin
  ASSERT(game<>nil);
  result:=HasFlag(game.mouseButtons,1 shl (btn-1));
 end;

function IsKeyDown(scanCode:integer):boolean;
 begin
  ASSERT(game<>nil);
  result:=HasFlag(game.keyState[scanCode],1);
 end;

function IsKeyPressed(scanCode:integer):boolean;
 begin
  ASSERT(game<>nil);
  result:=game.keyState[scanCode] and $3=1;
 end;

function IsKeyReleased(scanCode:integer):boolean;
 begin
  ASSERT(game<>nil);
  result:=game.keyState[scanCode] and $3=2;
 end;

procedure DrawToTexture(tex:TTexture;mipLevel:integer=0);
 begin
  if not tex.IsLocked then tex.Lock(mipLevel);
  SetRenderTarget(tex.data,tex.pitch,tex.width shr mipLevel,tex.height shr mipLevel);
 end;


{ TMesh }

procedure TMesh.AddTrg(v0,v1,v2: integer);
 begin
  indices[idx]:=v0; inc(idx);
  indices[idx]:=v1; inc(idx);
  indices[idx]:=v2; inc(idx);
 end;

procedure TMesh.AddVertex(var vertexData);
 begin
  ASSERT(PointerInRange(vData,vertices,vCount*layout.stride));
  move(vertexData,vData^,layout.stride);
  inc(vData,layout.stride);
 end;

function TMesh.DumpVertex(n:cardinal):String8;
 var
  pb:PByte;
 begin
  ASSERT(n<vCount);
  pb:=vertices;
  inc(pb,n*layout.stride);
  result:=layout.DumpVertex(pb^);
 end;

constructor TMesh.Create(vertexLayout: TVertexLayout; vertCount, indCount: integer);
 begin
  layout:=vertexLayout;
  vCount:=vertCount;
  if vCount>0 then GetMem(vertices,vCount*layout.stride);
  SetLength(indices,indCount);
  vData:=vertices;
  idx:=0;
 end;

destructor TMesh.Destroy;
 begin
  FreeMem(vertices);
  inherited;
 end;

procedure TMesh.Draw(tex:TTexture=nil); // draw whole mesh
 begin
  if length(indices)>0 then
   Apus.Engine.API.draw.IndexedMesh(vertices,layout,@indices[0],
     length(indices) div 3,vCount,tex)
  else
   Apus.Engine.API.draw.TrgList(vertices,layout,vCount div 3,tex)
 end;

procedure TMesh.SetVertices(data: pointer; sizeInBytes: integer);
 begin
  FreeMem(vertices);
  vertices:=data;
  vCount:=sizeInBytes div layout.stride;
  vData:=vertices;
 end;

function TMesh.vPos: integer;
 begin
  result:=(UIntPtr(vData)-UIntPtr(vertices)) div layout.stride;
 end;

{ TVertex }

procedure TVertex.Init(x, y, z, u, v: single; color: cardinal);
 begin
  self.x:=x; self.y:=y; self.z:=z;
  self.color:=color;
  self.u:=u; self.v:=v;
 end;

procedure TVertex.Init(x, y, z: single; color: cardinal);
 begin
  self.x:=x; self.y:=y; self.z:=z;
  self.color:=color;
  self.u:=0.5; self.v:=0.5;
 end;

{ TVertex2t }

procedure TVertex2t.Init(x, y, z, u, v, u2, v2: single; color: cardinal);
 begin
  self.x:=x; self.y:=y; self.z:=z;
  self.color:=color;
  self.u:=u; self.v:=v;
  self.u2:=u2; self.v2:=v2;
 end;

class function TVertex2t.Layout:TVertexLayout;
 var
  v:PVertex2t;
 begin
  v:=nil;
  result.Init(0,0,integer(@v.color),integer(@v.u),integer(@v.u2));
  ASSERT(result.stride=sizeof(TVertex2t));
 end;

{ TVertex3D }

class function TVertex3D.Layout:TVertexLayout;
 var
  v:PVertex3D;
 begin
  v:=nil;
  result.Init(0,integer(@v.nx),integer(@v.color),integer(@v.u),0);
  result.stride:=Sizeof(TVertex3D);
 end;

{ TNinePatch }

class function TNinePatch.ClassHash: pointer;
 begin
  result:=@ninePatchHash;
 end;

function TGameBase.RenderSize:TSize;
 begin
  result.cx:=renderWidth;
  result.cy:=renderHeight;
 end;

initialization
 PublishFunction('GetFont',fGetFontHandle);
 TVertex.layoutTex.Init(0,0,12,16,0); // color and uv1
 TVertex.layoutTex.stride:=Sizeof(TVertex);
 TVertex.layoutNoTex.Init(0,0,12,0,0); // color only
 TVertex.layoutNoTex.stride:=Sizeof(TVertex);
end.
