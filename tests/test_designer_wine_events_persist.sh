#!/usr/bin/env bash
# Wine GUI probe: EVENTS PERSISTENCE across open/save (handler+wiring already in
# a hand-crafted fixture shaped exactly like the serializer's own output).
# Open fixture -> click label (load proof) -> Save -> Form1.prg must still
# contain 'static function Label1Click' AND '::oLabel1:OnClick :=' -> Save again
# must be a fixpoint. The interactive creation path (Events tab dblclick) is
# blocked under Wine (tab control ignores mouse selection; see events probe).
set -u
ROOT="$HOME/HarbourBuilder"
WINE="$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine"
RUN="$(mktemp -d /tmp/designer_evp.XXXXXX)"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
cp /tmp/evfix/Form1.prg /tmp/evfix/Project1.prg /tmp/evfix/EvFix.hbp "$RUN/"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine events-persist probe: $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" | awk '{print $1}')"
echo "RUN=$RUN fixture=$(sha256sum "$RUN/Form1.prg" | awk '{print $1}')"
fail() { echo "WINE EVENTS-PERSIST FAIL: $* (RUN=$RUN)"; exit 1; }
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
WINPATH="Z:${RUN//\//\\}\\EvFix.hbp"

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
  xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 && break
  sleep 1
done
xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 || fail "Open dialog did not open"
comdlg_type_path "$WINPATH"
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$F1" ] || fail "Form1 did not appear after Open"
win_geo "$F1"
xdotool mousemove $((X + 205)) $((Y + 115)) click 1; sleep 2   # load proof: click label
file_menu; xdotool mousemove 95 194 click 1; sleep 3          # Save
grep -q 'static function Label1Click' "$RUN/Form1.prg" || { echo "--- Form1.prg after save:"; cat "$RUN/Form1.prg"; fail 'PERSIST: handler stub lost after open+save'; }
grep -q '::oLabel1:OnClick :=' "$RUN/Form1.prg" || { echo "--- Form1.prg after save:"; cat "$RUN/Form1.prg"; fail 'PERSIST: OnClick wiring lost after open+save'; }
echo "  save1 keeps stub + wiring"
S1=$(sha256sum "$RUN/Form1.prg" | awk '{print $1}')
file_menu; xdotool mousemove 95 194 click 1; sleep 3          # Save again
S2=$(sha256sum "$RUN/Form1.prg" | awk '{print $1}')
[ "$S1" = "$S2" ] || fail "second save not a fixpoint ($S1 != $S2)"
echo "WINE EVENTS-PERSIST PASS (RUN=$RUN)"
