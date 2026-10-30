#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/debug_object_gui
rt_provenance
mkdir -p "$RUN" /tmp/hbbuilder_debug
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
rm -f /tmp/debugmodules-result.txt
if [ -f /tmp/hbbuilder_debug/gtk3_inspector.o ]; then rm /tmp/hbbuilder_debug/gtk3_inspector.o; fi
mkdir -p /tmp/hbbuilder_debug/gtk3_inspector.o
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"
xdotool mousemove 15 62 click 1
sleep 9
import -window root /tmp/debug-object-refused.png
text=$(tesseract /tmp/debug-object-refused.png - --psm 6 2>/dev/null)
echo "$text" | grep -E 'Build aborted|inspector' || true
if ! echo "$text" | grep -q 'Build aborted'; then rt_cleanup; echo 'OBJECT GUI FAIL no refusal'; exit 1; fi
[ ! -f /tmp/debugmodules-result.txt ] || { rt_cleanup; exit 1; }
xdotool key Return; sleep 1
rmdir /tmp/hbbuilder_debug/gtk3_inspector.o
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 15 62 click 1
for try in $(seq 1 40); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
if ! grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt 2>/dev/null; then rt_cleanup; echo 'OBJECT GUI FAIL retry'; exit 1; fi
rt_cleanup
echo 'OBJECT GUI PASS refusal before app effect and repaired Debug retry'
