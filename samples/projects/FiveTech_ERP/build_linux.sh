#!/bin/bash
# FiveTech_ERP — Linux (same PRG set as Windows/macOS)
# Units: Project1.prg Form1.prg erp_meta.prg erp_http.prg erp_db.prg erp_proc.prg + classes.prg
# Backend: GTK3 + WebKit
set -e

PROJDIR="$(cd "$(dirname "$0")" && pwd)"
HBROOT="$(cd "$PROJDIR/../../.." && pwd)"
export HBROOT
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

echo "=== FiveTech_ERP Linux (same PRGs as Win/macOS) ==="
echo "HBROOT=$HBROOT  HBDIR=$HBDIR"

rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

cp -f "$HBROOT/include/hbbuilder.ch" . 2>/dev/null || true
cp -f "$HBROOT/include/hbide.ch" . 2>/dev/null || true
cp -f "$HBROOT/source/core/classes.prg" .

bash "$PROJDIR/assemble_main.sh" "$PROJDIR" "$BUILDDIR"

echo "[1] Harbour compile (main + erp_meta + erp_http + erp_db + erp_proc + classes)"
"$HBBIN/harbour" main.prg     -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -omain.c
"$HBBIN/harbour" erp_meta.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_meta.c
"$HBBIN/harbour" erp_http.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_http.c
if [ ! -f "$BUILDDIR/erp_db.prg" ]; then
  echo "ERROR: erp_db.prg missing in $BUILDDIR (assemble_main should copy it)"
  exit 1
fi
"$HBBIN/harbour" erp_db.prg   -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_db.c
"$HBBIN/harbour" erp_proc.prg -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oerp_proc.c
"$HBBIN/harbour" classes.prg  -n -w -q -I"$HBINC" -I"$BUILDDIR" -I"$HBROOT/include" -oclasses.c

echo "[2] gcc"
GTK_CFLAGS=$(pkg-config --cflags gtk+-3.0)
GTK_LIBS=$(pkg-config --libs gtk+-3.0)
# WebKitGTK if present (optional for TWebView)
if pkg-config --exists webkit2gtk-4.0 2>/dev/null; then
  GTK_CFLAGS="$GTK_CFLAGS $(pkg-config --cflags webkit2gtk-4.0) -DHAVE_WEBKIT2GTK"
  GTK_LIBS="$GTK_LIBS $(pkg-config --libs webkit2gtk-4.0)"
elif pkg-config --exists webkit2gtk-4.1 2>/dev/null; then
  GTK_CFLAGS="$GTK_CFLAGS $(pkg-config --cflags webkit2gtk-4.1) -DHAVE_WEBKIT2GTK"
  GTK_LIBS="$GTK_LIBS $(pkg-config --libs webkit2gtk-4.1)"
fi

CFLAGS="-O2 -Wno-unused-value $GTK_CFLAGS -I$HBINC -I$HBROOT/include -I$BUILDDIR"
gcc $CFLAGS -c main.c -o main.o
gcc $CFLAGS -c erp_meta.c -o erp_meta.o
gcc $CFLAGS -c erp_http.c -o erp_http.o
gcc $CFLAGS -c erp_db.c -o erp_db.o
gcc $CFLAGS -c erp_proc.c -o erp_proc.o
gcc $CFLAGS -c classes.c -o classes.o
gcc $CFLAGS -c "$HBROOT/source/backends/gtk3/gtk3_core.c" -o gtk3_core.o
gcc $CFLAGS -c "$PROJDIR/linux_stubs.c" -o linux_stubs.o

VMLIB="-lhbvm"
[ -f "$HBLIB/libhbvmmt.a" ] || [ -f "$HBLIB/hbvmmt.a" ] && VMLIB="-lhbvmmt"

OBJS="main.o erp_meta.o erp_http.o erp_db.o erp_proc.o classes.o gtk3_core.o linux_stubs.o"
ADSLIB=""
if [ -f "$HBLIB/librddads.a" ] || [ -f "$HBLIB/rddads.a" ]; then
  ADSLIB="-lrddads"
  echo "OpenADS: linking librddads"
else
  echo "WARNING: librddads not found — openads driver stubbed (json/dbfcdx OK)"
  cat > ads_stubs.c <<'STUBS'
#include "hbapi.h"
HB_FUNC( ADS ) {}
HB_FUNC( ADSCDX ) {}
HB_FUNC( ADSSETFILETYPE ) {}
HB_FUNC( ADSCONNECT60 ) { hb_retl( 0 ); }
STUBS
  gcc $CFLAGS -c ads_stubs.c -o ads_stubs.o
  OBJS="$OBJS ads_stubs.o"
fi

echo "[3] link"
gcc $OBJS -O2 -o "$OUT" \
  -L"$HBLIB" \
  -Wl,--start-group \
  -lhbcommon $VMLIB -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
  -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
  -lhbsqlit3 -lsqlite3 -lgttrm -lhbdebug -lhbpcre -lhbzlib $ADSLIB \
  $GTK_LIBS -lm -lpthread -ldl \
  -Wl,--end-group

chmod +x "$OUT"
file "$OUT"
echo
echo "=== BUILD OK ==="
echo "Binary: $OUT"
echo "PRGs:   Project1 Form1 erp_meta erp_http erp_db erp_proc (same set as Windows/macOS)"
echo "Run:    cd \"$PROJDIR\" && ./FiveTech_ERP"
echo "Login:  admin/1234  or  demo/demo"
