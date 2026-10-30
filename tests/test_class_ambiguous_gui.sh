#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/class_ambiguous_gui
export CLASS_CASE=${CLASS_CASE:-compound}
rt_provenance
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
python3 - "$RUN/Form1.prg" <<'PY'
from pathlib import Path
import sys,os
p=Path(sys.argv[1]);s=p.read_text();s=s.replace('   DATA oButton1   // TButton','   DATA oOther, oButton1 INIT nil // AMBIGUOUS-USER\n   DATA oKeep INIT 42 // USER-KEEP',1)

if os.environ['CLASS_CASE']=='missing':s=s.replace('ENDCLASS','// USER removed boundary',1)
p.write_text(s)
PY
rm -f /tmp/debugmodules-result.txt
MD=$(sha256sum "$RUN/Form1.prg" | cut -d' ' -f1)
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
for mode in sync save saveas run debug;do
 W0=$(rt_ide_windows | tr '\n' ' ')
 BAR=$(rt_find_bar)
 if [ "$mode" = sync ];then
  DESIGN=$(rt_find_designer)
  xdotool mousemove 532 90 click 1
  xdotool windowraise "$DESIGN";eval "$(xdotool getwindowgeometry --shell "$DESIGN")"
  xdotool mousemove $((X+350)) $((Y+200)) mousedown 1
  xdotool mousemove $((X+430)) $((Y+230)) mouseup 1
 else
  rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
  case "$mode" in save)xdotool key ctrl+s;; saveas)xdotool mousemove 20 12 click 1;sleep 1;xdotool mousemove 100 237 click 1;;run)xdotool key ctrl+r;;debug)xdotool mousemove 15 62 click 1;;esac
 fi
 sleep 2
 import -window root /tmp/class-$mode-refusal.png
 text=$(tesseract /tmp/class-$mode-refusal.png - --psm 6 2>/dev/null)
 echo "$mode: $text" | grep -E 'ambiguous|aborted|faithfully' || true
 echo "$text" | grep -Eq 'ambiguous compound|missing ENDCLASS' || { echo "FAIL $mode no ambiguous notice";rt_cleanup;exit 1; }
 [ "$MD" = "$(sha256sum "$RUN/Form1.prg" | cut -d' ' -f1)" ] || { echo "FAIL $mode disk changed";rt_cleanup;exit 1; }
 [ ! -f /tmp/debugmodules-result.txt ] || { echo "FAIL $mode app executed";rt_cleanup;exit 1; }
 echo "AMBIGUOUS $mode refused; disk exact=$MD no app result"
 rt_cleanup
 rt_setup "$RUN";rt_launch_ide
 for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
 rt_reopen_project
done
rt_cleanup
# Repair ambiguity on disk and reopen, rather than relying on hidden editor state.
python3 - "$RUN/Form1.prg" <<'PY'
from pathlib import Path
import sys,os
p=Path(sys.argv[1]);s=p.read_text().replace('DATA oOther, oButton1 INIT nil','DATA oButton1 INIT nil');s=s.replace('// USER removed boundary','ENDCLASS')
p.write_text(s)
PY
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
[ "$(grep -c 'DATA oButton1' "$RUN/Form1.prg")" = 1 ] || { rt_cleanup;exit 1; }
rm -f /tmp/debugmodules-result.txt
xdotool key ctrl+r
for try in $(seq 1 45);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { rt_cleanup;exit 1; }
rt_cleanup
echo 'AMBIGUOUS recovery save and Run executed PASS'
