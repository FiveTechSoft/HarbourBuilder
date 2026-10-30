#!/bin/bash
# Run-stale regression (TBRun quick-path cache key):
#   tail:     three Runs in one IDE process: (1) full build, (2) no edit -
#             the quick-path MUST fire (UserApp mtime unchanged), (3) after
#             editing the code BEYOND char 5000 the cache must invalidate:
#             rebuild and the APP EFFECT must change (trace VERSION-A -> B),
#             not just the hash. The designer window is parked off-screen
#             for the edit OCR and moved back afterwards, because its live
#             position is written back into the generated nLeft/nTop and
#             would otherwise legitimately change the hash (drift).
#   identity: project B with IDENTICAL text but different path must get a
#             real build and its own exe copy, not A's cached binary
# RED with the 5000-char toy hash + process-static nLastHash; GREEN after
# keying the cache on the FULL editor text + project path.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/runhash"
RUNA=/tmp/rt_runhash_a
RUNB=/tmp/rt_runhash_b
TRACE=/tmp/rt_runhash_trace.log
build_dir_for() {  # $1 = project dir; per-project build subdir keyed by MD5 of the .hbp absolute path
  printf '/tmp/hbbuilder_build/%s' "$(printf '%s' "$1/Project1.hbp" | md5sum | cut -d' ' -f1)"
}
source "$REPO/tests/harness_lib.sh"
fail() { echo "RUNHASH FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
FAILN=0

CASES="${@:-tail}"

launch_a() {
  rm -rf "$RUNA"; mkdir -p "$RUNA"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUNA"/
  rm -f "$TRACE"
  rt_setup "$RUNA"
  rt_launch_ide
  IDEPID=$RT_IDEPID
  rt_reopen_project
}

ctrl_r_and_trace() {  # echoes app trace line
  local BAR w p APPW="" APPPID="" i
  echo "  [t=$SECONDS] Ctrl+R start"
  BAR=$(rt_find_bar) || fail "IDE bar not found"
  rt_unmap_all_but "$BAR"; sleep 0.3
  xdotool mousemove 700 12 click 1; sleep 0.4
  xdotool key ctrl+r
  for i in $(seq 1 45); do
    for w in $(xdotool search --name 'Fixture RunHash' 2>/dev/null); do
      p=$(xprop -id "$w" _NET_WM_PID 2>/dev/null | awk '{print $3}')
      [ -n "$p" ] && [ "$p" != "$IDEPID" ] && { APPW=$w; APPPID=$p; break; }
    done
    [ -n "$APPW" ] && break
    sleep 2
  done
  [ -n "$APPW" ] || fail "app window did not appear after Ctrl+R"
  echo "  [t=$SECONDS] app window up"
  sleep 2
  kill "$APPPID" 2>/dev/null; sleep 1
  rt_map_all
  [ -f "$TRACE" ] && cat "$TRACE"
}

run_tail() {
launch_a
# --- Run 1: full build, effect VERSION-A
T1=$(ctrl_r_and_trace)
echo "trace after first Run: ${T1:-<missing>}"
echo "${T1:-}" | grep -q 'version:VERSION-A' \
  || { echo "  first Run did not produce the VERSION-A effect"; FAILN=$((FAILN+1)); }
M1=$(stat -c %Y "$(build_dir_for "$RUNA")/UserApp")

# --- Run 2, NO edit: quick-path must fire (same binary, no rebuild)
T2=$(ctrl_r_and_trace)
M2=$(stat -c %Y "$(build_dir_for "$RUNA")/UserApp")
echo "trace after no-edit Run: ${T2:-<missing>}"
if [ "$M1" = "$M2" ]; then
  echo "  no-edit Run: quick-path fired (UserApp mtime unchanged: $M1)"
else
  echo "  NO-EDIT RUN REBUILT (mtime $M1 -> $M2): cache invalidated without any edit"
  FAILN=$((FAILN+1))
fi

# --- case tail: edit the code tab BEYOND char 5000 (VERSION-A -> VERSION-B)
CED=""
for w in $(rt_ide_windows); do
  [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
done
[ -n "$CED" ] || fail "Code Editor window not found"
D=$(rt_find_designer) || fail "designer window not found"
eval "$(xdotool getwindowgeometry --shell "$D")"; DX=$X; DY=$Y
BAR=$(rt_find_bar); rt_park_all_but "$CED" "$BAR"; sleep 0.5
eval "$(xdotool getwindowgeometry --shell "$CED")"
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.5
echo "  [t=$SECONDS] tail edit start"
xdotool key ctrl+End; sleep 0.3
xdotool key Up; sleep 0.2
xdotool key Home; sleep 0.2
xdotool key shift+End; sleep 0.2
xdotool type --delay 15 'return "VERSION-B"'; sleep 1
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/rh_tail_edit.png 2>/dev/null
tesseract /tmp/rh_tail_edit.png - 2>/dev/null | grep -q 'VERSION-B'   || { tesseract /tmp/rh_tail_edit.png - 2>/dev/null | tail -3; fail "tail edit did not land in the editor (harness)"; }
echo "  [t=$SECONDS] tail edit verified visible"
# restore the designer window position so only the tail edit changes the code
xdotool windowmove "$D" "$DX" "$DY"; sleep 0.5
T3=$(ctrl_r_and_trace)
M3=$(stat -c %Y "$(build_dir_for "$RUNA")/UserApp")
echo "trace after tail-edit Run: ${T3:-<missing>} (UserApp mtime $M2 -> $M3)"
echo "${T3:-}" | grep -q 'version:VERSION-B' \
  || { echo "  TAIL-EDIT: app effect STILL the old build (stale quick-path)"; FAILN=$((FAILN+1)); }
echo "${T3:-}" | grep -q 'version:VERSION-A' \
  && { echo "  TAIL-EDIT: stale binary executed"; }

echo "tail case done (FAILN=$FAILN)"
rt_cleanup
}

run_identity() {
launch_a
# first Run builds project A (fills the process-static cache)
T1=$(ctrl_r_and_trace)
echo "trace after project-A Run: ${T1:-<missing>}"
# --- case identity: same process, point the INI at project B, reopen, Run
rm -rf "$RUNB"; mkdir -p "$RUNB"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUNB"/
rt_setup "$RUNB"    # rewrites bin/hbbuilder.ini File1 -> project B (same IDE!)
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 20 12 click 1; sleep 0.8
xdotool mousemove 100 134 click 1; sleep 5
rt_map_all; sleep 1
BEXE="$RUNB/$(basename "$RUNB")"
rm -f "$BEXE"
T3=$(ctrl_r_and_trace)
echo "trace after identity Run: ${T3:-<missing>}"
if [ -f "$BEXE" ]; then
  echo "  identity: project B got its own exe copy"
else
  echo "  IDENTITY: project B got NO exe (quick-path reused project A's build)"
  FAILN=$((FAILN+1))
fi

echo "identity case done (FAILN=$FAILN)"
rt_cleanup
}

for c in $CASES; do
  echo "== case: $c =="
  run_$c
done

if [ "$FAILN" -eq 0 ]; then
  echo "RUNHASH PASS: tail edits beyond char 5000 rebuild with the new app effect; a same-text project at a new path gets its own build and exe."
else
  echo "RUNHASH FAIL: $FAILN problem(s)"
  exit 1
fi
