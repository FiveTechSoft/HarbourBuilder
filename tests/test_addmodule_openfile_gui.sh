#!/bin/bash
# Adding a module after an unsaved standalone tab must preserve both texts.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/addmodule_openfile_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
printf 'function Standalone()\nreturn "BASE"\n' > "$RUN/Standalone.prg"
printf 'function NewModule()\nreturn "MODULE-CONTENT"\n' > "$RUN/NewModule.prg"
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 163 mouseup 1;sleep 1
xdotool key ctrl+l;xdotool type --delay 1 "$RUN/Standalone.prg";xdotool key Return;sleep 1;xdotool key Return;sleep 2
for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Code Editor' ] && ED=$w;done
xdotool windowmap "$ED";xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool key ctrl+a
xdotool type --delay 1 'function Standalone()
return "UNSAVED-STANDALONE-WORK"';sleep 1
xdotool key ctrl+a ctrl+c;sleep 1;xclip -selection clipboard -o > "$RUN/before-editor.txt"
grep -q UNSAVED-STANDALONE-WORK "$RUN/before-editor.txt" || exit 1
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 185 12 click 1;sleep 1
import -window root /tmp/addmodule-menu.png
# Stop here if requested, to inspect the actual Project menu before selecting.
if [ "${SCOUT:-0}" = 1 ];then exit 0;fi
xdotool key Escape
# Use the existing OCR menu helper, not an assumed Project menu coordinate.
menu_path_click '^Add Module' '^Project' || { echo 'FAIL Add Module menu missing';exit 1; }
sleep 1;xdotool key ctrl+l;xdotool type --delay 1 "$RUN/NewModule.prg";xdotool key Return;sleep 1;xdotool key Return;sleep 2
rt_map_all;xdotool windowmove "$ED" 0 125;xdotool windowsize "$ED" 1500 820;xdotool windowraise "$ED";xdotool windowfocus "$ED"
import -window root /tmp/addmodule-after.png
# Save tab snapshots by selecting from actual notebook x positions after inspection.
