#!/bin/bash
# Designer walkthrough probe: drop every Standard visual control on an empty
# form, save, verify every control survives in generated code with a unique
# DATA declaration, reopen, and require a re-save fixpoint.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUN=/tmp/designer_walkthrough
source "$REPO/tests/harness_lib.sh"
fail() { echo "WALKTHROUGH FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - designer walkthrough probe' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - designer walkthrough probe' \
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
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
echo "designer at $X,$Y ${WIDTH}x${HEIGHT}"

# palette icon centers (real screen coords; Standard tab row)
PI_Label=407; PI_Edit=471; PI_Button=532; PI_Memo=594; PI_CheckBox=656
PI_Radio=717; PI_ListBox=779; PI_ComboBox=840; PI_GroupBox=901; PI_Panel=961
PI_ScrollBar=1008

drop() { # $1 icon-x  $2 dx  $3 dy  $4 w  $5 h
  xdotool mousemove "$1" 90 click 1; sleep 1
  xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
  eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
  xdotool mousemove $((X+$2)) $((Y+$3)) mousedown 1; sleep 0.5
  xdotool mousemove $((X+$2+$4)) $((Y+$3+$5)) mouseup 1; sleep 1.5
}

# canvas cells, non-overlapping (offsets include window titlebar)
drop $PI_Label     20  40  90 20
drop $PI_Edit     130  40 140 24
drop $PI_Button   300  40  90 26
drop $PI_CheckBox  20 110 120 22
drop $PI_Radio    160 110 120 22
drop $PI_ListBox   20 170 130 80
drop $PI_ComboBox 170 170 140 24
drop $PI_GroupBox 330 170 170 80
import -window root /tmp/walkthrough-dropped.png

BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3

python3 - "$RUN/Form1.prg" <<'PY'
from pathlib import Path
import re, sys
s = Path(sys.argv[1]).read_text()
at = re.findall(r'@ \d+, \d+ (\w+) ::(\w+)', s)
datas = re.findall(r'DATA (\w+)', s)
print('AT-LINES:', at)
print('DATAS:', datas)
names = [n for _, n in at]
assert len(names) == len(set(names)), f'duplicate control names: {names}'
assert sorted(names) == sorted(datas), f'DATA decls {datas} != created {names}'
cmds = sorted(c for c, _ in at)
print('CMDS:', cmds)
expected = ['BUTTON','CHECKBOX','COMBOBOX','GET','GROUPBOX','LISTBOX','RADIOBUTTON','SAY']
missing = [c for c in expected if c not in cmds]
extra = [c for c in cmds if c not in expected]
print('MISSING:', missing, 'EXTRA:', extra)
assert len(at) == 8, f'expected 8 controls, got {len(at)}'
PY
[ $? = 0 ] || fail "saved file does not carry all 11 dropped controls"
cp "$RUN/Form1.prg" "$RUN/after-save1.prg"

# reopen and re-save: fixpoint required
rt_cleanup; rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
import -window root /tmp/walkthrough-reopened.png
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
cmp "$RUN/after-save1.prg" "$RUN/Form1.prg" || fail "reopen+save not a fixpoint"
echo "WALKTHROUGH PROBE PASS"
rt_cleanup
