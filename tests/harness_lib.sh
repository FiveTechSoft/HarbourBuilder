# Common harness for the GUI regression scripts (Linux sandbox, Xvfb).
# Isolation rules: never kills IDE instances it did not start, saves and
# restores bin/hbbuilder.ini, prints provenance (commit + binary hash).
GTKROOT=${GTKROOT:-/tmp/gtk-root}
RT_DISPLAY=${RT_DISPLAY:-:99}
export DISPLAY=$RT_DISPLAY

rt_provenance() {
  echo "== provenance =="
  echo "commit: $(git -C "$REPO" rev-parse HEAD)"
  echo "binary: $(sha256sum "$REPO/bin/hbbuilder_linux" | cut -d' ' -f1)  bin/hbbuilder_linux"
  echo "date:   $(date -Is)"
}

# Capture the absolute repo root ONCE at source time: after rt_launch_ide's
# cd into bin/, a relative test invocation path would resolve wrong here.
RT_REPO_ABS=$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)

rt_setup() {  # $1 = project dir to point the IDE at
  REPO=$RT_REPO_ABS
  RT_PROJDIR=$1
  # start Xvfb only when the display does not actually accept connections:
  # pgrep -x matches ZOMBIE Xvfb entries (their comm survives), which once
  # made this check skip starting a live server on a dead display
  if ! DISPLAY=$RT_DISPLAY xdotool getdisplaygeometry >/dev/null 2>&1; then
    Xvfb $RT_DISPLAY -screen 0 1600x1000x24 & sleep 2
  fi
  [ -f "$REPO/bin/hbbuilder.ini" ] && cp "$REPO/bin/hbbuilder.ini" /tmp/rt_ini_backup
  printf 'File1=%s\nFile2=\nFile3=\nFile4=\nFile5=\nFile6=\nFile7=\nFile8=\n' \
    "$RT_PROJDIR/Project1.hbp" > "$REPO/bin/hbbuilder.ini"
  RT_IDEPID=""
}

rt_launch_ide() {
  local before after p
  before=$(pgrep -f '\./hbbuilder_linux' | tr '\n' ' ')
  cd "$REPO/bin"
  nohup setsid env DISPLAY=$RT_DISPLAY \
    LD_LIBRARY_PATH=.:$GTKROOT/usr/lib/x86_64-linux-gnu \
    PKG_CONFIG_PATH=$GTKROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$GTKROOT/usr/share/pkgconfig \
    PKG_CONFIG_SYSROOT_DIR=$GTKROOT LIBRARY_PATH=$GTKROOT/usr/lib/x86_64-linux-gnu \
    GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 \
    ./hbbuilder_linux >/tmp/rt_ide.log 2>&1 </dev/null &
  disown
  for i in $(seq 1 15); do
    sleep 1
    after=$(pgrep -f '\./hbbuilder_linux' | tr '\n' ' ')
    for p in $after; do
      case " $before " in *" $p "*) ;; *) RT_IDEPID=$p;; esac
    done
    [ -n "$RT_IDEPID" ] && break
  done
  [ -n "$RT_IDEPID" ] || { echo "HARNESS FAIL: IDE did not start (/tmp/rt_ide.log)"; exit 1; }
  echo "IDE pid: $RT_IDEPID (started by this script)"
}

rt_cleanup() {  # kill only the IDE this script started, reap it, restore the INI
  if [ -n "${RT_IDEPID:-}" ]; then
    kill "$RT_IDEPID" 2>/dev/null
    wait "$RT_IDEPID" 2>/dev/null
  fi
  [ -f /tmp/rt_ini_backup ] && cp /tmp/rt_ini_backup "$REPO/bin/hbbuilder.ini"
}

rt_ide_windows() { xdotool search --pid "$RT_IDEPID" 2>/dev/null; }

rt_find_designer() {
  local w t
  for w in $(rt_ide_windows); do
    t=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$t" in Form1*|*"Fixture Roundtrip"*|*"Fixture HandEdit"*|*"Fixture PreClass"*|*"Fixture RunHash"*) echo "$w"; return 0;; esac
  done
  return 1
}

