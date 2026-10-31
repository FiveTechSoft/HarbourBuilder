#!/usr/bin/env bash
# Wine GUI probe: TAB activation destination (win32 IDE under Wine + Xvfb).
# The ghost-fix acceptance proved View>Forms activation + destination, and a manual
# session showed a Code-Editor tab click only MAPS the inactive form. This probe
# asserts the edit DESTINATION through tab activation: open 2-form fixture (real
# IDE-saved files in tests/fixtures/multiform) -> Form2 must NOT be mapped (ghost
# guard) -> click CE tab Form2.prg -> Form2 mapped -> click its label -> edit via
# Inspector -> Save must land in Form2.prg with Form1.prg untouched -> fixpoint.
set -u
ROOT="$HOME/HarbourBuilder"
WINE="$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine"
RUN="$(mktemp -d /tmp/designer_tabact.XXXXXX)"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
cp "$ROOT/tests/fixtures/multiform/Form1.prg" "$ROOT/tests/fixtures/multiform/Form2.prg" \
   "$ROOT/tests/fixtures/multiform/Project1.prg" "$ROOT/tests/fixtures/multiform/Multi.hbp" "$RUN/"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine tab-activate probe: $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" | awk '{print $1}')"
echo "RUN=$RUN fixtureF2=$(sha256sum "$RUN/Form2.prg" | awk '{print $1}')"
fail() { echo "WINE TABACT FAIL: $* (RUN=$RUN)"; exit 1; }
WINESERVER="$(dirname "$WINE")/wineserver"
cleanup() { [ -x "$WINESERVER" ] && WINEPREFIX="$WINEPREFIX" "$WINESERVER" -k 2>/dev/null; }
trap cleanup EXIT
win_geo() { local g; g=$(xdotool getwindowgeometry "$1") || return 1
  X=$(echo "$g" | awk -F'[ ,]' '/Position/{print $4}'); Y=$(echo "$g" | awk -F'[ ,]' '/Position/{print $5}')
  WIDTH=$(echo "$g" | awk -F'[ x]' '/Geometry/{print $4}'); HEIGHT=$(echo "$g" | awk -F'[ x]' '/Geometry/{print $5}'); }
launch() {
  setsid nohup "$WINE" "$ROOT/bin/hbbuilder_win.exe" >>"$RUN/ide.log" 2>&1 < /dev/null &
  local i
  for i in $(seq 1 90); do
    if xdotool search --onlyvisible --name 'HbBuilder 1.4.4' >/dev/null 2>&1; then
      echo "  window up after ${i}s"; sleep 10; return 0
    fi
    sleep 1
  done
  fail "IDE window did not appear 90s after launch"
}
dismiss_curl() {
  local i W
  for i in $(seq 1 25); do
    W=$(xdotool search --onlyvisible --name 'Not Found' 2>/dev/null | head -1)
    if [ -n "$W" ]; then win_geo "$W"; xdotool mousemove $((X + WIDTH/2)) $((Y + HEIGHT - 21)) click 1; sleep 2
      xdotool search --onlyvisible --name 'Not Found' >/dev/null 2>&1 || return 0
    fi
    sleep 1
  done
  xdotool search --onlyvisible --name 'curl.exe Not Found' >/dev/null 2>&1 || return 0
  fail "curl.exe modal did not dismiss"
}
file_menu() { xdotool mousemove 12 33 click 1; sleep 1; }
comdlg_type_path() {
  xdotool mousemove 200 239 click 1; sleep 0.6
  xdotool key End; sleep 0.4; xdotool key shift+Home; sleep 0.4
  xdotool type --delay 35 "$1"; sleep 0.6; xdotool key Return; sleep 3
}
inspector_edit() {
  xdotool mousemove 189 293 click 1; sleep 0.4; xdotool click 1; sleep 1
  xdotool key Home; sleep 0.3; xdotool key shift+End; sleep 0.3
  xdotool type --delay 40 "$1"; sleep 0.4; xdotool key Return; sleep 2
}
save_click() { file_menu; xdotool mousemove 95 194 click 1; sleep 3; }
WINPATH="Z:${RUN//\//\\}\\Multi.hbp"

launch; dismiss_curl
file_menu; xdotool mousemove 95 123 click 1; sleep 2
QP=""
for try in 1 2 3; do
  QP=$(xdotool search --onlyvisible --name '^HbBuilder$' 2>/dev/null | head -1)
  [ -n "$QP" ] && break
  xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 && break
  sleep 1
done
if [ -n "$QP" ]; then win_geo "$QP"; xdotool mousemove $((X + WIDTH/2 + 13)) $((Y + HEIGHT - 21)) click 1; sleep 2; fi
for try in 1 2 3 4 5; do
  xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 && break; sleep 1
done
xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 || fail "Open dialog did not open"
comdlg_type_path "$WINPATH"
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
F2=$(xdotool search --onlyvisible --name '^Form2$' 2>/dev/null | head -1)
[ -n "$F1" ] || fail "Open did not restore the active form window"
[ -z "$F2" ] || fail "inactive Form2 is mapped right after Open (ghost window)"
F1SHA=$(sha256sum "$RUN/Form1.prg" | awk '{print $1}')

# activate Form2 via the Code Editor tab (tab strip: 3rd tab ~= CE + (177,29))
CE=$(xdotool search --onlyvisible --name '^Code Editor$' 2>/dev/null | head -1)
[ -n "$CE" ] || fail "Code Editor window not found"
win_geo "$CE"
xdotool mousemove $((X + 177)) $((Y + 29)) click 1; sleep 2
F2=$(xdotool search --onlyvisible --name '^Form2$' 2>/dev/null | head -1)
[ -n "$F2" ] || fail "Form2 not mapped after CE tab click (tab activation did not show the form)"
echo "  Form2 mapped via CE tab click"
win_geo "$F2"
xdotool mousemove $((X + 240)) $((Y + 122)) click 1; sleep 2   # click Form2's label
inspector_edit 'TabDest2'
save_click
grep -q 'PROMPT "TabDest2"' "$RUN/Form2.prg" || { echo "--- Form2.prg:"; cat "$RUN/Form2.prg"; fail 'TAB-DEST: edit did not reach Form2.prg after tab activation'; }
grep -q 'TabDest2' "$RUN/Form1.prg" && fail "TAB-DEST: edit leaked into Form1.prg (wrong destination)"
[ "$(sha256sum "$RUN/Form1.prg" | awk '{print $1}')" = "$F1SHA" ] || fail "Form1.prg changed while editing tab-activated Form2"
S1=$(sha256sum "$RUN/Form2.prg" | awk '{print $1}')
save_click
[ "$(sha256sum "$RUN/Form2.prg" | awk '{print $1}')" = "$S1" ] || fail "second save not a fixpoint (Form2.prg)"
echo "WINE TABACT PASS (RUN=$RUN)"
