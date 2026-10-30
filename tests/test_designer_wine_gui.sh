#!/usr/bin/env bash
# GUI probe: HarbourBuilder Windows IDE (mingw build) under Wine.
# Covers: startup, curl modal dismiss, palette drop (TLabel), Inspector inline
# edit of cText, Save As roundtrip to a temp fixture, process restart, Open,
# re-save fixpoint. Assertions are on saved files (robust), not OCR.
# Requires: bin/hbbuilder_win.exe (build_win_mingw.sh), Kron4ek wine at
# $HOME/wine-toolchain/wine-11.20-amd64-wow64, Xvfb. No root needed.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WINE="${WINE:-$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine}"
export WINEPREFIX="${WINEPREFIX:-$HOME/wine-toolchain/prefix}" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
RUN="$(mktemp -d /tmp/designer_wine.XXXXXX)"
echo "== wine designer probe: $(date -Is) HEAD $(git -C "$ROOT" rev-parse HEAD 2>/dev/null) RUN=$RUN =="
[ -x "$ROOT/bin/hbbuilder_win.exe" ] || { echo "FAIL: bin/hbbuilder_win.exe missing (run build_win_mingw.sh)"; exit 1; }
[ -x "$WINE" ] || { echo "FAIL: wine not found at $WINE"; exit 1; }

fail() { echo "WINE DESIGNER FAIL: $1"; exit 1; }
cleanup() { pkill -f hbbuilder_win >/dev/null 2>&1; }
trap cleanup EXIT

pgrep Xvfb >/dev/null || { Xvfb "$DISPLAY" -screen 0 1600x1000x24 & sleep 1; }

win_geo() { # $1 window id -> sets X Y W H
  eval "$(xdotool getwindowgeometry --shell "$1" 2>/dev/null)"
}
launch() {
  setsid nohup "$WINE" "$ROOT/bin/hbbuilder_win.exe" >"$RUN/ide.log" 2>&1 < /dev/null &
  sleep 13
  pgrep -f hbbuilder_win >/dev/null || fail "IDE process not alive 13s after launch"
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
comdlg_type_path() { # $1 = Z:\... path ; assumes dialog at (3,48) 420x239
  xdotool mousemove 200 239 click 1; sleep 0.6
  xdotool key End; sleep 0.4; xdotool key shift+Home; sleep 0.4
  xdotool type --delay 35 "$1"; sleep 0.6
  xdotool key Return; sleep 3
}
WINPATH="Z:${RUN//\//\\}\\Project1.hbp"

# --- leg 1: launch, drop, edit, save ---
launch
dismiss_curl
# palette TLabel (Standard tab, first icon) then click design form
xdotool mousemove 472 79 click 1; sleep 1
FORM=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$FORM" ] || fail "design form window not found"
win_geo "$FORM"
xdotool mousemove $((X + 200)) $((Y + 110)) click 1; sleep 2
# Inspector inline edit of cText row (default layout: Inspector at x0, row y293)
xdotool mousemove 189 293 click 1; sleep 0.4; xdotool click 1; sleep 1
xdotool key Home; sleep 0.3; xdotool key shift+End; sleep 0.3
xdotool type --delay 40 'HolaWine'; sleep 0.4; xdotool key Return; sleep 2
# Save As to fixture
file_menu
xdotool mousemove 95 211 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Save HbBuilder Project' >/dev/null 2>&1 || fail "Save As dialog did not open"
comdlg_type_path "$WINPATH"
[ -f "$RUN/Project1.hbp" ] || fail "Project1.hbp not written"
grep -q 'PROMPT "HolaWine"' "$RUN/Form1.prg" || fail 'PROMPT "HolaWine" missing in saved Form1.prg'
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > "$RUN/save1.sha"
echo "  leg1 OK: drop+edit+save, $(wc -c < "$RUN/Form1.prg") bytes Form1.prg"

# --- leg 2: restart, open, verify, re-save fixpoint ---
cleanup; sleep 2
launch
dismiss_curl
file_menu
xdotool mousemove 95 123 click 1; sleep 2
# optional "Save current project before opening?" prompt (Yes/No/Cancel): click No
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
# re-save (File > Save) and require fixpoint
file_menu
xdotool mousemove 95 194 click 1; sleep 3
grep -q 'PROMPT "HolaWine"' "$RUN/Form1.prg" || fail 'PROMPT "HolaWine" lost after reopen+resave'
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > "$RUN/save2.sha"
cmp -s "$RUN/save1.sha" "$RUN/save2.sha" || fail "re-save not a fixpoint after reload"
import -window root "$RUN/reloaded.png" 2>/dev/null
echo "WINE DESIGNER PASS: drop -> inspector edit -> save -> restart -> open -> fixpoint (RUN=$RUN)"
cleanup
