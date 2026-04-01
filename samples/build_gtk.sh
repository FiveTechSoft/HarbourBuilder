#!/bin/bash
# build_gtk.sh - Build test_design_gtk for Linux using Harbour + GTK3
#
# Prerequisites:
#   sudo apt install libgtk-3-dev
#   Harbour compiler installed (default: ~/harbour)
#
# Usage: ./build_gtk.sh

set -e

# Harbour paths - adjust these for your system
HBDIR="${HBDIR:-$HOME/harbour}"
HBBIN="$HBDIR/bin/linux/gcc"
HBINC="$HBDIR/include"
HBLIB="$HBDIR/lib/linux/gcc"

PROJDIR="$(cd "$(dirname "$0")/.." && pwd)"
PROG="test_design_gtk"

cd "$(dirname "$0")"

echo "Using Harbour: $HBDIR"
echo ""

echo "[1/5] Compiling ${PROG}.prg..."
"$HBBIN/harbour" ${PROG}.prg -n -w -q \
   -I"$HBINC" \
   -I"$PROJDIR/include" \
   -I"$PROJDIR/harbour" \
   -o${PROG}.c

echo "[2/5] Compiling ${PROG}.c..."
gcc -c -g -Wno-unused-value \
   -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0) \
   ${PROG}.c -o ${PROG}.o

echo "[3/5] Compiling GTK3 core..."
gcc -c -g \
   -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0) \
   "$PROJDIR/backends/gtk3/gtk3_core.c" -o gtk3_core.o

echo "[4/5] Compiling GTK3 inspector..."
gcc -c -g \
   -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0) \
   "$PROJDIR/backends/gtk3/gtk3_inspector.c" -o gtk3_inspector.o

echo "[5/5] Linking ${PROG}..."
gcc ${PROG}.o gtk3_core.o gtk3_inspector.o -g -o ${PROG} \
   -L"$HBLIB" \
   -Wl,--start-group \
   -lhbcommon -lhbvm -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
   -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
   -lgttrm -lhbdebug -lhbpcre \
   $(pkg-config --libs gtk+-3.0) \
   -lm -lpthread -ldl -lrt \
   -L/usr/lib/x86_64-linux-gnu -l:libncurses.so.6 \
   -Wl,--end-group

echo ""
echo "-- ${PROG} built successfully --"
echo "Run with: ./${PROG}"
