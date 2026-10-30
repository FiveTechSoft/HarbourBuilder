#!/bin/bash
# Unsaved-work protection: with a dirty buffer, Reopen / Exit (Ctrl+Q) /
# New Application (Ctrl+N) must NOT silently discard it. Contract: a
# Save/Discard/Cancel dialog appears; choosing Cancel keeps everything
# (buffer content and IDE session intact). Save/Discard paths are
# exercised separately only after the Cancel contract is proven.
# RED on binaries without dirty tracking: each path discards silently.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/runhash"
RUNA=/tmp/rt_dirty_a
TRACE=/tmp/rt_dirty_trace.log
source "$REPO/tests/harness_lib.sh"
fail() { echo "DIRTY FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
FAILN=0
CASES="${@:-reopen}"

launch_a() {
  rm -rf "$RUNA"; mkdir -p "$RUNA"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUNA"/
  sed -i 's|/tmp/rt_runhash_trace.log|/tmp/rt_dirty_trace.log|' "$RUNA"/Form1.prg
  rm -f "$TRACE"
  rt_setup "$RUNA"
  rt_launch_ide
  IDEPID=$RT_IDEPID; OTHERPID=""
  rt_reopen_project
}

dirty_the_buffer() {  # tail edit VERSION-A -> VERSION-Y, OCR-verified; sets CED
  set_buffer_version 'return "VERSION-Y"'
}

set_buffer_version() {  # $1 = exact replacement line; OCR-verified; sets CED
  local WANT="$1" TOK
  CED=""
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
  done
  [ -n "$CED" ] || fail "Code Editor window not found"
  local D DX DY BAR
  D=$(rt_find_designer) || fail "designer window not found"
  eval "$(xdotool getwindowgeometry --shell "$D")"; DX=$X; DY=$Y
  BAR=$(rt_find_bar); rt_park_all_but "$CED" "$BAR"; sleep 0.5
  eval "$(xdotool getwindowgeometry --shell "$CED")"
  xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.5
  xdotool key ctrl+End; sleep 0.3
  xdotool key Up; sleep 0.2
  xdotool key Home; sleep 0.2
  xdotool key shift+End; sleep 0.2
  xdotool type --delay 15 "$WANT"; sleep 1
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/dl_edit.png 2>/dev/null
  TOK=$(echo "$WANT" | grep -o 'VERSION-[A-Z]')
  tesseract /tmp/dl_edit.png - 2>/dev/null | grep -q "$TOK" \
    || { tesseract /tmp/dl_edit.png - 2>/dev/null | tail -3; fail "buffer edit did not land (harness)"; }
  xdotool windowmove "$D" "$DX" "$DY"; sleep 0.3
  echo "  [t=$SECONDS] buffer set to $TOK (unsaved)"
}

buffer_shows() {  # $1 = token; 0 if the code editor tail shows it
  # on miss, dump what the tail actually shows for diagnosis

  local BAR
  BAR=$(rt_find_bar); rt_park_all_but "$CED" "$BAR"; sleep 0.5
  eval "$(xdotool getwindowgeometry --shell "$CED")"
  xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.4
  xdotool key ctrl+End; sleep 0.5
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/dl_check.png 2>/dev/null
  if tesseract /tmp/dl_check.png - 2>/dev/null | grep -q "$1"; then
    return 0
  fi
  echo "  [diag] editor tail OCR:"; tesseract /tmp/dl_check.png - 2>/dev/null | tail -4
  cp /tmp/dl_check.png "/tmp/dl_check_fail_$$.png" 2>/dev/null
  return 1
}

rt_is_unsaved_dialog() {  # $1 = window id; 0 if titled like the protection dialog
  xdotool getwindowname "$1" 2>/dev/null | grep -qi 'unsaved'
}

trigger_and_expect_dialog() {  # $1 = key sequence; echoes dialog window id
  local BEFORE BAR w i
  BEFORE=$(rt_ide_windows | sort -n | tr '\n' ' ')
  BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
  xdotool mousemove 700 12 click 1; sleep 0.4
  xdotool key "$1"
  DLG=""
  for i in $(seq 1 8); do
    for w in $(rt_ide_windows); do
      case " $BEFORE " in *" $w "*) ;; *) rt_is_unsaved_dialog "$w" && DLG=$w;; esac
    done
    [ -n "$DLG" ] && break
    sleep 2
  done
  rt_map_all; sleep 0.5
  echo "$DLG"
}

