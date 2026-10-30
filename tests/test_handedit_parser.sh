#!/bin/bash
# Hand-edit parser regression: a hand-written form must survive
# open -> designer sync -> save with these hand-edit shapes:
#   COMPONENT ::OTimer1 ...   (::O uppercase, H5 residual)
#   COMPONENT ::oTimer2<TAB>TYPE ...  (tab after the name)
#   END POPUP // comment  /  END MENUBAR // comment  (M2)
# RED before the fix: the COMPONENTs are dropped/corrupted and the
# controls AFTER the menu block are swallowed by the menu parse loop.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/handedit"
RUN=/tmp/rt_handedit
source "$REPO/tests/harness_lib.sh"
fail() { echo "FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
cp "$FIX/Form1.prg" "$RUN/original.prg"
rt_setup "$RUN"
rt_launch_ide

unmap_all_but() { rt_unmap_all_but "$@"; }
find_designer() { rt_find_designer; }
find_bar() { rt_find_bar; }
map_all() { rt_map_all; }

# one cycle: reopen + sync + save
BAR=$(find_bar)
[ -n "$BAR" ] || fail "IDE bar window not found"
unmap_all_but "$BAR"; sleep 0.4
xdotool mousemove 20 12 click 1;  sleep 0.8
xdotool mousemove 100 134 click 1; sleep 5
map_all; sleep 1
DESIGN=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  DESIGN=$(find_designer) && break
  sleep 1
done
[ -n "$DESIGN" ] || fail "designer form window not found"
eval "$(xdotool getwindowgeometry --shell "$DESIGN")"
xdotool windowsize "$DESIGN" $((WIDTH+1)) "$HEIGHT"; sleep 1.5
xdotool windowsize "$DESIGN" "$WIDTH" "$HEIGHT"; sleep 1.5
BAR=$(find_bar); unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 700 12 click 1; sleep 0.4
touch -d '2000-01-01 00:00:00' "$RUN/Form1.prg"
xdotool key ctrl+s; sleep 2
M1=$(stat -c %Y "$RUN/Form1.prg")
if [ "$M1" -lt 1000000000 ]; then
  xdotool mousemove 20 12 click 1; sleep 0.8
  xdotool mousemove 100 200 click 1; sleep 2
  M1=$(stat -c %Y "$RUN/Form1.prg")
fi
[ "$M1" -ge 1000000000 ] || fail "no real save (Form1.prg mtime unchanged)"
echo "saved (mtime $(date -d @$M1 -Is))"

# verification on the saved file
FAILN=0
chk() { if ! grep -Eq "$1" "$RUN/Form1.prg"; then echo "  MISSING: $1"; FAILN=$((FAILN+1)); fi; }
rej() { if grep -Eq "$1" "$RUN/Form1.prg"; then echo "  FORBIDDEN PRESENT: $1"; FAILN=$((FAILN+1)); fi; }

chk 'COMPONENT ::oTimer1 TYPE CT_TIMER OF Self'
chk 'COMPONENT ::oTimer2 TYPE CT_TIMER OF Self'
# the menu swallow drops the controls from the live form, which also
# removes their DATA declarations (the '@' lines survive as "hand-written"
# text but reference undeclared DATAs: the generated app would not compile)
chk 'DATA oButton1'
chk 'DATA oSay1'
chk 'DATA oTimer1'
chk 'DATA oTimer2'
chk 'DEFINE POPUP "Archivo"'
chk 'MENUITEM "Abrir"'
chk 'BUTTON ::oButton1 PROMPT "Boton"'
chk 'SAY ::oSay1 PROMPT "Texto"'
# corruption markers of the old bugs
rej 'Timer2.*TYPE TYPE'
rej '::oTimer2[A-Z]'

if [ "$FAILN" -gt 0 ]; then
  echo "HANDEDIT_PARSER FAIL ($FAILN problems). Evidence in $RUN"
  diff <(tr -d '\r' < "$RUN/original.prg") <(tr -d '\r' < "$RUN/Form1.prg") | head -30
  rt_cleanup
  exit 1
fi
echo "HANDEDIT_PARSER PASS: COMPONENT case/tab and menu END trailing comments survive open->sync->save."
rt_cleanup
exit 0
