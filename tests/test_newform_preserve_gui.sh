#!/bin/bash
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/newform_preserve_gui
rm -rf "$RUN";mkdir -p "$RUN";cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
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
 case "$1" in One) X=569;;Two) X=652;;Form2) X=260;;esac
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
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 57 mouseup 1;sleep 2
rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED"
copy_editor form-after;grep -q 'CLASS TForm2 FROM TForm' "$RUN/form-after.txt"
for n in One Two;do select_tab "$n";copy_editor "$n-after";cmp "$RUN/$n-before.txt" "$RUN/$n-after.txt";echo "PRESERVED $n exact unsaved buffer";done
# Save project: modules must route to NewModule, not either standalone buffer.
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
grep -q 'CLASS TForm2 FROM TForm' "$RUN/Form2.prg"
python3 - "$RUN" "$REPO" <<'ORDER'
from pathlib import Path
import sys
p=Path(sys.argv[1]);h=(p/'Project1.hbp').read_text();assert h.index('Form1')<h.index('Form2')<h.index('HelperA')<h.index('HelperB')
for n in ['HelperA','HelperB']:
 assert (p/(n+'.prg')).read_text().replace('\x1a','').strip()==(Path(sys.argv[2])/'tests/fixtures/debugmodules'/(n+'.prg')).read_text().strip()
print('ORDER Form1 Form2 HelperA HelperB, existing source contents intact')
ORDER
grep -q BASE-ONE "$RUN/One.prg";grep -q BASE-TWO "$RUN/Two.prg"
echo 'Project save routes module correctly and leaves standalone disk untouched'
# Close each standalone choosing Save; verify exact destination and buffer.
rt_map_all
for n in Two One;do
 select_tab "$n"
 BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
 xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 187 mouseup 1;sleep 1
 DLG=''
 for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Unsaved changes' ] && DLG=$w;done
 [ -n "$DLG" ] || { echo 'FAIL dirty standalone not protected';exit 1; }
 xdotool windowmap "$DLG";xdotool windowraise "$DLG";eval "$(xdotool getwindowgeometry --shell "$DLG")"
 xdotool mousemove $((X+WIDTH/6)) $((Y+HEIGHT-20)) click 1;sleep 1
 cmp "$RUN/$n-before.txt" "$RUN/$n.prg";echo "CLOSE SAVE $n correct destination exact bytes"
 rt_map_all
done
select_tab Form2;copy_editor form-final;grep -q 'CLASS TForm2 FROM TForm' "$RUN/form-final.txt"
import -window root /tmp/newform-preserved-final.png
echo 'GREEN two dirty standalone files survive New Form insertion, project save and correct Close Save routing'
