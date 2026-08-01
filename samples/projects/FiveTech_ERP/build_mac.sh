#!/bin/bash
# FiveTech_ERP — macOS (same PRG set as Windows/Linux)
# Units: Project1.prg Form1.prg erp_meta.prg erp_http.prg + classes.prg
# Backend: Cocoa + WKWebView
set -e

PROJDIR="$(cd "$(dirname "$0")" && pwd)"
HBROOT="$(cd "$PROJDIR/../../.." && pwd)"
export HBROOT
HBDIR="${HBDIR:-$HOME/harbour}"
BUILDDIR="$PROJDIR/_build_mac"
OUT="$PROJDIR/FiveTech_ERP"
APP="$PROJDIR/FiveTech_ERP.app"

if [ -f "$HBDIR/bin/darwin/clang/harbour" ]; then
  HBBIN="$HBDIR/bin/darwin/clang"
  HBLIB="$HBDIR/lib/darwin/clang"
elif [ -f "$HBDIR/bin/harbour" ]; then
  HBBIN="$HBDIR/bin"
  HBLIB="$HBDIR/lib"
else
  echo "ERROR: Harbour not found at $HBDIR"
  exit 1
fi
HBINC="$HBDIR/include"

echo "=== FiveTech_ERP macOS (same PRGs as Win/Linux) ==="
echo "HBROOT=$HBROOT  HBDIR=$HBDIR"

rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

cp -f "$HBROOT/include/hbbuilder.ch" . 2>/dev/null || true
cp -f "$HBROOT/include/hbide.ch" . 2>/dev/null || true
cp -f "$HBROOT/source/core/classes.prg" .

bash "$PROJDIR/assemble_main.sh" "$PROJDIR" "$BUILDDIR"

echo "[1] Harbour compile (main + erp_meta + erp_http + classes)"
"$HBBIN/harbour" main.prg     -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -omain.c
"$HBBIN/harbour" erp_meta.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_meta.c
"$HBBIN/harbour" erp_http.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_http.c
"$HBBIN/harbour" classes.prg  -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oclasses.c

echo "[2] clang"
CFLAGS="-O2 -Wno-unused-value -Wno-deprecated-declarations -mmacosx-version-min=10.15 -I$HBINC -I$HBROOT/include -I$BUILDDIR"
OBJCFLAGS="$CFLAGS -fobjc-arc"
FRAMEWORKS="-framework Cocoa -framework WebKit -framework Foundation -framework AppKit"

clang $CFLAGS -c main.c -o main.o
clang $CFLAGS -c erp_meta.c -o erp_meta.o
clang $CFLAGS -c erp_http.c -o erp_http.o
clang $CFLAGS -c classes.c -o classes.o
# cocoa_core.m requires ARC (same as root build_mac.sh)
clang $OBJCFLAGS -c "$HBROOT/source/backends/cocoa/cocoa_core.m" -o cocoa_core.o
[ -f "$HBROOT/source/backends/cocoa/cocoa_webserver.m" ] && \
  clang $OBJCFLAGS -c "$HBROOT/source/backends/cocoa/cocoa_webserver.m" -o cocoa_webserver.o || true

VMLIB="-lhbvm"
[ -f "$HBLIB/libhbvmmt.a" ] && VMLIB="-lhbvmmt"

OBJS="main.o erp_meta.o erp_http.o classes.o cocoa_core.o"
[ -f cocoa_webserver.o ] && OBJS="$OBJS cocoa_webserver.o"

echo "[3] link"
clang $OBJS -O2 -mmacosx-version-min=10.15 -o "$OUT" \
  -L"$HBLIB" \
  -lhbcommon $VMLIB -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
  -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
  -lhbdebug -lhbpcre -lhbzlib \
  $FRAMEWORKS -lpthread -fobjc-arc

chmod +x "$OUT"

echo "[4] .app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$OUT" "$APP/Contents/MacOS/FiveTech_ERP"
cp -R "$PROJDIR/www"  "$APP/Contents/MacOS/www"
cp -R "$PROJDIR/meta" "$APP/Contents/MacOS/meta"
cp -R "$PROJDIR/meta" "$APP/Contents/Resources/meta" 2>/dev/null || true
cat > "$APP/Contents/Info.plist" <<'PLIST'
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
</dict>
</plist>
PLIST

file "$OUT"
echo
echo "=== BUILD OK ==="
echo "Binary: $OUT"
echo "App:    $APP"
echo "PRGs:   Project1 Form1 erp_meta erp_http (identical to Windows/Linux)"
echo "Run:    open \"$APP\""
echo "Login:  admin/1234  or  demo/demo"
