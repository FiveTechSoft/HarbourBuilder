#!/bin/bash
# build_linux.sh - Build HarbourBuilder IDE for Linux using Harbour + GTK3 + Scintilla
#
# Prerequisites:
#   sudo apt install libgtk-3-dev
#   Harbour compiler installed (default: ~/harbour)
#   Scintilla/Lexilla shared libs in resources/ (see build_scintilla.sh)
#
# Usage: ./build_linux.sh [program]
#   ./build_linux.sh                    - builds hbbuilder_linux (full IDE)
#   ./build_linux.sh test_design_gtk    - builds test_design_gtk (simple demo)

set -e

HBDIR="${HBDIR:-$HOME/harbour}"
PROJDIR="$(cd "$(dirname "$0")" && pwd)"
PROG="${1:-hbbuilder_linux}"
RESDIR="$PROJDIR/resources"

cd "$PROJDIR/source"

# Check Harbour is installed
if [ ! -d "$HBDIR/include" ]; then
   echo "ERROR: Harbour not found at $HBDIR"
   echo "Run HbBuilder and press F9 — it will download Harbour automatically."
   echo "Or install manually: git clone https://github.com/harbour/core /tmp/harbour-src"
   echo "  cd /tmp/harbour-src && HB_INSTALL_PREFIX=$HBDIR make install"
   exit 1
fi

# Detect Harbour directory layout (bin/linux/gcc/ vs bin/)
if [ -f "$HBDIR/bin/linux/gcc/harbour" ]; then
   HBBIN="$HBDIR/bin/linux/gcc"
   HBLIB="$HBDIR/lib/linux/gcc"
elif [ -f "$HBDIR/bin/harbour" ]; then
   HBBIN="$HBDIR/bin"
   HBLIB="$HBDIR/lib"
else
   echo "ERROR: Harbour compiler not found in $HBDIR"
   echo "  Run the IDE first - it will auto-download and build Harbour."
   exit 1
fi
HBINC="$HBDIR/include"

echo "Using Harbour: $HBDIR"
echo "Building: $PROG"
echo ""

# Helper: rebuild if any source content changed (sha1-based, mtime-proof).
# Survives git pulls preserving mtime, manual .o copies, clock skew.
# Usage: needs_rebuild <obj> <src1> [<src2> ...]
# Sidecar <obj>.sha stores combined hash of all sources used to build <obj>.
needs_rebuild() {
   local obj="$1"; shift
   local stamp="${obj}.sha"
   [ ! -f "$obj" ] && { sha1sum "$@" | sha1sum | awk '{print $1}' > "$stamp"; return 0; }
   local cur
   cur="$(sha1sum "$@" | sha1sum | awk '{print $1}')"
   if [ ! -f "$stamp" ] || [ "$cur" != "$(cat "$stamp")" ]; then
      echo "$cur" > "$stamp"
      return 0
   fi
   return 1
}

NEED_LINK=0

# === Step 0: Build Scintilla/Lexilla .so if not present ===
if [ ! -f "$RESDIR/libscintilla.so" ] || [ ! -f "$RESDIR/liblexilla.so" ]; then
   echo "[0/6] Building Scintilla + Lexilla shared libraries..."
   if [ -f "$PROJDIR/build_scintilla.sh" ]; then
      bash "$PROJDIR/build_scintilla.sh"
   else
      echo "WARNING: libscintilla.so / liblexilla.so not found in resources/"
      echo "  The code editor will fall back to system libraries or fail."
      echo "  Run build_scintilla.sh to build from source, or install system packages."
   fi
fi

# [1/6] Harbour -> C (only if .prg changed)
if needs_rebuild "${PROG}.c" \
      "${PROG}.prg" \
      "$PROJDIR/source/core/classes.prg" \
      "$PROJDIR/source/inspector/inspector_gtk.prg" \
      "$PROJDIR/source/hbbuilder_common.prg" \
      "$PROJDIR/include/hbbuilder.ch" \
      "$PROJDIR/include/hbide.ch"; then
   echo "[1/6] Compiling ${PROG}.prg..."
   "$HBBIN/harbour" hbbuilder_common.prg ${PROG}.prg -n -w -q \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      -I"$PROJDIR/source" \
      -o${PROG}.c
   NEED_LINK=1
else
   echo "[1/6] ${PROG}.prg — up to date"
fi

# [2/6] C -> Object (only if .c changed)
if needs_rebuild "${PROG}.o" "${PROG}.c"; then
   echo "[2/6] Compiling ${PROG}.c..."
   gcc -c -g -Wno-unused-value \
      -I"$HBINC" \
      $(pkg-config --cflags gtk+-3.0) \
      ${PROG}.c -o ${PROG}.o
   NEED_LINK=1
else
   echo "[2/6] ${PROG}.o — up to date"
fi

