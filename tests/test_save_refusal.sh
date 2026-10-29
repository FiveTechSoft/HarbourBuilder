#!/bin/bash
# Destructive-save refusal: drop a control type the generator cannot
# serialize (Additional palette, "text" = TLabeledEdit, type 22) onto the
# fixture form and verify (a) the save-abort dialog appears naming the
# control and (b) Form1.prg on disk stays byte-identical.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_refusal
GTKROOT=/tmp/gtk-root
export DISPLAY=:99
fail() { echo "REFUSAL FAIL: $1"; exit 1; }

pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1600x1000x24 & sleep 2; }
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
printf 'File1=%s\nFile2=\nFile3=\nFile4=\nFile5=\nFile6=\nFile7=\nFile8=\n' \
  "$RUN/Project1.hbp" > "$REPO/bin/hbbuilder.ini"
pkill -f 'hbbuilder_linux' 2>/dev/null; sleep 1
cd "$REPO/bin"
nohup setsid env DISPLAY=:99 LD_LIBRARY_PATH=.:$GTKROOT/usr/lib/x86_64-linux-gnu \
  GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 \
  ./hbbuilder_linux >/tmp/ide-refusal.log 2>&1 </dev/null &
disown
sleep 7
IDEPID=$(pgrep -f '\./hbbuilder_linux' | head -1)
[ -n "$IDEPID" ] || fail "IDE did not start"

W0=$(xdotool search --pid "$IDEPID" | tr '\n' ' ')
MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)

# Additional palette tab, then the "text" (TLabeledEdit) component button
xdotool mousemove 489 37 click 1; sleep 1
xdotool mousemove 801 79 click 1; sleep 0.8
# drop on the designer form centre
DW=""
for w in $(xdotool search --pid "$IDEPID" 2>/dev/null); do
  t=$(xdotool getwindowname "$w" 2>/dev/null)
  case "$t" in Form1*|*"Fixture Roundtrip"*) DW=$w;; esac
done
[ -n "$DW" ] || fail "designer window not found"
eval "$(xdotool getwindowgeometry --shell "$DW")"
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 2.5

DLG=""
for w in $(xdotool search --pid "$IDEPID"); do
  case " $W0 " in *" $w "*) ;; *) DLG=$w;; esac
done
[ -n "$DLG" ] || fail "no refusal dialog appeared"
eval "$(xdotool getwindowgeometry --shell "$DLG")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/refusal-dialog.png
TXT=$(tesseract /tmp/refusal-dialog.png - 2>/dev/null)
echo "$TXT" | grep -qi 'Save aborted' || fail "dialog is not the save-abort notice"
echo "$TXT" | grep -qi 'type 32' || fail "dialog does not name the control"
MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
[ "$MD0" = "$MD1" ] || fail "Form1.prg changed on disk"
xdotool key Return; sleep 0.5
pkill -f '\./hbbuilder_linux' 2>/dev/null
echo "REFUSAL PASS: save aborted with explanation; file byte-identical."
