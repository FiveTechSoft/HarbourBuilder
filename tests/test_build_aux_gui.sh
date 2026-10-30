#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/aux_write_gui
rt_provenance
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
B=/tmp/hbbuilder_build/$(printf '%s' "$RUN/Project1.hbp" | md5sum | cut -d' ' -f1)
mkdir -p "$B"
[ ! -f "$B/.srchash" ] || rm "$B/.srchash"
mkdir -p "$B/.srchash"
DIAG=/tmp/hbbuilder_debug_main.prg
[ ! -f "$DIAG" ] || mv "$DIAG" /tmp/aux_diag_backup.prg
mkdir -p "$DIAG"
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
run_app(){
 rm -f /tmp/debugmodules-result.txt
 BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1; xdotool key ctrl+r
 for try in $(seq 1 50); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt 2>/dev/null || { rt_cleanup; exit 1; }
}
run_app
FIRST=$(stat -c %Y "$B/UserApp")
for w in $(rt_ide_windows); do case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*) xdotool windowmap "$w"; xdotool windowmove "$w" 0 125; xdotool windowsize "$w" 1350 700; xdotool windowraise "$w";; esac; done
sleep 1
import -window root /tmp/aux-warning.png
# Compiler log is displayed in the messages panel, scroll to its end if needed.
text=$(tesseract /tmp/aux-warning.png - --psm 6 2>/dev/null)
echo "$text" | grep -E 'WARNING|cache|diagnostic' || true
sleep 2; run_app
SECOND=$(stat -c %Y "$B/UserApp")
[ "$SECOND" -gt "$FIRST" ] || { echo 'AUX GUI FAIL no rebuild after cache write failure'; rt_cleanup; exit 1; }
echo "AUX GUI warning path executed app twice; rebuild mtimes=$FIRST,$SECOND"
rmdir "$B/.srchash" "$DIAG"
[ ! -f /tmp/aux_diag_backup.prg ] || mv /tmp/aux_diag_backup.prg "$DIAG"
run_app
THIRD=$(stat -c %Y "$B/UserApp")
sleep 2; run_app
FOURTH=$(stat -c %Y "$B/UserApp")
[ "$THIRD" = "$FOURTH" ] || { rt_cleanup; exit 1; }
[ -f "$B/.srchash" ] || { rt_cleanup; exit 1; }
rt_cleanup
echo "AUX GUI PASS nonfatal writes, failed cache rebuild, repaired cache hit mtimes=$THIRD,$FOURTH"
