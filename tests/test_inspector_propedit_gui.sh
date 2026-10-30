#!/bin/bash
# Inspector property-edit probe: drop a Button, edit its cText property in the
# Inspector window, save, verify PROMPT persisted in generated code, reopen,
# and require a re-save fixpoint.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUN=/tmp/inspector_propedit
source "$REPO/tests/harness_lib.sh"
fail() { echo "INSPECTOR PROPEDIT FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - inspector propedit probe' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - inspector propedit probe' \
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

rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar)
rt_park_all_but "$BAR" "$RT_DESIGNER"; sleep 1

drop() { # $1 icon-x  $2 dx  $3 dy  $4 w  $5 h
  xdotool mousemove "$1" 90 click 1; sleep 1
  xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
  eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
  xdotool mousemove $((X+$2)) $((Y+$3)) mousedown 1; sleep 0.5
  xdotool mousemove $((X+$2+$4)) $((Y+$3+$5)) mouseup 1; sleep 1.5
}

drop 532 20 40 90 26     # Button
sleep 1

# select the button (click its center)
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"; xdotool windowfocus "$RT_DESIGNER"
xdotool mousemove $((X+65)) $((Y+53)) click 1; sleep 1

# View -> Inspector
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
view_menu_click || fail "View -> Inspector menu path failed"

INS=""
for try in $(seq 1 10); do
  INS=$(xdotool search --name '^Inspector' 2>/dev/null | head -1)
  [ -n "$INS" ] && break
  sleep 1
done
[ -n "$INS" ] || fail "Inspector window did not appear"
xdotool windowmove "$INS" 850 120; xdotool windowmap "$INS"; xdotool windowraise "$INS"; xdotool windowfocus "$INS"; sleep 1

# OCR the Inspector window, find the cText row, edit its value cell
edit_prop() { # $1 = property token regex, $2 = new value
  local PROPRE="$1" NEWVAL="$2"
  local rel try rowx rowy roww rowh colx
  for try in 1 2 3; do
    import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
    rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' -v w="$1" '$12 ~ w {print $7" "$8" "$9" "$10; exit}')
    if [ -z "$rel" ]; then
      echo "  [diag] property $1 not OCRed (try $try):"; tesseract /tmp/rt_inspector.png - 2>/dev/null | grep -v '^$' | head -10
      sleep 1; continue
    fi
    set -- $rel; rowx=$1; rowy=$2; roww=$3; rowh=$4
    eval "$(xdotool getwindowgeometry --shell "$INS")"
    # value column: right of the name column (~180px), click near right third
    colx=$(( (WIDTH - 180) / 2 + 180 ))
    xdotool mousemove $((X + colx)) $((Y + rowy + rowh/2)) click 1; sleep 0.5
    xdotool mousemove $((X + colx)) $((Y + rowy + rowh/2)) click 1; sleep 0.8
    xdotool key ctrl+a; sleep 0.3
    xdotool type --delay 40 "$NEWVAL"; sleep 0.4
    xdotool key Return; sleep 1
    # verify the row shows the new value
    import -window "$INS" /tmp/rt_inspector2.png 2>/dev/null
    if tesseract /tmp/rt_inspector2.png - 2>/dev/null | grep -q "$NEWVAL"; then
      return 0
    fi
    echo "  [diag] value $NEWVAL not visible after edit (try $try)"
  done
  return 1
}
edit_prop '^cText' 'PROBE_OK' || fail "could not edit cText to PROBE_OK"

# save via the bar
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
rt_map_all

grep -q 'PROMPT "PROBE_OK"' "$RUN/Form1.prg" || { import -window root /tmp/propedit-save.png; fail "PROMPT PROBE_OK not in Form1.prg after save"; }

# reopen and require persistence + re-save fixpoint
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/propedit.sha1
rt_reopen_project
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
rt_map_all
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/propedit.sha2
grep -q 'PROMPT "PROBE_OK"' "$RUN/Form1.prg" || fail "PROMPT PROBE_OK lost after reopen"
cmp -s /tmp/propedit.sha1 /tmp/propedit.sha2 || fail "re-save not a fixpoint after property edit"

echo "INSPECTOR PROPEDIT PASS: cText edit -> save -> reopen -> fixpoint"
rt_cleanup
