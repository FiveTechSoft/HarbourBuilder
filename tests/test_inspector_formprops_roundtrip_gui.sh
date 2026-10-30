#!/bin/bash
# Inspector form-property round-trip probe for the form-level props the
# serializer now persists: nWindowState, nBorderStyle, nFormStyle via the
# Inspector (phase1 non-default, phase2 default-return) and lSizable via a
# file round-trip (phase3: the GTK Inspector does not offer lSizable, so it
# is injected on disk and must survive an IDE load+save).
#   phase1: defaults in file -> set the 3 enum props non-default via the
#           Inspector -> save -> assert each line present exactly once and
#           no spurious ::lSizable -> reopen -> Inspector screenshot
#           (values loaded from disk) -> re-save fixpoint.
#   phase2: (project left by phase1) -> set the 3 enums back to defaults
#           -> save -> assert none of the three lines is emitted
#           (default-return) and title/geometry survive -> reopen ->
#           re-save fixpoint.
#   phase3: inject ::lSizable := .T. on disk -> IDE load+save -> assert
#           preserved exactly once -> re-save fixpoint.
# No argument runs phase1+phase2+phase3 in one IDE session.
# RED at introduction: the serializer emitted none of these lines, so
# phase1/phase3 fail listing every silently-lost prop.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUN=/tmp/inspector_formprops
source "$REPO/tests/harness_lib.sh"
fail() { echo "FORMPROPS ROUNDTRIP FAIL: $1"; rt_cleanup; exit 1; }
PHASE="${1:-all}"

