#!/bin/bash
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/rewire_refusal_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
python3 - "$RUN/Form1.prg" <<'FIX'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();i=s.index('return nil');s=s[:i]+'   // Event wiring\n      CustomStartupSideEffect(Self)\n'+s[i:];s+='\nfunction Button1Click(oForm)\n HB_SYMBOL_UNUSED(oForm)\n MemoWrit("/tmp/rewire-binding-sentinel.txt","CLICK")\nreturn nil\nfunction CustomStartupSideEffect(oForm)\n HB_SYMBOL_UNUSED(oForm)\n MemoWrit("/tmp/rewire-startup-sentinel.txt","STARTUP")\nreturn nil\n';p.write_text(s)
q=p.parent/'Project1.prg';q.write_text('#include "hbbuilder.ch"\nprocedure Main()\n local oApp:=TApplication():New(),oForm:=TForm1():New()\n oApp:CreateForm(oForm)\n HelperA()\n oApp:Run()\nreturn\n')
FIX
rm -f /tmp/rewire-startup-sentinel.txt /tmp/rewire-binding-sentinel.txt
# Add second form and remove conventional handler until after project load.
cp "$REPO/tests/fixtures/preclass2/healthy/Form2.prg" "$RUN/Form2.prg"
sed -i '/^Form1$/a Form2' "$RUN/Project1.hbp"
cp "$RUN/Form1.prg" "$RUN/edited-form1.prg"
python3 - "$RUN/Form1.prg" <<'STRIP'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();a=s.index('function Button1Click');b=s.index('function CustomStartupSideEffect',a);p.write_text(s[:a]+s[b:])
STRIP
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
# Select Form1 tab, replace its editor contents with handler-added version,
# then select Form2 before Run. GTK notebook tabs are at top of code editor.
for w in $(rt_ide_windows);do [ "$(xdotool getwindowname "$w")" = 'Code Editor' ] && ED=$w;done
rt_map_all;xdotool windowmove "$ED" 0 125;xdotool windowsize "$ED" 1500 820;xdotool windowraise "$ED";xdotool windowfocus "$ED"
xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 135 120 click 1;sleep 1
xclip -selection clipboard -i "$RUN/edited-form1.prg"
xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+v;sleep 2
xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > /tmp/refusal-f1-before.txt
xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 220 120 click 1;sleep 1
xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > /tmp/refusal-f2-before.txt
python3 - <<'BREAK'
from pathlib import Path
p=Path('/tmp/refusal-f2-before.txt');s=p.read_text();assert 'CLASS TForm2 FROM TForm' in s;p=Path('/tmp/refusal-f2-broken.txt');p.write_text(s.replace('CLASS TForm2 FROM TForm','// removed class declaration'))
BREAK
xclip -selection clipboard -i /tmp/refusal-f2-broken.txt;xdotool key ctrl+a ctrl+v;sleep 1
xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > /tmp/refusal-f2-inserted.txt
sha256sum "$RUN/Form1.prg" "$RUN/Form2.prg" > /tmp/refusal-disks-before.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+s;sleep 2
import -window root /tmp/rewire-refusal-dialog.png
xdotool key Return;sleep 1
rt_map_all;xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > /tmp/refusal-f2-after.txt
xdotool windowraise "$ED";xdotool windowfocus "$ED";xdotool mousemove 135 120 click 1;sleep 1;xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+c;sleep 1
xclip -selection clipboard -o > /tmp/refusal-f1-after.txt
sha256sum "$RUN/Form1.prg" "$RUN/Form2.prg" > /tmp/refusal-disks-after.txt
python3 - <<'VERIFY'
from pathlib import Path
for a,b in [('f1-before','f1-after'),('f2-inserted','f2-after'),('disks-before','disks-after')]:
 x=Path('/tmp/refusal-'+a+'.txt').read_bytes();y=Path('/tmp/refusal-'+b+'.txt').read_bytes();assert x and x==y,(a,len(x),len(y));print('UNCHANGED',a,len(x))
assert b'Button1Click' in Path('/tmp/refusal-f1-after.txt').read_bytes()
print('REFUSAL staged merge: both editor buffers and both disk files unchanged')
VERIFY
