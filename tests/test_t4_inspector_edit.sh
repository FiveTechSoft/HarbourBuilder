#!/bin/bash
# T4 residual: edit FOLDER aTabs and BROWSE aColumns THROUGH THE INSPECTOR
# property grid (not the code editor). The two-way sync must regenerate the
# code faithfully: PROMPTS/HEADERS reflect the edit, and the rest of the
# structure (COLSIZES/FOOTERS, page membership of the page-2 button) survives.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
RUN=/tmp/t4insp
source "$REPO/tests/harness_lib.sh"
fail() { echo "T4INSP FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
rm -rf "$RUN"; mkdir -p "$RUN"
cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
rt_setup "$RUN"
rt_launch_ide
rt_reopen_project

INS=""
for i in 1 2 3 4 5; do
  for w in $(rt_ide_windows); do
    case "$(xdotool getwindowname "$w" 2>/dev/null)" in Inspector*) INS=$w; break;; esac
  done
  [ -n "$INS" ] && break
  sleep 1
done
if [ -z "$INS" ]; then
  echo "  [diag] IDE windows seen:"
  for w in $(rt_ide_windows); do
    echo "    $w '$(xdotool getwindowname "$w" 2>/dev/null)'"
  done
  fail "Inspector window not found"
fi
echo "Inspector window: $INS"

# --- simpler, deterministic path: the combo lists entries in build order ---
# oForm1, oBtnOk, oLbl1... oFld1, oFld1 pages..., oBrw1, oBrw1 cols...
# Select via keyboard: focus combo, then arrow down N times.
pick_combo() {  # $1 = entry text regex
  local PICKRE=$1
  xdotool windowmove "$INS" 0 165; xdotool windowraise "$INS"; xdotool windowfocus "$INS"; sleep 0.5
  eval "$(xdotool getwindowgeometry --shell "$INS")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_win.png
  local rel
  rel=$(tesseract /tmp/t4insp_win.png - tsv 2>/dev/null | \
    awk -F'\t' '$12 ~ /AS/ {printf "%d %d\n", $7+$9/2, $8+$10/2; exit}')
  [ -n "$rel" ] || fail "inspector combo not located"
  set -- $rel
  xdotool mousemove $((X+$1)) $((Y+$2)) click 1; sleep 1
  import -window root /tmp/t4insp_combo.png
  local pick
  pick=$(tesseract /tmp/t4insp_combo.png - tsv 2>/dev/null | \
    awk -F'\t' -v w="$PICKRE" '$12 ~ w {printf "%d %d\n", $7+$9/2, $8+$10/2; exit}')
  [ -n "$pick" ] || { tesseract /tmp/t4insp_combo.png - 2>/dev/null | head -12; fail "combo entry $PICKRE not found"; }
  set -- $pick
  xdotool mousemove "$1" "$2" click 1; sleep 1
}

