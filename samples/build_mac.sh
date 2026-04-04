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

echo "[1/4] Compiling ${SRC}.prg..."
"$HBBIN/harbour" ${SRC}.prg -n -w -q \
   -I"$HBINC" \
   -I"$PROJDIR/include" \
   -I"$PROJDIR/harbour" \
   -o${SRC}.c

echo "[2/4] Compiling ${SRC}.c..."
clang -c -O2 -Wno-unused-value \
   -I"$HBINC" \
   ${SRC}.c -o ${SRC}.o

echo "[3/4] Compiling Cocoa sources..."
clang -c -O2 -fobjc-arc \
   -I"$HBINC" \
   "$PROJDIR/backends/cocoa/cocoa_core.m" -o cocoa_core.o

clang -c -O2 -fobjc-arc \
   -I"$HBINC" \
   "$PROJDIR/backends/cocoa/cocoa_inspector.m" -o cocoa_inspector.o

echo "[3b/4] Compiling Scintilla editor (Objective-C++)..."
clang++ -c -O2 -fobjc-arc -std=c++17 \
   -I"$HBINC" \
   -I"$SCIINC" \
   -I"$SCICOCOA" \
   -I"$LEXINC" \
   -I"$SCIDIR/scintilla/src" \
   "$PROJDIR/backends/cocoa/cocoa_editor.mm" -o cocoa_editor.o

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
