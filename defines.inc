// Shared compiler/platform defines for Apus.Engine.* units.
// Keep only cross-module defaults here; module-specific toggles stay in modules.

{$IFDEF FPC}
  // Unify syntax with Delphi for FPC builds.
  {$MODE DELPHI}
  // Engine asm snippets are written in Intel syntax.
  {$IF DEFINED(CPUX86) OR DEFINED(CPUX86_64)}
    {$ASMMODE intel}
  {$ENDIF}
{$ELSE}
  // Normalize compiler check to one symbol in code paths.
  {$DEFINE DELPHI}
{$ENDIF}

{$IFDEF CPUAARCH64}
  // Normalize FPC's AArch64 symbol to the Delphi-style ARM64 name.
  {$DEFINE CPUARM64}
{$ENDIF}

{$IF DEFINED(CPUX64) OR DEFINED(CPUARM64)}
  // Backward-compatible alias used by legacy code paths.
  {$DEFINE CPU64}
{$ENDIF}

{$IF Defined(MSWINDOWS) or Defined(LINUX) or Defined(DARWIN)}
  // Desktop OpenGL loader path (unit dglOpenGL + InitOpenGL/extension handling).
  // Not defined for mobile targets where GLES headers are used instead.
  {$DEFINE DGL}
{$ENDIF}

{$IFDEF IOS}
  // iOS uses OpenGL ES profile.
  {$DEFINE GLES}
  // iOS legacy renderer paths expect GLES 1.1 symbol.
  {$DEFINE GLES11}
  // Marks OpenGL-family backend (desktop GL or GLES).
  {$DEFINE OPENGL}
{$ENDIF}

{$IFDEF ANDROID}
  // Android uses OpenGL ES profile.
  {$DEFINE GLES}
  // Android renderer paths use GLES 2.0 shader pipeline.
  {$DEFINE GLES20}
  // Marks OpenGL-family backend (desktop GL or GLES).
  {$DEFINE OPENGL}
{$ENDIF}

// Keep deterministic floating-point behavior across compilers.
{$EXCESSPRECISION OFF}