shot_dialog() {  # $1 = dialog id, $2 = case tag: real capture for the report
  local X Y WIDTH HEIGHT
  [ -n "$1" ] || return 0
  eval "$(xdotool getwindowgeometry --shell "$1")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" "/tmp/dl_dialog_$2.png" 2>/dev/null
  echo "  [capture] /tmp/dl_dialog_$2.png (${WIDTH}x${HEIGHT}+${X}+${Y})"
}

cancel_dialog() {  # $1 = dialog window id: Escape, verify closed, else click Cancel
  local DLGID="$1" X Y WIDTH HEIGHT rel
  [ -n "$DLGID" ] || return 0
  xdotool windowmap "$DLGID" 2>/dev/null; xdotool windowactivate "$DLGID" 2>/dev/null
  sleep 0.5; xdotool key Escape; sleep 1
  if xdotool search --pid "$RT_IDEPID" 2>/dev/null | grep -qx "$DLGID"; then
    echo "  [diag] dialog survived Escape; clicking its Cancel button"
    eval "$(xdotool getwindowgeometry --shell "$DLGID")"
    import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/dl_dialog.png 2>/dev/null
    rel=$(tesseract /tmp/dl_dialog.png - tsv 2>/dev/null | awk -F'\t' '$12 ~ /Cancel/ {print $7" "$8" "$9" "$10; exit}')
    if [ -n "$rel" ]; then
      set -- $rel
      xdotool mousemove $((X + $1 + $3/2)) $((Y + $2 + $4/2)) click 1; sleep 1
    else
      echo "  [diag] Cancel button not found by OCR"; tesseract /tmp/dl_dialog.png - 2>/dev/null | head -3
    fi
    xdotool search --pid "$RT_IDEPID" 2>/dev/null | grep -qx "$DLGID"       && echo "  [diag] dialog STILL open after Cancel click"       || echo "  [diag] dialog closed via Cancel button"
  fi
}

run_reopen() {
launch_a
dirty_the_buffer
local BEFORE w i
BEFORE=$(rt_ide_windows | sort -n | tr '
' ' ')
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 20 12 mousedown 1; sleep 0.4; xdotool mouseup 1; sleep 0.8
xdotool mousemove 100 134 click 1
DLG=""
for i in $(seq 1 8); do
  for w in $(rt_ide_windows); do
    case " $BEFORE " in *" $w "*) ;; *) rt_is_unsaved_dialog "$w" && DLG=$w;; esac
  done
  [ -n "$DLG" ] && break
  sleep 2
done
rt_map_all; sleep 0.5
if [ -n "$DLG" ]; then
  echo "  reopen: protection dialog appeared"
  shot_dialog "$DLG" reopen
  cancel_dialog "$DLG"
  buffer_shows 'VERSION-Y' \
    && echo "  reopen+Cancel: unsaved buffer preserved (VERSION-Y)" \
    || { echo "  REOPEN: buffer lost despite Cancel"; FAILN=$((FAILN+1)); }
  kill -0 "$IDEPID" 2>/dev/null \
    || { echo "  REOPEN: IDE died"; FAILN=$((FAILN+1)); }
else
  echo "  REOPEN: no protection dialog; checking whether the buffer was discarded"
  buffer_shows 'VERSION-Y' \
    && echo "  REOPEN-UNGUARDED: buffer survived (unexpected)" \
    || echo "  REOPEN-UNGUARDED: unsaved buffer SILENTLY DISCARDED (VERSION-Y lost)"
  FAILN=$((FAILN+1))
fi
echo "reopen case done (FAILN=$FAILN)"
rt_cleanup
}

