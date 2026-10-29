#!/bin/bash
# Delete -> abort -> resolve -> save.
# Proves the designer-delete record is NOT consumed by an aborted save
# (peek during merge, consume only at apply): delete Button1, explicit save
# refused (unserializable TLabeledEdit dropped first), disk must still
# contain the button line; then remove the cause, save, and the button must
# be gone (no verbatim resurrection) with hand-written lines intact.
# Note: the auto-sync refusal dialog is rate-limited (same refusal set is
# shown once), so the abort is asserted via the explicit bar-focused Ctrl+S
# (lFromSave always warns) plus file immutability, not via a second auto
# dialog.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_das
source "$REPO/tests/harness_lib.sh"
fail() { echo "DEL_ABORT_SAVE FAIL: $1"; rt_cleanup; exit 1; }

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
W0=$(rt_ide_windows | tr '\n' ' ')
BAR=$(rt_find_bar)
rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 0.5

ocr_win() {
  # OCR the full root window and return ABSOLUTE screen coordinates: the
  # designer window position varies between runs, so a stale crop offset is
  # a worse failure mode than a slower full-screen pass. $1 kept for call
  # compatibility; other windows are parked off-screen during this script.
  local png=/tmp/das_win_$$.png
  import -window root "$png" 2>/dev/null
  tesseract "$png" - tsv 2>/dev/null | \
    awk -F'\t' -v re="$2" \
      '$12 ~ re && $9+0 > 3 && $10+0 > 3 && $11+0 > 25 {printf "%d %d\n", $7+$9/2, $8+$10/2; exit}'
  rm -f "$png"
}
wait_dialog() {
  local i w
  for i in 1 2 3 4 5 6; do
    for w in $(xdotool search --pid "$RT_IDEPID" 2>/dev/null); do
      case " $W0 " in *" $w "*) continue;; esac
      [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && \
        xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && { echo "$w"; return 0; }
    done
    sleep 1
  done
  return 1
}
dismiss_dialog() {
  local X Y WIDTH HEIGHT
  eval "$(xdotool getwindowgeometry --shell "$1")"
  xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT-14)) click 1; sleep 1
}
bar_ctrl_s() { # focus the main bar (as test_save_refusal.sh does) then Ctrl+S
  local b; b=$(rt_find_bar)
  xdotool mousemove 700 12 click 1; sleep 0.5
  xdotool key ctrl+s; sleep 2
}

# 1) drop an unserializable TLabeledEdit (Additional palette, "text")
read AX AY <<< $(rt_ocr_bar_token '^Additional')
[ -n "${AX:-}" ] || fail "Additional palette tab not found"
xdotool mousemove "$AX" "$AY" click 1; sleep 1
read TX TY <<< $(rt_ocr_bar_token '^text$')
[ -n "${TX:-}" ] || fail "text (TLabeledEdit) component button not found"
xdotool mousemove "$TX" "$TY" click 1; sleep 0.8
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
# drop into the empty middle of the form (fixture has nothing there), so
# the later rubber-band intersects only this control
DROPX=$((X+250)); DROPY=$((Y+200))
xdotool mousemove "$DROPX" "$DROPY" click 1; sleep 2.5
D=$(wait_dialog) || fail "no abort dialog after dropping unserializable control"
echo "abort-on-drop dialog up (expected)"; dismiss_dialog "$D"
[ "$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)" = "$MD0" ] || fail "file changed after drop abort"

# 2) click Button1 and delete it
BX=""
for i in 1 2 3 4; do
  read BX BY <<< $(ocr_win "$RT_DESIGNER" '^Aceptar$')
  [ -n "${BX:-}" ] && break
  sleep 1
done
if [ -z "${BX:-}" ]; then
  import -window root /tmp/das_fail_root.png 2>/dev/null
  echo "root screenshot saved: /tmp/das_fail_root.png"
  ocr_win "$RT_DESIGNER" '.' | head -1
  tesseract /tmp/das_fail_root.png - tsv 2>/dev/null | awk -F'\t' '$12=="Aceptar" {print "Aceptar on root at",$7,$8}'
  fail "could not OCR Button1 prompt 'Aceptar' on the designer"
