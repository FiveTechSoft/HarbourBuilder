#!/bin/bash
# Simple designer delete -> save regression (auditor plan-a for R1):
# delete Button1 in the designer, save, and the button's line/DATA/prompt
# must be gone (no verbatim resurrection) with the SAY and the hand-written
# KEEP-ME line intact; the regenerated file must still compile.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_class_adddel
source "$REPO/tests/harness_lib.sh"
fail() { echo "SIMPLE_DELETE FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
# Minimal fixture: one deletable button + one SAY + a hand-written line,
# and a large empty canvas so the rubber-band cannot clip other controls.
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - fixture delete-abort-save test' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oApp:cTitle := "Del Abort Save"' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - fixture delete-abort-save test' \
  '//--------------------------------------------------------------------' \
  '' \
  'CLASS TForm1 FROM TForm' \
  '' \
  '   // IDE-managed Components' \
  '   DATA oButton1   // TButton' \
  '   DATA oSay1      // TLabel' \
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
  '   ::nTop    := 150' \
  '   ::nWidth  := 520' \
  '   ::nHeight := 420' \
  '' \
  '   @ 20, 20 BUTTON ::oButton1 PROMPT "Aceptar" OF Self SIZE 110, 30' \
  '   @ 60, 20 SAY ::oSay1 PROMPT "Entra un numero:" SIZE 140, 24' \
  '' \
  '   // hand-written marker line that must survive every regeneration' \
  '   // KEEP-ME: do not delete' \
  '' \
  'Return Nil' > "$RUN/Form1.prg"
python3 - "$RUN/Form1.prg" <<'PY2'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text().replace('   // IDE-managed Components','   // USER-CLASS-KEEP\n   DATA nCounter INIT 42 // KEEP-COUNTER\n   // IDE-managed Components',1);p.write_text(s)
PY2
rt_setup "$RUN"
rt_launch_ide
rt_reopen_project

MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
BAR=$(rt_find_bar)
rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 0.5

ocr_root() {
  local png=/tmp/sd_$$.png
  import -window root "$png" 2>/dev/null
  tesseract "$png" - tsv 2>/dev/null | \
    awk -F'\t' -v re="$1" \
      '$12 ~ re && $9+0 > 3 && $10+0 > 3 && $11+0 > 25 {printf "%d %d\n", $7+$9/2, $8+$10/2; exit}'
  rm -f "$png"
}

BX=""
for i in 1 2 3 4; do
  read BX BY <<< $(ocr_root '^Aceptar$')
  [ -n "${BX:-}" ] && break
  sleep 1
done
[ -n "${BX:-}" ] || fail "could not OCR Button1 prompt 'Aceptar'"
echo "Button1 at $BX,$BY (active=$(xdotool getactivewindow 2>/dev/null || echo none))"
xdotool mousemove "$BX" "$BY" click 1; sleep 1
echo "after click active=$(xdotool getactivewindow 2>/dev/null || echo none)"
xdotool key Delete; sleep 2
read BX2 BY2 <<< $(ocr_root '^Aceptar$')
[ -z "${BX2:-}" ] || fail "Button1 prompt still visible after Delete (key not delivered or delete failed)"
echo "Button1 deleted from designer (prompt gone; active=$(xdotool getactivewindow 2>/dev/null || echo none))"

# save via the main bar, using its live geometry (WM decorations safe)
eval "$(xdotool getwindowgeometry --shell "$BAR")"
xdotool mousemove $((X+700)) $((Y+12)) click 1; sleep 0.5
xdotool key ctrl+s; sleep 2.5

MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
[ "$MD1" != "$MD0" ] || fail "save did not write the file"
grep -q 'BUTTON ::oButton1' "$RUN/Form1.prg" && fail "deleted button line still present after save"
grep -q 'DATA oButton1' "$RUN/Form1.prg" && fail "deleted button DATA still present after save"
grep -q 'Aceptar' "$RUN/Form1.prg" && fail "deleted button prompt still present after save"
grep -q 'Entra un numero:' "$RUN/Form1.prg" || fail "unrelated SAY line lost"
grep -q 'SAY ::oSay1 PROMPT "Entra un numero:" OF Self SIZE 140, 24' "$RUN/Form1.prg" || \
  fail "SAY height lost on save (expected SIZE 140, 24 preserved)"
grep -q 'KEEP-ME: do not delete' "$RUN/Form1.prg" || fail "hand-written marker line lost"
grep -q 'DATA oSay1' "$RUN/Form1.prg" || fail "unrelated SAY DATA lost"
echo "--- resulting Form1.prg ---"; cat "$RUN/Form1.prg"

# Post-delete syntax check of THE SAVED FILE itself (harbour compiler
# with the hbbuilder.ch command definitions pre-included).
HARBOUR=${HARBOUR:-/tmp/harbour-review/bin/linux/gcc/harbour}
HB_INC=${HB_INC:-/tmp/harbour-review/include}
"$HARBOUR" -n2 -q -w -es2 -i"$REPO/include" -i"$HB_INC" \
  -u+"$REPO/include/hbbuilder.ch" "$RUN/Form1.prg" -o/tmp/rt_simpledel_syntax.hrb \
  && echo "post-delete syntax check: OK" || fail "post-delete Form1.prg has syntax errors"

# Add one button through the Standard palette, then save twice and reopen.
BAR=$(rt_find_bar); rt_map_all
for w in $(rt_ide_windows); do
 t=$(xdotool getwindowname "$w")
 echo "add setup window $w $t"
 case "$t" in *Palette*|*Components*) xdotool windowmove "$w" 320 25;xdotool windowraise "$w";; esac
done
sleep 1
read PX PY <<< $(rt_ocr_bar_token '^Standard$')
[ -n "${PX:-}" ] || fail "Standard palette not visible"
xdotool mousemove "$PX" "$PY" click 1
sleep 1
# Standard palette BUTTON is the third icon at x451.
xdotool mousemove 450 76 click 1
sleep 1
xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
xdotool mousemove $((X+260)) $((Y+220)) click 1
sleep 2
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
python3 - "$RUN/Form1.prg" <<'PY2'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text();decl=re.findall(r'DATA (oButton\w*)',s);created=re.findall(r'BUTTON ::(oButton\w*)',s)
assert len(created)==1,(decl,created)
assert decl==created,(decl,created)
assert 'DATA nCounter INIT 42 // KEEP-COUNTER' in s
assert '// USER-CLASS-KEEP' in s
print('GUI add/delete declarations unique and custom DATA/comment preserved',decl,created)
PY2
[ "$?" = 0 ] || fail "added button duplicate or lost custom declaration"
cp "$RUN/Form1.prg" "$RUN/after.prg"
rt_cleanup
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
python3 - "$RUN" <<'PY2'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);s=(p/'Form1.prg').read_text();a=(p/'after.prg').read_text()
assert s==a,'not fixpoint after reopening'
print('GUI add/delete reopened save fixpoint PASS')
PY2
[ "$?" = 0 ] || fail "reopen changed saved file"
rt_cleanup
echo "CLASS ADD DELETE GUI PASS"
