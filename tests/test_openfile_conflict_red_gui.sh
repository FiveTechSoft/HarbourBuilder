#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/openfile_conflict_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
printf 'function Standalone()\nreturn "BASE"\n' > "$RUN/Standalone.prg"
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
menu_path_click '^Open$' || exit 1
sleep 1
xdotool key ctrl+l;xdotool type --delay 1 "$RUN/Standalone.prg";xdotool key Return
sleep 2
for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Code Editor' ] && ED=$w;done
xdotool windowmap "$ED";xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool key ctrl+a
xdotool type --delay 2 'function Standalone()
return "UNSAVED-EDITOR-WORK"'
sleep 1
xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/editor.txt"
grep -q UNSAVED-EDITOR-WORK "$RUN/editor.txt" || exit 1
printf 'function Standalone()\nreturn "EXTERNAL-NEW-WORK"\n' > "$RUN/Standalone.prg"
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
menu_path_click '^Close$' || exit 1
sleep 1
for w in $(rt_ide_windows);do echo "window $w $(xdotool getwindowname "$w")";done
import -window root /tmp/openfile-close-choice.png
tesseract /tmp/openfile-close-choice.png - --psm 6 2>/dev/null
# Standard Yes/No/Cancel question: select Yes to save the editor buffer.
xdotool key alt+y;sleep 2
cat "$RUN/Standalone.prg"
if grep -q UNSAVED-EDITOR-WORK "$RUN/Standalone.prg";then echo 'RED external standalone work overwritten on Close->Save';exit 0;fi
echo 'RED not reproduced';exit 1