fi
echo "Button1 at $BX,$BY"
xdotool mousemove "$BX" "$BY" click 1; sleep 1
echo "pre-btn-delete active=$(xdotool getactivewindow 2>/dev/null || echo none)"
xdotool key Delete; sleep 2.5
import -window root /tmp/das_after_btn_delete.png 2>/dev/null
read BX2 BY2 <<< $(ocr_win "$RT_DESIGNER" '^Aceptar$')
[ -z "${BX2:-}" ] || fail "Button1 still visible after Delete"
echo "Button1 deleted from designer (prompt gone)"

# 3) explicit save must be REFUSED, disk intact, delete record preserved
bar_ctrl_s
D=$(wait_dialog) || fail "explicit Ctrl+S with unserializable control was not refused"
eval "$(xdotool getwindowgeometry --shell "$D")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/das-dialog.png 2>/dev/null
TXT=$(tesseract /tmp/das-dialog.png - 2>/dev/null)
echo "dialog OCR: $(echo "$TXT" | tr '\n' ' ')"
echo "$TXT" | grep -qi 'Save aborted' || fail "dialog is not the save-abort notice"
[ "$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)" = "$MD0" ] || fail "file changed on aborted save"
grep -q 'BUTTON ::oButton1' "$RUN/Form1.prg" || \
  fail "delete record lost on abort: BUTTON ::oButton1 already gone from disk"
dismiss_dialog "$D"
echo "explicit save refused; disk intact; button line still on disk"

# 4) resolve the cause: delete the TLabeledEdit. A plain click does not
# select it (its GtkEntry child consumes the press), so rubber-band it:
# press on empty form space right-below the drop point and drag across the
# control; the release handler selects intersecting controls.
inspector_title() {
  local w t
  for w in $(rt_ide_windows); do
    t=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$t" in "Inspector:"*) echo "$t"; return 0;; esac
  done
}
# Rubber-band the dropped control: press on empty form space right-below
# the drop point and drag across it; the release handler selects every
# intersecting control (a plain click is eaten by the composite's GtkEntry).
SX=$((DROPX+180)); SY=$((DROPY+80)); EX=$((DROPX-20)); EY=$((DROPY-20))
xdotool mousemove "$SX" "$SY" mousedown 1; sleep 0.3
xdotool mousemove $((SX-80)) $((SY-40)); sleep 0.2
xdotool mousemove $((SX-160)) $((SY-80)); sleep 0.2
xdotool mousemove "$EX" "$EY" mouseup 1; sleep 1
T=$(inspector_title); echo "after rubber-band, inspector: $T"
echo "pre-delete active=$(xdotool getactivewindow 2>/dev/null || echo none)"
xdotool key Delete; sleep 2.5
T=$(inspector_title); echo "after cause delete, inspector: $T"
import -window root /tmp/das_after_cause_delete.png 2>/dev/null
echo "screenshot: /tmp/das_after_cause_delete.png"

# 5) save must now apply; both deletions reflected, hand-written lines intact
bar_ctrl_s
if D2=$(wait_dialog); then
  eval "$(xdotool getwindowgeometry --shell "$D2")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/das-dialog2.png 2>/dev/null
  echo "unexpected dialog OCR: $(tesseract /tmp/das-dialog2.png - 2>/dev/null | tr '\n' ' ')"
  fail "save still refused after cause removed"
fi
MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
[ "$MD1" != "$MD0" ] || fail "save after resolving the cause did not write the file"
grep -q 'BUTTON ::oButton1' "$RUN/Form1.prg" && fail "deleted button line still present after save"
grep -q 'DATA oButton1' "$RUN/Form1.prg" && fail "deleted button DATA still present after save"
grep -q 'Aceptar' "$RUN/Form1.prg" && fail "deleted button prompt still present after save"
grep -q 'Entra un numero:' "$RUN/Form1.prg" || fail "unrelated SAY line lost"
grep -q 'KEEP-ME: do not delete' "$RUN/Form1.prg" || fail "hand-written marker line lost"
echo "--- resulting Form1.prg ---"; cat "$RUN/Form1.prg"

rt_cleanup
echo "DEL_ABORT_SAVE PASS: delete record survived the aborted save; final save applied both deletions; hand-written lines intact."
