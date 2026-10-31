#!/usr/bin/env bash
# Wine GUI probe: Inspector stale cell after in-place edit commit.
# Symptom (recorded 00:04, screenshots inspected by main): after committing an
# edited property value (Enter), the Inspector VALUE CELL still shows the old
# text while the widget/code take the new one; reselecting the control refreshes.
# Source cause candidate: properties ListView stores cell text (no LVS_OWNERDATA);
# InsEndEdit(TRUE) updates only d->rows[].szValue in memory, no LVM_SETITEMTEXT
# on the commit path (inspector_win.prg:2759-2810).
# Assertion by PIXELS (no OCR): crop the cText value cell before the edit; after
# committing a DIFFERENT value, the crop must CHANGE. Stale = crops identical.
# STALE_OK=1 env inverts the expectation (RED mode: PASS means stale reproduced).
set -u
ROOT="$HOME/HarbourBuilder"
WINE="$HOME/wine-toolchain/wine-11.20-amd64-wow64/bin/wine"
RUN="$(mktemp -d /tmp/designer_stale.XXXXXX)"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-$HOME/wine-toolchain/prefix}"
cp -a "$TEMPLATE_PREFIX" "$RUN/prefix"
export WINEPREFIX="$RUN/prefix" WINEDEBUG=err DISPLAY="${DISPLAY:-:99}"
exec > >(tee "$RUN/probe.log") 2>&1
echo "== wine inspector-stale probe (${STALE_OK:+RED-mode}${STALE_OK:-GREEN-mode}): $(date -Is) =="
echo "HEAD $(git -C "$ROOT" rev-parse HEAD)"
echo "exe sha256: $(sha256sum "$ROOT/bin/hbbuilder_win.exe" | awk '{print $1}')"
echo "RUN=$RUN"
TRACE="$ROOT/inspector_trace.log"
rm -f "$TRACE"
fail() { echo "WINE STALE FAIL: $* (RUN=$RUN)"; exit 1; }
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
cell_crop() { import -window root "$RUN/root.png"
  python3 -c "
from PIL import Image
im=Image.open('$RUN/root.png'); im.crop((120,280,336,306)).save('$1')" ; }

launch; dismiss_curl
xdotool mousemove 472 79 click 1; sleep 1
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$F1" ] || fail "Form1 design window not found"
win_geo "$F1"
xdotool mousemove $((X + 200)) $((Y + 110)) click 1; sleep 2   # drop TLabel (cText=Label1)
xdotool mousemove 189 293 click 1; sleep 1.5   # select the cText row (highlight) WITHOUT editing
cell_crop "$RUN/cell_before.png"
# commit a DIFFERENT value via the cText cell (189,293 = value column, cText row)
xdotool mousemove 189 293 click 1; sleep 0.4; xdotool click 1; sleep 1
xdotool key Home; sleep 0.3; xdotool key shift+End; sleep 0.3
xdotool type --delay 40 'StaleX'; sleep 0.4; xdotool key Return; sleep 1
# bind model before trusting any pixel: the commit MUST appear in the trace
CMT=""
for i in $(seq 1 12); do
  CMT=$(grep -c "InsApplyValue:.*val='StaleX'" "$TRACE" 2>/dev/null)
  [ -n "$CMT" ] && [ "$CMT" -ge 1 ] && break
  sleep 1
done
[ -n "$CMT" ] && [ "$CMT" -ge 1 ] || fail "HARNESS: edit 'StaleX' never committed in model (trace silent) - no product verdict"
echo "  model commit confirmed in trace (val='StaleX')"
sleep 1.5
cell_crop "$RUN/cell_after.png"
SAME=$(RUN="$RUN" python3 - <<'PYE'
import os
from PIL import Image, ImageChops
r=os.environ['RUN']
a=Image.open(r+'/cell_before.png').convert('L')
b=Image.open(r+'/cell_after.png').convert('L')
d=ImageChops.difference(a,b)
mx=max(d.getdata())
print(1 if mx < 10 else 0)
PYE
)
echo "  cell pixels identical after commit: $SAME (1=stale, 0=refreshed)"
LEG1SAME=$SAME
# backend must have taken the value regardless (widget/code updated)
file_menu() { xdotool mousemove 12 33 click 1; sleep 1; }
file_menu; xdotool mousemove 95 211 click 1; sleep 2.5
xdotool search --onlyvisible --name 'Save HbBuilder Project' >/dev/null 2>&1 || fail "Save As dialog did not open"
xdotool mousemove 200 239 click 1; sleep 0.6
xdotool key End; sleep 0.4; xdotool key shift+Home; sleep 0.4
xdotool type --delay 35 "Z:${RUN//\//\\}\\Stale.hbp"; sleep 0.6; xdotool key Return; sleep 3
grep -q 'PROMPT "StaleX"' "$RUN/Form1.prg" || fail 'backend did not take StaleX (edit itself failed - invalid repro)'
echo "  backend took StaleX (Form1.prg) - leg1 warm-up"
# leg2 (the 00:04 scenario): restart, reopen, edit AGAIN, then compare cell
"$WINESERVER" -k 2>/dev/null; sleep 3
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
xdotool search --onlyvisible --name 'Open HbBuilder Project' >/dev/null 2>&1 || fail "Open dialog did not open (leg2)"
xdotool mousemove 200 239 click 1; sleep 0.6
xdotool key End; sleep 0.4; xdotool key shift+Home; sleep 0.4
xdotool type --delay 35 "Z:${RUN//\//\\}\\Stale.hbp"; sleep 0.6; xdotool key Return; sleep 3
F1=$(xdotool search --onlyvisible --name '^Form1$' 2>/dev/null | head -1)
[ -n "$F1" ] || fail "Form1 did not reappear after Open"
win_geo "$F1"
xdotool mousemove $((X + 200)) $((Y + 110)) click 1; sleep 2   # select the reloaded label
xdotool mousemove 189 293 click 1; sleep 1.5                  # select cText row (highlight settle)
cell_crop "$RUN/cell_before2.png"
xdotool mousemove 189 293 click 1; sleep 0.4; xdotool click 1; sleep 1
xdotool key Home; sleep 0.3; xdotool key shift+End; sleep 0.3
xdotool type --delay 40 'StaleY'; sleep 0.4; xdotool key Return; sleep 2.5
cell_crop "$RUN/cell_after2.png"
SAME=$(RUN="$RUN" python3 - <<'PYE'
import os
from PIL import Image, ImageChops
r=os.environ['RUN']
a=Image.open(r+'/cell_before2.png').convert('L')
b=Image.open(r+'/cell_after2.png').convert('L')
d=ImageChops.difference(a,b)
mx=max(d.getdata())
print(1 if mx < 10 else 0)
PYE
)
echo "  leg2 (post-reopen, OBSERVATIONAL - scenario unverified) cell pixels identical: $SAME"
SAME=$LEG1SAME
if [ "${STALE_OK:-0}" = "1" ]; then
  [ "$SAME" = "1" ] || fail "RED-mode: cell DID refresh - stale symptom not reproduced"
  echo "WINE STALE RED: stale cell reproduced with backend updated (RUN=$RUN)"
else
  [ "$SAME" = "0" ] || fail "stale cell: value cell pixels unchanged after committing a different value"
  echo "WINE STALE GREEN (repaint signal only): model commit trace-confirmed and cell pixels changed."
echo "  NOT a text-content oracle: focus/highlight can change pixels. Visually confirm the"
echo "  crops show the typed value: $RUN/cell_before.png vs $RUN/cell_after.png"
fi
