#!/bin/bash
# TLabeledEdit EDIT leg: edit the VAR text in the Code Editor (non-default
# value), let code->form sync apply it, explicit save, then reopen: the
# edited value must persist on disk AND render in the designer. Proves the
# parser feeds the model (a failed parse would revert the line or trip the
# parse-block refusal) and that the generator re-emits it faithfully.
# Inspector property-field editing is NOT covered by this harness.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_edit
source "$REPO/tests/harness_lib.sh"
fail() { echo "LABELEDEDIT_EDIT FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
rt_setup "$RUN"
rt_launch_ide
rt_reopen_project

CED=""; BAR=$(rt_find_bar)
for w in $(rt_ide_windows); do
  [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
done
[ -n "$CED" ] || fail "Code Editor window not found"
[ -n "$BAR" ] || fail "IDE bar not found"
rt_park_all_but "$CED" "$BAR"; sleep 0.5

eval "$(xdotool getwindowgeometry --shell "$CED")"
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.5
EX=""
for i in 1 2 3 4 5 6; do
  xdotool key Next; sleep 0.6   # Page Down: the LABELEDEDIT line is below the fold
  import -window root /tmp/edit_ed.png 2>/dev/null
  read EX EY <<< $(tesseract /tmp/edit_ed.png - tsv 2>/dev/null | \
    awk -F'\t' '$12 ~ /editable/ && $9+0>3 {printf "%d %d\n", $7+$9/2, $8+$10/2; exit}')
  [ -n "${EX:-}" ] && break
  sleep 1
done
[ -n "${EX:-}" ] || { tesseract /tmp/edit_ed.png - 2>/dev/null | grep -iE "labeled|editable" | head -3; fail "LABELEDEDIT text not visible in Code Editor"; }
echo "editable token at $EX,$EY"

xdotool mousemove "$EX" "$EY" click --repeat 2 --delay 100 1; sleep 0.5
xdotool type --delay 40 "editado42"; sleep 2
import -window root /tmp/edit_after_type.png 2>/dev/null

xdotool windowactivate "$BAR" 2>/dev/null
xdotool mousemove 700 12 click 1; sleep 0.5
xdotool key ctrl+s; sleep 2

grep -q 'LABELEDEDIT ::oLedit1 VAR "editado42" OF Self SIZE 160, 24' "$RUN/Form1.prg" || \
  { echo "--- LABELEDEDIT lines ---"; grep LABELEDEDIT "$RUN/Form1.prg"; fail "edited VAR text not saved to disk"; }
echo "edited VAR text saved: $(grep 'LABELEDEDIT ::' "$RUN/Form1.prg" | head -1)"

rt_reopen_project
sleep 1
xdotool windowmove "$RT_DESIGNER" 200 150; sleep 0.5   # reopen kept the parked position
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/edit_reopen.png 2>/dev/null
tesseract /tmp/edit_reopen.png - 2>/dev/null | grep -q "editado42" || fail "edited text not rendered in designer after reopen"
grep -q 'VAR "editado42"' "$RUN/Form1.prg" || fail "edited text lost from file after reopen"
echo "edited text survives reopen and renders in the designer"
rt_cleanup
echo "LABELEDEDIT_EDIT PASS: code-edit of LABELEDEDIT VAR -> sync -> save -> reopen all faithful"
