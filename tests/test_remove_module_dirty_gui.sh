#!/bin/bash
# Adding a module after an unsaved standalone tab must preserve both texts.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/remove_module_dirty_gui
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
# Remove HelperA while standalone remains the active editor tab.
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 217 12 mousedown 1;sleep .5
xdotool mousemove 300 62 mouseup 1;sleep 1
for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Remove from Project' ] && DLG=$w;done
[ -n "${DLG:-}" ] || { echo 'FAIL remove dialog absent';exit 1; }
xdotool windowmap "$DLG";xdotool windowraise "$DLG";xdotool windowfocus "$DLG"
# Combo default Form1, next item HelperA.
xdotool key Down Tab Return;sleep 2
rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/after-editor.txt"
import -window root /tmp/remove-module-dirty-after.png
python3 - "$RUN" <<'CHECK'
from pathlib import Path
import sys
p=Path(sys.argv[1]);a=(p/'before-editor.txt').read_text();b=(p/'after-editor.txt').read_text();print('BEFORE',repr(a));print('AFTER',repr(b));assert 'UNSAVED-STANDALONE-WORK' in a;assert a!=b
print('RED removing another module discards active standalone unsaved editor text')
CHECK
