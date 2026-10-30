#!/bin/bash
# Run-stale regression (TBRun quick-path cache key):
#   tail:     editing the code BEYOND char 5000 must invalidate the build
#             cache; the second Run must rebuild and the APP EFFECT must
#             change (trace marker VERSION-A -> VERSION-B), not just the hash
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
source "$REPO/tests/harness_lib.sh"
fail() { echo "RUNHASH FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
FAILN=0

rm -rf "$RUNA" "$RUNB"; mkdir -p "$RUNA" "$RUNB"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUNA"/
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUNB"/
rm -f "$TRACE"
rt_setup "$RUNA"
rt_launch_ide
IDEPID=$RT_IDEPID
rt_reopen_project

ctrl_r_and_trace() {  # $1=expected-version-or-empty; echoes app trace line
  local BAR w p APPW="" APPPID="" i
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
  sleep 2
  kill "$APPPID" 2>/dev/null; sleep 1
  rt_map_all
  [ -f "$TRACE" ] && cat "$TRACE"
}

# --- build 1: full build, effect VERSION-A
T1=$(ctrl_r_and_trace)
echo "trace after first Run: ${T1:-<missing>}"
echo "${T1:-}" | grep -q 'version:VERSION-A' \
  || { echo "  first Run did not produce the VERSION-A effect"; FAILN=$((FAILN+1)); }

# --- case tail: edit the code tab BEYOND char 5000 (VERSION-A -> VERSION-B)
sed 's/VERSION-A/VERSION-B/' "$FIX/Form1.prg" > /tmp/rt_runhash_v2.prg
CED=""
for w in $(rt_ide_windows); do
  [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
done
[ -n "$CED" ] || fail "Code Editor window not found"
BAR=$(rt_find_bar); rt_park_all_but "$CED" "$BAR"; sleep 0.5
eval "$(xdotool getwindowgeometry --shell "$CED")"
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.5
xdotool key ctrl+a; sleep 0.5
xdotool type --delay 3 --file /tmp/rt_runhash_v2.prg; sleep 2
T2=$(ctrl_r_and_trace)
echo "trace after tail-edit Run: ${T2:-<missing>}"
echo "${T2:-}" | grep -q 'version:VERSION-B' \
  || { echo "  TAIL-EDIT: app effect STILL the old build (stale quick-path)"; FAILN=$((FAILN+1)); }
echo "${T2:-}" | grep -q 'version:VERSION-A' \
  && { echo "  TAIL-EDIT: stale binary executed"; }

# --- case identity: same process, point the INI at project B, reopen, Run
sed -i 's/VERSION-B/VERSION-A/' /tmp/rt_runhash_v2.prg   # v2 var reused below
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

if [ "$FAILN" -eq 0 ]; then
  echo "RUNHASH PASS: tail edits beyond char 5000 rebuild with the new app effect; a same-text project at a new path gets its own build and exe."
else
  echo "RUNHASH FAIL: $FAILN problem(s)"
  exit 1
fi
