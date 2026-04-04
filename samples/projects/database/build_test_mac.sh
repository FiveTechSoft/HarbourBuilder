#!/bin/bash
# Build and run database examples on macOS (console mode)
set -e

HBDIR="/Users/usuario/harbour"
HBBIN="$HBDIR/bin/darwin/clang"
HBINC="$HBDIR/include"
HBLIB="$HBDIR/lib/darwin/clang"
PROJDIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PROG="${1:-dbf_example}"

cd "$(dirname "$0")"

echo "=== Building $PROG ==="

# Compile the example
$HBBIN/harbour $PROG.prg -n -w -q \
   -I"$HBINC" -I"$PROJDIR/include" -I"$PROJDIR/harbour" \
   -o${PROG}.c

# Compile C
clang -c -O2 -Wno-unused-value -I"$HBINC" ${PROG}.c -o ${PROG}.o

# Compile classes.prg (has DB classes)
$HBBIN/harbour "$PROJDIR/harbour/classes.prg" -n -w -q \
   -I"$HBINC" -I"$PROJDIR/include" -I"$PROJDIR/harbour" \
   -oclasses.c
clang -c -O2 -Wno-unused-value -I"$HBINC" classes.c -o classes.o

# Compile cocoa_core (needed for MAC_ShellExec etc.)
clang -c -O2 -fobjc-arc -I"$HBINC" \
   "$PROJDIR/backends/cocoa/cocoa_core.m" -o cocoa_core.o 2>/dev/null

# Link
clang++ ${PROG}.o classes.o cocoa_core.o -o ${PROG} \
   -L"$HBLIB" \
   -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang \
   -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug \
   -lhbct -lhbextern -lhbsqlit3 \
   -lrddntx -lrddnsx -lrddcdx -lrddfpt \
   -lhbhsx -lhbsix -lhbusrrdd \
   -lgtcgi -lgttrm -lgtstd \
   -framework Cocoa -framework UniformTypeIdentifiers \
   -lm -lpthread -lsqlite3

echo ""
echo "=== Running $PROG ==="
echo ""
./${PROG}
echo ""
echo "=== Exit code: $? ==="
