#!/bin/bash
# build_test_debugger.sh - Build and run debugger unit tests
#
# Usage: ./build_test_debugger.sh
# Exit code: 0 = all tests passed, 1 = failures

set -e

HBDIR="${HBDIR:-$HOME/harbour}"
HBBIN="$HBDIR/bin/linux/gcc"
HBINC="$HBDIR/include"
HBLIB="$HBDIR/lib/linux/gcc"
PROJDIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$(dirname "$0")"

echo "=== Building debugger tests ==="
echo "Harbour: $HBDIR"
echo ""

# Step 1: Compile test .prg
echo "[1/4] Compiling test_debugger.prg..."
"$HBBIN/harbour" test_debugger.prg -n -w -q \
   -I"$HBINC" \
   -I"$PROJDIR/include" \
   -I"$PROJDIR/harbour" \
   -otest_debugger.c

# Step 2: Compile test C
echo "[2/4] Compiling test_debugger.c..."
gcc -c -g -Wno-unused-value \
   -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0) \
   test_debugger.c -o test_debugger.o

# Step 3: Compile GTK3 core (has the debugger engine)
echo "[3/4] Compiling GTK3 core..."
gcc -c -g \
   -I"$HBINC" \
   $(pkg-config --cflags gtk+-3.0) \
   "$PROJDIR/backends/gtk3/gtk3_core.c" -o gtk3_core.o

# Step 4: Link
echo "[4/4] Linking test_debugger..."
gcc test_debugger.o gtk3_core.o -g -o test_debugger \
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
echo "=== Running tests ==="
echo ""

# Run tests (LD_LIBRARY_PATH for Scintilla .so if needed)
LD_LIBRARY_PATH="$PROJDIR/resources:$PROJDIR/samples:." ./test_debugger
EXIT_CODE=$?

echo ""
exit $EXIT_CODE
