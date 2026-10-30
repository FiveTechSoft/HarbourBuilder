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
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 79 mouseup 1
sleep 1;xdotool key ctrl+l;xdotool type --delay 1 "$RUN/NewModule.prg";xdotool key Return;sleep 1;xdotool key Return;sleep 2
rt_map_all;xdotool windowmove "$ED" 0 125;xdotool windowsize "$ED" 1500 820;xdotool windowraise "$ED";xdotool windowfocus "$ED"
import -window root /tmp/addmodule-after.png
# Save tab snapshots by selecting from actual notebook x positions after inspection.
xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/slot5-after.txt"
xdotool mousemove 530 142 click 1;sleep 1;xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 350 250 click 1
printf CLIPBOARD-UNCHANGED | xclip -selection clipboard
xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/slot6-after.txt"
python3 - "$RUN" <<'CHECK'
from pathlib import Path
import sys
p=Path(sys.argv[1]);a=(p/'before-editor.txt').read_text();b=(p/'slot5-after.txt').read_text();c=(p/'slot6-after.txt').read_text()
assert 'UNSAVED-STANDALONE-WORK' in a
print('BEFORE standalone bytes',len(a))
print('AFTER old standalone tab content:',repr(b))
print('AFTER appended tab clipboard:',repr(c))
assert 'MODULE-CONTENT' in b,'module did not replace old standalone tab'
assert 'UNSAVED-STANDALONE-WORK' not in b+c,'unexpected preservation'
print('RED module add overwrites dirty standalone editor slot and appends empty tab')
CHECK
