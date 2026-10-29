#!/bin/bash
# Roundtrip GUI regression: drives the real IDE over Xvfb through
# open -> designer sync -> save -> reopen -> save (2 cycles) and verifies
# that no form content is lost. Run from the repo root:
#   bash tests/test_roundtrip_gui.sh
# Requires: Xvfb on :99, xdotool, the GTK sandbox root, Harbour build env.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/rt_run
CYC="$RUN/cycles"
GTKROOT=/tmp/gtk-root
export DISPLAY=:99

fail() { echo "FAIL: $1"; exit 1; }

# 0. fresh working copy of the fixture
rm -rf "$RUN"; mkdir -p "$CYC"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
cp "$FIX/Form1.prg" "$CYC/original.prg"

# 1. INI points at the working copy (Reopen Last Project source)
printf 'File1=%s\nFile2=\nFile3=\nFile4=\nFile5=\nFile6=\nFile7=\nFile8=\n' \
  "$RUN/Project1.hbp" > "$REPO/bin/hbbuilder.ini"

# 2. relaunch the IDE with the current binary
pkill -f 'hbbuilder_linux' 2>/dev/null; sleep 1
cd "$REPO/bin"
nohup setsid env DISPLAY=:99 \
  LD_LIBRARY_PATH=.:$GTKROOT/usr/lib/x86_64-linux-gnu \
  PKG_CONFIG_PATH=$GTKROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$GTKROOT/usr/share/pkgconfig \
  PKG_CONFIG_SYSROOT_DIR=$GTKROOT \
  LIBRARY_PATH=$GTKROOT/usr/lib/x86_64-linux-gnu \
  GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 \
  WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 \
  ./hbbuilder_linux >/tmp/ide-rt.log 2>&1 </dev/null &
disown
sleep 7
IDEPID=$(pgrep -f '\./hbbuilder_linux' | head -1)
[ -n "$IDEPID" ] || fail "IDE did not start (see /tmp/ide-rt.log)"
echo "IDE pid: $IDEPID"

# helpers ----------------------------------------------------------------
ide_windows() { xdotool search --pid "$IDEPID" 2>/dev/null; }

unmap_all_but() {  # $1 = window id to keep mapped
  local keep=$1 w
  for w in $(ide_windows); do
    [ "$w" = "$keep" ] && continue
    xdotool windowunmap "$w" 2>/dev/null
  done
}

find_designer() {  # the design surface window is titled with the form name
  local w t
  for w in $(ide_windows); do
    t=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$t" in Form1*|*"Fixture Roundtrip"*) echo "$w"; return 0;; esac
  done
  return 1
}

find_bar() {  # IDE bar: full-width, short window titled HbBuilder
  local w t geo h wd
  for w in $(ide_windows); do
    t=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$t" in
      HbBuilder*)
        geo=$(xdotool getwindowgeometry --shell "$w" 2>/dev/null) || continue
        h=$(echo "$geo" | sed -n 's/^HEIGHT=//p')
        wd=$(echo "$geo" | sed -n 's/^WIDTH=//p')
        [ -n "$h" ] && [ "$h" -le 130 ] && [ "$wd" -ge 800 ] && { echo "$w"; return 0; }
        ;;
    esac
  done
  return 1
}

map_all() {
  local w
  for w in $(ide_windows); do xdotool windowmap "$w" 2>/dev/null; done
}

