#!/bin/bash
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/newform_preserve_gui
mkdir -p "$RUN";cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
printf 'function One()\nreturn "BASE-ONE"\n' > "$RUN/One.prg"
printf 'function Two()\nreturn "BASE-TWO"\n' > "$RUN/Two.prg"
printf 'function NewModule()\nreturn "MODULE-CONTENT"\n' > "$RUN/NewModule.prg"
rt_provenance;rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
open_item(){
 BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
 xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 "$1" mouseup 1;sleep 1
 xdotool key ctrl+l;xdotool type --delay 1 "$RUN/$2.prg";xdotool key Return;sleep 1;xdotool key Return;sleep 2
 for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Code Editor' ] && ED=$w;done
 xdotool windowmap "$ED";xdotool windowmove "$ED" 0 125;xdotool windowsize "$ED" 1500 820;xdotool windowraise "$ED";xdotool windowfocus "$ED"
}
copy_editor(){
 xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+c;sleep 1
 xclip -selection clipboard -o > "$RUN/$1.txt"
 [ -s "$RUN/$1.txt" ]
}
select_tab(){
 xdotool windowraise "$ED";xdotool windowfocus "$ED";sleep .5
 import -window root /tmp/module-tabs.png
 case "$1" in One) X=604;;Two) X=689;;NewModule) X=496;;esac
 Y=142
 [ -n "${X:-}" ] || { echo "FAIL tab absent $1";exit 1; }
 xdotool mousemove "$X" "$Y" click 1;sleep 1
}
for n in One Two;do
 open_item 163 "$n"
 xdotool key ctrl+a;xdotool type --delay 1 "function $n()
return \"UNSAVED-$n\"";sleep 1
 copy_editor "$n-before"
done
# Existing two modules precede two dirty standalone tabs. New Form must
# not replace any of them when inserting the new form before modules.
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 57 mouseup 1;sleep 2
rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED"
import -window root /tmp/newform-after.png
copy_editor active-after
cat "$RUN/active-after.txt" | head -8
# Save project to expose which source path now receives the replaced tab.
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
python3 - "$RUN" <<'CHECK'
from pathlib import Path
import sys
p=Path(sys.argv[1]);h=(p/'HelperA.prg').read_text();print('HelperA after NewForm Save:',repr(h[:150]));assert 'function HelperB()' in h;assert 'UNSAVED-One' in (p/'HelperB.prg').read_text()
print('RED NewForm destroys HelperA buffer, shifts HelperB into HelperA file and unsaved standalone into HelperB file')
CHECK
