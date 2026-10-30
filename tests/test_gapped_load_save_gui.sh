#!/bin/bash
# A valid project with a gap in form numbers must not reuse an existing name.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/gapped_load_save_gui
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
cp "$RUN/Form3.prg" "$RUN/before-form3.prg"
touch -d '2000-01-01' "$RUN/Form3.prg"
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
rt_map_all
for w in $(rt_ide_windows);do
 if [ "$(xdotool getwindowname "$w")" = HbBuilder ];then
  xdotool windowraise "$w";eval "$(xdotool getwindowgeometry --shell "$w")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/gapped-load-dialog.png
 fi
done
import -window root /tmp/gapped-load-save.png
if [ "${EXPECT:-red}" = red ];then
 tesseract /tmp/gapped-load-dialog.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
else
 tesseract /tmp/gapped-load-save.png - --psm 11 2>/dev/null | tee "$RUN/ocr"
fi
python3 - "$RUN" "${EXPECT:-red}" <<'CHECK'
from pathlib import Path
import sys
p=Path(sys.argv[1]);h=(p/'Project1.hbp').read_text();f=(p/'Form3.prg').read_text();print('HBP',repr(h));print('FORM3_MARKER_PRESERVED','UNIQUE-FORM3-KEEP' in f)
if sys.argv[2]=='red':
 assert 'Operation aborted' in (p/'ocr').read_text()
 assert 'Form2' in (p/'ocr').read_text()
 assert (p/'before-form3.prg').read_bytes()==(p/'Form3.prg').read_bytes()
 print('RED valid Form1+Form3 loaded project refuses Save: internal Form2 identity mismatch; disk intact')
else:
 assert 'UNIQUE-FORM3-KEEP' in f
 assert (p/'Form3.prg').stat().st_mtime>1000000000
 assert 'Operation aborted' not in (p/'ocr').read_text()
 print('GREEN gapped named project saves existing Form3 correctly')
CHECK
