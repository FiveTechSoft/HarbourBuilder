#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/rewire_inactive_gui
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
xdotool mousemove 155 142 click 1;sleep 1
xclip -selection clipboard -i "$RUN/edited-form1.prg"
xdotool mousemove 350 250 click 1;xdotool key ctrl+a ctrl+v;sleep 2
xdotool mousemove 250 142 click 1;sleep 1
import -window root /tmp/rewire-inactive-before-run.png
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+r
for try in $(seq 1 40);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt||exit 1
B=/tmp/hbbuilder_build/$(printf '%s' "$RUN/Project1.hbp"|md5sum|cut -d' ' -f1)
python3 - "$RUN/Form1.prg" "$B/main.prg" <<'CHECK'
from pathlib import Path
import sys
for name in sys.argv[1:]:
 s=Path(name).read_text();body=s[s.index('METHOD CreateForm() CLASS'):];body=body[:body.index('return nil')]
 print(name+' custombinding='+str('::oButton1:OnClick := {|| CustomBusinessAction(Self)}' in body)+' startupcall='+str('   CustomStartupSideEffect(Self)' in body))
print('startup_sentinel_exists='+str(Path('/tmp/rewire-startup-sentinel.txt').exists()))
CHECK
grep -q STARTUP /tmp/rewire-startup-sentinel.txt||exit 1
grep -n 'Button1Click\|Button1:OnClick' "$B/main.prg"
if grep -q '::oButton1:OnClick.*Button1Click' "$B/main.prg";then echo 'INACTIVE convention wiring present';else echo 'INACTIVE convention wiring ABSENT';exit 2;fi
