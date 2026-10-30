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
  xdotool type --delay 15 'return "VERSION-Y"'; sleep 1
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/dl_edit.png 2>/dev/null
  tesseract /tmp/dl_edit.png - 2>/dev/null | grep -q 'VERSION-Y' \
    || { tesseract /tmp/dl_edit.png - 2>/dev/null | tail -3; fail "buffer edit did not land (harness)"; }
  xdotool windowmove "$D" "$DX" "$DY"; sleep 0.3
  echo "  [t=$SECONDS] buffer dirtied (VERSION-Y, unsaved)"
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
xdotool mousemove 20 12 click 1; sleep 0.8
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
