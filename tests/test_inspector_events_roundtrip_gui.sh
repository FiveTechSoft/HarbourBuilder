#!/bin/bash
# Inspector Events-tab round-trip probe: drop a Button, open the Inspector
# on it, switch to the Events tab, double-click OnClick (creates the
# static handler + event wiring via OnEventDblClick), save, require the
# handler and the ::oButton1:OnClick wiring in Form1.prg, reopen, require
# persistence and a re-save fixpoint.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUN=/tmp/inspector_events
source "$REPO/tests/harness_lib.sh"
fail() { echo "EVENTS ROUNDTRIP FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
printf 'Project1\nForm1\n' > "$RUN/Project1.hbp"
printf '%s\n' \
  '// Project1.prg - inspector events probe' \
  '#include "hbbuilder.ch"' \
  'PROCEDURE Main()' \
  '   local oApp, oForm1' \
  '   oApp := TApplication():New()' \
  '   oForm1 := TForm1():New()' \
  '   oApp:CreateForm( oForm1 )' \
  '   oApp:Run()' \
  'return' > "$RUN/Project1.prg"
printf '%s\n' \
  '// Form1.prg - inspector events probe' \
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

# drop a Button (palette Standard row, same x as the walkthrough probe)
xdotool mousemove 532 90 click 1; sleep 1
xdotool windowmap "$RT_DESIGNER"; xdotool windowraise "$RT_DESIGNER"
eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
xdotool mousemove $((X+300)) $((Y+40)) mousedown 1; sleep 0.5
xdotool mousemove $((X+390)) $((Y+66)) mouseup 1; sleep 1.5

# select the dropped button (click its center), then open the Inspector
xdotool mousemove $((X+345)) $((Y+53)) click 1; sleep 1

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

# the Inspector must be showing the button, not the form
import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
tesseract /tmp/rt_inspector.png - 2>/dev/null | grep -qi 'TButton\|Button' \
  || fail "Inspector is not showing the dropped Button"

# switch to the Events tab
rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' '$12 ~ /^Events$/ {print $7" "$8" "$9" "$10; exit}')
[ -n "$rel" ] || fail "Events tab not found in Inspector"
set -- $rel
eval "$(xdotool getwindowgeometry --shell "$INS")"
xdotool mousemove $((X + $1 + $3/2)) $((Y + $2 + $4/2)) click 1; sleep 1.2

# double-click the OnClick event row -> creates handler + wiring
rel=""
for try in 1 2 3; do
  import -window "$INS" /tmp/rt_inspector.png 2>/dev/null
  rel=$(tesseract /tmp/rt_inspector.png - tsv 2>/dev/null | awk -F'\t' 'tolower($12) ~ /onclick/ {print $7" "$8" "$9" "$10; exit}')
  [ -n "$rel" ] && break
  echo "  [diag] OnClick row not OCRed (try $try)"; sleep 1
done
[ -n "$rel" ] || fail "OnClick event row not found in Events tab"
set -- $rel
eval "$(xdotool getwindowgeometry --shell "$INS")"
xdotool mousemove $((X + $1 + $3/2)) $((Y + $2 + $4/2)) click --repeat 2 --delay 100 1; sleep 2

# save via the bar and require handler + wiring in the file
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
rt_map_all
grep -q 'METHOD CreateForm' "$RUN/Form1.prg" || fail "form not saved (save did not happen?)"
grep -q 'static function Button1Click' "$RUN/Form1.prg" || fail "handler Button1Click not created on Events double-click"
grep -qF '::oButton1:OnClick := { || Button1Click( Self ) }' "$RUN/Form1.prg" \
  || fail "OnClick wiring not emitted in CreateForm"

# reopen and require persistence + re-save fixpoint
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/events.sha1
rt_reopen_project
grep -q 'static function Button1Click' "$RUN/Form1.prg" || fail "handler lost after reopen (file level)"
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1
xdotool key ctrl+s; sleep 3
rt_map_all
sha1sum "$RUN/Form1.prg" | awk '{print $1}' > /tmp/events.sha2
cmp -s /tmp/events.sha1 /tmp/events.sha2 || fail "re-save not a fixpoint after reopen"
grep -qF '::oButton1:OnClick := { || Button1Click( Self ) }' "$RUN/Form1.prg" \
  || fail "OnClick wiring lost after reopen+resave"

echo "EVENTS ROUNDTRIP PASS: Events dblclick OnClick -> handler+wiring -> save -> reopen -> fixpoint"
rt_cleanup
