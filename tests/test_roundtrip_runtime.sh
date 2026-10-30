#!/bin/bash
# Runtime effect verification: opens the roundtrip fixture in the IDE,
# builds & runs it (Ctrl+R) and verifies the EXECUTED effects of the
# custom lines - not just their textual order:
#   /tmp/fixture_trace.log  written by FixtureTrace() during CreateForm
#   label caption           set by ::oLabel1:cText := FixtureCaption(::oCombo1)
#   edit content            set by ::oEdit1:cText := "modificado"
# Run from the repo root. Evidence screenshot lands in /tmp/rt_runtime.png.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="${RUNTIME_FIXTURE:-$REPO/tests/fixtures/roundtrip}"
EXPECT_TABS="${EXPECT_TABS:-P1|P2}"
EXPECT_TAB2="${EXPECT_TAB2:-P2}"
EXPECT_HEADER2="${EXPECT_HEADER2:-Edad}"
RUN=/tmp/rt_run
source "$REPO/tests/harness_lib.sh"
fail() { echo "RUNTIME FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
PICTURE_FILES="${PICTURE_FILES:-yes}"
rm -f /tmp/fixture_trace.log /tmp/rt_runtime.png
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
rt_setup "$RUN"
# the user app inherits the IDE cwd ($REPO/bin): relative PICTURE paths
# resolve there. PICTURE_FILES=no runs the negative control (files absent).
rm -f "$REPO/bin/icon.png" "$REPO/bin/test.png"
[ "$PICTURE_FILES" = "yes" ] && cp "$FIX/icon.png" "$FIX/test.png" "$REPO/bin/"
rt_launch_ide
IDEPID=$RT_IDEPID

find_bar() {
  local w t geo h wd
  for w in $(xdotool search --pid "$IDEPID" 2>/dev/null); do
    t=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$t" in HbBuilder*)
      geo=$(xdotool getwindowgeometry --shell "$w" 2>/dev/null) || continue
      h=$(echo "$geo" | sed -n 's/^HEIGHT=//p'); wd=$(echo "$geo" | sed -n 's/^WIDTH=//p')
      [ -n "$h" ] && [ "$h" -le 130 ] && [ "$wd" -ge 800 ] && { echo "$w"; return 0; }
      ;;
    esac
  done
}
unmap_all_but() { local keep=$1 w; for w in $(xdotool search --pid "$IDEPID" 2>/dev/null); do
  [ "$w" = "$keep" ] || xdotool windowunmap "$w" 2>/dev/null; done; }

# open the fixture project (File -> Reopen Last Project)
BAR=$(find_bar); [ -n "$BAR" ] || fail "IDE bar not found"
unmap_all_but "$BAR"; sleep 0.4
xdotool mousemove 20 12 click 1; sleep 0.8
xdotool mousemove 100 134 click 1; sleep 6
for w in $(xdotool search --pid "$IDEPID" 2>/dev/null); do xdotool windowmap "$w" 2>/dev/null; done
sleep 1

# build & run (Run menu accel)
BAR=$(find_bar); unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+r

# wait for the app window: titled like the form but owned by a child process
APPW=""; APPPID=""
for i in $(seq 1 45); do
  for w in $(xdotool search --name 'Fixture Roundtrip' 2>/dev/null); do
    p=$(xprop -id "$w" _NET_WM_PID 2>/dev/null | awk '{print $3}')
    [ -n "$p" ] && [ "$p" != "$IDEPID" ] && { APPW=$w; APPPID=$p; break; }
  done
  [ -n "$APPW" ] && break
  sleep 2
done
[ -n "$APPW" ] || fail "app window did not appear (build/run problem; /tmp/ide-runtime.log)"
sleep 3
echo "app window $APPW pid $APPPID"

# The saved form may legitimately start outside the display after designer
# parking. Move only the runtime app for visible checks, not its model.
xdotool windowmove "$APPW" 400 200; xdotool windowraise "$APPW"; sleep 0.5

# evidence screenshot of the app window region
eval "$(xdotool getwindowgeometry --shell "$APPW")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/rt_runtime.png

FAILN=0
# 1. side-effect call executed, with the live edit control
if [ -f /tmp/fixture_trace.log ]; then
  grep -q 'after-edit1:texto inicial' /tmp/fixture_trace.log \
    || { echo "  trace wrong: $(cat /tmp/fixture_trace.log)"; FAILN=$((FAILN+1)); }
  # T4: folder tabs, browse columns and page-2 child wiring, read from the
  # live runtime controls (not from the Harbour-side DATA mirrors)
  for want in "folder-tabs:$EXPECT_TABS" 'browse-cols:2' 'page2-btn:Pag2' 'page2-owner:folder' 'page2-page:1'; do
    grep -qF "$want" /tmp/fixture_trace.log \
      || { echo "  T4 trace missing: $want (got: $(cat /tmp/fixture_trace.log | tr '\n' ' '))"; FAILN=$((FAILN+1)); }
  done
else
  echo "  trace log missing"; FAILN=$((FAILN+1))
fi
# 2. dependent caption line + 3. custom edit line executed
OCR=$(tesseract /tmp/rt_runtime.png - tsv 2>/dev/null | awk -F'\t' '$12!="" {print $12}' | tr '\n' ' ')
echo "  OCR: $OCR"
echo "$OCR" | grep -q 'caption-ok' || { echo "  caption effect missing"; FAILN=$((FAILN+1)); }
echo "$OCR" | grep -q 'modificado' || { echo "  edit effect missing"; FAILN=$((FAILN+1)); }

# 4. PICTURE really loads (auditor: only textual preservation was covered,
# with nonexistent images). icon.png = solid cyan 16x16 (BITBTN), test.png =
# solid magenta 32x32 (IMAGE). Fraction of exact-color pixels in the window
# capture proves the pixbuf rendered, not just the property survived.
if [ "$PICTURE_FILES" = "yes" ]; then COPIED="with" ; else COPIED="without"; fi
echo "  picture check ($COPIED image files in the app cwd):"
HIST=$(convert /tmp/rt_runtime.png -format "%c" histogram:info:- 2>/dev/null)
MAG=$(echo "$HIST" | awk -F: '/255,0,255/{gsub(/ /,"",$1); s+=$1} END{print s+0}')
CYA=$(echo "$HIST" | awk -F: '/0,255,255/{gsub(/ /,"",$1); s+=$1} END{print s+0}')
echo "  exact-color pixels: magenta(test.png IMAGE, 32x32=1024 nominal)=$MAG cyan(icon.png BITBTN, 16x16=256 nominal)=$CYA"
if [ "$PICTURE_FILES" = "yes" ]; then
  [ "$MAG" -ge 400 ] || { echo "  IMAGE test.png not rendered (magenta px < 400)"; FAILN=$((FAILN+1)); }
  [ "$CYA" -ge 80 ]  || { echo "  BITBTN icon.png not rendered (cyan px < 80)"; FAILN=$((FAILN+1)); }
else
  [ "$MAG" -lt 50 ] || { echo "  CONTROL FAIL: magenta present without the image file (check cannot detect absence)"; FAILN=$((FAILN+1)); }
fi

# 5. T4 widget reality: browse headers/footer really rendered, and the
# page-2 button is visible ONLY after switching the folder to page 2.
HDR=$(tesseract /tmp/rt_runtime.png - 2>/dev/null)
for w in Nombre "$EXPECT_HEADER2" Total; do
  echo "$HDR" | grep -q "$w" || { echo "  browse widget text '$w' not rendered"; FAILN=$((FAILN+1)); }
done
echo "$HDR" | grep -q 'Pag2' && { echo "  Pag2 visible on page 1: page membership broken"; FAILN=$((FAILN+1)); }
APPX=$X; APPY=$Y
# click the P2 tab where it actually is: locate its word box by OCR
rel=$(tesseract /tmp/rt_runtime.png - tsv 2>/dev/null | awk -F'\t' -v tab="$EXPECT_TAB2" '$8+0 > 20 && $12 == tab {print $7" "$8" "$9" "$10; exit}')
if [ -n "$rel" ]; then
  set -- $rel
  echo "  P2 tab at +$1,+$2 ${3}x${4}; clicking its center"
  xdotool mousemove $((APPX+$1+$3/2)) $((APPY+$2+$4/2)) click 1; sleep 1
else
  echo "  P2 tab not found by OCR; page switch not attempted"; FAILN=$((FAILN+1))
fi
import -window root -crop "${WIDTH}x${HEIGHT}+${APPX}+${APPY}" /tmp/rt_runtime_p2.png
P2=$(tesseract /tmp/rt_runtime_p2.png - 2>/dev/null)
echo "$P2" | grep -q 'Pag2' || { echo "  Pag2 NOT visible after switching to page 2"; FAILN=$((FAILN+1)); }
rel=$(tesseract /tmp/rt_runtime_p2.png - tsv 2>/dev/null | awk -F'\t' '$8+0 > 20 && $12 ~ /^(P1|Pl)$/ {print $7" "$8" "$9" "$10; exit}')
if [ -n "$rel" ]; then
  set -- $rel
  xdotool mousemove $((APPX+$1+$3/2)) $((APPY+$2+$4/2)) click 1; sleep 1
else
  echo "  P1 tab not found by OCR for the switch back"; FAILN=$((FAILN+1))
fi
import -window root -crop "${WIDTH}x${HEIGHT}+${APPX}+${APPY}" /tmp/rt_runtime_p1b.png
P1B=$(tesseract /tmp/rt_runtime_p1b.png - 2>/dev/null)
echo "$P1B" | grep -q 'Pag2' && { echo "  Pag2 still visible after switching back to page 1"; FAILN=$((FAILN+1)); }

kill "$APPPID" 2>/dev/null
rm -f "$REPO/bin/icon.png" "$REPO/bin/test.png"
[ "$FAILN" -gt 0 ] && fail "$FAILN runtime effect(s) missing (screenshot /tmp/rt_runtime.png)"
echo "RUNTIME PASS: side-effect call, dependent caption and custom edit all executed."
rt_cleanup
