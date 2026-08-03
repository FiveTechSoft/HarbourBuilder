#!/bin/bash
# FiveTech_ERP — macOS (same PRG set as Windows/Linux)
# Units: Project1.prg Form1.prg erp_meta.prg erp_http.prg erp_db.prg erp_proc.prg + classes.prg
# Backend: Cocoa + WKWebView
#
# Arch:
#   default  = host (uname -m)   → arm64 on Apple Silicon, x86_64 on Intel
#   ARCH=arm64 ./build_mac.sh    → force Apple Silicon (needs arm64 Harbour)
#   ARCH=x86_64 ./build_mac.sh   → force Intel
#   ARCH=universal ./build_mac.sh → lipo arm64 + x86_64 if both toolchains exist
set -e

PROJDIR="$(cd "$(dirname "$0")" && pwd)"
HBROOT="$(cd "$PROJDIR/../../.." && pwd)"
export HBROOT
HBDIR="${HBDIR:-$HOME/harbour}"

HOST_ARCH="$(uname -m)"
ARCH="${ARCH:-$HOST_ARCH}"
case "$ARCH" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  universal)     ARCH=universal ;;
  *) echo "ERROR: unsupported ARCH=$ARCH (use arm64|x86_64|universal)"; exit 1 ;;
esac

if [ "$ARCH" = "universal" ]; then
  BUILDDIR="$PROJDIR/_build_mac_universal"
  OUT="$PROJDIR/FiveTech_ERP"
  APP="$PROJDIR/FiveTech_ERP.app"
else
  BUILDDIR="$PROJDIR/_build_mac_${ARCH}"
  OUT="$PROJDIR/FiveTech_ERP"
  APP="$PROJDIR/FiveTech_ERP.app"
fi

# Prefer arch-specific Harbour install if present
if [ "$ARCH" = "arm64" ] && [ -f "$HOME/harbour-arm64/bin/darwin/clang/harbour" ]; then
  HBDIR="$HOME/harbour-arm64"
elif [ "$ARCH" = "x86_64" ] && [ -f "$HOME/harbour-x86_64/bin/darwin/clang/harbour" ]; then
  HBDIR="$HOME/harbour-x86_64"
fi

if [ -f "$HBDIR/bin/darwin/clang/harbour" ]; then
  HBBIN="$HBDIR/bin/darwin/clang"
elif [ -f "$HBDIR/bin/harbour" ]; then
  HBBIN="$HBDIR/bin"
else
  echo "ERROR: Harbour not found at $HBDIR"
  exit 1
fi
# Libs may be under lib/darwin/clang (in-tree) or lib/ (make install prefix)
if [ -d "$HBDIR/lib/darwin/clang" ] && ls "$HBDIR/lib/darwin/clang"/libhbvm*.a >/dev/null 2>&1; then
  HBLIB="$HBDIR/lib/darwin/clang"
elif [ -d "$HBDIR/lib" ] && ls "$HBDIR/lib"/libhbvm*.a >/dev/null 2>&1; then
  HBLIB="$HBDIR/lib"
else
  echo "ERROR: Harbour libs not found under $HBDIR/lib"
  ls -la "$HBDIR/lib" 2>/dev/null || true
  exit 1
fi
HBINC="$HBDIR/include"
echo "HBBIN=$HBBIN"
echo "HBLIB=$HBLIB"
ls "$HBLIB"/libhb*.a 2>/dev/null | head -20 || true

# Verify Harbour binary arch when forcing a target
if [ "$ARCH" != "universal" ]; then
  HB_ARCH="$(lipo -archs "$HBBIN/harbour" 2>/dev/null || file -b "$HBBIN/harbour" || true)"
  echo "Harbour arch: $HB_ARCH"
  if [ "$ARCH" = "arm64" ] && ! echo "$HB_ARCH" | grep -Eq 'arm64|aarch64'; then
    if [ "$HOST_ARCH" != "arm64" ]; then
      echo "ERROR: Apple Silicon (arm64) build needs Harbour arm64 on an arm64 Mac."
      echo "  Host is $HOST_ARCH. Install Harbour for arm64 or run this script on Apple Silicon."
      echo "  Hint: CI uses macos-14 (arm64). Local: build Harbour with arch arm64 into ~/harbour."
      exit 1
    fi
  fi
