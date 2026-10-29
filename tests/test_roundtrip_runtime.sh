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
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_run
GTKROOT=/tmp/gtk-root
export DISPLAY=:99
fail() { echo "RUNTIME FAIL: $1"; exit 1; }

pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1600x1000x24 & sleep 2; }
rm -f /tmp/fixture_trace.log /tmp/rt_runtime.png
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
printf 'File1=%s\nFile2=\nFile3=\nFile4=\nFile5=\nFile6=\nFile7=\nFile8=\n' \
  "$RUN/Project1.hbp" > "$REPO/bin/hbbuilder.ini"

pkill -f 'hbbuilder_linux' 2>/dev/null; sleep 1
cd "$REPO/bin"
nohup setsid env DISPLAY=:99 \
  LD_LIBRARY_PATH=.:$GTKROOT/usr/lib/x86_64-linux-gnu \
  PKG_CONFIG_PATH=$GTKROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$GTKROOT/usr/share/pkgconfig \
  PKG_CONFIG_SYSROOT_DIR=$GTKROOT LIBRARY_PATH=$GTKROOT/usr/lib/x86_64-linux-gnu \
  GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 \
  ./hbbuilder_linux >/tmp/ide-runtime.log 2>&1 </dev/null &
disown
sleep 7
IDEPID=$(pgrep -f '\./hbbuilder_linux' | head -1)
[ -n "$IDEPID" ] || fail "IDE did not start"

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

# evidence screenshot of the app window region
eval "$(xdotool getwindowgeometry --shell "$APPW")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/rt_runtime.png

FAILN=0
# 1. side-effect call executed, with the live edit control
if [ -f /tmp/fixture_trace.log ]; then
  grep -q 'after-edit1:texto inicial' /tmp/fixture_trace.log \
    || { echo "  trace wrong: $(cat /tmp/fixture_trace.log)"; FAILN=$((FAILN+1)); }
else
  echo "  trace log missing"; FAILN=$((FAILN+1))
fi
# 2. dependent caption line + 3. custom edit line executed
OCR=$(tesseract /tmp/rt_runtime.png - tsv 2>/dev/null | awk -F'\t' '$12!="" {print $12}' | tr '\n' ' ')
echo "  OCR: $OCR"
echo "$OCR" | grep -q 'caption-ok' || { echo "  caption effect missing"; FAILN=$((FAILN+1)); }
echo "$OCR" | grep -q 'modificado' || { echo "  edit effect missing"; FAILN=$((FAILN+1)); }

kill "$APPPID" 2>/dev/null
[ "$FAILN" -gt 0 ] && fail "$FAILN runtime effect(s) missing (screenshot /tmp/rt_runtime.png)"
echo "RUNTIME PASS: side-effect call, dependent caption and custom edit all executed."
