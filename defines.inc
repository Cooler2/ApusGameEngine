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

{$IFDEF IOS}
  // iOS uses OpenGL ES 3.0 profile.
  {$DEFINE GLES}
  // Marks OpenGL-family backend (desktop GL or GLES).
  {$DEFINE OPENGL}
{$ENDIF}

{$IFDEF ANDROID}
  // Android uses OpenGL ES 3.0 profile.
  {$DEFINE GLES}
  // Marks OpenGL-family backend (desktop GL or GLES).
  {$DEFINE OPENGL}
{$ENDIF}

{$IF (Defined(MSWINDOWS) or Defined(LINUX) or Defined(DARWIN)) and not Defined(GLES)}
  // Desktop OpenGL loader path (unit dglOpenGL + InitOpenGL/extension handling).
  // Not defined when GLES is active (macOS desktop stays DGL; iOS/Android define GLES above).
  {$DEFINE DGL}
{$ENDIF}

// Keep deterministic floating-point behavior across compilers.
{$EXCESSPRECISION OFF}
