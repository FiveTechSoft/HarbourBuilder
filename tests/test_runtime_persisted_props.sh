#!/usr/bin/env bash
# Runtime probe: persisted Inspector properties in a COMPILED app (Linux/GTK3).
# Replicates the IDE build pipeline (hbbuilder_linux.prg steps 2-7) for fixture
# projects carrying the emitted property lines, runs each app under Xvfb and
# asserts it starts without the runtime error dialog, plus behavioral checks:
#   defcancel: clicking an lDefault button closes the form (modal result)
#   formprops: lSizable=.T. makes the window resizable (no max size hint)
# Defect history: lVisible/lReadOnly/lPassword had no ACCESS/ASSIGN in
# classes.prg, so the emitted assignments raised BASE/1005 at app startup;
# lVisible/lEnabled assigned pre-creation were never applied to the widget.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HBDIR="${HBDIR:-$HOME/harbour}"
HB_BIN="$HBDIR/bin/linux/gcc"
GTKROOT="${GTKROOT:-/tmp/gtk-root}"
RT_DISPLAY="${RT_DISPLAY:-:99}"
WORK=/tmp/hb-runtimeprops
export PKG_CONFIG_SYSROOT_DIR="$GTKROOT"
export PKG_CONFIG_LIBDIR="$GTKROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$GTKROOT/usr/share/pkgconfig"
export DISPLAY="$RT_DISPLAY"
export LD_LIBRARY_PATH="$GTKROOT/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
echo "== provenance: $(date -Is) HEAD $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown) =="
FAIL=0
note() { echo "  $1"; }
mkdir -p "$WORK/cache"
for f in source/core/classes.prg:classes.prg source/hix_runtime.prg:hix_runtime.prg source/hix_template.prg:hix_template.prg include/hbbuilder.ch:hbbuilder.ch include/hbide.ch:hbide.ch; do
  cp "$ROOT/${f%%:*}" "$WORK/cache/${f##*:}" || exit 1
