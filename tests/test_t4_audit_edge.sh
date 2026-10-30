#!/bin/bash
# T4 audit edge cases (independent-auditor findings):
#  - empty first PROMPTS/HEADERS items must SURVIVE a save (positive fidelity)
#  - surplus COLSIZES/FOOTERS, COLSIZES/FOOTERS without HEADERS, out-of-range
#    aPages[N] must REFUSE (negative, dialog at open, disk byte-identical)
#  - case-variant folder name in OF ::oFLD1:aPages[2] must RESOLVE (positive)
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIX="$REPO/tests/fixtures/roundtrip"
source "$REPO/tests/harness_lib.sh"
fail() { echo "T4EDGE FAIL: $1"; rt_cleanup; exit 1; }

rt_provenance

# negative: corrupt the fixture with $2, expect the refusal dialog at open
# whose OCR matches $3, disk byte-identical
run_refuse_case() {  # $1 name, $2 sed expr, $3 OCR reason regex
  local RUN=/tmp/t4edge_$1
  rm -rf "$RUN"; mkdir -p "$RUN"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
  sed -i "$2" "$RUN/Form1.prg"
  rt_setup "$RUN"
  rt_launch_ide
  rt_reopen_project
  local MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  local DLG="" w i
  for i in 1 2 3 4 5; do
    for w in $(rt_ide_windows); do
      [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && \
        xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && { DLG=$w; break; }
    done
    [ -n "$DLG" ] && break
    sleep 1
  done
  [ -n "$DLG" ] || fail "$1: no refusal dialog at open"
  eval "$(xdotool getwindowgeometry --shell "$DLG")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4edge_$1.png
  local TXT=$(tesseract /tmp/t4edge_$1.png - 2>/dev/null)
  echo "  [$1] dialog OCR: $(echo "$TXT" | tr '\n' ' ' | cut -c1-140)"
  echo "$TXT" | grep -qi 'aborted' || fail "$1: dialog is not the abort notice"
  echo "$TXT" | grep -qE "$3" || fail "$1: dialog does not name the reason ($3)"
  [ "$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)" = "$MD0" ] || fail "$1: disk changed on open"
  echo "  [$1] refused at open, disk byte-identical"
  rt_cleanup
  sleep 1
}

# positive: modify the fixture with $2, expect NO refusal at open, then a
# File > Save writes the file and $3 survives verbatim in the saved code
run_keep_case() {  # $1 name, $2 sed expr, $3 grep -F expected in saved file
  local RUN=/tmp/t4edge_$1
  rm -rf "$RUN"; mkdir -p "$RUN"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
  sed -i "$2" "$RUN/Form1.prg"
  rt_setup "$RUN"
  rt_launch_ide
  rt_reopen_project
  local w
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && \
      xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && \
      fail "$1: unexpected refusal dialog at open"
  done
  local MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  # expose the bar and save via the real File > Save menu
  local CED=""
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
  done
  [ -n "$CED" ] && xdotool windowmove "$CED" 0 500 2>/dev/null
  [ -n "${RT_DESIGNER:-}" ] && xdotool windowmove "$RT_DESIGNER" 0 600 2>/dev/null
  sleep 0.5
  menu_path_click '^Save' || fail "$1: File > Save menu path not clickable"
  sleep 2
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && \
      xwininfo -id "$w" 2>/dev/null | grep -q IsViewable && \
      fail "$1: save refused (dialog) though the source is interpretable"
  done
  local MD3=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  [ "$MD3" != "$MD0" ] || fail "$1: save did not write the file"
  grep -qF "$3" "$RUN/Form1.prg" || { echo "  [$1] saved line:"; grep -E "FOLDER|BROWSE|aPages" "$RUN/Form1.prg"; fail "$1: expected content not in the saved file: $3"; }
  echo "  [$1] saved, content preserved: $3"
  rt_cleanup
  sleep 1
}

WANT="${1:-all}"
run() { local kind=$1 name=$2; shift 2; [ "$WANT" = "all" ] || [ "$WANT" = "$name" ] || return 0; "run_${kind}_case" "$name" "$@"; }

run refuse surplus_sizes 's/COLSIZES 90, 60/COLSIZES 90, 60, 30/' 'COLSIZES'
run refuse surplus_footers 's/FOOTERS "Total", ""/FOOTERS "Total", "", "X"/' 'FOOTERS'
run refuse sizes_no_headers 's/ HEADERS "Nombre", "Edad"//' 'for 0 column'
run refuse page_oob 's/::oFld1:aPages\[2\]/::oFld1:aPages[9]/' 'not resolved'
run refuse page_junk 's/::oFld1:aPages\[2\]/::oFld1:aPages[2x]/' 'not resolved'
run keep empty_prompt 's/PROMPTS "P1", "P2"/PROMPTS "", "P2"/' 'PROMPTS "", "P2"'
run keep empty_header 's/HEADERS "Nombre", "Edad"/HEADERS "", "Edad"/' 'HEADERS "", "Edad"'
run keep case_variant 's/OF ::oFld1:aPages\[2\]/OF ::oFLD1:aPages[2]/' 'OF ::oFld1:aPages[2]'

echo "T4EDGE PASS: 5 refusals byte-identical; empty first prompt/header and case-variant folder name survive the save"
