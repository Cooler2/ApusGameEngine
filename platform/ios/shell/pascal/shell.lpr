library shell;

uses
  ctypes,
  sdl2;

const
  GL_COLOR_BUFFER_BIT=$00004000;

type
  // minimal GLES entry points, fetched via SDL_GL_GetProcAddress so the shell
  // needs no GLES unit and no extra framework link.
  TglClearColor=procedure(r,g,b,a:cfloat); cdecl;
  TglClear=procedure(mask:cuint); cdecl;

var
  window:PSDL_Window;
  context:TSDL_GLContext;
  glClearColor:TglClearColor;
  glClear:TglClear;

procedure ShellFrame(unused:Pointer); cdecl;
var
  event:TSDL_Event;
  t:double;
begin
  while SDL_PollEvent(@event)<>0 do begin
    if event.type_=cuint32(SDL_QUITEV) then begin
      SDL_GL_DeleteContext(context);
      SDL_DestroyWindow(window);
      SDL_Quit;
      exit;
    end;
  end;
  // animate the clear color so a live frame loop is visually obvious: a smooth
  // hue sweep, each channel a sine offset by a third of the period.
  if assigned(glClearColor) and assigned(glClear) then begin
    t:=SDL_GetTicks/1000.0;
    glClearColor(0.5+0.5*sin(t),
                 0.5+0.5*sin(t+2.0944),
                 0.5+0.5*sin(t+4.1888),
                 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
  end;
  SDL_GL_SwapWindow(window);
end;

function ShellSDLMain(argc:cint; argv:PPAnsiChar):cint; cdecl;
begin
  if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS)<0 then exit(1);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,SDL_GL_CONTEXT_PROFILE_ES);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,0);
  SDL_GL_SetAttribute(SDL_GL_RED_SIZE,8);
  SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,8);
  SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,8);
  SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,8);
  window:=SDL_CreateWindow('Apus Engine Shell',SDL_WINDOWPOS_UNDEFINED,
    SDL_WINDOWPOS_UNDEFINED,0,0,SDL_WINDOW_OPENGL or SDL_WINDOW_SHOWN or
    SDL_WINDOW_ALLOW_HIGHDPI);
  if window=nil then begin
    SDL_Quit;
    exit(2);
  end;
  context:=SDL_GL_CreateContext(window);
  if context=nil then begin
    SDL_DestroyWindow(window);
    SDL_Quit;
    exit(3);
  end;
  glClearColor:=TglClearColor(SDL_GL_GetProcAddress('glClearColor'));
  glClear:=TglClear(SDL_GL_GetProcAddress('glClear'));
  if SDL_iPhoneSetAnimationCallback(window,1,@ShellFrame,nil)<0 then begin
    SDL_GL_DeleteContext(context);
    SDL_DestroyWindow(window);
    SDL_Quit;
    exit(4);
  end;
  result:=0;
end;

function ApusIOSMain(argc:cint; argv:PPAnsiChar):cint; cdecl;
begin
  result:=SDL_UIKitRunApp(argc,argv,@ShellSDLMain);
end;

exports
  ApusIOSMain name '_ApusIOSMain';

begin
end.
