#!/bin/bash
# External-edit freshness contract for TBRun - CONSERVATIVE REFUSAL:
#   clean:    disk edit with a clean editor buffer -> Run must REFUSE with
#             a dialog (no app runs, disk keeps VERSION-X). Auto-reload is
#             NOT the contract until the disk->editor->model circuit is
#             proven safe; stale execution is the defect under test.
#   conflict: disk edit AND unsaved buffer edit -> Run must REFUSE with a
#             dialog and touch nothing (no app run, disk keeps VERSION-Z).
# RED on binaries without a freshness contract: clean runs the stale
# buffer (VERSION-A), conflict silently runs the buffer side.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/runhash"
RUNA=/tmp/rt_extedit_a
TRACE=/tmp/rt_extedit_trace.log
source "$REPO/tests/harness_lib.sh"
fail() { echo "EXTEDIT FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
FAILN=0
CASES="${@:-clean}"

# The fixture's trace path is fixed inside the fixture source; point it at
# our trace by patching the copied fixture.
launch_a() {
  rm -rf "$RUNA"; mkdir -p "$RUNA"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUNA"/
  sed -i 's|/tmp/rt_runhash_trace.log|/tmp/rt_extedit_trace.log|' "$RUNA"/Form1.prg
  rm -f "$TRACE"
  rt_setup "$RUNA"
  rt_launch_ide
  IDEPID=$RT_IDEPID; OTHERPID=""
  rt_reopen_project
}

ctrl_r_and_trace() {  # echoes app trace; fails hard if no app appears
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

run_clean() {
launch_a
T1=$(ctrl_r_and_trace)
echo "trace after baseline Run: ${T1:-<missing>}"
echo "${T1:-}" | grep -q 'version:VERSION-A' \
  || { echo "  baseline Run did not produce VERSION-A"; FAILN=$((FAILN+1)); }
# EXTERNAL edit: change the file on disk without touching the editor
sed -i 's/VERSION-A/VERSION-X/' "$RUNA/Form1.prg"
echo "  [t=$SECONDS] external disk edit VERSION-A -> VERSION-X (buffer untouched)"
sleep 1
BEFORE=$(rt_ide_windows | sort -n | tr '\n' ' ')
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+r
APPW=""; DLG=""
for i in $(seq 1 10); do
  for w in $(xdotool search --name 'Fixture RunHash' 2>/dev/null); do
    p=$(xprop -id "$w" _NET_WM_PID 2>/dev/null | awk '{print $3}')
    [ -n "$p" ] && [ "$p" != "$IDEPID" ] && { APPW=$w; break; }
  done
  for w in $(rt_ide_windows); do
    case " $BEFORE " in *" $w "*) ;; *) DLG=$w;; esac
  done
  [ -n "$APPW" ] || [ -n "$DLG" ] && break
  sleep 2
done
rt_map_all
if [ -n "$APPW" ]; then
  echo "  CLEAN-EDIT: app RAN despite external disk edit (stale buffer executed)"
  FAILN=$((FAILN+1))
else
  echo "  clean: no app ran"
fi
if [ -n "$DLG" ]; then
  echo "  clean: refusal dialog appeared"
  xdotool windowmap "$DLG" 2>/dev/null; sleep 0.5
  eval "$(xdotool getwindowgeometry --shell "$DLG" 2>/dev/null)" &&     import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/ee_clean_dialog.png 2>/dev/null
else
  echo "  CLEAN-EDIT: NO refusal dialog after external disk edit"
  FAILN=$((FAILN+1))
fi
grep -q 'VERSION-X' "$RUNA/Form1.prg"   && echo "  clean: disk content untouched (VERSION-X)"   || { echo "  CLEAN-EDIT: disk file was overwritten"; FAILN=$((FAILN+1)); }
echo "clean case done (FAILN=$FAILN)"
rt_cleanup
}

run_conflict() {
launch_a
T1=$(ctrl_r_and_trace)
echo "trace after baseline Run: ${T1:-<missing>}"
echo "${T1:-}" | grep -q 'version:VERSION-A' \
  || { echo "  baseline Run did not produce VERSION-A"; FAILN=$((FAILN+1)); }
# buffer edit (unsaved): VERSION-A -> VERSION-Y in the code editor
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
xdotool key ctrl+End; sleep 0.3
xdotool key Up; sleep 0.2
xdotool key Home; sleep 0.2
xdotool key shift+End; sleep 0.2
xdotool type --delay 15 'return "VERSION-Y"'; sleep 1
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/ee_buffer_edit.png 2>/dev/null
tesseract /tmp/ee_buffer_edit.png - 2>/dev/null | grep -q 'VERSION-Y' \
  || { tesseract /tmp/ee_buffer_edit.png - 2>/dev/null | tail -3; fail "buffer edit did not land (harness)"; }
xdotool windowmove "$D" "$DX" "$DY"; sleep 0.5
echo "  [t=$SECONDS] buffer edit VERSION-A -> VERSION-Y (unsaved)"
# external edit on disk: VERSION-A -> VERSION-Z
sed -i 's/VERSION-A/VERSION-Z/' "$RUNA/Form1.prg"
echo "  [t=$SECONDS] external disk edit VERSION-A -> VERSION-Z (buffer dirty)"
sleep 1
# Ctrl+R: contract says REFUSE (conflict). Count app windows for a while.
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+r
APPW=""
for i in $(seq 1 8); do
  for w in $(xdotool search --name 'Fixture RunHash' 2>/dev/null); do
    p=$(xprop -id "$w" _NET_WM_PID 2>/dev/null | awk '{print $3}')
    [ -n "$p" ] && [ "$p" != "$IDEPID" ] && { APPW=$w; break; }
  done
  [ -n "$APPW" ] && break
  sleep 2
done
DLG=""
for w in $(rt_ide_windows); do
  t=$(xdotool getwindowname "$w" 2>/dev/null)
  case "$t" in *HbBuilder*|*onflict*|*xternal*) DLG=$w;; esac
done
rt_map_all
if [ -n "$APPW" ]; then
  echo "  CONFLICT: Run proceeded despite disk+buffer conflict (app window appeared)"
  FAILN=$((FAILN+1))
else
  echo "  conflict: no app ran"
fi
if [ -n "$DLG" ]; then
  echo "  conflict: dialog appeared"
else
  echo "  CONFLICT: no dialog after disk+buffer conflict"
  FAILN=$((FAILN+1))
fi
grep -q 'VERSION-Z' "$RUNA/Form1.prg" \
  && echo "  conflict: disk content untouched (VERSION-Z)" \
  || { echo "  CONFLICT: disk file was overwritten"; FAILN=$((FAILN+1)); }
echo "conflict case done (FAILN=$FAILN)"
rt_cleanup
}

for c in $CASES; do
  echo "== case: $c =="
  run_$c
done

if [ "$FAILN" -eq 0 ]; then
  echo "EXTEDIT PASS (cases executed: $CASES)"
else
  echo "EXTEDIT FAIL (cases executed: $CASES): $FAILN problem(s)"
  exit 1
fi
