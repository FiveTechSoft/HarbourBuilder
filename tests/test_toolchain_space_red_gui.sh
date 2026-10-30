#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/toolchain_space_gui
mkdir -p "$RUN" '/tmp/hb home gui'
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
ln -sfn /tmp/harbour-review '/tmp/hb home gui/harbour'
export HOME='/tmp/hb home gui'
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+r
sleep 7
[ ! -f /tmp/debugmodules-result.txt ] || { echo 'Unexpected app executed';exit 1; }
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*)xdotool windowmap "$w";xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";;esac
done
sleep 1
import -window root /tmp/toolchain-space-red.png
tesseract /tmp/toolchain-space-red.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
grep -Eq 'exited 127|/tmp/hb.*not found' "$RUN/ocr" || { echo 'FAIL RED not seen';exit 1; }
echo 'RED native IDE Run toolchain installed in HOME with spaces failed; noapp'
