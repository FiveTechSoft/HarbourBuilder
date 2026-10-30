#!/usr/bin/env bash
# Wine GUI probe: MULTI-FORM save/reload parity (win32 IDE under Wine + Xvfb).
# Leg1: drop+propedit label on Form1, Save As fixture, File>New Form, drop+propedit
#   on Form2, Save -> assert Form1.prg/Form2.prg/Project1.prg(2x CreateForm)/.hbp.
# Leg2: restart, Open fixture (both form windows must reappear), RAISE Form2 via
#   title bar (forms overlap; a bare click hits the frontmost window), click its
#   label, controlled edit, Save -> assert edit reached disk, Form1.prg unchanged,
#   then a second Save must be a fixpoint. No OCR assertions.
set -u
ROOT="$HOME/HarbourBuilder"
WINE="$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine"
RUN="$(mktemp -d /tmp/designer_mf.XXXXXX)"
# Per-run isolated prefix: scoped 'wineserver -k' kills exactly this probe's tree.
# Fresh-prefix init (wineboot) hangs in the current sandbox, so copy the template.
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine multiform probe: $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" | awk '{print $1}')"
echo "wine: $("$WINE" --version 2>/dev/null) prefix=$WINEPREFIX"
echo "RUN=$RUN DISPLAY=$DISPLAY"
fail() { echo "WINE MULTIFORM FAIL: $* (RUN=$RUN)"; exit 1; }
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
      echo "  window up after ${i}s"
      sleep 10   # bounded settle: default-project creation finishes after window appears
      return 0
    fi
    sleep 1
  done
  fail "IDE window did not appear 90s after launch (see $RUN/ide.log)"
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
comdlg_type_path() { # $1 = Z:\... path ; comdlg filename field ~(200,239)
  xdotool mousemove 200 239 click 1; sleep 0.6
  xdotool key End; sleep 0.4; xdotool key shift+Home; sleep 0.4
  xdotool type --delay 35 "$1"; sleep 0.6
  xdotool key Return; sleep 3
}
inspector_edit() { # $1 = new value; requires the target object already selected
  xdotool mousemove 189 293 click 1; sleep 0.4; xdotool click 1; sleep 1
  xdotool key Home; sleep 0.3; xdotool key shift+End; sleep 0.3
  xdotool type --delay 40 "$1"; sleep 0.4; xdotool key Return; sleep 2
}
save_click() { # File>Save row (95,194)
  file_menu; xdotool mousemove 95 194 click 1; sleep 3
}
WINPATH="Z:${RUN//\//\\}\\Multi.hbp"

# --- leg 1: Form1 label, Save As, New Form, Form2 label, Save ---
launch
dismiss_curl
xdotool mousemove 472 79 click 1; sleep 1
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$F1" ] || fail "Form1 design window not found"
win_geo "$F1"
xdotool mousemove $((X + 200)) $((Y + 110)) click 1; sleep 2
inspector_edit 'HolaF1'
file_menu
xdotool mousemove 95 211 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Save HbBuilder Project' >/dev/null 2>&1 || fail "Save As dialog did not open"
comdlg_type_path "$WINPATH"
[ -f "$RUN/Multi.hbp" ] || fail "Multi.hbp not written"
grep -q 'PROMPT "HolaF1"' "$RUN/Form1.prg" || fail 'PROMPT "HolaF1" missing in Form1.prg'
[ "$(grep -c 'CreateForm' "$RUN/Project1.prg")" = "1" ] || fail "Project1.prg should have 1 CreateForm after first save"
# New Form
file_menu
xdotool mousemove 20 80 click 1; sleep 2
F2=$(xdotool search --onlyvisible --name '^Form2$' 2>/dev/null | head -1)
[ -n "$F2" ] || fail "Form2 design window did not appear after File>New Form"
win_geo "$F2"; F2X=$X; F2Y=$Y; F2W=$WIDTH
xdotool mousemove 472 79 click 1; sleep 1
xdotool mousemove $((F2X + 200)) $((F2Y + 110)) click 1; sleep 2
inspector_edit 'HolaF2'
save_click
grep -q 'PROMPT "HolaF2"' "$RUN/Form2.prg" || fail 'PROMPT "HolaF2" missing in Form2.prg after Save'
grep -q 'PROMPT "HolaF1"' "$RUN/Form1.prg" || fail 'Form1.prg lost HolaF1 on multi-form Save'
[ "$(grep -c 'CreateForm' "$RUN/Project1.prg")" = "2" ] || fail "Project1.prg should have 2 CreateForm after multi-form save"
[ "$(grep -c '^Form' "$RUN/Multi.hbp")" = "2" ] || fail "Multi.hbp should list both forms"
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > "$RUN/f1_leg1.sha"
sha1sum "$RUN/Form2.prg" | awk '{print $1}' > "$RUN/f2_leg1.sha"
echo "  leg1 OK: Form1($(wc -c < "$RUN/Form1.prg")B)+Form2($(wc -c < "$RUN/Form2.prg")B)+Project1+hbp"

