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
  local BAR=$(rt_find_bar)
  xdotool windowactivate "$BAR" 2>/dev/null
  xdotool mousemove 700 12 click 1; sleep 0.4
  xdotool key ctrl+s; sleep 2
  local DLG=""
  for i in 1 2 3 4 5; do
    for w in $(rt_ide_windows); do
      case " $W0 " in *" $w "*) continue;; esac
      [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && { DLG=$w; break; }
    done
    [ -n "$DLG" ] && break
    sleep 1
  done
  [ -n "$DLG" ] || fail "$1: Ctrl+S was not refused (no dialog)"
  eval "$(xdotool getwindowgeometry --shell "$DLG")"
  import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/t4neg_$1.png
  local TXT=$(tesseract /tmp/t4neg_$1.png - 2>/dev/null)
  echo "  [$1] dialog OCR: $(echo "$TXT" | tr '\n' ' ' | cut -c1-140)"
  echo "$TXT" | grep -qi 'aborted' || fail "$1: dialog is not the abort notice"
  echo "$TXT" | grep -qE "$3" || fail "$1: dialog does not name the reason ($3)"
  local MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  [ "$MD0" = "$MD1" ] || fail "$1: Form1.prg changed on disk after the refused save"
  echo "  [$1] refused, disk byte-identical"
  rt_cleanup
  sleep 1
}

run_case prompts 's/PROMPTS "P1", "P2"/PROMPTS "P1", "P2/' 'PROMPTS'
run_case colsizes 's/COLSIZES 90, 60/COLSIZES 90x, 60/' 'COLSIZES'

echo "T4BLOCK PASS: unparseable FOLDER PROMPTS and non-numeric COLSIZES both refused; disk byte-identical."
