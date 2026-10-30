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
/tmp/harbour-review/bin/linux/gcc/harbour "$RUN/Project1.prg" -n -w -q -I"$REPO/include" -I/tmp/harbour-review/include -o"$RUN/control.c"
EC=$?;echo standalone_compiler_exit=$EC
[ "$EC" = 0 ] || exit 1
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
if [ "${EXPECT:-red}" = failure ];then
 printf '\nthis is invalid Harbour syntax !\n' >> "$RUN/Project1.prg"
fi
rt_reopen_project
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
if [ "${MODE:-run}" = debug ];then xdotool mousemove 15 62 click 1;else xdotool key ctrl+r;fi
for try in $(seq 1 70);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*)xdotool windowmap "$w";xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";xdotool windowfocus "$w";xdotool key ctrl+End;;esac
done
sleep 1;import -window root /tmp/harbour-stdout-gui.png
tesseract /tmp/harbour-stdout-gui.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
grep -q 'Error-count=0' "$RUN/ocr" || { echo 'FAIL diagnostic not visible';exit 1; }
if [ "${EXPECT:-red}" = failure ];then
 [ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL invalid app executed';exit 1; }
 grep -Eq 'exited [1-9]|Error [EF][0-9]' "$RUN/ocr" || { echo 'FAIL real error not observed';exit 1; }
 echo 'Real invalid Harbour compile refused; no app sentinel'
 cp "$REPO/tests/fixtures/debugmodules/Project1.prg" "$RUN/Project1.prg"
 sed -i '1i #stdout Error-count=0 informational build note' "$RUN/Project1.prg"
 rt_map_all;rt_expose_bar;rt_reopen_project
 BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
 if [ "${MODE:-run}" = debug ];then xdotool mousemove 15 62 click 1;else xdotool key ctrl+r;fi
 for try in $(seq 1 70);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL recovery did not execute';exit 1; }
 echo "RECOVERY ${MODE:-run} legitimate stdout app executed"
elif [ "${EXPECT:-red}" = red ];then
 [ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL unexpected execution';exit 1; }
 echo 'RED real Harbour succeeds but IDE rejects harmless stdout text'
else
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL app did not execute';exit 1; }
 echo "GREEN real Harbour stdout preserved and ${MODE:-run} app executed"
fi
