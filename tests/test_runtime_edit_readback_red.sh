#!/usr/bin/env bash
# OBSERVATIONAL RED probe (2026-10-31): TEdit readback of user input at runtime.
# Typing into a TEdit in a compiled app never reaches the model: oEdit:Value /
# UI_GetProp "cText" return the stored FText, not the live widget text, and no
# "changed" signal is connected for edits (HBEdit_CreateWidget), so OnChange
# never fires either. This probe RECORDS the current (defective) behavior; it
# does not assert the desired behavior and always exits 0 unless the harness
# itself fails. Fix not authorized yet.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HBDIR="${HBDIR:-$HOME/harbour}"
GTKROOT="${GTKROOT:-/tmp/gtk-root}"
WORK=$(mktemp -d /tmp/hb-readback.XXXXXX)
OUT="$WORK/out"; mkdir -p "$OUT"
export PKG_CONFIG_SYSROOT_DIR="$GTKROOT"
export PKG_CONFIG_LIBDIR="$GTKROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$GTKROOT/usr/share/pkgconfig"
RT_DISPLAY=""
for d in 99 100 101 102 103; do
  if [ ! -e "/tmp/.X$d-lock" ] && [ ! -S "/tmp/.X11-unix/X$d" ]; then RT_DISPLAY=":$d"; break; fi
done
[ -n "$RT_DISPLAY" ] || { echo "harness FAIL: no free display"; exit 1; }
export DISPLAY="$RT_DISPLAY"
export LD_LIBRARY_PATH="$GTKROOT/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
echo "== provenance: $(date -Is) HEAD $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown) =="
HB_BIN="$HBDIR/bin/linux/gcc"
B="$WORK/build"; mkdir -p "$B"
for f in source/core/classes.prg:classes.prg source/hix_runtime.prg:hix_runtime.prg source/hix_template.prg:hix_template.prg include/hbbuilder.ch:hbbuilder.ch include/hbide.ch:hbide.ch; do
  cp "$ROOT/${f%%:*}" "$B/${f##*:}" || { echo "harness FAIL stage"; exit 1; }
done
{ echo '#include "hbbuilder.ch"'; echo; grep -v '#include "hbbuilder.ch"' "$ROOT/tests/fixtures/runtimeprops/readback/Project1.prg"; echo; sed "s|@OUTDIR@|$OUT|g" "$ROOT/tests/fixtures/runtimeprops/readback/Form1.prg"; } > "$B/main.prg"
"$HB_BIN/harbour" "$B/main.prg" -n -w -q -I"$HBDIR/include" -I"$B" -o"$B/main.c" 2>&1 || { echo "harness FAIL harbour"; exit 1; }
gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$B/main.c" -o "$B/main.o" || { echo "harness FAIL main.o"; exit 1; }
for m in classes hix_runtime hix_template; do
  "$HB_BIN/harbour" "$B/$m.prg" -n -w -q -I"$HBDIR/include" -I"$B" -o"$B/$m.c" 2>&1 || { echo "harness FAIL harbour $m"; exit 1; }
  gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$B/$m.c" -o "$B/$m.o" || { echo "harness FAIL $m.o"; exit 1; }
done
gcc -c -O2 -DHIX_PRGRUNTIME -I"$HBDIR/include" -I"$ROOT/include" $(pkg-config --cflags gtk+-3.0) \
  "$ROOT/source/backends/gtk3/gtk3_core.c" -o "$B/gtk3_core.o" || { echo "harness FAIL gtk3"; exit 1; }
gcc -c -O2 -I"$HBDIR/include" "$ROOT/source/backends/gtk3/gtk3_db_real.c" -o "$B/hbdb_real.o" || { echo "harness FAIL db"; exit 1; }
gcc -o "$B/UserApp" "$B/main.o" "$B/classes.o" "$B/hix_runtime.o" "$B/hix_template.o" "$B/gtk3_core.o" "$B/hbdb_real.o" \
  -L"$HBDIR/lib/linux/gcc" -Wl,--start-group -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug -lhbct -lhbextern -lrddntx -lrddnsx -lrddcdx -lrddfpt -lhbhsx -lhbsix -lhbusrrdd -lhbsqlit3 -lsddsqlt3 -lrddsql -lgttrm -lhbpcre -Wl,--end-group \
  -L"$GTKROOT/usr/lib/x86_64-linux-gnu" $(pkg-config --libs gtk+-3.0) -lm -lpthread -ldl -lrt -lsqlite3 -l:libncurses.so.6 || { echo "harness FAIL link"; exit 1; }
Xvfb "$RT_DISPLAY" -screen 0 1024x768x24 >/dev/null 2>&1 & XPID=$!; sleep 4
"$B/UserApp" >/dev/null 2>&1 & APP=$!; sleep 3
WID=$(xdotool search --name "Form1" | head -1)
if [ -z "$WID" ]; then echo "harness FAIL: no window"; kill $APP $XPID 2>/dev/null; exit 1; fi
eval $(xdotool getwindowgeometry --shell "$WID")
xdotool mousemove $((X+60)) $((Y+53)) click 1; sleep 0.4; xdotool type "TYPED"; sleep 0.4
xdotool mousemove $((X+100)) $((Y+105)) click 1; sleep 1   # BtnRead
READ=$(cat "$OUT/read.txt" 2>/dev/null || echo MARKER-MISSING)
timeout 10 import -window root "$WORK/readback-typed.png" 2>/dev/null  # widget still shows TYPED
xdotool mousemove $((X+260)) $((Y+105)) click 1; sleep 1   # BtnSet
SET=$(cat "$OUT/set.txt" 2>/dev/null || echo MARKER-MISSING)
timeout 10 import -window root "$WORK/readback-afterset.png" 2>/dev/null
echo "== after typing TYPED into the edit, oEdit1:Value read: $READ"
echo "== after oEdit1:Value := SETVALUE, read-back: $SET"
if [ "$READ" = "VALUE=[]" ]; then
  echo "DEFECT REPRODUCED: typed input never reaches the model (Value/cText stale)"
else
  echo "NOTE: readback returned '$READ' - behavior changed, review the probe"
fi
kill $APP $XPID 2>/dev/null
echo "PROBE ARTIFACTS: $WORK (markers + screenshot)"
echo "OBSERVATIONAL: exit 0 regardless; no desired-behavior assertion"
exit 0
