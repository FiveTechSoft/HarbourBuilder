#!/usr/bin/env bash
# Harbour for Android - cross-compile from Windows (MSYS2 bash)
#
# Prerequisites:
#   - Android NDK r26+ installed
#   - Native Windows Harbour already built (for host hbmk2 bootstrap)
#   - GNU make (bundled in Harbour: C:\harbour\win-make.exe) and git
#
# Usage:
#   ./build-android.sh            # build arm64-v8a (default)
#   ABI=armeabi-v7a ./build-android.sh
#   ABI=x86_64 ./build-android.sh
#   CLEAN=1 ./build-android.sh    # make clean first

set -eu

# ---------- configurable ----------
: "${NDK_ROOT:=/c/Android/android-ndk-r26d}"
: "${HARBOUR_SRC:=/c/HarbourAndroid/harbour-core}"
: "${HARBOUR_HOST:=/c/harbour}"                   # native Windows Harbour (bootstrap)
: "${HARBOUR_HOST_BIN:=/c/harbour/bin/win/bcc}"   # dir with hbmk2.exe, harbour.exe
: "${API_LEVEL:=24}"
: "${ABI:=arm64-v8a}"
: "${JOBS:=8}"
: "${MAKE_BIN:=/c/harbour/win-make.exe}"
# ----------------------------------

case "$ABI" in
  arm64-v8a)     TRIPLE=aarch64-linux-android ;;
  armeabi-v7a)   TRIPLE=armv7a-linux-androideabi ;;
  x86_64)        TRIPLE=x86_64-linux-android ;;
  x86)           TRIPLE=i686-linux-android ;;
  *) echo "Unknown ABI: $ABI" >&2; exit 1 ;;
esac

NDK_BIN="$NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64/bin"
CC_BIN="$NDK_BIN/${TRIPLE}${API_LEVEL}-clang"
CXX_BIN="$NDK_BIN/${TRIPLE}${API_LEVEL}-clang++"

# --- sanity checks ---
[ -d "$NDK_ROOT" ]       || { echo "NDK not found at $NDK_ROOT"; exit 1; }
[ -x "${CC_BIN}.cmd" ] || [ -f "${CC_BIN}.cmd" ] || [ -x "$CC_BIN" ] || {
  echo "Clang not found: $CC_BIN(.cmd)"; exit 1; }
[ -d "$HARBOUR_SRC" ]    || { echo "Harbour src not found at $HARBOUR_SRC"; exit 1; }
[ -f "$HARBOUR_HOST_BIN/hbmk2.exe" ] || {
  echo "Host hbmk2.exe not found at $HARBOUR_HOST_BIN"; exit 1; }

echo "=============================================="
echo " Harbour for Android build"
echo "=============================================="
echo " NDK        : $NDK_ROOT"
echo " ABI        : $ABI  ($TRIPLE)"
echo " API level  : $API_LEVEL"
echo " Host HB    : $HARBOUR_HOST"
echo " Src        : $HARBOUR_SRC"
echo " Jobs       : $JOBS"
echo "=============================================="

# --- environment for the Harbour build system ---
export HB_PLATFORM=android
export HB_COMPILER=clang
export HB_BUILD_STRIP=all
export HB_BUILD_CONTRIBS=no          # start minimal; enable later
: "${DYN:=no}"                        # set DYN=yes to also build libharbour.so
export HB_BUILD_DYN=$DYN
export HB_BUILD_SHARED=$DYN
export HB_BUILD_PARTS=lib
export HB_BUILD_NAME=-android-$ABI

# Point host-tool invocations (hbmk2, hbpp) at the Windows native build
export HB_HOST_BIN="$HARBOUR_HOST_BIN"
export PATH="$HARBOUR_HOST_BIN:$NDK_BIN:$PATH"

# Compiler overrides
export HB_CCPATH="$NDK_BIN/"
export HB_CCPREFIX=""
export HB_CC="${TRIPLE}${API_LEVEL}-clang"
export HB_CXX="${TRIPLE}${API_LEVEL}-clang++"
export HB_LD="$HB_CC"
export HB_AR="$NDK_BIN/llvm-ar"
export HB_RANLIB="$NDK_BIN/llvm-ranlib"
export HB_STRIP="$NDK_BIN/llvm-strip"

# ABI-specific flags
case "$ABI" in
  armeabi-v7a)
    EXTRA_CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16 -mthumb"
    ;;
  *)
    EXTRA_CFLAGS=""
    ;;
esac

CLANG_TARGET="--target=${TRIPLE}${API_LEVEL}"
export HB_USER_CFLAGS="$CLANG_TARGET -fPIC $EXTRA_CFLAGS"
export HB_USER_LDFLAGS="$CLANG_TARGET"

cd "$HARBOUR_SRC"

if [ "${CLEAN:-0}" = "1" ]; then
  echo ">>> $MAKE_BIN clean"
  "$MAKE_BIN" clean || true
fi

echo ">>> $MAKE_BIN -j$JOBS"
"$MAKE_BIN" -j"$JOBS"

echo
echo "=============================================="
echo " Build finished. Look for libs under:"
echo "   $HARBOUR_SRC/lib/android/clang$HB_BUILD_NAME/"
echo "=============================================="