done
build_group() {
  local G="$1"
  local B="$WORK/$G"
  mkdir -p "$B"
  cp "$WORK/cache"/{classes.prg,hix_runtime.prg,hix_template.prg,hbbuilder.ch,hbide.ch} "$B/"
  { echo '#include "hbbuilder.ch"'; echo; grep -v '#include "hbbuilder.ch"' "$ROOT/tests/fixtures/runtimeprops/$G/Project1.prg"; echo; cat "$ROOT/tests/fixtures/runtimeprops/$G/Form1.prg"; } > "$B/main.prg"
  "$HB_BIN/harbour" "$B/main.prg" -n -w -q -I"$HBDIR/include" -I"$B" -o"$B/main.c" 2>&1 || return 1
  gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$B/main.c" -o "$B/main.o" || return 1
  if [ ! -f "$WORK/cache/classes.o" ]; then
    for m in classes hix_runtime hix_template; do
      "$HB_BIN/harbour" "$WORK/cache/$m.prg" -n -w -q -I"$HBDIR/include" -I"$WORK/cache" -o"$WORK/cache/$m.c" 2>&1 || return 1
      gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$WORK/cache/$m.c" -o "$WORK/cache/$m.o" || return 1
    done
    gcc -c -O2 -DHIX_PRGRUNTIME -I"$HBDIR/include" -I"$ROOT/include" $(pkg-config --cflags gtk+-3.0) \
      "$ROOT/source/backends/gtk3/gtk3_core.c" -o "$WORK/cache/gtk3_core.o" || return 1
    gcc -c -O2 -I"$HBDIR/include" "$ROOT/source/backends/gtk3/gtk3_db_real.c" -o "$WORK/cache/hbdb_real.o" || return 1
  fi
  cp "$WORK/cache"/{classes.o,hix_runtime.o,hix_template.o,gtk3_core.o,hbdb_real.o} "$B/"
  gcc -o "$B/UserApp" "$B/main.o" "$B/classes.o" "$B/hix_runtime.o" "$B/hix_template.o" "$B/gtk3_core.o" "$B/hbdb_real.o" \
    -L"$HBDIR/lib/linux/gcc" -Wl,--start-group -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug -lhbct -lhbextern -lrddntx -lrddnsx -lrddcdx -lrddfpt -lhbhsx -lhbsix -lhbusrrdd -lhbsqlit3 -lsddsqlt3 -lrddsql -lgttrm -lhbpcre -Wl,--end-group \
    -L"$GTKROOT/usr/lib/x86_64-linux-gnu" $(pkg-config --libs gtk+-3.0) -lm -lpthread -ldl -lrt -lsqlite3 -l:libncurses.so.6 || return 1
}
start_x() {
  pkill -f "Xvfb $RT_DISPLAY" 2>/dev/null; pkill -f "$WORK/.*/UserApp" 2>/dev/null; sleep 1
  rm -f /tmp/.X${RT_DISPLAY#:}-lock
  Xvfb "$RT_DISPLAY" -screen 0 1024x768x24 >/dev/null 2>&1 &
  XPID=$!; sleep 4
}
run_group() { # asserts: app alive, Form1 window, no Runtime Error dialog
  local G="$1"
  pkill -f "$WORK/.*/UserApp" 2>/dev/null; sleep 0.5
  "$WORK/$G/UserApp" >/dev/null 2>&1 &
  local APP=$!; sleep 3
  if ! ps -p $APP >/dev/null; then note "FAIL $G: app exited at startup"; FAIL=1; kill $APP 2>/dev/null; return; fi
  if xdotool search --name "Runtime Error" | grep -q .; then note "FAIL $G: Runtime Error dialog at startup"; FAIL=1; kill $APP 2>/dev/null; return; fi
  if ! xdotool search --name "Form1" | grep -q .; then note "FAIL $G: no Form1 window"; FAIL=1; kill $APP 2>/dev/null; return; fi
  note "PASS $G: starts clean"
  kill $APP 2>/dev/null
}
start_x
for G in readonly password visible enabled; do
  if build_group "$G"; then run_group "$G"; else note "FAIL $G: build"; FAIL=1; fi
done
# defcancel: clicking the lDefault button closes the form (modal result behavior)
if build_group defcancel; then
  pkill -f "$WORK/.*/UserApp" 2>/dev/null; sleep 0.5
  "$WORK/defcancel/UserApp" >/dev/null 2>&1 & APP=$!; sleep 3
  WID=$(xdotool search --name "Form1" | head -1)
  if [ -n "$WID" ]; then
    eval $(xdotool getwindowgeometry --shell "$WID")
    xdotool mousemove $((X + 40 + 70)) $((Y + 100 + 16)) click 1; sleep 2
    if xdotool search --name "Form1" | grep -q .; then note "FAIL defcancel: window survived lDefault click"; FAIL=1
    else note "PASS defcancel: lDefault click closed the form"; fi
  else note "FAIL defcancel: no window"; FAIL=1; fi
  kill $APP 2>/dev/null
else note "FAIL defcancel: build"; FAIL=1; fi
# formprops: lSizable=.T. -> resizable (no max size hint)
if build_group formprops; then
  pkill -f "$WORK/.*/UserApp" 2>/dev/null; sleep 0.5
  "$WORK/formprops/UserApp" >/dev/null 2>&1 & APP=$!; sleep 3
  WID=$(xdotool search --name "Form1" | head -1)
  if [ -n "$WID" ]; then
    if xwininfo -id "$WID" -size | grep -q "program specified maximum size"; then
      note "FAIL formprops: lSizable=.T. but window has max size hint"; FAIL=1
    else note "PASS formprops: lSizable=.T. -> resizable"; fi
  else note "FAIL formprops: no window"; FAIL=1; fi
  kill $APP 2>/dev/null
else note "FAIL formprops: build"; FAIL=1; fi
kill $XPID 2>/dev/null
echo "TEST SUMMARY: runtime persisted props: $([ $FAIL -eq 0 ] && echo PASS || echo FAIL)"
exit $FAIL
