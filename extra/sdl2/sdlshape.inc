// from "sdl_shape.h"

{**  SDL_shape.h
 *
 * Header file for the shaped window API.
 *}
const
  SDL_NONSHAPEABLE_WINDOW    = -1;
  SDL_INVALID_SHAPE_ARGUMENT = -2;
  SDL_WINDOW_LACKS_SHAPE     = -3;

{**
 * Create a window that can be shaped with the specified position, dimensions,
 * and flags.
 *
 * \param title The title of the window, in UTF-8 encoding.
 * \param x The x position of the window, SDL_WINDOWPOS_CENTERED,
 *          or SDL_WINDOWPOS_UNDEFINED.
 * \param y The y position of the window, SDL_WINDOWPOS_CENTERED,
 *          or SDL_WINDOWPOS_UNDEFINED.
 * \param w The width of the window.
 * \param h The height of the window.
 * \param flags The flags for the window, a mask of SDL_WINDOW_BORDERLESS with
 *              any of the following: SDL_WINDOW_OPENGL,
 *              SDL_WINDOW_INPUT_GRABBED, SDL_WINDOW_HIDDEN,
 *              SDL_WINDOW_RESIZABLE, SDL_WINDOW_MAXIMIZED,
 *              SDL_WINDOW_MINIMIZED.
 *              SDL_WINDOW_BORDERLESS is always set,
 *              and SDL_WINDOW_FULLSCREEN is always unset.
 * \return the window created, or NIL if window creation failed.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_DestroyWindow
 *}
function SDL_CreateShapedWindow(title: PAnsiChar; x: cuint; y: cuint; w: cuint; h: cuint; flags: cuint32): PSDL_Window; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateShapedWindow' {$ENDIF} {$ENDIF};

{**
 * Return whether the given window is a shaped window.
 *
 * \param window The window to query for being shaped.
 * \return SDL_TRUE if the window is a window that can be shaped,
 *         SDL_FALSE if the window is unshaped or NIL.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateShapedWindow
 *}
function SDL_IsShapedWindow(window: PSDL_Window): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_IsShapedWindow' {$ENDIF} {$ENDIF};


type
  {** \brief An enum denoting the specific type of contents present in an SDL_WindowShapeParams union. *}
  PPWindowShapeMode = ^PWindowShapeMode;
  PWindowShapeMode = ^TWindowShapeMode;
  TWindowShapeMode = type Integer;

const
  {** \brief The default mode, a binarized alpha cutoff of 1. *}
  ShapeModeDefault               = TWindowShapeMode(0);
  {** \brief A binarized alpha cutoff with a given integer value. *}
  ShapeModeBinarizeAlpha         = TWindowShapeMode(1);
  {** \brief A binarized alpha cutoff with a given integer value, but with the opposite comparison. *}
  ShapeModeReverseBinarizeAlpha  = TWindowShapeMode(2);
  {** \brief A color key is applied. *}
  ShapeModeColorKey              = TWindowShapeMode(3);

function SDL_SHAPEMODEALPHA(mode: TWindowShapeMode): Boolean;

type
  {** A union containing parameters for shaped windows. *}
  PPSDL_WindowShapeParams = ^PSDL_WindowShapeParams;
  PSDL_WindowShapeParams = ^TSDL_WindowShapeParams;
  TSDL_WindowShapeParams = record
    case cint of
      {** a cutoff alpha value for binarization of the window shape's alpha channel. *}
      0: (binarizationCutoff: cuint8;);
      1: (colorKey: TSDL_Color;);
  end;

  {** A struct that tags the SDL_WindowShapeParams union with an enum describing the type of its contents. *}
  PPSDL_WindowShapeMode = ^PSDL_WindowShapeMode;
  PSDL_WindowShapeMode = ^TSDL_WindowShapeMode;
  TSDL_WindowShapeMode = record
    {** The mode of these window-shape parameters. *}
    mode: TWindowShapeMode;
    {** Window-shape parameters. *}
    parameters: TSDL_WindowShapeParams;
  end;

{**
 * Set the shape and parameters of a shaped window.
 *
 * \param window The shaped window whose parameters should be set.
 * \param shape A surface encoding the desired shape for the window.
 * \param shape_mode The parameters to set for the shaped window.
 * \return 0 on success, SDL_INVALID_SHAPE_ARGUMENT on an invalid shape
 *         argument, or SDL_NONSHAPEABLE_WINDOW if the SDL_Window given does
 *         not reference a valid shaped window.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_WindowShapeMode
 * \sa SDL_GetShapedWindowMode
 *}
function SDL_SetWindowShape(window: PSDL_Window; shape: PSDL_Surface; shape_mode: PSDL_WindowShapeMode): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowShape' {$ENDIF} {$ENDIF};

{**
 * Get the shape parameters of a shaped window.
 *
 * \param window The shaped window whose parameters should be retrieved.
 * \param shape_mode An empty shape-mode structure to fill, or NIL to check
 *                   whether the window has a shape.
 * \return 0 if the window has a shape and, provided shape_mode was not NIL,
 *         shape_mode has been filled with the mode data,
 *         SDL_NONSHAPEABLE_WINDOW if the SDL_Window given is not a shaped
 *         window, or SDL_WINDOW_LACKS_SHAPE if the SDL_Window given is a
 *         shapeable window currently lacking a shape.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_WindowShapeMode
 * \sa SDL_SetWindowShape
 *}
function SDL_GetShapedWindowMode(window: PSDL_Window; shape_mode: PSDL_WindowShapeMode): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetShapedWindowMode' {$ENDIF} {$ENDIF};
