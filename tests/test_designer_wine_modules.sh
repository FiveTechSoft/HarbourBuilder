#!/usr/bin/env bash
# Wine GUI probe: MODULE multi-file parity (win32 IDE under Wine + Xvfb).
# Targets editor-buffer persistence to the correct destination:
# Leg1: Save As project fixture, File>Add Module (existing ModExtra.prg picked via
#   dialog), edit the module BUFFER in the code editor (marker line), Save ->
#   assert marker reached $RUN/ModExtra.prg, .hbp gained [modules] ModExtra,
#   Form1.prg untouched.
# Leg2: restart, Open fixture, select the module TAB (3rd tab, position derived
#   from the runtime-located 'Code Editor' window), edit buffer (marker2), Save ->
#   assert marker2 in ModExtra.prg, Form1.prg byte-identical to leg1 (no
#   cross-destination write), .hbp keeps the module, second Save = fixpoint.
set -u
ROOT="$HOME/HarbourBuilder"
WINE="$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine"
RUN="$(mktemp -d /tmp/designer_mod.XXXXXX)"
# Per-run isolated prefix: scoped 'wineserver -k' kills exactly this probe's tree.
# Fresh-prefix init (wineboot) hangs in the current sandbox, so copy the template.
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine modules probe: $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" | awk '{print $1}')"
echo "wine: $("$WINE" --version 2>/dev/null) prefix=$WINEPREFIX"
echo "RUN=$RUN DISPLAY=$DISPLAY"
fail() { echo "WINE MODULES FAIL: $* (RUN=$RUN)"; exit 1; }
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
    if xdotool search --onlyvisible --name 'Visual IDE for Harbour' >/dev/null 2>&1; then
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
save_click() { file_menu; xdotool mousemove 95 194 click 1; sleep 3; }
edit_module_buffer() { # $1 = marker text ; requires module tab already selected
  local CE CX CY g
  CE=$(xdotool search --onlyvisible --name '^Code Editor$' 2>/dev/null | head -1)
  [ -n "$CE" ] || fail "Code Editor window not found"
  g=$(xdotool getwindowgeometry "$CE")
  CX=$(echo "$g"|awk -F'[ ,]' '/Position/{print $4}'); CY=$(echo "$g"|awk -F'[ ,]' '/Position/{print $5}')
  xdotool mousemove $((CX + 200)) $((CY + 80)) click 1; sleep 1
  xdotool key ctrl+End; sleep 0.5; xdotool key Return; sleep 0.3
  xdotool type --delay 40 "$1"; sleep 0.5
}
printf '// ModExtra.prg\nFUNCTION ModExtraOriginal()\nRETURN nil\n' > "$RUN/ModExtra.prg"
WINPATH="Z:${RUN//\//\\}\\Mod.hbp"
WINMOD="Z:${RUN//\//\\}\\ModExtra.prg"

# --- leg 1: save project, add module, edit buffer, save ---
launch
dismiss_curl
file_menu
xdotool mousemove 95 211 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Save HbBuilder Project' >/dev/null 2>&1 || fail "Save As dialog did not open"
comdlg_type_path "$WINPATH"
[ -f "$RUN/Mod.hbp" ] || fail "Mod.hbp not written"
file_menu
xdotool mousemove 20 97 click 1; sleep 2
xdotool search --onlyvisible --name 'Add Module' >/dev/null 2>&1 || fail "Add Module dialog did not open"
comdlg_type_path "$WINMOD"
edit_module_buffer '// MARCADOR_MOD_1'
save_click
grep -q 'MARCADOR_MOD_1' "$RUN/ModExtra.prg" || fail 'marker1 did not reach ModExtra.prg (module buffer not persisted)'
grep -q 'ModExtraOriginal' "$RUN/ModExtra.prg" || fail 'original module content lost on save'
grep -q '^\[modules\]' "$RUN/Mod.hbp" && grep -q '^ModExtra' "$RUN/Mod.hbp" || fail "Mod.hbp missing [modules] ModExtra"
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > "$RUN/f1_leg1.sha"
sha1sum "$RUN/ModExtra.prg" | awk '{print $1}' > "$RUN/mod_leg1.sha"
echo "  leg1 OK: module added+edited+saved (ModExtra.prg $(wc -c < "$RUN/ModExtra.prg")B)"

# --- leg 2: restart, open, select module tab, edit buffer, save, fixpoint ---
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
# select the module tab: 3rd tab, position derived from the runtime-located
# 'Code Editor' window (tab strip offsets measured: 3rd tab center +177/+29)
CE=$(xdotool search --onlyvisible --name '^Code Editor$' 2>/dev/null | head -1)
[ -n "$CE" ] || fail "Code Editor window not found after Open"
win_geo "$CE"
xdotool mousemove $((X + 177)) $((Y + 29)) click 1; sleep 2
edit_module_buffer '// MARCADOR_MOD_2'
save_click
grep -q 'MARCADOR_MOD_2' "$RUN/ModExtra.prg" || fail 'marker2 did not reach ModExtra.prg after reopen (buffer or destination wrong)'
grep -q 'MARCADOR_MOD_1' "$RUN/ModExtra.prg" || fail 'marker1 lost after reopen+save'
sha1sum "$RUN/ModExtra.prg" | awk '{print $1}' > "$RUN/mod_leg2.sha"
cmp -s "$RUN/mod_leg1.sha" "$RUN/mod_leg2.sha" && fail "ModExtra.prg unchanged after controlled edit (save ineffective)"
cmp -s "$RUN/f1_leg1.sha" <(sha1sum "$RUN/Form1.prg" | awk '{print $1}') || fail "Form1.prg changed while editing module buffer (wrong-destination write)"
grep -q '^ModExtra' "$RUN/Mod.hbp" || fail "Mod.hbp lost the module after reopen+save"
save_click
cmp -s "$RUN/mod_leg2.sha" <(sha1sum "$RUN/ModExtra.prg" | awk '{print $1}') || fail "second save not a fixpoint (ModExtra.prg)"
echo "WINE MODULES PASS: save -> AddModule -> buffer edit -> save -> restart -> open -> tab select -> buffer edit -> save(correct destination, Form1 intact) -> fixpoint (RUN=$RUN)"