edit_row() {  # $1 prop name, $2 new value
  local NEWVAL=$2 PROP=$1
  xdotool windowraise "$INS"; xdotool windowfocus "$INS"; sleep 0.5
  local rel try
  # the property list scrolls: page it until the row is confidently visible
  for try in 1 2 3 4 5 6; do
    eval "$(xdotool getwindowgeometry --shell "$INS")"
    import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_props.png
    rel=$(tesseract /tmp/t4insp_props.png - tsv 2>/dev/null | \
      awk -F'\t' -v w="^$PROP$" '$11+0 > 40 && $12 ~ w {printf "%d %d\n", $7, $8+$10/2; exit}')
    [ -n "$rel" ] && break
    xdotool mousemove $((X+150)) $((Y+400)) click 1; sleep 0.4
    xdotool key Next; sleep 0.8
  done
  [ -n "$rel" ] || { tesseract /tmp/t4insp_props.png - 2>/dev/null | head -25; fail "property row $PROP not found after scrolling"; }
  set -- $rel
  echo "  [$PROP] row at +$1,+$2; inspector $INS origin=$X,$Y size=${WIDTH}x${HEIGHT}"
  # Array properties use the dedicated Array Editor, not inline editing.
  # Activate the name cell to avoid the noneditable value renderer.
  xdotool mousemove $((X+60)) $((Y+$2)) click 1
  xdotool key Return; sleep 1
  local ARR="" w
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Array Editor" ] && { ARR=$w; break; }
  done
  [ -n "$ARR" ] || fail "$PROP: Array Editor did not open"
  eval "$(xdotool getwindowgeometry --shell "$ARR")"
  xdotool windowraise "$ARR"; xdotool windowfocus "$ARR"
  xdotool mousemove $((X+100)) $((Y+80)) click 1
  xdotool key ctrl+a
  printf '%s' "$NEWVAL" | tr '|' '\n' > /tmp/t4insp_newvalue.txt
  local item first=1
  while IFS= read -r item || [ -n "$item" ]; do
    [ "$first" = 1 ] || xdotool key Return
    xdotool type --clearmodifiers -- "$item"
    first=0
  done < /tmp/t4insp_newvalue.txt
  sleep 0.5
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_array_${PROP}.png
  echo "  [$PROP] Array Editor content: $(tesseract /tmp/t4insp_array_${PROP}.png - 2>/dev/null | tr '\n' ' ')"
  local ok
  ok=$(tesseract /tmp/t4insp_array_${PROP}.png - tsv 2>/dev/null | awk -F'\t' 'tolower($12) == "ok" {printf "%d %d", $7+$9/2, $8+$10/2; exit}')
  [ -n "$ok" ] || fail "$PROP: OK button not located"
  set -- $ok
  xdotool mousemove $((X+$1)) $((Y+$2)) click 1; sleep 1.5
  xwininfo -id "$ARR" 2>/dev/null | grep -q IsViewable && fail "$PROP: Array Editor did not close"
  echo "  [$PROP] Array Editor OK applied; checking generated buffer next"

}

# OCR the code editor buffer for a regenerated line BEFORE any save: proves
# the two-way sync updated the buffer (separates edit-commit from save driving)
verify_buffer() {  # $1 = OCR regex expected in the Code Editor buffer
  [ -n "${CED:-}" ] || fail "Code Editor missing"
  xdotool windowmove "$CED" 310 200; xdotool windowraise "$CED"; xdotool windowfocus "$CED"
  eval "$(xdotool getwindowgeometry --shell "$CED")"
  xdotool mousemove $((X+400)) $((Y+150)) click 1
  xdotool key ctrl+Home
  xdotool key --repeat 54 --repeat-delay 5 Down; sleep 0.5
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_buffer_$1.png
  tesseract /tmp/t4insp_buffer_$1.png - 2>/dev/null | grep -qF "$1" || fail "regenerated buffer missing $1 before Save"
  echo "  [buffer] regenerated text verified BEFORE Save: $1"

}

save_and_check() {  # $1 label, rest: grep -F patterns that must be in the file
  local label=$1; shift
  # park EVERY non-bar IDE window: any of them can cover the menu bar at 0,0
  local BARW w
  BARW=$(rt_find_bar) || fail "$label: IDE bar not found"
  for w in $(rt_ide_windows); do
    case "$(xdotool getwindowname "$w" 2>/dev/null)" in
      "Code Editor"|Inspector*|"AI Assistant"|Messages|"Fixture Roundtrip")
        xdotool windowmove "$w" 1100 700 2>/dev/null;;
    esac
  done
  # Never move unnamed GTK popup/menu windows: doing so relocates the
  # dropdown offscreen. Raise/focus only the actual main menu toplevel.
  xdotool windowmove "$BARW" 0 0; xdotool windowraise "$BARW"; xdotool windowfocus "$BARW"
  sleep 0.5
  if ! menu_path_click '^Save'; then
    echo "  [$label] menu path failed; using the real Ctrl+S handler with focus on the bar window"
    xdotool mousemove 700 12 click 1; sleep 0.4
    xdotool key ctrl+s
  fi
  sleep 2
  for w in $(rt_ide_windows); do
    case "$(xdotool getwindowname "$w" 2>/dev/null)" in HbBuilder)
      xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && \
        [ "$(xdotool getwindowname "$w")" = "HbBuilder" ] && \
        fail "$label: unexpected modal after save (refusal?)";; esac
  done
  local p
  for p in "$@"; do
    grep -qF "$p" "$RUN/Form1.prg" || { echo "--- $label: FOLDER/BROWSE lines ---"; grep -E "FOLDER|BROWSE|aPages" "$RUN/Form1.prg"; fail "$label: missing in saved file: $p"; }
    echo "  [$label] saved file keeps: $p"
  done
}

