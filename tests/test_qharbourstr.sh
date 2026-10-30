#!/bin/bash
# Compile-and-run unit test for HB_QHarbourStr/HB_HarbourStrEval.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
BUILD=/tmp/qstr_build
HB=/tmp/harbour-review
HBIN="$HB/bin/linux/gcc"; [ -x "$HBIN/harbour" ] || HBIN="$HB/bin"
rm -rf "$BUILD"; mkdir -p "$BUILD"
cp "$REPO/tests/test_qharbourstr.prg" "$REPO/source/hbbuilder_common.prg" "$REPO/tests/messages_stubs.c" "$BUILD/"
cd "$BUILD" || exit 1
for m in test_qharbourstr hbbuilder_common; do
  "$HBIN/harbour" "$m.prg" -n -w -q -I"$HB/include" -I"$REPO/include" -I"$REPO/source" -o"$m.c" || { echo "QSTR FAIL: harbour compile $m"; exit 1; }
  gcc -c -O2 -I"$HB/include" "$m.c" -o "$m.o" || { echo "QSTR FAIL: gcc $m"; exit 1; }
done
gcc -c -O2 -I"$HB/include" messages_stubs.c -o messages_stubs.o || { echo "QSTR FAIL: gcc stubs"; exit 1; }
gcc -o QStrTest test_qharbourstr.o hbbuilder_common.o messages_stubs.o \
  -L"$HB/lib/linux/gcc" -L"$HB/lib" -Wl,--start-group \
  -lhbvm -lhbrtl -lhblang -lhbrdd -lrddntx -lrddfpt -lhbsix -lhbhsx -lhbusrrdd -lhbnulrdd \
  -lhbmacro -lhbcplr -lhbpp -lhbcommon -lhbcpage -lhbpcre -lgtstd -lgttrm -lgtcgi -lgtpca -lhbct -lhbnortl \
  -Wl,--end-group -lm || { echo "QSTR FAIL: link"; exit 1; }
./QStrTest
