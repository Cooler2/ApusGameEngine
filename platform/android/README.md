# Android CLI Toolset

This directory contains the IDE-independent Android build path for R-24. The
eventual pipeline is:

`FPC cross-compiler -> Android NDK linker -> lib<demo>.so -> Gradle wrapper -> APK`

The current T0 slice validates the host toolchain and builds a minimal JNI
library when the native prerequisites are available. It does not build Engine5
or an APK yet.

The canonical modern-NDK path uses FPC's `-XLL` switch and LLVM's `ld.lld`.
Current FPC trunk needs the patch in `patches/fpc-android-lld.patch`: it teaches
the Android backend to select `ld.lld` and omits a GNU BFD-only linker-script
anchor that LLD cannot process. Keep the patch tied to the recorded FPC commit
until it is accepted upstream.

## Quick start

From the repository root:

```powershell
pwsh ./platform/android/toolchain.ps1
```

Use `-CheckOnly` to report the environment without compiling the probe:

```powershell
pwsh ./platform/android/toolchain.ps1 -CheckOnly
```

Package the probe into a debug APK through the pinned SDL/Gradle shell:

```powershell
pwsh ./platform/android/package.ps1
```

The packaging script downloads and verifies the SDL 2.30.9 source archive,
stages its official Android project under `tmp/android/package/`, builds SDL for
`arm64-v8a`, and adds the FPC probe library to the APK. Gradle 8.11.1, Android
Gradle Plugin 8.10.1, compile/target SDK 36, NDK r27d, and minimum API 21 are
pinned at the build boundary.

The script is intentionally usable from a terminal, CI, a Lazarus external
tool, or a VS Code task. No IDE project is authoritative.

## Toolchain contract

The script resolves these tools from explicit environment variables first:

| Variable | Purpose |
|---|---|
| `FPC_ANDROID` | Full path to the FPC `ppcrossa64` executable |
| `FPC_ANDROID_BINUTILS` | Directory containing `aarch64-linux-android-as` and `aarch64-linux-android-ld.lld` |
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
- `downloads/` and `sources/` - verified SDL source cache;
- `package/` - generated Gradle project and debug APK.

The probe exports `JNI_OnLoad`. If the NDK `llvm-readelf` tool is available,
the script verifies both the AArch64 ELF header and the export.

## Next slice

S0 will replace the packaging probe with a minimal Engine5 target and compile
Android code paths without the deprecated PainterGL/PainterGL2 backend.
