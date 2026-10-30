#!/bin/bash
# Real Harbour #stdout output is data, not a compilation status.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/harbour_stdout_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
sed -i '1i #stdout Error-count=0 informational build note' "$RUN/Project1.prg"
rt_provenance
/tmp/harbour-review/bin/linux/gcc/harbour "$RUN/Project1.prg" -n -w -q -I"$REPO/include" -o"$RUN/control.c"
EC=$?;echo standalone_compiler_exit=$EC
[ "$EC" = 0 ] || exit 1
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
if [ "${MODE:-run}" = debug ];then xdotool mousemove 15 62 click 1;else xdotool key ctrl+r;fi
for try in $(seq 1 35);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*)xdotool windowmap "$w";xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";xdotool windowfocus "$w";xdotool key ctrl+End;;esac
done
sleep 1;import -window root /tmp/harbour-stdout-gui.png
tesseract /tmp/harbour-stdout-gui.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
grep -q 'Error-count=0' "$RUN/ocr" || { echo 'FAIL diagnostic not visible';exit 1; }
if [ "${EXPECT:-red}" = red ];then
 [ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL unexpected execution';exit 1; }
 echo 'RED real Harbour succeeds but IDE rejects harmless stdout text'
else
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL app did not execute';exit 1; }
 echo "GREEN real Harbour stdout preserved and ${MODE:-run} app executed"
fi
