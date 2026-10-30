#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/ins_identity
fail(){ echo "IDENTITY FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
mkdir -p "$RUN"
cp "$REPO"/tests/fixtures/roundtrip/{Form1.prg,Project1.prg,Project1.hbp} "$RUN/"
rt_setup "$RUN"; rt_launch_ide; rt_reopen_project
INS=""
for w in $(rt_ide_windows); do
 case "$(xdotool getwindowname "$w")" in Inspector*) INS=$w;; esac
done
[ -n "$INS" ] || fail 'Inspector missing'
pick(){
 local idx=$1 want=$2
 xdotool windowmove "$INS" 0 165; xdotool windowraise "$INS"; xdotool windowfocus "$INS"
 xdotool mousemove 100 182 click 1; xdotool key Home
 [ "$idx" -gt 0 ] && xdotool key --repeat "$idx" --repeat-delay 40 Down
 xdotool key Return; sleep 0.7
 eval "$(xdotool getwindowgeometry --shell "$INS")"
 import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" "/tmp/identity_${idx}.png"
 local title txt
 title=$(xdotool getwindowname "$INS")
 txt=$(tesseract "/tmp/identity_${idx}.png" - 2>/dev/null)
 if [[ "$want" == page* ]]; then
  echo "$txt" | grep -q cCaption || fail "index$idx did not expose page caption"
  echo "$txt" | grep -q nPage || fail "index$idx did not expose page index"
 elif [ "$want" = column ]; then
  echo "$txt" | grep -q nWidth || fail "column width property missing"
 else
  [[ "$title" == "Inspector: $want" ]] || fail "index$idx expected $want got $title"
 fi
 echo "  selected index$idx expected=$want title=$title"
}
pick 1 TButton
pick 13 TFolder
pick 14 page1
pick 15 page2
pick 16 TButton
pick 17 TBrowse
pick 18 column
pick 19 column
# Delete the selected first button through the designer, then inspect the
# rebuilt live map (one control fewer, pages/columns still expanded).
pick 1 TButton
xdotool windowmove "$RT_DESIGNER" 400 200
xdotool windowraise "$RT_DESIGNER"; xdotool windowfocus "$RT_DESIGNER"
xdotool key Delete; sleep 1
pick 12 TFolder
pick 13 page1
pick 14 page2
pick 15 TButton
pick 16 TBrowse
pick 17 column
rt_cleanup
echo 'IDENTITY PASS: controls before/after folder, pages, columns and map after delete'
