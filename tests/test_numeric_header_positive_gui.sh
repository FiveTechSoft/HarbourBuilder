#!/bin/bash
# Reproduce user class declaration loss without altering the IDE source.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
rt_find_designer(){
 local w t
 for w in $(rt_ide_windows);do
  t=$(xdotool getwindowname "$w")
  case "$t" in *Fixture*|*USER-EXTRA*) echo "$w";return 0;;esac
 done
 return 1
}
RUN=/tmp/form_numeric_positive_gui
rt_provenance
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/roundtrip/"* "$RUN/"
python3 - "$RUN/Form1.prg" <<'PY2'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text().replace('::nLeft   := 200','::nLeft   := + 200.0').replace('::nTop    := 150','::nTop    := 0x96').replace('::nHeight := 480','::nHeight := 480.0\n   ::nClrPane := -1').replace('   ::nHeight','   ::nWidthExtra := 777\n   ::nHeight',1);p.write_text(s)
PY2
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
# Capture actual code editor class text after reopening/saving.
rt_map_all
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in "Code Editor") xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";xdotool windowfocus "$w";xdotool key ctrl+Home;;esac
done
sleep 1
import -window root /tmp/numeric-header-red-editor.png
rt_cleanup
python3 - "$RUN" <<'PY'
from pathlib import Path
import sys,difflib,re,os
p=Path(sys.argv[1]);a=(p/'before.prg').read_text();b=(p/'cycle2.prg').read_text()
print('COMPLETE DIFF original to save/reopen/save:')
print(''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile='before',tofile='cycle2')))
get=lambda s,k:re.search(r'^   ::'+k+r'\s*:= (.*)$',s,re.M).group(1)
n=0
for k,v in {'nLeft':'200','nTop':'150','nWidth':'640','nHeight':'480','nClrPane':'4294967295','nWidthExtra':'777'}.items():
 print(k+' after='+get(b,k)+' expected='+v)
 if get(b,k)!=v:n+=1
if (p/'cycle1.prg').read_bytes()!=(p/'cycle2.prg').read_bytes():print('FAIL no fixpoint');n+=1
print('NUMERIC HEADER positive changed_count='+str(n))
sys.exit(n)
PY
