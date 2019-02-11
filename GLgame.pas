// OpenGL version of the Game object
//
// Copyright (C) 2011 Apus Software (www.games4win.com, www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by)
unit GLgame;
interface
 uses EngineAPI,Images,engineTools,classes,myservis,BasicGame;

type
 TGLGame=class(TBasicGame)
  constructor Create(useShaders:boolean=false);
 protected
  dRT:TTexture; // default RT
  useShaders:boolean; // use shaders (programmable pipeline)

  procedure ApplySettings; override;

  // Эти методы используются при смене режима работы (вызов только из главного потока)
  procedure InitGraph; override; // Инициализация графической части (переключить режим и все такое прочее)
  procedure DoneGraph; override; // Финализация графической части
  procedure SetupRenderArea; override;

  procedure PresentFrame; override;
  procedure ChoosePixelFormats(needMem:integer); override;
  procedure InitObjects; override;
  procedure onEngineEvent(event:string;tag:cardinal); override;
  {$IFDEF MSWINDOWS}
  procedure CaptureFrame; override;
  procedure ReleaseFrameData(obj:TRAWImage); override;
  {$ENDIF}
 public
  glVersion,glRenderer:string; // версия OpenGL и название видеокарты
  glVersionNum:single; // like 3.1 or 1.4
  globalTintColor:cardinal; // global color used to display framebuffer (multiply2X)
  function GetStatus(n:integer):string; override;
 end;

implementation
 uses types,SysUtils,cmdproc{$IFDEF DELPHI},graphics{$ENDIF},
     {$IFDEF MSWINDOWS}windows,{$ENDIF}
     {$IFNDEF GLES}dglOpenGL,{$ENDIF}
     GlImages,EventMan,ImageMan,UIClasses,UIScene,gfxformats,
     Console,PainterGL,PainterGL2, BasicPainter;

{ TGlGame }

procedure TGlGame.ApplySettings;
var
 i:integer;
begin
 if running then begin // смена параметров во время работы
  Signal('Debug\Settings Changing');
  ConfigureMainWindow;
  if painter<>nil then (painter as TGLPainter).Reset;
  SetupRenderArea;
  for i:=low(scenes) to high(scenes) do
   scenes[i].ModeChanged;
 end;
end;

function EventHandler(event:EventStr;tag:integer):boolean;
begin
 result:=true;
 event:=UpperCase(copy(event,8,500));
 if event='SETSWAPINTERVAL' then begin
  if WGL_EXT_swap_control then begin
   wglSwapIntervalEXT(tag);
   PutMsg('Swap interval set to '+inttostr(tag));
  end else
   PutMsg('Not supported');
 end;
end;

// Эта процедура пытается установить запрошенный видеорежим
// В случае ошибки она просто бросит исключение
procedure TGLGame.InitGraph;
var
 DC:HDC;
 RC:HGLRC;
 PFD:TPixelFormatDescriptor;
 pf:integer;
 v:integer;
begin
 inherited;
 globalTintColor:=$FF808080;
 ConfigureMainWindow;
 SetEventHandler('GLGAME',EventHandler);

 // OpenGL activation
 LogMessage('Init OpenGL');
 InitOpenGL;
 LogMessage('Prepare GL context');
 fillchar(pfd,sizeof(PFD),0);
 with PFD do begin
  nSize:=sizeof(PFD);
  nVersion:=1;
  dwFlags:=PFD_SUPPORT_OPENGL+PFD_DRAW_TO_WINDOW+PFD_DOUBLEBUFFER;
  iPixelType:=PFD_TYPE_RGBA;
  cDepthBits:=16;
