#!/bin/bash
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/loaded_form_names_gui
mkdir -p "$RUN";cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
python3 - "$RUN" "$REPO" <<'FIX'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=(p/'Form1.prg').read_text()
(p/'Form7.prg').write_text(s.replace('Form1','Form7').replace('FIXTURE roundtrip v3','KEEP-Form7'))
s=(Path(sys.argv[2])/'tests/fixtures/preclass2/healthy/Form2.prg').read_text()
(p/'Invoice.prg').write_text(s.replace('Form2','Invoice').replace('COMENTARIO-PRECLASS-F2','KEEP-Invoice'))
(p/'Project1.hbp').write_text('Project1\nForm7\nInvoice\n[modules]\nHelperA\nHelperB\n')
FIX
rt_provenance;rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
python3 - "$RUN" <<'CHECK'
from pathlib import Path
import sys
p=Path(sys.argv[1]);h=(p/'Project1.hbp').read_text();assert h.index('Form7')<h.index('Invoice')
for n in ['Form7','Invoice']:
 s=(p/(n+'.prg')).read_text();assert 'CLASS T'+n+' FROM TForm' in s;assert 'KEEP-'+n in s;assert s.count('CLASS T'+n+' FROM TForm')==1
assert not (p/'Form2.prg').exists()
print('SAVE arbitrary/reordered names and own classes/prefaces preserved')
CHECK
rm -f /tmp/debugmodules-result.txt
if [ "${MODE:-run}" = debug ];then xdotool mousemove 15 62 click 1;else xdotool key ctrl+r;fi
for try in $(seq 1 70);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt
echo "ACTUAL ${MODE:-run} assembled arbitrary/reordered named forms executed"
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*)xdotool windowmap "$w";xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";xdotool windowfocus "$w";xdotool key ctrl+End;;esac
done
import -window root /tmp/loaded-form-names-runtime.png