# cycles -------------------------------------------------------------------
for C in 1 2; do
  echo "--- cycle $C: reopen + sync + save"
  BAR=$(find_bar)
  [ -n "$BAR" ] || fail "cycle $C: IDE bar window not found"
  unmap_all_but "$BAR"
  sleep 0.4
  # File menu -> Reopen Last Project (coords proven in the walkthrough)
  xdotool mousemove 20 12 click 1;  sleep 0.8
  xdotool mousemove 100 134 click 1; sleep 5
  map_all; sleep 1
  DESIGN=""
  for i in 1 2 3 4 5 6 7 8 9 10; do
    DESIGN=$(find_designer) && break
    sleep 1
  done
  [ -n "$DESIGN" ] || fail "cycle $C: designer form window not found"
  # force a designer->code sync via a 1px resize (OnResize -> SyncDesignerToCode)
  eval "$(xdotool getwindowgeometry --shell "$DESIGN")"
  xdotool windowsize "$DESIGN" $((WIDTH+1)) "$HEIGHT"; sleep 1.5
  xdotool windowsize "$DESIGN" "$WIDTH" "$HEIGHT"; sleep 1.5
  # save: focus the bar and hit the Save accelerator
  BAR=$(find_bar); unmap_all_but "$BAR"; sleep 0.3
  xdotool mousemove 700 12 click 1; sleep 0.4
  M0=$(stat -c %Y "$RUN/Form1.prg")
  xdotool key ctrl+s; sleep 2
  M1=$(stat -c %Y "$RUN/Form1.prg")
  if [ "$M1" = "$M0" ] && [ "$C" = 1 ]; then
    # accelerator did not fire: fall back to File -> Save menu item
    xdotool mousemove 20 12 click 1; sleep 0.8
    xdotool mousemove 100 200 click 1; sleep 2
  fi
  cp "$RUN/Form1.prg" "$CYC/cycle$C.prg"
done

# verification -------------------------------------------------------------
echo "--- verification"
FAILN=0
chk() {  # $1 = regex that MUST match in cycle2
  if ! grep -Eq "$1" "$CYC/cycle2.prg"; then
    echo "  MISSING: $1"; FAILN=$((FAILN+1))
  fi
}
rej() {  # $1 = pattern that must NOT appear
  if grep -Eq "$1" "$CYC/cycle2.prg"; then
    echo "  FORBIDDEN PRESENT: $1"; FAILN=$((FAILN+1))
  fi
}

chk 'BUTTON ::oButton1 PROMPT "Aceptar"'
chk 'SAY ::oLabel1 PROMPT "Etiqueta fija"'
chk 'GET ::oEdit1 VAR "texto inicial"'
chk 'CHECKBOX ::oChk1 PROMPT "Marcado".* CHECKED'
chk 'COMBOBOX ::oCombo1 .* ITEMS "Uno", "Dos", "Tres"'
chk 'GROUPBOX ::oGroup1 PROMPT "Grupo"'
chk 'RADIOBUTTON ::oRadio1 PROMPT "Opcion A".* CHECKED'
chk 'BITBTN ::oBitBtn1 PROMPT "ConIcono"'
chk 'IMAGE ::oImage1 .* PICTURE "test.png"'
chk 'MEMO ::oMemo1 VAR "linea1"'
chk 'LISTBOX ::oList1 .* ITEMS "Alfa", "Beta"'
chk '::oButton1:oFont := "Sans,10"'
chk '::oEdit1:cText := "modificado"'
chk '// comentario manual del usuario'
chk '::oButton1:OnClick := \{ \|\| FixtureClick\( Self \) \}'
chk 'static function FixtureHelper'
chk 'function FixtureClick'
rej '// ::o(Radio1|BitBtn1|Image1|Memo1)'

if ! diff -q "$CYC/cycle1.prg" "$CYC/cycle2.prg" >/dev/null; then
  echo "  NOT A FIXPOINT: cycle1 != cycle2"; FAILN=$((FAILN+1))
fi

if [ "$FAILN" -gt 0 ]; then
  echo "ROUNDTRIP FAIL ($FAILN problems). Evidence in $CYC"
  exit 1
fi
echo "ROUNDTRIP PASS: 2 cycles, no content lost, fixpoint reached."
echo "diff original -> cycle2 (allowed geometry drift only):"
diff "$CYC/original.prg" "$CYC/cycle2.prg" | head -60
exit 0
