# iOS lifecycle shell

## Why a shell

The shell is a minimal iOS application that proves the boundary between Xcode,
SDL2 and Pascal before the full engine is brought in. Xcode owns the Mach-O
executable, the `.app` structure, signing, provisioning and embedding of
dynamic frameworks. The Pascal side is compiled by FPC into a static archive
and linked into the executable.

The shell is not an engine demo. Its job is to prove, in isolation, that the
following chain works on current Xcode and iOS:

```text
iOS -> native main() -> Pascal bootstrap -> SDL/UIKit lifecycle
    -> Pascal frame callback -> engine
```

## Why main.c stays

iOS launches a native Mach-O executable through its `main` symbol. Our Pascal
code is linked in as a library and SDL2 as a dynamic framework; neither is the
application executable itself, so the Xcode target must own the entry point.

Plain C is enough — no Objective-C required. `main.c` is a trivial C-ABI
adapter:

```c
extern int ApusIOSMain(int argc, char *argv[]);

int main(int argc, char *argv[])
{
  return ApusIOSMain(argc,argv);
}
```

`main.c` must contain no SDL window, no GLES, no event handling and no engine
logic. C exists only because Xcode/iOS expect a native entry point.

## Why SDL is called from Pascal

The engine already has the Pascal binding `extra/sdl2/sdl2.pas`, so once
`ApusIOSMain` is entered, all regular SDL calls are made from Pascal:

1. Call `SDL_UIKitRunApp`, passing a Pascal application-start callback.
2. In that callback create the SDL window and a GLES 3 context.
3. Register `SDL_iPhoneSetAnimationCallback`.
4. In the frame callback process SDL events and run an engine frame.
5. On shutdown release the SDL resources.

This avoids duplicating the SDL API in C; all platform logic stays in Pascal
and uses the same binding as the engine's other SDL platforms. The native
layer stays narrow and stable. The app needs no SDL C headers: the C code
makes no SDL calls.

## FPC static archive specifics

A regular Pascal program starts the RTL and unit `initialization` sections
automatically. FPC keeps the same mechanism for a library that ends up inside
an application as a static archive.

The library object contains a Mach-O constructor (`__mod_init_func`) pointing
at a `_FPC_LIBMAIN` call stub, and a destructor (`__mod_term_func`) pointing
at `fpc_lib_exit`. The current Apple linker converts the constructor into a
`__TEXT,__init_offsets` entry, so dyld initializes the FPC RTL and Pascal
units before the C `main` runs, and finalizes them on unload. Calling
`_FPC_LIBMAIN` or `fpc_lib_exit` manually is unnecessary and unsafe — it would
double the initialization or finalization. To keep the constructor object in
the final executable, the Pascal archive is linked with `-force_load`.

## Files and dependencies

- `app/main.c` — minimal native entry, a single call to `ApusIOSMain`.
- `pascal/shell.lpr` — the Pascal static library.
- `ApusShell.xcodeproj` — unsigned device target.
- `build.sh` — reproducible build of the FPC archive and the Xcode app.
- `redist/ios/SDL2.framework` — runtime framework files only (binary and
  `Info.plist`), with provenance in `redist/ios/SOURCES.txt`.

Generated `build/` and `DerivedData/` are git-ignored and safe to delete.
Task status and verification notes live in `Work/R-30_ios_platform.md`, not
here.
