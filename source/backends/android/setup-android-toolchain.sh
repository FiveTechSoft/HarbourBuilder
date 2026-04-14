#!/usr/bin/env bash
# setup-android-toolchain.sh
#
# Downloads + installs every external component HarbourBuilder needs to
# target Android, into fixed paths under C:\. Skips pieces already present.
# Runs in its own terminal window so the user can watch progress and
# accept the SDK license interactively.
#
# Components (in install order):
#   1. JDK 17 Temurin      ~175 MB  -> C:\JDK17\
#   2. Android NDK r26d    ~1.5 GB  -> C:\Android\android-ndk-r26d\
#   3. SDK cmdline-tools   ~100 MB  -> C:\Android\Sdk\cmdline-tools\latest\
#   4. SDK packages        ~1.2 GB  -> C:\Android\Sdk\   (via sdkmanager)
#      * platform-tools, platforms;android-34, build-tools;34.0.0,
#        emulator, system-images;android-34;google_apis;x86_64
#   5. AVD HarbourBuilderAVD        -> ~/.android/avd/HarbourBuilderAVD.avd
#   6. Harbour-for-Android libs     -> C:\HarbourAndroid\harbour-core\
#      (extracted from releases/harbour-android-arm64-v8a.zip in the repo)
#
# Total download on a fresh machine ~2.8 GB. Takes 5-20 minutes depending
# on bandwidth.

set -u

on_exit() {
  local rc=$?
  echo
  echo "============================================================"
  echo " setup-android-toolchain finished (exit code $rc)"
  echo "============================================================"
  read -p "Press enter to close this window..." _
}
trap on_exit EXIT

# ---------- configurable paths ----------
JDK_ROOT=/c/JDK17
JDK_SUB=jdk-17.0.13+11
JDK_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13%2B11/OpenJDK17U-jdk_x64_windows_hotspot_17.0.13_11.zip"

NDK_ROOT=/c/Android/android-ndk-r26d
NDK_URL="https://dl.google.com/android/repository/android-ndk-r26d-windows.zip"

SDK_ROOT=/c/Android/Sdk
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

AVD_NAME=HarbourBuilderAVD
SYSIMG="system-images;android-34;google_apis;x86_64"

HB_REPO=/c/HarbourBuilder
HB_ANDROID_LIB_ZIP="$HB_REPO/releases/harbour-android-arm64-v8a.zip"
HB_ANDROID_ROOT=/c/HarbourAndroid/harbour-core

banner() {
  echo
  echo "============================================================"
  echo " $*"
  echo "============================================================"
}

have_java() { [ -f "$JDK_ROOT/$JDK_SUB/bin/javac.exe" ]; }
have_ndk()  { [ -d "$NDK_ROOT" ]; }
have_cmdt() { [ -f "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager.bat" ]; }
have_plat() { [ -d "$SDK_ROOT/platforms/android-34" ]; }
have_bt()   { [ -d "$SDK_ROOT/build-tools/34.0.0" ]; }
have_pt()   { [ -f "$SDK_ROOT/platform-tools/adb.exe" ]; }
have_emu()  { [ -f "$SDK_ROOT/emulator/emulator.exe" ]; }
have_sysimg() { [ -d "$SDK_ROOT/system-images/android-34/google_apis/x86_64" ]; }
have_avd()  { [ -d "$USERPROFILE/.android/avd/$AVD_NAME.avd" ]; }
have_hbAnd() { [ -d "$HB_ANDROID_ROOT/lib/android/clang-android-arm64-v8a" ]; }

download() {   # download <url> <dest>
  local url="$1" dest="$2"
  echo ">>> downloading: $url"
  echo "    -> $dest"
  curl -L --retry 3 -o "$dest" "$url"
}

unzip_to() {   # unzip_to <zip> <dest-root>
  local zip="$1" dest="$2"
  mkdir -p "$dest"
  echo ">>> extracting $zip"
  echo "    -> $dest"
  # Prefer PowerShell Expand-Archive (ships with Windows, reliable for big zips)
  powershell -NoProfile -Command \
    "Expand-Archive -Force -LiteralPath '$(cygpath -w "$zip")' -DestinationPath '$(cygpath -w "$dest")'"
}

# ---------- 1. JDK ----------
if ! have_java; then
  banner "1/6  JDK 17 (Temurin)  ~175 MB"
  mkdir -p /tmp/hb-android-setup
  download "$JDK_URL" /tmp/hb-android-setup/jdk.zip
  unzip_to /tmp/hb-android-setup/jdk.zip "$JDK_ROOT"
  have_java && echo "    OK: $JDK_ROOT/$JDK_SUB" || { echo "JDK install FAILED"; exit 1; }
else
  echo "[skip] JDK 17 already installed"
fi
export JAVA_HOME="$JDK_ROOT/$JDK_SUB"
export PATH="$JAVA_HOME/bin:$PATH"

