#!/usr/bin/env bash
# Wine GUI probe: File > Reopen Last Project contract (win32 IDE under Wine + Xvfb).
# Contract per source (hbbuilder_win.prg): recents are added ONLY by OpenProjectFile
#   (:3677 AddRecentProject), persisted in hbbuilder.ini keys File1..N (host-visible);
#   TBSave/Save As does NOT add; ReopenLastProject (:3720) opens ATail(GetRecentProjects)
#   or shows MsgInfo "No recent project..." when empty; GetRecentProjects drops
#   entries whose file no longer exists.
# Leg A: empty recents + Save As own fixture -> INI must NOT gain the path;
#   Reopen -> MsgInfo dialog expected.
# Leg B: File > Open marked fixture (cTitle ReopenMark) -> INI File1 = its path;
#   restart -> Reopen -> window '^ReopenMark$' appears with NO Open dialog.
set -u
ROOT="$HOME/HarbourBuilder"
WINE="$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine"
RUN="$(mktemp -d /tmp/designer_reopen.XXXXXX)"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
INI="$ROOT/hbbuilder.ini"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine reopenlast probe: $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" | awk '{print $1}')"
echo "RUN=$RUN"
fail() { echo "WINE REOPENLAST FAIL: $* (RUN=$RUN)"; exit 1; }
WINESERVER="$(dirname "$WINE")/wineserver"
cleanup() { [ -x "$WINESERVER" ] && WINEPREFIX="$WINEPREFIX" "$WINESERVER" -k 2>/dev/null
  if [ -f "$RUN/ini.bak" ]; then cp "$RUN/ini.bak" "$INI"; else rm -f "$INI"; fi; }
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
click_dialog_button() { # $1 = x offset from center
  local W
  W=$(xdotool search --onlyvisible --name '^HbBuilder$' 2>/dev/null | head -1)
  [ -n "$W" ] || return 1
  win_geo "$W"; xdotool mousemove $((X + WIDTH/2 + $1)) $((Y + HEIGHT - 21)) click 1; sleep 2
}

# marked fixture (own work): same shape as events fixture, distinctive cTitle
mkdir -p "$RUN/marked"
sed 's/::cTitle  := "Form1"/::cTitle  := "ReopenMark"/' "$ROOT/tests/fixtures/events_persist/Form1.prg" > "$RUN/marked/Form1.prg"
cp "$ROOT/tests/fixtures/events_persist/Project1.prg" "$RUN/marked/Project1.prg"
printf 'Project1\nForm1\n' > "$RUN/marked/Marked.hbp"
MARKED_WINPATH="Z:${RUN//\//\\}\\marked\\Marked.hbp"
ASONLY_WINPATH="Z:${RUN//\//\\}\\AsOnly.hbp"

# isolate INI (backup + empty recents)
[ -f "$INI" ] && cp "$INI" "$RUN/ini.bak"
rm -f "$INI"

# --- leg A: Save As must NOT add recents; Reopen with empty list -> MsgInfo ---
launch; dismiss_curl
file_menu; xdotool mousemove 95 211 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Save HbBuilder Project' >/dev/null 2>&1 || fail "Save As dialog did not open"
comdlg_type_path "$ASONLY_WINPATH"
[ -f "$RUN/AsOnly.hbp" ] || fail "AsOnly.hbp not written"
if [ -f "$INI" ] && grep -qi 'asonly' "$INI"; then fail "CONTRACT: Save As added a recent entry (code says only OpenProjectFile does)"; fi
echo "  legA1 OK: Save As did not add recents (ini: $([ -f "$INI" ] && wc -c < "$INI" || echo 0) bytes)"
file_menu; xdotool key l; sleep 2.5   # Reopen &Last Project (accelerator)
D=""
for i in 1 2 3 4 5; do D=$(xdotool search --onlyvisible --name '^HbBuilder$' 2>/dev/null | head -1); [ -n "$D" ] && break; sleep 1; done
if [ -n "$D" ]; then
  import -window "$D" "$RUN/msginfo.png"
  echo "  legA2: 'HbBuilder' dialog appeared (expected MsgInfo 'No recent project'); shot $RUN/msginfo.png"
  click_dialog_button 0   # OK centered
else
  fail "legA2: no MsgInfo dialog after Reopen with empty recents (expected 'No recent project')"
fi
xdotool search --onlyvisible --name '^Form1$' >/dev/null 2>&1 || fail "default Form1 gone unexpectedly after leg A"

# --- leg B: Open marked fixture -> INI File1; restart; Reopen -> ReopenMark ---
file_menu; xdotool mousemove 95 123 click 1; sleep 2.5
QP=$(xdotool search --onlyvisible --name '^HbBuilder$' 2>/dev/null | head -1)
[ -n "$QP" ] && click_dialog_button 13   # save prompt Yes/No: No
for i in 1 2 3 4 5; do xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 && break; sleep 1; done
xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 || fail "Open dialog did not open (leg B)"
comdlg_type_path "$MARKED_WINPATH"
xdotool search --onlyvisible --name '^ReopenMark$' >/dev/null 2>&1 || fail "ReopenMark window not shown after Open (load failed?)"
sleep 2
[ -f "$INI" ] || fail "INI not recreated after Open"
grep -qiF 'marked\Marked.hbp' "$INI" || { echo "--- INI:"; cat "$INI"; fail "INI FileN does not point at the opened fixture"; }
echo "  legB1 OK: INI recents gained the opened fixture: $(grep -i marked "$INI" | head -1)"
"$WINESERVER" -k 2>/dev/null; sleep 3
launch; dismiss_curl
xdotool search --onlyvisible --name '^ReopenMark$' >/dev/null 2>&1 && fail "ReopenMark already open before Reopen (default project should be clean)"
file_menu; xdotool key l; sleep 2.5   # Reopen &Last Project (accelerator)
QP=$(xdotool search --onlyvisible --name '^HbBuilder$' 2>/dev/null | head -1)
[ -n "$QP" ] && { echo "  save prompt before reopen: answering No"; click_dialog_button 0; }  # Yes|No|Cancel: No centered
for i in $(seq 1 15); do xdotool search --onlyvisible --name '^ReopenMark$' >/dev/null 2>&1 && break; sleep 1; done
xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 && fail "Reopen unexpectedly opened an Open dialog"
xdotool search --onlyvisible --name '^ReopenMark$' >/dev/null 2>&1 || fail "ROUNDTRIP: Reopen Last Project did not restore the fixture after restart"
echo "WINE REOPENLAST PASS (RUN=$RUN)"
