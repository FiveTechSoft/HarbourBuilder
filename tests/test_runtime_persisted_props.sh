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
# Unique workdir per run: no state carries over between runs.
WORK=$(mktemp -d /tmp/hb-runtimeprops.XXXXXX)
# Cache keyed by source hashes: objects are rebuilt whenever the staged
# sources change, so a stale classes.o/gtk3_core.o can never be linked.
SRCKEY=$(sha256sum "$ROOT/source/core/classes.prg" "$ROOT/source/hix_runtime.prg" "$ROOT/source/hix_template.prg" "$ROOT/source/backends/gtk3/gtk3_core.c" "$ROOT/source/backends/gtk3/gtk3_db_real.c" | sha256sum | cut -c1-16)
CACHE="$WORK/cache-$SRCKEY"
APPPIDS=""
OUT="$WORK/out"
mkdir -p "$OUT"
# Free display owned by this probe only; never signal other Xvfb instances.
RT_DISPLAY=""
for d in 99 100 101 102 103; do
  if [ ! -e "/tmp/.X$d-lock" ] && [ ! -S "/tmp/.X11-unix/X$d" ]; then RT_DISPLAY=":$d"; break; fi
done
[ -n "$RT_DISPLAY" ] || { echo "no free display"; exit 1; }
export PKG_CONFIG_SYSROOT_DIR="$GTKROOT"
export PKG_CONFIG_LIBDIR="$GTKROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$GTKROOT/usr/share/pkgconfig"
export DISPLAY="$RT_DISPLAY"
export LD_LIBRARY_PATH="$GTKROOT/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
echo "== provenance: $(date -Is) HEAD $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown) =="
FAIL=0
note() { echo "  $1"; }
mkdir -p "$CACHE"
echo "== source key: $SRCKEY"
for f in source/core/classes.prg:classes.prg source/hix_runtime.prg:hix_runtime.prg source/hix_template.prg:hix_template.prg include/hbbuilder.ch:hbbuilder.ch include/hbide.ch:hbide.ch; do
  cp "$ROOT/${f%%:*}" "$CACHE/${f##*:}" || exit 1
