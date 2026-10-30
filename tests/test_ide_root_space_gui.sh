#!/bin/bash
# Launch the real IDE from a copied installation whose root has spaces.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
ORIGINAL_REPO=$REPO
ROOT='/tmp/harbourbuilder installed space'
RUN=/tmp/ide_root_space_gui
mkdir -p "$ROOT/bin" "$RUN"
cp "$REPO/bin/hbbuilder_linux" "$ROOT/bin/"
for p in source include resources images;do ln -sfn "$REPO/$p" "$ROOT/$p";done
for p in libscintilla.so liblexilla.so;do ln -sfn "$REPO/bin/$p" "$ROOT/bin/$p";done
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
rt_provenance
RT_REPO_ABS=$ROOT
trap 'rt_cleanup' EXIT
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
if [ "${MODE:-run}" = debug ];then xdotool mousemove 15 62 click 1;else xdotool key ctrl+r;fi
for try in $(seq 1 70);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*)xdotool windowmap "$w";xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";xdotool windowfocus "$w";xdotool key ctrl+End;;esac
done
sleep 1
import -window root /tmp/ide-root-space.png
tesseract /tmp/ide-root-space.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
if [ "${EXPECT:-red}" = red ];then
 [ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL unexpected app execution';exit 1; }
 grep -Eq 'FAILED|No such file|exited [1-9]' "$RUN/ocr" || { echo 'FAIL compiler failure not observed';exit 1; }
 echo 'RED real IDE relocated to space-containing root cannot build app'
else
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL app did not execute';exit 1; }
 echo "GREEN relocated IDE ${MODE:-run} actual app executed"
fi
