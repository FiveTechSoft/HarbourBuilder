#!/bin/bash
# Destructive-save refusal: drop a control the generator cannot serialize
# (Additional palette, "text" = TLabeledEdit, CT 32) onto the fixture form.
# Asserts: (1) the save-abort dialog appears naming the control;
# (2) Form1.prg on disk stays byte-identical; (3) an explicit Ctrl+S after
# the abort is refused too (dialog again, file still identical).
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_refusal
source "$REPO/tests/harness_lib.sh"
fail() { echo "REFUSAL FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
rt_setup "$RUN"
rt_launch_ide
rt_reopen_project          # precondition: project open, designer live

MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
W0=$(rt_ide_windows | tr '\n' ' ')

BAR=$(rt_find_bar)
rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 0.5

# Additional palette tab, then the "text" (TLabeledEdit) component button
read AX AY <<< $(rt_ocr_bar_token '^Additional')
[ -n "${AX:-}" ] || fail "Additional palette tab not found"
xdotool mousemove "$AX" "$AY" click 1; sleep 1
read TX TY <<< $(rt_ocr_bar_token '^text$')
[ -n "${TX:-}" ] || fail "text (TLabeledEdit) component button not found"
xdotool mousemove "$TX" "$TY" click 1; sleep 0.8

eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 2.5

# a modal dialog titled HbBuilder that was not there before the drop
DLG=""
for i in 1 2 3 4 5; do
  for w in $(rt_ide_windows); do
    case " $W0 " in *" $w "*) continue;; esac
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && { DLG=$w; break; }
  done
  [ -n "$DLG" ] && break
  sleep 1
done
[ -n "$DLG" ] || fail "no refusal dialog after dropping an unserializable control"
eval "$(xdotool getwindowgeometry --shell "$DLG")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/refusal-dialog.png
TXT=$(tesseract /tmp/refusal-dialog.png - 2>/dev/null)
echo "dialog OCR: $(echo "$TXT" | tr '\n' ' ')"
echo "$TXT" | grep -qi 'Save aborted' || fail "dialog is not the save-abort notice"
echo "$TXT" | grep -qE 'type (32|S2)' || fail "dialog does not name the control type"
MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
[ "$MD0" = "$MD1" ] || fail "Form1.prg changed on disk after the refused sync"

# dismiss, then an explicit Ctrl+S must be refused as well
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT-14)) click 1; sleep 1
BAR=$(rt_find_bar)
xdotool windowactivate "$BAR" 2>/dev/null
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+s; sleep 2
DLG2=""
for w in $(xdotool search --pid "$RT_IDEPID" 2>/dev/null); do
  [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && \
    xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && { DLG2=$w; break; }
done
[ -n "$DLG2" ] || fail "explicit Ctrl+S after the abort was not refused"
eval "$(xdotool getwindowgeometry --shell "$DLG2")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/refusal-dialog-ctrls.png
TXT2=$(tesseract /tmp/refusal-dialog-ctrls.png - 2>/dev/null)
echo "$TXT2" | grep -qi 'Save aborted' || fail "second dialog is not the save-abort notice"
MD2=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
[ "$MD0" = "$MD2" ] || fail "Form1.prg changed on disk after the refused Ctrl+S"

rt_cleanup
echo "REFUSAL PASS: sync abort + explicit save refused, file byte-identical both times."
