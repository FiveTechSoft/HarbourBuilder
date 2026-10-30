#!/bin/bash
# Real Harbour #stdout output is data, not a compilation status.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/debug_c_warning_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
cat >> "$RUN/Project1.prg" <<'CWARNING'
#pragma BEGINDUMP
#warning error: informational build note
#pragma ENDDUMP
CWARNING
rt_provenance
/tmp/harbour-review/bin/linux/gcc/harbour "$RUN/Project1.prg" -n -w -q -I"$REPO/include" -I/tmp/harbour-review/include -o"$RUN/control.c"
EC=$?;echo standalone_compiler_exit=$EC
[ "$EC" = 0 ] || exit 1
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
if [ "${EXPECT:-red}" = failure ];then
 cat >> "$RUN/Project1.prg" <<'CFAIL'
#pragma BEGINDUMP
#error real_C_failure_fixture
#pragma ENDDUMP
CFAIL
fi
rt_reopen_project
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
if [ "${MODE:-run}" = debug ];then xdotool mousemove 15 62 click 1;else xdotool key ctrl+r;fi
for try in $(seq 1 25);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*)xdotool windowmap "$w";xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";xdotool windowfocus "$w";xdotool key ctrl+End;;esac
done
sleep 1;import -window root /tmp/debug-c-warning-gui.png
tesseract /tmp/debug-c-warning-gui.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
grep -q 'error: informational' "$RUN/ocr" || { echo 'FAIL diagnostic not visible';exit 1; }
if [ "${EXPECT:-red}" = failure ];then
 [ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL invalid C app executed';exit 1; }
 grep -q 'real_C_failure_fixture' "$RUN/ocr" || { echo 'FAIL C failure absent';exit 1; }
 grep -q 'exited 1' "$RUN/ocr" || { echo 'FAIL C status absent';exit 1; }
 echo 'REAL C failure exited1; no app executed'
 sed -i '/#error real_C_failure_fixture/d' "$RUN/Project1.prg"
 rt_map_all;rt_expose_bar;rt_reopen_project
 BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool mousemove 15 62 click 1
 for try in $(seq 1 70);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL recovery app absent';exit 1; }
 echo 'RECOVERY Debug actual app executed with legitimate C warning'
elif [ "${EXPECT:-red}" = red ];then
 [ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL unexpected execution';exit 1; }
 echo 'RED real GCC warning succeeds but Debug IDE rejects harmless error: text'
else
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL app did not execute';exit 1; }
 echo "GREEN real GCC warning preserved and ${MODE:-run} app executed"
fi
