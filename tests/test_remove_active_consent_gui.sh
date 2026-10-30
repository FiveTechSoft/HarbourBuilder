#!/bin/bash
# Dirty target removal consent, save refusal, and unrelated-buffer preservation.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/remove_active_module_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
printf 'function Standalone()\nreturn "BASE"\n' > "$RUN/Standalone.prg"
printf 'function NewModule()\nreturn "MODULE-CONTENT"\n' > "$RUN/NewModule.prg"
cp "$RUN/Project1.hbp" "$RUN/hbp-before"
TARGET=${TARGET:-module}
NAME=HelperA;TAB_X=265
if [ "$TARGET" = form ];then NAME=Form1;TAB_X=160;fi
cp "$RUN/$NAME.prg" "$RUN/disk-before"
cp "$RUN/HelperB.prg" "$RUN/other-before"
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
# Select module HelperA and make a real unsaved edit before removing it.
xdotool windowmove "$ED" 0 125;xdotool windowsize "$ED" 1500 820;xdotool windowraise "$ED";xdotool windowfocus "$ED"
xdotool mousemove "$TAB_X" 142 click 1;sleep 1
xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 350 250 click 1
if [ "$TARGET" = form ];then
 cat "$RUN/Form1.prg" > "$RUN/edit-input"
 printf '\n// UNSAVED-MODULE-WORK\n' >> "$RUN/edit-input"
 xclip -selection clipboard -i "$RUN/edit-input"
else
 printf 'function HelperA()\nreturn "UNSAVED-MODULE-WORK"\n' | xclip -selection clipboard
fi
xdotool key ctrl+a ctrl+v;sleep 1;xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/module-before.txt"
grep -q UNSAVED-MODULE-WORK "$RUN/module-before.txt" || exit 1
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 217 12 mousedown 1;sleep .5;xdotool mousemove 300 62 mouseup 1;sleep 1
for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Remove from Project' ] && DLG=$w;done
[ -n "${DLG:-}" ] || exit 1
xdotool windowmap "$DLG";xdotool windowraise "$DLG";xdotool windowfocus "$DLG";if [ "$TARGET" = module ];then xdotool key Down;fi
xdotool key Tab Return;sleep 2
DLG=''
for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Unsaved changes' ] && DLG=$w;done
[ -n "$DLG" ] || { echo 'FAIL unsaved prompt absent';exit 1; }
xdotool windowmap "$DLG";xdotool windowraise "$DLG";eval "$(xdotool getwindowgeometry --shell "$DLG")"
import -window root /tmp/remove-consent-prompt.png
if [ "${CHOICE:-cancel}" = failure ];then printf '\n// EXTERNAL-WORK\n' >> "$RUN/$NAME.prg";fi
case "${CHOICE:-cancel}" in save|failure) K=1;;discard) K=3;;cancel) K=5;;esac
xdotool mousemove $((X+K*WIDTH/6)) $((Y+HEIGHT-20)) click 1;sleep 2
rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED"
if [ "${CHOICE:-cancel}" = failure ];then
 for w in $(rt_ide_windows);do
  if [ "$(xdotool getwindowname "$w")" = HbBuilder ];then xdotool windowmap "$w";xdotool windowraise "$w";xdotool windowfocus "$w";xdotool key Return;fi
 done
 rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool key ctrl+a ctrl+c;sleep 1
 xclip -selection clipboard -o > "$RUN/module-after.txt"
 cmp "$RUN/module-before.txt" "$RUN/module-after.txt" || exit 1
 cmp "$RUN/hbp-before" "$RUN/Project1.hbp" || exit 1
 grep -q EXTERNAL-WORK "$RUN/$NAME.prg" || exit 1
 echo 'SAVE refusal aborts removal; buffer HBP and external disk preserved'
elif [ "${CHOICE:-cancel}" = cancel ];then
 xdotool key ctrl+a ctrl+c;sleep 1;xclip -selection clipboard -o > "$RUN/module-after.txt"
 cmp "$RUN/module-before.txt" "$RUN/module-after.txt" || exit 1
 cmp "$RUN/hbp-before" "$RUN/Project1.hbp" || exit 1
 cmp "$RUN/disk-before" "$RUN/$NAME.prg" || exit 1
 echo 'CANCEL preserves exact unsaved module buffer HBP disk'
else
 if [ "$CHOICE" = save ];then grep -q UNSAVED-MODULE-WORK "$RUN/$NAME.prg" || exit 1;echo 'SAVE before removal persisted module edit';else
  ! grep -q UNSAVED-MODULE-WORK "$RUN/$NAME.prg" || exit 1;echo 'DISCARD explicitly removed edit without disk write'
 fi
fi
# Check the actual notebook header, not generated main (modules are not emitted there).
xdotool windowmap "$ED";xdotool windowraise "$ED";xdotool windowfocus "$ED"
xdotool windowmove "$ED" 0 125;xdotool windowsize "$ED" 1500 820;sleep 1
import -window root -crop 1500x40+0+125 "$RUN/tabs.png"
tesseract "$RUN/tabs.png" "$RUN/tabs" 2>/dev/null
cat "$RUN/tabs.txt"
if [ "${CHOICE:-cancel}" = cancel ] || [ "${CHOICE:-cancel}" = failure ];then
 grep -Eq "${NAME/1/[1l]}.prg" "$RUN/tabs.txt" || exit 1
else
 ! grep -Eq "${NAME/1/[1l]}.prg" "$RUN/tabs.txt" || exit 1
fi
cmp "$RUN/other-before" "$RUN/HelperB.prg" || exit 1
# Locate standalone by OCR in actual geometry after any shifting.
if [ "${CHOICE:-cancel}" = cancel ] || [ "${CHOICE:-cancel}" = failure ];then SX=493;else SX=387;fi
xdotool mousemove "$SX" 142 click 1;sleep 1;xdotool windowfocus "$ED";xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > "$RUN/standalone-after"
cmp "$RUN/before-editor.txt" "$RUN/standalone-after" || exit 1
echo "TARGET=$TARGET CHOICE=${CHOICE:-cancel}: notebook membership and unrelated dirty standalone preserved"
import -window root /tmp/remove-consent-after.png
cp /tmp/remove-consent-after.png "/tmp/remove-$TARGET-${CHOICE:-cancel}-after.png"
