#!/bin/bash
# Refusal recovery walkthrough: drop a supported and an unserializable
# control, refuse the save, delete the offending control, save again:
# the supported control must persist and the file must be written.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUN=/tmp/designer_refusal_recovery
source "$REPO/tests/harness_lib.sh"
fail() { echo "RECOVERY FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - refusal recovery probe' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - refusal recovery probe' \
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

drop() { # $1 icon-x  $2 dx  $3 dy  $4 w  $5 h
  xdotool mousemove "$1" 90 click 1; sleep 1
  xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
  eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
  xdotool mousemove $((X+$2)) $((Y+$3)) mousedown 1; sleep 0.5
  xdotool mousemove $((X+$2+$4)) $((Y+$3+$5)) mouseup 1; sleep 1.5
}

W0=" $(rt_ide_windows | tr '\n' ' ') "
drop 532 20 40 90 26     # Button (supported)
drop 594 20 120 160 70   # Memo (type 24, unserializable)
sleep 1

# the drop itself triggers the refusal sync dialog; dismiss every modal
dismiss_all() {
  local w d
  for i in 1 2 3 4 5 6; do
    d=""
    for w in $(rt_ide_windows); do
      case " $W0 " in *" $w "*) continue;; esac
      [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && { d=$w; break; }
    done
    [ -z "$d" ] && return 0
    xdotool windowmap "$d"; xdotool windowraise "$d"; xdotool windowfocus "$d"
    xdotool key Return; sleep 1
  done
  return 1
}
dismiss_all || echo 'note: no drop-time refusal dialog to dismiss'

# select the Memo (click its center) and delete it
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"; xdotool windowfocus "$RT_DESIGNER"
xdotool mousemove $((X+100)) $((Y+155)) click 1; sleep 1
xdotool key Delete; sleep 2
import -window root /tmp/recovery-after-delete.png

BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3

python3 - "$RUN/Form1.prg" <<'PY'
from pathlib import Path
import re, sys
s = Path(sys.argv[1]).read_text()
at = re.findall(r'@ \d+, \d+ (\w+) ::(\w+)', s)
print('AT-LINES:', at)
assert at == [('BUTTON', 'oButton1')], f'expected only the button, got {at}'
assert 'MEMO' not in s.upper() or 'Memo' not in s, 'memo survived save'
print('RECOVERY PASS: refusal cleared after deleting the unserializable control; button saved')
PY
[ $? = 0 ] || fail "save after deleting the unserializable control did not produce exactly the button"
rt_cleanup
