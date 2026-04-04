#!/bin/bash
# build_test_report.sh - Build and run report designer unit tests
#
# Usage: ./build_test_report.sh
# Exit code: 0 = all tests passed, 1 = failures

set -e

HBDIR="${HBDIR:-$HOME/harbour}"
HBBIN="$HBDIR/bin/linux/gcc"
HBINC="$HBDIR/include"
HBLIB="$HBDIR/lib/linux/gcc"
PROJDIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$(dirname "$0")"

echo "=== Building report designer tests ==="
echo "Harbour: $HBDIR"
echo ""

# Step 1: Compile classes.prg (contains TReport, TReportBand, TReportField)
echo "[1/5] Compiling classes.prg..."
"$HBBIN/harbour" "$PROJDIR/harbour/classes.prg" -n -w -q \
   -I"$HBINC" \
   -I"$PROJDIR/include" \
   -I"$PROJDIR/harbour" \
   -oclasses.c

# Step 2: Compile test .prg
echo "[2/5] Compiling test_report.prg..."
"$HBBIN/harbour" test_report.prg -n -w -q \
   -I"$HBINC" \
   -I"$PROJDIR/include" \
   -I"$PROJDIR/harbour" \
   -otest_report.c

# Step 3: Compile C files
echo "[3/6] Compiling classes.c..."
gcc -c -g -Wno-unused-value \
   -I"$HBINC" \
   classes.c -o classes.o

echo "[4/6] Compiling test_report.c..."
gcc -c -g -Wno-unused-value \
   -I"$HBINC" \
   test_report.c -o test_report.o

echo "[5/6] Compiling ui_stubs.c..."
gcc -c -g \
   -I"$HBINC" \
   ui_stubs.c -o ui_stubs.o

# Step 6: Link
echo "[6/6] Linking test_report..."
gcc test_report.o classes.o ui_stubs.o -g -o test_report \
   -L"$HBLIB" \
   -Wl,--start-group \
   -lhbcommon -lhbvm -lhbrtl -lhbrdd -lhbmacro -lhblang -lhbcpage -lhbpp \
   -lhbcplr -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbusrrdd -lhbct \
   -lgttrm -lhbdebug -lhbpcre \
   -lm -lpthread -ldl -lrt \
   -L/usr/lib/x86_64-linux-gnu -l:libncurses.so.6 \
   -Wl,--end-group

echo ""
echo "=== Running tests ==="
echo ""

./test_report
EXIT_CODE=$?

echo ""
exit $EXIT_CODE
