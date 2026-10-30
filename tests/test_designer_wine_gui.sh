#!/usr/bin/env bash
# GUI probe: HarbourBuilder Windows IDE (mingw build) under Wine.
# Leg1: startup, curl modal dismiss, palette drop (TLabel), drag, Inspector
#   inline edit of cText, Save As to temp fixture (asserts on saved file).
# Leg2: full process restart, File>Open of the fixture, effective-load proof:
#   click the RELOADED label (only exists if the fixture loaded), edit cText to
#   a NEW value, File>Save, assert the modification reached disk, then a second
#   Save must be a fixpoint. No OCR assertions.
# Requires: bin/hbbuilder_win.exe (build_win_mingw.sh), Kron4ek wine at
# $HOME/wine-toolchain/wine-11.20-amd64-wow64, Xvfb. No root needed.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WINE="${WINE:-$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine}"
RUN="$(mktemp -d /tmp/designer_wine.XXXXXX)"
# Per-run isolated prefix so scoped 'wineserver -k' kills exactly this probe's tree.
# NOTE: fresh-prefix init (wineboot) hangs in the current sandbox state, so the
# per-run prefix is a copy of the already-initialized template prefix.
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine designer probe: $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" 2>/dev/null | awk '{print $1}')"
echo "wine: $("$WINE" --version 2>/dev/null) prefix=$WINEPREFIX"
echo "RUN=$RUN DISPLAY=$DISPLAY"
[ -x "$ROOT/bin/hbbuilder_win.exe" ] || { echo "FAIL: bin/hbbuilder_win.exe missing (run build_win_mingw.sh)"; exit 1; }
[ -x "$WINE" ] || { echo "FAIL: wine not found at $WINE"; exit 1; }

fail() { echo "WINE DESIGNER FAIL: $1"; exit 1; }
WINESERVER="$(dirname "$WINE")/wineserver"
cleanup() { [ -x "$WINESERVER" ] && WINEPREFIX="$WINEPREFIX" "$WINESERVER" -k 2>/dev/null; }
trap cleanup EXIT

pgrep Xvfb >/dev/null || { Xvfb "$DISPLAY" -screen 0 1600x1000x24 & sleep 1; }

win_geo() { eval "$(xdotool getwindowgeometry --shell "$1" 2>/dev/null)"; } # sets X Y WIDTH HEIGHT
launch() {
  setsid nohup "$WINE" "$ROOT/bin/hbbuilder_win.exe" >>"$RUN/ide.log" 2>&1 < /dev/null &
  # cold-prefix init can take tens of seconds: poll for the main window up to 90s
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
  local w try
  for try in 1 2 3 4 5; do
    w=$(xdotool search --onlyvisible --name 'curl.exe Not Found' 2>/dev/null | head -1)
    if [ -n "$w" ]; then
      win_geo "$w"
      xdotool mousemove $((X + WIDTH/2)) $((Y + HEIGHT - 21)) click 1; sleep 1.5
    fi
    xdotool search --onlyvisible --name 'curl.exe Not Found' >/dev/null 2>&1 || return 0
    sleep 1
  done
  fail "curl.exe modal did not dismiss"
}
file_menu() { xdotool mousemove 12 33 click 1; sleep 1; }
comdlg_type_path() { # $1 = Z:\... path ; comdlg at (3,48) 420x239, filename field ~(200,239)
  xdotool mousemove 200 239 click 1; sleep 0.6
  xdotool key End; sleep 0.4; xdotool key shift+Home; sleep 0.4
  xdotool type --delay 35 "$1"; sleep 0.6
  xdotool key Return; sleep 3
}
inspector_edit_ctext() { # $1 = new value; requires the control already selected
  xdotool mousemove 189 293 click 1; sleep 0.4; xdotool click 1; sleep 1
  xdotool key Home; sleep 0.3; xdotool key shift+End; sleep 0.3
  xdotool type --delay 40 "$1"; sleep 0.4; xdotool key Return; sleep 2
}
WINPATH="Z:${RUN//\//\\}\\Project1.hbp"

# --- leg 1: launch, drop, drag, edit, save ---
launch
dismiss_curl
xdotool mousemove 472 79 click 1; sleep 1
FORM=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$FORM" ] || fail "design form window not found"
win_geo "$FORM"
DROPX=$((X + 200)); DROPY=$((Y + 110))
xdotool mousemove $DROPX $DROPY click 1; sleep 2
# drag the dropped label +150/+80 screen px
LBLX=$((DROPX + 40)); LBY=$((DROPY + 12))
xdotool mousemove $LBLX $LBY mousedown 1; sleep 0.5
xdotool mousemove --sync $((LBLX + 70)) $((LBY + 40)); sleep 0.3
xdotool mousemove --sync $((LBLX + 150)) $((LBY + 80)); sleep 0.5
xdotool mouseup 1; sleep 2
DRAGLBLX=$((LBLX + 150)); DRAGLBY=$((LBY + 80))
inspector_edit_ctext 'HolaWine'
file_menu
xdotool mousemove 95 211 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Save HbBuilder Project' >/dev/null 2>&1 || fail "Save As dialog did not open"
comdlg_type_path "$WINPATH"
[ -f "$RUN/Project1.hbp" ] || fail "Project1.hbp not written"
grep -q 'PROMPT "HolaWine"' "$RUN/Form1.prg" || fail 'PROMPT "HolaWine" missing in saved Form1.prg'
grep -q '@ 184, 348 SAY' "$RUN/Form1.prg" || fail 'drag coords (@ 184, 348) missing in saved Form1.prg'
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > "$RUN/save1.sha"
echo "  leg1 OK: drop+drag+edit+save, $(wc -c < "$RUN/Form1.prg") bytes Form1.prg"

# --- leg 2: restart, open, prove effective load, controlled edit, save, fixpoint ---
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
# effective-load proof: click the reloaded label where leg1 left it (screen coords of the drag landing)
xdotool mousemove $DRAGLBLX $DRAGLBY click 1; sleep 2
# controlled modification that must reach disk
inspector_edit_ctext 'HolaWine2'
file_menu
xdotool mousemove 95 194 click 1; sleep 3
grep -q 'PROMPT "HolaWine2"' "$RUN/Form1.prg" || fail 'controlled edit (HolaWine2) did not reach disk after reopen (load or save ineffective)'
grep -q '@ 184, 348 SAY' "$RUN/Form1.prg" || fail 'loaded drag coords lost after reopen+save'
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > "$RUN/save2.sha"
cmp -s "$RUN/save1.sha" "$RUN/save2.sha" && fail "file unchanged after controlled edit (save ineffective)"
# second save without changes must be a fixpoint
file_menu
xdotool mousemove 95 194 click 1; sleep 3
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > "$RUN/save3.sha"
cmp -s "$RUN/save2.sha" "$RUN/save3.sha" || fail "second save not a fixpoint"
import -window root "$RUN/reloaded.png" 2>/dev/null
echo "WINE DESIGNER PASS: drop -> drag -> edit -> save -> restart -> open(load proven) -> edit -> save -> fixpoint (RUN=$RUN)"
cleanup