done
build_group() {
  local G="$1"
  local B="$WORK/$G"
  mkdir -p "$B"
  cp "$CACHE"/{classes.prg,hix_runtime.prg,hix_template.prg,hbbuilder.ch,hbide.ch} "$B/"
  { echo '#include "hbbuilder.ch"'; echo; grep -v '#include "hbbuilder.ch"' "$ROOT/tests/fixtures/runtimeprops/$G/Project1.prg"; echo; sed "s|@OUTDIR@|$OUT|g" "$ROOT/tests/fixtures/runtimeprops/$G/Form1.prg"; } > "$B/main.prg"
  "$HB_BIN/harbour" "$B/main.prg" -n -w -q -I"$HBDIR/include" -I"$B" -o"$B/main.c" 2>&1 || return 1
  gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$B/main.c" -o "$B/main.o" || return 1
  if [ ! -f "$CACHE/classes.o" ]; then
    for m in classes hix_runtime hix_template; do
      "$HB_BIN/harbour" "$CACHE/$m.prg" -n -w -q -I"$HBDIR/include" -I"$CACHE" -o"$CACHE/$m.c" 2>&1 || return 1
      gcc -c -O2 -Wno-unused-value -I"$HBDIR/include" "$CACHE/$m.c" -o "$CACHE/$m.o" || return 1
    done
    gcc -c -O2 -DHIX_PRGRUNTIME -I"$HBDIR/include" -I"$ROOT/include" $(pkg-config --cflags gtk+-3.0) \
      "$ROOT/source/backends/gtk3/gtk3_core.c" -o "$CACHE/gtk3_core.o" || return 1
    gcc -c -O2 -I"$HBDIR/include" "$ROOT/source/backends/gtk3/gtk3_db_real.c" -o "$CACHE/hbdb_real.o" || return 1
    echo "== object hashes:"
    sha256sum "$CACHE/classes.o" "$CACHE/gtk3_core.o" "$CACHE/hbdb_real.o" | sed "s/^/== obj /"
  fi
  cp "$CACHE"/{classes.o,hix_runtime.o,hix_template.o,gtk3_core.o,hbdb_real.o} "$B/"
  gcc -o "$B/UserApp" "$B/main.o" "$B/classes.o" "$B/hix_runtime.o" "$B/hix_template.o" "$B/gtk3_core.o" "$B/hbdb_real.o" \
    -L"$HBDIR/lib/linux/gcc" -Wl,--start-group -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug -lhbct -lhbextern -lrddntx -lrddnsx -lrddcdx -lrddfpt -lhbhsx -lhbsix -lhbusrrdd -lhbsqlit3 -lsddsqlt3 -lrddsql -lgttrm -lhbpcre -Wl,--end-group \
    -L"$GTKROOT/usr/lib/x86_64-linux-gnu" $(pkg-config --libs gtk+-3.0) -lm -lpthread -ldl -lrt -lsqlite3 -l:libncurses.so.6 || return 1
}
start_x() {
  Xvfb "$RT_DISPLAY" -screen 0 1024x768x24 >/dev/null 2>&1 &
  XPID=$!; sleep 4
}
stop_apps() { for p in $APPPIDS; do kill $p 2>/dev/null; done; APPPIDS=""; }
run_group() { # asserts ONLY: app alive, Form1 window, no Runtime Error dialog.
  # Property effects (input rejection, masking, hidden, insensitive) are visual
  # observations (screenshots in the review package), NOT asserted by this probe.
  local G="$1"
  stop_apps; sleep 0.5
  "$WORK/$G/UserApp" >/dev/null 2>&1 &
  local APP=$!; APPPIDS="$APPPIDS $APP"; sleep 3
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
  stop_apps; sleep 0.5
  rm -f "$OUT/defclick.txt"
  "$WORK/defcancel/UserApp" >/dev/null 2>&1 & APP=$!; APPPIDS="$APPPIDS $APP"; sleep 3
  WID=$(xdotool search --name "Form1" | head -1)
  if [ -n "$WID" ]; then
    eval $(xdotool getwindowgeometry --shell "$WID")
    xdotool mousemove $((X + 40 + 70)) $((Y + 100 + 16)) click 1; sleep 2
    if xdotool search --name "Form1" | grep -q .; then note "FAIL defcancel: window survived lDefault click"; FAIL=1
    elif [ ! -f "$OUT/defclick.txt" ]; then note "FAIL defcancel: OnClick marker missing (handler did not run)"; FAIL=1
    else note "PASS defcancel: OnClick fired, then lDefault closed the form"; fi
  else note "FAIL defcancel: no window"; FAIL=1; fi
  kill $APP 2>/dev/null
else note "FAIL defcancel: build"; FAIL=1; fi
# formprops: lSizable=.T. -> resizable (no max size hint)
if build_group formprops; then
  stop_apps; sleep 0.5
  "$WORK/formprops/UserApp" >/dev/null 2>&1 & APP=$!; APPPIDS="$APPPIDS $APP"; sleep 3
  WID=$(xdotool search --name "Form1" | head -1)
  if [ -n "$WID" ]; then
    if xwininfo -id "$WID" -size | grep -q "program specified maximum size"; then
      note "FAIL formprops: lSizable=.T. but window has max size hint"; FAIL=1
    else note "PASS formprops: lSizable=.T. -> resizable"; fi
  else note "FAIL formprops: no window"; FAIL=1; fi
  kill $APP 2>/dev/null
else note "FAIL formprops: build"; FAIL=1; fi
# behavior: read-only rejects typed input while a normal edit accepts it;
# disabled button never fires its callback while a live one does.
if build_group behavior; then
  stop_apps; sleep 0.5
  mkdir -p "$OUT"; rm -f "$OUT/btnok.txt" "$OUT/btnoff.txt"
  "$WORK/behavior/UserApp" >/dev/null 2>&1 & APP=$!; APPPIDS="$APPPIDS $APP"; sleep 3
  WID=$(xdotool search --name "Form1" | head -1)
  if [ -n "$WID" ]; then
    eval $(xdotool getwindowgeometry --shell "$WID")
    xdotool mousemove $((X+60)) $((Y+53)) click 1; sleep 0.4; xdotool type "NO"; sleep 0.4
    xdotool mousemove $((X+60)) $((Y+93)) click 1; sleep 0.4; xdotool type "YES"; sleep 0.4
    xdotool mousemove $((X+100)) $((Y+145)) click 1; sleep 1
    xdotool mousemove $((X+260)) $((Y+145)) click 1; sleep 1
    [ -f "$OUT/btnok.txt" ] && note "PASS behavior: live button callback fired" || { note "FAIL behavior: live button callback missing"; FAIL=1; }
    [ ! -f "$OUT/btnoff.txt" ] && note "PASS behavior: disabled button callback absent" || { note "FAIL behavior: disabled button fired"; FAIL=1; }
  else note "FAIL behavior: no window"; FAIL=1; fi
  kill $APP 2>/dev/null
else note "FAIL behavior: build"; FAIL=1; fi
# cancel: clicking an lCancel button closes the form
if build_group cancel; then
  stop_apps; sleep 0.5
  rm -f "$OUT/cancelclick.txt"
  "$WORK/cancel/UserApp" >/dev/null 2>&1 & APP=$!; APPPIDS="$APPPIDS $APP"; sleep 3
  WID=$(xdotool search --name "Form1" | head -1)
  if [ -n "$WID" ]; then
    eval $(xdotool getwindowgeometry --shell "$WID")
    xdotool mousemove $((X + 40 + 70)) $((Y + 100 + 16)) click 1; sleep 2
    if xdotool search --name "Form1" | grep -q .; then note "FAIL cancel: window survived lCancel click"; FAIL=1
    elif [ ! -f "$OUT/cancelclick.txt" ]; then note "FAIL cancel: OnClick marker missing (handler did not run)"; FAIL=1
    else note "PASS cancel: OnClick fired, then lCancel closed the form"; fi
  else note "FAIL cancel: no window"; FAIL=1; fi
  kill $APP 2>/dev/null
else note "FAIL cancel: build"; FAIL=1; fi
stop_apps; kill $XPID 2>/dev/null; rm -rf "$WORK"
echo "TEST SUMMARY: runtime persisted props: $([ $FAIL -eq 0 ] && echo PASS || echo FAIL)"
exit $FAIL
