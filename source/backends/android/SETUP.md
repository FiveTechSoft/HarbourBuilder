# Android target — setup guide

HarbourBuilder's Android target turns your `.prg` forms into signed APKs
running on a real Android emulator or device. This page documents every
prerequisite the toolchain needs so a fresh clone can build an APK.

**Auto-installer wizard is on the roadmap (iteration 6).** Until it lands,
follow this guide once; everything is self-contained and stays outside
the system `PATH` / registry.

---

## 1 · External toolchain (~4 GB total)

Install to the paths below — the build scripts assume them. If you put
them elsewhere, edit `source/backends/android/build-apk-gui.sh` and
`bootstrap-harbour.sh`.

| Component | Version | Path | Download |
|---|---|---|---|
| **Android NDK** | r26d | `C:\Android\android-ndk-r26d\` | https://developer.android.com/ndk/downloads |
| **Android SDK cmdline-tools** | latest | `C:\Android\Sdk\cmdline-tools\latest\` | https://developer.android.com/studio#command-line-tools-only |
| **Android platform** | android-34 | `C:\Android\Sdk\platforms\android-34\` | `sdkmanager "platforms;android-34"` |
| **Android build-tools** | 34.0.0 | `C:\Android\Sdk\build-tools\34.0.0\` | `sdkmanager "build-tools;34.0.0"` |
| **platform-tools (adb)** | latest | `C:\Android\Sdk\platform-tools\` | `sdkmanager "platform-tools"` |
| **emulator** | latest | `C:\Android\Sdk\emulator\` | `sdkmanager "emulator"` |
| **system-image** | android-34 / google_apis / x86_64 | `C:\Android\Sdk\system-images\android-34\google_apis\x86_64\` | `sdkmanager "system-images;android-34;google_apis;x86_64"` |
| **JDK 17** | Temurin portable | `C:\JDK17\jdk-17.0.13+11\` | https://adoptium.net/temurin/releases/ |
| **Git for Windows** | any recent | `C:\Program Files\Git\` | https://git-scm.com/download/win |

### NDK tweak (one-time)

Inside `C:\Android\android-ndk-r26d\toolchains\llvm\prebuilt\windows-x86_64\bin\`
the Harbour make files expect bare `ar`, `ranlib`, `strip`. Copy (don't
rename — we still want the `llvm-*` originals):

```cmd
cd C:\Android\android-ndk-r26d\toolchains\llvm\prebuilt\windows-x86_64\bin
copy llvm-ar.exe     ar.exe
copy llvm-ranlib.exe ranlib.exe
copy llvm-strip.exe  strip.exe
```

### Create the AVD

```bash
/c/Android/Sdk/cmdline-tools/latest/bin/avdmanager.bat create avd \
  -n HarbourBuilderAVD \
  -k "system-images;android-34;google_apis;x86_64" \
  -d pixel_5
```

---

## 2 · Cross-compile Harbour for Android (~13 MB of .a)

This is the step most people skip. HarbourBuilder needs **Harbour itself**
built for Android (ARM64) — 30 static libraries (`libhbvm.a`, `libhbrtl.a`,
`libgttrm.a`, …) that get linked into every APK you produce.

### Prerequisites

- A **native Windows Harbour** installed at `C:\harbour\` (the same one
  HarbourBuilder uses to build itself). `build_win.bat` in the repo
  root runs the bootstrap.
- The above Android toolchain in place.

### Run the bootstrap

```bash
# One-time clone of the official Harbour sources to
# C:\HarbourAndroid\harbour-core\ (and subsequent builds)
mkdir -p /c/HarbourAndroid
cd /c/HarbourAndroid
git clone https://github.com/harbour/core harbour-core

# Cross-compile for arm64-v8a (default)
cp /c/HarbourBuilder/source/backends/android/bootstrap-harbour.sh .
bash bootstrap-harbour.sh
```

Takes ~5-10 minutes. Output is 30 `.a` files in
`/c/HarbourAndroid/harbour-core/lib/android/clang-android-arm64-v8a/`.

Alternative ABIs:
```bash
ABI=armeabi-v7a bash bootstrap-harbour.sh   # 32-bit ARM
ABI=x86_64      bash bootstrap-harbour.sh   # emulator host arch
```

### Why not ship the prebuilt .a in the repo?

Because (a) they're build artifacts, (b) Harbour evolves and the user
may want to track upstream, (c) they're per-ABI and per-NDK-version.
Shipping the recipe (`bootstrap-harbour.sh`) is the right layer.

---

## 3 · Validate

From the HarbourBuilder repo root:

```bash
# 1. Build the demo APK using the GUI pipeline
bash source/backends/android/build-apk-gui.sh

# 2. Boot emulator, install, launch, stream logcat
bash source/backends/android/install-and-run.sh
```

You should see "Hello Android" with a Label, EditText and Button on the
Pixel 5 emulator. Type a name, press "Saludar" → the label updates.

Or, all in one from the IDE:

1. Open HarbourBuilder (`bin/hbbuilder_win.exe`)
2. Load `samples/projects/android/Project1.hbp`
3. Menu **Run → Run on Android...**

The IDE generates `_generated.prg` from your form, runs the full
pipeline, boots the emulator, installs the APK and opens a logcat window.

---

## 4 · Troubleshooting

### Trace log

Every Run-on-Android session appends to
`C:\HarbourBuilder\android_trace.log` with paths, PRG size, build cmd,
control enumeration, return codes. Start here when something silently
fails.

### Build log

`C:\HarbourAndroid\build-apk-gui.log` contains the stdout/stderr of the
8-stage APK pipeline. On build failure the IDE shows it in a dialog;
you can also `cat` it.

### App launched but widgets missing or crash

Open the logcat terminal that install-and-run.sh leaves open. Look for
`HbAndroid:*` and `AndroidRuntime:*` lines. Common culprits:

- **UnsatisfiedLinkError: cannot locate symbol HB_FUN_*** — the
  generated PRG references a function that's not in `_generated.prg`.
  Almost always a handler the translator couldn't match. Check
  `source/backends/android/_generated.prg` to see what was emitted.
- **variable 'hXxx' does not exist** — fixed in iter 1b by emitting
  control handles as module-scope `STATIC`. If you see this, you're
  running an old APK; rebuild.

### Emulator never finishes booting

The install-and-run terminal polls `sys.boot_completed` every 2 seconds.
If it sits there forever: kill the emulator, delete the AVD's
`.android/avd/HarbourBuilderAVD.avd/*.lock` files and try again.

---

## 5 · Roadmap

The manual steps above are temporary. Target state (iteration 6):

**Setup Android Wizard** inside the IDE that:

1. Scans for existing installs — offers to reuse an Android Studio SDK
   or NDK already on the machine.
2. Downloads any missing component from Google / Adoptium with a progress
   bar, staying inside `<HarbourBuilder>/android-toolchain/` (no PATH,
   no registry, no admin).
3. Generates the AVD.
4. Runs `bootstrap-harbour.sh` to produce the cross-compiled libs.
5. Validates end-to-end by building & launching the sample.

Tracked in `project_mobile.md`. Until then, this guide is the source of
truth.
