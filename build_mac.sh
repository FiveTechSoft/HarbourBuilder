#!/bin/bash
# build_mac.sh - Build HbBuilder MacOS using Harbour + Cocoa + Scintilla
#
# Usage: ./build_mac.sh

set -e

HBDIR="${HBDIR:-$HOME/harbour}"
PROJDIR="$(cd "$(dirname "$0")" && pwd)"
SRC="hbbuilder_macos"
PROG="HbBuilder"

# Detect macOS version for API compatibility
MACOS_VER=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
echo "Detected macOS $MACOS_VER"

cd "$PROJDIR/source"

# Check Harbour is installed
if [ ! -d "$HBDIR/include" ]; then
   echo "ERROR: Harbour not found at $HBDIR"
   echo "Run HbBuilder and press F9 — it will download Harbour automatically."
   echo "Or install manually: git clone https://github.com/harbour/core /tmp/harbour-src"
   echo "  cd /tmp/harbour-src && HB_INSTALL_PREFIX=$HBDIR make install"
   exit 1
fi

# Detect Harbour directory layout (bin/darwin/clang/ vs bin/)
if [ -f "$HBDIR/bin/darwin/clang/harbour" ]; then
   HBBIN="$HBDIR/bin/darwin/clang"
   HBLIB="$HBDIR/lib/darwin/clang"
elif [ -f "$HBDIR/bin/harbour" ]; then
   HBBIN="$HBDIR/bin"
   HBLIB="$HBDIR/lib"
else
   echo "ERROR: harbour binary not found in $HBDIR/bin"
   exit 1
fi
HBINC="$HBDIR/include"

# Scintilla paths
SCIDIR="$PROJDIR/resources/scintilla_src"
SCIBUILD="$SCIDIR/build"
SCIINC="$SCIDIR/scintilla/include"
SCICOCOA="$SCIDIR/scintilla/cocoa"
LEXINC="$SCIDIR/lexilla/include"

# Download Scintilla + Lexilla source if not present
if [ ! -f "$SCICOCOA/ScintillaView.h" ]; then
   echo "[0/4] Downloading Scintilla + Lexilla source..."
   mkdir -p "$SCIDIR"
   curl -L -o "$SCIDIR/scintilla556.tgz" https://www.scintilla.org/scintilla556.tgz
   curl -L -o "$SCIDIR/lexilla520.tgz" https://www.scintilla.org/lexilla520.tgz
   tar xzf "$SCIDIR/scintilla556.tgz" -C "$SCIDIR"
   tar xzf "$SCIDIR/lexilla520.tgz" -C "$SCIDIR"
   rm -f "$SCIDIR/scintilla556.tgz" "$SCIDIR/lexilla520.tgz"
fi

# Build Scintilla static libraries if not present — or if architecture mismatch
HOST_ARCH=$(uname -m)   # arm64 or x86_64
SCI_ARCH_OK=1
if [ ! -f "$SCIBUILD/libscintilla.a" ] || [ ! -f "$SCIBUILD/liblexilla.a" ]; then
   SCI_ARCH_OK=0
else
   # Verify cached libs match host architecture (prevents silent link failures
   # when switching between Intel and Apple Silicon, or using stale libs)
   for lib in libscintilla.a liblexilla.a; do
      LIB_ARCH=$(lipo -archs "$SCIBUILD/$lib" 2>/dev/null || echo "unknown")
      if ! echo "$LIB_ARCH" | grep -qw "$HOST_ARCH"; then
         echo "[0/4] $lib is '$LIB_ARCH' but host is '$HOST_ARCH' — will rebuild"
         SCI_ARCH_OK=0
         break
      fi
   done
fi
if [ "$SCI_ARCH_OK" -eq 0 ]; then
   echo "[0/4] Building Scintilla + Lexilla static libraries..."
   rm -rf "$SCIBUILD"
   bash "$SCIDIR/build_scintilla_mac.sh"
fi

# Helper: compile only if source is newer than object
needs_rebuild() {
   [ ! -f "$2" ] && return 0
   [ "$1" -nt "$2" ] && return 0
   return 1
}

NEED_LINK=0

# [1/4] Harbour → C (only if .prg changed)
if needs_rebuild "${SRC}.prg" "${SRC}.c" || \
   needs_rebuild "$PROJDIR/source/core/classes.prg" "${SRC}.c" || \
   needs_rebuild "$PROJDIR/include/hbbuilder.ch" "${SRC}.c"; then
   echo "[1/4] Compiling ${SRC}.prg..."
   "$HBBIN/harbour" ${SRC}.prg -n -w -q \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      -I"$PROJDIR/source/core" \
      -I"$PROJDIR/source/inspector" \
      -o${SRC}.c
   NEED_LINK=1
else
   echo "[1/4] ${SRC}.prg — up to date"
fi

