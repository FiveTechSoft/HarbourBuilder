#!/usr/bin/env bash
# Run HarbourBuilder headless unit tests (Linux / macOS)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HBDIR="${HBDIR:-$HOME/harbour}"
COMMON="$ROOT/source/hbbuilder_common.prg"
RUNNER="$ROOT/tests/test_runner.prg"
INCDIR="$ROOT/include"
TESTDIR="$ROOT/tests"
BINDIR="$ROOT/tests/bin"

if [ ! -x "$HBDIR/bin/harbour" ] && [ ! -x "$HBDIR/bin/linux/gcc/harbour" ]; then
   echo "ERROR: harbour not found in HBDIR=$HBDIR"
   exit 1
fi

HB_BIN="$HBDIR/bin/harbour"
[ -x "$HB_BIN" ] || HB_BIN="$HBDIR/bin/linux/gcc/harbour"

HB_INC="$HBDIR/include"
HB_LIB="$HBDIR/lib"
[ -d "$HB_LIB" ] || HB_LIB="$HBDIR/lib/linux/gcc"

mkdir -p "$BINDIR"
cd "$TESTDIR"

TESTS=(
   test_codegen
   test_hbp_index
   test_project_tab
   test_hix_path
   test_component_types
   test_ct_constants
)

HBLINK="-lhbvm -lhbrtl -lhbcommon -lhblang -lhbrdd -lhbmacro -lhbpp -lhbct -lhbsix -lrddntx -lrddfpt -lgttrm -lm -ldl"
FAIL=0
PASS=0

for name in "${TESTS[@]}"; do
   echo "=== $name ==="
   rm -f "${name}.c" "${name}.o"
   "$HB_BIN" "${name}.prg" "$RUNNER" "$COMMON" \
      -n -w -es2 -q -I"$HB_INC" -I"$INCDIR" -o"${name}"
   if [ ! -f "${name}.c" ]; then
      echo "NO C OUTPUT: $name"
      FAIL=$((FAIL + 1))
      continue
   fi
   gcc -o "$BINDIR/${name}" "${name}.c" \
      -I"$HB_INC" -L"$HB_LIB" $HBLINK -Wno-unused-variable
   if "$BINDIR/${name}"; then
      PASS=$((PASS + 1))
   else
      echo "FAILED: $name (exit $?)"
      FAIL=$((FAIL + 1))
   fi
done

echo ""
echo "=== compile-only: IDE sources ==="
cd "$ROOT/source"
"$HB_BIN" hbbuilder_common.prg hbbuilder_linux.prg \
   -n -w -es2 -q -I"$HB_INC" -I"$INCDIR" -ohbbuilder_linux_syntax
rm -f hbbuilder_linux_syntax.c hbbuilder_common.c
echo "OK: hbbuilder_linux.prg syntax"

echo ""
if [ "$FAIL" -eq 0 ]; then
   echo "ALL TESTS PASSED ($PASS tests)"
   exit 0
else
   echo "TESTS FAILED ($FAIL failed, $PASS passed)"
   exit 1
fi