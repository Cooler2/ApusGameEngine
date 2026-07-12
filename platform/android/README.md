# Android CLI Toolset

This directory contains the IDE-independent Android build path for R-24. The
eventual pipeline is:

`FPC cross-compiler -> Android NDK linker -> lib<demo>.so -> Gradle wrapper -> APK`

The current S1 slice builds and runs TouchDemo on the ARM64 Android emulator.
It validates the host toolchain, links the Engine5/TouchDemo closure into a
Pascal SDL entry library, packages the demo asset, and assembles a debug APK.

The canonical modern-NDK path uses FPC's `-XLL` switch and LLVM's `ld.lld`.
Current FPC trunk needs the patch in `patches/fpc-android-lld.patch`: it teaches
the Android backend to select `ld.lld` and omits a GNU BFD-only linker-script
anchor that LLD cannot process. Keep the patch tied to the recorded FPC commit
until it is accepted upstream. The exact FPC commit, binutils origins, and all
other component pins are recorded in `toolchain.lock.md`.

## Quick start

From the repository root:

```powershell
pwsh ./platform/android/toolchain.ps1
```

Use `-CheckOnly` to report the environment without compiling the probe:

```powershell
pwsh ./platform/android/toolchain.ps1 -CheckOnly
```

On an Apple Silicon Mac, source the local environment helper before running a
native command. It records the FPC 3.3.1-20523 installation, NDK r27d, and the
Homebrew JDK 21 locations used for the R-24 bring-up. It also keeps AVD data
under `~/Library/Android/avd`:

```sh
. ./platform/android/macos_env.sh
```

Compile TouchDemo with the full Engine5 `GameApp` closure and package it into a debug APK
through the pinned SDL/Gradle shell:

```powershell
pwsh ./platform/android/package.ps1
```

The packaging script downloads and verifies the SDL 2.30.9 source archive,
stages its official Android project under `tmp/android/package/`, builds SDL for
`arm64-v8a`, links TouchDemo against it, and adds both libraries plus
`sprite.png` to the APK. At startup the asset is copied through `Apus.Android`
to the app-private `app_Data` directory before the resource system loads it.
Gradle 8.11.1, Android
Gradle Plugin 8.10.1, compile/target SDK 36, NDK r27d, and minimum API 21 are
pinned at the build boundary.

S0 compiles the SDL-first OpenGL ES path. The obsolete GLSurfaceView bindings and Java
SoundPool/MediaPlayer backend remain available only through the explicit
`ANDROID_NATIVE_JNI` and `ANDROID_LEGACY_AUDIO` defines; neither is part of the
current package gate.

The script is intentionally usable from a terminal, CI, a Lazarus external
tool, or a VS Code task. No IDE project is authoritative.

## Toolchain contract

The script resolves these tools from explicit environment variables first:

| Variable | Purpose |
|---|---|
| `FPC_ANDROID` | Full path to the FPC `ppcrossa64` executable |
| `FPC_ANDROID_BINUTILS` | Directory containing `aarch64-linux-android-as` and the selected target linker |
| `FPC_ANDROID_UNITS` | Optional root of the `aarch64-android` FPC unit tree when the compiler has no local `fpc.cfg`; all installed package directories are added after project paths, preserving local compatibility units |
| `FPC_ANDROID_LINKER` | Optional linker kind: `lld` (default, requires `aarch64-linux-android-ld.lld`) or `bfd` (requires `aarch64-linux-android-ld`) |
| `ANDROID_SDK_ROOT` | Android SDK command-line installation |
| `ANDROID_NDK_ROOT` | Pinned Android NDK installation |
| `JAVA_HOME` | JDK used by the future Gradle build |

Standard command lookup and Android SDK/NDK environment aliases are accepted
as fallbacks. CI should set explicit paths or restore them from a pinned cache.

The default target is `aarch64-android` at API 21, the first Android API with
64-bit support. Override the API for experiments with `-ApiLevel`.

## Output

Generated files stay under `tmp/android/`:

- `units/` - FPC intermediate units and objects;
- `libapus_android_probe.so` - minimal JNI-loadable ARM64 library.
- `engine-units/` - FPC output for the Engine5 compile gate;
- `libapus_android_engine_probe.so` - linked Engine5 `GameApp` closure;
- `downloads/` and `sources/` - verified SDL source cache;
- `package/` - generated Gradle project and debug APK.

The probe exports `JNI_OnLoad`. If the NDK `llvm-readelf` tool is available,
the script verifies both the AArch64 ELF header and the export.

## Runtime status and next slice

S1 is verified on the API 36 Google APIs ARM64 emulator: the APK loads, creates
an accepted GLES 3.0 context (ANGLE exposes GLES 3.1), renders TouchDemo's line
pattern and PNG sprite at the native `320x480` drawable size, and SDL's primary
touch/mouse mapping drags the sprite. Audio is deliberately disabled for this
gate.

Next, handle Android system bars/display cutouts so UI content uses a deliberate
safe area (the current `Drag the ball` label is under the status/cutout area),
then verify pause/resume, rotation/context restoration, clean exit, and text
input.
