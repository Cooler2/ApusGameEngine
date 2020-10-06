// Definition of engine's abstract classes structure
//
// Copyright (C) 2003 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit EngineAPI;
interface
 uses Images,Geom2D,Geom3D,types,EventMan,publics;

const
 // Image allocation flags (ai - AllocImage)
 aiMipMapping     =  1; // Allocate mip-map levels (may be auto-generated upon of implementation)
 aiTexture        =  2; // Allocate full texture object of the underlying API (no texture sharing)
 aiRenderTarget   =  4; // Image can be used as Render Target for GPU (no CPU access)
 aiSysMem         =  8; // Image will have its buffer in system RAM, so can be accessed by CPU
 aiPow2           = 16; // Enlarge dimensions to be PoT
// aiWriteOnly      = 32; // Can be locked, but for write only operation
 aiDontScale      = 64; // Use exact width/height for render target allocation (otherwise they're scaled using current scale factor)
 aiClampUV        = 128; // clamp texture coordinates instead of wrapping them (for aiTexture only)
 aiUseZBuffer     = 256; // allocate Depth Buffer for this image (for aiRenderTarget only)

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

 // Texture features flags
 tfCanBeLost      = 1;   // Texture data can be lost at any moment
 tfDirectAccess   = 2;   // CPU access allowed, texture can be locked
 tfNoRead         = 4;   // Reading of texture data is not allowed
 tfNoWrite        = 8;   // Writing to texture data is not allowed
 tfRenderTarget   = 16;  // Can be used as a target for GPU rendering
 tfAutoMipMap     = 32;  // MIPMAPs are generated automatically, don't need to fill manually
 tfNoLock         = 64;  // No need to lock the texture to access its data
 tfClamped        = 128; // By default texture coordinates are clamped (otherwise - not clamped)
 tfVidmemOnly     = 256; // Texture uses only VRAM (can't be accessed by CPU)
 tfSysmemOnly     = 512; // Texture uses only System RAM (can't be used by GPU)
 tfTexture        = 1024; // Texture corresponds to a texture object of the underlying API
 tfScaled         = 2048; // scale factors are used
 tfCloned         = 4096; // Texture object is cloned from another, so don't free any underlying resources

 // Special flags for the "index" field of particles
 partPosU  = $00000001;
 partPosV  = $00000100;
 partSizeU = $00010000;
 partSizeV = $00100000;
 partFlip  = $01000000;
 partEndpoint = $02000000; // free end of a polyline
 partLoop = $04000000; // end of a polyline loop

 // Primitive types
 LINE_LIST = 1;
 LINE_STRIP = 2;
 TRG_FAN = 3;
 TRG_STRIP = 4;
 TRG_LIST = 5;

 // TextOut options flags (overrides font handle flags)
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

 // GetFont style flags
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