for w in $(rt_ide_windows); do
  [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
done

# 1. FOLDER aTabs edit: P1|P2 -> P1|Pag2X
pick_combo 'TFolder$'
edit_row aTabs 'P1|Pag2X' 
verify_buffer 'Pag2X'
save_and_check folder 'PROMPTS "P1", "Pag2X"' 'COLSIZES 90, 60' 'FOOTERS "Total", ""' 'OF ::oFld1:aPages[2]'

# 2. BROWSE aColumns edit: Nombre|Edad -> Nombre|Anos
pick_combo 'TBrowse$'
edit_row aColumns 'Nombre|Anos' 
verify_buffer 'Anos'
save_and_check browse 'HEADERS "Nombre", "Anos"' 'COLSIZES 90, 60' 'FOOTERS "Total", ""' 'PROMPTS "P1", "Pag2X"'

# Fresh IDE process loading the saved files: inspect actual persisted arrays.
rt_cleanup
rt_launch_ide
rt_reopen_project
INS=""
for w in $(rt_ide_windows); do
  case "$(xdotool getwindowname "$w" 2>/dev/null)" in Inspector*) INS=$w; break;; esac
done
[ -n "$INS" ] || fail "Inspector missing after reopening saved project"
check_array() {
  local PROP=$1 WANT1=$2 WANT2=$3 rel ARR="" w
  pick_combo "$4"
  rel=$(tesseract /tmp/t4insp_win.png - tsv 2>/dev/null | awk -F'\t' -v p="$PROP" '$12 == p {printf "%d %d",$7+$9/2,$8+$10/2;exit}')
  # Capture current properties after combo selection, not the earlier form.
  eval "$(xdotool getwindowgeometry --shell "$INS")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_reopen_props.png
  rel=$(tesseract /tmp/t4insp_reopen_props.png - tsv 2>/dev/null | awk -F'\t' -v p="$PROP" '$12 == p {printf "%d %d",$7+$9/2,$8+$10/2;exit}')
  [ -n "$rel" ] || fail "$PROP missing after reopen"
  set -- $rel
  xdotool mousemove $((X+$1)) $((Y+$2)) click 1; xdotool key Return; sleep 1
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Array Editor" ] && { ARR=$w; break; }
  done
  [ -n "$ARR" ] || fail "$PROP Array Editor missing after reopen"
  eval "$(xdotool getwindowgeometry --shell "$ARR")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_reopen_${PROP}.png
  convert /tmp/t4insp_reopen_${PROP}.png +repage -crop 300x100+0+0 +repage -resize 300% /tmp/t4insp_reopen_text.png
  tesseract /tmp/t4insp_reopen_text.png - --psm 6 2>/dev/null | grep -qiF "$WANT1" || fail "$PROP first item lost after reopen"
  tesseract /tmp/t4insp_reopen_text.png - --psm 6 2>/dev/null | grep -qiF "$WANT2" || fail "$PROP second item lost after reopen"
  echo "  [reopen Inspector] $PROP contains $WANT1 / $WANT2"
  xdotool key Escape; sleep 0.5
}
check_array aTabs P1 Pag2X 'TFolder$'
check_array aColumns Nombre Anos 'TBrowse$'
rt_cleanup
echo "T4INSP PASS: inspector edits, generated buffer, Save and fresh-process Inspector reopen verified"
