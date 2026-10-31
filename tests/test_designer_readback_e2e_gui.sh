#!/usr/bin/env bash
# Designer readback E2E: real IDE drop of TEdit + TButton, real save, handler
# line added to the emitted file externally, equivalent external runtime
# compile, GTK3 run under Xvfb. Asserts Value readback of typed input.
# Scope note: the IDE event editor and the IDE Compile action are NOT used;
# those legs are covered separately. GTK3/Linux only.
# Isolation: unique run dir, own display, own-PID cleanup with reaping.
# Diagnostics: if palette icon coordinates go stale (IDE layout change), the
# emitted file will lack the expected control lines and the test says so.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
GTKROOT=${GTKROOT:-/tmp/gtk-root}
HBDIR="${HBDIR:-$HOME/harbour}"
RUN=$(mktemp -d /tmp/hb-e2e-readback.XXXXXX)
OUT="$RUN/out"; B="$RUN/build"; mkdir -p "$OUT" "$B"
TOKEN="E2E$(date +%H%M%S)$$"
RT_DISPLAY=""
for d in 97 96 95 94 93; do
  if [ ! -e "/tmp/.X$d-lock" ] && [ ! -S "/tmp/.X11-unix/X$d" ]; then RT_DISPLAY=":$d"; break; fi
done
[ -n "$RT_DISPLAY" ] || { echo "FAIL: no free display"; exit 1; }
XVFB_PID=""; APP_PID=""
cleanup() {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null && wait "$APP_PID" 2>/dev/null
  rt_cleanup
  if [ -n "$XVFB_PID" ]; then kill "$XVFB_PID" 2>/dev/null; wait "$XVFB_PID" 2>/dev/null; fi
}
fail() { echo "E2E READBACK FAIL: $1"; cleanup; exit 1; }
source "$REPO/tests/harness_lib.sh"
trap cleanup EXIT
rt_provenance
echo "run dir: $RUN  token: $TOKEN  display: $RT_DISPLAY"
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - designer readback e2e' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - designer readback e2e' \
  '//--------------------------------------------------------------------' \
  '' \
  'CLASS TForm1 FROM TForm' \
  '' \
  '   // IDE-managed Components' \
  '' \
  '   // Event handlers' \
  '' \
  '   METHOD CreateForm()' \
  '' \
  'ENDCLASS' \
  '//--------------------------------------------------------------------' \
  '' \
  'METHOD CreateForm() CLASS TForm1' \
  '' \
  '   ::cTitle  := "Form1"' \
  '   ::nLeft   := 200' \
  '   ::nTop    := 100' \
  '   ::nWidth  := 700' \
  '   ::nHeight := 600' \
  '' \
  'Return Nil' > "$RUN/Form1.prg"
rt_setup "$RUN"
# rt_setup starts Xvfb itself when the display is down; record whether we own one
if ! xdotool getdisplaygeometry >/dev/null 2>&1; then
  Xvfb $RT_DISPLAY -screen 0 1600x1000x24 & XVFB_PID=$!; sleep 2
fi
rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar); rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 1
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
echo "designer at $X,$Y ${WIDTH}x${HEIGHT}"
# palette icon centers (Standard tab row, absolute screen coords at 1600x1000).
# If an IDE layout change moves the palette, the drops land elsewhere and the
# emitted file lacks the control lines; the check below reports exactly that.
PI_Edit=471; PI_Button=532; PI_Y=90
drop() { # $1 icon-x  $2 dx  $3 dy  $4 w  $5 h
  xdotool mousemove "$1" $PI_Y click 1; sleep 1
  xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
  eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
  xdotool mousemove $((X+$2)) $((Y+$3)) mousedown 1; sleep 0.5
  xdotool mousemove $((X+$2+$4)) $((Y+$3+$5)) mouseup 1; sleep 1.5
}
drop $PI_Edit   130 40 140 24
drop $PI_Button 300 40  90 26
import -window root "$RUN/dropped.png" 2>/dev/null
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
grep -q 'GET ::oEdit1' "$RUN/Form1.prg" || fail "emitted Form1.prg lacks 'GET ::oEdit1' - edit drop did not land; palette icon coords (PI_Edit=$PI_Edit,$PI_Y) likely stale, re-derive from a Standard-palette screenshot"
grep -q 'BUTTON ::oButton1' "$RUN/Form1.prg" || fail "emitted Form1.prg lacks 'BUTTON ::oButton1' - button drop did not land; palette icon coords (PI_Button=$PI_Button,$PI_Y) likely stale"
echo "designer+save OK: IDE emitted expected control lines"
# handler line added externally (the IDE event editor is a separate leg)
python3 - "$RUN/Form1.prg" "$OUT" <<'PY'
import sys
path, outdir = sys.argv[1], sys.argv[2]
s = open(path).read()
anchor = None
for line in s.splitlines():
    if 'BUTTON ::oButton1' in line:
        anchor = line
