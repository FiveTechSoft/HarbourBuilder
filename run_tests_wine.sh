#!/usr/bin/env bash
# Run HarbourBuilder headless unit tests as Windows binaries under Wine (Linux host).
# Cross-compiles each suite with the host hbmk2 (-plat=win -comp=mingw64) and runs
# the resulting .exe with Wine. Requires: HBDIR_SRC (harbour source prefix with
# linux host tools and win/mingw64 libs), WINE, and a mingw-w64 cross toolchain.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
HBDIR_SRC="${HBDIR_SRC:-$HOME/harbour}"
WINE="${WINE:-wine}"
HB_HOST_BIN="$HBDIR_SRC/bin/linux/gcc"
if [ ! -x "$HB_HOST_BIN/hbmk2" ]; then
   echo "ERROR: host hbmk2 not found in $HB_HOST_BIN"
   exit 1
fi
export PATH="$HB_HOST_BIN:$PATH" HBDIR="$HBDIR_SRC"
BINDIR="$ROOT/tests/bin/win"
mkdir -p "$BINDIR"
TESTS=(test_codegen test_items_parse test_hbp_index test_hbp_parse test_messages test_project_tab
       test_hix_path test_component_types test_ct_constants test_project_roundtrip)
FAIL=0
PASS=0
echo "=== test harness self-check (Wine) ==="
cd "$ROOT" || exit 1
if "$HB_HOST_BIN/hbmk2" -plat=win -comp=mingw64 tests/harness_failure.prg tests/test_runner.prg \
   -Itests -q -quiet -w -es2 -gtstd -otests/bin/win/harness_failure; then
   if "$WINE" "$BINDIR/harness_failure.exe" >/dev/null 2>&1; then
      echo "ERROR: test harness accepted an intentional assertion failure"
      exit 1
   fi
else
   echo "ERROR: could not build harness self-check"
   exit 1
fi
for name in "${TESTS[@]}"; do
   echo "=== $name ==="
   if "$HB_HOST_BIN/hbmk2" -plat=win -comp=mingw64 "tests/$name.prg" tests/test_runner.prg \
      source/hbbuilder_common.prg tests/messages_stubs.prg \
      -Iinclude -Itests -q -quiet -w -es2 -gtstd -o"tests/bin/win/$name"; then
      if "$WINE" "$BINDIR/$name.exe"; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi
   else
      echo "BUILD FAILED: $name"
      FAIL=$((FAIL + 1))
   fi
done
echo "TEST SUMMARY: $PASS suites passed, $FAIL failures"
[ "$FAIL" -eq 0 ]