run_exit() {
launch_a
dirty_the_buffer
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  exit: protection dialog appeared"
  shot_dialog "$DLG" exit
  cancel_dialog "$DLG"
  kill -0 "$IDEPID" 2>/dev/null \
    && echo "  exit+Cancel: IDE still running" \
    || { echo "  EXIT: IDE closed despite Cancel"; FAILN=$((FAILN+1)); }
  buffer_shows 'VERSION-Y' \
    && echo "  exit+Cancel: unsaved buffer preserved (VERSION-Y)" \
    || { echo "  EXIT: buffer lost despite Cancel"; FAILN=$((FAILN+1)); }
else
  sleep 2
  if kill -0 "$IDEPID" 2>/dev/null; then
    echo "  EXIT: ctrl+q did nothing (unexpected, no dialog)"
  else
    echo "  EXIT-UNGUARDED: IDE closed with unsaved changes, no prompt"
  fi
  FAILN=$((FAILN+1))
fi
echo "exit case done (FAILN=$FAILN)"
rt_cleanup
}

run_newapp() {
launch_a
dirty_the_buffer
DLG=$(trigger_and_expect_dialog "ctrl+n")
if [ -n "$DLG" ]; then
  echo "  newapp: protection dialog appeared"
  shot_dialog "$DLG" newapp
  cancel_dialog "$DLG"
  buffer_shows 'VERSION-Y' \
    && echo "  newapp+Cancel: unsaved buffer preserved (VERSION-Y)" \
    || { echo "  NEWAPP: buffer lost despite Cancel"; FAILN=$((FAILN+1)); }
else
  buffer_shows 'VERSION-Y' \
    && echo "  NEWAPP-UNGUARDED: buffer survived (unexpected)" \
    || echo "  NEWAPP-UNGUARDED: unsaved buffer SILENTLY DISCARDED (VERSION-Y lost)"
  FAILN=$((FAILN+1))
fi
echo "newapp case done (FAILN=$FAILN)"
rt_cleanup
}

run_cleanopen() {
launch_a
local BEFORE w i
BEFORE=$(rt_ide_windows | sort -n | tr '\n' ' ')
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 20 12 mousedown 1; sleep 0.4; xdotool mouseup 1; sleep 0.8
xdotool mousemove 100 134 click 1
DLG=""
for i in $(seq 1 6); do
  for w in $(rt_ide_windows); do
    case " $BEFORE " in *" $w "*) ;; *) rt_is_unsaved_dialog "$w" && DLG=$w;; esac
  done
  [ -n "$DLG" ] && break
  sleep 2
done
rt_map_all; sleep 0.5
if [ -n "$DLG" ]; then
  echo "  CLEANOPEN: FALSE PROMPT on Reopen (no edits were made)"
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  echo "  cleanopen: Reopen proceeded without prompt (nothing to lose)"
fi
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  CLEANOPEN: FALSE PROMPT on Exit (no edits were made)"
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  sleep 2
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  CLEANOPEN: ctrl+q did not close the clean IDE"; FAILN=$((FAILN+1)); }     || echo "  cleanopen: Exit closed immediately, no false prompt"
fi
echo "cleanopen case done (FAILN=$FAILN)"
rt_cleanup
}

run_revert() {
launch_a
dirty_the_buffer
set_buffer_version 'return "VERSION-A"'
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  REVERT: FALSE PROMPT on Exit after reverting to the exact saved text"
  shot_dialog "$DLG" revert
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  sleep 2
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  REVERT: ctrl+q did not close after exact revert"; FAILN=$((FAILN+1)); }     || echo "  revert: edit+revert is clean; Exit closed with no prompt"
fi
echo "revert case done (FAILN=$FAILN)"
rt_cleanup
}

click_dialog_button() {  # $1 = dialog id, $2 = OCR name regex
  local DLGID="$1" WANT="$2" X Y WIDTH HEIGHT rel
  xdotool windowmap "$DLGID" 2>/dev/null; sleep 0.3
  eval "$(xdotool getwindowgeometry --shell "$DLGID")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/dl_btn.png 2>/dev/null
  rel=$(tesseract /tmp/dl_btn.png - tsv 2>/dev/null | awk -F'\t' -v w="$WANT" '$12 ~ w {print $7" "$8" "$9" "$10; exit}')
  [ -n "$rel" ] || { echo "  [diag] button $WANT not found"; return 1; }
  set -- $rel
  xdotool mousemove $((X + $1 + $3/2)) $((Y + $2 + $4/2)) click 1; sleep 1
}

