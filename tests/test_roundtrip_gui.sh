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
source "$REPO/tests/harness_lib.sh"
fail() { echo "FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$CYC"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
cp "$FIX/Form1.prg" "$CYC/original.prg"
rt_setup "$RUN"
rt_launch_ide

ide_windows() { rt_ide_windows; }
unmap_all_but() { rt_unmap_all_but "$@"; }
find_designer() { rt_find_designer; }
find_bar() { rt_find_bar; }
map_all() { rt_map_all; }

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
  touch -d '2000-01-01 00:00:00' "$RUN/Form1.prg"
  xdotool key ctrl+s; sleep 2
  M1=$(stat -c %Y "$RUN/Form1.prg")
  if [ "$M1" -lt 1000000000 ]; then
    # accelerator did not fire: fall back to File -> Save menu item
    xdotool mousemove 20 12 click 1; sleep 0.8
    xdotool mousemove 100 200 click 1; sleep 2
    M1=$(stat -c %Y "$RUN/Form1.prg")
  fi
  [ "$M1" -ge 1000000000 ] || fail "cycle $C: no real save (Form1.prg mtime unchanged)"
  echo "cycle $C: Form1.prg written (mtime $(date -d @$M1 -Is))"
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
chk 'LABELEDEDIT ::oLedit1 VAR "editable" OF Self SIZE 160, 24'
chk 'GET ::oEdit1 VAR "texto inicial"'
chk 'CHECKBOX ::oChk1 PROMPT "Marcado".* CHECKED'
chk 'COMBOBOX ::oCombo1 .* ITEMS "Uno", "Di " \+ Chr\(34\) \+ "si" \+ Chr\(34\), "Tre, s"'
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
chk 'BITBTN ::oBitBtn1 PROMPT "ConIcono".* PICTURE "icon.png"'
chk '::oList1:Value := 2'
chk '::oCombo1:Value := 0'
chk 'FixtureTrace\( "after-edit1", ::oEdit1 \)'
chk '::oLabel1:cText := FixtureCaption\( ::oCombo1 \)'
chk 'function FixtureTrace'
chk 'function FixtureCaption'
# T4: folder/browse structure must survive both cycles
chk 'DATA oFld1 +// TFolder'
chk 'DATA oBrw1 +// TBrowse'
chk 'DATA oBtnPg2 +// TButton'
chk 'FOLDER ::oFld1 OF Self SIZE 165, 160 PROMPTS "P1", "P2"'
chk 'BUTTON ::oBtnPg2 PROMPT "Pag2" OF ::oFld1:aPages\[2\] SIZE 90, 26'
chk 'BROWSE ::oBrw1 OF Self SIZE 165, 150 HEADERS "Nombre", "Edad" COLSIZES 90, 60 FOOTERS "Total", ""'
rej '// ::o(Radio1|BitBtn1|Image1|Memo1)'
rej 'Value := 1'

# no duplicated side-effect lines
N=$(grep -c 'FixtureTrace( "after-edit1"' "$CYC/cycle2.prg")
[ "$N" = 1 ] || { echo "  DUPLICATED/LOST side-effect line (count=$N)"; FAILN=$((FAILN+1)); }

# order preservation: custom lines stay between their original neighbours
ord() { grep -n "$1" "$CYC/cycle2.prg" | head -1 | cut -d: -f1; }
L_GET=$(ord 'GET ::oEdit1');  L_TR=$(ord 'FixtureTrace( "after'); L_CHK=$(ord 'CHECKBOX ::oChk1')
L_CB=$(ord 'COMBOBOX ::oCombo1'); L_CAP=$(ord 'FixtureCaption'); L_GB=$(ord 'GROUPBOX ::oGroup1')
[ "$L_GET" -lt "$L_TR" ] && [ "$L_TR" -lt "$L_CHK" ] || { echo "  ORDER BROKEN around FixtureTrace ($L_GET/$L_TR/$L_CHK)"; FAILN=$((FAILN+1)); }
[ "$L_CB" -lt "$L_CAP" ] && [ "$L_CAP" -lt "$L_GB" ] || { echo "  ORDER BROKEN around FixtureCaption ($L_CB/$L_CAP/$L_GB)"; FAILN=$((FAILN+1)); }

if ! diff -q "$CYC/cycle1.prg" "$CYC/cycle2.prg" >/dev/null; then
  echo "  NOT A FIXPOINT: cycle1 != cycle2"; FAILN=$((FAILN+1))
fi

# T2: original -> cycle2 must now be IDENTICAL in geometry. M6 is closed:
# - LISTBOX 90->100: the '@' parser dropped the SIZE height on load
#   (UI_ListBoxNew 5th arg defaulted to 100); fixed in 771683a.
# - form 480->520/530: GTK enforces the toplevel min-content size and the
#   configure write-back copied the forced size into the model; the
#   write-back now keeps the design size when the event sits exactly at
#   the enforced minimum (gtk3_core.c on_window_configure).
# A nHeight or LISTBOX line in this diff is a real regression and fails.
GEOM_BAD=$(diff <(tr -d '\r' < "$CYC/original.prg") <(tr -d '\r' < "$CYC/cycle2.prg") | grep -E '^[<>]' | \
  # SAY lines are regenerated with their explicit height (the width-only
  # emission that dropped a hand-written SAY height was fixed in this
  # batch). The fixture line is width-only; the parser defaults the height
  # to 15, but GTK realizes the label at its natural height 21, and the
  # generator emits the live height. Verified stable: cycle1 == cycle2
  # (one-shot 15->21 at first realize, no progressive drift). A regression
  # that drops the height again produces a width-only '>' line and fails.
  grep -vE '^< +@ 20, 160 SAY ::oLabel1 PROMPT "Etiqueta fija" OF Self SIZE 200$' | \
  grep -vE '^> +@ 20, 160 SAY ::oLabel1 PROMPT "Etiqueta fija" OF Self SIZE 200, 21$' | \
  grep -vE '^[<>] +@ 140, 20 COMBOBOX ::oCombo1 OF Self SIZE 180, 26 ITEMS "Uno", "Di " \+ Chr\( ?34 ?\) \+ "si" \+ Chr\( ?34 ?\), "Tre, s"$' | \

  grep -vE '^[<>] +DATA o(Label1|Edit1|Chk1|Combo1|Group1|Radio1|Image1|Memo1|List1|Ledit1) +// [A-Za-z0-9_]+$' | \
  grep -vE '^[<>] // Form1\.prg$' | \
  grep -vE '^[<>] // Form1\.prg - FIXTURE roundtrip v3: order preservation \+ side-effect calls$' | \
  grep -v $'\x1A' || true)
# T6: the "// Event wiring" marker must survive both cycles (auditor T6:
# it disappeared when the form had only manual wiring, i.e. cEvents empty)
for C in 1 2; do
  grep -q '// Event wiring' "$CYC/cycle$C.prg" || { echo "  T6: '// Event wiring' marker lost in cycle$C"; FAILN=$((FAILN+1)); }
done

if [ -n "$GEOM_BAD" ]; then
  echo "  UNEXPECTED DRIFT original -> cycle2:"
  echo "$GEOM_BAD" | head -20
  FAILN=$((FAILN+1))
fi

if [ "$FAILN" -gt 0 ]; then
  echo "ROUNDTRIP FAIL ($FAILN problems). Evidence in $CYC"
  rt_cleanup
  exit 1
fi
import -window root /tmp/rt_roundtrip.png
echo "screenshot: /tmp/rt_roundtrip.png"
echo "ROUNDTRIP PASS: 2 cycles, real save verified in both, no content lost, fixpoint reached."
echo "diff original -> cycle2, CRLF-normalized (known non-geometry items only; M7 tracked):"
diff <(tr -d '\r' < "$CYC/original.prg") <(tr -d '\r' < "$CYC/cycle2.prg") | head -60
rt_cleanup
exit 0
