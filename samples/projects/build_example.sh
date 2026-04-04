#!/bin/bash
# Build and run any example project
# Usage: ./build_example.sh <dir>/<name>
#   ./build_example.sh printing/print_example
#   ./build_example.sh internet/http_example
#   ./build_example.sh threading/thread_example
set -e

HBDIR="${HBDIR:-$HOME/harbour}"
HBBIN="$HBDIR/bin/linux/gcc"
HBINC="$HBDIR/include"
HBLIB="$HBDIR/lib/linux/gcc"
PROJDIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROG="$1"
PROGNAME=$(basename "$PROG")
PROGDIR=$(dirname "$PROG")

cd "$(dirname "$0")/$PROGDIR"

echo "=== Building $PROGNAME ==="

$HBBIN/harbour ${PROGNAME}.prg -n -w -q \
   -I"$HBINC" -I"$PROJDIR/include" -I"$PROJDIR/harbour" \
   -o${PROGNAME}.c 2>&1

gcc -c -g -Wno-unused-value -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0 2>/dev/null) \
   ${PROGNAME}.c -o ${PROGNAME}.o

# Compile classes + GTK3 core
$HBBIN/harbour "$PROJDIR/harbour/classes.prg" -n -w -q \
   -I"$HBINC" -I"$PROJDIR/include" -I"$PROJDIR/harbour" \
   -oclasses.c 2>&1
gcc -c -g -Wno-unused-value -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0 2>/dev/null) \
   classes.c -o classes.o
gcc -c -g -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0 2>/dev/null) \
   "$PROJDIR/backends/gtk3/gtk3_core.c" -o gtk3_core.o 2>/dev/null

gcc ${PROGNAME}.o classes.o gtk3_core.o -g -o ${PROGNAME} \
   -L"$HBLIB" \
   -Wl,--start-group \
   -lhbcommon -lhbvm -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
   -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
   -lhbsqlit3 -lsddsqlt3 -lrddsql \
   -lgttrm -lhbdebug -lhbpcre \
   $(pkg-config --libs gtk+-3.0 2>/dev/null) \
   -lm -lpthread -ldl -lrt -lsqlite3 \
   -L/usr/lib/x86_64-linux-gnu -l:libncurses.so.6 \
   -Wl,--end-group

echo ""
echo "=== Running $PROGNAME ==="
echo ""
echo "" | timeout 15 ./${PROGNAME} 2>&1
echo ""
echo "=== Exit: $? ==="
