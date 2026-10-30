#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/debugmodules_gui
rt_provenance
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
rm -f /tmp/debugmodules-result.txt
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"
xdotool mousemove 15 62 click 1
sleep 30
for w in $(rt_ide_windows); do xdotool windowmap "$w"; done
import -window root /tmp/debugmodules-paused.png
printf 'debug source modules: '
grep -n 'function Helper[AB]' /tmp/hbbuilder_debug/debug_main.prg || true
# Keep the run bounded and preserve the paused view before stepping.
for i in $(seq 1 12); do
 xdotool windowraise "$BAR"; xdotool mousemove 90 62 click 1; sleep 0.5
done
import -window root /tmp/debugmodules-stepped.png
if [ ! -x /tmp/hbbuilder_debug/DebugApp ] || [ ! -f /tmp/debugmodules-result.txt ]; then
 echo 'DEBUG MODULE GUI FAIL: executable/result missing'; rt_cleanup; exit 1
fi
grep -q 'MODULES-EXECUTED' /tmp/debugmodules-result.txt || { rt_cleanup; exit 1; }
cat /tmp/debugmodules-result.txt
echo 'DEBUG MODULE native build+execution PASS (not breakpoint/navigation)' 
rt_cleanup
