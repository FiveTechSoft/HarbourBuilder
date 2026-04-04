#!/bin/bash
# build_mac.sh - Build HbBuilder MacOS using Harbour + Cocoa + Scintilla
#
# Usage: ./build_mac.sh

set -e

HBDIR="/Users/usuario/harbour"
HBBIN="$HBDIR/bin/darwin/clang"
HBINC="$HBDIR/include"
HBLIB="$HBDIR/lib/darwin/clang"
PROJDIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="hbbuilder_macos"
PROG="HbBuilder"

# Scintilla paths
SCIDIR="$PROJDIR/resources/scintilla_src"
SCIBUILD="$SCIDIR/build"
SCIINC="$SCIDIR/scintilla/include"
SCICOCOA="$SCIDIR/scintilla/cocoa"
LEXINC="$SCIDIR/lexilla/include"

cd "$(dirname "$0")"

# Build Scintilla static libraries if not present
if [ ! -f "$SCIBUILD/libscintilla.a" ] || [ ! -f "$SCIBUILD/liblexilla.a" ]; then
   echo "[0/4] Building Scintilla + Lexilla static libraries..."
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
   needs_rebuild "$PROJDIR/harbour/classes.prg" "${SRC}.c" || \
   needs_rebuild "$PROJDIR/harbour/hbbuilder.ch" "${SRC}.c"; then
   echo "[1/4] Compiling ${SRC}.prg..."
   "$HBBIN/harbour" ${SRC}.prg -n -w -q \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      -I"$PROJDIR/harbour" \
      -o${SRC}.c
   NEED_LINK=1
else
   echo "[1/4] ${SRC}.prg — up to date"
fi

# [2/4] C → Object (only if .c changed)
if needs_rebuild "${SRC}.c" "${SRC}.o"; then
   echo "[2/4] Compiling ${SRC}.c..."
   clang -c -O2 -Wno-unused-value \
      -I"$HBINC" \
      ${SRC}.c -o ${SRC}.o
   NEED_LINK=1
else
   echo "[2/4] ${SRC}.o — up to date"
fi

# [3/4] Cocoa sources (only if .m changed)
if needs_rebuild "$PROJDIR/backends/cocoa/cocoa_core.m" cocoa_core.o; then
   echo "[3/4] Compiling cocoa_core.m..."
   clang -c -O2 -fobjc-arc \
      -I"$HBINC" \
      "$PROJDIR/backends/cocoa/cocoa_core.m" -o cocoa_core.o
   NEED_LINK=1
else
   echo "[3/4] cocoa_core.o — up to date"
fi

if needs_rebuild "$PROJDIR/backends/cocoa/cocoa_inspector.m" cocoa_inspector.o; then
   echo "[3/4] Compiling cocoa_inspector.m..."
   clang -c -O2 -fobjc-arc \
      -I"$HBINC" \
      "$PROJDIR/backends/cocoa/cocoa_inspector.m" -o cocoa_inspector.o
   NEED_LINK=1
else
   echo "[3/4] cocoa_inspector.o — up to date"
fi

# [3b/4] Scintilla editor (only if .mm changed)
if needs_rebuild "$PROJDIR/backends/cocoa/cocoa_editor.mm" cocoa_editor.o; then
   echo "[3b/4] Compiling cocoa_editor.mm..."
   clang++ -c -O2 -fobjc-arc -std=c++17 \
      -I"$HBINC" \
      -I"$SCIINC" \
      -I"$SCICOCOA" \
      -I"$LEXINC" \
      -I"$SCIDIR/scintilla/src" \
      "$PROJDIR/backends/cocoa/cocoa_editor.mm" -o cocoa_editor.o
   NEED_LINK=1
else
   echo "[3b/4] cocoa_editor.o — up to date"
fi

if [ "$NEED_LINK" -eq 0 ] && [ -f "${PROG}" ]; then
   echo "[4/4] ${PROG} — up to date (nothing changed)"
   echo ""
   echo "-- ${PROG} is up to date (incremental build) --"
   echo "Run with: ./${PROG}"
   exit 0
fi

echo "[4/4] Linking ${PROG}..."
clang++ -o ${PROG} \
   ${SRC}.o cocoa_core.o cocoa_inspector.o cocoa_editor.o \
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
   -framework UniformTypeIdentifiers \
   -lm -lpthread -lc++ -lsqlite3

echo ""
echo "-- ${PROG} built successfully (with Scintilla editor) --"
echo "Run with: ./${PROG}"
