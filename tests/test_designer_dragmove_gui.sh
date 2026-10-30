#!/bin/bash
# Drag-move walkthrough: drop a button, drag it to a new position, save,
# reopen, and require the moved position to persist (and re-save fixpoint).
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUN=/tmp/designer_dragmove
source "$REPO/tests/harness_lib.sh"
fail() { echo "DRAGMOVE FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - drag-move probe' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - drag-move probe' \
  '//--------------------------------------------------------------------' \
  '' \
  'CLASS TForm1 FROM TForm' \
  '' \
  '   // IDE-managed Components' \
  '' \
  '   // Event handlers' \
  '' \
  '   METHOD CreateForm()' \
  '' \
  'ENDCLASS' \
  '//--------------------------------------------------------------------' \
  '' \
  'METHOD CreateForm() CLASS TForm1' \
  '' \
  '   ::cTitle  := "Form1"' \
  '   ::nLeft   := 200' \
  '   ::nTop    := 100' \
  '   ::nWidth  := 700' \
  '   ::nHeight := 600' \
  '' \
  'Return Nil' > "$RUN/Form1.prg"

rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar)
rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 1

# drop button at canvas (20,40) size 90x26 (window-relative offsets)
xdotool mousemove 532 90 click 1; sleep 1
xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
xdotool mousemove $((X+20)) $((Y+40)) mousedown 1; sleep 0.5
xdotool mousemove $((X+110)) $((Y+66)) mouseup 1; sleep 1.5

# drag the button from its center (65,53) to (300,300)
xdotool mousemove $((X+65)) $((Y+53)) mousedown 1; sleep 0.5
xdotool mousemove $((X+200)) $((Y+180)) sleep 0.3
xdotool mousemove $((X+345)) $((Y+313)) mouseup 1; sleep 1.5
import -window root /tmp/dragmove-after.png

BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3

python3 - "$RUN/Form1.prg" <<'PY'
from pathlib import Path
import re, sys
s = Path(sys.argv[1]).read_text()
m = re.search(r'@ (\d+), (\d+) BUTTON ::(\w+)', s)
print('BUTTON-LINE:', m.group(0) if m else None)
assert m, 'button missing after save'
top, left = int(m.group(1)), int(m.group(2))
print('position:', top, left)
# dropped at (40,20); dragged by (+280,+260) => expect around (300,300)
assert abs(top - 300) <= 12 and abs(left - 300) <= 12, f'button did not move with the drag: @ {top}, {left}'
PY
[ $? = 0 ] || fail "drag-move did not persist to saved code"
cp "$RUN/Form1.prg" "$RUN/after-save1.prg"

rt_cleanup; rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
cmp "$RUN/after-save1.prg" "$RUN/Form1.prg" || fail "reopen+save not a fixpoint after drag-move"
echo "DRAGMOVE PROBE PASS"
rt_cleanup