fi

echo "=== FiveTech_ERP macOS ==="
echo "HOST_ARCH=$HOST_ARCH  TARGET_ARCH=$ARCH"
echo "HBROOT=$HBROOT  HBDIR=$HBDIR"
echo "BUILDDIR=$BUILDDIR"

ARCH_FLAG=""
if [ "$ARCH" = "arm64" ]; then
  ARCH_FLAG="-arch arm64"
elif [ "$ARCH" = "x86_64" ]; then
  ARCH_FLAG="-arch x86_64"
fi

rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

cp -f "$HBROOT/include/hbbuilder.ch" . 2>/dev/null || true
cp -f "$HBROOT/include/hbide.ch" . 2>/dev/null || true
cp -f "$HBROOT/source/core/classes.prg" .

# On Cocoa, UI is native — use GT_NUL to avoid forcing a GUI GT symbol
bash "$PROJDIR/assemble_main.sh" "$PROJDIR" "$BUILDDIR" mac

echo "[1] Harbour compile (main + erp_meta + erp_http + erp_db + erp_proc + classes)"
"$HBBIN/harbour" main.prg     -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -omain.c
"$HBBIN/harbour" erp_meta.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_meta.c
"$HBBIN/harbour" erp_http.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_http.c
# Data layer (ErpDb*) — required by erp_http; assemble_main.sh already copies erp_db.prg
if [ ! -f "$BUILDDIR/erp_db.prg" ]; then
  echo "ERROR: erp_db.prg missing in $BUILDDIR (assemble_main should copy it)"
  exit 1
fi
"$HBBIN/harbour" erp_db.prg   -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_db.c
"$HBBIN/harbour" erp_proc.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_proc.c
"$HBBIN/harbour" classes.prg  -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oclasses.c

echo "[2] clang $ARCH_FLAG"
# Match CI/runtime macOS (runner is 14.x). If Harbour libs were built with a
# higher deployment target you may see ld warnings; rebuild Harbour with
# MACOSX_DEPLOYMENT_TARGET=$MACOSX_MIN or set MACOSX_MIN to match those libs.
MACOSX_MIN="${MACOSX_MIN:-14.0}"
CFLAGS="-O2 -Wno-unused-value -Wno-deprecated-declarations -mmacosx-version-min=$MACOSX_MIN $ARCH_FLAG -I$HBINC -I$HBROOT/include -I$BUILDDIR"
OBJCFLAGS="$CFLAGS -fobjc-arc"

clang $CFLAGS -c main.c -o main.o
clang $CFLAGS -c erp_meta.c -o erp_meta.o
clang $CFLAGS -c erp_http.c -o erp_http.o
clang $CFLAGS -c erp_db.c -o erp_db.o
clang $CFLAGS -c erp_proc.c -o erp_proc.o
clang $CFLAGS -c classes.c -o classes.o
clang $CFLAGS -c "$PROJDIR/mac_stubs.c" -o mac_stubs.o
clang $OBJCFLAGS -c "$HBROOT/source/backends/cocoa/cocoa_core.m" -o cocoa_core.o
[ -f "$HBROOT/source/backends/cocoa/cocoa_webserver.m" ] && \
  clang $OBJCFLAGS -c "$HBROOT/source/backends/cocoa/cocoa_webserver.m" -o cocoa_webserver.o || true

VMLIB="-lhbvm"
[ -f "$HBLIB/libhbvmmt.a" ] && VMLIB="-lhbvmmt"