# [2/4] C → Object (only if .c changed)
if needs_rebuild "${SRC}.c" "${SRC}.o"; then
   echo "[2/4] Compiling ${SRC}.c..."
   clang -c -O2 -mmacosx-version-min=10.15 -Wno-unused-value \
      -I"$HBINC" \
      ${SRC}.c -o ${SRC}.o
   NEED_LINK=1
else
   echo "[2/4] ${SRC}.o — up to date"
fi

# [2b/4] hix_runtime.prg → C → Object
if needs_rebuild "$PROJDIR/source/hix_runtime.prg" hix_runtime.c || \
   needs_rebuild "$PROJDIR/include/hbbuilder.ch" hix_runtime.c; then
   echo "[2b/4] Compiling hix_runtime.prg..."
   "$HBBIN/harbour" "$PROJDIR/source/hix_runtime.prg" -n -w -q \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      -ohix_runtime.c
   NEED_LINK=1
fi
if needs_rebuild hix_runtime.c hix_runtime.o; then
   clang -c -O2 -mmacosx-version-min=10.15 -Wno-unused-value \
      -I"$HBINC" \
      hix_runtime.c -o hix_runtime.o
   NEED_LINK=1
fi

# [2c/4] hix_template.prg → C → Object
if needs_rebuild "$PROJDIR/source/hix_template.prg" hix_template.c || \
   needs_rebuild "$PROJDIR/include/hbbuilder.ch" hix_template.c; then
   echo "[2c/4] Compiling hix_template.prg..."
   "$HBBIN/harbour" "$PROJDIR/source/hix_template.prg" -n -w -q \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      -ohix_template.c
   NEED_LINK=1
fi
if needs_rebuild hix_template.c hix_template.o; then
   clang -c -O2 -mmacosx-version-min=10.15 -Wno-unused-value \
      -I"$HBINC" \
      hix_template.c -o hix_template.o
   NEED_LINK=1
fi

# [3/4] Cocoa sources (only if .m changed)
if needs_rebuild "$PROJDIR/source/backends/cocoa/cocoa_core.m" cocoa_core.o; then
   echo "[3/4] Compiling cocoa_core.m..."
   clang -c -O2 -mmacosx-version-min=10.15 -fobjc-arc \
      -I"$HBINC" \
      "$PROJDIR/source/backends/cocoa/cocoa_core.m" -o cocoa_core.o
   NEED_LINK=1
else
   echo "[3/4] cocoa_core.o — up to date"
fi

if needs_rebuild "$PROJDIR/source/backends/cocoa/cocoa_inspector.m" cocoa_inspector.o; then
   echo "[3/4] Compiling cocoa_inspector.m..."
   clang -c -O2 -mmacosx-version-min=10.15 -fobjc-arc \
      -I"$HBINC" \
      "$PROJDIR/source/backends/cocoa/cocoa_inspector.m" -o cocoa_inspector.o
   NEED_LINK=1
else
   echo "[3/4] cocoa_inspector.o — up to date"
fi

if needs_rebuild "$PROJDIR/source/backends/cocoa/cocoa_webserver.m" cocoa_webserver.o; then
   echo "[3d/4] Compiling cocoa_webserver.m..."
   clang -c -O2 -mmacosx-version-min=10.15 -fobjc-arc \
      -I"$HBINC" \
      "$PROJDIR/source/backends/cocoa/cocoa_webserver.m" -o cocoa_webserver.o
   NEED_LINK=1
else
   echo "[3d/4] cocoa_webserver.o — up to date"
fi

# [3b/4] Scintilla editor (only if .mm changed)
if needs_rebuild "$PROJDIR/source/backends/cocoa/cocoa_editor.mm" cocoa_editor.o; then
   echo "[3b/4] Compiling cocoa_editor.mm..."
   clang++ -c -O2 -mmacosx-version-min=10.15 -fobjc-arc -std=c++17 \
      -I"$HBINC" \
      -I"$SCIINC" \
      -I"$SCICOCOA" \
      -I"$LEXINC" \
      -I"$SCIDIR/scintilla/src" \
      "$PROJDIR/source/backends/cocoa/cocoa_editor.mm" -o cocoa_editor.o
   NEED_LINK=1
else
   echo "[3b/4] cocoa_editor.o — up to date"
fi

# [3c/4] Standard dialog backends (TOpenDialog/TSaveDialog/TFontDialog/TColorDialog)
if needs_rebuild "$PROJDIR/resources/stddlgs_mac.mm" stddlgs_mac.o; then
   echo "[3c/4] Compiling stddlgs_mac.mm..."
   clang++ -c -O2 -mmacosx-version-min=10.15 -fobjc-arc \
      -I"$HBINC" \
      "$PROJDIR/resources/stddlgs_mac.mm" -o stddlgs_mac.o
   NEED_LINK=1
else
   echo "[3c/4] stddlgs_mac.o — up to date"
fi

if [ "$NEED_LINK" -eq 0 ] && [ -f "${PROG}" ]; then
   echo "[4/4] ${PROG} — up to date (nothing changed)"
   # Still create .app bundle if missing
   if [ -d "$PROJDIR/bin/${PROG}.app" ]; then
      echo ""
      echo "-- ${PROG} is up to date (incremental build) --"
      echo "Run with: open $PROJDIR/bin/${PROG}.app"
      exit 0
   fi
