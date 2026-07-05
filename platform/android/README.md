# Android CLI Toolset

This directory contains the IDE-independent Android build path for R-24. The
eventual pipeline is:

`FPC cross-compiler -> Android NDK linker -> lib<demo>.so -> Gradle wrapper -> APK`

The current T0 slice validates the host toolchain and builds a minimal JNI
library when the native prerequisites are available. It does not build Engine5
or an APK yet.

## Quick start

From the repository root:

```powershell
pwsh ./platform/android/toolchain.ps1
```

Use `-CheckOnly` to report the environment without compiling the probe:

```powershell
pwsh ./platform/android/toolchain.ps1 -CheckOnly
```

The script is intentionally usable from a terminal, CI, a Lazarus external
tool, or a VS Code task. No IDE project is authoritative.

## Toolchain contract

The script resolves these tools from explicit environment variables first:

| Variable | Purpose |
|---|---|
| `FPC_ANDROID` | Full path to the FPC `ppcrossa64` executable |
| `FPC_ANDROID_BINUTILS` | Directory containing `aarch64-linux-android-as` and `aarch64-linux-android-ld` |
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

The probe exports `JNI_OnLoad`. If the NDK `llvm-readelf` tool is available,
the script verifies both the AArch64 ELF header and the export.

## Next slice

T1 will add a pinned Gradle wrapper and minimal Android/SDL shell that packages
the probe library into a debug APK. Engine units remain outside the toolchain
probe until that package path is reproducible locally and in CI.
