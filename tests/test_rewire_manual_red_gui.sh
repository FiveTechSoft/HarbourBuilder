#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/rewire_manual_gui
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
python3 - "$RUN/Form1.prg" <<'FIX'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();i=s.index('return nil');s=s[:i]+'   // Event wiring\n   ::oButton1:OnClick := {|| CustomBusinessAction(Self)}\n   CustomStartupSideEffect(Self)\n'+s[i:];s+='\nfunction CustomBusinessAction(oForm)\n HB_SYMBOL_UNUSED(oForm)\n MemoWrit("/tmp/rewire-binding-sentinel.txt","CLICK")\nreturn nil\nfunction CustomStartupSideEffect(oForm)\n HB_SYMBOL_UNUSED(oForm)\n MemoWrit("/tmp/rewire-startup-sentinel.txt","STARTUP")\nreturn nil\n';p.write_text(s)
q=p.parent/'Project1.prg';q.write_text('#include "hbbuilder.ch"\nprocedure Main()\n local oApp:=TApplication():New(),oForm:=TForm1():New()\n oApp:CreateForm(oForm)\n HelperA()\n oForm:oButton1:OnClick:Eval()\nreturn\n')
FIX
rm -f /tmp/rewire-startup-sentinel.txt /tmp/rewire-binding-sentinel.txt
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
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
[ ! -f /tmp/rewire-startup-sentinel.txt ]||exit 1
echo 'RED real Run app executed but custom startup disappeared from assembled code'
