# Android Toolchain Manifest (status quo, 2026-07-06)

Records the exact toolchain that produced the first green Android
compile/package gate (engine5 `83c869af`). Until the planned toolchain
repository publishes prebuilt cross-compilers as versioned releases, this file
is the reproducibility pin; at that point it becomes (or is replaced by) a
machine-readable lock referencing a toolchain release + SHA256.

## Pinned identities (machine-independent)

| Component | Identity |
|---|---|
| FPC | trunk commit `afe4d4122e` (3.3.1-20523-gafe4d4122e), <https://gitlab.com/freepascal.org/fpc/source.git> |
| FPC patch | `patches/fpc-android-lld.patch` applied to the source tree before building the cross-compiler |
| GNU cross-binutils (`as`, `ar`, `ld`, `objcopy`, `strip`) | fpcupdeluxe WinCrossBins v1.1: <https://github.com/LongDirtyAnimAlf/fpcupdeluxe/releases/download/wincrossbins_v1.1/WinCrossBinsAndroidAll.zip> |
| LLD linker | `ld.lld.exe` from NDK r27d (`toolchains/llvm/prebuilt/<host>/bin/`), LLD 18.0.4, renamed to `aarch64-linux-android-ld.lld.exe` |
| Android NDK | 27.3.13750724 (r27d) |
| Android SDK | Platform 36, Build Tools 36.0.0 |
| Gradle | 8.11.1 (wrapper, SHA256-pinned in `shell/gradle/wrapper/gradle-wrapper.properties`) |
| Android Gradle Plugin | 8.10.1 (`shell/build.gradle`) |
| SDL | 2.30.9 (SHA256-pinned in `package.ps1`) |
| JDK | Oracle JDK 22.0.1, resolved from PATH (AGP needs >=17; pin a Temurin LTS when the toolchain repo lands) |
| Target | `aarch64-android` only, min API 21 |

## Host instantiation (Windows dev machine, informative)

fpcupdeluxe installation under `G:\android` (local README there repeats this):

```powershell
$env:FPC_ANDROID='G:\android\fpcup\fpc\bin\x86_64-win64\ppcrossa64.exe'
$env:FPC_ANDROID_BINUTILS='G:\android\cross-tools\aarch64-android'
$env:ANDROID_SDK_ROOT='G:\android\sdk'
$env:ANDROID_NDK_ROOT='G:\android\sdk\ndk\27.3.13750724'
```

- FPC source checkout: `G:\android\fpcup\fpcsrc` (git, LLD patch applied as a
  working-tree modification of `compiler/systems/t_android.pas` — verified
  identical to the repository patch).
- The binutils directory mixes two origins on purpose: GNU tools come from the
  fpcupdeluxe crossbins archive, while `ld.lld` is the NDK's linker under the
  target-prefixed name FPC invokes. NDK r24+ ships no GNU binutils, so the
  assembler `as` is the piece that must come from the crossbins archive.
- Origins hash-verified 2026-07-06: `aarch64-linux-android-as.exe` matches the
  crossbins copy, `aarch64-linux-android-ld.lld.exe` matches the NDK r27d copy.
