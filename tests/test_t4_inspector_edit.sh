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
  xdotool windowactivate "$INS"; sleep 0.5
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
  # value column: right half of the inspector, same row
  xdotool mousemove $((X+WIDTH-60)) $((Y+$2)) click --repeat 2 --delay 120 1; sleep 0.7
  xdotool key ctrl+a; sleep 0.2
  xdotool type --delay 20 "$NEWVAL"; sleep 0.3
  xdotool key Return; sleep 1.5
  # verify the cell commit independently of any save step: re-read the row
  eval "$(xdotool getwindowgeometry --shell "$INS")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_after.png
  local NOW
  NOW=$(tesseract /tmp/t4insp_after.png - 2>/dev/null | grep -iE "atabs|acolumns" | head -2 | tr '\n' ' ')
  echo "  [edit_row $PROP] inspector row after commit: $NOW"
  echo "$NOW" | grep -qF "$NEWVAL" || fail "$PROP: cell edit did not commit (row shows: $NOW)"
}

# OCR the code editor buffer for a regenerated line BEFORE any save: proves
# the two-way sync updated the buffer (separates edit-commit from save driving)
verify_buffer() {  # $1 = OCR regex expected in the Code Editor buffer
  [ -n "${CED:-}" ] || { echo "  [buffer] Code Editor window unknown, skipped"; return 0; }
  eval "$(xdotool getwindowgeometry --shell "$CED")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_buf.png
  if tesseract /tmp/t4insp_buf.png - 2>/dev/null | grep -qE "$1"; then
    echo "  [buffer] regenerated line visible in code editor: $1"
  else
    echo "  [buffer] WARN: $1 not visible (tab not focused?); continuing to save check"
  fi
}

save_and_check() {  # $1 label, rest: grep -F patterns that must be in the file
  local label=$1; shift
  # park EVERY non-bar IDE window: any of them can cover the menu bar at 0,0
  local BARW w
  BARW=$(rt_find_bar) || fail "$label: IDE bar not found"
  for w in $(rt_ide_windows); do
    [ "$w" = "$BARW" ] || xdotool windowmove "$w" 1100 700 2>/dev/null
  done
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

echo "T4INSP PASS: inspector edits of aTabs/aColumns regenerate faithfully; structure preserved"
