#!/bin/bash
# A valid project with a gap in form numbers must not reuse an existing name.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/newform_name_gap_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/preclass2/healthy/"* "$RUN/"
python3 - "$RUN" <<'FIX'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=(p/'Form2.prg').read_text().replace('Form2','Form3').replace('PRECLASS-F2','UNIQUE-FORM3-KEEP');(p/'Form3.prg').write_text(s)
(p/'Project1.hbp').write_text('Project1\nForm1\nForm3\n')
FIX
rt_provenance;rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
xdotool mousemove 20 12 mousedown 1;sleep .5;xdotool mousemove 100 57 mouseup 1;sleep 2
rt_map_all
for w in $(rt_ide_windows);do
 [ "$(xdotool getwindowname "$w")" = 'Code Editor' ] && { ED=$w;xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";xdotool windowfocus "$w"; }
done
import -window root /tmp/newform-name-gap.png
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
rt_map_all
for w in $(rt_ide_windows);do
 [ "$(xdotool getwindowname "$w")" = 'Code Editor' ] && { xdotool windowraise "$w";xdotool windowfocus "$w"; }
done
import -window root /tmp/newform-name-gap-after-save.png
tesseract /tmp/newform-name-gap-after-save.png - --psm 11 2>/dev/null
python3 - "$RUN" "${EXPECT:-red}" <<'CHECK'
from pathlib import Path
import sys
p=Path(sys.argv[1]);h=(p/'Project1.hbp').read_text();f=(p/'Form3.prg').read_text();print('HBP',repr(h));print('FORM3_MARKER_PRESERVED','UNIQUE-FORM3-KEEP' in f)
if sys.argv[2]=='red':
 assert h.splitlines().count('Form3')==2
 assert 'UNIQUE-FORM3-KEEP' not in f
 print('RED NewForm duplicates existing Form3 name and save overwrites its source')
else:
 names=[x for x in h.splitlines() if x.startswith('Form')];assert len(names)==3 and len(set(x.lower() for x in names))==3
 assert 'UNIQUE-FORM3-KEEP' in f
 print('GREEN new name unique; existing Form3 source preserved')
CHECK
