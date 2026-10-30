#!/bin/bash
# T4 negative: a FOLDER/BROWSE line that cannot be parsed faithfully must
# block the save (parse-block refusal) and leave Form1.prg byte-identical.
# Case A: unbalanced quote in PROMPTS. Case B: "90x" in COLSIZES (would be
# silently truncated to 90 by a lenient Val()-only parse).
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
source "$REPO/tests/harness_lib.sh"
fail() { echo "T4BLOCK FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance

run_case() {  # $1 name, $2 sed expr, $3 reason regex expected in dialog OCR
  local RUN=/tmp/t4neg_$1
  rm -rf "$RUN"; mkdir -p "$RUN"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
  sed -i "$2" "$RUN/Form1.prg"
  grep -q "PROMPTS" "$RUN/Form1.prg" || fail "$1: corruption sed did not apply"
  rt_setup "$RUN"
  rt_launch_ide
  rt_reopen_project
  local MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  local W0=$(rt_ide_windows | tr '\n' ' ')
  # the refusal dialog may appear AT OPEN (the designer parses the corrupted
  # form right away; s_cLastRefusal then dedups later syncs) or on the first
  # designer->code sync; accept whichever comes first.
  local DLG=""
  for i in 1 2 3; do
    for w in $(rt_ide_windows); do
      [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] &&         xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && { DLG=$w; break; }
    done
    [ -n "$DLG" ] && break
    sleep 1
  done
  DLGATOPEN=no
  [ -n "$DLG" ] && DLGATOPEN=yes
  if [ -z "$DLG" ]; then
    eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
    xdotool windowsize "$RT_DESIGNER" $((WIDTH+1)) "$HEIGHT"; sleep 1.5
    xdotool windowsize "$RT_DESIGNER" "$WIDTH" "$HEIGHT"; sleep 1.5
    for i in 1 2 3 4 5; do
      for w in $(rt_ide_windows); do
        case " $W0 " in *" $w "*) continue;; esac
        [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && { DLG=$w; break; }
      done
      [ -n "$DLG" ] && break
      sleep 1
    done
  fi
  [ -n "$DLG" ] || fail "$1: save/sync was not refused (no dialog at open nor on sync)"
  echo "  [$1] SEQ: refusal dialog present (at open=$DLGATOPEN)"
  eval "$(xdotool getwindowgeometry --shell "$DLG")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4neg_$1.png
  local TXT=$(tesseract /tmp/t4neg_$1.png - 2>/dev/null)
  echo "  [$1] dialog OCR: $(echo "$TXT" | tr '\n' ' ' | cut -c1-140)"
  echo "$TXT" | grep -qi 'aborted' || fail "$1: dialog is not the abort notice"
  echo "$TXT" | grep -qE "$3" || fail "$1: dialog does not name the reason ($3)"
  local MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  [ "$MD0" = "$MD1" ] || fail "$1: Form1.prg changed on disk after the refused save"
  # dismiss, then an explicit dirty save must be refused again
  xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT-14)) click 1; sleep 1
  echo "  [$1] SEQ: dialog dismissed, forcing explicit save via designer resize"
  eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
  xdotool windowsize "$RT_DESIGNER" $((WIDTH+2)) "$HEIGHT"; sleep 1
  BAR=$(rt_find_bar); xdotool windowactivate "$BAR" 2>/dev/null
  xdotool mousemove 700 12 click 1; sleep 0.4
  xdotool key ctrl+s; sleep 2
  local DLG2=""
  for w in $(xdotool search --pid "$RT_IDEPID" 2>/dev/null); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] &&       xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && { DLG2=$w; break; }
  done
  [ -n "$DLG2" ] || fail "$1: explicit Ctrl+S after the first refusal was not refused"
  eval "$(xdotool getwindowgeometry --shell "$DLG2")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4neg_$1-ctrls.png
  local TXT2=$(tesseract /tmp/t4neg_$1-ctrls.png - 2>/dev/null)
  echo "  [$1] SEQ: second refusal OCR: $(echo "$TXT2" | tr '\n' ' ' | cut -c1-100)"
  echo "$TXT2" | grep -qi 'aborted' || fail "$1: second dialog is not the abort notice"
  local MD2=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  [ "$MD0" = "$MD2" ] || fail "$1: Form1.prg changed on disk after the refused Ctrl+S"
  xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT-14)) click 1; sleep 1
  for i in 1 2 3 4 5; do
    xwininfo -id "$DLG2" 2>/dev/null | grep -q IsViewable || break
    echo "  [$1] SEQ: dialog still modal after dismiss click, retrying"
    xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT-14)) click 1; sleep 1
  done
  xwininfo -id "$DLG2" 2>/dev/null | grep -q IsViewable && fail "$1: second dialog would not dismiss (modal grab)"
  echo "  [$1] SEQ: second dialog dismissed"
  # repair the corrupted line in the editor; the save must then succeed
  echo "  [$1] SEQ: repairing line $4 in the code editor"
  local CED=""
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
  done
  [ -n "$CED" ] || fail "$1: Code Editor window not found"
  eval "$(xdotool getwindowgeometry --shell "$CED")"
  xdotool windowactivate "$CED" 2>/dev/null
  xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.5
  xdotool key ctrl+Home; sleep 0.3
  xdotool key --repeat $(( $4 - 1 )) --repeat-delay 15 Down; sleep 0.5
  xdotool key Home; sleep 0.2
  xdotool key shift+End; sleep 0.2
  xdotool type --delay 15 "$5"; sleep 2
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4neg_$1-repair.png
  echo "  [$1] SEQ: editor after repair OCR tail: $(tesseract /tmp/t4neg_$1-repair.png - 2>/dev/null | grep -iE 'folder|browse|prompts|colsizes' | head -2 | tr '\n' ' ' | cut -c1-120)"
  # save via the real File -> Save menu: the Ctrl+S accel lives on the main
  # window's menu and is not delivered when the Code Editor toplevel has focus
  menu_path_click '^Save' || fail "$1: File > Save menu path not clickable"
  sleep 2
  # any dialog here (third refusal, freshness guard) is product behavior: capture it
  local DLG3=""
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && \
      xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && { DLG3=$w; break; }
  done
  if [ -n "$DLG3" ]; then
    eval "$(xdotool getwindowgeometry --shell "$DLG3")"
    import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4neg_$1-dlg3.png
    echo "  [$1] SEQ: dialog after repaired save OCR: $(tesseract /tmp/t4neg_$1-dlg3.png - 2>/dev/null | tr '\n' ' ' | cut -c1-140)"
    fail "$1: save still refused after a verified repair (dialog captured)"
  fi
  import -window root /tmp/t4neg_$1-aftersave.png
  local MD3=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  [ "$MD3" != "$MD0" ] || fail "$1: save after repair did not write the file"
  grep -qF "$6" "$RUN/Form1.prg" || fail "$1: repaired line not in the saved file"
  echo "  [$1] SEQ: save after repair succeeded, repaired line on disk"
  echo "  [$1] refused twice byte-identical, repair recovered the save"
  rt_cleanup
  sleep 1
}