rt_find_bar() {
  local w t geo h wd
  for w in $(rt_ide_windows); do
    t=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$t" in HbBuilder*)
      geo=$(xdotool getwindowgeometry --shell "$w" 2>/dev/null) || continue
      h=$(echo "$geo" | sed -n 's/^HEIGHT=//p'); wd=$(echo "$geo" | sed -n 's/^WIDTH=//p')
      [ -n "$h" ] && [ "$h" -le 130 ] && [ "$wd" -ge 800 ] && { echo "$w"; return 0; }
      ;;
    esac
  done
  return 1
}

rt_expose_bar() {  # move non-bar HbBuilder windows off the menu bar area
  local w t bar
  bar=$(rt_find_bar) || return 1
  for w in $(rt_ide_windows); do
    t=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$t" in HbBuilder*) [ "$w" = "$bar" ] || xdotool windowmove "$w" 0 500 2>/dev/null;; esac
  done
  sleep 0.5
  echo "$bar"
}

# These menus are press-drag-release: the dropdown stays open only while
# the button is held, and mouseup activates the item under the cursor.
# $1 = OCR regex for the item; opens File at (30,12) and releases on the item.
menu_path_click() {
  local ITEMRE="$1" rel
  rt_expose_bar >/dev/null
  xdotool mousemove 30 12 mousedown 1; sleep 0.7
  import -window root -crop "400x400+0+0" /tmp/rt_menu.png 2>/dev/null
  rel=$(tesseract /tmp/rt_menu.png - tsv 2>/dev/null | awk -F'\t' -v w="$ITEMRE" '$8+0 > 20 && $12 ~ w {print $7" "$8" "$9" "$10; exit}')
  if [ -z "$rel" ]; then
    xdotool mouseup 1; sleep 0.3
    echo "  [diag] menu item $ITEMRE not found:"; tesseract /tmp/rt_menu.png - 2>/dev/null | grep -v '^$' | head -8
    return 1
  fi
  set -- $rel
  xdotool mousemove $(($1 + $3/2)) $(($2 + $4/2)); sleep 0.4
  xdotool mouseup 1; sleep 1
}

rt_unmap_all_but() {
  local keep=$1 w
  for w in $(rt_ide_windows); do
    [ "$w" = "$keep" ] || xdotool windowunmap "$w" 2>/dev/null
  done
}

rt_park_all_but() {  # move every IDE window except the listed ids off-screen
  local w keep=" $* "
  for w in $(rt_ide_windows); do
    case "$keep" in *" $w "*) ;; *) xdotool windowmove "$w" 3000 3000 2>/dev/null;; esac
  done
}

rt_map_all() { local w; for w in $(rt_ide_windows); do xdotool windowmap "$w" 2>/dev/null; done; }

rt_reopen_project() {  # File -> Reopen Last Project, then wait for the designer
  local bar i
  bar=$(rt_find_bar) || { echo "HARNESS FAIL: IDE bar not found"; exit 1; }
  menu_path_click '^Reopen' || { echo "HARNESS FAIL: Reopen menu item not found"; exit 1; }
  sleep 4
  for i in $(seq 1 12); do
    RT_DESIGNER=$(rt_find_designer) && break
    sleep 1
  done
  [ -n "${RT_DESIGNER:-}" ] || { echo "HARNESS FAIL: designer window not found"; exit 1; }
}

rt_ocr_bar_token() {  # $1 = regex of the token, $2 = min OCR confidence (default 40)
  local png=/tmp/rt_bar_$$.png
  import -window root -crop "1600x118+0+0" "$png" 2>/dev/null
  tesseract "$png" - tsv 2>/dev/null | \
    awk -F'\t' -v re="$1" -v mc="${2:-40}" '$12 ~ re && $9+0 > 5 && $10+0 > 5 && $11+0 > mc {printf "%d %d\n", $7+$9/2, $8+$10/2; exit}'
  rm -f "$png"
}