# Only link libs that exist in this Harbour install
hblib() {
  local name="$1"
  if [ -f "$HBLIB/lib${name}.a" ] || [ -f "$HBLIB/${name}.a" ]; then
    echo "-l${name}"
  fi
}

OBJS="main.o erp_meta.o erp_http.o erp_db.o erp_proc.o classes.o cocoa_core.o mac_stubs.o"
[ -f cocoa_webserver.o ] && OBJS="$OBJS cocoa_webserver.o"

FRAMEWORKS="-framework Cocoa -framework WebKit -framework Foundation -framework AppKit \
  -framework QuartzCore -framework CoreText -framework MapKit -framework CoreLocation \
  -framework SceneKit -framework UniformTypeIdentifiers"

HBLIBS="$(hblib hbcommon) $VMLIB $(hblib hbrtl) $(hblib hbrdd) $(hblib hbmacro) \
  $(hblib hblang) $(hblib hbcpage) $(hblib hbpp) $(hblib hbcplr) \
  $(hblib rddntx) $(hblib rddnsx) $(hblib rddcdx) $(hblib rddfpt) \
  $(hblib hbsix) $(hblib hbusrrdd) $(hblib hbct) $(hblib hbextern) \
  $(hblib hbsqlit3) $(hblib gtcgi) $(hblib gttrm) $(hblib gtstd) $(hblib gtnul) \
  $(hblib hbdebug) $(hblib hbpcre) $(hblib hbzlib) $(hblib hbhsx) $(hblib hbuddall)"

# OpenADS / rddads (optional). erp_db REQUESTs ADS+ADSCDX and calls Ads*.
# If librddads is missing, provide stubs so json/dbfcdx still link.
if [ -f "$HBLIB/librddads.a" ] || [ -f "$HBLIB/rddads.a" ]; then
  HBLIBS="$HBLIBS -lrddads"
  echo "OpenADS: linking librddads"
else
  echo "WARNING: librddads not found — openads driver stubbed (json/dbfcdx OK)"
  cat > ads_stubs.c <<'STUBS'
#include "hbapi.h"
/* Minimal stubs when rddads is not built into this Harbour install */
HB_FUNC( ADS ) {}
HB_FUNC( ADSCDX ) {}
HB_FUNC( ADSSETFILETYPE ) {}
HB_FUNC( ADSCONNECT60 ) { hb_retl( 0 ); }
STUBS
  clang $CFLAGS -c ads_stubs.c -o ads_stubs.o
  OBJS="$OBJS ads_stubs.o"
fi

echo "[3] link"
echo "HBLIBS=$HBLIBS"
clang $OBJS -O2 -mmacosx-version-min=$MACOSX_MIN $ARCH_FLAG -o "$OUT" \
  -L"$HBLIB" \
  $HBLIBS \
  $FRAMEWORKS -lpthread -lsqlite3 -lm -fobjc-arc

chmod +x "$OUT"

echo "[4] .app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$OUT" "$APP/Contents/MacOS/FiveTech_ERP"
cp -R "$PROJDIR/www"  "$APP/Contents/MacOS/www"
cp -R "$PROJDIR/meta" "$APP/Contents/MacOS/meta"
cp -R "$PROJDIR/meta" "$APP/Contents/Resources/meta" 2>/dev/null || true
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>FiveTech_ERP</string>
  <key>CFBundleDisplayName</key><string>FiveTech ERP</string>
  <key>CFBundleIdentifier</key><string>com.fivetech.fivetech-erp</string>
  <key>CFBundleVersion</key><string>1.0.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>FiveTech_ERP</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSArchitecturePriority</key>
  <array>
    <string>${ARCH}</string>
  </array>
</dict>
</plist>
PLIST

file "$OUT"
lipo -archs "$OUT" 2>/dev/null || true
echo
echo "=== BUILD OK ($ARCH) ==="
echo "Binary: $OUT"
echo "App:    $APP"
echo "Build:  $BUILDDIR"
echo "Run:    open \"$APP\""
echo "Login:  admin/1234  or  demo/demo"
