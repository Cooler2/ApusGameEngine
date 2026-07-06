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

// ---------------------------------------------------------------------------
// GL define family - three symbols, two axes:
//   OPENGL - umbrella: a GL-family renderer is compiled in (desktop GL or GLES).
//            Gate "any GL" code with it. Set by the build (-dOPENGL); forced
//            below for mobile targets.
//   GLES   - dialect: OpenGL ES 3.0 baseline instead of desktop GL 3.3 core.
//            Implies OPENGL. Forced for iOS/Android; may also be set manually
//            (-dGLES) on desktop for bring-up/debugging (native ES context or
//            ANGLE). Bindings unit: extra/dglOpenGLES.pas.
//   GLDESKTOP - derived (= OPENGL minus GLES), never set manually: the
//            desktop loader unit dglOpenGL is in scope.
// RULE: unit dglOpenGL must only ever be referenced under {$IFDEF GLDESKTOP}.
// Gating it with OPENGL pulls the desktop loader into GLES builds, where its
// ReadOpenGLCore/ReadExtensions shadow the dglOpenGLES ones (implementation
// uses outranks interface uses) and GL entry points silently stay nil.
// ---------------------------------------------------------------------------

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
  // Not defined when GLES is active (macOS desktop stays GLDESKTOP; iOS/Android define GLES above).
  {$DEFINE GLDESKTOP}
{$ENDIF}

// Keep deterministic floating-point behavior across compilers.
{$EXCESSPRECISION OFF}
