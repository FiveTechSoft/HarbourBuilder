#!/bin/bash
# Save dialog extension normalization. The GTK save chooser appends the
# filter extension unconditionally; the app must normalize to exactly one
# .hbp, preserving the user's own suffix (any case) and never touching
# directory parts of the path.
# RED on binaries without normalization: name.hbp becomes name.hbp.hbp.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUNA=/tmp/rt_saveext
DEST=/tmp/rt_saveext_dest
source "$REPO/tests/harness_lib.sh"
fail() { echo "SAVEEXT FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
FAILN=0

try_save() {  # $1 = typed path, $2 = expected resulting file
  local TYPED="$1" WANT="$2"
  rm -rf "$RUNA"; mkdir -p "$RUNA"
  rt_setup "$RUNA"; rt_launch_ide
  IDEPID=$RT_IDEPID; sleep 3
  xdotool mousemove 700 12 click 1; sleep 0.4
  xdotool key ctrl+s; sleep 2.5
  xdotool key ctrl+l; sleep 0.8
  xdotool type --delay 15 "$TYPED"; sleep 0.5
  # a typed name matching the filter confirms on the first Return; a name
  # without it (or different case) only completes in the location bar and
  # needs a second Return to accept
  xdotool key Return; sleep 1.5
  xdotool key Return; sleep 2.5
  if [ -f "$WANT" ]; then
    echo "  saveext: typed [$TYPED] -> $WANT OK"
  else
    echo "  SAVEEXT: typed [$TYPED] did not produce $WANT:"; ls -la "$DEST" "$DEST/proj.hbp" 2>/dev/null
    FAILN=$((FAILN+1))
  fi
  rt_cleanup
}

rm -rf "$DEST"; mkdir -p "$DEST/proj.hbp"   # dir whose NAME contains .hbp
try_save "$DEST/foo.hbp"        "$DEST/foo.hbp"
[ -f "$DEST/foo.hbp.hbp" ] && { echo "  SAVEEXT: double extension foo.hbp.hbp"; FAILN=$((FAILN+1)); }
try_save "$DEST/sinext"         "$DEST/sinext.hbp"
try_save "$DEST/UPPER.HBP"      "$DEST/UPPER.HBP"
[ -f "$DEST/UPPER.HBP.hbp" ] && { echo "  SAVEEXT: double extension UPPER.HBP.hbp"; FAILN=$((FAILN+1)); }
try_save "$DEST/proj.hbp/inner" "$DEST/proj.hbp/inner.hbp"

# full project written next to the normalized name + clean session
[ -f "$DEST/proj.hbp/Project1.prg" ] || { echo "  SAVEEXT: Project1.prg not written in .hbp-named dir"; FAILN=$((FAILN+1)); }
[ -f "$DEST/proj.hbp/Form1.prg" ]    || { echo "  SAVEEXT: Form1.prg not written in .hbp-named dir"; FAILN=$((FAILN+1)); }

if [ "$FAILN" -eq 0 ]; then
  echo "SAVEEXT PASS: one .hbp for typed .hbp/plain/.HBP names; .hbp-named directory untouched; full project written"
else
  echo "SAVEEXT FAIL: $FAILN problem(s)"; exit 1
fi