view_menu_click() {
  local rel try vx vy
  rt_expose_bar >/dev/null
  for try in 1 2 3 4; do
    rel=$(rt_ocr_bar_token '^View' 40) || rel=""
    [ -z "$rel" ] && { echo "  [diag] View token not found (try $try)"; sleep 1; continue; }
    vx=${rel%% *}; vy=${rel##* }
    xdotool mousemove "$vx" "$vy" mousedown 1; sleep 0.7
    import -window root -crop "500x500+0+0" /tmp/rt_viewmenu.png 2>/dev/null
    if ! tesseract /tmp/rt_viewmenu.png - 2>/dev/null | grep -qi 'Inspector'; then
      xdotool mouseup 1; sleep 0.6
      echo "  [diag] View dropdown did not open (try $try)"
      continue
    fi
    rel=$(tesseract /tmp/rt_viewmenu.png - tsv 2>/dev/null | awk -F'\t' '$8+0 > 20 && $12 ~ /Inspector/ {print $7" "$8" "$9" "$10; exit}')
    if [ -z "$rel" ]; then
      xdotool mouseup 1; sleep 0.6
      echo "  [diag] Inspector item not found (try $try)"
      continue
    fi
    set -- $rel
    xdotool mousemove $(($1 + $3/2)) $(($2 + $4/2)); sleep 0.4
    xdotool mouseup 1; sleep 1.5
    return 0
  done
  return 1
}

open_inspector() {
  view_menu_click || fail "View -> Inspector menu path failed"
  INS=""
  for try in $(seq 1 10); do
    INS=$(xdotool search --name '^Inspector' 2>/dev/null | head -1)
    [ -n "$INS" ] && break
    sleep 1
  done
  [ -n "$INS" ] || fail "Inspector window did not appear"
  xdotool windowmove "$INS" 700 20; xdotool windowsize "$INS" 560 960
  xdotool windowmap "$INS"; xdotool windowraise "$INS"; xdotool windowfocus "$INS"; sleep 1
}

scroll_list() { # $1 = 4 (up) | 5 (down), $2 = clicks
  local i
  eval "$(xdotool getwindowgeometry --shell "$INS")"
  xdotool mousemove $((X + 280)) $((Y + 500)); sleep 0.3
  for i in $(seq 1 "$2"); do xdotool click "$1"; sleep 0.25; done
  sleep 0.5
}
scroll_to_top()    { scroll_list 4 14; }
scroll_to_bottom() { scroll_list 5 14; }

enum_select_kb() { # $1 anchor row regex, $2 arrows to target (D/U chars), $3 popup nav (D/U), $4 expected value (soft check)
  local ANCHOR="$1" ARROWS="$2" NAV="$3" EXPECT="$4"
  local rel try rowx rowy roww rowh i ch
  for try in 1 2 3; do
    import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
    rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' -v w="$ANCHOR" '$12 ~ w {print $7" "$8" "$9" "$10; exit}')
    if [ -z "$rel" ]; then
      echo "  [diag] anchor $ANCHOR not OCRed (try $try)"; sleep 1; continue
    fi
    set -- $rel; rowx=$1; rowy=$2; roww=$3; rowh=$4
    eval "$(xdotool getwindowgeometry --shell "$INS")"
    xdotool mousemove $((X + 100)) $((Y + rowy + rowh/2)) click 1; sleep 0.6
    for (( i=0; i<${#ARROWS}; i++ )); do
      ch=${ARROWS:$i:1}; [ "$ch" = D ] && xdotool key Down || xdotool key Up; sleep 0.3
    done
    xdotool key Return; sleep 0.9
    for (( i=0; i<${#NAV}; i++ )); do
      ch=${NAV:$i:1}; [ "$ch" = D ] && xdotool key Down || xdotool key Up; sleep 0.3
    done
    xdotool key Return; sleep 1.2
    import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
    if tesseract /tmp/rt_inspector.png - 2>/dev/null | grep -q "$EXPECT"; then
      echo "  [ok] $EXPECT visible after enum set"
    else
      echo "  [diag][warn] '$EXPECT' not OCR-verified; file assertion decides"
    fi
    return 0
  done
  return 1
}

edit_prop() { # $1 = row token regex, $2 = new value (inline-editable rows)
  local PROPRE="$1" NEWVAL="$2"
  local rel try rowx rowy roww rowh colx
  for try in 1 2 3; do
    import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
    rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' -v w="$PROPRE" '$12 ~ w {print $7" "$8" "$9" "$10; exit}')
    if [ -z "$rel" ]; then
      echo "  [diag] row $PROPRE not OCRed (try $try)"; sleep 1; continue
    fi
    set -- $rel; rowx=$1; rowy=$2; roww=$3; rowh=$4
    eval "$(xdotool getwindowgeometry --shell "$INS")"
    colx=$(( (WIDTH - 180) / 2 + 180 ))
    xdotool mousemove $((X + colx)) $((Y + rowy + rowh/2)) click 1; sleep 0.5
    xdotool mousemove $((X + colx)) $((Y + rowy + rowh/2)) click 1; sleep 0.8
    xdotool key ctrl+a; sleep 0.3
    xdotool type --delay 40 "$NEWVAL"; sleep 0.4
    xdotool key Return; sleep 1
    return 0
  done
  return 1
}

enum_select() { # $1 = row token regex, $2 = popup item regex
  local PROPRE="$1" ITEMRE="$2"
  local rel try rowx rowy roww rowh colx
  for try in 1 2 3; do
    import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
    rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' -v w="$PROPRE" '$12 ~ w {print $7" "$8" "$9" "$10; exit}')
    if [ -z "$rel" ]; then
      echo "  [diag] row $PROPRE not OCRed (try $try)"; sleep 1; continue
    fi
    set -- $rel; rowx=$1; rowy=$2; roww=$3; rowh=$4
    eval "$(xdotool getwindowgeometry --shell "$INS")"
    colx=$(( (WIDTH - 180) / 2 + 180 ))
    xdotool mousemove $((X + colx)) $((Y + rowy + rowh/2)) click 1; sleep 0.4
    xdotool mousemove $((X + colx)) $((Y + rowy + rowh/2)) click --repeat 2 --delay 100 1; sleep 1
    import -window root /tmp/rt_enummenu.png 2>/dev/null
    rel=$(tesseract /tmp/rt_enummenu.png - tsv 2>/dev/null | awk -F'\t' -v w="$ITEMRE" '$12 ~ w {print $7" "$8" "$9" "$10; exit}')
    if [ -z "$rel" ]; then
      echo "  [diag] enum item $ITEMRE not found (try $try)"
      xdotool key Escape; sleep 0.5; continue
    fi
    set -- $rel
    xdotool mousemove $(($1 + $3/2)) $(($2 + $4/2)) click 1; sleep 1.5
    return 0
  done
  return 1
}

save_and_check() { # $1 = phase tag; asserts per-phase file expectations
  local BAR
  BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
  xdotool key ctrl+s; sleep 3
  rt_map_all
  grep -q 'METHOD CreateForm' "$RUN/Form1.prg" || fail "form not saved (save did not happen?)"
  if [ "$1" = nondefault ]; then
    local missing="" pat label
    for spec in '::nWindowState := 2|nWindowState' '::nBorderStyle := 3|nBorderStyle' \
                '::nFormStyle := 1|nFormStyle'; do
      pat=${spec%%|*}; label=${spec##*|}
      [ "$(grep -cF "$pat" "$RUN/Form1.prg")" = 1 ] || missing="$missing $label"
    done
    [ -z "$missing" ] || fail "silently lost on save:$missing"
    grep -qF '::lSizable' "$RUN/Form1.prg" && fail "spurious ::lSizable emitted with default FSizable=0"
  else
    local left="" pat label
    for spec in '::nWindowState|nWindowState' '::nBorderStyle|nBorderStyle' \
                '::nFormStyle|nFormStyle'; do
      pat=${spec%%|*}; label=${spec##*|}
      grep -qF "$pat" "$RUN/Form1.prg" && left="$left $label"
    done
    [ -z "$left" ] || fail "default-return emitted spurious lines:$left"
    grep -q '::cTitle' "$RUN/Form1.prg"  || fail "default-return lost ::cTitle"
    grep -qE '::nWidth[ ]*:=[ ]*700' "$RUN/Form1.prg" || fail "default-return lost ::nWidth"
  fi
}

reopen_resave_fixpoint() {
  local BAR
  sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/formprops.sha1
  rt_reopen_project
  BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
  xdotool key ctrl+s; sleep 3
  rt_map_all
  sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/formprops.sha2
  cmp -s /tmp/formprops.sha1 /tmp/formprops.sha2 || fail "re-save not a fixpoint"
}

rt_provenance
if [ "$PHASE" = "phase1" ] || [ "$PHASE" = "all" ]; then
  rm -rf "$RUN"; mkdir -p "$RUN"
  printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
  printf '%s\n' \
    '// Project1.prg - inspector formprops probe' \
    '#include "hbbuilder.ch"' \
    'PROCEDURE Main()' \
    '   local oApp, oForm1' \
    '   oApp := TApplication():New()' \
    '   oForm1 := TForm1():New()' \
    '   oApp:CreateForm( oForm1 )' \
    '   oApp:Run()' \
    'return' > "$RUN/Project1.prg"
  printf '%s\n' \
    '// Form1.prg - inspector formprops probe' \
    '//--------------------------------------------------------------------' \
    '' \
    'CLASS TForm1 FROM TForm' \
    '' \
    '   // IDE-managed Components' \
    '' \
    '   // Event handlers' \
    '' \
    '   METHOD CreateForm()' \
    '' \
    'ENDCLASS' \
    '//--------------------------------------------------------------------' \
    '' \
    'METHOD CreateForm() CLASS TForm1' \
    '' \
    '   ::cTitle  := "Form1"' \
    '   ::nLeft   := 200' \
    '   ::nTop    := 100' \
    '   ::nWidth  := 700' \
    '   ::nHeight := 600' \
    '' \
    'Return Nil' > "$RUN/Form1.prg"
fi
[ -f "$RUN/Form1.prg" ] || { echo "phase2 needs phase1 output in $RUN"; exit 1; }

rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar)
rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 1
open_inspector

if [ "$PHASE" = "phase1" ] || [ "$PHASE" = "all" ]; then
  # keyboard enum sets anchored on nWindowState (its value OCRs reliably);
  # nFormStyle is 1 row below, nBorderStyle 3 rows above (fixed Appearance order)
  enum_select_kb 'sNormal' 'D'   'DD'   'fsStayOnTop' || fail "could not set nFormStyle fsStayOnTop"
  enum_select_kb 'sNormal' 'UUU' 'DDDD' 'bsDialog'    || fail "could not set nBorderStyle bsDialog"
  enum_select_kb 'sNormal' ''    'DDD'  'wsMaximized' || fail "could not set nWindowState wsMaximized"
  save_and_check nondefault

  # reopen, then screenshot the Inspector with the values loaded from disk
  sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/formprops.sha1
  rt_reopen_project
  BAR=$(rt_find_bar)
  rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 1
  open_inspector
  import -window "$INS" /tmp/formprops-reopen-inspector.png 2>/dev/null
  ocr=$(tesseract /tmp/formprops-reopen-inspector.png - 2>/dev/null)
  for want in Maximized bsDialog fsStayOnTop; do
    echo "$ocr" | grep -q "$want" && echo "  [screenshot] value visible after reopen: $want" \
      || echo "  [screenshot][warn] OCR did not read '$want' (screenshot kept for manual check)"
  done
  rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
  xdotool key ctrl+s; sleep 3
  rt_map_all
  sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/formprops.sha2
  cmp -s /tmp/formprops.sha1 /tmp/formprops.sha2 || fail "re-save not a fixpoint after reopen"
fi

if [ "$PHASE" = "phase2" ] || [ "$PHASE" = "all" ]; then
  scroll_to_top
  enum_select_kb 'sMaximized' 'D'   'D'   'fsNormal'   || fail "could not reset nFormStyle fsNormal"
  enum_select_kb 'sMaximized' 'UUU' 'DDD' 'bsSizeable' || fail "could not reset nBorderStyle bsSizeable"
  enum_select_kb 'sMaximized' ''    'D'   'wsNormal'   || fail "could not reset nWindowState wsNormal"
  save_and_check defaults
  reopen_resave_fixpoint
fi

if [ "$PHASE" = "phase3" ] || [ "$PHASE" = "all" ]; then
  grep -qF '::lSizable := .T.' "$RUN/Form1.prg" || \
    sed -i 's|^   ::nHeight := 600|   ::nHeight := 600\n   ::lSizable := .T.|' "$RUN/Form1.prg"
  grep -qF '::lSizable := .T.' "$RUN/Form1.prg" || fail "could not inject ::lSizable line on disk"
  rt_reopen_project
  BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
  xdotool key ctrl+s; sleep 3
  rt_map_all
  [ "$(grep -cF '::lSizable := .T.' "$RUN/Form1.prg")" = 1 ] || fail "::lSizable := .T. dropped or duplicated on load+save"
  grep -qF '::nWindowState' "$RUN/Form1.prg" && fail "phase3: unexpected ::nWindowState (defaults must not emit)"
  reopen_resave_fixpoint
fi

case "$PHASE" in
  phase1) echo "FORMPROPS PHASE1 PASS: 3 enum props set non-default -> save -> reopen (screenshot) -> fixpoint" ;;
  phase2) echo "FORMPROPS PHASE2 PASS: 3 enum props back to defaults -> save (no spurious lines) -> reopen -> fixpoint" ;;
  phase3) echo "FORMPROPS PHASE3 PASS: ::lSizable := .T. loaded from disk -> save -> preserved once -> fixpoint" ;;
  *)      echo "FORMPROPS ROUNDTRIP PASS: 3 enums non-default roundtrip + default-return + lSizable file roundtrip, all fixpoint" ;;
esac
rt_cleanup
