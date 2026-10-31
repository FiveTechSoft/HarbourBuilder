#!/usr/bin/env bash
# Wine GUI probe: EVENTS roundtrip (win32 IDE under Wine + Xvfb).
# Leg1: drop TLabel on Form1, switch Inspector to the Events tab (click verified
#   by pixels+OCR, one retry), dblclick the OnClick row -> OnEventDblClick must
#   generate the handler stub + wiring; Save As fixture -> assert Form1.prg has
#   'static function Label1Click' AND '::oLabel1:OnClick :='.
# Leg2: restart, Open fixture, click label (load proof), Save -> handler+wiring
#   still present; second Save must be a fixpoint. No stage claims beyond this.
set -u
ROOT="$HOME/HarbourBuilder"
WINE="$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine"
RUN="$(mktemp -d /tmp/designer_ev.XXXXXX)"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine events probe: $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" | awk '{print $1}')"
echo "RUN=$RUN"
fail() { echo "WINE EVENTS FAIL: $* (RUN=$RUN)"; exit 1; }
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
insp_shot() { import -window root "$1"; }
insp_list_has_onclick() { # OCR the inspector list area (root coords) for OnClick
  python3 -c "
from PIL import Image
im=Image.open('$1'); im.crop((0,180,340,640)).resize((1360,1840),Image.LANCZOS).save('$1.crop.png')"
  tesseract "$1.crop.png" stdout --psm 6 2>/dev/null | grep -qi 'onclick'
}
insp_onclick_row_y() { # TSV: root-coord y of the OnClick events row
  python3 -c "
from PIL import Image
im=Image.open('$1'); im.crop((0,180,340,640)).resize((1360,1840),Image.LANCZOS).save('$1.crop.png')"
  tesseract "$1.crop.png" stdout --psm 6 tsv 2>/dev/null | \
    awk -F'\t' 'tolower($12) ~ /onclick/ {print int($8/4+180); exit}'
}
switch_to_events() { # activate inspector by caption, click Events tab, verify
  local try
  for try in 1 2; do
    xdotool mousemove 150 118 click 1; sleep 1          # caption: activate window
    insp_shot "$RUN/tab_before.png"
    xdotool mousemove 105 166 click 1; sleep 0.5; xdotool click 1; sleep 1.5
    insp_shot "$RUN/tab_after.png"
    if insp_list_has_onclick "$RUN/tab_after.png"; then echo "  Events tab switched (try $try)"; return 0; fi
    python3 - <<EOF
from PIL import Image, ImageChops
a=Image.open('$RUN/tab_before.png').crop((0,155,340,190)).convert('L')
b=Image.open('$RUN/tab_after.png').crop((0,155,340,190)).convert('L')
print('  tab strip diff bbox:', ImageChops.difference(a,b).getbbox())
EOF
    sleep 1
  done
  fail "Events tab did not switch by mouse (verified coords root ~(105,166); strip diff above)"
}
WINPATH="Z:${RUN//\//\\}\\Events.hbp"

# --- leg 1: drop label, Events tab, dblclick OnClick, Save As ---
launch; dismiss_curl
xdotool mousemove 472 79 click 1; sleep 1
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$F1" ] || fail "Form1 design window not found"
win_geo "$F1"
xdotool mousemove $((X + 200)) $((Y + 110)) click 1; sleep 2
switch_to_events
ROWY=$(insp_onclick_row_y "$RUN/tab_after.png")
[ -n "$ROWY" ] || fail "OnClick row not found in Events list OCR"
echo "  OnClick row at root y=$ROWY; dblclick"
xdotool mousemove 150 "$ROWY" click --repeat 2 --delay 80 1; sleep 3
file_menu; xdotool mousemove 95 211 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Save HbBuilder Project' >/dev/null 2>&1 || fail "Save As dialog did not open"
comdlg_type_path "$WINPATH"
[ -f "$RUN/Events.hbp" ] || fail "Events.hbp not written"
grep -q 'static function Label1Click' "$RUN/Form1.prg" || { echo "--- Form1.prg tail:"; tail -20 "$RUN/Form1.prg"; fail 'handler stub missing in Form1.prg (events silent-loss?)'; }
grep -q '::oLabel1:OnClick :=' "$RUN/Form1.prg" || fail 'OnClick wiring missing in Form1.prg'
echo "  leg1 OK: stub + wiring present"

# --- leg 2: restart, open, click label, save, persistence + fixpoint ---
"$WINESERVER" -k 2>/dev/null; sleep 3
launch; dismiss_curl
file_menu; xdotool mousemove 95 123 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 || fail "Open dialog did not open"
comdlg_type_path "$WINPATH"
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$F1" ] || fail "Form1 did not reappear after Open"
win_geo "$F1"
xdotool mousemove $((X + 200)) $((Y + 110)) click 1; sleep 2   # load proof: click label
file_menu; xdotool mousemove 95 194 click 1; sleep 3          # Save
grep -q 'static function Label1Click' "$RUN/Form1.prg" || fail 'ROUNDTRIP: handler lost after reload'
grep -q '::oLabel1:OnClick :=' "$RUN/Form1.prg" || fail 'ROUNDTRIP: wiring lost after reload'
S1=$(sha256sum "$RUN/Form1.prg" | awk '{print $1}')
file_menu; xdotool mousemove 95 194 click 1; sleep 3          # Save again
S2=$(sha256sum "$RUN/Form1.prg" | awk '{print $1}')
[ "$S1" = "$S2" ] || fail "second save not a fixpoint ($S1 != $S2)"
echo "WINE EVENTS PASS (RUN=$RUN)"