WANT="${1:-all}"
[ "$WANT" = "all" ] || [ "$WANT" = "prompts" ] || exit 0
run_case prompts 's/PROMPTS "P1", "P2"/PROMPTS "P1", "P2/' 'PROMPTS' 54 \
  '   @ 60, 460 FOLDER ::oFld1 OF Self SIZE 165, 160 PROMPTS "P1", "P2"' \
  'PROMPTS "P1", "P2"'
[ "$WANT" = "all" ] || [ "$WANT" = "colsizes" ] || exit 0
run_case colsizes 's/COLSIZES 90, 60/COLSIZES 90x, 60/' 'COLSIZES' 56 \
  '   @ 240, 460 BROWSE ::oBrw1 OF Self SIZE 165, 150 HEADERS "Nombre", "Edad" COLSIZES 90, 60 FOOTERS "Total", ""' \
  'COLSIZES 90, 60'

[ "$WANT" = "all" ] || [ "$WANT" = "items" ] || exit 0
# Pre-existing block type at open: if an R2-era ITEMS block also dialogs at
# open, the at-open notice is the old guard's behavior, not a T4 regression.
RUN=/tmp/t4neg_items
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
sed -i 's/ITEMS "Uno", "Di " + Chr( 34 ) + "si" + Chr( 34 ), "Tre, s"/ITEMS "Uno|x", "Tre"/' "$RUN/Form1.prg"
rt_setup "$RUN"
rt_launch_ide
rt_reopen_project
MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
DLG=""
for i in 1 2 3 4 5; do
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] &&       xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && { DLG=$w; break; }
  done
  [ -n "$DLG" ] && break
  sleep 1
done
if [ -n "$DLG" ]; then
  eval "$(xdotool getwindowgeometry --shell "$DLG")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4neg_items.png
  echo "  [items] SEQ: at-open dialog=yes OCR: $(tesseract /tmp/t4neg_items.png - 2>/dev/null | tr '\n' ' ' | cut -c1-120)"
else
  echo "  [items] SEQ: at-open dialog=no"
fi
[ "$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)" = "$MD0" ] || fail "items: disk changed on open"
rt_cleanup
sleep 1

echo "T4BLOCK PASS: unparseable FOLDER PROMPTS and non-numeric COLSIZES both refused; disk byte-identical."