# --- leg 2: restart, open, raise Form2, controlled edit, save, fixpoint ---
cleanup; sleep 2
launch
dismiss_curl
file_menu
xdotool mousemove 95 123 click 1; sleep 2
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
sleep 2
# load evidence: both design forms restored
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
F2=$(xdotool search --onlyvisible --name '^Form2$' 2>/dev/null | head -1)
[ -n "$F1" ] && [ -n "$F2" ] || fail "Open did not restore both form windows (F1=$F1 F2=$F2)"
# Form activation is driven by the IDE (SwitchToForm), not by window clicks:
# clicking an inactive form's window does not activate it (validated: the edit
# landed in Form1's cTitle). Use View > Forms... (first menu item), whose
# 'Select a form' dialog is a findable window: click the Form2 row, then OK.
xdotool mousemove 188 36 click 1; sleep 1.2
xdotool mousemove 210 61 click 1; sleep 2
SF=$(xdotool search --onlyvisible --name 'Select a form' 2>/dev/null | head -1)
[ -n "$SF" ] || fail "'Select a form' dialog did not open"
win_geo "$SF"
xdotool mousemove $((X + 60)) $((Y + 38)) click 1; sleep 0.8
xdotool mousemove $((X + 97)) $((Y + 291)) click 1; sleep 2
xdotool search --onlyvisible --name 'Select a form' >/dev/null 2>&1 && fail "'Select a form' dialog did not close"
win_geo "$F2"
xdotool mousemove $((X + 240)) $((Y + 122)) click 1; sleep 2
inspector_edit 'HolaF2b'
save_click
grep -q 'PROMPT "HolaF2b"' "$RUN/Form2.prg" || fail 'controlled edit (HolaF2b) did not reach Form2.prg after reopen'
sha1sum "$RUN/Form2.prg" | awk '{print $1}' > "$RUN/f2_leg2.sha"
cmp -s "$RUN/f2_leg1.sha" "$RUN/f2_leg2.sha" && fail "Form2.prg unchanged after controlled edit (save ineffective)"
cmp -s "$RUN/f1_leg1.sha" <(sha1sum "$RUN/Form1.prg" | awk '{print $1}') || fail "Form1.prg changed while editing Form2 (cross-form contamination)"
[ "$(grep -c 'CreateForm' "$RUN/Project1.prg")" = "2" ] || fail "Project1.prg lost a CreateForm after reopen+save"
# second save without changes must be a fixpoint
save_click
cmp -s "$RUN/f2_leg2.sha" <(sha1sum "$RUN/Form2.prg" | awk '{print $1}') || fail "second save not a fixpoint (Form2.prg)"
import -window root "$RUN/reopened.png" 2>/dev/null
echo "WINE MULTIFORM PASS: F1 edit -> save -> NewForm -> F2 edit -> save(4 files) -> restart -> open(both forms) -> raise F2 -> edit -> save -> fixpoint (RUN=$RUN)"