//  cDepthBits:=params.zbuffer;
 end;
 DC:=getDC(window);
 LogMessage('ChoosePixelFormat');
 pf:=ChoosePixelFormat(DC,@PFD);
 LogMessage('Pixel format: '+inttostr(pf));
 if not SetPixelFormat(DC,pf,@PFD) then
  LogMessage('Failed to set pixel format!');
 LogMessage('Create GL context');
 RC:=wglCreateContext(DC);
 if RC=0 then
  raise EError.Create('Can''t create RC!');
 LogMessage('Activate GL context');
 ActivateRenderingContext(DC,RC); // Здесь происходит загрузка основных функций OpenGL
 glVersion:=glGetString(GL_VERSION);
 glRenderer:=glGetString(GL_RENDERER);
 ForceLogMessage('OpenGL version: '+glVersion);
 ForceLogMessage('OpenGL vendor: '+PAnsiChar(glGetString(GL_VENDOR)));
 ForceLogMessage('OpenGL renderer: '+glRenderer);
 ForceLogMessage('OpenGL extensions: '+#13#10+StringReplace(PAnsiChar(glGetString(GL_EXTENSIONS)),' ',#13#10,[rfReplaceAll]));
// ForceLogMessage('GL Functions: '#13#10+loadedOpenGLFunctions);
 if not GL_VERSION_1_4 then
  raise Exception.Create('OpenGL 1.4 or higher required!'#13#10'Please update your video drivers.');

 glVersionNum:=1.4;
 if GL_VERSION_1_5 then glVersionNum:=1.5;
 if GL_VERSION_2_0 then glVersionNum:=2.0;
 if GL_VERSION_2_1 then glVersionNum:=2.1;
 if GL_VERSION_3_0 then glVersionNum:=3.0;
 if GL_VERSION_3_1 then glVersionNum:=3.1;
 if GL_VERSION_3_2 then glVersionNum:=3.2;
 if GL_VERSION_3_3 then glVersionNum:=3.3;
 if GL_VERSION_4_0 then glVersionNum:=4.0;
 if GL_VERSION_4_1 then glVersionNum:=4.1;
 if GL_VERSION_4_2 then glVersionNum:=4.2;
 if GL_VERSION_4_3 then glVersionNum:=4.3;

 if WGL_EXT_swap_control then
  wglSwapIntervalEXT(params.VSync);

 AfterInitGraph;
end;

procedure TGLGame.InitObjects;
var
 fl:boolean;
begin
 try
  LogMessage('Texman');
  texman:=TGLTextureMan.Create(1024*BestVidMem);
  LogMessage('Painter');
  if useShaders then
   painter:=TGLPainter2.Create(texman)
  else
   painter:=TGLPainter.Create(texman);

  LogMessage('Default RT');
  fl:=HasParam('-nodrt');
  if fl then LogMessage('Modern rendering model disabled by -noDRT switsh');
  if not fl and GL_VERSION_2_0 and (texman.maxRTTextureSize>=params.width) then begin
   LogMessage('Switching to the modern rendering model');
   dRT:=texman.AllocImage(params.width,params.height,pfRTHigh,aiRenderTarget,'DefaultRT');
   (painter as TGLPainter).SetDefaultRenderTarget(dRT);
  end;
 except
  on e:exception do begin
   ForceLogMessage('Error in GLG:IO '+ExceptionMsg(e));
   ErrorMessage('Game engine failure (GLG:IO): '+ExceptionMsg(e));
   Halt;
  end;
 end;
end;

procedure TGLGame.onEngineEvent(event: string; tag: cardinal);
begin
 inherited;
 if event='SETGLOBALTINTCOLOR' then globalTintColor:=tag;
end;

procedure TGLGame.PresentFrame;
var
 DC:HDC;
begin
  with painter as TGLPainter do begin
   if dRT<>nil then begin
    // Была отрисовка в текстуру - теперь нужно отрисовать её в RenderRect
    SetDefaultRenderArea(0,0,windowWidth,windowHeight,windowWidth,windowHeight);
    ResetTarget;
    BeginPaint(nil);
    try
    // Если есть неиспользуемые полосы - очистить их (но не каждый кадр, чтобы не тормозило)
    if not types.EqualRect(displayRect,types.Rect(0,0,windowWidth,windowHeight)) and
       ((frameNum mod 5=0) or (frameNum<3)) then painter.Clear($FF000000);

    with displayRect do begin
     TexturedRect(Left,Top,right-1,bottom-1,DRT,0,1,1,1,1,0,globalTintColor);
    end;
    finally
     EndPaint;
    end;
    SetDefaultRenderTarget(dRT);
   end;
  end;
   FLog('Present');
   StartMeasure(1);
   DC:=getDC(window);
   if not SwapBuffers(DC) then
    LogMessage('Swap error: '+IntToStr(GetLastError));
   ReleaseDC(window,DC);

   inc(FrameNum);
end;

procedure TGLGame.SetupRenderArea;
begin
  inherited;
  if painter<>nil then begin
   if dRT=nil then begin
    // Rendering directly to the framebuffer
    TGLPainter(painter).SetDefaultRenderArea(displayRect.Left,windowHeight-displayRect.Bottom,
      displayRect.right-displayRect.Left,displayRect.bottom-displayRect.top,
      settings.width,settings.height);
   end else begin
    // Rendering to a framebuffer texture
    with params.mode do
     if (displayFitMode in [dfmStretch,dfmKeepAspectRatio]) and
        (displayScaleMode in [dsmDontScale,dsmScale]) and
        ((dRT.width<>displayRect.Width) or (dRT.height<>displayRect.Height)) then begin
      LogMessage('Resizing framebuffer');
      texman.ResizeTexture(dRT,displayRect.Width,displayRect.Height);
     end;
   end;
  end;
end;

procedure TGLGame.ChoosePixelFormats(needMem:integer);
begin
 pfTrueColor:=ipfXRGB;
 pfTrueColorAlpha:=ipfARGB;
 pfTrueColorLow:=ipfXRGB;
 pfTrueColorAlphaLow:=ipfARGB;

 pfRTLow:=ipfXRGB;
 pfRTNorm:=ipfXRGB;
 pfRTHigh:=ipfXRGB;
 pfRTAlphaLow:=ipfARGB;
 pfRTAlphaNorm:=ipfARGB;
 pfRTAlphaHigh:=ipfARGB;
{ if not GL_VERSION_2_1 then begin
  pfTrueColorLow:=ipf565;
 end;}
end;

{$IFDEF MSWINDOWS}
procedure TGLGame.CaptureFrame;
var
 w,h:integer;
 ipf:ImagePixelFormat;
 img:TRAWimage;
 r:TRect;
 buf:PByte;
begin
//  GetClientRect(window,r);
  r:=displayRect;
  w:=r.Right-r.Left;
  h:=r.Bottom-r.top;
  GetMem(buf,w*h*4);

  glReadPixels(0,0,w,h,GL_BGRA,GL_UNSIGNED_BYTE,buf);

  img:=TRAWImage.Create;
  img.width:=w;
  img.height:=h;
  img.PixelFormat:=ipfXRGB;
  img.paletteFormat:=palNone;
  img.tag:=cardinal(buf);
  inc(buf,w*4*(h-1));
  img.data:=buf;
  img.pitch:=-w*4;
  screenshotDataRAW:=img;
  inherited;
end;

constructor TGLGame.Create(useShaders: boolean);
begin
 inherited Create(0);
 self.useShaders:=useShaders;
end;

procedure TGLGame.ReleaseFrameData(obj:TRAWImage);
var
 p:pointer;
begin
 if obj.tag<>0 then p:=pointer(obj.tag);
 obj.Free;
 FreeMem(p);
end;
{$ENDIF}

procedure TGLGame.DoneGraph;
begin
  inherited;
end;

function TGLGame.GetStatus(n: integer): string;
begin
 result:='';
end;

end.
