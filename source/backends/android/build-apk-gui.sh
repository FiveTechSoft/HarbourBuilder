#!/usr/bin/env bash
# build-apk-gui.sh - Build an APK from the Android GUI backend.
#
# Assembles the build directory from the repo (source of truth) into
# $WORK, compiles android_core.c + the user's PRG, links libapp.so and
# produces a signed APK.
#
# Usage:
#   build-apk-gui.sh <project_prg>
#     project_prg : path to a .prg whose Main() calls UI_FormNew etc.
#
# Defaults to hello_gui.prg (the demo shipped next to this script).

set -eu

# ---------- paths ----------
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"   # source/backends/android/
PRG_SRC="${1:-$SCRIPT_DIR/hello_gui.prg}"

WORK=/c/HarbourAndroid/apk-gui
HB_SRC=/c/HarbourAndroid/harbour-core
HB_LIB=$HB_SRC/lib/android/clang-android-arm64-v8a
HB_INC=$HB_SRC/include
HOST_HB=/c/harbour/bin/win/bcc/harbour.exe

NDK=/c/Android/android-ndk-r26d
NDK_BIN=$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin
CLANG=$NDK_BIN/clang.exe
TARGET=aarch64-linux-android24

SDK=/c/Android/Sdk
JDK=/c/JDK17/jdk-17.0.13+11
BT=$SDK/build-tools/34.0.0
ANDROID_JAR=$SDK/platforms/android-34/android.jar
KEYSTORE=/c/HarbourAndroid/apk-demo/debug.keystore  # reuse existing debug keystore

export PATH="$JDK/bin:$BT:$PATH"
export JAVA_HOME="$JDK"

# ---------- stage build dir ----------
echo ">>> staging $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"/{obj,gen,jni-libs/arm64-v8a,apk,res-compiled,classes,src/prg,src/cpp}

cp    "$SCRIPT_DIR/android_core.c"     "$WORK/src/cpp/"
cp    "$PRG_SRC"                       "$WORK/src/prg/hello.prg"
cp    "$SCRIPT_DIR/AndroidManifest.xml" "$WORK/"
cp -r "$SCRIPT_DIR/res"                "$WORK/src/"
cp -r "$SCRIPT_DIR/java"               "$WORK/src/"

# ---------- 1. PRG -> C ----------
echo ">>> [1/8] harbour.exe hello.prg"
cd "$WORK/src/prg"
"$HOST_HB" hello.prg -n -q -I"$(cygpath -w $HB_INC)" -o"$(cygpath -w $WORK/obj/)"
ls "$WORK/obj/hello.c"

# ---------- 2. cross-compile ----------
echo ">>> [2/8] cross-compile C sources"
CFLAGS="--target=$TARGET -fPIC -O2 -Wall -I$HB_INC"
"$CLANG" $CFLAGS -c "$WORK/obj/hello.c"         -o "$WORK/obj/hello.o"
"$CLANG" $CFLAGS -c "$WORK/src/cpp/android_core.c" -o "$WORK/obj/android_core.o"

# ---------- 3. link libapp.so ----------
echo ">>> [3/8] link libapp.so"
"$CLANG" --target=$TARGET -shared -fPIC \
  -Wl,-soname,libapp.so \
  -o "$WORK/jni-libs/arm64-v8a/libapp.so" \
  "$WORK/obj/android_core.o" \
  -Wl,--whole-archive \
  "$WORK/obj/hello.o" \
  -Wl,--no-whole-archive \
  -L"$HB_LIB" \
  -Wl,--start-group \
  -lhbvm -lhbrtl -lhblang -lhbcpage -lhbrdd -lhbmacro -lhbpp -lhbcommon \
  -lhbpcre -lhbzlib -lhbnulrdd -lhbdebug -lhbcplr \
  -lrddntx -lrddcdx -lrddfpt -lrddnsx \
  -lgtstd -lgttrm -lgtcgi -lgtpca \
  -lhbsix -lhbhsx \
  -Wl,--end-group \
  -ldl -lm -llog
ls -lh "$WORK/jni-libs/arm64-v8a/libapp.so"

# ---------- 4. aapt2 compile ----------
echo ">>> [4/8] aapt2 compile"
aapt2 compile --dir "$WORK/src/res" -o "$WORK/res-compiled"

# ---------- 5. aapt2 link ----------
echo ">>> [5/8] aapt2 link"
aapt2 link \
  -I "$ANDROID_JAR" \
  --manifest "$WORK/AndroidManifest.xml" \
  --java "$WORK/gen" \
  -o "$WORK/apk/base.apk" \
  $(ls "$WORK/res-compiled"/*.flat)

# ---------- 6. javac ----------
echo ">>> [6/8] javac"
javac -d "$WORK/classes" \
      -source 1.8 -target 1.8 \
      -bootclasspath "$ANDROID_JAR" \
      -classpath "$ANDROID_JAR" \
      $(find "$WORK/src/java" "$WORK/gen" -name '*.java')

# ---------- 7. d8 ----------
echo ">>> [7/8] d8"
d8.bat --lib "$ANDROID_JAR" --min-api 24 \
       --output "$WORK/apk" $(find "$WORK/classes" -name '*.class')
ls "$WORK/apk/classes.dex"

# ---------- 8. package & sign ----------
echo ">>> [8/8] package & sign"
cp "$WORK/apk/base.apk" "$WORK/apk/unsigned.apk"

# Stage payload tree and add classes.dex + libapp.so to the APK via jar uf.
mkdir -p "$WORK/payload/lib/arm64-v8a"
cp "$WORK/apk/classes.dex"              "$WORK/payload/classes.dex"
cp "$WORK/jni-libs/arm64-v8a/libapp.so" "$WORK/payload/lib/arm64-v8a/libapp.so"
cd "$WORK/payload"
"$JDK/bin/jar.exe" uf "$WORK/apk/unsigned.apk" classes.dex lib/arm64-v8a/libapp.so
cd "$WORK"

zipalign.exe -f -p 4 "$WORK/apk/unsigned.apk" "$WORK/apk/aligned.apk"

# Debug keystore (reuse if already created, else generate)
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -v -keystore "$KEYSTORE" -alias demo -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass android -keypass android \
    -dname "CN=HarbourBuilder Debug,O=HarbourBuilder,C=ES"
fi

apksigner.bat sign --ks "$KEYSTORE" --ks-pass pass:android \
                   --key-pass pass:android \
                   --out "$WORK/harbour-gui.apk" "$WORK/apk/aligned.apk"

echo "=============================================="
echo " APK ready: $WORK/harbour-gui.apk"
ls -lh "$WORK/harbour-gui.apk"
echo "=============================================="
