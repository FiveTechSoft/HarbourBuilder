#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/openfile_conflict_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
printf 'function Standalone()\nreturn "BASE"\n' > "$RUN/Standalone.prg"
cp "$RUN/Standalone.prg" "$RUN/baseline.prg"
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 163 mouseup 1
sleep 1
xdotool key ctrl+l;xdotool type --delay 1 "$RUN/Standalone.prg";xdotool key Return;sleep 1;xdotool key Return
sleep 2
for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Code Editor' ] && ED=$w;done
xdotool windowmap "$ED";xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool key ctrl+a
xdotool type --delay 2 'function Standalone()
return "UNSAVED-EDITOR-WORK"'
sleep 1
xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/editor.txt"
grep -q UNSAVED-EDITOR-WORK "$RUN/editor.txt" || exit 1
if [ "${CONFLICT:-changed}" = missing ];then rm "$RUN/Standalone.prg";else
 printf 'function Standalone()\nreturn "EXTERNAL-NEW-WORK"\n' > "$RUN/Standalone.prg"
fi
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
if [ "${ACTION:-close}" = new ];then xdotool key ctrl+n;else
 xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 187 mouseup 1
fi
sleep 1
for w in $(rt_ide_windows);do echo "window $w $(xdotool getwindowname "$w")";done
import -window root /tmp/openfile-close-choice.png
tesseract /tmp/openfile-close-choice.png - --psm 6 2>/dev/null
rt_map_all;sleep 1
# Standard Yes/No/Cancel question: select Yes to save the editor buffer.
for w in $(rt_ide_windows);do
 if [ "$(xdotool getwindowname "$w")" = 'Unsaved changes' ];then
  xdotool windowmap "$w";xdotool windowraise "$w";eval "$(xdotool getwindowgeometry --shell "$w")"
  xdotool mousemove $((X+WIDTH/6)) $((Y+HEIGHT-20)) click 1
 fi
done
sleep 2
# Conflict must preserve raw disk and leave standalone tab/editor open.
if [ "${CONFLICT:-changed}" = missing ];then [ ! -e "$RUN/Standalone.prg" ]||exit 1;else
 grep -q EXTERNAL-NEW-WORK "$RUN/Standalone.prg"||exit 1
fi
for w in $(rt_ide_windows);do
 if [ "$(xdotool getwindowname "$w")" = HbBuilder ];then
  xdotool windowmap "$w";xdotool windowmove "$w" 200 200;xdotool windowraise "$w"
 fi
done
import -window root /tmp/openfile-conflict-refusal.png
tesseract /tmp/openfile-conflict-refusal.png - --psm 6 2>/dev/null | tee "$RUN/refusal-ocr"
tesseract /tmp/openfile-conflict-refusal.png - --psm 11 2>/dev/null | grep -q 'Save refused'||exit 1
for w in $(rt_ide_windows);do
 [ "$(xdotool getwindowname "$w")" = HbBuilder ] && { xdotool windowfocus "$w";xdotool key Return; }
done
rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/editor-after.txt"
[ -s "$RUN/editor-after.txt" ] && cmp "$RUN/editor.txt" "$RUN/editor-after.txt" || exit 1
echo "GREEN conflict ${CONFLICT:-changed} action=${ACTION:-close} disk preserved editor nonempty exact tab open"
# Restore exact original disk bytes to settle external conflict; retry closes/saves.
cp "$RUN/baseline.prg" "$RUN/Standalone.prg"
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 187 mouseup 1;sleep 1
for w in $(rt_ide_windows);do
 if [ "$(xdotool getwindowname "$w")" = 'Unsaved changes' ];then
  xdotool windowmap "$w";xdotool windowraise "$w";eval "$(xdotool getwindowgeometry --shell "$w")"
  xdotool mousemove $((X+WIDTH/6)) $((Y+HEIGHT-20)) click 1
 fi
done
sleep 1
grep -q UNSAVED-EDITOR-WORK "$RUN/Standalone.prg"||exit 1
echo 'GREEN recovery Close Save writes editor after exact disk restoration'
