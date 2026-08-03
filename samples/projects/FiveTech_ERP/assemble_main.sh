#!/bin/bash
# Assemble main.prg from the SAME PRG units used on Windows:
#   Project1.prg + Form1.prg  (erp_meta / erp_http compile as separate units)
# Usage: assemble_main.sh <ProjDir> <BuildDir> [mac|linux|win]
#   mac|linux → REQUEST HB_GT_NUL  (native UI backend, no Harbour GT GUI)
#   default   → REQUEST HB_GT_GUI_DEFAULT
set -e
PROJDIR="${1:?ProjDir}"
BUILDDIR="${2:?BuildDir}"
TARGET_OS="${3:-}"
mkdir -p "$BUILDDIR"

if [ "$TARGET_OS" = "mac" ] || [ "$TARGET_OS" = "linux" ]; then
  GT_REQ='REQUEST HB_GT_NUL'
else
  GT_REQ='REQUEST HB_GT_GUI_DEFAULT'
fi

{
  echo '#include "hbbuilder.ch"'
  echo "$GT_REQ"
  echo 'REQUEST HB_CODEPAGE_UTF8EX'
  echo 'REQUEST HB_MT'
  echo 'REQUEST DBFCDX, DBFNTX, DBFFPT'
  echo 'REQUEST RDDSYS'
  echo
  for f in Project1.prg Form1.prg; do
    # Strip includes that the build injects / compiles separately
    # Strip any REQUEST HB_GT_* from Project1 so assembler owns the GT choice
    sed -e 's/#include *"hbbuilder.ch"//' \
        -e 's/#include *"classes.prg"//' \
        -e '/REQUEST HB_GT_/d' \
        "$PROJDIR/$f"
    echo
  done
} > "$BUILDDIR/main.prg"

cp -f "$PROJDIR/erp_meta.prg" "$BUILDDIR/erp_meta.prg"
cp -f "$PROJDIR/erp_http.prg" "$BUILDDIR/erp_http.prg"
cp -f "$PROJDIR/erp_proc.prg" "$BUILDDIR/erp_proc.prg"
[ -f "$PROJDIR/erp_db.prg" ] && cp -f "$PROJDIR/erp_db.prg" "$BUILDDIR/erp_db.prg" || true
cp -f "$HBROOT/source/core/classes.prg" "$BUILDDIR/classes.prg" 2>/dev/null || \
  cp -f "$(cd "$PROJDIR/../../.." && pwd)/source/core/classes.prg" "$BUILDDIR/classes.prg"

echo "Assembled $BUILDDIR/main.prg ($GT_REQ) + erp_meta/http/db/proc classes.prg"