# ---------- 2. NDK ----------
if ! have_ndk; then
  banner "2/6  Android NDK r26d  ~1.5 GB"
  mkdir -p /tmp/hb-android-setup /c/Android
  download "$NDK_URL" /tmp/hb-android-setup/ndk.zip
  unzip_to /tmp/hb-android-setup/ndk.zip /c/Android
  # Harbour's mk files call bare ar/ranlib/strip; copy the llvm-* names.
  local_bin="$NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64/bin"
  if [ -d "$local_bin" ]; then
    cp -n "$local_bin/llvm-ar.exe"     "$local_bin/ar.exe"     || true
    cp -n "$local_bin/llvm-ranlib.exe" "$local_bin/ranlib.exe" || true
    cp -n "$local_bin/llvm-strip.exe"  "$local_bin/strip.exe"  || true
  fi
  have_ndk && echo "    OK: $NDK_ROOT" || { echo "NDK install FAILED"; exit 1; }
else
  echo "[skip] NDK already installed"
fi

# ---------- 3. SDK cmdline-tools ----------
if ! have_cmdt; then
  banner "3/6  Android SDK cmdline-tools  ~100 MB"
  mkdir -p /tmp/hb-android-setup "$SDK_ROOT/cmdline-tools"
  download "$CMDLINE_URL" /tmp/hb-android-setup/cmdline.zip
  # The zip extracts to cmdline-tools/, but sdkmanager expects it under
  # cmdline-tools/latest/ so it can coexist with future versions.
  rm -rf "$SDK_ROOT/cmdline-tools/latest"
  unzip_to /tmp/hb-android-setup/cmdline.zip "$SDK_ROOT/cmdline-tools/_tmp"
  mv "$SDK_ROOT/cmdline-tools/_tmp/cmdline-tools" "$SDK_ROOT/cmdline-tools/latest"
  rm -rf "$SDK_ROOT/cmdline-tools/_tmp"
  have_cmdt && echo "    OK: cmdline-tools installed" || { echo "cmdline-tools FAILED"; exit 1; }
else
  echo "[skip] SDK cmdline-tools already installed"
fi
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$PATH"

# ---------- 4. SDK packages ----------
missing_pkgs=()
have_plat  || missing_pkgs+=("platforms;android-34")
have_bt    || missing_pkgs+=("build-tools;34.0.0")
have_pt    || missing_pkgs+=("platform-tools")
have_emu   || missing_pkgs+=("emulator")
have_sysimg|| missing_pkgs+=("$SYSIMG")

if [ ${#missing_pkgs[@]} -gt 0 ]; then
  banner "4/6  SDK packages  (~1.2 GB)"
  echo "Installing: ${missing_pkgs[*]}"
  echo
  echo "You will be prompted to accept the Android SDK licenses."
  echo "Type 'y' and press enter at each prompt (or 'yes | sdkmanager ...')."
  echo
  cmdmgr="$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager.bat"
  yes | "$cmdmgr" --sdk_root="$(cygpath -w "$SDK_ROOT")" --licenses
  "$cmdmgr" --sdk_root="$(cygpath -w "$SDK_ROOT")" --install "${missing_pkgs[@]}"
else
  echo "[skip] all SDK packages already installed"
fi

# ---------- 5. AVD ----------
if ! have_avd; then
  banner "5/6  AVD '$AVD_NAME'  (Pixel 5, android-34)"
  avdmgr="$SDK_ROOT/cmdline-tools/latest/bin/avdmanager.bat"
  echo "no" | "$avdmgr" create avd -n "$AVD_NAME" -k "$SYSIMG" -d pixel_5
  have_avd && echo "    OK: AVD created" || echo "    WARN: AVD not detected"
else
  echo "[skip] AVD $AVD_NAME already exists"
fi

# ---------- 6. Harbour-for-Android libs ----------
if ! have_hbAnd; then
  banner "6/6  Harbour-for-Android  (3.6 MB, shipped in repo)"
  if [ ! -f "$HB_ANDROID_LIB_ZIP" ]; then
    echo "ERROR: shipped zip not found at $HB_ANDROID_LIB_ZIP"
    exit 1
  fi
  mkdir -p /c/HarbourAndroid "$HB_ANDROID_ROOT" /tmp/hb-android-setup
  unzip_to "$HB_ANDROID_LIB_ZIP" /tmp/hb-android-setup/hb-libs
  cp -r /tmp/hb-android-setup/hb-libs/harbour-android-arm64-v8a/* "$HB_ANDROID_ROOT/"
  rm -rf /tmp/hb-android-setup/hb-libs
  have_hbAnd && echo "    OK: $HB_ANDROID_ROOT" || { echo "Harbour libs install FAILED"; exit 1; }
else
  echo "[skip] Harbour-for-Android already installed"
fi

banner "All done. You can now Run > Run on Android from the IDE."
