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

echo "=== messages_stubs ==="
rm -f messages_stubs.c messages_stubs.o
"$HB_BIN" messages_stubs.prg -n -w -es2 -q -I"$HB_INC" -omessages_stubs
gcc -c -o messages_stubs.o messages_stubs.c -I"$HB_INC" -Wno-unused-variable

TESTS=(
   test_codegen
   test_hbp_index
   test_hbp_parse
   test_messages
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
   gcc -o "$BINDIR/${name}" "${name}.c" messages_stubs.o \
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
for ide in hbbuilder_linux hbbuilder_macos; do
   "$HB_BIN" hbbuilder_common.prg "${ide}.prg" \
      -n -w -es2 -q -I"$HB_INC" -I"$INCDIR" -I"$ROOT/source" -o"${ide}_syntax"
   rm -f "${ide}_syntax.c" hbbuilder_common.c
   echo "OK: ${ide}.prg syntax"
done

echo ""
if [ "$FAIL" -eq 0 ]; then
   echo "ALL TESTS PASSED ($PASS tests)"
   exit 0
else
   echo "TESTS FAILED ($FAIL failed, $PASS passed)"
   exit 1
fi