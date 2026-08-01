#!/bin/bash
# FiveTech_ERP — Linux (Harbour + GTK3 + native WebView backend)
# Run on a Linux machine with: harbour, libgtk-3-dev, pkg-config
set -e

PROJDIR="$(cd "$(dirname "$0")" && pwd)"
HBROOT="$(cd "$PROJDIR/../../.." && pwd)"
HBDIR="${HBDIR:-$HOME/harbour}"
BUILDDIR="$PROJDIR/_build_linux"
OUT="$PROJDIR/FiveTech_ERP"

if [ -f "$HBDIR/bin/linux/gcc/harbour" ]; then
  HBBIN="$HBDIR/bin/linux/gcc"
  HBLIB="$HBDIR/lib/linux/gcc"
elif [ -f "$HBDIR/bin/harbour" ]; then
  HBBIN="$HBDIR/bin"
  HBLIB="$HBDIR/lib"
else
  echo "ERROR: Harbour not found at $HBDIR"
  exit 1
fi
HBINC="$HBDIR/include"

echo "=== FiveTech_ERP Linux build ==="
echo "HBROOT=$HBROOT  HBDIR=$HBDIR"

rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

cp -f "$HBROOT/source/core/classes.prg" .
cp -f "$HBROOT/include/hbbuilder.ch" . 2>/dev/null || true
cp -f "$HBROOT/include/hbide.ch" . 2>/dev/null || true

# Assemble main.prg
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

GTK_CFLAGS=$(pkg-config --cflags gtk+-3.0)
GTK_LIBS=$(pkg-config --libs gtk+-3.0)

gcc -c -O2 -Wno-unused-value $GTK_CFLAGS -I"$HBINC" -I"$HBROOT/include" main.c -o main.o
gcc -c -O2 -Wno-unused-value $GTK_CFLAGS -I"$HBINC" -I"$HBROOT/include" classes.c -o classes.o
gcc -c -O2 $GTK_CFLAGS -I"$HBINC" -I"$HBROOT/include" \
  "$HBROOT/source/backends/gtk3/gtk3_core.c" -o gtk3_core.o

# Prefer multi-thread VM if present
VMLIB="-lhbvm"
[ -f "$HBLIB/libhbvmmt.a" ] || [ -f "$HBLIB/hbvmmt.a" ] && VMLIB="-lhbvmmt"

gcc main.o classes.o gtk3_core.o -O2 -o "$OUT" \
  -L"$HBLIB" \
  -Wl,--start-group \
  -lhbcommon $VMLIB -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
  -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
  -lhbsqlit3 -lgttrm -lhbdebug -lhbpcre -lhbzlib \
  $GTK_LIBS -lm -lpthread -ldl \
  -Wl,--end-group

chmod +x "$OUT"
echo "=== BUILD OK ==="
echo "Output: $OUT"
echo "Run: $OUT"
echo "Ensure www/ and meta_fwh/ (or meta/) sit next to the binary or cwd."
