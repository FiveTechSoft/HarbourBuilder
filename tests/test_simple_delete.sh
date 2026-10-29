#!/bin/bash
# Simple designer delete -> save regression (auditor plan-a for R1):
# delete Button1 in the designer, save, and the button's line/DATA/prompt
# must be gone (no verbatim resurrection) with the SAY and the hand-written
# KEEP-ME line intact; the regenerated file must still compile.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_simpledel
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
grep -q 'KEEP-ME: do not delete' "$RUN/Form1.prg" || fail "hand-written marker line lost"
grep -q 'DATA oSay1' "$RUN/Form1.prg" || fail "unrelated SAY DATA lost"
echo "--- resulting Form1.prg ---"; cat "$RUN/Form1.prg"

# Compileability of regenerated code from this fixture family is covered by
# tests/test_roundtrip_runtime.sh (IDE build & run via Ctrl+R) - not duplicated here.

rt_cleanup
echo "SIMPLE_DELETE PASS: designer delete saved without resurrection; unrelated and hand-written lines intact."