fi

echo "[4/4] Linking ${PROG}..."
clang++ -o ${PROG} \
   ${SRC}.o cocoa_core.o cocoa_inspector.o cocoa_webserver.o cocoa_editor.o stddlgs_mac.o \
   hix_runtime.o hix_template.o \
   -L"$HBLIB" \
   -L"$SCIBUILD" \
   -lscintilla -llexilla \
   -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang \
   -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug \
   -lhbct -lhbextern -lhbsqlit3 \
   -lrddntx -lrddnsx -lrddcdx -lrddfpt \
   -lhbhsx -lhbsix -lhbusrrdd \
   -lgtcgi -lgttrm -lgtstd \
   -framework Cocoa \
   -framework QuartzCore \
   -framework CoreText \
   -framework MapKit \
   -framework CoreLocation \
   -framework SceneKit \
   -framework WebKit \
   $([ "$MACOS_MAJOR" -ge 11 ] 2>/dev/null && echo "-framework UniformTypeIdentifiers" || echo "") \
   -lm -lpthread -lsqlite3 -lcups

# [5/5] Create .app bundle
APP="$PROJDIR/bin/${PROG}.app"
echo "[5/5] Creating ${PROG}.app bundle..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "${PROG}" "$APP/Contents/MacOS/${PROG}"
cp "$PROJDIR/resources/HbBuilder.icns" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/resources/toolbar.bmp" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/resources/toolbar_debug.bmp" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/resources/palette.bmp" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/resources/harbour_logo.png" "$APP/Contents/Resources/" 2>/dev/null
cp -R "$PROJDIR/resources/menu_icons" "$APP/Contents/Resources/" 2>/dev/null
# Copy Harbour source files needed for building user projects
cp "$PROJDIR/source/core/classes.prg" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/include/hbbuilder.ch" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/include/hbide.ch" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/resources/stddlgs_mac.mm" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/source/debugger/dbgclient.prg" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/source/debugger/dbghook.c" "$APP/Contents/Resources/" 2>/dev/null
# Copy backends for user project compilation
mkdir -p "$APP/Contents/Resources/backends/cocoa"
cp "$PROJDIR/source/backends/cocoa/cocoa_core.m" "$APP/Contents/Resources/backends/cocoa/" 2>/dev/null
cp "$PROJDIR/source/backends/cocoa/cocoa_editor.mm" "$APP/Contents/Resources/backends/cocoa/" 2>/dev/null
cp "$PROJDIR/source/backends/cocoa/cocoa_inspector.m" "$APP/Contents/Resources/backends/cocoa/" 2>/dev/null
cp "$PROJDIR/source/backends/cocoa/cocoa_webserver.m" "$APP/Contents/Resources/backends/cocoa/" 2>/dev/null
cp "$PROJDIR/source/hix_runtime.prg" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/source/hix_template.prg" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/source/backends/cocoa/gt_dummy.c" "$APP/Contents/Resources/backends/cocoa/" 2>/dev/null
# iOS backend
if [ -d "$PROJDIR/source/backends/ios" ]; then
   mkdir -p "$APP/Contents/Resources/backends/ios"
   cp -r "$PROJDIR/source/backends/ios/"* "$APP/Contents/Resources/backends/ios/" 2>/dev/null
fi
# Copy Scintilla includes and libs for user project compilation
mkdir -p "$APP/Contents/Resources/scintilla/include"
mkdir -p "$APP/Contents/Resources/scintilla/cocoa"
mkdir -p "$APP/Contents/Resources/scintilla/lexilla"
mkdir -p "$APP/Contents/Resources/scintilla/build"
cp "$SCIINC"/*.h "$APP/Contents/Resources/scintilla/include/" 2>/dev/null
cp "$SCICOCOA"/*.h "$APP/Contents/Resources/scintilla/cocoa/" 2>/dev/null
cp "$LEXINC"/*.h "$APP/Contents/Resources/scintilla/lexilla/" 2>/dev/null
cp "$SCIBUILD"/lib*.a "$APP/Contents/Resources/scintilla/build/" 2>/dev/null
# Info.plist
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>HbBuilder</string>
	<key>CFBundleDisplayName</key>
	<string>HbBuilder</string>
	<key>CFBundleIdentifier</key>
	<string>com.fivetechsoft.hbbuilder</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleExecutable</key>
	<string>HbBuilder</string>
	<key>CFBundleIconFile</key>
	<string>HbBuilder</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>10.15</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026 FiveTech Software. MIT License.</string>
</dict>
</plist>
PLIST
# Also copy raw binary to bin/
cp "${PROG}" "$PROJDIR/bin/${PROG}"

echo ""
echo "-- ${PROG} built successfully (with Scintilla editor) --"
echo "Run with: open $APP"
echo "   or:    ./${PROG}"
