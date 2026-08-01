#!/bin/bash
# FiveTech_ERP — macOS (Harbour + Cocoa + WebView backend)
# Run on a Mac with: Harbour (darwin/clang), Xcode CLI tools
set -e

PROJDIR="$(cd "$(dirname "$0")" && pwd)"
HBROOT="$(cd "$PROJDIR/../../.." && pwd)"
HBDIR="${HBDIR:-$HOME/harbour}"
BUILDDIR="$PROJDIR/_build_mac"
OUT="$PROJDIR/FiveTech_ERP"

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

echo "=== FiveTech_ERP macOS build ==="
echo "HBROOT=$HBROOT  HBDIR=$HBDIR"

rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

cp -f "$HBROOT/source/core/classes.prg" .
cp -f "$HBROOT/include/hbbuilder.ch" . 2>/dev/null || true
cp -f "$HBROOT/include/hbide.ch" . 2>/dev/null || true

{
  echo '#include "hbbuilder.ch"'
  echo 'REQUEST HB_GT_GUI_DEFAULT'
  echo 'REQUEST HB_CODEPAGE_UTF8EX'
  for f in Project1.prg Form1.prg erp_meta.prg erp_http.prg; do
    sed -e 's/#include *"hbbuilder.ch"//' -e 's/#include *"classes.prg"//' "$PROJDIR/$f"
    echo
  done
} > main.prg

"$HBBIN/harbour" main.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -omain.c
"$HBBIN/harbour" classes.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oclasses.c

CFLAGS="-O2 -Wno-unused-value -I$HBINC -I$HBROOT/include"
FRAMEWORKS="-framework Cocoa -framework WebKit -framework Foundation -framework AppKit"

clang $CFLAGS -c main.c -o main.o
clang $CFLAGS -c classes.c -o classes.o
clang $CFLAGS -c "$HBROOT/source/backends/cocoa/cocoa_core.m" -o cocoa_core.o
# Optional pieces if present
[ -f "$HBROOT/source/backends/cocoa/cocoa_webserver.m" ] && \
  clang $CFLAGS -c "$HBROOT/source/backends/cocoa/cocoa_webserver.m" -o cocoa_webserver.o || true

VMLIB="-lhbvm"
[ -f "$HBLIB/libhbvmmt.a" ] && VMLIB="-lhbvmmt"

OBJS="main.o classes.o cocoa_core.o"
[ -f cocoa_webserver.o ] && OBJS="$OBJS cocoa_webserver.o"

clang $OBJS -O2 -o "$OUT" \
  -L"$HBLIB" \
  -lhbcommon $VMLIB -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
  -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
  -lhbdebug -lhbpcre -lhbzlib \
  $FRAMEWORKS -lpthread

chmod +x "$OUT"
echo "=== BUILD OK ==="
echo "Output: $OUT"
echo "Run: $OUT"
