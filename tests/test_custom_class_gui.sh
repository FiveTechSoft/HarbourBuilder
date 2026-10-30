#!/bin/bash
# Reproduce user class declaration loss without altering the IDE source.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/custom_class_gui
rt_provenance
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/roundtrip/"* "$RUN/"
python3 - "$RUN/Form1.prg" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();s=s.replace('   // IDE-managed Components','''   // USER CLASS DECLARATIONS - exact text must survive
   DATA nCounter INIT 42 // USER-COUNTER
   DATA cNote INIT "keep  spaces" // USER-NOTE
   DATA oButton1 INIT nil // USER-OWNED-CONTROL

   // IDE-managed Components''',1)
s=s.replace('   DATA oButton1   // TButton\n','',1)
s=s.replace('   METHOD CreateForm()','   METHOD UserCounter()\n   METHOD CreateForm()',1)
s+='\nMETHOD UserCounter() CLASS TForm1\n   // USER-METHOD-BODY\nreturn ::nCounter\n'
p.write_text(s)
PY
cp "$RUN/Form1.prg" "$RUN/before.prg"
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
for cycle in 1 2; do
 DESIGN=$(rt_find_designer)
 eval "$(xdotool getwindowgeometry --shell "$DESIGN")"
 xdotool windowsize "$DESIGN" $((WIDTH+1)) "$HEIGHT"; sleep 1
 xdotool windowsize "$DESIGN" "$WIDTH" "$HEIGHT"; sleep 1
 BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1
 touch -d '2000-01-01 00:00:00' "$RUN/Form1.prg"
 xdotool key ctrl+s; sleep 2
 [ "$(stat -c %Y "$RUN/Form1.prg")" -gt 1000000000 ] || { echo "FAIL no actual save cycle$cycle";rt_cleanup;exit 1; }
 cp "$RUN/Form1.prg" "$RUN/cycle$cycle.prg"
 echo "Actual save cycle$cycle completed"
 if [ "$cycle" = 1 ]; then
  rt_cleanup
  rt_setup "$RUN";rt_launch_ide
  for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
  rt_reopen_project
 fi
done
rt_cleanup
python3 - "$RUN" <<'PY'
from pathlib import Path
import sys,difflib
p=Path(sys.argv[1]);a=(p/'before.prg').read_text();b=(p/'cycle2.prg').read_text()
print('COMPLETE DIFF original to save/reopen/save:')
print(''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile='before',tofile='cycle2')))
n=0
ac=a[a.index('CLASS TForm1'):a.index('ENDCLASS')];bc=b[b.index('CLASS TForm1'):b.index('ENDCLASS')]
if ac!=bc: print('FAIL entire CLASS body changed');n+=1
if b.count('DATA oButton1')!=1:print('FAIL duplicate control DATA');n+=1
for token in ['   DATA nCounter INIT 42 // USER-COUNTER','   DATA cNote INIT "keep  spaces" // USER-NOTE
   DATA oButton1 INIT nil // USER-OWNED-CONTROL','   METHOD UserCounter()','METHOD UserCounter() CLASS TForm1','   // USER-METHOD-BODY','return ::nCounter']:
 ok=token in b;print(('PRESERVED ' if ok else 'LOST ')+token)
 if not ok:n+=1
print('CUSTOM CLASS GUI loss_count='+str(n))
sys.exit(n)
PY
