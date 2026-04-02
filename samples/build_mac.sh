#!/bin/bash
# build_mac.sh - Build HBCPP MacOS using Harbour + Cocoa
#
# Usage: ./build_mac.sh

set -e

HBDIR="/Users/usuario/harbour"
HBBIN="$HBDIR/bin/darwin/clang"
HBINC="$HBDIR/include"
HBLIB="$HBDIR/lib/darwin/clang"
PROJDIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="hbcpp_macos"
PROG="HbBuilder"

cd "$(dirname "$0")"

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

echo "[4/4] Linking ${PROG}..."
clang++ -o ${PROG} \
   ${SRC}.o cocoa_core.o cocoa_inspector.o \
   -L"$HBLIB" \
   -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang \
   -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug \
   -lhbct -lhbextern \
   -lrddntx -lrddnsx -lrddcdx -lrddfpt \
   -lhbhsx -lhbsix -lhbusrrdd \
   -lgtcgi -lgttrm -lgtstd \
   -framework Cocoa \
   -lm -lpthread

echo ""
echo "-- ${PROG} built successfully --"
echo "Run with: ./${PROG}"
