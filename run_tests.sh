#!/usr/bin/env bash
# Run HarbourBuilder headless unit tests (Linux / macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
HBDIR="${HBDIR:-$HOME/harbour}"
HB_BIN=""
for dir in "$HBDIR/bin" "$HBDIR/bin/linux/gcc" "$HBDIR/bin/darwin/clang"; do
   if [ -x "$dir/harbour" ] && [ -x "$dir/hbmk2" ]; then
      HB_BIN="$dir"
      break
   fi
done
if [ -z "$HB_BIN" ]; then
   echo "ERROR: harbour and hbmk2 not found in HBDIR=$HBDIR"
   exit 1
fi
export PATH="$HB_BIN:$PATH"
BINDIR="$ROOT/tests/bin"
mkdir -p "$BINDIR"
TESTS=(test_codegen test_hbp_index test_hbp_parse test_messages test_project_tab
       test_hix_path test_component_types test_ct_constants test_project_roundtrip)
FAIL=0
PASS=0
# Verify that an assertion failure actually reaches the caller as a nonzero exit.
echo "=== test harness self-check ==="
"$HB_BIN/hbmk2" "$ROOT/tests/harness_failure.prg" "$ROOT/tests/test_runner.prg" \
   -I"$ROOT/tests" -q -quiet -w -es2 -gtstd -o"$BINDIR/harness_failure"
if "$BINDIR/harness_failure"; then
   echo "ERROR: test harness accepted an intentional assertion failure"
   exit 1
fi
for name in "${TESTS[@]}"; do
   echo "=== $name ==="
   if "$HB_BIN/hbmk2" "$ROOT/tests/$name.prg" "$ROOT/tests/test_runner.prg" \
      "$ROOT/source/hbbuilder_common.prg" "$ROOT/tests/messages_stubs.prg" \
      -I"$ROOT/include" -I"$ROOT/tests" -q -quiet -w -es2 -gtstd -o"$BINDIR/$name"; then
      if "$BINDIR/$name"; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi
   else
      echo "BUILD FAILED: $name"
      FAIL=$((FAIL + 1))
   fi
done
# Compilation to C checks Harbour syntax only, not native GUI/runtime support.
echo "=== compile-only: IDE sources ==="
for ide in hbbuilder_linux hbbuilder_macos; do
   if "$HB_BIN/harbour" "$ROOT/source/$ide.prg" -n -w -es2 -q \
      -I"$HBDIR/include" -I"$ROOT/include" -I"$ROOT/source" -o"$BINDIR/${ide}_syntax.c"; then
      echo "OK: $ide.prg syntax"
   else
      echo "SYNTAX FAILED: $ide.prg"
      FAIL=$((FAIL + 1))
   fi
done
echo "TEST SUMMARY: $PASS suites passed, $FAIL failures"
[ "$FAIL" -eq 0 ]
