#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/staging_refusal_gui
rt_provenance
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
B=/tmp/hbbuilder_build/$(printf '%s' "$RUN/Project1.hbp" | md5sum | cut -d' ' -f1)
D=/tmp/hbbuilder_debug
for dir in "$B" "$D"; do
 mkdir -p "$dir"
 if [ -f "$dir/Project1.prg" ]; then rm "$dir/Project1.prg"; fi
 mkdir -p "$dir/Project1.prg"
done
rm -f /tmp/debugmodules-result.txt
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
for mode in run debug; do
 BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"
 if [ "$mode" = run ]; then xdotool mousemove 700 12 click 1; xdotool key ctrl+r
 else xdotool mousemove 15 62 click 1; fi
 sleep 3
 import -window root "/tmp/staging-${mode}.png"
 text=$(tesseract "/tmp/staging-${mode}.png" - --psm 6 2>/dev/null)
 echo "$text" | grep -E 'Build aborted|Project1|compiler' || true
 if ! echo "$text" | grep -q 'Build aborted'; then echo "GUI WRITE FAIL: no refusal $mode"; rt_cleanup; exit 1; fi
 if [ -f /tmp/debugmodules-result.txt ]; then echo 'GUI WRITE FAIL: app ran'; rt_cleanup; exit 1; fi
 echo "GUI WRITE $mode refused, no app result"
 xdotool key Return; sleep 1
 import -window root "/tmp/staging-${mode}-dismissed.png"
 if tesseract "/tmp/staging-${mode}-dismissed.png" - --psm 6 2>/dev/null | grep -q 'Saving project files'; then
 echo 'GUI WRITE FAIL: progress remained after dismiss'; rt_cleanup; exit 1
 fi
 echo "GUI WRITE $mode modal dismissed, no saving-progress text"
done
for dir in "$B" "$D"; do rmdir "$dir/Project1.prg"; done
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"
xdotool mousemove 700 12 click 1; xdotool key ctrl+r
for try in $(seq 1 60); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
if ! grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt 2>/dev/null; then
 echo 'GUI WRITE FAIL: repaired Run retry did not execute'; rt_cleanup; exit 1
fi
echo 'GUI WRITE repaired Run retry executed MODULES-EXECUTED'
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"
xdotool mousemove 15 62 click 1
for try in $(seq 1 40); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
if ! grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt 2>/dev/null; then
 echo 'GUI WRITE FAIL: repaired Debug retry did not execute'; rt_cleanup; exit 1
fi
echo 'GUI WRITE repaired Debug retry executed MODULES-EXECUTED'
rt_cleanup
echo 'GUI WRITE REFUSAL PASS: Run and Debug, dismissed progress and repaired retry' 