# Detect WebKit2GTK (try 4.1 first, then 4.0)
WEBKIT_CFLAGS=""
WEBKIT_LIBS=""
WEBKIT_DEFINE=""
if pkg-config --exists webkit2gtk-4.1 2>/dev/null; then
   WEBKIT_CFLAGS="$(pkg-config --cflags webkit2gtk-4.1)"
   WEBKIT_LIBS="$(pkg-config --libs webkit2gtk-4.1)"
   WEBKIT_DEFINE="-DHAVE_WEBKIT2GTK"
   echo "  WebKit2GTK 4.1 detected — WebView enabled"
elif pkg-config --exists webkit2gtk-4.0 2>/dev/null; then
   WEBKIT_CFLAGS="$(pkg-config --cflags webkit2gtk-4.0)"
   WEBKIT_LIBS="$(pkg-config --libs webkit2gtk-4.0)"
   WEBKIT_DEFINE="-DHAVE_WEBKIT2GTK"
   echo "  WebKit2GTK 4.0 detected — WebView enabled"
else
   echo "  WebKit2GTK not found — WebView will show placeholder"
   echo "  Install with: sudo apt install libwebkit2gtk-4.1-dev"
fi

# [3/6] GTK3 core (only if .c changed)
if needs_rebuild gtk3_core.o "$PROJDIR/source/backends/gtk3/gtk3_core.c"; then
   echo "[3/6] Compiling GTK3 core..."
   gcc -c -g \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      $(pkg-config --cflags gtk+-3.0) \
      $WEBKIT_CFLAGS $WEBKIT_DEFINE \
      "$PROJDIR/source/backends/gtk3/gtk3_core.c" -o gtk3_core.o
   NEED_LINK=1
else
   echo "[3/6] gtk3_core.o — up to date"
fi

# [4/6] GTK3 inspector (only if .c changed)
if needs_rebuild gtk3_inspector.o "$PROJDIR/source/backends/gtk3/gtk3_inspector.c"; then
   echo "[4/6] Compiling GTK3 inspector..."
   gcc -c -g \
      -I"$HBINC" \
      $(pkg-config --cflags gtk+-3.0) \
      "$PROJDIR/source/backends/gtk3/gtk3_inspector.c" -o gtk3_inspector.o
   NEED_LINK=1
else
   echo "[4/6] gtk3_inspector.o — up to date"
fi

# [4b/6] DB bindings via runtime dlopen — no -dev headers needed at build
# time. Mirrors Win hb_db_real.cpp pattern. libmysqlclient.so / libpq.so
# resolved at launch; missing libs return safe defaults.
rm -f hbmysql.o hbpgsql.o hbdb_stub.o
if needs_rebuild hbdb_real.o "$PROJDIR/source/backends/gtk3/gtk3_db_real.c"; then
   echo "[4b] Compiling DB bindings (dlopen-based)..."
   gcc -c -O2 -I"$HBINC" \
      "$PROJDIR/source/backends/gtk3/gtk3_db_real.c" -o hbdb_real.o
   NEED_LINK=1
fi

# Skip link if nothing changed
if [ "$NEED_LINK" -eq 0 ] && [ -f "${PROG}" ]; then
   echo "[5/6] ${PROG} — up to date (nothing changed)"
   echo ""
   echo "-- ${PROG} is up to date (incremental build) --"
   echo "Run with: cd $PROJDIR/bin && LD_LIBRARY_PATH=. ./${PROG}"
   exit 0
fi

# [5/6] Link
echo "[5/6] Linking ${PROG}..."
EXTRA_OBJS=""
[ -f hbdb_real.o ] && EXTRA_OBJS="$EXTRA_OBJS hbdb_real.o"

gcc ${PROG}.o gtk3_core.o gtk3_inspector.o $EXTRA_OBJS -g -o ${PROG} \
   -L"$HBLIB" \
   -Wl,--start-group \
   -lhbcommon -lhbvm -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
   -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
   -lhbsqlit3 -lsddsqlt3 -lrddsql \
   -lgttrm -lhbdebug -lhbpcre \
   $(pkg-config --libs gtk+-3.0) \
   $WEBKIT_LIBS \
   -lm -lpthread -ldl -lrt -lsqlite3 \
   -L/usr/lib/x86_64-linux-gnu -l:libncurses.so.6 \
   -Wl,--end-group

# [6/6] Install to bin/
echo "[6/6] Installing to bin/..."
BINDIR="$PROJDIR/bin"
mkdir -p "$BINDIR"
cp -f "${PROG}" "$BINDIR/"
if [ -f "$RESDIR/libscintilla.so" ]; then
   cp -u "$RESDIR/libscintilla.so" "$BINDIR/"
   cp -u "$RESDIR/liblexilla.so" "$BINDIR/"
   echo "  Copied libscintilla.so + liblexilla.so to bin/"
fi

echo ""
echo "-- ${PROG} built successfully --"
echo "Run with: cd $BINDIR && LD_LIBRARY_PATH=. ./${PROG}"
