#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap rt_cleanup EXIT
RUN=/tmp/remove_new_designer_gui
mkdir -p "$RUN"
rt_provenance;rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 57 mouseup 1;sleep 2
DES='';ED=''
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in Form2*) DES=$w;;'Code Editor') ED=$w;;esac
done
[ -n "$DES" ]&&[ -n "$ED" ] || { echo 'FAIL designer/editor missing';exit 1; }
xdotool windowmap "$DES";xdotool windowraise "$DES";eval "$(xdotool getwindowgeometry --shell "$DES")"
if [ "${CLEAN:-0}" != 1 ];then xdotool windowsize "$DES" $((WIDTH+33)) "$HEIGHT";fi
sleep 2
xdotool windowmap "$ED";xdotool windowmove "$ED" 0 125;xdotool windowsize "$ED" 1500 820;xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/before"
grep -q TForm2 "$RUN/before" || exit 1
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 217 12 mousedown 1;sleep .5;xdotool mousemove 300 62 mouseup 1;sleep 1
DLG='';for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Remove from Project' ]&&DLG=$w;done
[ -n "$DLG" ]||exit 1
xdotool windowmap "$DLG";xdotool windowraise "$DLG";xdotool windowfocus "$DLG";xdotool key Down Tab Return;sleep 2
DLG='';for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Unsaved changes' ]&&DLG=$w;done
if [ "${CLEAN:-0}" = 1 ];then
 [ -z "$DLG" ] || { echo 'FAIL spurious prompt for unchanged new form';exit 1; }
 echo 'GREEN unchanged new form removed without spurious prompt';exit 0
fi
if [ -z "$DLG" ];then echo 'RED new unsaved designer-resized form removed without consent';import -window root /tmp/new-designer-remove-red.png;exit 1;fi
xdotool windowmap "$DLG";xdotool windowraise "$DLG";eval "$(xdotool getwindowgeometry --shell "$DLG")"
xdotool mousemove $((X+5*WIDTH/6)) $((Y+HEIGHT-20)) click 1;sleep 1
rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/after"
cmp "$RUN/before" "$RUN/after"||exit 1
echo 'GREEN unsaved designer resize protected, Cancel keeps exact Form2 buffer'
import -window root /tmp/new-designer-remove-green.png