run_savefail() {
launch_a
chmod a-w "$RUNA"/* 2>/dev/null
dirty_the_buffer
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -z "$DLG" ]; then
  echo "  SAVEFAIL: no protection dialog on Exit"; FAILN=$((FAILN+1))
else
  shot_dialog "$DLG" savefail1
  click_dialog_button "$DLG" '^Save$'   # writes must fail (read-only files)
  sleep 2
  if kill -0 "$IDEPID" 2>/dev/null; then
    echo "  savefail: IDE still running after failed Save (did not continue)"
  else
    echo "  SAVEFAIL: IDE closed although the save FAILED"; FAILN=$((FAILN+1))
  fi
  # the failed save must WARN (auditor: silent read-only failure). Find the
  # warning, capture it as evidence, dismiss it.
  WARN=""
  for w in $(rt_ide_windows); do
    xdotool getwindowname "$w" 2>/dev/null | grep -q '^HbBuilder$' && WARN=$w
  done
  if [ -n "$WARN" ]; then
    echo "  savefail: failure warning dialog present"
    shot_dialog "$WARN" savefail-warning
    xdotool windowactivate "$WARN" 2>/dev/null; sleep 0.5; xdotool key Return; sleep 1
  else
    echo "  SAVEFAIL: no warning dialog after failed Save (silent failure)"
    FAILN=$((FAILN+1))
  fi
  DLG2=$(trigger_and_expect_dialog "ctrl+q")
  if [ -n "$DLG2" ]; then
    echo "  savefail: dirty still set after failed Save (guard prompts again)"
    shot_dialog "$DLG2" savefail2
    cancel_dialog "$DLG2"
    kill -0 "$IDEPID" 2>/dev/null       || { echo "  SAVEFAIL: IDE closed despite Cancel"; FAILN=$((FAILN+1)); }
  else
    echo "  SAVEFAIL: dirty flag lost after failed Save (no second prompt)"; FAILN=$((FAILN+1))
  fi
fi
chmod u+w "$RUNA"/* 2>/dev/null
echo "savefail case done (FAILN=$FAILN)"
rt_cleanup
}

run_xclose() {
launch_a
dirty_the_buffer
BAR=$(rt_find_bar)
local BEFORE w i
BEFORE=$(rt_ide_windows | sort -n | tr '\n' ' ')
# real WM_DELETE_WINDOW client message (what a window-manager close sends);
# xdotool windowclose without a WM can hard-kill instead
if [ ! -x /tmp/wmdel ]; then
  gcc "$REPO/tests/wmdel.c" -o /tmp/wmdel -I/tmp/gtk-root/usr/include     -L/tmp/gtk-root/usr/lib/x86_64-linux-gnu -lX11 || fail "wmdel build failed"
fi
/tmp/wmdel "$BAR"
DLG=""
for i in $(seq 1 8); do
  for w in $(rt_ide_windows); do
    case " $BEFORE " in *" $w "*) ;; *) rt_is_unsaved_dialog "$w" && DLG=$w;; esac
  done
  [ -n "$DLG" ] && break
  sleep 2
done
if [ -n "$DLG" ]; then
  echo "  xclose: protection dialog appeared on window X"
  shot_dialog "$DLG" xclose
  cancel_dialog "$DLG"
  kill -0 "$IDEPID" 2>/dev/null     && echo "  xclose+Cancel: IDE still running"     || { echo "  XCLOSE: IDE closed despite Cancel"; FAILN=$((FAILN+1)); }
  buffer_shows 'VERSION-Y'     && echo "  xclose+Cancel: unsaved buffer preserved (VERSION-Y)"     || { echo "  XCLOSE: buffer lost despite Cancel"; FAILN=$((FAILN+1)); }
else
  sleep 1
  kill -0 "$IDEPID" 2>/dev/null     && echo "  XCLOSE: windowclose did nothing (no WM route to delete-event?)"     || echo "  XCLOSE-UNGUARDED: IDE closed via window X with unsaved changes, no prompt"
  FAILN=$((FAILN+1))
fi
echo "xclose case done (FAILN=$FAILN)"
rt_cleanup
}

click_menu_item() {  # $1 = OCR token; clicks that word in the open File menu
  import -window root -crop "240x340+0+0" /tmp/dl_menu.png 2>/dev/null
  local rel
  rel=$(tesseract /tmp/dl_menu.png - tsv 2>/dev/null | awk -F'\t' -v w="$1" '$12 ~ ("^" w) && $8+0 > 30 {print $7" "$8" "$9" "$10; exit}')
  [ -n "$rel" ] || { echo "  [diag] menu token $1 not found:"; tesseract /tmp/dl_menu.png - 2>/dev/null | head -5; return 1; }
  set -- $rel
  xdotool mousemove $(($1 + $3/2)) $(($2 + $4/2)) click 1; sleep 1
}

run_saveas() {
launch_a
dirty_the_buffer
mkdir -p /tmp/rt_saveas_b; rm -f /tmp/rt_saveas_b/*
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 20 12 mousedown 1; sleep 0.4; xdotool mouseup 1; sleep 0.8
click_menu_item 'As'
sleep 2
xdotool key ctrl+l; sleep 0.5
xdotool type --delay 15 '/tmp/rt_saveas_b/Project1'; sleep 0.5
xdotool key Return; sleep 3
rt_map_all; sleep 0.5
for f in Project1.hbp Project1.prg Form1.prg; do
  [ -f "/tmp/rt_saveas_b/$f" ] || { echo "  SAVEAS: /tmp/rt_saveas_b/$f not written"; FAILN=$((FAILN+1)); }
done
if [ -f /tmp/rt_saveas_b/Form1.prg ]; then
  grep -q 'VERSION-Y' /tmp/rt_saveas_b/Form1.prg     && echo "  saveas: edited content written to the new path"     || { echo "  SAVEAS: new Form1.prg lacks the edit"; FAILN=$((FAILN+1)); }
fi
# auditor defect: deleting the OLD project must not cause a false refusal
rm -f "$RUNA"/Project1.hbp "$RUNA"/Project1.prg "$RUNA"/Form1.prg
local BEFORE w
BEFORE=$(rt_ide_windows | sort -n | tr '\n' ' ')
xdotool key ctrl+s; sleep 3
REF=""
for w in $(rt_ide_windows); do
  case " $BEFORE " in *" $w "*) ;; *) REF=$w;; esac
done
if [ -n "$REF" ]; then
  echo "  SAVEAS: refusal after old project deleted (identity not transitioned)"
  shot_dialog "$REF" saveas-refusal; FAILN=$((FAILN+1))
else
  echo "  saveas: old project deleted, ctrl+s saved without refusal"
fi
echo "saveas case done (FAILN=$FAILN)"
rt_cleanup
}

run_occupied() {
launch_a
mkdir -p /tmp/rt_occ; rm -f /tmp/rt_occ/*
echo "foreign hbp"   > /tmp/rt_occ/Project1.hbp
echo "foreign form"  > /tmp/rt_occ/Form1.prg
echo "foreign main"  > /tmp/rt_occ/Project1.prg
md5sum /tmp/rt_occ/* > /tmp/rt_occ.md5
DLG=$(trigger_and_expect_dialog "ctrl+n")
[ -n "$DLG" ] && { echo "  OCCUPIED: unexpected prompt at New on a clean project"; cancel_dialog "$DLG"; FAILN=$((FAILN+1)); }
sleep 2
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+s; sleep 2
xdotool key ctrl+l; sleep 0.5
xdotool type --delay 15 '/tmp/rt_occ/Project1'; sleep 0.5
xdotool key Return; sleep 2
# the GTK chooser asks its own Replace? when the .hbp exists: confirm it so
# the product-level foreign-file check gets the path at all
REP=""
for w in $(rt_ide_windows); do
  REP=$(tesseract /tmp/dl_repl.png - tsv 2>/dev/null | awk -F'\t' '$12 ~ /^Replace/ {print $7" "$8" "$9" "$10; exit}')
done
import -window root /tmp/dl_replroot.png 2>/dev/null
REP=$(tesseract /tmp/dl_replroot.png - tsv 2>/dev/null | awk -F'\t' '$12 ~ /^Replace/ {print $7" "$8" "$9" "$10; exit}')
if [ -n "$REP" ]; then
  set -- $REP
  echo "  occupied: confirming the GTK chooser's own Replace prompt"
  xdotool mousemove $(($1 + $3/2)) $(($2 + $4/2)) click 1; sleep 2
fi
WARN=""
for w in $(rt_ide_windows); do
  xdotool getwindowname "$w" 2>/dev/null | grep -q '^HbBuilder$' && WARN=$w
done
if [ -n "$WARN" ]; then
  echo "  occupied: overwrite confirmation appeared"
  shot_dialog "$WARN" occupied-confirm
  click_dialog_button "$WARN" '^No$'
  sleep 1
  if md5sum -c /tmp/rt_occ.md5 >/dev/null 2>&1; then
    echo "  occupied: No -> foreign files untouched"
  else
    echo "  OCCUPIED: foreign files MODIFIED despite answering No"; FAILN=$((FAILN+1))
  fi
else
  echo "  OCCUPIED: no overwrite confirmation for foreign files"; FAILN=$((FAILN+1))
fi
echo "occupied case done (FAILN=$FAILN)"
rt_cleanup
}

run_saveclose() {
launch_a
dirty_the_buffer
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+s; sleep 3
rt_map_all; sleep 0.5
grep -q 'VERSION-Y' "$RUNA/Form1.prg"   && echo "  saveclose: ctrl+s wrote the edit to disk"   || { echo "  SAVECLOSE: edit not on disk after ctrl+s"; FAILN=$((FAILN+1)); }
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  SAVECLOSE: FALSE PROMPT on Exit right after a successful save"
  shot_dialog "$DLG" saveclose
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  sleep 2
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  SAVECLOSE: IDE did not exit after clean save"; FAILN=$((FAILN+1)); }     || echo "  saveclose: save then exit, no prompt, IDE closed"
fi
echo "saveclose case done (FAILN=$FAILN)"
rt_cleanup
}

run_discard() {
launch_a
dirty_the_buffer
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -z "$DLG" ]; then
  echo "  DISCARD: no protection dialog on Exit"; FAILN=$((FAILN+1))
else
  shot_dialog "$DLG" discard
  click_dialog_button "$DLG" '^Discard$'
  sleep 3
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  DISCARD: IDE still running after Discard on Exit"; FAILN=$((FAILN+1)); }     || echo "  discard: Discard on Exit closed the IDE"
  grep -q 'VERSION-A' "$RUNA/Form1.prg" && ! grep -q 'VERSION-Y' "$RUNA/Form1.prg"     && echo "  discard: disk content untouched (VERSION-A intact)"     || { echo "  DISCARD: disk changed despite Discard"; FAILN=$((FAILN+1)); }
fi
echo "discard case done (FAILN=$FAILN)"
rt_cleanup
}

run_parkonly() {
launch_a
# programmatic designer move (no user edit): sync regenerates to the frozen
# clean text, so Exit must not prompt
local D DX DY
D=$(rt_find_designer) || fail "designer window not found"
eval "$(xdotool getwindowgeometry --shell "$D")"; DX=$X; DY=$Y
xdotool windowmove "$D" 1300 850; sleep 1.5
xdotool windowmove "$D" "$DX" "$DY"; sleep 1.5
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  PARKONLY: FALSE PROMPT on Exit after programmatic move only"
  shot_dialog "$DLG" parkonly
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  sleep 2
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  PARKONLY: IDE did not exit"; FAILN=$((FAILN+1)); }     || echo "  parkonly: programmatic move produced no false dirty"
fi
echo "parkonly case done (FAILN=$FAILN)"
rt_cleanup
}

run_realmoved() {
launch_a
# real model change: drag a control in the designer
local D X Y WIDTH HEIGHT rel
D=$(rt_find_designer) || fail "designer window not found"
BAR=$(rt_find_bar); rt_park_all_but "$D" "$BAR"; sleep 0.5
eval "$(xdotool getwindowgeometry --shell "$D")"
import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/dl_designer.png 2>/dev/null
rel=$(tesseract /tmp/dl_designer.png - tsv 2>/dev/null | awk -F'\t' '$12 ~ /Button|Btn|Boton|Aceptar|OK/ {print $7" "$8" "$9" "$10; exit}')
if [ -z "$rel" ]; then
  echo "  [diag] no control found by OCR; dragging fixture button coords (70,33)"
  rel="70 33 10 10"
fi
set -- $rel
local CX=$((X + $1 + $3/2)) CY=$((Y + $2 + $4/2))
xdotool mousemove "$CX" "$CY" mousedown 1 mousemove $((CX+40)) $((CY+40)) sleep 0.3 mousemove $((CX+45)) $((CY+45)) mouseup 1
sleep 1.5
rt_map_all; sleep 0.5
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  realmoved: real designer change flagged dirty (dialog on Exit)"
  shot_dialog "$DLG" realmoved
  cancel_dialog "$DLG"
  kill -0 "$IDEPID" 2>/dev/null     || { echo "  REALMOVED: IDE closed despite Cancel"; FAILN=$((FAILN+1)); }
else
  sleep 1
  kill -0 "$IDEPID" 2>/dev/null     && echo "  REALMOVED: no dialog and IDE alive (unexpected)"     || echo "  REALMOVED: real designer change did NOT set dirty (silent loss risk)"
  FAILN=$((FAILN+1))
fi
echo "realmoved case done (FAILN=$FAILN)"
rt_cleanup
}

run_closefile() {
launch_a
echo 'line one' > /tmp/rt_openme.txt
# File > Open File...
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
xdotool mousemove 20 12 mousedown 1; sleep 0.4; xdotool mouseup 1; sleep 0.8
click_menu_item 'File'
sleep 1
xdotool key ctrl+l; sleep 0.5
xdotool type --delay 15 '/tmp/rt_openme.txt'; sleep 0.5
xdotool key Return; sleep 2
rt_map_all; sleep 0.5
# edit the opened file tab
CED=""
for w in $(rt_ide_windows); do
  [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
done
[ -n "$CED" ] || fail "Code Editor window not found"
BAR=$(rt_find_bar); rt_park_all_but "$CED" "$BAR"; sleep 0.5
eval "$(xdotool getwindowgeometry --shell "$CED")"
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.4
xdotool key ctrl+End; sleep 0.3
xdotool type --delay 15 '// edited'; sleep 1
rt_map_all; sleep 0.3
# File > Close File -> expect Save/Discard/Cancel
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
local BEFORE w i
BEFORE=$(rt_ide_windows | sort -n | tr '\n' ' ')
xdotool mousemove 20 12 mousedown 1; sleep 0.4; xdotool mouseup 1; sleep 0.8
click_menu_item 'Close'
DLG=""
for i in $(seq 1 8); do
  for w in $(rt_ide_windows); do
    case " $BEFORE " in *" $w "*) ;; *) rt_is_unsaved_dialog "$w" && DLG=$w;; esac
  done
  [ -n "$DLG" ] && break
  sleep 2
done
rt_map_all; sleep 0.5
if [ -z "$DLG" ]; then
  echo "  CLOSEFILE: no guard closing a modified open file"; FAILN=$((FAILN+1))
else
  echo "  closefile: guard appeared for modified open file"
  shot_dialog "$DLG" closefile
  cancel_dialog "$DLG"
  # Cancel must keep the file open: closing again prompts again
  BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; sleep 0.3
  BEFORE=$(rt_ide_windows | sort -n | tr '\n' ' ')
  xdotool mousemove 20 12 mousedown 1; sleep 0.4; xdotool mouseup 1; sleep 0.8
  click_menu_item 'Close'
  DLG=""
  for i in $(seq 1 8); do
    for w in $(rt_ide_windows); do
      case " $BEFORE " in *" $w "*) ;; *) rt_is_unsaved_dialog "$w" && DLG=$w;; esac
    done
    [ -n "$DLG" ] && break
    sleep 2
  done
  rt_map_all; sleep 0.5
  if [ -n "$DLG" ]; then
    echo "  closefile: Cancel kept the file open (guard prompts again)"
    click_dialog_button "$DLG" '^Discard$'; sleep 1
    grep -q 'edited' /tmp/rt_openme.txt       && { echo "  CLOSEFILE: Discard wrote to disk?!"; FAILN=$((FAILN+1)); }       || echo "  closefile: Discard closed without writing"
  else
    echo "  CLOSEFILE: file gone after Cancel (Cancel lost the tab)"; FAILN=$((FAILN+1))
  fi
fi
echo "closefile case done (FAILN=$FAILN)"
rt_cleanup
}


launch_fresh() {  # fresh IDE, startup empty project (never saved)
  rm -rf "$RUNA"; mkdir -p "$RUNA"; rm -f "$TRACE"
  rt_setup "$RUNA"
  rt_launch_ide
  IDEPID=$RT_IDEPID; OTHERPID=""
  rt_find_designer >/dev/null || fail "designer window not found"
  sleep 2
}

run_newclean() {
launch_fresh
# startup empty project, untouched: Exit must NOT prompt (false dirty)
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  NEWCLEAN: FALSE PROMPT on Exit at clean startup"
  shot_dialog "$DLG" newclean-startup
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  sleep 2
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  NEWCLEAN: IDE did not exit at clean startup"; FAILN=$((FAILN+1)); }     || echo "  newclean: clean startup exits with no prompt"
fi
rt_cleanup
# Ctrl+N (TBNew) on a clean session must also stay clean afterwards
launch_fresh
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+n; sleep 3
DLG=""
for w in $(rt_ide_windows); do rt_is_unsaved_dialog "$w" && DLG=$w; done
if [ -n "$DLG" ]; then
  echo "  NEWCLEAN: FALSE PROMPT on Ctrl+N over clean startup project"
  shot_dialog "$DLG" newclean-ctrln
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  echo "  newclean: Ctrl+N over clean startup prompted nothing (correct)"
fi
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  NEWCLEAN: FALSE PROMPT on Exit after clean Ctrl+N"
  shot_dialog "$DLG" newclean-ctrln-exit
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  sleep 2
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  NEWCLEAN: IDE did not exit after clean Ctrl+N"; FAILN=$((FAILN+1)); }     || echo "  newclean: clean Ctrl+N then Exit, no prompt"
fi
echo "newclean case done (FAILN=$FAILN)"
rt_cleanup
}

run_newresize() {
launch_fresh
# real model change on a never-saved project: resize the design form
local D X Y WIDTH HEIGHT
D=$(rt_find_designer) || fail "designer window not found"
BAR=$(rt_find_bar); rt_park_all_but "$D" "$BAR"; sleep 0.5
eval "$(xdotool getwindowgeometry --shell "$D")"
xdotool windowsize "$D" $((WIDTH+40)) $((HEIGHT+40)); sleep 2
rt_map_all; sleep 0.3
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -z "$DLG" ]; then
  sleep 2
  if kill -0 "$IDEPID" 2>/dev/null; then
    echo "  NEWRESIZE: inconclusive (no prompt, IDE alive)"
  else
    echo "  NEWRESIZE: resized never-saved project LOST on Exit (no prompt)"
  fi
  FAILN=$((FAILN+1))
else
  echo "  newresize: resize of never-saved project flagged dirty (dialog on Exit)"
  shot_dialog "$DLG" newresize
  cancel_dialog "$DLG"
fi
echo "newresize case done (FAILN=$FAILN)"
rt_cleanup
}

run_newrevert() {
launch_fresh
# edit then exact revert (BackSpace) on a never-saved project: back to frozen text = clean
local CED w
CED=""
for w in $(rt_ide_windows); do
  [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
done
[ -n "$CED" ] || fail "Code Editor window not found"
BAR=$(rt_find_bar); rt_park_all_but "$CED" "$BAR"; sleep 0.5
eval "$(xdotool getwindowgeometry --shell "$CED")"
xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.4
xdotool key ctrl+End; sleep 0.3
xdotool type --delay 15 'x'; sleep 0.5
xdotool key BackSpace; sleep 0.8
rt_map_all; sleep 0.3
DLG=$(trigger_and_expect_dialog "ctrl+q")
if [ -n "$DLG" ]; then
  echo "  NEWREVERT: FALSE PROMPT after edit+revert on never-saved project"
  shot_dialog "$DLG" newrevert
  cancel_dialog "$DLG"; FAILN=$((FAILN+1))
else
  sleep 2
  kill -0 "$IDEPID" 2>/dev/null     && { echo "  NEWREVERT: IDE did not exit after edit+revert"; FAILN=$((FAILN+1)); }     || echo "  newrevert: edit+revert returns to clean (no prompt)"
fi
echo "newrevert case done (FAILN=$FAILN)"
rt_cleanup
}

for c in $CASES; do
  echo "== case: $c =="
  run_$c
done

if [ "$FAILN" -eq 0 ]; then
  echo "DIRTY PASS (cases executed: $CASES)"
else
  echo "DIRTY FAIL (cases executed: $CASES): $FAILN problem(s)"
  exit 1
fi