assert anchor, "button line vanished"
inject = anchor + '\n   ::oButton1:OnClick := { || hb_MemoWrit( "' + outdir + '/read.txt", "VALUE=[" + ::oEdit1:Value + "]" ) }'
open(path, 'w').write(s.replace(anchor, inject))
print("handler line injected")
PY
[ $? = 0 ] || fail "handler injection"
# equivalent external runtime compile (same steps as test_runtime_* suites)
export PKG_CONFIG_SYSROOT_DIR=$GTKROOT
export PKG_CONFIG_LIBDIR="$GTKROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$GTKROOT/usr/share/pkgconfig"
for f in source/core/classes.prg:classes.prg source/hix_runtime.prg:hix_runtime.prg source/hix_template.prg:hix_template.prg include/hbbuilder.ch:hbbuilder.ch include/hbide.ch:hbide.ch; do
  cp "$REPO/${f%%:*}" "$B/${f##*:}" || fail "stage ${f##*:}"
done
{ echo '#include "hbbuilder.ch"'; echo; grep -v '#include "hbbuilder.ch"' "$RUN/Project1.prg"; echo; cat "$RUN/Form1.prg"; } > "$B/main.prg"
HB_BIN="$HBDIR/bin/linux/gcc"
"$HB_BIN/harbour" "$B/main.prg" -n -w -q -I"$HBDIR/include" -I"$B" -o"$B/main.c" 2>&1 || fail "harbour main"
gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$B/main.c" -o "$B/main.o" || fail "main.o"
for m in classes hix_runtime hix_template; do
  "$HB_BIN/harbour" "$B/$m.prg" -n -w -q -I"$HBDIR/include" -I"$B" -o"$B/$m.c" 2>&1 || fail "harbour $m"
  gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$B/$m.c" -o "$B/$m.o" || fail "$m.o"
done
gcc -c -O2 -DHIX_PRGRUNTIME -I"$HBDIR/include" -I"$REPO/include" $(pkg-config --cflags gtk+-3.0) \
  "$REPO/source/backends/gtk3/gtk3_core.c" -o "$B/gtk3_core.o" || fail "gtk3_core.o"
gcc -c -O2 -I"$HBDIR/include" "$REPO/source/backends/gtk3/gtk3_db_real.c" -o "$B/hbdb_real.o" || fail "hbdb_real.o"
gcc -o "$B/UserApp" "$B/main.o" "$B/classes.o" "$B/hix_runtime.o" "$B/hix_template.o" "$B/gtk3_core.o" "$B/hbdb_real.o" \
  -L"$HBDIR/lib/linux/gcc" -Wl,--start-group -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug -lhbct -lhbextern -lrddntx -lrddnsx -lrddcdx -lrddfpt -lhbhsx -lhbsix -lhbusrrdd -lhbsqlit3 -lsddsqlt3 -lrddsql -lgttrm -lhbpcre -Wl,--end-group \
  -L"$GTKROOT/usr/lib/x86_64-linux-gnu" $(pkg-config --libs gtk+-3.0) -lm -lpthread -ldl -lrt -lsqlite3 -l:libncurses.so.6 || fail "link"
echo "build OK"
# run the IDE-designed app on a separate small display
APP_DISPLAY=""
for d in 92 91 90; do
  if [ ! -e "/tmp/.X$d-lock" ] && [ ! -S "/tmp/.X11-unix/X$d" ]; then APP_DISPLAY=":$d"; break; fi
done
[ -n "$APP_DISPLAY" ] || fail "no free display for app"
Xvfb "$APP_DISPLAY" -screen 0 1024x768x24 >/dev/null 2>&1 &
APP_XVFB=$!
sleep 3
DISPLAY="$APP_DISPLAY" LD_LIBRARY_PATH="$GTKROOT/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$B/UserApp" >/dev/null 2>&1 &
APP_PID=$!
sleep 3
WID=$(DISPLAY="$APP_DISPLAY" xdotool search --name "Form1" | head -1)
[ -n "$WID" ] || fail "app window not found"
eval $(DISPLAY="$APP_DISPLAY" xdotool getwindowgeometry --shell "$WID")
# emitted layout: GET at row 40 col 128, BUTTON at row 40 col 296 (+20/+13 offsets)
DISPLAY="$APP_DISPLAY" xdotool mousemove $((X+148)) $((Y+53)) click 1; sleep 0.4
DISPLAY="$APP_DISPLAY" xdotool type "$TOKEN"; sleep 0.4
DISPLAY="$APP_DISPLAY" xdotool mousemove $((X+316)) $((Y+53)) click 1; sleep 1
DISPLAY="$APP_DISPLAY" timeout 10 import -window root "$RUN/readback.png" 2>/dev/null
kill "$APP_PID" 2>/dev/null; wait "$APP_PID" 2>/dev/null; APP_PID=""
kill "$APP_XVFB" 2>/dev/null; wait "$APP_XVFB" 2>/dev/null
READ=$(cat "$OUT/read.txt" 2>/dev/null || echo MARKER-MISSING)
echo "typed: $TOKEN  readback: $READ"
if [ "$READ" = "VALUE=[$TOKEN]" ]; then
  echo "E2E READBACK PASS: IDE-designed app reads back typed input"
  echo "ARTIFACTS: $RUN"
  exit 0
else
  fail "expected VALUE=[$TOKEN], got $READ"
fi
