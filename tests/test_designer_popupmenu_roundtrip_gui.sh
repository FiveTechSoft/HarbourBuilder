#!/bin/bash
# PopupMenu round-trip probe: drop a PopupMenu component, open it in the
# Inspector, double-click aMenuItems to open the Menu Items Editor, add a
# popup with one item, save, require COMPONENT+DEFINE POPUPMENU block in
# Form1.prg, reopen, require persistence + re-save fixpoint.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUN=/tmp/designer_popupmenu
source "$REPO/tests/harness_lib.sh"
fail() { echo "POPUPMENU ROUNDTRIP FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - popupmenu probe' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - popupmenu probe' \
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

# locate the Mnu palette icon by OCR (positions drift with palette width);
# buttons are small: upscale the strip 3x before OCR
import -window root -crop "1600x70+0+60" /tmp/rt_pal_raw.png 2>/dev/null
convert /tmp/rt_pal_raw.png -resize 300% /tmp/rt_palette.png 2>/dev/null
rel=$(tesseract /tmp/rt_palette.png - tsv 2>/dev/null | awk -F'\t' '$12 ~ /^Pop$/ {print $7" "$8" "$9" "$10; exit}')
if [ -n "$rel" ]; then
  set -- $rel; MNUX=$(( ($1 + $3/2) / 3 )); MNUY=$(( 60 + ($2 + $4/2) / 3 ))
else
  echo "  [diag] Mnu OCR miss; tokens:"; tesseract /tmp/rt_palette.png - tsv 2>/dev/null | awk -F'\t' '$12 != "" {printf "%s@x%d ", $12, $7/3}' | head -c 400; echo
  MNUX=1108; MNUY=90
  echo "  [diag] fallback Pop position $MNUX,$MNUY (verified via combo later)"
fi
echo "  [ok] Pop icon at $MNUX,$MNUY"

# drop the MainMenu on the designer (drag gesture like visual controls)
xdotool mousemove "$MNUX" "$MNUY" click 1; sleep 1
xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
xdotool mousemove $((X+300)) $((Y+300)) mousedown 1; sleep 0.5
xdotool mousemove $((X+380)) $((Y+340)) mouseup 1; sleep 1.5

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
      xdotool mouseup 1; sleep 0.6; continue
    fi
    rel=$(tesseract /tmp/rt_viewmenu.png - tsv 2>/dev/null | awk -F'\t' '$8+0 > 20 && $12 ~ /Inspector/ {print $7" "$8" "$9" "$10; exit}')
    [ -z "$rel" ] && { xdotool mouseup 1; sleep 0.6; continue; }
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
  [ -n "$INS" ] && break; sleep 1
done
[ -n "$INS" ] || fail "Inspector window did not appear"
xdotool windowmove "$INS" 700 20; xdotool windowsize "$INS" 560 960
xdotool windowmap "$INS"; xdotool windowraise "$INS"; xdotool windowfocus "$INS"; sleep 1

# pick the MainMenu in the Inspector's object combo (top of the window)
import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' '$12 ~ /TForm|AS/ {print $7" "$8" "$9" "$10; exit}')
[ -n "$rel" ] || fail "Inspector object combo not found"
set -- $rel
eval "$(xdotool getwindowgeometry --shell "$INS")"
xdotool mousemove $((X + $1 + $3/2)) $((Y + $2 + $4/2)) click 1; sleep 1.2
import -window root /tmp/rt_combo.png 2>/dev/null
rel=$(tesseract /tmp/rt_combo.png - tsv 2>/dev/null | awk -F'\t' 'tolower($12) ~ /popupmenu/ {print $7" "$8" "$9" "$10; exit}')
[ -n "$rel" ] || fail "PopupMenu not listed in Inspector combo"
set -- $rel
xdotool mousemove $(($1 + $3/2)) $(($2 + $4/2)) click 1; sleep 1.2

# find the aMenuItems row (Data category, type 'M'); scroll down first:
# it sits below the fold; double-click opens the editor
eval "$(xdotool getwindowgeometry --shell "$INS")"
xdotool mousemove $((X + 280)) $((Y + 500)); sleep 0.3
for i in $(seq 1 14); do xdotool click 5; sleep 0.2; done
sleep 0.5
rel=""
for try in 1 2 3; do
  import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
  rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' 'tolower($12) ~ /menu.?tems/ {print $7" "$8" "$9" "$10; exit}')
  [ -n "$rel" ] && break
  echo "  [diag] aMenuItems row not OCRed (try $try)"; sleep 1
done
[ -n "$rel" ] || fail "aMenuItems row not found in Inspector"
set -- $rel
eval "$(xdotool getwindowgeometry --shell "$INS")"
xdotool mousemove $((X + $1 + $3/2)) $((Y + $2 + $4/2)) click --repeat 2 --delay 100 1; sleep 2

# Menu Items Editor dialog
MEI=""
for try in $(seq 1 8); do
  MEI=$(xdotool search --name 'Menu Items Editor' 2>/dev/null | head -1)
  [ -n "$MEI" ] && break; sleep 1
done
[ -n "$MEI" ] || fail "Menu Items Editor dialog did not open"
xdotool windowmove "$MEI" 300 200; xdotool windowmap "$MEI"; xdotool windowraise "$MEI"; xdotool windowfocus "$MEI"; sleep 1
import -window "$MEI" /tmp/mei-open.png

# toolbar/bottom buttons sit at fixed offsets in the modal 640x400 dialog
# (measured from a live capture; OCR of the tiny +/- labels is unreliable)
mei_click_at() { # $1 = rel-x, $2 = rel-y, $3 = label for diags
  eval "$(xdotool getwindowgeometry --shell "$MEI")"
  xdotool mousemove $((X + $1)) $((Y + $2)) click 1; sleep 1
  echo "  [ok] MEI click $3 at +$1,+$2"
}
mei_type_caption() { # $1 = caption text; the right-pane Caption entry sits
  # at a fixed offset in the modal 640x400 dialog (measured from a live capture)
  eval "$(xdotool getwindowgeometry --shell "$MEI")"
  xdotool mousemove $((X + 500)) $((Y + 69)) click 1; sleep 0.5
  xdotool key ctrl+a; sleep 0.2
  xdotool type --delay 40 "$1"; sleep 0.4
  xdotool key Tab; sleep 0.6
  return 0
}

mei_click_at 51 24 "+Popup"
mei_type_caption "Archivo" || fail "Caption entry not found (popup)"
mei_click_at 138 24 "+Item"
mei_type_caption "Abrir" || fail "Caption entry not found (item)"
import -window "$MEI" /tmp/mei-filled.png
mei_click_at 504 376 "OK"
sleep 1.5

# save via the bar and require the emitted menu code
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
rt_map_all
grep -q 'METHOD CreateForm' "$RUN/Form1.prg" || fail "form not saved (save did not happen?)"
grep -qE 'COMPONENT ::o\w+ TYPE CT_POPUPMENU' "$RUN/Form1.prg" || fail "PopupMenu component not emitted"
grep -q 'DEFINE POPUPMENU' "$RUN/Form1.prg" || fail "DEFINE POPUPMENU not emitted"
grep -q 'END POPUPMENU' "$RUN/Form1.prg" || fail "END POPUPMENU not emitted"
grep -qF 'DEFINE POPUP "Archivo"' "$RUN/Form1.prg" || fail "popup Archivo not emitted"
grep -qF 'MENUITEM "Abrir"' "$RUN/Form1.prg" || fail "item Abrir not emitted"

# reopen and require persistence + re-save fixpoint
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/popupmenu.sha1
rt_reopen_project
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
rt_map_all
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/popupmenu.sha2
cmp -s /tmp/popupmenu.sha1 /tmp/popupmenu.sha2 || fail "re-save not a fixpoint after reopen"
grep -qF 'MENUITEM "Abrir"' "$RUN/Form1.prg" || fail "menu item lost after reopen+resave"

echo "POPUPMENU ROUNDTRIP PASS: PopupMenu + editor popup/item -> save -> reopen -> fixpoint"
rt_cleanup
