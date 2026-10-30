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
  local NEWVAL=$2
  eval "$(xdotool getwindowgeometry --shell "$INS")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4insp_props.png
  local rel
  rel=$(tesseract /tmp/t4insp_props.png - tsv 2>/dev/null | \
    awk -F'\t' -v w="^$1$" '$12 ~ w {printf "%d %d\n", $7, $8+$10/2; exit}')
  [ -n "$rel" ] || { tesseract /tmp/t4insp_props.png - 2>/dev/null | grep -iE "atabs|acolum|behavior|data" | head -5; fail "property row $1 not found"; }
  set -- $rel
  # value column: right half of the inspector, same row
  xdotool mousemove $((X+WIDTH-60)) $((Y+$2)) click --repeat 2 --delay 120 1; sleep 0.7
  xdotool key ctrl+a; sleep 0.2
  xdotool type --delay 20 "$NEWVAL"; sleep 0.3
  xdotool key Return; sleep 1.5
}

save_and_check() {  # $1 label, rest: grep -F patterns that must be in the file
  local label=$1; shift
  [ -n "${CED:-}" ] && xdotool windowmove "$CED" 0 500 2>/dev/null
  xdotool windowmove "$INS" 0 600 2>/dev/null
  [ -n "${RT_DESIGNER:-}" ] && xdotool windowmove "$RT_DESIGNER" 0 700 2>/dev/null
  for w in $(rt_ide_windows); do
    case "$(xdotool getwindowname "$w" 2>/dev/null)" in "AI Assistant") xdotool windowmove "$w" 1100 700 2>/dev/null;; esac
  done
  sleep 0.5
  menu_path_click '^Save' || fail "$label: File > Save not clickable"
  sleep 2
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
save_and_check folder 'PROMPTS "P1", "Pag2X"' 'COLSIZES 90, 60' 'FOOTERS "Total", ""' 'OF ::oFld1:aPages[2]'

# 2. BROWSE aColumns edit: Nombre|Edad -> Nombre|Anos
pick_combo 'TBrowse$'
edit_row aColumns 'Nombre|Anos' 
save_and_check browse 'HEADERS "Nombre", "Anos"' 'COLSIZES 90, 60' 'FOOTERS "Total", ""' 'PROMPTS "P1", "Pag2X"'

echo "T4INSP PASS: inspector edits of aTabs/aColumns regenerate faithfully; structure preserved"