type
 // Which API use for rendering
 TGraphicsAPI=(gaAuto,     // Check one considering defined symbols
               gaDirectX,  // Currently Direct3D8
               gaOpenGL,   // OpenGL 1.4 or higher with fixed function pipeline
               gaOpenGL2); // OpenGL 2.0 or higher with shaders

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
                   tblInterpolate // previous*factor+texture*(1-factor) текстурные стадии смешиваются между собой
                   );
{ TTexInterpolateMode=(tintFactor, // factor=constant
                      tintDiffuse, // factor=diffuse alpha
                      tintTexture, // factor=texture alpha
                      tintCurrent); // factor=previous stage alpha}

 // Режим интерполяции текстур
 TTexFilter=(fltUndefined,    // filter not defined
             fltNearest,      // Без интерполяции
             fltBilinear,     // Билинейная интерполяция
             fltTrilinear,    // Трилинейная (только для mip-map)
             fltAnisotropic); // Анизотропная (только для mip-map)

 TTextAlignment=(taLeft,      // обычный вывод
                 taCenter,    // точка вывода указывает на центр надписи
                 taRight,     // точка вывода указывает на правую границу
                 taJustify);  // точка вывода указывает на левую границу, а spacing - ширина строки
                              // (вывод превращается в левый если реальная ширина строки слишком мала или строка заканчивается на #10 или #13)

 // Access mode for locked resources
 TLockMode=(lmReadOnly,       // read-only (do not invalidate data when unlocked)
            lmReadWrite,      // read+write (invalidate the whole area)
            lmCustomUpdate);  // read+write, do not invalidate anything (AddDirtyRect is required, partial lock is not allowed in this case)


 // -------------------------------------------------------------------
 // Textures - классы текстурных изображений
 // -------------------------------------------------------------------
 texnamestr=string;

 // Базовый абстрактный класс - текстура или ее часть
 TTexture=class
  PixelFormat:ImagePixelFormat;
  width,height:integer; // dimension (in virtual pixels)
  left,top:integer; // position
  mipmaps:byte; // кол-во уровней MIPMAP
  caps:integer; // возможности и флаги
  name:texnamestr; // texture name (for debug purposes)
  refCounter:integer; // number of child textures referencing this texture data
  parent:TTexture;
  // These properties may not be valid if texture is not ONLINE
  u1,v1,u2,v2:single; // texture coordinates
  stepU,stepV:single; // halved texel step
  // These properties are valid when texture is LOCKED
  data:pointer;   // raw data
  pitch:integer;  // offset to next scanline

  // Create cloned image (separate object referencing the same image data). Original image can't be destroyed unless all its clones are destroyed
  constructor CreateClone(src:TTexture);
  function Clone:TTexture;
  function ClonePart(part:TRect):TTexture;
  procedure Lock(miplevel:byte=0;mode:TLockMode=lmReadWrite;rect:PRect=nil); virtual; abstract; // 0-й уровень - самый верхний
  procedure LockNext; virtual; abstract; // lock next mip-map level
  function GetRawImage:TRawImage; virtual; abstract; // Create RAW image for the topmost MIP level (when locked)
  function IsLocked:boolean;
  procedure Unlock; virtual; abstract;
  procedure AddDirtyRect(rect:TRect); virtual; abstract; // mark area to update when unlocked (mode=lmCustomUpdate)
  procedure GenerateMipMaps(count:byte); virtual; abstract; // Сгенерировать изображения mip-map'ов
 protected
  locked:integer; // lock counter
 end;

 // -------------------------------------------------------------------
 // TextureManager - менеджер изображений (фактически, менеджер текстурной памяти)
 // -------------------------------------------------------------------

 TTextureMan=class
  scaleX,scaleY:single; // scale factor for render target allocation
  maxTextureSize,maxRTtextureSize:integer;
  // Создать изображение (в случае ошибки будет исключение)
  function AllocImage(width,height:integer;PixFmt:ImagePixelFormat;
     flags:integer;name:texnamestr):TTexture; virtual; abstract;
  // Change size of texture if it supports it (render target etc)
  procedure ResizeTexture(var img:TTexture;newWidth,newHeight:integer); virtual; abstract;
  function Clone(img:TTexture):TTexture; virtual; abstract;
  // Освободить изображение
  procedure FreeImage(var image:TTexture); overload; virtual; abstract;
  // Сделать текстуру доступной для использования (может использоваться для менеджмента текстур)
  // необходимо вызывать всякий раз перед переключением на текстуру (обычно это делает код рисовалки)
  procedure MakeOnline(img:TTexture;stage:integer=0); virtual; abstract;
  // Проверить возможность выделения текстуры в заданном формате с заданными флагами
  // Возвращает true если такую текстуру принципиально можно создать
  function QueryParams(width,height:integer;format:ImagePixelFormat;aiFlags:integer):boolean; virtual; abstract;
  // Формирует строки статуса
  function GetStatus(line:byte):string; virtual; abstract;
  // Создает дамп использования и распределения видеопамяти
  procedure Dump(st:string=''); virtual; abstract;
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

 // Basic vertex format for drawing textured primitives
 PScrPoint=^TScrPoint;
 TScrPoint=packed record
  x,y,z:single;
  {$IFDEF DIRECTX}
  rhw:single;
  {$ENDIF}
  diffuse:cardinal;
  {$IFDEF DIRECTX}
  specular:cardinal;
  {$ENDIF}
  u,v:single;
 end;

 // Basic vertex format for drawing non-textured primitives
 TScrPointNoTex=record
  x,y,z:single;
  {$IFDEF DIRECTX}
  rhw:single;
  {$ENDIF}
  diffuse:cardinal;
  {$IFDEF DIRECTX}
  specular:cardinal;
  {$ENDIF}
 end;

 // Vertex format for drawing multitextured primitives
 PScrPoint3=^TScrPoint3;
 TScrPoint3=record
  x,y,z,rhw:single;
  diffuse,specular:cardinal;
  u,v:single;
  u2,v2:single;
  u3,v3:single;
 end;

 // vertex and index arrays
 TVertices=array of TScrPoint;
 TIndices=array of word;
 TTexCoords=array of TPoint2s;

 TMesh=class
  vertices:TVertices;
  indices:TIndices;
 end;

 PMultiTexLayer=^TMultiTexLayer;
 TMultiTexLayer=record
  texture:TTexture;
  matrix:TMatrix32s;  // матрица трансформации текстурных к-т
  next:PMultiTexLayer;
 end;

 TCullMode=(cullNone, // Display both sides
   cullCW,    // Omit CW faces. This engine uses CW faces for 2D drawing
   cullCCW);  // Omit CCW faces. in OpenGL CCW-faces are considered front by default

 T3DMatrix=TMatrix4;

 // Drawing interface
 TPainter=class
  TextColorX2:boolean; // true: white=FF808080 range, false: white=FFFFFFFF
  textEffects:array[1..4] of TTextEffectLayer;
  textMetrics:array of TRect; // results of text measurement (if requested)
  zPlane:double; // default Z value for all primitives
  viewMatrix:T3DMatrix; // текущая матрица камеры
  objMatrix:T3DMatrix; // текущая матрица трансформации объекта (ибо OGL не хранит отдельно матрицы объекта и камеры)
  projMatrix:T3DMatrix; // текущая матрица проекции

  // Начать рисование (использовать указанную текстуру либо основной буфер если она не указана)
  procedure BeginPaint(target:TTexture); virtual; abstract;
  // Завершить рисование
  procedure EndPaint; virtual; abstract;

  // Установка RenderTarget'а (потомки класса могут иметь дополнительные методы,
  // характерные для конкретного 3D API, например D3D)
  procedure ResetTarget; virtual; abstract; // Установить target в backbuffer
  procedure SetTargetToTexture(tex:TTexture); virtual; abstract; // Установить target в указанную текстуру
  procedure PushRenderTarget; virtual; abstract; // запомнить target в стеке
  procedure PopRenderTarget; virtual; abstract; // восстановить target тиз стека
  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); virtual; abstract;

  // Clipping --------------------------
  procedure NoClipping; virtual; abstract; // отсечение по границе экрана
  function GetClipping:TRect; virtual; abstract;
  procedure SetClipping(r:TRect); virtual; abstract; // область отсечения (в пределах текущей)
  procedure ResetClipping; virtual; abstract; // Отменить предыдущее отсечение
  procedure OverrideClipping; virtual; abstract; // то же что setClipping по границам экрана без учета текущего отсечения

  // 3D / Camera  / Projection
  // -------------------------
  // Switch to default 2D view (use screen coordinates, no T&L)
  procedure SetDefaultView; virtual; abstract;
  // Switch to 3D view - set perspective projection (in camera space: camera pos = 0,0,0, Z-forward, X-right, Y-down)
  // zMin, zMax - near and far Z plane
  // xMin,xMax - x coordinate range on the zScreen Z plane
  // yMin,yMax - y coordinate range on the zScreen Z plane
  // Т.е. точки (x,y,zScreen), где xMin <= x <= xMax, yMin <= y <= yMax - покрывают всю область вывода и только её
  procedure SetPerspective(xMin,xMax,yMin,yMax,zScreen,zMin,zMax:double); virtual; abstract;
  // Set orthographic projection matrix
  // For example: scale=3 means that 1 unit in the world space is mapped to 3 pixels (in backbuffer)
  procedure SetOrthographic(scale,zMin,zMax:double); virtual; abstract;
  // Set view transformation matrix (camera position)
  // View matrix is (R - right, D - down, F - forward, O - origin):
  // Rx Ry Rz
  // Dx Dy Dz
  // Fx Fy Fz
  // Ox Oy Oz
  procedure Set3DView(view:T3DMatrix); virtual; abstract;
  // Alternate way to set camera position and orientation (origin - camera center, target - point to look, up - any point, so plane OTU is vertical), turnCW - camera turn angle (along view axis, CW direction)
  procedure SetupCamera(origin,target,up:TPoint3;turnCW:double=0); virtual; abstract;
  // Set Model (model to world) transformation matrix (MUST BE USED AFTER setting the view/camera)
  procedure Set3DTransform(mat:T3DMatrix); virtual; abstract;
  // Get Model-View-Projection matrix (i.e. transformation from model space to screen space)
  function GetMVPMatrix:T3DMatrix; virtual; abstract;

  // Set cull mode
  procedure SetCullMode(mode:TCullMode); virtual; abstract;

  procedure SetMode(blend:TBlendingMode); virtual; abstract; // Режим альфа-блендинга
  procedure SetTexMode(stage:byte;colorMode:TTexBlendingMode=tblModulate2X;alphaMode:TTexBlendingMode=tblModulate;
     filter:TTexFilter=fltUndefined;intFactor:single=0.0); virtual; abstract; //  Настройка стадий (операций) текстурирования
  procedure UseCustomShader; virtual; abstract; // указывает, что клиентский код включил собственный шейдер => движок не должен его переключать
  procedure ResetTexMode; virtual; abstract; // возврат к стандартному режиму текстурирования (втч после использования своего шейдера)

  procedure SetMask(rgb:boolean;alpha:boolean); virtual; abstract;
  procedure ResetMask; virtual; abstract; // вернуть маску на ту, которая была до предыдущего SetMask

  procedure Restore; virtual; abstract; // Восстановить состояние акселератора (если оно было нарушено внешним кодом)
  procedure RestoreClipping; virtual; abstract; // Установить параметры отсечения по текущему viewport'у

  // Upload texture to the Video RAM and make it active for given stage (don't call manually if you don't really need)
  procedure UseTexture(tex:TTexture;stage:integer=0); virtual; abstract;

  // Basic primitives -----------------
  procedure DrawLine(x1,y1,x2,y2:single;color:cardinal); virtual; abstract;
  procedure DrawPolyline(points:PPoint2;cnt:integer;color:cardinal;closed:boolean=false); virtual; abstract;
  procedure DrawPolygon(points:PPoint2;cnt:integer;color:cardinal); virtual; abstract;
  procedure Rect(x1,y1,x2,y2:integer;color:cardinal); virtual; abstract;
  procedure RRect(x1,y1,x2,y2:integer;color:cardinal;r:integer=2); virtual; abstract;
  procedure FillRect(x1,y1,x2,y2:integer;color:cardinal); virtual; abstract;
  procedure ShadedRect(x1,y1,x2,y2,depth:integer;light,dark:cardinal); virtual; abstract;
  procedure FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal); virtual; abstract;
  procedure FillGradrect(x1,y1,x2,y2:integer;color1,color2:cardinal;vertical:boolean); virtual; abstract;

  // Textured primitives ---------------
  // Указываются к-ты тех пикселей, которые будут зарисованы (без границы)
  procedure DrawImage(x_,y_:integer;tex:TTexture;color:cardinal=$FF808080); overload; virtual; abstract;
  procedure DrawImage(x,y,scale:single;tex:TTexture;color:cardinal=$FF808080;pivotX:single=0;pivotY:single=0); overload;
  procedure DrawImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080); virtual; abstract;
  procedure DrawCentered(x,y:integer;tex:TTexture;color:cardinal=$FF808080); overload; virtual; abstract;
  procedure DrawCentered(x,y,scale:single;tex:TTexture;color:cardinal=$FF808080); overload;
  procedure DrawImagePart(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect); virtual; abstract;
  // Рисовать часть картинки с поворотом ang раз на 90 град по часовой стрелке
  procedure DrawImagePart90(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect;ang:integer); virtual; abstract;
  procedure TexturedRect(x1,y1,x2,y2:integer;texture:TTexture;u1,v1,u2,v2,u3,v3:single;color:cardinal); virtual; abstract;
  procedure DrawScaled(x1,y1,x2,y2:single;image:TTexture;color:cardinal=$FF808080); virtual; abstract;
  procedure DrawRotScaled(x,y,scaleX,scaleY,angle:double;image:TTexture;color:cardinal=$FF808080;pivotX:single=0.5;pivotY:single=0.5); virtual; abstract; // x,y - центр

  // Returns scale
  function DrawImageCover(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single; virtual; abstract;
  function DrawImageInside(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single; virtual; abstract;

  // Meshes ------------------
  // Draw textured tri-mesh (tex=nil -> colored mode)
  procedure DrawTrgListTex(pnts:PScrPoint;trgcount:integer;tex:TTexture); virtual; abstract;
  // Draw indexed tri-mesh (tex=nil -> colored mode)
  procedure DrawIndexedMesh(vertices:PScrPoint;indices:PWord;trgCount,vrtCount:integer;tex:TTexture); virtual; abstract;

  // Multitexturing functions ------------------
  // Режим мультитекстурирования должен быть предварительно настроен с помощью SetTexMode / SetTexInterpolationMode
  // а затем сброшен с помощью SetTexMode(1,tblDisable)
  // Рисует два изображения, наложенных друг на друга, за один проход (если размер отличается, будет видна лишь общая часть)
  procedure DrawDouble(x,y:integer;image1,image2:TTexture;color:cardinal=$FF808080); virtual; abstract;
  // Рисует два изображения (каждое - с индвидуальным масштабом), повёрнутых на одинаковый угол. ЯЕсли итоговый размер отличается - будет видна лишь общая часть)
  procedure DrawDoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
      image1,image2:TTexture;color:cardinal=$FF808080); virtual; abstract;
  // Заполнение прямоугольника несколькими текстурами (из списка)
  procedure DrawMultiTex(x1,y1,x2,y2:integer;layers:PMultiTexLayer;color:cardinal=$FF808080); virtual; abstract;

  // Deprecated Text functions (Legacy Text Protocol 2003) ---------------------
  function PrepareFont(fontNum:integer;border:integer=0):THandle; virtual; abstract;  // Подготовить шрифт (из DirectText) к использованию
  procedure SetFontScale(font:THandle;scale:single); virtual; abstract;
  procedure SaveToFile(font:THandle;name:string); virtual; abstract;  // Сохранить шрифт
  function LoadFontFromFile(name:string):THandle; virtual; abstract;  // Загрузить из файла
  procedure FreeFont(font:THandle); virtual; abstract;   // Удалить подготовленный шрифт
  procedure SetFont(font:THandle); virtual; abstract;  // Выбрать шрифт
  procedure SetTextOverlay(tex:TTexture;scale:single=1.0;relative:boolean=true); virtual; abstract;
  function GetTextWidth(st:string;font:integer=0):integer; virtual; abstract;  // Определить ширину текста в пикселях (spacing=0)
  function GetFontHeight:byte; virtual; abstract;  // Определить высоту шрифта в пикселях
  procedure WriteSimple(x,y:integer;color:cardinal;st:string;align:TTextAlignment=taLeft;spacing:integer=0); virtual; abstract;  // Простейший вывод текста
  // Навороченный вывод текста с применением эффектов
  procedure WriteEx(x,y:integer;color:cardinal;st:string;align:TTextAlignment=taLeft;spacing:integer=0); virtual; abstract;

  // Recent Text functions (Text Protocol 2011) ---------------------------
  // font handle structure: xxxxxxxx ssssssss yyyyyyyy 00ffffff (f - font object index, s - scale, x - realtime effects, y - renderable effects and styles)
  function LoadFont(fname:string;asName:string=''):string; overload; virtual; abstract; // возвращает имя шрифта
  function LoadFont(font:array of byte;asName:string=''):string; overload; virtual; abstract; // возвращает имя шрифта
  function GetFont(name:string;size:single=0.0;flags:integer=0;effects:byte=0):cardinal; virtual; abstract; // возвращает хэндл шрифта
  function TextWidth(font:cardinal;st:AnsiString):integer; virtual; abstract; // text width in pixels
  function TextWidthW(font:cardinal;st:WideString):integer; virtual; abstract; // text width in pixels
  function FontHeight(font:cardinal):integer; virtual; abstract; // Height of capital letters (like 'A'..'Z','0'..'9') in pixels
  procedure TextOut(font:cardinal;x,y:integer;color:cardinal;st:AnsiString;align:TTextAlignment=taLeft;
     options:integer=0;targetWidth:integer=0;query:cardinal=0); virtual; abstract;
  procedure TextOutW(font:cardinal;x,y:integer;color:cardinal;st:WideString;align:TTextAlignment=taLeft;
     options:integer=0;targetWidth:integer=0;query:cardinal=0); virtual; abstract;
  procedure SetFontOption(handle:cardinal;option:cardinal;value:single); virtual; abstract;
  procedure MatchFont(oldfont,newfont:cardinal;addY:integer=0); virtual; abstract; // какой новый шрифт использовать вместо старого

  // Text drawing cache / misc
  procedure BeginTextBlock; virtual; abstract; // включает кэширование вывода текста
  procedure EndTextBlock;  virtual; abstract; // выводит кэш и выключает кэширование
  procedure SetTextTarget(buf:pointer;pitch:integer); virtual; abstract; // устанавливает буфер для отрисовки текста, отсечения нет - весь текст должен помещаться в буфере!

  // Particles ------------------------------------------
  procedure DrawParticles(x,y:integer;data:PParticle;count:integer;tex:TTexture;size:integer;zDist:single=0); virtual; abstract;
  procedure DrawBand(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect); virtual; abstract;

 protected
  // Максимальная область рендертаргета, доступная для отрисовки, т.е. это значение, которое принимает ClipRect при сбросе отсечения
  // Используется при установке вьюпорта (при смене рендертаргета)
  screenRect:TRect;  // maximal clipping area (0,0 - width,height) in virtual pixels (for current RT)
 // Устанавливается при установке отсечения (путём пересечения с текущей областью отсечения) с учётом ofsX/Y
  clipRect:TRect;    // currently requested clipping area (in virtual pixels), might be different from actual clipping area

 end;

 TGameObj=class
  // Глобально доступные переменные
  renderWidth,renderHeight:integer; // Size of render area in virtual pixels (primitive of this size fills the whole renderRect)
  displayRect:TRect;     // область вывода в окне (после инициализации - все окно) в реальных экранных пикселях
  screenWidth,screenHeight:integer; // реальный размер всего экрана
  windowWidth,windowHeight:integer; // размеры клиентской части окна в реальных пикселях
  screenDPI:integer;    // According to system settings
  active:boolean;       // Окно активно, цикл перерисовки выполняется
  paused:boolean;       // Режим паузы (изначально сброшен, движком не изменяется и не используется)
  terminated:boolean;   // Работа цикла завершена, можно начинать деинициализацию и выходить
  changed:boolean;      // Нужно ли перерисовывать экран (аналог результата onFrame, только можно менять в разных местах)
  frameNum:integer;     // Номер кадра
  frameStartTime:int64; // MyTickCount в начале кадра

  keyState:array[0..255] of byte; // 0-й бит - клавиша нажата, 1-й - была нажата в пред. раз
  shiftstate:byte; // состояние клавиш сдвига (1-shift, 2-ctrl, 4-alt, 8-win)
  mouseX,mouseY:integer; // положение мыши внутри окна/экрана
  oldMouseX,oldMouseY:integer; // предыдущее положение мыши (не на предыдущем кадре, а вообще!)
  mouseMoved:int64; // Момент времени, когда положение мыши изменилось
  mouseButtons:byte;     // Флаги "нажатости" кнопок мыши (0-левая, 1-правая, 2-средняя)
  oldMouseButtons:byte;  // предыдущее (отличающееся) значение mouseButtons
  textLink:cardinal; // Вычисленный на предыдущем кадре номер ссылки под мышью записывается здесь (сам по себе он не вычисляется, для этого надо запускать отрисовку текста особым образом)
                     // TODO: плохо, что этот параметр глобальный, надо сделать его свойством сцен либо элементов UI, чтобы можно было проверять объект под мышью с учётом наложений
  textLinkRect:TRect; // область ссылки, по номеру textLink

  // Key game objects
  painter:TPainter;
  texman:TTextureMan;
 end;

 // Display target
 TDisplayMode=(dmNone,             // not specified
               dmSwitchResolution, // Fullscreen: switch to desired display mode (change screen resolution)
               dmFullScreen,       // Use current resolution with fullscreen window
               dmFixedWindow,      // Use fixed-size window
               dmWindow);          // Use resizeable window

 // How the default render target should appear in the output area
 TDisplayFitMode=(dfmCenter,           // render target is centered in the output window rect (1:1) (DisplayScaleMode is ignored)
                  dfmStretch,          // render target is stretched to fill the whole output window rect
                  dfmKeepAspectRatio); // render target is stretched to fill the output window rect while keeping it's aspect ratio

 // How rendering is processed if back buffer size doesn't match the output rect
 TDisplayScaleMode=(dsmDontScale,   // Ignore the back buffer size and set it to match the output rect size
                    dsmStretch,     // Render to the back buffer size and then stretch to the output rect
                    dsmScale);      // Render to the output rect size using scale transformation matrix

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

  // Внутренние величины
  accumTime:integer; // накопленное время (в мс)

  constructor Create(fullscreen:boolean=true);
  destructor Destroy; override;

  // Вызывается из конструктора, можно переопределить для инициализации без влезания в конструктор
  // !!! Call this manually from constructor!
  procedure onCreate; virtual;

  // Для изменения статуса использовать только это!
  procedure SetStatus(st:TSceneStatus); virtual;

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
  // Прочитать клавишу из буфера (младший байт - код символа, старший - сканкод клавиши)
  // Старшее слово - unicode код символа
  function ReadKey:cardinal; virtual;
  //Записать клавишу в буфер
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

 TVarTypeAlignment=class(TVarType)
  class procedure SetValue(variable:pointer;v:string); override;
  class function GetValue(variable:pointer):string; override;
 end;


implementation
 uses SysUtils,MyServis;

 constructor TTexture.CreateClone(src:TTexture);
  begin
   PixelFormat:=src.PixelFormat;
   left:=src.left;
   top:=src.top;
   width:=src.width;
   height:=src.height;
   u1:=src.u1; v1:=src.v1;
   u2:=src.u2; v2:=src.v2;
   stepU:=src.stepU; stepV:=src.stepV;
   mipmaps:=src.mipmaps;
   caps:=src.caps or tfCloned;
   name:=src.name;
   if src.parent<>nil then
    parent:=src.parent
   else
    parent:=src;
   inc(parent.refCounter);
  end;

function TTexture.IsLocked: boolean;
 begin
  result:=locked>0;
 end;

function TTexture.Clone:TTexture;
 begin
  result:=TTexture.CreateClone(self);
 end;


function TTexture.ClonePart(part:TRect): TTexture;
 begin
  result:=Clone;
  result.left:=left+part.Left;
  result.top:=top+part.Top;
  result.width:=part.Width;
  result.height:=part.Height;
  result.u1:=u1+part.left*stepU*2;
  result.u2:=u1+part.right*stepU*2;
  result.v1:=v1+part.top*stepV*2;
  result.v2:=v1+part.bottom*stepV*2;
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

{ TVarTypeAlignment }

 function StrToAlign(s:string):TTextAlignment;
  begin
   result:=taCenter;
   s:=uppercase(s);
   if s='LEFT' then result:=taLeft else
   if s='RIGHT' then result:=taRight else
   if s='CENTER' then result:=taCenter else
   if s='JUSTIFY' then result:=taJustify;
  end;

class function TVarTypeAlignment.GetValue(variable: pointer): string;
 var
  a:TTextAlignment;
 begin
  a:=TTextAlignment(variable^);
  case a of
   taLeft:result:='Left';
   taRight:result:='Right';
   taCenter:result:='Center';
   taJustify:result:='Justify';
  end;
 end;

class procedure TVarTypeAlignment.SetValue(variable: pointer; v: string);
 var
  a:^TTextAlignment;
 begin
  a:=variable;
  a^:=StrToAlign(v);
 end;

{ TPainter }

procedure TPainter.DrawCentered(x, y, scale: single; tex: TTexture;
  color: cardinal);
 begin
  DrawRotScaled(x,y,scale,scale,0,tex,color);
 end;

procedure TPainter.DrawImage(x, y, scale: single; tex: TTexture;
  color: cardinal; pivotX, pivotY: single);
 begin
  if scale=1.0 then
   DrawImage(round(x-tex.width*pivotX),round(y-tex.height*pivotY),tex,color)
  else
   DrawRotScaled(x,y,scale,scale,0,tex,color,pivotX,pivotY);
 end;

end.
